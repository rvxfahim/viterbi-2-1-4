# Architecture

## The code

| Parameter | Value |
|---|---|
| Rate | 1/2 |
| Constraint length K | 4 |
| Memory elements | 3 |
| Trellis states | 8 |
| Generators | g1 = `1111` (octal 17), g0 = `1011` (octal 13) |
| Message block | 7 bits, **not** zero-tail terminated |
| Codeword | 14 bits |
| Decision | hard |
| Decoder latency | 45 trellis clocks + 8 traceback clocks |

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

## Decoder — `rtl/decoder.sv`

The decoder takes the entire 14-bit received word in parallel on `dat` and
returns the 7-bit message on `out`. It is a single 1300-line
`always @(posedge clk)` block with the trellis hand-unrolled rather than
generated.

**Data structures.** Seven `HammingTable` structs `h1 … h7`, one per trellis
stage. Each holds the received bit pair for its stage, the eight branch metrics
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
| 3 … 7 | 8 each | the full trellis |
| **total** | **45** | |

Traceback then needs one edge to pick the lowest final metric and seven to walk
back and emit the message, for **53 clocks end to end**.

**Survivor marking.** Rather than storing survivor pointers, the loser of each
compare has its branch-metric field overwritten with the sentinel value `3`.
`getReturnPath()` later reads those sentinels back to reconstruct the path. The
C++ reference uses `-1` for the same purpose.

**Comparisons** use a strict `<`, so on a metric tie the *higher-numbered*
predecessor survives; the final-state scan also uses strict `<`, so on a tie the
*lowest-numbered* state wins. `model/viterbi_ref.py` reproduces both rules
exactly, which is why the two agree on all 1920 sweep cases.

## Why the design loses to uncoded BPSK

The 7-bit block is not flushed with `K-1 = 3` zero bits, so the decoder cannot
force the trellis back to state 0 and must instead minimise over all eight end
states. The last two message bits are therefore decided by only one or two
branch comparisons each, and are barely protected.

Consequences, all measured rather than asserted:

* Exhaustively, 1536 of 1792 single-bit channel errors are corrected (85.7%),
  and **every** failure lands on codeword bits 0–3 — see
  `docs/img/error_correction_heatmap.png`.
* Over AWGN the rate-1/2 code spends 3 dB of energy per information bit to buy
  redundancy, and the weak tail means it never earns that back: the as-built
  decoder sits *above* the uncoded BPSK curve at every Eb/N0 simulated.
* Adding a 3-bit zero tail (rate 7/20) moves the curve below uncoded and is
  worth about 2.3 dB at BER = 1e-3.

This is a property of the block framing, not a bug in the ACS or traceback
logic — those are exactly correct, as the 1920-case equivalence check shows.

## Critical path

Synthesised to an iCE40 UP5K the design uses 1873 of 5280 logic cells (35%) and
reaches about **13 MHz**. The limit is the combinational depth of
`getReturnPath()`: a seven-deep chain of 8-way case statements is evaluated
within a single clock edge. Pipelining that tree, or storing survivor pointers
in a RAM instead of recomputing them from sentinels, is the obvious speed-up.

See also [bitorder.md](bitorder.md), [known-issues.md](known-issues.md),
[toolchain.md](toolchain.md).
