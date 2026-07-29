"""Run the folded decoder at long block lengths, and over a real channel.

Two gaps this closes.

1. `rtl/decoder_folded.sv` was verified exhaustively at 7 message bits
   (`tb/system_folded_tb.sv`, 3200 cases) and synthesised at 20, 40 and 100 --
   but never *simulated* past 7.  Its bit-exactness with `rtl/decoder_term.sv`
   is a claim about the tie-break rule and the metric normalisation, and the
   normalisation is precisely the part that only starts working hard once the
   block is long.  So: decode random frames through the real folded RTL at
   several lengths and compare every one against
   `model/viterbi_ref.decode_terminated`.

2. The long-block coding gain the README quotes (+1.15 dB at 20 message bits,
   +1.63 at 100) came from `model/ber_sweep.py`, not from RTL.  The folded
   decoder is the reason those lengths fit on the device at all, so the curve
   ought to be measured on it.

   The bench runs a binary symmetric channel, and that is not an
   approximation: hard-decision BPSK over AWGN *is* a BSC with

       p = Q(sqrt(2 * R * Eb/N0))

   because `ber_sweep._run_batch` draws sigma = sqrt(1/(2*R*Eb/N0)) around
   x = +/-1 and then thresholds at zero.  So the RTL is driven at exactly the
   crossover its Eb/N0 point implies, and the resulting BER is comparable
   like for like against the model's AWGN curve and against uncoded BPSK.

    python scripts/run_all.py folded
    python scripts/run_all.py folded --lengths 20 100 --ebno 4 5 6
"""

from __future__ import annotations

import argparse
import csv
import math
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "scripts"))

import vl  # noqa: E402

from model import ber_sweep  # noqa: E402
from model import viterbi_ref as ref  # noqa: E402

BER_DIR = REPO / "results" / "ber"
GREEN, RED, DIM, RESET = "\033[32m", "\033[31m", "\033[2m", "\033[0m"

TAIL_BITS = 3

#: 20 and 40 mirror scripts/check_long.py so the folded and unrolled decoders
#: are checked at the same lengths; 100 is the length the README's +1.63 dB
#: figure refers to, and the one the unrolled decoder cannot reach on a UP5K.
DEFAULT_LENGTHS = (20, 40, 100)

#: Where the coded and uncoded curves actually cross and separate.  Below 4 dB
#: the terminated code is still losing; by 7 dB a 100-bit block needs more
#: frames than an HDL simulator wants to spend.
DEFAULT_EBNO = (4.0, 5.0, 6.0, 7.0)

TOP = "decoder_folded_gen_tb"
SOURCES = ["rtl/decoder_folded.sv", "rtl/d_ff.sv", "tb/decoder_folded_gen_tb.sv"]


def rate(msg_bits: int) -> float:
    return msg_bits / (2.0 * (msg_bits + TAIL_BITS))


def bsc_p(msg_bits: int, ebno_db: float) -> float:
    """Crossover probability of the hard-decision AWGN channel at this point."""
    ebno = 10.0 ** (ebno_db / 10.0)
    return ber_sweep.qfunc(math.sqrt(2.0 * rate(msg_bits) * ebno))


def build(msg_bits: int) -> None:
    vl.build(TOP, SOURCES, extra=[f"-GMSG_BITS={msg_bits}"], quiet=True)


def simulate(msg_bits: int, *, frames: int, errors: int = 1, ppm: int = 0,
             grid: Path | None = None, seed: int | None = None) -> dict:
    """One bench run; returns the aggregate row it wrote."""
    BER_DIR.mkdir(parents=True, exist_ok=True)
    agg = BER_DIR / f"rtl_folded_run_{msg_bits}.csv"

    plusargs = {"MSGCSV": f"results/ber/{agg.name}",
                "FRAMES": str(frames), "ERRORS": str(errors), "PPM": str(ppm)}
    if grid is not None:
        plusargs["GRID"] = f"results/ber/{grid.name}"
    if seed is not None:
        plusargs["SEED"] = str(seed)

    proc = vl.run(TOP, plusargs=plusargs, quiet=True, check=False)
    if proc.returncode != 0:
        sys.stdout.write(proc.stdout)
        raise SystemExit(f"{TOP} failed at MSG_BITS={msg_bits}")

    with agg.open(newline="") as fh:
        row = next(csv.DictReader(fh))
    agg.unlink()                       # per-run scratch, not a result
    return {k: int(v) for k, v in row.items()}


# ---------------------------------------------------------------------------
# 1. Long-block equivalence against the golden model
# ---------------------------------------------------------------------------

