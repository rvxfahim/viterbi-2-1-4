# Viterbi (2, 1, 4) — convolutional encoder and decoder in SystemVerilog

A rate-1/2, constraint-length-4 convolutional encoder and a hard-decision
Viterbi decoder, written in SystemVerilog and now built, simulated, verified,
synthesised and plotted with **an entirely open-source toolchain** — no vendor
licence anywhere in the flow.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/trellis-dark.png">
    <img src="docs/img/trellis.png" alt="The 8-state trellis with one channel error corrected" width="820">
  </picture>
</p>

```
  message ──► encoder ──► channel ──► decoder ──► message
   7 bits     d_ff.sv     BSC/AWGN   decoder.sv    7 bits
                 │                        │
            14-bit codeword         45 + 8 clocks
```

| | |
|---|---|
| Rate | 1/2 |
| Constraint length K | 4 (3 memory elements, 8 states) |
| Generators | g1 = `1111` (17₈), g0 = `1011` (13₈) |
| Decision | hard |

Two decoders are built from one template, differing only in block framing —
same code, same generators, byte-identical encoder:

| | `decoder` | `decoder_term` |
|---|---|---|
| Block | 7 bits → 14 code bits | 7 bits + 3 zero tail → 20 code bits |
| Effective rate | 0.50 | 0.35 |
| Latency | 45 + 8 clocks | 69 + 11 clocks |
| **Single-bit errors corrected** | 1536/1792 (85.7%) | **2560/2560 (100%)** |
| iCE40 UP5K | 1810/5280 cells (34%), ~13 MHz | 2356/5280 cells (44%), ~27 MHz |

`decoder` is the original assignment's framing and the one the published
waveforms show; `decoder_term` is what the code should have been framed as.

---

## Quickstart

You need **Docker** and **Python 3.10+**. Everything else is optional.

```bash
git clone https://github.com/rvxfahim/viterbi-2-1-4
cd viterbi-2-1-4
pip install numpy matplotlib vcdvcd

python scripts/run_all.py env      # what's available
python scripts/run_all.py all      # simulate, verify, sweep, plot
```

`all` ends with every figure in `docs/img/` and every dataset in `results/`.
Individual stages:

```bash
python scripts/run_all.py gen      # regenerate the RTL from its Jinja template
python scripts/run_all.py model    # Python golden model self-test
python scripts/run_all.py cpp      # C++ reference model vs the golden model
python scripts/run_all.py sim      # RTL simulation + self-checking benches
python scripts/run_all.py sweep    # exhaustive correctness sweeps, both variants
python scripts/run_all.py ber      # Monte-Carlo BER study
python scripts/run_all.py synth    # Yosys + nextpnr   (needs OSS CAD Suite)
python scripts/run_all.py plots    # regenerate all figures
```

Synthesis additionally needs the
[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases/latest)
installed to a path with no spaces; the script finds it automatically.

---

## How it works

### The encoder

Four-tap shift register; the two parities are taken from the post-shift
register. With the pre-shift state written `s = (q0, q1, q2)`:

```
out1 = d ^ s2 ^ s1 ^ s0        // g1 = 1111
out0 = d ^ s2 ^ s0             // g0 = 1011
next = (d << 2) | (s >> 1)
```

<p align="center">
  <img src="docs/img/encoder_schematic.svg" alt="Encoder netlist" width="700">
</p>

### The decoder

The decoder takes the whole received word in parallel and runs **one
add-compare-select butterfly per clock edge**, sequenced by `steps_n` (trellis
stage) and `stage_n` (state within the stage). One `HammingTable` struct per
stage holds the metrics. Instead of storing survivor pointers, the loser of each
compare has its branch-metric field overwritten with the sentinel `3`, and
traceback reads those sentinels back.

**The RTL is generated.** `rtl/decoder.sv` and `rtl/decoder_term.sv` both come
from `rtl/gen/decoder.sv.j2` via `scripts/gen_rtl.py`. The original was written
out by hand — 1317 lines for seven stages — and extending that to ten by hand
meant ~600 more lines of near-identical ladder with a mistyped `high`/`low`
waiting in it. The template derives every branch's expected output pair from the
generator polynomials instead. Edit the template, not the `.sv` files;
`run_all.py gen --check` fails if they have drifted.

That the template *reproduces* the hand-written decoder rather than merely
resembling it is not taken on faith: the generated seven-stage decoder passes
the same 1920-case equivalence check against the Python model that the original
does, and `rtl/legacy/decoder.sv` is kept so the two can be diffed.

