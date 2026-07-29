"""Logic area against block length, unrolled vs folded.

The one figure that explains why `rtl/decoder.sv` cannot be given a longer
block and `rtl/decoder_folded.sv` can.  Both decode the identical trellis and
produce identical bits; the difference is entirely how the C++ model's
`for` loop over `vector<HammingTable>` was translated into hardware.

  unrolled  every trellis stage is its own register bank and its own
            add-compare-select ladder, so area is linear in the block length
            and the design runs off the end of the device.
  folded    eight add-compare-select units reused once per stage, metrics
            renormalised so they stay 4 bits wide.  Only the survivor memory
            grows, and it grows as memory rather than logic.

Reads results/synth/synth_summary.json (written by scripts/synth.py).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

import vizstyle as vs  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

SUMMARY = REPO / "results" / "synth" / "synth_summary.json"
DEVICE_LUTS = 5280               # Lattice iCE40 UP5K (SG48)


def draw(theme):
    data = json.loads(SUMMARY.read_text())
    sweep = data.get("block_sweep")
    if not sweep:
        return None

    fig, ax = plt.subplots(figsize=(8.6, 5.6))

    # Direct labels rather than a legend, per the house rule in vizstyle.py:
    # the two curves are far apart everywhere, so a legend would only add a
    # second place to look.
    styles = {
        "unrolled": (theme["series"][1], "decoder_term.sv\nunrolled", 1, 0),
        "folded":   (theme["series"][2], "decoder_folded.sv\nfolded", 2, 0),
    }

    seen = {}
    for arch, (colour, label, slot, dy) in styles.items():
        pts = sorted((r for r in sweep if r["arch"] == arch),
                     key=lambda r: r["msg_bits"])
        if not pts:
            continue
        x = np.array([r["msg_bits"] for r in pts])
        y = np.array([r["lut4"] for r in pts])
        seen[arch] = (x, y)
        ax.plot(x, y, color=colour, marker=vs.MARKERS[slot], markersize=6,
                lw=2.0, markeredgecolor=theme["surface"],
                markeredgewidth=0.9, zorder=3)
        ax.annotate(label, xy=(x[-1], y[-1]), xytext=(9, dy),
                    textcoords="offset points", color=colour, fontsize=9,
                    fontweight="600", va="center", linespacing=1.35,
                    clip_on=False)

    # The device ceiling is the whole point of the unrolled curve.  Label it
    # on the right, where neither curve passes.
    ax.axhline(DEVICE_LUTS, color=theme["muted"], lw=1.2, ls=(0, (5, 3)))
    ax.annotate(f"iCE40 UP5K capacity — {DEVICE_LUTS} LUT4",
                xy=(1.0, DEVICE_LUTS), xycoords=("axes fraction", "data"),
                xytext=(-6, 6), textcoords="offset points",
                color=theme["muted"], fontsize=8.5, va="bottom", ha="right")

    # Where the unrolled design runs out of device, interpolated between the
    # two synthesised points that straddle the line.
    if "unrolled" in seen:
        x, y = seen["unrolled"]
        for i in range(len(x) - 1):
            if y[i] <= DEVICE_LUTS < y[i + 1]:
                f = (DEVICE_LUTS - y[i]) / (y[i + 1] - y[i])
                xc = x[i] + f * (x[i + 1] - x[i])
                ax.plot([xc], [DEVICE_LUTS], marker="o", markersize=7,
                        color=theme["ink2"], zorder=5, fillstyle="none",
                        markeredgewidth=1.6)
                ax.annotate(f"unrolled runs out of\ndevice at ≈{xc:.0f} message bits",
                            xy=(xc, DEVICE_LUTS), xytext=(26, -46),
                            textcoords="offset points", color=theme["ink2"],
                            fontsize=9, fontweight="600", linespacing=1.4,
                            arrowprops=dict(arrowstyle="-", color=theme["axis"],
                                            lw=0.9, shrinkA=2, shrinkB=4))
                break

    ax.set_xlabel("Message bits per block")
    ax.set_ylabel("SB_LUT4 cells after synth_ice40")
    vs.titles(ax,
              "Why the block length was stuck",
              "Same code, same trellis, same decoded bits. The unrolled decoder "
              "spends logic per trellis\nstage; the folded one reuses it, so its "
              "area barely moves as the block grows.",
              theme)
    ax.set_ylim(0, None)
    ax.set_xlim(0, 118)                 # headroom for the direct labels
    ax.grid(True, which="major", axis="y")
    vs.despine(ax)
    return fig, "area_blocklen"


def main() -> None:
    if not SUMMARY.exists():
        raise SystemExit("no synthesis data -- run: python scripts/run_all.py synth")
    vs.both_themes(draw)


if __name__ == "__main__":
    main()
