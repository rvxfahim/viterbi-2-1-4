"""Monte-Carlo bit-error-rate study of the (2,1,4) code.

The RTL decodes one 14-bit word per ~53 clocks, so a statistically meaningful
BER curve is far out of reach for an HDL simulator: the points below need
tens of millions of decoded frames.  This module therefore reimplements the
*same* trellis as ``model/viterbi_ref.py`` -- and is checked against it -- but
vectorised over frames with NumPy, which makes the whole sweep a few seconds.

Channels
--------
BSC    independent bit flips with probability p; uncoded BER is p by definition.
AWGN   BPSK over additive white Gaussian noise.  Code bit c maps to x = 1-2c,
       y = x + n with n ~ N(0, N0/2), Es = 1.  For a rate-R code at a given
       Eb/N0, Es/N0 = R * Eb/N0, so coding must overcome an initial penalty
       before it pays off -- which is exactly why the curves cross.

Variants
--------
rtl        7-bit block, no zero-tail flush, hard decision.  This is what
           rtl/decoder.sv actually implements.
terminated 7 message bits + 3 zero flush bits (rate 7/20), hard decision.
           Shows the coding gain the design leaves on the table by not
           terminating the trellis.
soft       7-bit block, unquantised soft decision.  Shows the ~2 dB the
           hard-decision front end costs.
"""

from __future__ import annotations

import argparse
import csv
import math
import os
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from model import viterbi_ref as ref  # noqa: E402

BER_DIR = REPO / "results" / "ber"
N_STATES = ref.N_STATES
MSG_BITS = ref.MSG_BITS
TAIL_BITS = 3           # K - 1 flush bits for the terminated variant

#: For each state s: (pred_lo, pred_hi, out1_lo, out0_lo, out1_hi, out0_hi)
#: where the branch from pred carries input bit s >> 2.
_TABLE = []
for _s in range(N_STATES):
    _lo, _hi = ref.predecessors(_s)
    _bit = _s >> 2
    _o1l, _o0l = ref.branch_outputs(_lo, _bit)
    _o1h, _o0h = ref.branch_outputs(_hi, _bit)
    _TABLE.append((_lo, _hi, _o1l, _o0l, _o1h, _o0h))

_BIG = np.int32(1 << 14)


def _encode_frames(msgs: np.ndarray, n_bits: int) -> np.ndarray:
    """Encode an (F, n_bits) uint8 array into (F, 2*n_bits) code bits."""
    n_frames = msgs.shape[0]
    code = np.empty((n_frames, 2 * n_bits), dtype=np.uint8)
    state = np.zeros(n_frames, dtype=np.uint8)
    for k in range(n_bits):
        bit = msgs[:, k]
        s2 = (state >> 2) & 1
        s1 = (state >> 1) & 1
        s0 = state & 1
        code[:, 2 * k] = bit ^ s2 ^ s1 ^ s0        # g1 = 1111
        code[:, 2 * k + 1] = bit ^ s2 ^ s0         # g0 = 1011
        state = ((bit << 2) | (state >> 1)) & 0b111
    return code


def _viterbi_frames(rx: np.ndarray, n_bits: int, *, soft: bool,
                    terminated: bool) -> np.ndarray:
    """Decode an (F, 2*n_bits) array. `rx` is uint8 for hard, float for soft.

    Returns an (F, n_bits) uint8 array of decoded input bits.
    """
    n_frames = rx.shape[0]
    dtype = np.float32 if soft else np.int32
    big = np.float32(1e9) if soft else _BIG

    metrics = np.full((n_frames, N_STATES), big, dtype=dtype)
    metrics[:, 0] = 0                                   # start state is known
    survivors = np.empty((n_bits, n_frames, N_STATES), dtype=np.uint8)

    for k in range(n_bits):
        r1 = rx[:, 2 * k]
        r0 = rx[:, 2 * k + 1]
        new = np.empty_like(metrics)
        for s in range(N_STATES):
            lo, hi, o1l, o0l, o1h, o0h = _TABLE[s]
            if soft:
                # metric contribution is -y when the branch bit is 0, +y when 1
                bl = (r1 if o1l else -r1) + (r0 if o0l else -r0)
                bh = (r1 if o1h else -r1) + (r0 if o0h else -r0)
            else:
                bl = (r1 ^ o1l) + (r0 ^ o0l)
                bh = (r1 ^ o1h) + (r0 ^ o0h)
            cand_lo = metrics[:, lo] + bl
            cand_hi = metrics[:, hi] + bh
            # strict `<` matches the RTL: the higher predecessor wins ties
            take_lo = cand_lo < cand_hi
            new[:, s] = np.where(take_lo, cand_lo, cand_hi)
            survivors[k, :, s] = np.where(take_lo, lo, hi)
        metrics = new

    if terminated:
        state = np.zeros(n_frames, dtype=np.uint8)
    else:
        # lowest metric, lowest index on a tie -- np.argmin already does this
        state = metrics.argmin(axis=1).astype(np.uint8)

    bits = np.empty((n_frames, n_bits), dtype=np.uint8)
    idx = np.arange(n_frames)
    for k in range(n_bits - 1, -1, -1):
        bits[:, k] = state >> 2
        state = survivors[k, idx, state]
    return bits