Full detail — tie-breaking rules, the cycle schedule, the critical path — is in
**[docs/architecture.md](docs/architecture.md)**. Before wiring anything up,
read **[docs/bitorder.md](docs/bitorder.md)**.

---

## Results

### Waveforms

Regenerated from real Verilator VCDs, replacing the 2022 ModelSim screenshots.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/encoder_waveform-dark.png">
    <img src="docs/img/encoder_waveform.png" alt="Encoder waveform" width="880">
  </picture>
  <br><br>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/decoder_waveform_clean-dark.png">
    <img src="docs/img/decoder_waveform_clean.png" alt="Decoder waveform, clean codeword" width="880">
  </picture>
  <br><br>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/decoder_waveform_error-dark.png">
    <img src="docs/img/decoder_waveform_error.png" alt="Decoder waveform with a channel error" width="880">
  </picture>
</p>

### Inside the decoder

The original flow could never show this. Both legacy testbenches call
`$dumpvars(1)`, which dumps only top-level signals — but Verilator dumps the
whole hierarchy regardless, so all 288 signals including
`h1..h7.hammingDistances.finalStates[0:7]` reach the VCD. Below is the path
metric of every state at every trellis stage, read straight out of the RTL,
with the surviving path from the Python model overlaid.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/decoder_metrics-dark.png">
    <img src="docs/img/decoder_metrics.png" alt="Path metrics per trellis stage" width="840">
  </picture>
</p>

### Correctness

Both decoders are driven end to end from the encoder, for **every message ×
every single-bit error position**, and every case is cross-checked against the
independent Python model. 4608 decodes in total, and the terminated variant is
held to an absolute standard rather than merely to agreement:

```
decoder      -- 128 messages x 15 channels  (14-bit, unterminated)
    SUMMARY  clean channel  : 128/128
    SUMMARY  1-bit errors   : 1536/1792 (85.7%)
decoder_term -- 128 messages x 21 channels  (20-bit, terminated)
    SUMMARY  clean channel  : 128/128
    SUMMARY  1-bit errors   : 2560/2560 (100.0%)

PASS  encoder: all 128 RTL codewords match model/viterbi_ref.encode()
PASS  decoder: RTL and model agree on all 1920 decode cases
PASS  decoder_term: RTL and model agree on all 2688 decode cases
PASS  decoder_term: every single-bit error in all 2688 cases corrected
```

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/error_correction_compare-dark.png">
    <img src="docs/img/error_correction_compare.png" alt="Single-bit error correction, terminated vs not" width="880">
  </picture>
</p>

The 85.7% was never a decoder bug — the ACS and traceback logic are exactly
correct. Every failure lands on codeword bits 0–3, because the 7-bit block is
not flushed with `K-1 = 3` zero bits, so the last two message bits are decided
by only one or two branch comparisons each. Clocking three zeros in after the
message pins the survivor's end state, and a (2,1,4) code with free distance 6
then corrects **every** single error, anywhere in the block.

Note what did *not* change to get there: the encoder. `rtl/d_ff.sv` is
byte-identical between the two flows — terminating is something the transmitter
does, not the encoder.

### Error-rate performance

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/ber_awgn-dark.png">
    <img src="docs/img/ber_awgn.png" alt="BER vs Eb/N0 over AWGN" width="880">
  </picture>
</p>

**As originally framed, this decoder is worse than not coding at all.** A
rate-1/2 code spends 3 dB of energy per information bit buying redundancy, and
an unterminated 7-bit block never earns it back. The 3-bit zero tail that
`decoder_term` adds moves the curve below uncoded BPSK and is worth about
**2.3 dB at BER = 1e-3**; soft decision would buy roughly another 2 dB on top,
though the RTL is hard-decision only.

On a binary symmetric channel, where no rate penalty applies, the picture is
friendlier — the decoder helps below p ≈ 0.088:

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/ber_bsc-dark.png">
    <img src="docs/img/ber_bsc.png" alt="BER over a binary symmetric channel" width="880">
  </picture>
</p>

Curves come from `model/ber_sweep.py`, a NumPy-vectorised re-implementation of
the same trellis, validated frame-by-frame against `model/viterbi_ref.py`. The
simulated uncoded curve sits on the analytic `Q(√(2Eb/N0))` line across four
decades, which is what validates the channel model before any coding claim is
made.

### Synthesis

Yosys 0.67 `read_slang` (the built-in Verilog reader cannot parse this design)
plus nextpnr-ice40, targeting a Lattice iCE40 UP5K in SG48:

