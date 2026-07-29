# Toolchain

The project was originally simulated and synthesised under an Aldec student
licence, with waveforms captured from ModelSim. This document records what
replaced it and, more usefully, what does *not* work — the design uses one
SystemVerilog construct that rules out much of the open-source ecosystem.

## The constraint that drives everything

`rtl/decoder.sv` declares **unpacked** `typedef struct`s whose members are
themselves unpacked arrays:

```systemverilog
typedef struct {
  logic [4:0] finalStates[0:7];
} FinalHammingDistance;

typedef struct {
  bit         recievedSequence[0:1];
  bit [4:0]   aTransition[0:1];
  ...
  FinalHammingDistance hammingDistances;
} HammingTable;
```

These cannot be made `packed` — a packed struct may not contain unpacked array
members — so this is not a one-keyword fix.

| Tool | Handles it? | Notes |
|---|---|---|
| **Verilator 5.050** | yes | unpacked structs supported since ~5.006 |
| **Yosys `read_slang`** | yes | slang front end, in Yosys core since 0.67 |
| Yosys `read_verilog -sv` | **no** | packed structs only |
| Icarus Verilog 13 | **no** | hard parse error, upstream issue #266 open since 2019 |

Icarus is therefore usable for `rtl/d_ff.sv` (plain Verilog-2001) but not for
the decoder.

## Simulation — Verilator in Docker

Verilator has no reliable native-Windows build: the OSS CAD Suite Windows
package ships a Perl wrapper that will not run from `cmd.exe`, and `--build`
fails at link (oss-cad-suite-build issues #142 and #173). Upstream supports
Windows only through Cygwin/MinGW/WSL2. So the flow runs Verilator in a pinned
container and everything goes through `scripts/vl.py`:

```
verilator/verilator:v5.050
  --binary --timing --trace-vcd --timescale 1ns/1ps
  -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-TIMESCALEMOD
```

* `--binary` = `--main --exe --build --timing`, so one command produces a
  runnable executable.
* `--timing` is mandatory: the testbenches are driven by `#` delays. It needs a
  C++20 coroutine-capable compiler, which the image has.
* `--timescale` is mandatory because `decoder.sv` and `decoder_tb.sv` carry no
  `timescale` while `dff_tb.sv` declares one.
* The three waivers are listed individually, not as `-Wno-fatal`, so a *new*
  warning still breaks the build.
* `scripts/vl.py` falls back to a native `verilator` when one is on PATH, so the
  same scripts work unchanged on Linux/WSL2.

**A bonus that mattered.** The legacy testbenches call `$dumpvars(1)`, which
under most simulators dumps only the top level — which is why the original
project never had visibility into the decoder. Verilator dumps the full
hierarchy anyway, so all 288 signals including `h1..h7.hammingDistances.finalStates[0:7]`
land in the VCD. `docs/img/decoder_metrics.png` is a direct consequence.

## Synthesis — Yosys + nextpnr, native

Install the [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases/latest)
to a path **with no spaces** (the suite requires it). `scripts/synth.py` looks
for `C:\oss\oss-cad-suite`, `C:\oss-cad-suite`, `~/oss-cad-suite`,
`/opt/oss-cad-suite`, or whatever `OSS_CAD_SUITE` points at, and puts its `bin`
and `lib` on PATH itself — you do not have to dot-source `environment.ps1`
first.

```
yosys -p "read_slang --top decoder rtl/decoder.sv;
          synth_ice40 -top decoder -json results/synth/decoder_ice40.json"
nextpnr-ice40 --up5k --package sg48 --freq 50 ...
```

The encoder goes through the built-in `read_verilog -sv` instead, since it needs
nothing special, and its netlist is rendered by `netlistsvg` (needs Node.js;
skipped automatically if absent).

On Windows, `subprocess` resolves argv[0] against the *parent's* PATH rather
than the environment handed to the child, so `scripts/synth.py` resolves each
tool to an absolute path before launching it.

## RTL generation - Jinja2

`rtl/decoder.sv` and `rtl/decoder_term.sv` are generated from
`rtl/gen/decoder.sv.j2` by `scripts/gen_rtl.py`. The template needs nothing but
`jinja2`; there is no HDL generator framework involved.

    pip install jinja2
    python scripts/run_all.py gen           # regenerate
    python scripts/run_all.py gen --check   # fail if the checked-in RTL drifted

The generator derives every branch's expected output pair from the generator
polynomials rather than transcribing it, so the seven-stage and ten-stage
decoders cannot disagree by typo. Correctness is not taken on faith: the
generated seven-stage decoder is held to the same 1920-case equivalence check
against `model/viterbi_ref.py` that the hand-written original passes.

Field widths come from `gen_rtl.widths()` rather than being literals, so a
longer block widens `steps_n`, the path metrics and `getReturnPath`'s table
index as it needs to. They are floored at the original values, which is what
keeps the two checked-in decoders byte-identical to what was published.

    python scripts/gen_rtl.py --msg-bits 20 --out sim/scratch/d20.sv
    python scripts/run_all.py long          # build and check 20 and 40 bits

`rtl/decoder_folded.sv` is *not* generated. It is a folded architecture with
one add-compare-select array reused per stage, so it needs no per-stage code —
`MSG_BITS` is an ordinary module parameter. Yosys takes it via slang:

    yosys -p "read_slang --top decoder_folded -G MSG_BITS=20 rtl/decoder_folded.sv; ..."

and Verilator via `-GMSG_BITS=20`, which is how `tb/decoder_gen_tb.sv` drives
one bench across several block lengths.

## Plotting

`vcdvcd` reads the VCDs; matplotlib draws everything. Verilator writes vector
names with a trailing bit range (`tb.dut.q[3:0]`), which the resolver in
`scripts/plot_waves.py` strips before matching.

## Versions this was built and verified against

| Tool | Version |
|---|---|
| Verilator | 5.050 (`verilator/verilator:v5.050`) |
| Yosys | 0.67+102 |
| nextpnr-ice40 | OSS CAD Suite 2026-07-28 |
| Python | 3.12 |
| numpy / matplotlib / vcdvcd | 2.4 / 3.10 / 2.6 |
| jinja2 | 3.1 |
| Node (netlistsvg, optional) | 24 |
