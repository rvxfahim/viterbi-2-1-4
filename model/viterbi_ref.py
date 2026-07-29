"""Bit-accurate Python model of the (2,1,4) encoder/decoder in ``rtl/``.

This is the golden reference: the RTL is checked against it, and the BER study
is run on it (a Monte-Carlo sweep would take days through a Verilog simulator).
Every convention below was read out of ``rtl/d_ff.sv`` and ``rtl/decoder.sv``,
including the tie-breaking rules, so the two agree bit for bit.

Code
----
Rate 1/2, constraint length K = 4, 3 memory elements, 8 trellis states.

    g1 = 1111  (octal 17)   ->  out[1]
    g0 = 1011  (octal 13)   ->  out[0]

State and transition
--------------------
``rtl/d_ff.sv`` shifts ``q0 <- d``, ``q1 <- q0``, ``q2 <- q1``, ``q3 <- q2`` and
then computes its outputs from the *post-shift* register.  Writing the
pre-shift state as ``s = (q0, q1, q2)`` with ``s2 = q0`` the newest bit:

    out1 = d ^ s2 ^ s1 ^ s0
    out0 = d ^ s2 ^ s0
    next = (d << 2) | (s >> 1)

so state ``n`` is reachable only from ``2*(n & 3)`` and ``2*(n & 3) + 1``.

Bit order
---------
The decoder takes the whole 14-bit received word in parallel as ``dat``:

    dat[13 - 2k] = out1 of message bit k
    dat[12 - 2k] = out0 of message bit k

and emits the message with ``out[6]`` = first bit, ``out[0]`` = last, because
its traceback counts ``pinOut`` up while ``table_counter`` counts down.

Tie-breaking (matched to the RTL, not to convention)
----------------------------------------------------
* ACS uses a strict ``<``, so on a metric tie the *higher-numbered*
  predecessor survives.
* The final-state scan also uses a strict ``<``, so on a tie the
  *lowest-numbered* state wins.

Termination
-----------
The block is 7 bits with no zero-tail flush, so the decoder minimises over all
8 end states rather than being forced back to state 0.  That is a property of
the original design and it costs a little coding gain -- see docs/architecture.md.
"""

from __future__ import annotations

import argparse
import sys

K = 4               # constraint length
N_STATES = 8        # 2 ** (K - 1)
MSG_BITS = 7        # fixed block length of this design
CW_BITS = 2 * MSG_BITS

#: Canonical example used throughout the repo, docs and testbenches.
CANONICAL_MSG = 0b1011000
CANONICAL_CW = 0b11110111010111
CANONICAL_ERROR_BIT = 6      # the bit tb/legacy/decoder_tb.sv deliberately flips


# ---------------------------------------------------------------------------
# Trellis
# ---------------------------------------------------------------------------

def branch_outputs(state: int, bit: int) -> tuple[int, int]:
    """(out1, out0) emitted when `bit` is clocked into `state`."""
    s2, s1, s0 = (state >> 2) & 1, (state >> 1) & 1, state & 1
    out1 = bit ^ s2 ^ s1 ^ s0          # g1 = 1111
    out0 = bit ^ s2 ^ s0               # g0 = 1011
    return out1, out0


def next_state(state: int, bit: int) -> int:
    return ((bit << 2) | (state >> 1)) & 0b111


def predecessors(state: int) -> tuple[int, int]:
    """The two states that can reach `state`, in ascending order."""
    base = 2 * (state & 0b11)
    return base, base + 1


#: transitions[s][b] = (next_state, out1, out0) -- built once, used everywhere.
TRANSITIONS = [
    [(next_state(s, b), *branch_outputs(s, b)) for b in (0, 1)]
    for s in range(N_STATES)
]


# ---------------------------------------------------------------------------
# Encoder
# ---------------------------------------------------------------------------

def encode_bits(message: list[int]) -> list[int]:
    """Encode a bit list into a flat list of 2*len(message) code bits."""
    state, out = 0, []
    for bit in message:
        nxt, out1, out0 = TRANSITIONS[state][bit]
        out += [out1, out0]
        state = nxt
    return out


def encode(message: int, n_bits: int = MSG_BITS) -> int:
    """Encode an integer message (MSB = first bit) into a codeword integer."""
    bits = [(message >> (n_bits - 1 - i)) & 1 for i in range(n_bits)]
    code = encode_bits(bits)
    word = 0
    for bit in code:
        word = (word << 1) | bit
    return word


# ---------------------------------------------------------------------------
# Decoder -- hard decision
# ---------------------------------------------------------------------------

_INF = 1 << 20


