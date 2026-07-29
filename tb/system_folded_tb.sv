// ---------------------------------------------------------------------------
// system_folded_tb -- end-to-end regression for the folded decoder
//
// Same encoder, same code, same pass criteria as system_term_tb.sv, against
// rtl/decoder_folded.sv.  rtl/d_ff.sv is unchanged: folding is a decoder
// architecture change and nothing about the encoding moves.
//
// Two phases:
//
//   1. 128 messages x {clean, single-bit error at 0..19} = 2688 cases.
//      Enforced here, exactly as system_term_tb enforces them:
//        * clean channel -> 128/128
//        * 1-bit error   -> 2560/2560, since a terminated (2,1,4) code has
//                           free distance 6.
//
//   2. 512 random three-error words, recorded with error_bit = -2 and *not*
//      enforced -- three errors are beyond the code's correcting power, so
//      the decoder is entitled to get them wrong.  What matters is that it
//      gets them wrong in exactly the way model/viterbi_ref.py does, which
//      scripts/check_rtl.py checks.
//
//      This phase exists because the single-error sweep cannot see an
//      add-compare-select tie: the two possible tie rules agree on all 4608
//      exhaustive single-error cases across both decoders, which is how an
//      inverted tie-break sat undetected in the golden model.  Ties appear
//      from three errors up.  See docs/known-issues.md #6.
//
//   +CSV=<path>   pass/fail grid
//   +VCD=<path>   waveform output
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module system_folded_tb;

  localparam int MSG_BITS         = 7;
  localparam int TAIL_BITS        = 3;                      // K - 1 flush bits
  localparam int STAGES           = MSG_BITS + TAIL_BITS;   // 10
  localparam int CW_BITS          = 2 * STAGES;             // 20

  // One clock per trellis stage, one per traceback step.  system_term_tb
  // needs 69 + 11 for the same trellis.
  localparam int TRELLIS_CYCLES   = STAGES;                 // 10
  localparam int TRACEBACK_CYCLES = STAGES;                 // 10

  localparam int RANDOM_FRAMES    = 512;
  localparam int RANDOM_ERRORS    = 3;
  localparam int RANDOM_SEED      = 32'h5EED_1011;

  logic clk = 1'b0;

  // encoder
  logic       enc_reset;
  logic       d;
  wire  [3:0] q;
  wire  [1:0] enc_out;

  // decoder
  logic                dec_reset;
  logic                ready;
  logic [CW_BITS-1:0]  dat;
  wire  [MSG_BITS-1:0] out;

  logic [MSG_BITS-1:0] msg, expected;
  logic [CW_BITS-1:0]  cw, rx;
  string       csv_file, vcd_file;
  int          fd;
  int          clean_pass, clean_total, err_pass, err_total;
  int          rand_total;
  int          seed;

  always #5 clk = ~clk;

  d_ff           enc (clk, enc_reset, q, d, enc_out);
  decoder_folded #(.MSG_BITS(MSG_BITS)) dec (clk, dec_reset, dat, out, ready);

  // -------------------------------------------------------------------------
  // Encode `msg` into `cw`, flushing the register with TAIL_BITS zeros.
  // Identical to system_term_tb.do_encode -- the encoder is not what changed.
  // -------------------------------------------------------------------------
  task automatic do_encode();
    @(negedge clk);
    enc_reset = 1'b0;
    d         = 1'b0;
    @(posedge clk);
    for (int k = 0; k < STAGES; k++) begin
      @(negedge clk);
      enc_reset = 1'b1;
      d         = (k < MSG_BITS) ? msg[MSG_BITS - 1 - k] : 1'b0;   // zero tail
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

  initial begin
    csv_file = "results/ber/rtl_sweep_folded.csv";
    vcd_file = "system_folded_tb.vcd";
    void'($value$plusargs("CSV=%s", csv_file));
    void'($value$plusargs("VCD=%s", vcd_file));

    $dumpfile(vcd_file);
    $dumpvars(0, system_folded_tb);

    fd = $fopen(csv_file, "w");
    if (fd == 0) $fatal(1, "system_folded_tb: cannot open %s", csv_file);
    $fwrite(fd, "message,error_bit,codeword,received,decoded,pass\n");

    clean_pass = 0; clean_total = 0;
    err_pass   = 0; err_total   = 0;
    rand_total = 0;

    // ---- phase 1: exhaustive single-error sweep ---------------------------
    for (int m = 0; m < 128; m++) begin
      msg      = m[MSG_BITS-1:0];
      expected = m[MSG_BITS-1:0];
      do_encode();

      for (int e = -1; e < CW_BITS; e++) begin
        rx = (e < 0) ? cw : (cw ^ (CW_BITS'(1) << e));
        do_decode();

        $fwrite(fd, "%07b,%0d,%020b,%020b,%07b,%0d\n",
                msg, e, cw, rx, out, (out === expected));

        if (e < 0) begin
          clean_total++;
          if (out === expected) clean_pass++;
          else $display("FAIL  clean  msg=%07b cw=%020b out=%07b", msg, cw, out);
        end else begin
          err_total++;
          if (out === expected) err_pass++;
          else $display("FAIL  bit%0d  msg=%07b rx=%020b out=%07b", e, msg, rx, out);
        end
      end
    end

    // ---- phase 2: random three-error words, tie-break exposure -------------
    // Fixed seed so the CSV is reproducible and reviewable in a diff.
    seed = RANDOM_SEED;
    for (int f = 0; f < RANDOM_FRAMES; f++) begin
      msg      = MSG_BITS'($urandom(seed));
      expected = msg;
      seed     = 0;                       // seed only the first draw
      do_encode();

      rx = cw;
      for (int e = 0; e < RANDOM_ERRORS; e++)
        rx ^= CW_BITS'(1) << ($urandom % CW_BITS);
      do_decode();

      // error_bit = -2 marks "multiple errors, correction not required".
      $fwrite(fd, "%07b,-2,%020b,%020b,%07b,%0d\n",
              msg, cw, rx, out, (out === expected));
      rand_total++;
    end

    $fclose(fd);

    $display("SUMMARY  clean channel  : %0d/%0d", clean_pass, clean_total);
    $display("SUMMARY  1-bit errors   : %0d/%0d (%0.1f%%)",
             err_pass, err_total, 100.0 * err_pass / err_total);
    $display("SUMMARY  3-bit errors   : %0d recorded for model cross-check",
             rand_total);
    $display("SUMMARY  grid written to %s", csv_file);

    if (clean_pass != clean_total) begin
      $display("RESULT   FAIL -- clean channel must be error free");
      $fatal(1, "system_folded_tb: clean-channel regression failed");
    end
    if (err_pass != err_total) begin
      $display("RESULT   FAIL -- a terminated trellis must correct every single-bit error");
      $fatal(1, "system_folded_tb: single-error regression failed");
    end
    $display("RESULT   PASS");
    $finish;
  end

  initial begin
    #400000000;
    $fatal(1, "system_folded_tb: timeout");
  end

endmodule
