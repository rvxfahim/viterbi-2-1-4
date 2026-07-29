# Known issues and design quirks

Everything here was found by the open-source flow. The first section lists what
has since been fixed and how the fix is proven; the second lists what is still
outstanding, deliberately or otherwise.

The original hand-written decoder is preserved verbatim at
`rtl/legacy/decoder.sv`, so every item below can still be reproduced.

---

## Fixed

### 1. `counter_for_path` was never reset

The original resets `steps_n`, `stage_n`, `table_counter` and `pinOut` in its
`if (!reset)` branch, but not `counter_for_path`, which drives the traceback
state machine. A single decode worked because the `byte` starts at 0, but a
second decode in the same simulation began with a stale counter of 8 and emitted
nothing — the design decoded exactly **one word per power-on**.

`tb/system_tb.sv` used to work around this with a cross-module reference that
zeroed the counter before each case. The generated decoder clears it on reset,
the workaround is gone, and the sweep now runs 1920 decodes back to back with
nothing but `reset` between them — which is what demonstrates the fix.

### 2. The traceback block ran during reset

The `if (ready == 1)` block sat outside the `if (!reset) … else …`, so it was
evaluated on every clock edge including reset edges. It was harmless only
because the testbenches happened to hold `ready` low during reset; a design that
asserted `ready` early would have corrupted its output. It is now inside the
`else`, so reset genuinely means reset.

### 3. No zero-tail termination

The most consequential finding in the repo. The 7-bit block was not flushed with
`K-1 = 3` zero bits, so the trellis could not be forced back to state 0 and the
decoder had to minimise over all eight end states. The last two message bits
were decided by only one or two branch comparisons each:

* 1536/1792 single-bit errors corrected (85.7%), with **every** failure on
  codeword bits 0–3.
* Over AWGN the decoder was *worse than uncoded BPSK* at every Eb/N0 simulated —
  a rate-1/2 code spends 3 dB buying redundancy and never earned it back.

`rtl/decoder_term.sv` terminates the trellis. This does **not** change the code:
it is still (2,1,4), rate 1/2, the same generators, and `rtl/d_ff.sv` needed no
edit at all — terminating just means clocking three more zeros through the
encoder. Only the block framing changes, 7 → 14 becoming 7 → 20 bits.

Measured, not asserted: **2560/2560** single-bit errors corrected, at every one
of the 20 codeword positions, across all 128 messages. See
`docs/img/error_correction_compare.png`.

Be careful how far that is pushed, though. Terminating is worth 2.3 dB against
the unterminated decoder, but against *uncoded BPSK* it wins by only +0.05 dB at
BER = 1e-3, and below 6.41 dB it still loses. That is exactly what theory
predicts for a block this short: d_free = 6 and an effective rate of 7/20 give
an asymptotic hard-decision gain of 10 log10(0.35 * 6 / 2) = +0.21 dB. The
remaining problem is the block length, not the decoder - see
[architecture.md](architecture.md).

The unterminated `rtl/decoder.sv` is still built, still swept and still
documented, because it is what the original assignment produced and what the
published waveforms show.

### 4. Dead code

Lines 682–708 of the original are a commented-out duplicate of the traceback
`always` block; the reset loop initialising `h5` is duplicated while `h4` is
missing from that sequence (harmless — `h4` is zeroed elsewhere); and
`toggle_flag` is declared and never used. None of it survives into the generated
RTL, which is part of why the generated `decoder` is slightly smaller than the
hand-written one (1810 vs 1873 logic cells).

### 5. `getFinalLowestState()` in the C++ model returned a metric, not a state

`model/cpp/viterbi_2_1_4.cpp` had

```cpp
int lowestValue  = finalStates[0];
int lowest_state = lowestValue;      // should be 0
for (i = 0; i < 8; i++)
    if (finalStates[i] < lowestValue) { lowestValue = finalStates[i]; lowest_state = i; }
```

The loop uses a strict `<`, so when state 0 was the winner nothing ever assigned
`lowest_state` and the *path metric* was returned where a *state index* was
expected. This is invisible on an error-free word — the metric is 0 and so is
the state — which is exactly why the canonical demo printed the right answer and
the bug went unnoticed. With any channel error the traceback started from the
wrong end state:

| | corrected | agrees with the model |
|---|---|---|
| as written | 1312/1792 (73.2%) | 1632/1920 |
| fixed | 1536/1792 (85.7%) | 1920/1920 |

All 288 disagreements were cases where the true best end state was 0 and the
minimum metric was non-zero, which accounts for the failure completely. The RTL
never had this bug — it keeps `lowest_value` and `lowest_index` as separate
variables. `scripts/check_cpp.py` now runs the same exhaustive sweep against the
C++ model so this class of bug cannot return.