# ---------------------------------------------------------------------------
# Channel simulations
# ---------------------------------------------------------------------------

def _terminated(msg_bits: int, soft: bool = False) -> tuple:
    """A zero-tail-terminated variant of any length.

    The tail is always K - 1 = 3 bits however long the block is, so the rate
    is msg / (2 * (msg + 3)) and the overhead shrinks as the block grows:
    30% at 7 message bits, 13% at 20, 2.9% at 100.  Nothing else changes --
    same generators, same 8 states, same trellis.
    """
    stages = msg_bits + TAIL_BITS
    return (msg_bits, stages, True, soft, msg_bits / (2 * stages))


VARIANTS = {
    #  name             msg_bits  n_bits (stages)  terminated  soft   rate
    "rtl":             (MSG_BITS, MSG_BITS,        False,      False, 0.5),
    "soft":            (MSG_BITS, MSG_BITS,        False,      True,  0.5),
    "terminated":      _terminated(MSG_BITS),        # 7 msg bits, rate 7/20
    # The long blocks the README quotes.  These were asymptotic formulas
    # (10 log10(R * d_free / 2) = +1.15 and +1.63 dB) until the width
    # constants in rtl/gen/decoder.sv.j2 were made to derive from the stage
    # count; now they are simulated points on the same curve as the rest.
    "terminated20":    _terminated(20),              # rate 20/46  = 0.435
    "terminated100":   _terminated(100),             # rate 100/206 = 0.485
}


def _msgs(rng: np.random.Generator, n_frames: int, msg_bits: int,
          n_bits: int) -> np.ndarray:
    msgs = np.zeros((n_frames, n_bits), dtype=np.uint8)
    msgs[:, :msg_bits] = rng.integers(0, 2, (n_frames, msg_bits), dtype=np.uint8)
    return msgs                      # tail bits stay zero for the flush


def _msg_bits(variant: str) -> int:
    """Information bits per frame -- the denominator of every BER here."""
    return MSG_BITS if variant == "uncoded" else VARIANTS[variant][0]


def _run_batch(variant: str, channel: str, level: float, n_frames: int,
               rng: np.random.Generator) -> tuple[int, int]:
    if variant == "uncoded":
        # Simulated (not analytic) uncoded BPSK -- this is what validates the
        # channel model: it must land on the Q(sqrt(2*Eb/N0)) line.
        bits = rng.integers(0, 2, (n_frames, MSG_BITS), dtype=np.uint8)
        if channel == "bsc":
            hat = bits ^ (rng.random(bits.shape) < level)
        else:
            ebno = 10.0 ** (level / 10.0)
            sigma = math.sqrt(1.0 / (2.0 * ebno))
            y = (1.0 - 2.0 * bits) + rng.normal(0.0, sigma, bits.shape)
            hat = (y < 0).astype(np.uint8)
        return int(np.count_nonzero(hat ^ bits)), n_frames * MSG_BITS

    msg_bits, n_bits, terminated, soft, rate = VARIANTS[variant]
    msgs = _msgs(rng, n_frames, msg_bits, n_bits)
    code = _encode_frames(msgs, n_bits)

    if channel == "bsc":
        flips = rng.random(code.shape) < level
        rx = (code ^ flips).astype(np.uint8)
    else:                                              # awgn
        ebno = 10.0 ** (level / 10.0)
        esno = rate * ebno
        sigma = math.sqrt(1.0 / (2.0 * esno))
        x = 1.0 - 2.0 * code.astype(np.float32)
        y = x + rng.normal(0.0, sigma, code.shape).astype(np.float32)
        rx = y if soft else (y < 0).astype(np.uint8)

    hat = _viterbi_frames(rx, n_bits, soft=soft, terminated=terminated)
    errors = int(np.count_nonzero(hat[:, :msg_bits] ^ msgs[:, :msg_bits]))
    return errors, n_frames * msg_bits


