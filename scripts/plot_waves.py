"""Digital timing diagrams rendered from real VCDs with vcdvcd + matplotlib.

Replaces the four screenshots the original README linked to, and adds one the
old flow could not produce at all: the eight surviving path metrics inside the
decoder.  The vendor setup dumped only the top-level testbench signals, but
Verilator dumps the whole hierarchy, so h1..h7.hammingDistances.finalStates[*]
are visible for the first time.

  encoder_waveform          from the legacy dff_tb   -> replaces README image 2
  decoder_waveform_clean    clean codeword           -> replaces README image 3
  decoder_waveform_error    dat[6] flipped           -> replaces README image 4
  decoder_metrics           path metrics per stage   -> new
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import numpy as np
from vcdvcd import VCDVCD

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
sys.path.insert(0, str(REPO))

from model import viterbi_ref as ref  # noqa: E402
import vizstyle as vs  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Polygon  # noqa: E402

VCD_DIR = REPO / "results" / "vcd"


# ---------------------------------------------------------------------------
# VCD access
# ---------------------------------------------------------------------------

class Trace:
    """Thin wrapper that resolves signal names loosely and steps values."""

    #: Verilator appends a bit range to vector names, e.g. "tb.dut.q[3:0]" and
    #: "tb.dut.h7.hammingDistances.finalStates[0][4:0]".  Strip only that
    #: trailing range so array indices in the middle of a name survive.
    _RANGE = re.compile(r"\[\d+:\d+\]$")

    _UNITS = [(1e-12, "ps"), (1e-9, "ns"), (1e-6, "µs"), (1e-3, "ms"), (1.0, "s")]

    def __init__(self, path: Path):
        self.vcd = VCDVCD(str(path), store_tvs=True)
        self.names = list(self.vcd.references_to_ids.keys())
        self._base = {self._RANGE.sub("", n): n for n in self.names}
        self.timescale = self.vcd.timescale

        # VCD timestamps are integers in units of the file's timescale; vcdvcd
        # reports that as a `factor` in seconds.  Raw picosecond counts are
        # unreadable on an axis, so rescale to a unit that keeps the span small.
        factor = float(self.timescale["factor"])
        span_s = self.end * factor
        self.div, self.unit = 1.0, "ticks"
        for size, label in self._UNITS:
            if span_s < size * 1000:
                self.div, self.unit = size / factor, label
                break

    def find(self, suffix: str) -> str:
        if suffix in self._base:
            return self._base[suffix]
        hits = [b for b in self._base if b.endswith("." + suffix)]
        if not hits:
            raise KeyError(
                f"{suffix!r} not in VCD (have {len(self.names)} signals, "
                f"e.g. {self.names[:3]})")
        return self._base[min(hits, key=len)]

    def tv(self, suffix: str) -> list[tuple[int, str]]:
        return self.vcd[self.find(suffix)].tv

    def steps(self, suffix: str, t_end: int) -> tuple[np.ndarray, np.ndarray]:
        """Return (times, values) as a step series; x/z become NaN.

        Times come back already scaled into `self.unit`.
        """
        tv = self.tv(suffix)
        times, vals = [], []
        for t, v in tv:
            times.append(t)
            vals.append(_num(v))
        times.append(t_end)
        vals.append(vals[-1] if vals else np.nan)
        return (np.array(times, dtype=float) / self.div,
                np.array(vals, dtype=float))

    @property
    def end(self) -> int:
        return int(self.vcd.endtime)

    @property
    def end_scaled(self) -> float:
        return self.end / self.div


def _num(value: str) -> float:
    s = str(value).strip().lstrip("b")
    if not s or set(s) - {"0", "1"}:
        return np.nan
    return float(int(s, 2))


# ---------------------------------------------------------------------------
# Drawing primitives
# ---------------------------------------------------------------------------

def _digital(ax, t, v, color, theme, y0=0.0, height=0.62, lw=1.8):
    """A 1-bit signal as a classic digital trace."""
    ax.step(t, y0 + v * height, where="post", color=color, lw=lw,
            solid_joinstyle="miter")


def _bus(ax, t, v, color, theme, y0=0.0, height=0.62, fmt="{:0.0f}",
         label_every=1, hexfmt=False, width=None):
    """A multi-bit signal as a hexagon-per-value bus trace with inline labels."""
    for i in range(len(t) - 1):
        t0, t1 = t[i], t[i + 1]
        if t1 <= t0:
            continue
        skew = min((t1 - t0) * 0.12, (t[-1] - t[0]) * 0.004)
        pts = [(t0, y0 + height / 2), (t0 + skew, y0 + height),
               (t1 - skew, y0 + height), (t1, y0 + height / 2),
               (t1 - skew, y0), (t0 + skew, y0)]
        val = v[i]
        bad = np.isnan(val)
        ax.add_patch(Polygon(
            pts, closed=True,
            facecolor=(theme["grid"] if bad else color),
            alpha=(1.0 if bad else 0.16),
            edgecolor=(theme["muted"] if bad else color), lw=1.4,
            joinstyle="miter"))
        if (t1 - t0) > (t[-1] - t[0]) * 0.028 and i % label_every == 0:
            text = "x" if bad else (f"{int(val):0{width}b}" if width
                                    else fmt.format(val))
            ax.text((t0 + t1) / 2, y0 + height / 2, text, ha="center",
                    va="center", fontsize=7.6, color=theme["ink2"],
                    fontfamily="monospace")


def _lane_labels(ax, rows, theme, t0):
    ax.set_yticks([r["y"] + 0.31 for r in rows])
    ax.set_yticklabels([r["label"] for r in rows], fontsize=9)
    for tick, r in zip(ax.get_yticklabels(), rows):
        tick.set_color(r.get("color", theme["ink2"]))
        tick.set_fontfamily("monospace")


def _timing_figure(rows, t0, t1, title, subtitle, theme, xlabel,
                   height_per_row=0.46, marks=None):
    fig, ax = plt.subplots(figsize=(9.6, 2.1 + height_per_row * len(rows)))
    ax.set_xlim(t0, t1)
    # headroom above the top lane so cursor labels do not land on the clock
    ax.set_ylim(-0.45, len(rows) * 1.0 + 0.22)
    ax.grid(True, axis="x", which="major")
    ax.grid(False, axis="y")
    vs.despine(ax, keep=("bottom",))
    _lane_labels(ax, rows, theme, t0)
    ax.tick_params(axis="y", length=0)
    ax.set_xlabel(xlabel)
    vs.titles(ax, title, subtitle, theme)
    for r in rows:
        ax.axhline(r["y"] - 0.18, color=theme["grid"], lw=0.6, zorder=0)
    if marks:
        for x, text, color in marks:
            ax.axvline(x, color=color, lw=1.1, ls=(0, (3, 3)), zorder=1)
            ax.annotate(text, xy=(x, len(rows) + 0.06), xytext=(4, 0),
                        textcoords="offset points", fontsize=8.5,
                        color=color, va="bottom", ha="left", fontweight="600")
    return fig, ax


# ---------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------

def _render(tr, rows, theme, title, subtitle, marks=None):
    """Draw a lane per row.  Control signals wear secondary ink, data signals a
    categorical slot -- in a timing diagram the lane label carries identity, so
    colour is reserved for telling data apart from clocking chrome."""
    t1 = tr.end
    fig, ax = _timing_figure(rows, 0, tr.end_scaled, title, subtitle, theme,
                             f"time ({tr.unit})", marks=marks)
    for r in rows:
        t, v = tr.steps(r["sig"], t1)
        color = (theme["ink2"] if r.get("ctl")
                 else theme["series"][r["slot"]])
        r["color"] = color
        if r["kind"] == "bit":
            _digital(ax, t, v, color, theme, y0=r["y"], lw=r.get("lw", 1.8))
        else:
            _bus(ax, t, v, color, theme, y0=r["y"], width=r.get("width"),
                 fmt=r.get("fmt", "{:0.0f}"))
        # The last value of a bus often lands in a segment too narrow to label
        # in place, so call it out explicitly at the right edge.
        if r.get("final"):
            val = v[-1]
            text = ("x" if np.isnan(val)
                    else (f"{int(val):0{r['width']}b}" if r.get("width")
                          else f"{int(val)}"))
            ax.annotate(text, xy=(t[-1], r["y"] + 0.31), xytext=(8, 0),
                        textcoords="offset points", ha="left", va="center",
                        fontsize=9, fontweight="600", color=color,
                        fontfamily="monospace", clip_on=False)
    _lane_labels(ax, rows, theme, 0)          # re-apply now that colours are known
    ax.tick_params(axis="y", length=0)
    return fig, ax


def draw_encoder_full(theme):
    tr = Trace(VCD_DIR / "encoder_legacy.vcd")
    rows = [
        {"label": "clk",      "y": 4.0, "sig": "clk",   "kind": "bit", "ctl": True},
        {"label": "reset",    "y": 3.0, "sig": "reset", "kind": "bit", "ctl": True},
        {"label": "d",        "y": 2.0, "sig": "d",     "kind": "bit", "slot": 0},
        {"label": "q[3:0]",   "y": 1.0, "sig": "q",     "kind": "bus", "slot": 2,
         "width": 4},
        {"label": "out[1:0]", "y": 0.0, "sig": "out",   "kind": "bus", "slot": 1,
         "width": 2},
    ]
    fig, _ = _render(
        tr, rows, theme,
        "Encoder — rtl/d_ff.sv, original testbench stimulus",
        "Regenerated from a real Verilator VCD, replacing the 2022 ModelSim "
        "screenshot.\nq is the shift register; out[1] is the g1 = 1111 parity, "
        "out[0] the g0 = 1011 parity.")
    return fig, "encoder_waveform"


def _decoder_figure(theme, vcd_name, stem, title, subtitle):
    tr = Trace(VCD_DIR / vcd_name)
    rows = [
        {"label": "clk",       "y": 6.0, "sig": "clk",     "kind": "bit",
         "ctl": True, "lw": 1.1},
        {"label": "reset",     "y": 5.0, "sig": "reset",   "kind": "bit", "ctl": True},
        {"label": "ready",     "y": 4.0, "sig": "ready",   "kind": "bit", "ctl": True},
        {"label": "dat[13:0]", "y": 3.0, "sig": "dat",     "kind": "bus", "slot": 0,
         "width": 14},
        {"label": "steps_n",   "y": 2.0, "sig": "steps_n", "kind": "bus", "slot": 2},
        {"label": "stage_n",   "y": 1.0, "sig": "stage_n", "kind": "bus", "slot": 3},
        {"label": "out[6:0]",  "y": 0.0, "sig": "out",     "kind": "bus", "slot": 1,
         "width": 7, "final": True},
    ]

    ready_t, ready_v = tr.steps("ready", tr.end)
    marks = []
    idx = np.nonzero(ready_v == 1)[0]
    if len(idx):
        marks.append((ready_t[idx[0]], "traceback begins", theme["muted"]))

    fig, _ = _render(tr, rows, theme, title, subtitle, marks=marks)
    return fig, stem


def draw_decoder_clean(theme):
    return _decoder_figure(
        theme, "decoder_bench_clean.vcd", "decoder_waveform_clean",
        "Decoder — clean codeword",
        "dat = 11110111010111 decodes to out = 1011000 after 45 trellis cycles "
        "and 8 traceback cycles.\nsteps_n walks the seven trellis stages; "
        "stage_n walks the eight states within a stage.")


def draw_decoder_error(theme):
    return _decoder_figure(
        theme, "decoder_bench_error.vcd", "decoder_waveform_error",
        "Decoder — single-bit channel error corrected",
        "dat[6] is flipped, so dat = 11110110010111 — yet out still settles to "
        "1011000.\nThis is the case the original project was built to "
        "demonstrate.")


def draw_metrics(theme):
    """The 8x7 path-metric matrix read straight out of the RTL.

    A view the original vendor flow could not produce: it dumped only top-level
    testbench signals, so h1..h7 were invisible.  Each column is one trellis
    stage's converged metrics; the survivor path from the Python model is
    overlaid to show the two agree.
    """
    tr = Trace(VCD_DIR / "decoder_bench_error.vcd")
    t1 = tr.end

    # Each h<k> holds stage k's metrics; take the settled value at end of sim.
    metrics = np.full((8, 7), np.nan)
    for k in range(1, 8):
        for s in range(8):
            _, v = tr.steps(f"h{k}.hammingDistances.finalStates[{s}]", t1)
            metrics[s, k - 1] = v[-1]

    # States unreachable that early carry a meaningless zero from reset.
    for k in range(1, 8):
        reachable = min(2 ** k, 8)
        if reachable < 8:
            allowed = {0}
            for _ in range(k):
                allowed = {ref.next_state(st, b) for st in allowed for b in (0, 1)}
            for s in range(8):
                if s not in allowed:
                    metrics[s, k - 1] = np.nan

    trace = ref.trellis_trace(ref.CANONICAL_CW ^ (1 << ref.CANONICAL_ERROR_BIT))
    path = trace["path"]                    # path[k] = state after stage k

    fig, ax = plt.subplots(figsize=(9.0, 5.0))
    ramp = theme["seq"]
    vmax = np.nanmax(metrics)

    for s in range(8):
        for k in range(7):
            val = metrics[s, k]
            if np.isnan(val):
                ax.add_patch(plt.Rectangle(
                    (k + 0.53, s + 0.53), 0.94, 0.94,
                    facecolor=theme["surface"], edgecolor=theme["grid"],
                    lw=1.0, ls=(0, (2, 2))))
                continue
            step = ramp[min(int(round(val / vmax * (len(ramp) - 1))),
                            len(ramp) - 1)]
            ax.add_patch(plt.Rectangle(
                (k + 0.53, s + 0.53), 0.94, 0.94,
                facecolor=step, edgecolor=theme["surface"], lw=2.0))
            # ink on the cell, not the series colour
            light = int(round(val / vmax * (len(ramp) - 1))) < len(ramp) / 2
            ax.text(k + 1, s + 1, f"{int(val)}", ha="center", va="center",
                    fontsize=10, fontweight="600",
                    color=("#0b0b0b" if light else "#ffffff"))

    # survivor path on top
    xs = list(range(1, 8))
    ys = [path[k] + 1 for k in range(1, 8)]
    # Open markers so the metric printed in each cell stays readable.
    ax.plot(xs, ys, color=theme["series"][1], lw=2.2, marker="o",
            markersize=17, markerfacecolor="none", markeredgewidth=2.2,
            zorder=10, label="surviving path (Python model)")

    ax.set_xlim(0.4, 7.6)
    ax.set_ylim(0.4, 8.6)
    ax.set_xticks(range(1, 8))
    ax.set_xticklabels([f"h{k}" for k in range(1, 8)])
    ax.set_yticks(range(1, 9))
    ax.set_yticklabels([f"{s:03b}" for s in range(8)], fontfamily="monospace")
    ax.set_xlabel("trellis stage  (message bit 1 → 7)")
    ax.set_ylabel("state  (q0 q1 q2)")
    ax.grid(False)
    vs.despine(ax, keep=())
    ax.tick_params(length=0)
    vs.titles(ax,
              "Inside the decoder — accumulated path metrics per stage",
              "Read directly out of h1..h7 in the RTL, with dat[6] corrupted. "
              "The original vendor flow\ncould not show this: it dumped only "
              "top-level signals. Dashed cells are not yet reachable.",
              theme)
    ax.legend(loc="upper left", bbox_to_anchor=(0, -0.12), frameon=False)
    return fig, "decoder_metrics"


def main() -> None:
    missing = [n for n in ("encoder_legacy.vcd", "decoder_bench_clean.vcd",
                           "decoder_bench_error.vcd")
               if not (VCD_DIR / n).exists()]
    if missing:
        raise SystemExit(f"missing VCDs {missing} -- run: "
                         f"python scripts/run_all.py sim")
    vs.both_themes(draw_encoder_full)
    vs.both_themes(draw_decoder_clean)
    vs.both_themes(draw_decoder_error)
    vs.both_themes(draw_metrics)


if __name__ == "__main__":
    main()