### 6. Two of the four models resolved add-compare-select ties the wrong way

Including `model/viterbi_ref.py`, which is the reference every other
implementation is checked against.

On a metric tie the RTL keeps the **higher**-numbered predecessor. That falls
out of the shape of the compare in `rtl/gen/decoder.sv.j2:132`: the low
predecessor wins only on a strict `<`, so a tie drops through to the `else`.
`model/ber_sweep.py:108` does the same thing (`take_lo = cand_lo < cand_hi`),
and `viterbi_ref.py`'s own docstring said the same thing.

| implementation | tie went to | correct |
|---|---|---|
| `rtl/gen/decoder.sv.j2` (both unrolled decoders) | high predecessor | yes |
| `model/ber_sweep.py` | high predecessor | yes |
| `model/viterbi_ref.py` | **low** predecessor | no |
| `model/cpp/viterbi_2_1_4.cpp` | **low** predecessor | no |

`viterbi_ref.py` looped over `(lo, hi)` seeding the best with `lo` and replaced
only on a strict `<`. The C++ had the same shape: `finalStates[]` is seeded
from the even-state transition and the odd one replaces it only on a strict
`<`. Both now keep the high predecessor, and `rtl/decoder_folded.sv` was
written against the corrected rule from the start.

It survived because **a single bit error never produces a tie**. The two rules
agree on all 4608 exhaustive single-error cases across both decoders, which is
every case any sweep in this repo ran. Ties start appearing at three errors:

| errors injected | decodes that differ between the two rules |
|---|---|
| 1 (all 4608 exhaustive cases) | 0 |
| 2 (4000 random) | 0 |
| 3 (4000 random) | 439 (11%) |
| 4 (4000 random) | 1597 (40%) |

Settled against the hardware rather than by argument: four three-error words
were run through `rtl/decoder_term.sv` in simulation and all four came back
with the high predecessor's answer. Those four words are now pinned in
`model/viterbi_ref.TIE_BREAK_WORDS` and checked three ways — by the model's
`--self-test`, by `scripts/check_cpp.py` against the C++ binary, and
implicitly by the RTL sweep below.

Three further regressions close the hole that let it hide:

* `system_folded_tb.sv` records 512 random three-error words that
  `scripts/check_rtl.py` compares against the model. The old model disagreed
  on 34 of them, so this alone would have caught it.
* `scripts/check_cpp.py` runs the four pinned words through the C++ model,
  which its 2688-case sweep could never distinguish.
* `ber_sweep.self_check` now runs at p = 0.25 as well as 0.08. At 0.08 alone
  the frames were too clean to produce a tie, which is why that check passed
  for so long while the two implementations disagreed.

No committed result moved: every sweep CSV and every BER curve was produced
either by the RTL or by `ber_sweep.py`, both of which were already right.

### 7. The block length was not the parameter the docs claimed

`docs/architecture.md` said the fix for the short block was "a longer block,
not different logic; the RTL is generated from a template and the block length
is a parameter". The first half is true. The second was not.

`scripts/gen_rtl.py` does derive every stage, branch metric and traceback entry
from `MSG_BITS` and the generators. But three widths in the template were
literals sized for a 7-bit block:

| declaration | ceiling | first breaks at |
|---|---|---|
| `getReturnPath(… bit [3:0] currentTable)` | 15 stages | **12** message bits |
| `logic [4:0] steps_n, stage_n` | 31 steps | ~27 message bits |
| `logic [4:0] finalStates[0:7]` | metric ≤ 31 | ~100 message bits |

Past those the decoder still compiles, still simulates and still reports no
warning — it just returns garbage. Measured: at 20 message bits the old widths
decoded **3/200** random single-error frames correctly. With the widths derived
from the stage count, **200/200**.

All three now come from `gen_rtl.widths()`, floored at the original values so
`rtl/decoder.sv` and `rtl/decoder_term.sv` regenerate byte-identically and every
published figure and synthesis number still stands. `scripts/check_long.py`
(`run_all.py long`) builds the generated decoder at 20 and 40 message bits and
checks every frame against the model, so this cannot regress silently again.

The claim came from `model/cpp/viterbi_2_1_4.cpp:8`, where it is true: that
file was refactored to build its stages in a loop over a
`vector<HammingTable>`, which does make its block length a parameter. In
software that refactor is free. In hardware the equivalent is not a refactor
but a different architecture, and the RTL never got it — so the claim was true
of the model and false of the design it was describing. See the translation
section in [architecture.md](architecture.md).

---

## Outstanding