def check_equivalence(msg_bits: int, frames: int, errors: int) -> int:
    grid = BER_DIR / f"rtl_folded_long_{msg_bits}.csv"
    build(msg_bits)
    simulate(msg_bits, frames=frames, errors=errors, grid=grid)

    mismatches = corrected = total = 0
    with grid.open(newline="") as fh:
        for row in csv.DictReader(fh):
            total += 1
            got = int(row["decoded"], 2)
            if got != ref.decode_terminated(int(row["received"], 2), msg_bits):
                mismatches += 1
            if got == int(row["message"], 2):
                corrected += 1

    stages = msg_bits + TAIL_BITS
    if mismatches:
        print(f"  {RED}FAIL{RESET}  folded, {msg_bits} message bits: "
              f"{mismatches}/{total} frames disagree with model/viterbi_ref.py")
        return 1
    print(f"  {GREEN}PASS{RESET}  folded, {msg_bits} message bits ({stages} stages, "
          f"{2 * stages} clocks): RTL and model agree on all {total} frames, "
          f"{corrected}/{total} single-error frames corrected")
    return 0


# ---------------------------------------------------------------------------
# 2. BER over a channel, on the RTL itself
# ---------------------------------------------------------------------------

def measure_ber(msg_bits: int, ebno_points, frames: int) -> list[dict]:
    build(msg_bits)
    r = rate(msg_bits)

    # Register a matching model variant so the comparison runs the *same*
    # block length through model/ber_sweep.py's vectorised trellis.
    variant = f"folded{msg_bits}"
    ber_sweep.VARIANTS[variant] = ber_sweep._terminated(msg_bits)

    rows = []
    for i, ebno_db in enumerate(ebno_points):
        p = bsc_p(msg_bits, ebno_db)
        ppm = max(1, round(p * 1e6))
        agg = simulate(msg_bits, frames=frames, ppm=ppm, seed=3000 + i)

        rtl_ber = agg["bit_errors"] / agg["total_bits"]
        model_ber = ber_sweep.measure(variant, "bsc", ppm / 1e6,
                                      max_frames=200_000, target_errors=500,
                                      seed=3000 + i)
        uncoded = ber_sweep.qfunc(math.sqrt(2.0 * 10.0 ** (ebno_db / 10.0)))

        rows.append({"msg_bits": msg_bits, "ebno_db": ebno_db, "rate": round(r, 4),
                     "p": p, "frames": agg["frames"],
                     "bit_errors": agg["bit_errors"],
                     "total_bits": agg["total_bits"],
                     "rtl_ber": rtl_ber, "model_ber": model_ber,
                     "uncoded_theory": uncoded})
        print(f"  {msg_bits:3d} bits  Eb/N0={ebno_db:4.1f} dB  p={p:.4f}  "
              f"RTL={rtl_ber:.3e} ({agg['bit_errors']}/{agg['total_bits']})  "
              f"model={model_ber:.3e}  uncoded={uncoded:.3e}")
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--lengths", type=int, nargs="+", default=list(DEFAULT_LENGTHS),
                    metavar="N", help="message-bit counts to check")
    ap.add_argument("--frames", type=int, default=200,
                    help="random frames per equivalence run (default 200)")
    ap.add_argument("--errors", type=int, default=1,
                    help="bit errors injected per equivalence frame (default 1)")
    ap.add_argument("--ebno", type=float, nargs="+", default=list(DEFAULT_EBNO),
                    metavar="DB", help="Eb/N0 points for the BER run")
    ap.add_argument("--ber-frames", type=int, default=20_000,
                    help="frames per BER point (default 20000)")
    ap.add_argument("--ber-lengths", type=int, nargs="+", default=[7, 100],
                    metavar="N", help="block lengths to measure BER at")
    ap.add_argument("--skip-ber", action="store_true")
    args = ap.parse_args()

    print("Folded decoder at longer block lengths, vs the golden model")
    rc = sum(check_equivalence(n, args.frames, args.errors) for n in args.lengths)
    if rc:
        raise SystemExit(rc)

    if args.skip_ber:
        return

    print("\nFolded decoder BER, measured on the RTL over a BSC at the "
          "crossover each Eb/N0 implies")
    rows = []
    for n in args.ber_lengths:
        rows += measure_ber(n, args.ebno, args.ber_frames)

    out = BER_DIR / "rtl_folded_ber.csv"
    with out.open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {out.relative_to(REPO)}")


if __name__ == "__main__":
    main()
