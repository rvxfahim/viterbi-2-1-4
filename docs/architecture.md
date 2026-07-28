# Architecture

## The code

| Parameter | Value |
|---|---|
| Rate | 1/2 |
| Constraint length K | 4 |
| Memory elements | 3 |
| Trellis states | 8 |
| Generators | g1 = `1111` (octal 17), g0 = `1011` (octal 13) |
| Decision | hard |

Two decoder variants are built, differing only in block framing — the code,
the generators and the encoder are identical:

| | `rtl/decoder.sv` | `rtl/decoder_term.sv` |
|---|---|---|
| Message block | 7 bits | 7 bits + 3 zero tail bits |
| Codeword | 14 bits | 20 bits |
| Effective rate | 7/14 = 0.50 | 7/20 = 0.35 |
| Trellis stages | 7 | 10 |
| Traceback starts from | lowest of 8 end states | state 0, known |
| Latency | 45 + 8 clocks | 69 + 11 clocks |
| Single-bit errors corrected | 1536/1792 (85.7%) | **2560/2560 (100%)** |

`decoder.sv` is what the original assignment produced and what the published
waveforms show. `decoder_term.sv` is what the code should have been framed as.

## Encoder — `rtl/d_ff.sv`

A four-tap shift register. On each rising edge `q0 <- d`, `q1 <- q0`,
`q2 <- q1`, `q3 <- q2`, and the outputs are then computed from the *post-shift*
register:

```
out[1] = q0 ^ q1 ^ q2 ^ q3      // g1 = 1111
out[0] = q0 ^ q1 ^ q3           // g0 = 1011
```

Writing the pre-shift state as `s = (q0, q1, q2)` with `s2 = q0` the newest bit,
that is equivalently

```
out1 = d ^ s2 ^ s1 ^ s0
out0 = d ^ s2 ^ s0
next = (d << 2) | (s >> 1)
```

so state `n` is reachable only from `2*(n & 3)` and `2*(n & 3) + 1`. This is
the transition rule the decoder, the Python model and every figure share.

## Decoder

The decoder takes the entire received word in parallel on `dat` and returns the
7-bit message on `out`. It is a single `always @(posedge clk)` block with the
trellis fully unrolled — one `steps_n`/`stage_n` branch per butterfly.

**Both variants are generated** from `rtl/gen/decoder.sv.j2` by
`scripts/gen_rtl.py`. The original was written out by hand, which is why it ran
to 1317 lines for seven stages; extending that to ten by hand would have meant
~600 more lines of near-identical ladder with a mistyped `high`/`low` waiting in
it. The template derives every branch's expected output pair from the generator
polynomials instead, so the two variants cannot disagree by transcription error.
The generated seven-stage decoder is checked against the golden model on the
same 1920 cases as the hand-written one, which is what shows the template
reproduces the original rather than merely resembling it.

Do not edit `rtl/decoder.sv` or `rtl/decoder_term.sv` directly — edit the
template and run `python scripts/run_all.py gen`. `gen --check` fails if the
checked-in files have drifted.

**Data structures.** One `HammingTable` struct per trellis stage, `h1 … h7`
(or `h1 … h10`). Each holds the received bit pair for its stage, the eight branch metrics
(`aTransition … hTransition`), the previous stage's metrics, and its own eight
accumulated path metrics in `hammingDistances.finalStates[0:7]`. These are
*unpacked* structs containing unpacked arrays — the single most consequential
fact about this design for tooling (see [toolchain.md](toolchain.md)).

**Schedule.** One add-compare-select butterfly per clock edge, sequenced by
`steps_n` (which stage) and `stage_n` (which state within the stage):

| `steps_n` | edges | why |
|---|---|---|
| 1 | 1 | only state 0 is occupied, so only two branches exist |
| 2 | 4 | four states reachable (0, 2, 4, 6) |
| 3 … N | 8 each | the full trellis |
| **total** | **45** (7 stages) / **69** (10 stages) | |

