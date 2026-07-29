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

---

## Outstanding

### 6. The legacy testbenches race at time zero

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

### 7. `decoder_tb.sv` has no `timescale` and no `$finish`

The flow supplies `--timescale 1ns/1ps` on the Verilator command line and the
simulation terminates by event exhaustion at 14 µs. The new benches declare
their own timescale and call `$finish`.

### 8. Blocking assignments in a sequential block

The decoder uses `=` throughout `always @(posedge clk)`. It simulates correctly
because everything lives in one block, and it synthesises, but it trips
Verilator's `BLKSEQ` style warning and is fragile to refactoring. Kept, because
the generated RTL deliberately mirrors the original's structure.

### 9. Width mismatches

`out[pinNumber]` indexes a 7-bit vector with a `byte`, and `set_outputs` takes a
`bit[3:0]` argument fed 3-bit actuals. Both are benign; the flow waives
`WIDTHTRUNC` and `WIDTHEXPAND` explicitly rather than globally, so any *new*
width warning still fails the build.

### 10. The end-state search sits on the clock's critical path

Earlier revisions of this document claimed the ceiling was `getReturnPath()`.
Reading the nextpnr timing report rather than guessing shows otherwise, so the
claim is corrected here.

In **both** variants the critical path starts at `data`, runs through a stage's
metric add-compare-select carry chains, and *ends at the `lowest_index`
register*. That is the eight-way minimum-over-end-states search being chained
combinationally onto the ACS logic inside a single clock edge — which happens
because the whole decoder is one `always` block using blocking assignments
(issue 8), so the search reads metrics computed earlier in the same edge.

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
