"""Cross-check the RTL sweep results against model/viterbi_ref.py.

The RTL and the Python model were written from the same specification but
independently; agreeing on all 128 codewords and all 1920 decode outcomes is
what makes either of them trustworthy.  Run after `run_all.py sim` and
`run_all.py sweep`.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from model import viterbi_ref as ref  # noqa: E402

BER_DIR = REPO / "results" / "ber"
GREEN, RED, YELLOW, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[0m"


def check_encoder() -> int:
    path = BER_DIR / "rtl_encoder.csv"
    if not path.exists():
        print(f"  {YELLOW}SKIP{RESET}  {path.name} missing "
              f"(run: python scripts/run_all.py sim --only encoder_bench)")
        return 0

    bad = []
    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            msg = int(row["message"], 2)
            rtl = int(row["codeword"], 2)
            want = ref.encode(msg)
            if rtl != want:
                bad.append((msg, rtl, want))

    if bad:
        print(f"  {RED}FAIL{RESET}  encoder: {len(bad)}/128 codewords disagree "
              f"with the model")
        for msg, rtl, want in bad[:5]:
            print(f"          msg={msg:07b}  rtl={rtl:014b}  model={want:014b}")
        return 1

    print(f"  {GREEN}PASS{RESET}  encoder: all 128 RTL codewords match "
          f"model/viterbi_ref.encode()")
    return 0


def check_decoder() -> int:
    path = BER_DIR / "rtl_sweep.csv"
    if not path.exists():
        print(f"  {YELLOW}SKIP{RESET}  {path.name} missing "
              f"(run: python scripts/run_all.py sweep)")
        return 0

    mismatches, clean_fail = [], []
    total = 0
    with path.open(newline="") as fh:
        for row in csv.DictReader(fh):
            total += 1
            msg = int(row["message"], 2)
            rx = int(row["received"], 2)
            rtl_out = int(row["decoded"], 2)
            model_out = ref.decode(rx)
            if rtl_out != model_out:
                mismatches.append((row["message"], row["error_bit"],
                                   rtl_out, model_out))
            if int(row["error_bit"]) < 0 and rtl_out != msg:
                clean_fail.append(row["message"])

    rc = 0
    if mismatches:
        print(f"  {RED}FAIL{RESET}  decoder: {len(mismatches)}/{total} cases "
              f"where RTL and model disagree")
        for m, e, r, w in mismatches[:5]:
            print(f"          msg={m} err={e:>3}  rtl={r:07b}  model={w:07b}")
        rc = 1
    else:
        print(f"  {GREEN}PASS{RESET}  decoder: RTL and model agree on all "
              f"{total} decode cases")

    if clean_fail:
        print(f"  {RED}FAIL{RESET}  clean channel: {len(clean_fail)} messages "
              f"decoded incorrectly")
        rc = 1
    return rc


def main() -> None:
    print("Cross-checking RTL against the Python golden model")
    rc = check_encoder() + check_decoder()
    if rc:
        raise SystemExit(rc)


if __name__ == "__main__":
    main()
