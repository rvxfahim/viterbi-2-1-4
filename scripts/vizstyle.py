"""Shared matplotlib theming for every figure in docs/img/.

Each figure is rendered twice -- light and dark -- so the README can serve the
right one with a <picture> element and the plots stay legible in either GitHub
theme.  The dark steps are the same hues restepped for the dark surface, not an
inverted light palette.

Palette provenance: both the light and the dark four-slot sets were checked with
the data-viz validator (lightness band, chroma floor, adjacent-pair CVD
separation, normal-vision floor, contrast).  All hard gates pass.  On the light
surface aqua and yellow fall below 3:1 against the surface, so the relief rule
applies: every series carries a direct label and a distinct marker, and identity
is never left to color alone.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
IMG_DIR = REPO / "docs" / "img"

THEMES = {
    "light": {
        "surface": "#fcfcfb",
        "page": "#f9f9f7",
        "ink": "#0b0b0b",
        "ink2": "#52514e",
        "muted": "#898781",
        "grid": "#e1e0d9",
        "axis": "#c3c2b7",
        # categorical slots 1..8, fixed order, never cycled
        "series": ["#2a78d6", "#eb6834", "#1baf7a", "#eda100",
                   "#e87ba4", "#008300", "#4a3aa7", "#e34948"],
        # single-hue sequential ramp, light -> dark
        "seq": ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5",
                "#256abf", "#184f95", "#0d366b"],
        "good": "#0ca30c",
        "critical": "#d03b3b",
        "suffix": "",
    },
    "dark": {
        "surface": "#1a1a19",
        "page": "#0d0d0d",
        "ink": "#ffffff",
        "ink2": "#c3c2b7",
        "muted": "#898781",
        "grid": "#2c2c2a",
        "axis": "#383835",
        "series": ["#3987e5", "#d95926", "#199e70", "#c98500",
                   "#d55181", "#008300", "#9085e9", "#e66767"],
        "seq": ["#0d366b", "#184f95", "#256abf", "#3987e5",
                "#6da7ec", "#9ec5f4", "#cde2fb"],
        "good": "#0ca30c",
        "critical": "#d03b3b",
        "suffix": "-dark",
    },
}

#: Distinct markers per categorical slot -- secondary encoding so a series is
#: never identified by hue alone.
MARKERS = ["o", "s", "^", "D", "v", "P", "X", "*"]

FONT = ["Segoe UI", "DejaVu Sans", "sans-serif"]


def apply(theme: dict) -> None:
    plt.rcParams.update({
        "figure.facecolor": theme["page"],
        "axes.facecolor": theme["surface"],
        "savefig.facecolor": theme["page"],
        "font.family": "sans-serif",
        "font.sans-serif": FONT,
        "font.size": 10,
        "text.color": theme["ink"],
        "axes.labelcolor": theme["ink2"],
        "axes.edgecolor": theme["axis"],
        "axes.titlecolor": theme["ink"],
        "axes.titlesize": 12,
        "axes.titleweight": "600",
        "axes.titlelocation": "left",
        "axes.titlepad": 10,
        "axes.labelsize": 10,
        "axes.grid": True,
        "axes.axisbelow": True,
        "grid.color": theme["grid"],
        "grid.linewidth": 0.7,
        "xtick.color": theme["muted"],
        "ytick.color": theme["muted"],
        "xtick.labelcolor": theme["ink2"],
        "ytick.labelcolor": theme["ink2"],
        "xtick.labelsize": 9,
        "ytick.labelsize": 9,
        "legend.frameon": False,
        "legend.fontsize": 9,
        "legend.labelcolor": theme["ink2"],
        "lines.linewidth": 2.0,          # 2px lines per the mark spec
        "lines.markersize": 5,
        "figure.dpi": 130,
        "savefig.dpi": 130,
        "savefig.bbox": "tight",
        "savefig.pad_inches": 0.25,
    })


def despine(ax, keep=("left", "bottom")) -> None:
    for side, spine in ax.spines.items():
        spine.set_visible(side in keep)


def titles(ax, title: str, subtitle: str, theme: dict) -> None:
    """Title block aligned to the axes' left edge, subtitle under the title.

    The title pad is derived from the subtitle's line count so the two never
    collide regardless of how long the subtitle is.
    """
    lines = subtitle.count("\n") + 1 if subtitle else 0
    ax.annotate(subtitle, xy=(0, 1), xycoords="axes fraction",
                xytext=(0, 8), textcoords="offset points",
                ha="left", va="bottom", fontsize=9.5, color=theme["muted"],
                linespacing=1.45)
    ax.set_title(title, pad=8 + int(13.5 * lines) + 9, fontsize=12.5,
                 fontweight="600", color=theme["ink"], loc="left")


def save(fig, stem: str, theme: dict) -> Path:
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    path = IMG_DIR / f"{stem}{theme['suffix']}.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"  wrote docs/img/{path.name}")
    return path


def both_themes(draw) -> None:
    """Render `draw(theme)` once per theme.  `draw` returns (fig, stem)."""
    for name in ("light", "dark"):
        theme = THEMES[name]
        apply(theme)
        fig, stem = draw(theme)
        save(fig, stem, theme)
