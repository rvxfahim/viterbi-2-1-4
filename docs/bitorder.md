# Bit ordering

Read this before wiring anything to either module. None of it is documented in
the original sources; it was recovered by simulation and is now locked down by
`tb/encoder_bench.sv` and `tb/system_tb.sv`, which fail if any of it changes.

## Codeword layout

The encoder emits two bits per message bit; the decoder wants all 14 at once on
`dat`, most significant pair first:

```
message bit k (k = 0 is the FIRST bit transmitted)

    dat[13 - 2k]  =  out[1]   the g1 = 1111 parity
    dat[12 - 2k]  =  out[0]   the g0 = 1011 parity
```

So for the canonical message `1011000`:

| k | message bit | state before | (g1 g0) | `dat` bits |
|---|---|---|---|---|
| 0 | 1 | 000 | 1 1 | `dat[13:12]` |
| 1 | 0 | 100 | 1 1 | `dat[11:10]` |
| 2 | 1 | 010 | 0 1 | `dat[9:8]` |
| 3 | 1 | 101 | 1 1 | `dat[7:6]` |
| 4 | 0 | 110 | 0 1 | `dat[5:4]` |
| 5 | 0 | 011 | 0 1 | `dat[3:2]` |
| 6 | 0 | 001 | 1 1 | `dat[1:0]` |

giving `dat = 14'b11_11_01_11_01_01_11` = `11110111010111`.

## Decoder output

Traceback walks `table_counter` down from 7 while `pinOut` counts up from 0, so
the message comes out **reversed relative to `pinOut`**:

```
out[6]  =  first message bit
out[0]  =  last message bit
```

Printing `%b` of `out[6:0]` therefore shows the message in transmission order —
`1011000` for the vector above.

## State numbering

`s = (q0, q1, q2)` with `s2 = q0` the most recently shifted-in bit:

```
next_state = (d << 2) | (s >> 1)
predecessors(n) = { 2*(n & 3),  2*(n & 3) + 1 }
```

Note this is *not* the same numbering the C++ reference prints in its traceback
log; the decoded bits agree, the intermediate state labels do not. Do not try
to match them line for line.

## The error the legacy testbench injects

`tb/legacy/decoder_tb.sv` flips `dat[6]` — the g1 parity of message bit 3 —
turning the pair `11` into `10`. The decoder still returns `1011000`, which is
the demonstration the original project was built around.

## Where this is enforced

* `tb/encoder_bench.sv` writes all 128 codewords to CSV;
  `scripts/check_rtl.py` compares every one against `model/viterbi_ref.encode()`.
* `tb/system_tb.sv` drives the encoder into the decoder for all 128 messages
  and all 15 channel conditions and self-checks the round trip.

If either convention above is wrong, both of those fail immediately.
