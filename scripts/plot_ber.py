"""BER curves from results/ber/*.csv.

Two figures, each rendered light and dark:

  ber_awgn  -- BER vs Eb/N0 over AWGN.  The headline result, because it shows
               the design's real weakness: the 7-bit block is not zero-tail
               terminated, so the as-built decoder is *worse* than uncoded BPSK.
               Terminating the trellis recovers the coding gain.
  ber_bsc   -- BER vs BSC crossover probability, where the rate penalty does
               not enter and the coding gain is visible directly.
"""

from __future__ import annotations

import csv
import math
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

import vizstyle as vs  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

BER_DIR = REPO / "results" / "ber"
FLOOR = 1e-6                     # default plot floor; zero-error points sit here


def _read(path: Path) -> dict[str, np.ndarray]:
    with path.open(newline="") as fh:
        rows = list(csv.DictReader(fh))
    return {k: np.array([float(r[k]) for r in rows]) for k in rows[0]}


def _clip(y: np.ndarray, floor: float = FLOOR) -> np.ndarray:
    return np.where(y <= 0, floor, y)


def _label_end(ax, x, y, text, color, theme, dy=0.0, side="right"):
    """Direct label at one end of a series (the light-mode relief rule).

    Labels go wherever the curves are *separated*: the right end on the AWGN
    chart, the left end on the BSC chart where the three converge on the right.
    """
    dx = 6 if side == "right" else -6
    ax.annotate(text, xy=(x, y), xytext=(dx, dy), textcoords="offset points",
                color=color, fontsize=9, fontweight="600", va="center",
                ha="left" if side == "right" else "right", clip_on=False)


# ---------------------------------------------------------------------------

SERIES_AWGN = [
    #  key           legend label                   short label   slot
    ("uncoded",    "Uncoded BPSK",                  "uncoded",     0),
    ("rtl",        "decoder (no tail flush)",       "decoder",     1),
    ("terminated", "decoder_term (zero-tail)",      "term",        2),
    ("soft",       "Soft decision (no tail flush)", "soft",        3),
]


def _crossing(x, y, target):
    """Interpolate, in log-BER, the x where series y passes `target`."""
    yy = np.log10(_clip(y))
    t = math.log10(target)
    for i in range(len(yy) - 1):
        if (yy[i] - t) * (yy[i + 1] - t) <= 0 and yy[i] != yy[i + 1]:
            f = (t - yy[i]) / (yy[i + 1] - yy[i])
            return x[i] + f * (x[i + 1] - x[i])
    return None


def draw_awgn(theme):
    d = _read(BER_DIR / "ber_awgn.csv")
    x = d["ebno_db"]

    fig, ax = plt.subplots(figsize=(8.6, 5.6))

    # Analytic reference behind the simulated points.  That the simulated
    # uncoded curve sits on it is what validates the channel model; it goes in
    # the legend rather than inline, where it would land on top of the curves.
    ax.plot(x, _clip(d["uncoded_theory"]), color=theme["muted"],
            lw=1.0, ls=(0, (4, 3)), zorder=1,
            label="Uncoded, analytic  Q(√(2Eb/N0))")

    for key, label, short, slot in SERIES_AWGN:
        ax.plot(x, _clip(d[key]), color=theme["series"][slot],
                marker=vs.MARKERS[slot], markersize=4.5, label=label,
                markeredgecolor=theme["surface"], markeredgewidth=0.8,
                zorder=3)

    # Direct labels (relief rule) -- short text, nudged apart vertically.
    for (key, _label, short, slot), dy in zip(SERIES_AWGN, (9, 0, -12, 6)):
        _label_end(ax, x[-1], _clip(d[key])[-1], short,
                   theme["series"][slot], theme, dy)

    ax.set_yscale("log")
    ax.set_xlabel("Eb/N0  (dB)")
    ax.set_ylabel("Bit error rate")
    vs.titles(ax,
              "Coding gain over AWGN — rate 1/2, K = 4",
              "rtl/decoder.sv is worse than no coding at all — a 7-bit block with "
              "no zero-tail flush\ncannot pay back the rate-1/2 energy penalty. "
              "rtl/decoder_term.sv adds the flush.",
              theme)
    ax.set_xlim(x[0], x[-1] + 1.6)
    ax.set_ylim(FLOOR, 1)
    ax.grid(True, which="both", axis="y")
    ax.grid(True, which="major", axis="x")
    vs.despine(ax)

    # The finding worth annotating is the cost of not terminating the trellis.
    x_rtl = _crossing(x, d["rtl"], 1e-3)
    x_term = _crossing(x, d["terminated"], 1e-3)
    if x_rtl and x_term:
        ax.annotate("", xy=(x_rtl, 1e-3), xytext=(x_term, 1e-3),
                    arrowprops=dict(arrowstyle="<->", color=theme["ink2"],
                                    lw=1.3, shrinkA=0, shrinkB=0))
        # Callout parked in the empty upper-right, with a leader to the arrow.
        ax.annotate(f"{x_rtl - x_term:.1f} dB lost by not\nterminating the trellis",
                    xy=((x_rtl + x_term) / 2, 1.15e-3), xytext=(7.4, 9e-2),
                    ha="center", va="bottom", color=theme["ink2"],
                    fontsize=9, fontweight="600", linespacing=1.4,
                    arrowprops=dict(arrowstyle="-", color=theme["axis"],
                                    lw=0.9, shrinkA=4, shrinkB=2))

    ax.legend(loc="lower left", ncol=1)
    return fig, "ber_awgn"