def decode_bits(received: list[int], *, trace: bool = False,
                end_state: int | None = None):
    """Viterbi-decode a flat list of 2*n received bits.

    ``end_state`` forces the traceback to start from a known final state, which
    is what a zero-tail-terminated block allows.  The RTL does not terminate,
    so it passes ``None`` and minimises over every state; the BER study uses
    the terminated variant to show what termination would buy.

    Returns the decoded bit list, or ``(bits, metrics, survivors)`` when
    ``trace`` is set -- ``metrics[k]`` holds the 8 path metrics after stage k
    and ``survivors[k][s]`` the surviving predecessor of state ``s``.
    """
    n = len(received) // 2
    metrics = [0] + [_INF] * (N_STATES - 1)      # start state is known to be 0
    survivors: list[list[int]] = []
    history: list[list[int]] = [metrics[:]]

    for k in range(n):
        r1, r0 = received[2 * k], received[2 * k + 1]
        new = [_INF] * N_STATES
        surv = [0] * N_STATES
        for state in range(N_STATES):
            lo, hi = predecessors(state)
            bit = state >> 2                     # the input bit implied by `state`
            best_pred, best_metric = None, _INF
            for pred in (lo, hi):
                if metrics[pred] >= _INF:
                    continue
                _, o1, o0 = TRANSITIONS[pred][bit]
                cand = metrics[pred] + (o1 ^ r1) + (o0 ^ r0)
                # strict `<` mirrors the RTL: on a tie the higher pred wins
                if best_pred is None or cand < best_metric:
                    best_pred, best_metric = pred, cand
            new[state] = best_metric
            surv[state] = best_pred if best_pred is not None else lo
        metrics = new
        survivors.append(surv)
        history.append(metrics[:])

    # No zero-tail flush: minimise over every end state, lowest index on a tie.
    end = (end_state if end_state is not None
           else min(range(N_STATES), key=lambda s: (metrics[s], s)))

    bits: list[int] = []
    state = end
    for k in range(n - 1, -1, -1):
        bits.append(state >> 2)                  # the input bit that entered `state`
        state = survivors[k][state]
    bits.reverse()

    return (bits, history, survivors) if trace else bits


def decode(word: int, n_bits: int = MSG_BITS) -> int:
    """Decode a codeword integer (MSB first) into a message integer."""
    received = [(word >> (2 * n_bits - 1 - i)) & 1 for i in range(2 * n_bits)]
    bits = decode_bits(received)
    msg = 0
    for bit in bits:
        msg = (msg << 1) | bit
    return msg


def decode_soft(llrs: list[float]) -> list[int]:
    """Soft-decision Viterbi over per-bit log-likelihood ratios.

    Sign convention: ``llr > 0`` favours a transmitted 0.  Included so the BER
    study can quantify what the hard-decision RTL leaves on the table
    (~2 dB for this code); the RTL itself is hard-decision only.
    """
    n = len(llrs) // 2
    metrics = [0.0] + [float(_INF)] * (N_STATES - 1)
    survivors = []

    for k in range(n):
        l1, l0 = llrs[2 * k], llrs[2 * k + 1]
        new = [float(_INF)] * N_STATES
        surv = [0] * N_STATES
        for state in range(N_STATES):
            lo, hi = predecessors(state)
            bit = state >> 2
            best_pred, best_metric = None, float(_INF)
            for pred in (lo, hi):
                if metrics[pred] >= _INF:
                    continue
                _, o1, o0 = TRANSITIONS[pred][bit]
                cand = (metrics[pred]
                        + (l1 if o1 else -l1)
                        + (l0 if o0 else -l0))
                if best_pred is None or cand < best_metric:
                    best_pred, best_metric = pred, cand
            new[state] = best_metric
            surv[state] = best_pred if best_pred is not None else lo
        metrics = new
        survivors.append(surv)

    end = min(range(N_STATES), key=lambda s: (metrics[s], s))
    bits, state = [], end
    for k in range(n - 1, -1, -1):
        bits.append(state >> 2)
        state = survivors[k][state]
    bits.reverse()
    return bits


# ---------------------------------------------------------------------------
# Zero-tail terminated variant  (rtl/decoder_term.sv)
# ---------------------------------------------------------------------------
#
# Clocking K-1 = 3 zeros in after the message drives the register back to state
# 0, so the decoder knows where the survivor ends and never has to guess.  The
# code is still (2,1,4) -- only the block framing changes:
#
#     7 message bits  ->  10 trellis stages  ->  20 code bits
#
# It costs rate (7/20 rather than 7/14) and buys back the protection the last
# message bits were missing.

TAIL_BITS = K - 1
TERM_MSG_BITS = MSG_BITS
TERM_STAGES = MSG_BITS + TAIL_BITS
TERM_CW_BITS = 2 * TERM_STAGES