### 8. The legacy testbenches race at time zero

`tb/legacy/decoder_tb.sv` and `tb/legacy/dff_tb.sv` drive the clock by hand with
non-blocking assignments (`clk <= ~clk`) from one `initial` block while another
does `clk <= 0`. At time 0 both are scheduled in the same NBA region, so the
result depends on scheduler ordering. It resolves benignly under Verilator and
did under ModelSim, but it is not portable.

Neither file has been touched — they are the benches the published waveforms
came from, and reproducing those exactly is the point. The benches in `tb/` are
race-free replacements with a proper `always #5 clk = ~clk` generator, and all
of them drive DUT inputs on `negedge` so they never race the DUT's blocking
assignments.

### 9. `decoder_tb.sv` has no `timescale` and no `$finish`

The flow supplies `--timescale 1ns/1ps` on the Verilator command line and the
simulation terminates by event exhaustion at 14 µs. The new benches declare
their own timescale and call `$finish`.

### 10. Blocking assignments in a sequential block

The decoder uses `=` throughout `always @(posedge clk)`. It simulates correctly
because everything lives in one block, and it synthesises, but it trips
Verilator's `BLKSEQ` style warning and is fragile to refactoring. Kept, because
the generated RTL deliberately mirrors the original's structure.

### 11. Width mismatches

`out[pinNumber]` indexes a 7-bit vector with a `byte`, and `set_outputs` takes a
`bit[3:0]` argument fed 3-bit actuals. Both are benign; the flow waives
`WIDTHTRUNC` and `WIDTHEXPAND` explicitly rather than globally, so any *new*
width warning still fails the build.

### 12. The end-state search sits on the clock's critical path

Earlier revisions of this document claimed the ceiling was `getReturnPath()`.
Reading the nextpnr timing report rather than guessing shows otherwise, so the
claim is corrected here.

In **both** variants the critical path starts at `data`, runs through a stage's
metric add-compare-select carry chains, and *ends at the `lowest_index`
register*. That is the eight-way minimum-over-end-states search being chained
combinationally onto the ACS logic inside a single clock edge — which happens
because the whole decoder is one `always` block using blocking assignments
(issue 10), so the search reads metrics computed earlier in the same edge.

| | hops on the critical path | logic | routing | total |
|---|---|---|---|---|
| `decoder` | 60 | 33.4 ns | 44.3 ns | 77.7 ns |
| `decoder_term` | 14 | 12.7 ns | 24.2 ns | 36.9 ns |

`decoder_term` sets `lowest_index = 0` outright, because a terminated trellis
knows where the survivor ends. Deleting the search takes the path from 60 hops
to 14 and roughly doubles Fmax, despite the design being 30% larger.

For the unterminated decoder the fix is to register the end-state search rather
than fold it into the same edge, costing one clock of latency. `getReturnPath()`
is on the terminated variant's path but is not what limits either design today.

Fmax varies by roughly ±0.5 MHz between placer seeds; the numbers above come
from `results/synth/*_nextpnr.log` at seed 1.

### 13. The unrolled decoders never normalise their path metrics

`finalStates` accumulates without bound, so the width has to be sized for the
worst case the block can produce — 2 per stage — rather than for the spread
that actually matters. `gen_rtl.widths()` now does exactly that, which is
correct but wasteful, and it is why the unrolled decoder's metric fields grow
with the block while `rtl/decoder_folded.sv` stays at 4 bits forever.

The textbook fix is to subtract the stage minimum, as the folded decoder does:
it cannot change any later comparison, because every metric moves by the same
amount. It is not retrofitted here because the unrolled decoders also encode
survivors by overwriting the losing branch metric with the sentinel `3`, and
normalising would have to leave that sentinel alone. That is a change to the
one mechanism every existing equivalence check depends on, for a design whose
block length is capped at ~17 message bits by area anyway (issue 7).

Measured, for reference: at a 10% channel error rate the largest final metric
is 6 at 10 stages, 10 at 23, 31 at 103.

### 14. `decoder_folded` does a whole trellis stage in one combinational path

Eight butterflies, the eight-way minimum over the new metrics, and the
normalising subtract all sit between two clock edges. That is why it has the
lowest Fmax of the three decoders (~11 MHz) despite being the smallest by a
factor of nearly four.

It still wins on throughput — 20 clocks against 80 for the same trellis, so
3.95 Mbit/s against 2.37 — so this is a headroom problem rather than a
regression. Two standard fixes, neither applied yet: put a pipeline register
between the add-compare-select and the normalisation, or drop the explicit
minimum-search in favour of modulo arithmetic, which bounds the metrics without
a reduction tree at all.