Traceback then needs one edge to establish the starting state and one per stage
to walk back and emit the message: **53 clocks end to end** unterminated, **80**
terminated. In the terminated variant the first three bits recovered are the
zero tail and are dropped rather than driven onto `out`.

**Survivor marking.** Rather than storing survivor pointers, the loser of each
compare has its branch-metric field overwritten with the sentinel value `3`.
`getReturnPath()` later reads those sentinels back to reconstruct the path. The
C++ reference uses `-1` for the same purpose.

**Comparisons** use a strict `<`, so on a metric tie the *higher-numbered*
predecessor survives; the final-state scan also uses strict `<`, so on a tie the
*lowest-numbered* state wins. `model/viterbi_ref.py` reproduces both rules
exactly, which is why the two agree on all 1920 sweep cases.

## Why the unterminated design loses to uncoded BPSK

The 7-bit block is not flushed with `K-1 = 3` zero bits, so the decoder cannot
force the trellis back to state 0 and must instead minimise over all eight end
states. The last two message bits are therefore decided by only one or two
branch comparisons each, and are barely protected.

Consequences, all measured rather than asserted:

* Exhaustively, 1536 of 1792 single-bit channel errors are corrected (85.7%),
  and **every** failure lands on codeword bits 0-3 - see
  `docs/img/error_correction_heatmap.png`.
* Over AWGN the rate-1/2 code spends 3 dB of energy per information bit to buy
  redundancy, and the weak tail means it never earns that back: the as-built
  decoder sits *above* the uncoded BPSK curve at every Eb/N0 simulated.

This is a property of the block framing, not a bug in the ACS or traceback
logic - those are exactly correct, as the 1920-case equivalence check shows.

## What termination fixes

`rtl/decoder_term.sv` clocks `K-1 = 3` zeros in after the message, driving the
encoder's register back to state 0. The decoder then knows where the survivor
ends and traces back from there unconditionally.

This does not change the code. It is still (2,1,4), still rate 1/2, still the
same generator polynomials, and `rtl/d_ff.sv` is byte-identical between the two
flows - terminating is something the *transmitter* does, not the encoder. Only
the framing changes: 7 message bits now occupy 20 code bits instead of 14, an
effective rate of 0.35 rather than 0.50.

What it buys:

* **2560/2560** single-bit errors corrected, at every one of the 20 codeword
  positions, across all 128 messages. A (2,1,4) code has free distance 6, so
  with a defined end state every single error is inside its correcting radius.
  `docs/img/error_correction_compare.png` puts the two side by side.
* About **2.3 dB at BER = 1e-3** over AWGN, which is what moves the curve from
  above the uncoded BPSK line to below it.

## Synthesis and critical path

On an iCE40 UP5K (SG48), via Yosys `read_slang` and nextpnr-ice40:

| | logic cells | LUT4 | carry | flops | Fmax | critical path |
|---|---|---|---|---|---|---|
| `decoder` | 1810 / 5280 (34%) | 1338 | 511 | 497 | ~13 MHz | 77.7 ns (33.4 logic + 44.3 routing) |
| `decoder_term` | 2356 / 5280 (44%) | 1936 | 799 | 703 | ~27 MHz | 36.9 ns (12.7 logic + 24.2 routing) |

Two things in that table are worth reading carefully.

The terminated decoder is 30% larger, which is expected - three more trellis
stages means three more `HammingTable` structs and three more ladder blocks.

It is also **twice as fast**, which is not obvious. The structural difference is
that the unterminated variant contains an eight-way minimum search over
`temp_states` to find the best end state, evaluated combinationally within one
clock edge; the terminated variant has no such search because the end state is
known. Both critical paths run from `data[*]` into a stage's metric flops, and
the unterminated one is more than twice as long. Fmax varies by roughly ±0.5 MHz
between placer seeds, so treat these as approximate.

Either way the ceiling is combinational depth evaluated in a single edge.
Storing survivor pointers in a RAM instead of recomputing them from sentinels,
or pipelining `getReturnPath()`, is the obvious next step.

See also [bitorder.md](bitorder.md), [known-issues.md](known-issues.md),
[toolchain.md](toolchain.md).