def encode_terminated(message: int, n_bits: int = MSG_BITS) -> int:
    """Encode with a zero tail: `n_bits` message bits -> 2*(n_bits+3) code bits."""
    bits = [(message >> (n_bits - 1 - i)) & 1 for i in range(n_bits)]
    bits += [0] * TAIL_BITS
    word = 0
    for bit in encode_bits(bits):
        word = (word << 1) | bit
    return word


def decode_terminated(word: int, n_bits: int = MSG_BITS) -> int:
    """Decode a terminated codeword, tracing back from the known end state 0."""
    total = 2 * (n_bits + TAIL_BITS)
    received = [(word >> (total - 1 - i)) & 1 for i in range(total)]
    bits = decode_bits(received, end_state=0)[:n_bits]     # drop the tail
    msg = 0
    for bit in bits:
        msg = (msg << 1) | bit
    return msg


def trellis_trace(word: int = CANONICAL_CW, n_bits: int = MSG_BITS,
                  end_state: int | None = None):
    """Metrics + survivors for plotting, plus the surviving state path.

    ``n_bits`` is the number of trellis *stages*, so a terminated block passes
    10 rather than 7, together with ``end_state=0``.
    """
    received = [(word >> (2 * n_bits - 1 - i)) & 1 for i in range(2 * n_bits)]
    bits, history, survivors = decode_bits(received, trace=True,
                                           end_state=end_state)

    final = history[-1]
    end = (end_state if end_state is not None
           else min(range(N_STATES), key=lambda s: (final[s], s)))
    path = [end]
    state = end
    for k in range(n_bits - 1, -1, -1):
        state = survivors[k][state]
        path.append(state)
    path.reverse()
    return {"bits": bits, "metrics": history, "survivors": survivors, "path": path}


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

def self_test() -> int:
    fails = 0

    def check(name: str, got, want) -> None:
        nonlocal fails
        if got == want:
            print(f"  PASS  {name}")
        else:
            fails += 1
            print(f"  FAIL  {name}: got {got!r}, want {want!r}")

    check("encode(canonical message)",
          f"{encode(CANONICAL_MSG):014b}", f"{CANONICAL_CW:014b}")
    check("decode(canonical codeword)",
          f"{decode(CANONICAL_CW):07b}", f"{CANONICAL_MSG:07b}")

    # The legacy testbench's deliberately corrupted word must still decode.
    corrupted = CANONICAL_CW ^ (1 << CANONICAL_ERROR_BIT)
    check(f"decode(canonical codeword with dat[{CANONICAL_ERROR_BIT}] flipped)",
          f"{decode(corrupted):07b}", f"{CANONICAL_MSG:07b}")

    bad = [m for m in range(128) if decode(encode(m)) != m]
    check("round-trip over all 128 messages, clean channel", bad, [])

    # Single-bit error correction over the whole message space.
    total = corrected = 0
    for m in range(128):
        cw = encode(m)
        for pos in range(CW_BITS):
            total += 1
            corrected += decode(cw ^ (1 << pos)) == m
    pct = 100.0 * corrected / total
    print(f"  INFO  single-bit errors corrected: {corrected}/{total} ({pct:.1f}%)")
    if corrected < total:
        print("        (< 100% is expected: the 7-bit block has no zero-tail "
              "flush, so errors in the last bits are not fully protected)")

    # ---- terminated variant (rtl/decoder_term.sv) --------------------------
    bad = [m for m in range(128) if decode_terminated(encode_terminated(m)) != m]
    check("terminated round-trip over all 128 messages", bad, [])

    total = corrected = 0
    weak = []
    for m in range(128):
        cw = encode_terminated(m)
        for pos in range(TERM_CW_BITS):
            total += 1
            ok = decode_terminated(cw ^ (1 << pos)) == m
            corrected += ok
            if not ok:
                weak.append(pos)
    check("terminated: every single-bit error corrected",
          f"{corrected}/{total}", f"{total}/{total}")
    if weak:
        print(f"        uncorrected at codeword bit positions {sorted(set(weak))}")

    print(f"\n  {'all checks passed' if not fails else f'{fails} FAILURES'}")
    return fails


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--self-test", action="store_true")
    p.add_argument("--encode", metavar="BITS", help="7-bit message, e.g. 1011000")
    p.add_argument("--decode", metavar="BITS", help="14-bit codeword")
    args = p.parse_args()

    if args.encode:
        print(f"{encode(int(args.encode, 2)):014b}")
    if args.decode:
        print(f"{decode(int(args.decode, 2)):07b}")
    if args.self_test or not (args.encode or args.decode):
        sys.exit(1 if self_test() else 0)


if __name__ == "__main__":
    main()
