"""Generate the unrolled Viterbi decoder RTL from rtl/gen/decoder.sv.j2.

`rtl/legacy/decoder.sv` is 1317 lines because every trellis stage is written
out by hand -- h1..h7, each with its own eight-way add-compare-select ladder,
each branch metric's expected output pair typed in as a literal.  That style is
readable and it synthesises well, but it does not extend: adding the three
zero-tail flush stages the code actually needs means hand-writing another ~600
lines of near-identical ladder, and one mistyped `high`/`low` in there is a bug
no review would reliably catch.

So the ladder is generated instead.  Everything the template needs is derived
here from the code definition alone -- generators g1 = 1111 and g0 = 1011 --
rather than transcribed, which means the two variants below cannot disagree
with each other or with `model/viterbi_ref.py` by transcription error:

    decoder       7 stages, 14-bit codeword, unterminated  (the original)
    decoder_term  10 stages, 20-bit codeword, zero-tail terminated

The generated `decoder` is checked against the golden model on all 1920 sweep
cases, which is what demonstrates the template reproduces the hand-written
stages rather than merely resembling them.

    python scripts/gen_rtl.py           # regenerate both
    python scripts/gen_rtl.py --check   # fail if the checked-in files differ
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from jinja2 import Environment, FileSystemLoader, StrictUndefined  # noqa: E402

from model.viterbi_ref import branch_outputs, next_state  # noqa: E402

GEN_DIR = REPO / "rtl" / "gen"
RTL_DIR = REPO / "rtl"

N_STATES = 8
TAIL_BITS = 3                     # K - 1 flush bits
MSG_BITS = 7

#: The struct field the original names each predecessor state's branch by.
#: state 0 -> aTransition, 1 -> bTransition, ... 7 -> hTransition.
BRANCH_LETTER = "abcdefgh"


def predecessors(state: int) -> tuple[int, int]:
    """The two states that can reach `state` -- 2*(state & 3) and that + 1."""
    base = 2 * (state & 0b11)
    return base, base + 1


def reachable(stage: int) -> set[int]:
    """States reachable from the all-zero start after `stage` input bits.

    The trellis opens 1 -> 2 -> 4 -> 8, which is why the first three stages of
    the ladder are narrower than the rest.
    """
    states = {0}
    for _ in range(stage):
        states = {next_state(s, b) for s in states for b in (0, 1)}
    return states


def branch_for(target: int, pred: int) -> dict:
    """One arm of the butterfly into `target`, as the template needs it."""
    bit = target >> 2                       # the input bit this transition implies
    assert next_state(pred, bit) == target, (pred, bit, target)
    out1, out0 = branch_outputs(pred, bit)
    return {
        "field": f"{BRANCH_LETTER[pred]}Transition",
        "index": bit,                       # [0] for targets 0-3, [1] for 4-7
        "pred": pred,
        "out1": "high" if out1 else "low",
        "out0": "high" if out0 else "low",
    }


def build_stage(stage: int, stages: int, cw_bits: int) -> dict:
    """One `steps_n == stage` block: its bit slice and its sub-stage list."""
    hi = cw_bits - 1 - 2 * (stage - 1)
    prev_reachable = reachable(stage - 1)

    subs = []
    for target in sorted(reachable(stage)):
        arms = [p for p in predecessors(target) if p in prev_reachable]
        subs.append({
            "target": target,
            "stage_n": target,              # the original indexes sub-stages by target state
            "compare": len(arms) == 2,
            "branches": [branch_for(target, p) for p in arms],
        })

    # The original advances stage_n by the gap to the next populated sub-stage,
    # so stage 2 counts 0, 2, 4, 6 and the rest count by one.
    for i, sub in enumerate(subs):
        last = i == len(subs) - 1
        sub["last"] = last
        sub["step"] = 0 if last else subs[i + 1]["stage_n"] - sub["stage_n"]

    return {
        "n": stage,
        "table": f"h{stage}",
        "prev_table": f"h{stage - 1}",
        "bit_hi": hi,
        "bit_lo": hi - 1,
        "subs": subs,
    }


#: Widths the original hand-written decoder used.  Deriving the widths from
#: the stage count (below) would make them *narrower* than these at 7 and 10
#: stages, which would change rtl/decoder.sv and rtl/decoder_term.sv and every
#: synthesis number and waveform already published from them.  Flooring at the
#: original values keeps those two byte-identical while still letting longer
#: blocks widen as they need to.
LEGACY_TABLE_W = 4
LEGACY_STEP_W = 5
LEGACY_METRIC_W = 5

#: `table_counter`, `pinOut` and `counter_for_path` are `byte` in the template,
#: so the sequencer cannot count past 127 stages however wide the fields get.
MAX_STAGES = 127


def widths(stages: int) -> dict:
    """The three widths that were hard-coded for a 7-bit block.

    Each is a property of the stage count, not of the algorithm:

    * ``table_w``  -- ``getReturnPath`` compares ``currentTable`` against 1..stages.
    * ``step_w``   -- ``steps_n`` counts up to stages + 1 before it falls out.
    * ``metric_w`` -- there is no metric normalisation anywhere in this design,
      so a path metric grows with the block.  The bound is 2 per stage (the
      branch metric is a Hamming distance over a 2-bit symbol), hence
      ``2 * stages``.  That bound is loose -- measured over
      ``model/viterbi_ref.py`` at a 10% channel error rate the largest final
      metric is 6 at 10 stages, 10 at 23 and 31 at 103 -- but it is the only
      one that cannot be exceeded.  ``rtl/decoder_folded.sv`` normalises
      instead and stays 4 bits wide at every length.
    """
    if stages > MAX_STAGES:
        raise SystemExit(
            f"{stages} stages exceeds the sequencer's {MAX_STAGES}-stage limit: "
            "table_counter, pinOut and counter_for_path are `byte` in "
            "rtl/gen/decoder.sv.j2 and would wrap.")
    return {
        "table_w": max(LEGACY_TABLE_W, stages.bit_length()),
        "step_w": max(LEGACY_STEP_W, (stages + 1).bit_length()),
        "metric_w": max(LEGACY_METRIC_W, (2 * stages).bit_length()),
    }


def context(name: str, terminate: bool, msg_bits: int = MSG_BITS) -> dict:
    tail = TAIL_BITS if terminate else 0
    stages = msg_bits + tail
    cw_bits = 2 * stages

    # 1 cycle for stage 1, then one cycle per populated sub-stage.
    trellis_cycles = 1 + sum(len(reachable(s)) for s in range(2, stages + 1))

    # Traceback reads the survivor back out of the sentinels: for each state,
    # the arm from its *even* predecessor is checked, and a 3 there means that
    # arm lost the compare so the odd predecessor is the survivor.
    return_paths = []
    for state in range(N_STATES):
        p0, p1 = predecessors(state)
        return_paths.append({
            "state": state,
            "field": f"{BRANCH_LETTER[p0]}Transition",
            "index": state >> 2,
            "pred_even": p0,
            "pred_odd": p1,
        })

    # set_outputs turns a (previous -> current) state pair back into the input
    # bit that caused it, which is just the top bit of the current state.
    output_map = [
        {"from_s": s, "at_state": p, "bit": s >> 2}
        for s in range(N_STATES) for p in predecessors(s)
    ]

    return {
        **widths(stages),
        "module": name,
        "terminate": terminate,
        "return_paths": return_paths,
        "output_map": output_map,
        "tail": tail,
        "msg_bits": msg_bits,
        "stages": stages,
        "cw_bits": cw_bits,
        "trellis_cycles": trellis_cycles,
        "traceback_cycles": stages + 1,
        "tables": [f"h{i}" for i in range(1, stages + 1)],
        "stage_blocks": [build_stage(s, stages, cw_bits) for s in range(2, stages + 1)],
        "first_hi": cw_bits - 1,
        "first_lo": cw_bits - 2,
        "letters": BRANCH_LETTER,
        "generator": Path(__file__).name,
    }


VARIANTS = [
    # module name, terminated, output file
    ("decoder", False, RTL_DIR / "decoder.sv"),
    ("decoder_term", True, RTL_DIR / "decoder_term.sv"),
]


def _env() -> Environment:
    return Environment(
        loader=FileSystemLoader(GEN_DIR),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )


def render(name: str, terminate: bool, msg_bits: int = MSG_BITS) -> tuple[str, dict]:
    """Render one variant.  Importable so scripts/synth.py can build the
    block-length sweep without writing anything into rtl/."""
    ctx = context(name, terminate, msg_bits)
    return _env().get_template("decoder.sv.j2").render(**ctx), ctx


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="verify the checked-in RTL matches the template")
    ap.add_argument("--msg-bits", type=int, metavar="N",
                    help="render a one-off variant with N message bits instead "
                         "of regenerating the two checked-in decoders")
    ap.add_argument("--out", type=Path, metavar="PATH",
                    help="where --msg-bits writes (default: stdout)")
    ap.add_argument("--module", default="decoder_term",
                    help="module name for --msg-bits (default: decoder_term)")
    ap.add_argument("--no-terminate", action="store_true",
                    help="with --msg-bits, omit the zero-tail flush")
    args = ap.parse_args()

    if args.msg_bits is not None:
        text, ctx = render(args.module, not args.no_terminate, args.msg_bits)
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(text)
            print(f"  {args.out}  {ctx['stages']} stages, "
                  f"{ctx['cw_bits']}-bit codeword, widths "
                  f"table={ctx['table_w']} step={ctx['step_w']} "
                  f"metric={ctx['metric_w']}, {len(text.splitlines())} lines")
        else:
            sys.stdout.write(text)
        return

    env = Environment(
        loader=FileSystemLoader(GEN_DIR),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )
    template = env.get_template("decoder.sv.j2")

    stale = []
    for name, terminate, path in VARIANTS:
        ctx = context(name, terminate)
        text = template.render(**ctx)
        if args.check:
            current = path.read_text() if path.exists() else None
            if current != text:
                stale.append(path)
            continue
        path.write_text(text)
        print(f"  {path.relative_to(REPO)}  "
              f"{ctx['stages']} stages, {ctx['cw_bits']}-bit codeword, "
              f"{ctx['trellis_cycles']}+{ctx['traceback_cycles']} cycles, "
              f"{len(text.splitlines())} lines")

    if args.check:
        if stale:
            for p in stale:
                print(f"  STALE  {p.relative_to(REPO)}", file=sys.stderr)
            raise SystemExit("generated RTL is out of date -- run scripts/gen_rtl.py")
        print("  PASS  generated RTL matches rtl/gen/decoder.sv.j2")


if __name__ == "__main__":
    main()
