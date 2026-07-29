"""Open-source synthesis and place-and-route.

Yosys' built-in Verilog front end supports *packed* structs only, so it cannot
read rtl/decoder.sv at all.  The slang front end (`read_slang`, folded into
Yosys core at 0.67 and shipped in the OSS CAD Suite) handles the unpacked
structs this design is built on, and is what makes an all-open-source synthesis
flow possible here for the first time.

Outputs, all committed under results/synth/:
    decoder_yosys.log        full Yosys transcript
    decoder_ice40_stat.txt   cell counts after technology mapping
    decoder_nextpnr.log      utilisation, Fmax and the critical path
    synth_summary.json       the numbers the README quotes
    d_ff_netlist.json        encoder netlist for netlistsvg
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SYNTH_DIR = REPO / "results" / "synth"
IMG_DIR = REPO / "docs" / "img"

#: Small enough to be a credible, cheap target; big enough that the design fits.
DEVICE = {"family": "ice40", "part": "--up5k", "package": "sg48",
          "name": "Lattice iCE40 UP5K (SG48)", "luts": 5280}

#: Where the OSS CAD Suite usually lands.  It must live on a space-free path.
CANDIDATES = [
    Path(r"C:\oss\oss-cad-suite"),
    Path(r"C:\oss-cad-suite"),
    Path.home() / "oss-cad-suite",
    Path("/opt/oss-cad-suite"),
]


def oss_env() -> dict:
    """PATH/YOSYSHQ_ROOT for the OSS CAD Suite, if one can be found."""
    env = dict(os.environ)
    if shutil.which("yosys"):
        return env
    root = None
    if os.environ.get("OSS_CAD_SUITE"):
        root = Path(os.environ["OSS_CAD_SUITE"])
    else:
        root = next((c for c in CANDIDATES if (c / "bin").is_dir()), None)
    if root is None:
        raise SystemExit(
            "yosys not found.\n"
            "  Install the OSS CAD Suite to a path with no spaces (e.g. "
            "C:\\oss\\oss-cad-suite),\n"
            "  or set OSS_CAD_SUITE to point at it:\n"
            "    https://github.com/YosysHQ/oss-cad-suite-build/releases/latest")
    env["PATH"] = f"{root / 'bin'}{os.pathsep}{root / 'lib'}{os.pathsep}{env['PATH']}"
    env["YOSYSHQ_ROOT"] = str(root) + os.sep
    return env


def resolve(name: str, env: dict) -> str:
    """Absolute path to a tool.

    On Windows, subprocess resolves argv[0] against the *parent's* PATH, not
    the env passed in -- so the OSS CAD Suite additions above are invisible to
    it unless the binary is resolved here first.
    """
    found = shutil.which(name, path=env["PATH"])
    if not found:
        raise SystemExit(f"{name} not found in the OSS CAD Suite installation")
    return found


def run(argv: list[str], env: dict, log: Path | None = None,
        check: bool = True) -> str:
    argv = [resolve(argv[0], env), *argv[1:]]
    proc = subprocess.run(argv, cwd=REPO, env=env, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(proc.stdout, encoding="utf-8")
    if check and proc.returncode != 0:
        sys.stdout.write(proc.stdout[-4000:])
        raise SystemExit(f"failed ({proc.returncode}): {' '.join(argv[:3])} ...")
    return proc.stdout


# ---------------------------------------------------------------------------

def synth_encoder(env: dict) -> dict:
    """The encoder is plain Verilog-2001, so the built-in front end handles it."""
    SYNTH_DIR.mkdir(parents=True, exist_ok=True)
    script = (
        "read_verilog -sv rtl/d_ff.sv; "
        "hierarchy -check -top d_ff; "
        "prep -top d_ff; "
        "write_json results/synth/d_ff_netlist.json; "
        "synth_ice40 -top d_ff; "
        "tee -o results/synth/d_ff_ice40_stat.txt stat"
    )
    out = run(["yosys", "-p", script], env, SYNTH_DIR / "d_ff_yosys.log")
    return {"cells": _stat_cells(out)}


def synth_decoder(env: dict, top: str = "decoder", *, src: str | None = None,
                  label: str | None = None, msg_bits: int | None = None,
                  keep_stats: bool = True) -> dict:
    """Synthesise one decoder variant.

    `src` overrides the source path, which is how the block-length sweep feeds
    in the one-off decoders scripts/gen_rtl.py renders into sim/scratch/.
    `msg_bits` sets the module parameter, which only decoder_folded has -- the
    unrolled variants bake their length in at generation time, which is the
    whole difference being measured.
    """
    src = src or f"rtl/{top}.sv"
    label = label or top
    param = f"-G MSG_BITS={msg_bits} " if msg_bits is not None else ""
    # The sweep points pass keep_stats=False: fourteen more committed stat
    # files would bury the three that anyone actually reads, and their numbers
    # land in synth_summary.json anyway.
    generic = (f"tee -o results/synth/{label}_generic_stat.txt stat"
               if keep_stats else "stat")
    ice40 = (f"tee -o results/synth/{label}_ice40_stat.txt stat"
             if keep_stats else "stat")
    script = (
        f"read_slang --top {top} {param}{src}; "
        f"hierarchy -check -top {top}; "
        f"{generic}; "
        f"synth_ice40 -top {top} -json results/synth/{label}_ice40.json; "
        f"{ice40}"
    )
    out = run(["yosys", "-p", script], env, SYNTH_DIR / f"{label}_yosys.log")
    return {"cells": _stat_cells(out)}


#: The measurement the whole exercise is for.  The unrolled decoder puts every
#: trellis stage on the die, so its area is linear in the block length and it
#: runs off the end of the device; the folded one reuses eight add-compare-
#: select units and only its survivor memory grows.  Both decode the identical
#: trellis.  Yosys cell counts rather than full place-and-route, because the
#: long unrolled variants do not fit and nextpnr cannot report an area for a
#: design it cannot place.
BLOCK_SWEEP = [
    # architecture, message bits
    ("unrolled", 7),
    ("unrolled", 20),
    ("unrolled", 40),
    ("folded", 7),
    ("folded", 20),
    ("folded", 40),
    ("folded", 100),
]


def block_sweep(env: dict) -> list[dict]:
    """Area against block length, for both architectures."""
    sys.path.insert(0, str(REPO / "scripts"))
    import gen_rtl                                   # noqa: PLC0415

    scratch = REPO / "sim" / "scratch"
    scratch.mkdir(parents=True, exist_ok=True)
    rows = []

    for arch, n in BLOCK_SWEEP:
        stages = n + 3
        if arch == "folded":
            label = f"folded_m{n}"
            res = synth_decoder(env, "decoder_folded", label=label,
                                msg_bits=n, keep_stats=False)
        else:
            # The unrolled decoder has no parameter to set: a different block
            # length is a different 4000- or 8000-line source file.
            text, _ = gen_rtl.render("decoder_term", True, n)
            path = scratch / f"decoder_term_{n}.sv"
            path.write_text(text)
            label = f"unrolled_m{n}"
            res = synth_decoder(env, "decoder_term", label=label,
                                src=path.relative_to(REPO).as_posix(),
                                keep_stats=False)

        cells = res["cells"]
        lut = cells.get("SB_LUT4", 0)
        ff = sum(v for k, v in cells.items() if k.startswith("SB_DFF"))
        ram = sum(v for k, v in cells.items() if "RAM" in k)
        rows.append({"arch": arch, "msg_bits": n, "stages": stages,
                     "lut4": lut, "flops": ff, "ram": ram,
                     "fits_up5k": lut <= DEVICE["luts"]})
        fit = "" if lut <= DEVICE["luts"] else "   OVER DEVICE"
        print(f"    {arch:<8} {n:>3} msg bits  {stages:>3} stages  "
              f"LUT4 {lut:>5}  flops {ff:>4}{fit}")
    return rows


def _stat_cells(text: str) -> dict[str, int]:
    """Parse the last `stat` block's cell counts."""
    cells: dict[str, int] = {}
    for line in text.splitlines():
        m = re.match(r"\s+(\d+)\s+(SB_\w+|\$\w+)\s*$", line)
        if m:
            cells[m.group(2)] = int(m.group(1))
    return cells


