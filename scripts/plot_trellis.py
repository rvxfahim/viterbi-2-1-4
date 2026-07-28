"""Explanatory figures generated from the golden model.

  trellis                    the 8-state trellis with the survivor path
  error_correction_heatmap   128 messages x 15 channels, pass/fail
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
sys.path.insert(0, str(REPO))

from model import viterbi_ref as ref  # noqa: E402
import vizstyle as vs  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402

BER_DIR = REPO / "results" / "ber"


def draw_trellis(theme):
    """The trellis, with the survivor path for the corrupted canonical word."""
    word = ref.CANONICAL_CW ^ (1 << ref.CANONICAL_ERROR_BIT)
    trace = ref.trellis_trace(word)
    path = trace["path"]
    survivors = trace["survivors"]
    n = ref.MSG_BITS

    fig, ax = plt.subplots(figsize=(10.2, 5.8))

    survivor_edges = {(k, survivors[k][path[k + 1]], path[k + 1])
                      for k in range(n)}

    # every legal transition, faint
    for k in range(n):
        for s in range(8):
            if k == 0 and s != 0:
                continue
            if k == 1 and s not in (0, 4):
                continue
            for b in (0, 1):
                nxt, o1, o0 = ref.TRANSITIONS[s][b]
                on_path = (k, s, nxt) in survivor_edges
                ax.plot([k, k + 1], [s, nxt],
                        color=(theme["series"][1] if on_path else theme["axis"]),
                        lw=(2.6 if on_path else 1.0),
                        zorder=(6 if on_path else 2),
                        solid_capstyle="round")
                # branch labels only on the first stage, else it is unreadable
                if k == 0:
                    ax.text(k + 0.5, (s + nxt) / 2 + 0.14, f"{o1}{o0}",
                            ha="center", va="bottom", fontsize=8,
                            color=theme["muted"], fontfamily="monospace")

    # received bit pairs along the top
    for k in range(n):
        pair = f"{(word >> (2 * n - 2 - 2 * k)) & 3:02b}"
        corrupted = (2 * n - 1 - ref.CANONICAL_ERROR_BIT) // 2 == k
        ax.text(k + 0.5, 7.72, pair, ha="center", va="bottom",
                fontsize=10, fontweight="600", fontfamily="monospace",
                color=(theme["critical"] if corrupted else theme["ink2"]))
    ax.text(-0.06, 7.72, "received", ha="right", va="bottom", fontsize=9,
            color=theme["muted"])
    ax.annotate("bit flipped by the channel",
                xy=((2 * n - 1 - ref.CANONICAL_ERROR_BIT) // 2 + 0.5, 7.68),
                xytext=(0, 30), textcoords="offset points", ha="center",
                va="bottom", fontsize=8.5, color=theme["critical"],
                arrowprops=dict(arrowstyle="->", color=theme["critical"], lw=1.1))

    # nodes
    for k in range(n + 1):
        for s in range(8):
            if k == 0 and s != 0:
                continue
            if k == 1 and s not in (0, 4):
                continue
            on = path[k] == s
            ax.plot([k], [s], marker="o", markersize=(9 if on else 6),
                    color=(theme["series"][1] if on else theme["muted"]),
                    markerfacecolor=(theme["series"][1] if on
                                     else theme["surface"]),
                    markeredgewidth=1.4, zorder=8)

    # decoded bits under the survivor path
    for k in range(n):
        ax.text(k + 0.5, -0.85, str(trace["bits"][k]), ha="center", va="center",
                fontsize=11, fontweight="600", color=theme["series"][1],
                fontfamily="monospace")
    ax.text(-0.06, -0.85, "decoded", ha="right", va="center", fontsize=9,
            color=theme["muted"])

    ax.set_xlim(-0.35, n + 0.45)
    ax.set_ylim(-1.4, 9.5)     # headroom for the channel-error callout
    ax.set_xticks(range(n + 1))
    ax.set_xticklabels([f"{k}" for k in range(n + 1)])
    ax.set_yticks(range(8))
    ax.set_yticklabels([f"{s:03b}" for s in range(8)], fontfamily="monospace")
    ax.set_xlabel("trellis stage")
    ax.set_ylabel("state  (q0 q1 q2)")
    ax.grid(True, axis="y")
    ax.grid(False, axis="x")
    vs.despine(ax, keep=("left",))
    ax.tick_params(length=0)
    vs.titles(ax,
              "The 8-state trellis, with one channel error corrected",
              "Branch labels on stage 1 are the transmitted pair (g1 g0). The "
              "highlighted path is the\nmaximum-likelihood survivor — it "
              "disagrees with the received bits in exactly one place.",
              theme)
    ax.legend(handles=[
        plt.Line2D([], [], color=theme["series"][1], lw=2.6,
                   label="surviving (maximum-likelihood) path"),
        plt.Line2D([], [], color=theme["axis"], lw=1.0,
                   label="discarded transitions"),
    ], loc="upper right", bbox_to_anchor=(1.0, -0.1), ncol=2)
    return fig, "trellis"


def draw_heatmap(theme):
    """Exhaustive RTL sweep: which (message, error position) pairs recover."""
    path = BER_DIR / "rtl_sweep.csv"
    grid = np.zeros((14, 128), dtype=float)
    clean = np.zeros(128, dtype=float)
    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            m = int(row["message"], 2)
            e = int(row["error_bit"])
            ok = float(row["pass"])
            if e < 0:
                clean[m] = ok
            else:
                grid[e, m] = ok

    fig, ax = plt.subplots(figsize=(10.2, 4.6))
    # pass/fail is a status encoding, not a categorical series, so it uses the
    # reserved status colours -- and both are labelled, never colour alone.
    good, bad = theme["good"], theme["critical"]
    ax.imshow(grid, aspect="auto", origin="lower", interpolation="nearest",
              cmap=plt.matplotlib.colors.ListedColormap([bad, good]),
              vmin=0, vmax=1, extent=(-0.5, 127.5, -0.5, 13.5))

    # boundary between the protected body of the word and its unprotected tail
    ax.axhline(3.5, color=theme["ink"], lw=1.6)
    ax.annotate("bits 4–13: every single error corrected",
                xy=(2, 4.0), xytext=(0, 0), textcoords="offset points",
                ha="left", va="bottom", fontsize=9, fontweight="600",
                color="#ffffff")
    ax.annotate("bits 0–3: the un-flushed tail — half of all messages fail",
                xy=(2, 3.1), xytext=(0, 0), textcoords="offset points",
                ha="left", va="top", fontsize=9, fontweight="600",
                color="#ffffff")

    rate = grid.mean()
    ax.set_xlabel("message  (0 … 127)")
    ax.set_ylabel("flipped codeword bit")
    ax.set_yticks(range(0, 14, 1))
    ax.set_xticks(range(0, 128, 16))
    vs.despine(ax, keep=())
    ax.tick_params(length=0)
    ax.grid(False)
    vs.titles(ax,
              "Single-bit error correction across the whole message space",
              f"Every 7-bit message against every single-bit channel error: "
              f"{int(grid.sum())} of {grid.size} recover "
              f"({100 * rate:.1f}%); the clean channel is 128/128.\nFailures "
              f"land only on codeword bits 0–3 — the last two message bits, "
              f"which no zero-tail flush protects.",
              theme)
    ax.legend(handles=[
        Patch(facecolor=good, label="message recovered"),
        Patch(facecolor=bad, label="decode failed"),
    ], loc="upper right", bbox_to_anchor=(1.0, -0.18), ncol=2)
    return fig, "error_correction_heatmap"


def _load_grid(path, cw_bits):
    grid = np.zeros((cw_bits, 128), dtype=float)
    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            e = int(row["error_bit"])
            if e >= 0:
                grid[e, int(row["message"], 2)] = float(row["pass"])
    return grid


def draw_heatmap_compare(theme):
    """The same sweep against both decoder variants, stacked for comparison.

    This is the single figure that shows what the fix bought: the same
    add-compare-select logic, the same encoder, the same channel -- the only
    difference is three zero bits clocked in at the end of the block.
    """
    plain = _load_grid(BER_DIR / "rtl_sweep.csv", 14)
    term = _load_grid(BER_DIR / "rtl_sweep_term.csv", 20)

    good, bad = theme["good"], theme["critical"]
    cmap = plt.matplotlib.colors.ListedColormap([bad, good])

    fig, axes = plt.subplots(
        2, 1, figsize=(10.2, 8.0),
        gridspec_kw={"height_ratios": [14, 20], "hspace": 0.34},
    )
    # Two panels share one title block, so it lives on the figure rather than
    # on an axes -- vs.titles() would overwrite the first panel's own label.
    fig.subplots_adjust(top=0.855)
    fig.text(0.055, 0.975, "What terminating the trellis is worth",
             ha="left", va="top", fontsize=12.5, fontweight="600",
             color=theme["ink"])
    fig.text(0.055, 0.945,
             "Identical ACS logic, identical encoder, identical channel. The "
             "only difference is three\nzero bits clocked in at the end of the "
             "block, which pins the survivor's end state.",
             ha="left", va="top", fontsize=9.5, color=theme["muted"],
             linespacing=1.45)

    for ax, grid, title in (
        (axes[0], plain, "decoder — 14-bit block, no tail flush"),
        (axes[1], term, "decoder_term — 20-bit block, zero-tail terminated"),
    ):
        rows = grid.shape[0]
        ax.imshow(grid, aspect="auto", origin="lower", interpolation="nearest",
                  cmap=cmap, vmin=0, vmax=1,
                  extent=(-0.5, 127.5, -0.5, rows - 0.5))
        ax.set_ylabel("flipped codeword bit")
        ax.set_yticks(range(0, rows, 2))
        ax.set_xticks(range(0, 128, 16))
        vs.despine(ax, keep=())
        ax.tick_params(length=0)
        ax.grid(False)
        pct = 100 * grid.mean()
        ax.set_title(f"{title}      {int(grid.sum())}/{grid.size}  ({pct:.1f}%)",
                     loc="left", fontsize=10.5, fontweight="600",
                     color=theme["ink"], pad=6)

    axes[0].axhline(3.5, color=theme["ink"], lw=1.6)
    axes[0].annotate("bits 0–3: the un-flushed tail — half of all messages fail",
                     xy=(2, 2.95), ha="left", va="top", fontsize=9,
                     fontweight="600", color="#ffffff")
    axes[1].annotate("every bit position, every message — no failures",
                     xy=(2, 9.5), ha="left", va="center", fontsize=9,
                     fontweight="600", color="#ffffff")

    axes[1].set_xlabel("message  (0 … 127)")
    axes[1].legend(handles=[
        Patch(facecolor=good, label="message recovered"),
        Patch(facecolor=bad, label="decode failed"),
    ], loc="upper right", bbox_to_anchor=(1.0, -0.16), ncol=2)
    return fig, "error_correction_compare"


def main() -> None:
    vs.both_themes(draw_trellis)
    if (BER_DIR / "rtl_sweep.csv").exists():
        vs.both_themes(draw_heatmap)
    else:
        print("  skipping heatmap -- run: python scripts/run_all.py sweep")
    if (BER_DIR / "rtl_sweep_term.csv").exists():
        vs.both_themes(draw_heatmap_compare)
    else:
        print("  skipping comparison -- run: python scripts/run_all.py sweep")


if __name__ == "__main__":
    main()
