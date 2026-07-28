"""Orchestrator for the open-source Viterbi (2,1,4) flow.

`make` is not part of the toolchain here: it is absent on stock Windows, and
quoting Makefile paths through a Docker volume mount is miserable.  Python 3
is needed anyway (golden model, BER sweep, plotting), so it is the single
entry point.

    python scripts/run_all.py all            # everything
    python scripts/run_all.py env            # capability probe
    python scripts/run_all.py sim            # RTL simulation + self-checks
    python scripts/run_all.py sweep          # exhaustive RTL correctness sweep
    python scripts/run_all.py ber            # Monte-Carlo BER study
    python scripts/run_all.py synth          # Yosys / nextpnr
    python scripts/run_all.py plots          # regenerate every figure
    python scripts/run_all.py clean
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
sys.path.insert(0, str(REPO))

import vl  # noqa: E402

VCD_DIR = REPO / "results" / "vcd"
SYNTH_DIR = REPO / "results" / "synth"
BER_DIR = REPO / "results" / "ber"
IMG_DIR = REPO / "docs" / "img"

RTL_DECODER = ["rtl/decoder.sv"]
RTL_ENCODER = ["rtl/d_ff.sv"]
RTL_BOTH = ["rtl/decoder.sv", "rtl/d_ff.sv"]

GREEN, RED, YELLOW, DIM, RESET = (
    "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m",
)


def _hdr(text: str) -> None:
    print(f"\n{'=' * 72}\n  {text}\n{'=' * 72}")


def _ok(text: str) -> None:
    print(f"  {GREEN}PASS{RESET}  {text}")


def _warn(text: str) -> None:
    print(f"  {YELLOW}SKIP{RESET}  {text}")


def _py(script: str, *args: str) -> None:
    # flush first: our prints are buffered, the child's are not, so without
    # this the section headers appear after the output they introduce
    sys.stdout.flush()
    subprocess.run([sys.executable, str(REPO / script), *args], check=True, cwd=REPO)
    sys.stdout.flush()


# ---------------------------------------------------------------------------
# env
# ---------------------------------------------------------------------------

def cmd_env(_args) -> None:
    _hdr("Environment")
    rows = []

    try:
        rows.append(("verilator", vl.backend(), True))
    except vl.VerilatorError:
        rows.append(("verilator", "MISSING (need Docker or native verilator)", False))

    rows.append(("docker", shutil.which("docker") or "not found",
                 bool(shutil.which("docker"))))

    # The OSS CAD Suite is usually not on PATH; scripts/synth.py finds it, so
    # probe through the same path it uses rather than reporting a false miss.
    import synth
    try:
        oss = synth.oss_env()
        oss_where = "on PATH" if shutil.which("yosys") else "auto-detected"
    except SystemExit:
        oss, oss_where = None, None
    for tool in ("yosys", "nextpnr-ice40", "iverilog", "gtkwave"):
        path = shutil.which(tool, path=oss["PATH"]) if oss else shutil.which(tool)
        rows.append((tool, f"{path} ({oss_where})" if path and oss_where
                     else (path or "not found — optional, synthesis only"),
                     bool(path)))

    rows.append(("npx", shutil.which("npx") or "not found — optional, schematic only",
                 bool(shutil.which("npx"))))

    rows.append(("python", sys.version.split()[0], True))
    for mod in ("numpy", "matplotlib", "vcdvcd"):
        try:
            __import__(mod)
            rows.append((mod, "ok", True))
        except ImportError:
            rows.append((mod, f"MISSING -- pip install {mod}", mod == "vcdvcd"))

    width = max(len(r[0]) for r in rows)
    for name, detail, ok in rows:
        mark = f"{GREEN}o{RESET}" if ok else f"{RED}x{RESET}"
        print(f"  {mark} {name:<{width}}  {DIM}{detail}{RESET}")

    print(f"\n  Simulation needs: Verilator (Docker is fine) + numpy/matplotlib/vcdvcd")
    print(f"  Synthesis needs : Yosys >= 0.67 (OSS CAD Suite) -- optional")


# ---------------------------------------------------------------------------
# sim
# ---------------------------------------------------------------------------

def cmd_sim(args) -> None:
    _hdr("RTL simulation (Verilator)")
    VCD_DIR.mkdir(parents=True, exist_ok=True)
    only = args.only

    if only in (None, "legacy"):
        # The legacy benches hardcode $dumpfile("dump.vcd"), so the working
        # directory is the only lever for placing their output.
        for top, srcs, name in [
            ("decoder_tb", RTL_DECODER + ["tb/legacy/decoder_tb.sv"], "decoder_legacy"),
            ("dff_tb", RTL_ENCODER + ["tb/legacy/dff_tb.sv"], "encoder_legacy"),
        ]:
            vl.build(top, srcs)
            vl.run(top, cwd_rel=f"results/vcd/_{top}", quiet=True)
            src = VCD_DIR / f"_{top}" / "dump.vcd"
            src.replace(VCD_DIR / f"{name}.vcd")
            shutil.rmtree(VCD_DIR / f"_{top}", ignore_errors=True)
            _ok(f"legacy {top}  ->  results/vcd/{name}.vcd")

    if only in (None, "decoder_bench"):
        vl.build("decoder_bench", RTL_DECODER + ["tb/decoder_bench.sv"])
        # Clean codeword, then the same codeword with dat[6] flipped -- the
        # single-error case the original project was built to demonstrate.
        for label, dat in [("clean", "11110111010111"), ("error", "11110110010111")]:
            proc = vl.run(
                "decoder_bench",
                plusargs={"DAT": dat, "EXP": "1011000",
                          "VCD": f"results/vcd/decoder_bench_{label}.vcd"},
                quiet=True, check=False,
            )
            if "PASS" not in proc.stdout or proc.returncode != 0:
                sys.stdout.write(proc.stdout)
                raise SystemExit(f"decoder_bench {label} FAILED")
            _ok(f"decoder_bench {label:<5}  dat={dat}  out=1011000")

    if only in (None, "encoder_bench"):
        vl.build("encoder_bench", RTL_ENCODER + ["tb/encoder_bench.sv"])
        proc = vl.run("encoder_bench",
                      plusargs={"VCD": "results/vcd/encoder_bench.vcd"},
                      quiet=True, check=False)
        if proc.returncode != 0 or "FAIL" in proc.stdout:
            sys.stdout.write(proc.stdout)
            raise SystemExit("encoder_bench FAILED")
        for line in proc.stdout.splitlines():
            if line.startswith("PASS") or line.startswith("SUMMARY"):
                _ok(line)


# ---------------------------------------------------------------------------
# sweep
# ---------------------------------------------------------------------------

def cmd_sweep(args) -> None:
    _hdr("Exhaustive RTL correctness sweep (128 messages x 15 channels)")
    VCD_DIR.mkdir(parents=True, exist_ok=True)
    vl.build("system_tb", RTL_BOTH + ["tb/system_tb.sv"])
    t0 = time.time()
    proc = vl.run("system_tb",
                  plusargs={"VCD": "results/vcd/system_tb.vcd",
                            "CSV": "results/ber/rtl_sweep.csv"},
                  quiet=True, check=False)
    sys.stdout.write("\n".join(
        l for l in proc.stdout.splitlines()
        if l.startswith(("SUMMARY", "FAIL", "RESULT"))
    ) + "\n")
    print(f"  {DIM}elapsed {time.time() - t0:.1f}s{RESET}")
    if proc.returncode != 0:
        raise SystemExit("system_tb FAILED")
    _py("scripts/check_rtl.py")


# ---------------------------------------------------------------------------
# model / ber / plots / synth
# ---------------------------------------------------------------------------

def cmd_model(_args) -> None:
    _hdr("Python golden model self-test")
    _py("model/viterbi_ref.py", "--self-test")


def cmd_ber(args) -> None:
    _hdr("Monte-Carlo BER study")
    BER_DIR.mkdir(parents=True, exist_ok=True)
    _py("model/ber_sweep.py", "--trials", str(args.trials), "--jobs", str(args.jobs))


def cmd_synth(args) -> None:
    _hdr("Synthesis (Yosys / nextpnr)")
    # synth.py locates an OSS CAD Suite that is not on PATH, so ask it rather
    # than checking PATH here and wrongly reporting the tool as missing.
    import synth
    try:
        synth.oss_env()
    except SystemExit:
        _warn("yosys not found -- install the OSS CAD Suite to a space-free "
              "path (e.g. C:\\oss\\oss-cad-suite) or set OSS_CAD_SUITE")
        return
    _py("scripts/synth.py", *(["--skip-pnr"] if args.skip_pnr else []))


def cmd_plots(_args) -> None:
    _hdr("Figures")
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    _py("scripts/plot_waves.py")
    _py("scripts/plot_trellis.py")
    if (BER_DIR / "ber_awgn.csv").exists():
        _py("scripts/plot_ber.py")
    else:
        _warn("no BER data yet -- run `python scripts/run_all.py ber` first")


def cmd_clean(_args) -> None:
    for path in [REPO / "sim" / "build", VCD_DIR]:
        shutil.rmtree(path, ignore_errors=True)
        print(f"  removed {path.relative_to(REPO)}")


def cmd_all(args) -> None:
    cmd_env(args)
    cmd_model(args)
    cmd_sim(args)
    cmd_sweep(args)
    cmd_ber(args)
    cmd_synth(args)
    cmd_plots(args)
    _hdr("Done -- see results/ and docs/img/")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("env").set_defaults(func=cmd_env)
    sub.add_parser("model").set_defaults(func=cmd_model)

    s = sub.add_parser("sim")
    s.add_argument("--only", choices=["legacy", "decoder_bench", "encoder_bench"])
    s.set_defaults(func=cmd_sim)

    sub.add_parser("sweep").set_defaults(func=cmd_sweep)

    b = sub.add_parser("ber")
    b.add_argument("--trials", type=int, default=200_000)
    b.add_argument("--jobs", type=int, default=0, help="0 = all cores")
    b.set_defaults(func=cmd_ber)

    y = sub.add_parser("synth")
    y.add_argument("--skip-pnr", action="store_true")
    y.set_defaults(func=cmd_synth)

    sub.add_parser("plots").set_defaults(func=cmd_plots)
    sub.add_parser("clean").set_defaults(func=cmd_clean)

    a = sub.add_parser("all")
    a.add_argument("--trials", type=int, default=200_000)
    a.add_argument("--jobs", type=int, default=0)
    a.add_argument("--skip-pnr", action="store_true")
    a.add_argument("--only", default=None)
    a.set_defaults(func=cmd_all)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