SERIES_BSC = [
    ("uncoded",    "Uncoded",                    "uncoded",    0),
    ("rtl",        "decoder (no tail flush)",    "decoder",    1),
    ("terminated", "decoder_term (zero-tail)",   "term",       2),
]


def draw_bsc(theme):
    d = _read(BER_DIR / "ber_bsc.csv")
    x = d["p"]
    floor = 1e-7                       # the terminated curve genuinely reaches 3e-7

    fig, ax = plt.subplots(figsize=(8.6, 5.6))
    for key, label, short, slot in SERIES_BSC:
        ax.plot(x, _clip(d[key], floor), color=theme["series"][slot],
                marker=vs.MARKERS[slot], markersize=4.5, label=label,
                markeredgecolor=theme["surface"], markeredgewidth=0.8)

    # Left end: the three curves span three decades there and converge on the
    # right, so that is the only end where a direct label can be read.
    for (key, _label, short, slot), dy in zip(SERIES_BSC, (7, -7, 0)):
        _label_end(ax, x[0], _clip(d[key], floor)[0], short,
                   theme["series"][slot], theme, dy, side="left")

    # where the coded curve crosses the uncoded one
    cross = None
    for i in range(len(x) - 1):
        a = d["rtl"][i] - d["uncoded"][i]
        b = d["rtl"][i + 1] - d["uncoded"][i + 1]
        if a < 0 <= b:
            cross = x[i + 1]
            break
    if cross:
        ax.axvline(cross, color=theme["muted"], lw=1, ls=(0, (2, 3)))
        ax.annotate(f"break-even\np ≈ {cross:.3f}", xy=(cross, 0.5),
                    xytext=(-7, 0), textcoords="offset points",
                    ha="right", va="center", fontsize=8.5,
                    color=theme["muted"], linespacing=1.4)

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("BSC crossover probability  p")
    ax.set_ylabel("Bit error rate")
    vs.titles(ax,
              "Binary symmetric channel — coded vs uncoded",
              "With no rate penalty in play the decoder helps below the "
              "break-even point and hurts above it.\nTerminating the trellis "
              "is worth three orders of magnitude at low p.",
              theme)
    ax.set_xlim(x[0] / 2.6, x[-1] * 1.25)
    ax.set_ylim(floor, 1)
    ax.grid(True, which="both")
    vs.despine(ax)
    ax.legend(loc="lower right")
    return fig, "ber_bsc"


def main() -> None:
    if not (BER_DIR / "ber_awgn.csv").exists():
        raise SystemExit("no BER data -- run: python scripts/run_all.py ber")
    vs.both_themes(draw_awgn)
    vs.both_themes(draw_bsc)


if __name__ == "__main__":
    main()
