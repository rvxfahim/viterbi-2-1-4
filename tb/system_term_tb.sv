// ---------------------------------------------------------------------------
// system_term_tb -- end-to-end regression for the zero-tail terminated decoder
//
// Same sweep as system_tb, against rtl/decoder_term.sv.  The encoder is
// unchanged -- rtl/d_ff.sv is still the (2,1,4) encoder and needs no edit;
// terminating simply means clocking K-1 = 3 more zeros through it after the
// message, which drives the shift register back to state 0.  That costs rate
// (7 message bits now occupy 20 code bits rather than 14) and buys the last
// message bits the protection they were missing.
//
// 128 messages x {clean, single-bit error at 0..19} = 2688 cases.
//
// Pass criteria (both enforced -- unlike system_tb, nothing here is merely
// reported):
//   * clean channel -> 128/128
//   * 1-bit error   -> 2560/2560.  A terminated (2,1,4) code has free distance
//                      6 and so corrects any single error anywhere in the
//                      block; model/viterbi_ref.decode_terminated agrees.
//
//   +CSV=<path>   pass/fail grid
//   +VCD=<path>   waveform output
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module system_term_tb;

  localparam int MSG_BITS        = 7;
  localparam int TAIL_BITS       = 3;                      // K - 1 flush bits
  localparam int STAGES          = MSG_BITS + TAIL_BITS;   // 10
  localparam int CW_BITS         = 2 * STAGES;             // 20
  localparam int TRELLIS_CYCLES  = 69;                     // 1 + 4 + 8 + 8*(STAGES-3)
  localparam int TRACEBACK_CYCLES = STAGES + 1;            // 11

  logic clk = 1'b0;

  // encoder
  logic       enc_reset;
  logic       d;
  wire  [3:0] q;
  wire  [1:0] enc_out;

  // decoder
  logic              dec_reset;
  logic              ready;
  logic [CW_BITS-1:0] dat;
  wire  [MSG_BITS-1:0] out;

  logic [MSG_BITS-1:0] msg, expected;
  logic [CW_BITS-1:0]  cw, rx;
  string       csv_file, vcd_file;
  int          fd;
  int          clean_pass, clean_total, err_pass, err_total;

  always #5 clk = ~clk;

  d_ff         enc (clk, enc_reset, q, d, enc_out);
  decoder_term dec (clk, dec_reset, dat, out, ready);

  // -------------------------------------------------------------------------
  // Encode `msg` into `cw`, flushing the register with TAIL_BITS zeros.
  // All DUT inputs are driven on negedge: driving them at the active edge
  // races the DUT's blocking assignments.
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
    csv_file = "results/ber/rtl_sweep_term.csv";
    vcd_file = "system_term_tb.vcd";
    void'($value$plusargs("CSV=%s", csv_file));
    void'($value$plusargs("VCD=%s", vcd_file));

    $dumpfile(vcd_file);
    $dumpvars(0, system_term_tb);

    fd = $fopen(csv_file, "w");
    if (fd == 0) $fatal(1, "system_term_tb: cannot open %s", csv_file);
    $fwrite(fd, "message,error_bit,codeword,received,decoded,pass\n");

    clean_pass = 0; clean_total = 0;
    err_pass   = 0; err_total   = 0;

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

    $fclose(fd);

    $display("SUMMARY  clean channel  : %0d/%0d", clean_pass, clean_total);
    $display("SUMMARY  1-bit errors   : %0d/%0d (%0.1f%%)",
             err_pass, err_total, 100.0 * err_pass / err_total);
    $display("SUMMARY  grid written to %s", csv_file);

    if (clean_pass != clean_total) begin
      $display("RESULT   FAIL -- clean channel must be error free");
      $fatal(1, "system_term_tb: clean-channel regression failed");
    end
    if (err_pass != err_total) begin
      $display("RESULT   FAIL -- a terminated trellis must correct every single-bit error");
      $fatal(1, "system_term_tb: single-error regression failed");
    end
    $display("RESULT   PASS");
    $finish;
  end

  initial begin
    #400000000;
    $fatal(1, "system_term_tb: timeout");
  end

endmodule
