// ---------------------------------------------------------------------------
// system_tb -- end-to-end encoder -> channel -> decoder regression
//
// For every one of the 128 seven-bit messages, and for every channel in
// {clean, single-bit error at position 0..13}, this bench encodes with
// rtl/d_ff.sv, optionally flips one codeword bit, decodes with rtl/decoder.sv
// and checks the result.  1920 cases in total; the pass/fail grid is written
// to CSV and rendered as docs/img/error_correction_heatmap.png.
//
// Pass criteria (enforced here):
//   * clean channel  -> must be 128/128.  Any failure is a real bug.
//   * 1-bit error    -> reported, not asserted.  The 7-bit block carries no
//                       zero-tail flush, so errors near the end of the word
//                       are not fully protected.  model/viterbi_ref.py
//                       independently predicts 1536/1792 = 85.7%.
//
//   +CSV=<path>   pass/fail grid
//   +VCD=<path>   waveform output (large -- one full sweep)
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module system_tb;

  localparam int TRELLIS_CYCLES   = 45;
  localparam int TRACEBACK_CYCLES = 8;
  localparam int CW_BITS          = 14;

  logic clk = 1'b0;

  // encoder
  logic       enc_reset;
  logic       d;
  wire  [3:0] q;
  wire  [1:0] enc_out;

  // decoder
  logic        dec_reset;
  logic        ready;
  logic [13:0] dat;
  wire  [6:0]  out;

  logic [6:0]  msg, expected;
  logic [13:0] cw, rx;
  string       csv_file, vcd_file;
  int          fd;
  int          clean_pass, clean_total, err_pass, err_total;

  always #5 clk = ~clk;

  d_ff    enc (clk, enc_reset, q, d, enc_out);
  decoder dec (clk, dec_reset, dat, out, ready);

  // -------------------------------------------------------------------------
  // Encode `msg` into `cw`.
  // -------------------------------------------------------------------------
  task automatic do_encode();
    @(negedge clk);
    enc_reset = 1'b0;
    d         = 1'b0;
    @(posedge clk);
    for (int k = 0; k < 7; k++) begin
      @(negedge clk);
      enc_reset = 1'b1;
      d         = msg[6 - k];
      @(posedge clk);
      #1;
      cw[13 - 2 * k] = enc_out[1];
      cw[12 - 2 * k] = enc_out[0];
    end
  endtask

  // -------------------------------------------------------------------------
  // Decode `rx` into `out`.
  //
  // This used to need a cross-module reference to zero dec.counter_for_path,
  // because the original RTL never cleared it on reset and so decoded exactly
  // one word per power-on.  The generated decoder clears it, so reset alone is
  // now enough and the sweep exercises that -- 1920 decodes back to back with
  // nothing but reset between them.  See docs/known-issues.md #1.
  // -------------------------------------------------------------------------
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
    csv_file = "results/ber/rtl_sweep.csv";
    vcd_file = "system_tb.vcd";
    void'($value$plusargs("CSV=%s", csv_file));
    void'($value$plusargs("VCD=%s", vcd_file));

    $dumpfile(vcd_file);
    $dumpvars(0, system_tb);

    fd = $fopen(csv_file, "w");
    if (fd == 0) $fatal(1, "system_tb: cannot open %s", csv_file);
    $fwrite(fd, "message,error_bit,codeword,received,decoded,pass\n");

    clean_pass = 0; clean_total = 0;
    err_pass   = 0; err_total   = 0;

    for (int m = 0; m < 128; m++) begin
      msg      = m[6:0];
      expected = m[6:0];
      do_encode();

      // error_bit = -1 is the clean channel; 0..13 flip that codeword bit.
      for (int e = -1; e < CW_BITS; e++) begin
        rx = (e < 0) ? cw : (cw ^ (14'b1 << e));
        do_decode();

        $fwrite(fd, "%07b,%0d,%014b,%014b,%07b,%0d\n",
                msg, e, cw, rx, out, (out === expected));

        if (e < 0) begin
          clean_total++;
          if (out === expected) clean_pass++;
          else $display("FAIL  clean  msg=%07b cw=%014b out=%07b", msg, cw, out);
        end else begin
          err_total++;
          if (out === expected) err_pass++;
        end
      end
    end

    $fclose(fd);

    $display("SUMMARY  clean channel  : %0d/%0d", clean_pass, clean_total);
    $display("SUMMARY  1-bit errors   : %0d/%0d (%0.1f%%)",
             err_pass, err_total, 100.0 * err_pass / err_total);
    $display("SUMMARY  grid written to %s", csv_file);

    if (clean_pass != clean_total) begin
      $display("RESULT   FAIL -- clean channel must be error free");
      $fatal(1, "system_tb: clean-channel regression failed");
    end
    $display("RESULT   PASS");
    $finish;
  end

  initial begin
    #200000000;
    $fatal(1, "system_tb: timeout");
  end

endmodule
