# Known issues and design quirks

Everything here was found by the open-source flow. The RTL is deliberately left
as the original author wrote it — these are documented, not patched.

## 1. `counter_for_path` is never reset

`rtl/decoder.sv` resets `steps_n`, `stage_n`, `table_counter` and `pinOut` in
its `if (!reset)` branch, but not `counter_for_path`, which drives the traceback
state machine. A single decode works because the 2-state `byte` starts at 0, but
**a second decode in the same simulation begins with a stale counter of 8** and
emits nothing.

* Impact: the design decodes exactly one word per power-on. Any real use, and
  the exhaustive sweep, needs it cleared.
* Workaround in use: `tb/system_tb.sv` zeroes it through a cross-module
  reference before each decode, with a comment pointing here.
* Fix: add `counter_for_path = 0;` to the reset branch.

## 2. The traceback block runs during reset

The `if (ready == 1)` block sits outside the `if (!reset) … else …`, so it is
evaluated on every clock edge including reset edges. It is harmless only
because the testbenches hold `ready` low during reset. A design that asserted
`ready` early would corrupt the output.

## 3. No zero-tail termination

The 7-bit block is not flushed with `K-1 = 3` zero bits, so the trellis cannot
be forced back to state 0 and the decoder minimises over all eight end states.
The last two message bits are consequently under-protected:

* 1536/1792 single-bit errors corrected (85.7%); every failure is on codeword
  bits 0–3.
* Over AWGN the as-built decoder is worse than uncoded BPSK at every Eb/N0
  simulated; terminating the trellis is worth ~2.3 dB at BER = 1e-3.

This is the most consequential finding in the repo and is quantified in
`docs/img/ber_awgn.png` and `docs/img/error_correction_heatmap.png`.

## 4. The legacy testbenches race at time zero

`tb/legacy/decoder_tb.sv` and `tb/legacy/dff_tb.sv` drive the clock by hand with
non-blocking assignments (`clk <= ~clk`) from one `initial` block while another
`initial` block does `clk <= 0`. At time 0 both are scheduled in the same NBA
region, so the resulting value depends on scheduler ordering. It resolves
benignly under Verilator and did under ModelSim, but it is not portable.

Neither file has been touched — they are the testbenches the published
waveforms came from, and reproducing those exactly is the point. `tb/decoder_bench.sv`
is the race-free replacement used for regression, with a proper
`always #5 clk = ~clk` generator.

## 5. `decoder_tb.sv` has no `timescale` and no `$finish`

The flow supplies `--timescale 1ns/1ps` on the Verilator command line, and the
simulation terminates by event exhaustion at 14 µs. The new benches declare
their own timescale and call `$finish` explicitly.

## 6. Blocking assignments in a sequential block

`rtl/decoder.sv` uses `=` throughout `always @(posedge clk)`. It simulates
correctly because everything lives in one block, and it synthesises, but it
trips Verilator's `BLKSEQ` style warning and is fragile to refactoring.

## 7. Width mismatches

`out[pinNumber]` indexes a 7-bit vector with a `byte`, and `set_outputs` takes
a `bit[3:0]` argument fed 3-bit actuals. Both are benign; the flow waives
`WIDTHTRUNC` and `WIDTHEXPAND` explicitly rather than globally, so any *new*
width warning still fails the build.

## 8. Dead code

Lines 682–708 of `rtl/decoder.sv` are a commented-out duplicate of the traceback
`always` block, and the reset loop initialising `h5` is duplicated while `h4` is
missing from that particular sequence (harmless — `h4` is zeroed elsewhere).
