// ---------------------------------------------------------------------------
// decoder_gen_tb -- random-frame bench for a *generated* decoder of any length
//
// The other benches all hard-code 7 message bits.  This one takes MSG_BITS as
// a parameter (set with verilator -GMSG_BITS=N) so the same source drives the
// 20- and 40-message-bit variants that scripts/gen_rtl.py --msg-bits emits.
// It exists to prove the three width constants really do derive from the stage
// count now: at 20 message bits the old `bit [3:0] currentTable` silently
// truncated a table_counter of 23 to 7 and traceback returned garbage.
//
// There is no golden model inside the simulator, so this writes every frame to
// CSV and scripts/check_long.py does the comparison against
// model/viterbi_ref.decode_terminated.
//
//   +CSV=<path>      frame grid
//   +FRAMES=<n>      how many random frames (default 200)
//   +ERRORS=<n>      bit errors injected per frame (default 1)
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module decoder_gen_tb #(
    parameter int MSG_BITS = 20
);

  localparam int TAIL_BITS = 3;
  localparam int STAGES    = MSG_BITS + TAIL_BITS;
  localparam int CW_BITS   = 2 * STAGES;

  // The generated sequencer spends one clock on stage 1, then one per
  // reachable target state: the trellis opens 2 -> 4 -> 8, so stage 2 costs 4
  // and every stage from 3 on costs 8.  Matches gen_rtl.py's trellis_cycles.
  localparam int TRELLIS_CYCLES   = 1 + 4 + 8 * (STAGES - 2);
  localparam int TRACEBACK_CYCLES = STAGES + 1;

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
  string  csv_file;
  int     fd, frames, errors, seed, ok;

  always #5 clk = ~clk;

  d_ff         enc (clk, enc_reset, q, d, enc_out);
  decoder_term dec (clk, dec_reset, dat, out, ready);

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

  initial begin
    csv_file = "results/ber/rtl_long.csv";
    frames   = 200;
    errors   = 1;
    void'($value$plusargs("CSV=%s", csv_file));
    void'($value$plusargs("FRAMES=%d", frames));
    void'($value$plusargs("ERRORS=%d", errors));

    fd = $fopen(csv_file, "w");
    if (fd == 0) $fatal(1, "decoder_gen_tb: cannot open %s", csv_file);
    $fwrite(fd, "msg_bits,message,received,decoded,pass\n");

    seed = 32'hDEC0_DE00 + MSG_BITS;
    ok   = 0;
    for (int f = 0; f < frames; f++) begin
      for (int w = 0; w < MSG_BITS; w++) msg[w] = 1'($urandom(seed));
      seed = 0;
      do_encode();

      rx = cw;
      for (int e = 0; e < errors; e++)
        rx ^= CW_BITS'(1) << ($urandom % CW_BITS);
      do_decode();

      $fwrite(fd, "%0d,%b,%b,%b,%0d\n", MSG_BITS, msg, rx, out, (out === msg));
      if (out === msg) ok++;
    end
    $fclose(fd);

    $display("SUMMARY  MSG_BITS=%0d  %0d stages  %0d trellis + %0d traceback clocks",
             MSG_BITS, STAGES, TRELLIS_CYCLES, TRACEBACK_CYCLES);
    $display("SUMMARY  %0d/%0d frames decoded correctly, %0d error(s) each",
             ok, frames, errors);
    $display("SUMMARY  grid written to %s", csv_file);
    $finish;
  end

  initial begin
    #2000000000;
    $fatal(1, "decoder_gen_tb: timeout");
  end

endmodule