def measure(variant: str, channel: str, level: float, *, max_frames: int,
            target_errors: int = 300, batch: int = 20_000,
            seed: int = 0) -> float:
    """Adaptive Monte-Carlo: keep running batches until enough errors."""
    rng = np.random.default_rng(seed)
    # Long variants carry more information bits per frame, so the same frame
    # budget buys many more bits and the adaptive stop fires far sooner.
    mb = _msg_bits(variant)
    errors = bits = 0
    while bits < max_frames * mb and errors < target_errors:
        n = min(batch, max_frames - bits // mb)
        if n <= 0:
            break
        e, b = _run_batch(variant, channel, level, n, rng)
        errors += e
        bits += b
    return errors / bits if bits else float("nan")


def qfunc(x: float) -> float:
    return 0.5 * math.erfc(x / math.sqrt(2.0))


# ---------------------------------------------------------------------------
# Sweeps
# ---------------------------------------------------------------------------

def sweep_bsc(max_frames: int) -> list[dict]:
    """BSC sweep.  Soft decision is omitted: it is undefined on a hard channel."""
    rows = []
    levels = np.logspace(math.log10(2e-3), math.log10(0.35), 16)
    for i, p in enumerate(levels):
        row = {"p": float(p), "uncoded_theory": float(p)}
        for variant in ("uncoded", "rtl", "terminated"):
            row[variant] = measure(variant, "bsc", float(p),
                                   max_frames=max_frames, seed=1000 + i)
        rows.append(row)
        print(f"  BSC  p={p:9.5f}   uncoded={row['uncoded']:.3e}  "
              f"rtl={row['rtl']:.3e}  term={row['terminated']:.3e}")
    return rows


def sweep_awgn(max_frames: int) -> list[dict]:
    rows = []
    levels = np.arange(0.0, 10.5, 0.5)
    for i, ebno_db in enumerate(levels):
        ebno = 10.0 ** (ebno_db / 10.0)
        row = {"ebno_db": float(ebno_db),
               "uncoded_theory": qfunc(math.sqrt(2.0 * ebno))}
        for variant in ("uncoded", "rtl", "terminated", "terminated20",
                        "terminated100", "soft"):
            row[variant] = measure(variant, "awgn", float(ebno_db),
                                   max_frames=max_frames, seed=2000 + i)
        rows.append(row)
        print(f"  AWGN Eb/N0={ebno_db:4.1f} dB  "
              f"uncoded={row['uncoded']:.3e} (theory {row['uncoded_theory']:.3e})  "
              f"rtl={row['rtl']:.3e}  term={row['terminated']:.3e}  "
              f"t20={row['terminated20']:.3e}  t100={row['terminated100']:.3e}  "
              f"soft={row['soft']:.3e}")
    return rows


def _write(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {path.relative_to(REPO)}")


def self_check() -> None:
    """The vectorised decoder must agree with the scalar reference."""
    rng = np.random.default_rng(7)
    msgs = rng.integers(0, 2, (256, MSG_BITS), dtype=np.uint8)
    code = _encode_frames(msgs, MSG_BITS)
    # Two noise levels deliberately.  At 0.08 the frames almost never carry
    # enough errors to force an ACS tie, so this check passed for a long time
    # while the two implementations disagreed on how to resolve one; 0.25
    # produces ties in bulk.  See docs/known-issues.md #6.
    for p in (0.08, 0.25):
        noisy = code ^ (rng.random(code.shape) < p)
        hat = _viterbi_frames(noisy.astype(np.uint8), MSG_BITS,
                              soft=False, terminated=False)
        for i in range(256):
            word = int("".join(str(b) for b in noisy[i].astype(int)), 2)
            want = ref.decode_bits([int(b) for b in noisy[i]])
            got = [int(b) for b in hat[i]]
            if got != want:
                raise SystemExit(
                    f"vectorised decoder disagrees with viterbi_ref at p={p} "
                    f"on frame {i}: rx={word:014b} got={got} want={want}")
    # and the encoder
    for i in range(256):
        want = ref.encode_bits([int(b) for b in msgs[i]])
        got = [int(b) for b in code[i]]
        if got != want:
            raise SystemExit(f"vectorised encoder disagrees on frame {i}")
    print("  PASS  vectorised engine matches model/viterbi_ref.py "
          "(2 x 256 frames at p = 0.08 and 0.25, encode + decode)")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--trials", type=int, default=200_000,
                   help="max frames per point (adaptive stop at 300 errors)")
    p.add_argument("--jobs", type=int, default=0, help="unused; NumPy is already vectorised")
    p.add_argument("--self-check-only", action="store_true")
    args = p.parse_args()

    # NumPy already saturates a core per batch; extra processes mostly add
    # pickling overhead at these frame counts.
    os.environ.setdefault("OMP_NUM_THREADS", "1")

    self_check()
    if args.self_check_only:
        return

    print(f"\n  max {args.trials} frames per point, adaptive stop at 300 bit errors\n")
    _write(BER_DIR / "ber_bsc.csv", sweep_bsc(args.trials))
    print()
    _write(BER_DIR / "ber_awgn.csv", sweep_awgn(args.trials))


if __name__ == "__main__":
    main()
