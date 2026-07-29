// ---------------------------------------------------------------------------
// decoder_term_bench -- single-decode, self-checking bench for
// rtl/decoder_term.sv
//
// The counterpart to decoder_bench.sv.  system_term_tb.sv sweeps all 2688
// cases and its VCD is far too large to plot; this one decodes a single word
// so the waveform and the per-stage path metrics can be drawn.
//
//   +DAT=<20 binary digits>   received codeword, MSB first   (default: canonical)
//   +EXP=<7 binary digits>    expected decoded message       (default: 1011000)
//   +VCD=<path>               VCD output file
//
// The default codeword is the canonical message 1011000 encoded *with* the
// three-bit zero tail, so it is the 20-bit sibling of the 14-bit word every
// other figure in the repo uses.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module decoder_term_bench;

  // 1 posedge for stage 1, 4 for stage 2 (states 0,2,4,6), 8 for each of
  // stages 3..10  =>  1 + 4 + 8*8 = 69.  Traceback then needs one posedge to
  // establish the start state and one per stage to walk back.
  localparam int TRELLIS_CYCLES   = 69;
  localparam int TRACEBACK_CYCLES = 11;

  logic        clk = 1'b0;
  logic        reset;
  logic        ready;
  logic [19:0] dat;
  wire  [6:0]  out;

  logic [6:0]  expected;
  string       vcd_file;

  always #5 clk = ~clk;                 // 100 MHz, no time-zero race

  decoder_term dut (clk, reset, dat, out, ready);

  initial begin
    // The first 14 bits are the canonical codeword unchanged -- the tail only
    // appends stages, it does not alter what came before.
    dat      = 20'b11_11_01_11_01_01_11_00_00_00;  // 1011000 + zero tail
    expected = 7'b1011000;
    vcd_file = "decoder_term_bench.vcd";

    void'($value$plusargs("DAT=%b", dat));
    void'($value$plusargs("EXP=%b", expected));
    void'($value$plusargs("VCD=%s", vcd_file));

    $dumpfile(vcd_file);
    $dumpvars(0, decoder_term_bench);

    // All DUT inputs move on negedge -- the DUT reads them with blocking
    // assignments inside always @(posedge clk).
    reset = 1'b0;                        // active low; also latches data <= dat
    ready = 1'b0;
    repeat (2) @(posedge clk);

    @(negedge clk);
    reset = 1'b1;
    repeat (TRELLIS_CYCLES) @(posedge clk);

    @(negedge clk);
    ready = 1'b1;
    repeat (TRACEBACK_CYCLES) @(posedge clk);

    @(negedge clk);

    if (out === expected) begin
      $display("PASS  dat=%b  out=%b", dat, out);
    end else begin
      $display("FAIL  dat=%b  out=%b  expected=%b", dat, out, expected);
      $fatal(1, "decoder_term_bench: output mismatch");
    end
    $finish;
  end

  initial begin
    #100000;
    $display("FAIL  watchdog timeout");
    $fatal(1, "decoder_term_bench: timeout");
  end

endmodule
