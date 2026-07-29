// ---------------------------------------------------------------------------
// decoder_folded_gen_tb -- the folded decoder at any block length, over a
// real channel.
//
// Why this bench exists
// ---------------------
// tb/system_folded_tb.sv pins rtl/decoder_folded.sv to 7 message bits, and
// scripts/check_long.py exercises long blocks only on the *generated*
// (unrolled) decoder.  So the folded decoder had been synthesised at 20, 40
// and 100 message bits but never simulated past 7, and the long-block coding
// gain the README quotes came from model/ber_sweep.py rather than from RTL.
// This bench closes both gaps with one parameterised source.
//
// MSG_BITS is set with verilator -GMSG_BITS=N.  Nothing else changes: the
// folded decoder needs no per-stage code, so unlike the generated decoder
// there is no RTL to re-render for a new length.
//
// Two modes, chosen by +PPM:
//
//   +PPM=0  (default)  inject exactly +ERRORS bit errors per frame at uniform
//                      random positions.  Every frame is written to +GRID and
//                      scripts/check_folded.py compares each one against
//                      model/viterbi_ref.decode_terminated -- the long-block
//                      equivalence check.
//
//   +PPM=n             binary symmetric channel, crossover probability
//                      n / 1e6.  Hard-decision BPSK over AWGN *is* a BSC with
//                      p = Q(sqrt(2*R*Eb/N0)) -- see model/ber_sweep.py's
//                      awgn branch, which draws sigma = sqrt(1/(2*R*Eb/N0))
//                      and then thresholds at zero -- so a BSC run at that p
//                      is directly comparable to the model's AWGN curve at
//                      that Eb/N0.  Only aggregate counts are written.
//
// Plusargs
//   +MSGCSV=<path>   aggregate row: one line of counts for this run
//   +GRID=<path>     per-frame grid (mode 1 only; omit to skip)
//   +FRAMES=<n>      frames to run            (default 200)
//   +ERRORS=<n>      injected errors/frame    (default 1, mode 1 only)
//   +PPM=<n>         BSC crossover x 1e-6     (default 0 = mode 1)
//   +SEED=<n>        $urandom seed            (default derived from MSG_BITS)
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module decoder_folded_gen_tb #(
    parameter int MSG_BITS = 20
);

  localparam int TAIL_BITS = 3;                       // K - 1 flush bits
  localparam int STAGES    = MSG_BITS + TAIL_BITS;
  localparam int CW_BITS   = 2 * STAGES;

  // The whole point of the folded architecture: one clock per trellis stage
  // and one per traceback step, independent of MSG_BITS.  The generated
  // decoder needs 1 + 4 + 8*(STAGES-2) for the same trellis.
  localparam int TRELLIS_CYCLES   = STAGES;
  localparam int TRACEBACK_CYCLES = STAGES;

  localparam int PPM_SCALE = 1000000;

  logic clk = 1'b0;

  logic       enc_reset;
  logic       d;
  wire  [3:0] q;
  wire  [1:0] enc_out;

  logic                dec_reset;
  logic                ready;
  logic [CW_BITS-1:0]  dat;
  wire  [MSG_BITS-1:0] out;

  logic [MSG_BITS-1:0] msg;
  logic [CW_BITS-1:0]  cw, rx;

  string csv_file, grid_file;
  int    fd, gd;
  int    frames, errors, ppm, seed;
  int    frame_errors;
  logic [31:0] draw;
  longint bit_errors, total_bits, flipped;

  always #5 clk = ~clk;

  d_ff           enc (clk, enc_reset, q, d, enc_out);
  decoder_folded #(.MSG_BITS(MSG_BITS)) dec (clk, dec_reset, dat, out, ready);

  // -------------------------------------------------------------------------
  // Encode `msg` into `cw`, flushing with TAIL_BITS zeros.  Byte-identical to
  // system_folded_tb.do_encode; rtl/d_ff.sv is the same encoder at every
  // block length, because the tail is a property of the framing, not the
  // encoder.
  // -------------------------------------------------------------------------
  task automatic do_encode();
    @(negedge clk);
    enc_reset = 1'b0;
    d         = 1'b0;
    @(posedge clk);
    for (int k = 0; k < STAGES; k++) begin
      @(negedge clk);
      enc_reset = 1'b1;
      d         = (k < MSG_BITS) ? msg[MSG_BITS - 1 - k] : 1'b0;
      @(posedge clk);
      #1;
      cw[CW_BITS - 1 - 2 * k] = enc_out[1];
      cw[CW_BITS - 2 - 2 * k] = enc_out[0];
    end
  endtask

  task automatic do_decode();
    @(negedge clk);
    dec_reset = 1'b0;
    ready     = 1'b0;
    dat       = rx;
    @(posedge clk);

    @(negedge clk);
    dec_reset = 1'b1;
    repeat (TRELLIS_CYCLES) @(posedge clk);
    @(negedge clk);
    ready = 1'b1;
    repeat (TRACEBACK_CYCLES) @(posedge clk);
    @(negedge clk);
  endtask

  function automatic int popcount(input logic [MSG_BITS-1:0] v);
    int n = 0;
    for (int i = 0; i < MSG_BITS; i++) n += int'(v[i]);
    return n;
  endfunction

  initial begin
    csv_file  = "";
    grid_file = "";
    frames    = 200;
    errors    = 1;
    ppm       = 0;
    seed      = 32'hF01D_0000 + MSG_BITS;
    void'($value$plusargs("MSGCSV=%s", csv_file));
    void'($value$plusargs("GRID=%s", grid_file));
    void'($value$plusargs("FRAMES=%d", frames));
    void'($value$plusargs("ERRORS=%d", errors));
    void'($value$plusargs("PPM=%d", ppm));
    void'($value$plusargs("SEED=%d", seed));

    gd = 0;
    if (grid_file != "") begin
      gd = $fopen(grid_file, "w");
      if (gd == 0) $fatal(1, "decoder_folded_gen_tb: cannot open %s", grid_file);
      $fwrite(gd, "msg_bits,message,received,decoded,pass\n");
    end

    bit_errors   = 0;
    total_bits   = 0;
    frame_errors = 0;
    flipped      = 0;

    void'($urandom(seed));                 // seed once, then free-run

    for (int f = 0; f < frames; f++) begin
      for (int w = 0; w < MSG_BITS; w++) msg[w] = 1'($urandom);
      do_encode();

      rx = cw;
      if (ppm == 0) begin
        // Fixed error count: the equivalence mode.  Positions may repeat,
        // exactly as decoder_gen_tb does it, so a frame can end up with
        // fewer than `errors` distinct flips -- that is fine, the model sees
        // the same received word either way.
        for (int e = 0; e < errors; e++)
          rx ^= CW_BITS'(1) << ($urandom % CW_BITS);
      end else begin
        // Binary symmetric channel, independent per code bit.
        //
        // `draw` is not a convenience: Verilator 5.050 hoists a bare
        // `$urandom` out of a loop when it appears directly in an `if`
        // condition, so `if (($urandom % PPM_SCALE) < ppm)` draws *once per
        // frame* and flips either all 20 code bits or none.  That reproduces
        // a plausible-looking BER (the frame-error rate lands on p) and is
        // invisible in the frame counts.  Assigning to a variable first
        // forces the call per iteration.  The `rx ^= 1 << ($urandom % N)`
        // form used by the other benches is evaluated correctly.
        for (int b = 0; b < CW_BITS; b++) begin
          draw = $urandom;
          if ((draw % PPM_SCALE) < ppm) begin
            rx[b] ^= 1'b1;
            flipped++;
          end
        end
      end

      do_decode();

      if (gd != 0)
        $fwrite(gd, "%0d,%b,%b,%b,%0d\n", MSG_BITS, msg, rx, out, (out === msg));

      bit_errors += popcount(out ^ msg);
      total_bits += MSG_BITS;
      if (out !== msg) frame_errors++;
    end

    if (gd != 0) $fclose(gd);

    if (csv_file != "") begin
      fd = $fopen(csv_file, "w");
      if (fd == 0) $fatal(1, "decoder_folded_gen_tb: cannot open %s", csv_file);
      $fwrite(fd, "msg_bits,ppm,frames,bit_errors,total_bits,frame_errors,flipped\n");
      $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
              MSG_BITS, ppm, frames, bit_errors, total_bits, frame_errors, flipped);
      $fclose(fd);
    end

    $display("SUMMARY  MSG_BITS=%0d  %0d stages  %0d trellis + %0d traceback clocks",
             MSG_BITS, STAGES, TRELLIS_CYCLES, TRACEBACK_CYCLES);
    if (ppm == 0)
      $display("SUMMARY  %0d/%0d frames decoded correctly, %0d error(s) each",
               frames - frame_errors, frames, errors);
    else
      $display("SUMMARY  ppm=%0d  %0d/%0d message bit errors, %0d/%0d frames wrong",
               ppm, bit_errors, total_bits, frame_errors, frames);
    $finish;
  end

  initial begin
    #20000000000;
    $fatal(1, "decoder_folded_gen_tb: timeout");
  end

endmodule
