"""Prove the generated decoder still decodes when the block gets longer.

`docs/architecture.md` used to claim the block length was already a parameter.
It was not: three widths in `rtl/gen/decoder.sv.j2` were sized for a 7-bit
block and truncated silently past it.  The worst was `getReturnPath`'s
`input bit [3:0] currentTable`, which at 20 message bits wrapped a
`table_counter` of 23 round to 7 and made traceback read the wrong stage.

That was a decoder that compiled, simulated, reported no warning and produced
garbage.  So this check is a negative-control regression: build the generated
decoder at several block lengths, decode random frames through the real RTL,
and compare every one against `model/viterbi_ref.decode_terminated`.

    python scripts/run_all.py long
    python scripts/run_all.py long --frames 500 --lengths 20 40 100

Measured when the widths were fixed: at 20 message bits the old widths decoded
3/200 frames correctly, the derived widths 200/200.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "scripts"))

import gen_rtl  # noqa: E402
import vl  # noqa: E402

from model import viterbi_ref as ref  # noqa: E402

SCRATCH = REPO / "sim" / "scratch"
BER_DIR = REPO / "results" / "ber"
GREEN, RED, DIM, RESET = "\033[32m", "\033[31m", "\033[2m", "\033[0m"

#: 20 is the first length the old `bit [3:0] currentTable` could not reach;
#: 40 is past the old `[4:0] steps_n` as well.  Both stay small enough that a
#: 4000-line generated decoder still verilates quickly.
DEFAULT_LENGTHS = (20, 40)


def check_one(msg_bits: int, frames: int, errors: int) -> int:
    SCRATCH.mkdir(parents=True, exist_ok=True)
    BER_DIR.mkdir(parents=True, exist_ok=True)

    text, ctx = gen_rtl.render("decoder_term", True, msg_bits)
    src = SCRATCH / f"decoder_term_{msg_bits}.sv"
    src.write_text(text)
    print(f"  {DIM}rendered {src.relative_to(REPO)}: {ctx['stages']} stages, "
          f"widths table={ctx['table_w']} step={ctx['step_w']} "
          f"metric={ctx['metric_w']}, {len(text.splitlines())} lines{RESET}")

    csv_path = BER_DIR / f"rtl_long_{msg_bits}.csv"
    vl.build("decoder_gen_tb",
             [src.relative_to(REPO).as_posix(), "rtl/d_ff.sv", "tb/decoder_gen_tb.sv"],
             extra=[f"-GMSG_BITS={msg_bits}"], quiet=True)
    proc = vl.run("decoder_gen_tb",
                  plusargs={"CSV": f"results/ber/{csv_path.name}",
                            "FRAMES": str(frames), "ERRORS": str(errors)},
                  quiet=True, check=False)
    if proc.returncode != 0:
        sys.stdout.write(proc.stdout)
        raise SystemExit(f"decoder_gen_tb failed at MSG_BITS={msg_bits}")

    mismatches = corrected = total = 0
    with csv_path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            total += 1
            rx = int(row["received"], 2)
            got = int(row["decoded"], 2)
            if got != ref.decode_terminated(rx, msg_bits):
                mismatches += 1
            if got == int(row["message"], 2):
                corrected += 1

    if mismatches:
        print(f"  {RED}FAIL{RESET}  {msg_bits} message bits: {mismatches}/{total} "
              f"frames disagree with model/viterbi_ref.py")
        return 1
    print(f"  {GREEN}PASS{RESET}  {msg_bits} message bits ({ctx['stages']} stages): "
          f"RTL and model agree on all {total} frames, "
          f"{corrected}/{total} single-error frames corrected")
    return 0


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--lengths", type=int, nargs="+", default=list(DEFAULT_LENGTHS),
                    metavar="N", help="message-bit counts to build and check")
    ap.add_argument("--frames", type=int, default=200,
                    help="random frames per length (default 200)")
    ap.add_argument("--errors", type=int, default=1,
                    help="bit errors injected per frame (default 1)")
    args = ap.parse_args()

    print("Generated decoder at longer block lengths, vs the golden model")
    rc = sum(check_one(n, args.frames, args.errors) for n in args.lengths)
    if rc:
        raise SystemExit(rc)


if __name__ == "__main__":
    main()