def pnr(env: dict, top: str = "decoder") -> dict:
    log = SYNTH_DIR / f"{top}_nextpnr.log"
    out = run([f"nextpnr-{DEVICE['family']}", DEVICE["part"],
               "--package", DEVICE["package"],
               "--json", f"results/synth/{top}_ice40.json",
               "--asc", f"results/synth/{top}.asc",
               "--freq", "50", "--placer", "heap", "--seed", "1"],
              env, log, check=False)

    util, fmax, crit = {}, None, None
    for line in out.splitlines():
        m = re.search(r"^Info:\s+(\w+):\s+(\d+)/\s*(\d+)\s+(\d+)%", line)
        if m:
            util[m.group(1)] = {"used": int(m.group(2)),
                                "total": int(m.group(3)),
                                "percent": int(m.group(4))}
        m = re.search(r"Max frequency for clock.*?:\s*([\d.]+)\s*MHz", line)
        if m:
            fmax = float(m.group(1))
        m = re.search(r"Max delay .*posedge.*:\s*([\d.]+)\s*ns", line)
        if m and crit is None:
            crit = float(m.group(1))
    return {"device": DEVICE["name"], "utilisation": util,
            "fmax_mhz": fmax, "critical_path_ns": crit}


def schematic(env: dict) -> bool:
    """netlistsvg render of the encoder.  Optional -- needs Node."""
    if not shutil.which("npx"):
        print("  SKIP  netlistsvg needs Node.js on PATH")
        return False
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["npx", "-y", "netlistsvg", "results/synth/d_ff_netlist.json",
         "-o", "docs/img/encoder_schematic.svg"],
        cwd=REPO, env=env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=(os.name == "nt"))
    if proc.returncode != 0:
        print("  SKIP  netlistsvg failed:\n" + proc.stdout[-800:])
        return False
    print("  wrote docs/img/encoder_schematic.svg")
    return True


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--skip-pnr", action="store_true")
    p.add_argument("--skip-schematic", action="store_true")
    p.add_argument("--skip-sweep", action="store_true",
                   help="skip the area-against-block-length sweep")
    args = p.parse_args()

    env = oss_env()
    ver = run(["yosys", "-V"], env).strip().splitlines()[0]
    print(f"  {ver}")

    summary: dict = {"yosys": ver}

    print("  synthesising encoder (rtl/d_ff.sv, built-in front end) ...")
    summary["encoder"] = synth_encoder(env)

    # The two unrolled variants come off the same template, so synthesising
    # both is what puts a number on what termination costs in area and Fmax.
    # decoder_folded joins them at the same 7 message bits / 10 stages, which
    # is the head-to-head: same trellis, same decoded bits, other architecture.
    for top in ("decoder", "decoder_term", "decoder_folded"):
        print(f"  synthesising {top} (rtl/{top}.sv, read_slang front end) ...")
        summary[top] = synth_decoder(env, top)
        cells = summary[top]["cells"]
        print(f"    SB_LUT4 {cells.get('SB_LUT4', 0)}, "
              f"SB_CARRY {cells.get('SB_CARRY', 0)}, "
              f"flops {sum(v for k, v in cells.items() if k.startswith('SB_DFF'))}")

        if not args.skip_pnr:
            print(f"    place & route on {DEVICE['name']} ...")
            summary[top]["pnr"] = pnr(env, top)
            lc = summary[top]["pnr"]["utilisation"].get("ICESTORM_LC", {})
            print(f"      {lc.get('used')}/{lc.get('total')} logic cells "
                  f"({lc.get('percent')}%),  "
                  f"Fmax {summary[top]['pnr']['fmax_mhz']} MHz")

    if not args.skip_sweep:
        print("  area against block length (yosys cell counts) ...")
        summary["block_sweep"] = block_sweep(env)

    if not args.skip_schematic:
        summary["schematic"] = schematic(env)

    out = SYNTH_DIR / "synth_summary.json"
    out.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"  wrote results/synth/{out.name}")


if __name__ == "__main__":
    main()
