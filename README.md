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
| Block | 7 message bits → 14 code bits, **no zero-tail flush** |
| Decision | hard |
| Latency | 45 trellis clocks + 8 traceback clocks |
| Device | 1873/5280 iCE40 UP5K logic cells (35%), ~13 MHz |

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
python scripts/run_all.py sim      # RTL simulation + self-checking benches
python scripts/run_all.py sweep    # exhaustive 1920-case correctness sweep
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

`rtl/decoder.sv` takes the whole 14-bit word in parallel and runs **one
add-compare-select butterfly per clock edge**, sequenced by `steps_n` (trellis
stage) and `stage_n` (state within the stage). Seven `HammingTable` structs
`h1…h7` hold the per-stage metrics. Instead of storing survivor pointers, the
loser of each compare has its branch-metric field overwritten with the sentinel
`3`, and traceback reads those sentinels back.

Full detail — including the tie-breaking rules, the 45-cycle schedule and the
critical path — is in **[docs/architecture.md](docs/architecture.md)**.
Before wiring anything up, read **[docs/bitorder.md](docs/bitorder.md)**.

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

`tb/system_tb.sv` drives the encoder into the decoder for **all 128 messages ×
15 channel conditions** (clean, plus every single-bit error position) and
self-checks each one. Every case is then compared against the independent
Python model.

```
SUMMARY  clean channel  : 128/128
SUMMARY  1-bit errors   : 1536/1792 (85.7%)
PASS  encoder: all 128 RTL codewords match model/viterbi_ref.encode()
PASS  decoder: RTL and model agree on all 1920 decode cases
```

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/error_correction_heatmap-dark.png">
    <img src="docs/img/error_correction_heatmap.png" alt="Error correction across the message space" width="880">
  </picture>
</p>

The 85.7% is not a decoder bug — the ACS and traceback logic are exactly
correct. Every failure lands on codeword bits 0–3, because the 7-bit block is
never flushed with `K-1 = 3` zero bits, so the last two message bits are decided
by only one or two branch comparisons each.

### Error-rate performance

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/ber_awgn-dark.png">
    <img src="docs/img/ber_awgn.png" alt="BER vs Eb/N0 over AWGN" width="880">
  </picture>
</p>

**The headline result is a negative one, and it is worth stating plainly: as
built, this decoder is worse than not coding at all.** A rate-1/2 code spends
3 dB of energy per information bit buying redundancy, and an unterminated 7-bit
block never earns it back. Adding a 3-bit zero tail moves the curve below
uncoded BPSK and is worth about **2.3 dB at BER = 1e-3**; soft decision buys
roughly another 2 dB on top.

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

| | |
|---|---|
| Front end | Yosys 0.67 `read_slang` (the built-in reader cannot parse this design) |
| Target | Lattice iCE40 UP5K, SG48 |
| Logic cells | 1873 / 5280 (35%) |
| I/O | 24 / 39 |
| Fmax | ~13 MHz |
| Critical path | ~57 ns, through the seven-deep `getReturnPath()` case tree |

The clock ceiling is entirely the combinational traceback tree evaluated in a
single edge. Pipelining it, or storing survivor pointers in a RAM instead of
recomputing them from sentinels, is the obvious next step.

---

## Repository map

```
rtl/                decoder.sv, d_ff.sv        the original RTL, unmodified
tb/
  decoder_bench.sv                             self-checking, plusarg-driven
  encoder_bench.sv                             all 128 messages -> CSV
  system_tb.sv                                 end-to-end 1920-case sweep
  legacy/                                      the 2022 testbenches, verbatim
model/
  viterbi_ref.py                               bit-accurate golden model
  ber_sweep.py                                 vectorised Monte-Carlo BER
  cpp/                                         the author's C++ reference + MSVC project
scripts/
  run_all.py                                   the only entry point you need
  vl.py                                        Verilator-in-Docker driver
  synth.py                                     Yosys + nextpnr + netlistsvg
  check_rtl.py                                 RTL vs model equivalence
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

The RTL is **left exactly as the original author wrote it**. The open-source
flow surfaced several genuine defects, which are documented rather than
silently patched — most importantly that `counter_for_path` is never cleared on
reset, so the design decodes exactly one word per power-on. See
**[docs/known-issues.md](docs/known-issues.md)** for the full list.

The two legacy testbenches are likewise preserved byte-for-byte, because they
are the benches the published waveforms came from; the new benches in `tb/` are
what regression actually runs.

One three-character change was made outside the RTL: `void main()` →
`int main()` in the C++ reference, which no compiler other than MSVC accepts.

---

## Why these tools

`rtl/decoder.sv` is built on **unpacked** structs containing unpacked arrays.
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