| | `decoder` | `decoder_term` |
|---|---|---|
| Logic cells | 1810 / 5280 (34%) | 2356 / 5280 (44%) |
| LUT4 / carry / flops | 1338 / 511 / 497 | 1936 / 799 / 703 |
| Fmax | ~13 MHz | ~27 MHz |
| Critical path | 77.7 ns | 36.9 ns |

The terminated decoder being 30% larger is expected — three more trellis stages.
Its being **twice as fast** is less obvious: the unterminated variant carries an
eight-way minimum search over the final path metrics, evaluated combinationally
inside one clock edge, which the terminated variant does not need because its
end state is known. Fmax moves by roughly ±0.5 MHz between placer seeds.

Either way the ceiling is combinational depth in a single edge. Storing survivor
pointers in a RAM instead of recomputing them from sentinels, or pipelining
`getReturnPath()`, is the obvious next step.

---

## Repository map

```
rtl/
  d_ff.sv                                      the encoder, unmodified
  decoder.sv  decoder_term.sv                  GENERATED -- do not edit
  gen/decoder.sv.j2                            the template they come from
  legacy/decoder.sv                            the 2022 hand-written decoder
tb/
  decoder_bench.sv                             self-checking, plusarg-driven
  encoder_bench.sv                             all 128 messages -> CSV
  system_tb.sv                                 end-to-end 1920-case sweep
  system_term_tb.sv                            terminated, 2688-case sweep
  legacy/                                      the 2022 testbenches, verbatim
model/
  viterbi_ref.py                               bit-accurate golden model
  ber_sweep.py                                 vectorised Monte-Carlo BER
  cpp/                                         the author's C++ reference, file-driven
scripts/
  run_all.py                                   the only entry point you need
  gen_rtl.py                                   renders the RTL from the template
  vl.py                                        Verilator-in-Docker driver
  synth.py                                     Yosys + nextpnr + netlistsvg
  check_rtl.py  check_cpp.py                   RTL / C++ vs model equivalence
  plot_waves.py, plot_ber.py, plot_trellis.py  figures
  vizstyle.py                                  shared light/dark plot theme
docs/
  architecture.md  bitorder.md                 how it works
  known-issues.md  toolchain.md                what to watch out for
  img/                                         generated figures
  legacy/                                      original PDFs, slides, truth table
results/            vcd/  synth/  ber/         generated data
```

---

## Design notes

The open-source flow surfaced four real defects. Three are fixed, one was fatal
to the design's whole premise, and the original code is preserved so every one
of them can still be reproduced:

* **`counter_for_path` was never cleared on reset**, so the decoder worked
  exactly once per power-on. The sweep used to zero it through a cross-module
  reference; it now runs 1920 decodes back to back with nothing but `reset`
  between them, which is what proves the fix.
* **The traceback block ran during reset** — harmless only because the
  testbenches happened to hold `ready` low.
* **No zero-tail termination**, which is why the design lost to uncoded BPSK.
  `decoder_term` fixes it and corrects every single-bit error.
* **The C++ model returned a path metric where a state index belonged**, in
  `getFinalLowestState()`. Invisible on an error-free word — metric 0, state 0 —
  which is exactly why the canonical demo printed the right answer for years.
  It cost 12.5 points of correction rate. The RTL never had this bug.

Everything is measured against `model/viterbi_ref.py` rather than asserted, and
the full write-up is in **[docs/known-issues.md](docs/known-issues.md)**.

`rtl/legacy/decoder.sv` is the 2022 hand-written decoder, kept verbatim so the
generated version can be diffed against it. The two legacy testbenches are
preserved byte-for-byte too, because they are the benches the published
waveforms came from; the benches in `tb/` are what regression actually runs.

---

## Why these tools

The decoder is built on **unpacked** structs containing unpacked arrays.
They cannot be made `packed`, and that single fact decides the toolchain:
Verilator and Yosys' slang front end handle them, while Icarus Verilog and
Yosys' built-in Verilog reader reject them outright. Verilator additionally has
no working native-Windows build, so it runs in a pinned container.

The full reasoning, exact command lines and version matrix are in
**[docs/toolchain.md](docs/toolchain.md)**.

---

## Credits and licence

Original design, C++ reference model and presentation by
[@rvxfahim](https://github.com/rvxfahim). Licensed under **GPL-3.0** — see
[LICENSE](LICENSE).

References:

* A. J. Viterbi, *Error bounds for convolutional codes and an asymptotically
  optimum decoding algorithm*, IEEE Trans. Inf. Theory, 1967.
* S. Lin and D. J. Costello, *Error Control Coding*, 2nd ed., Pearson, 2004.
