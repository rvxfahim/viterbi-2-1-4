// ---------------------------------------------------------------------------
// decoder_folded_bench -- single-decode, self-checking bench for
// rtl/decoder_folded.sv
//
// The counterpart to decoder_term_bench.sv, and deliberately the same shape so
// the two waveforms can be put side by side: same canonical word, same
// handshake, same pass criterion.  What differs is the clock count, and that
// is the point of the figure.
//
//   decoder_term    10 stages, 69 trellis clocks   (~8 clocks per stage)
//   decoder_folded  10 stages, 10 trellis clocks   (1 clock per stage)
//
//   +DAT=<20 binary digits>   received codeword, MSB first   (default: canonical)
//   +EXP=<7 binary digits>    expected decoded message       (default: 1011000)
//   +VCD=<path>               VCD output file
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module decoder_folded_bench;

  localparam int MSG_BITS  = 7;
  localparam int TAIL_BITS = 3;
  localparam int STAGES    = MSG_BITS + TAIL_BITS;   // 10
  localparam int CW_BITS   = 2 * STAGES;             // 20

  // One trellis stage per clock, then one traceback step per clock.  Compare
  // with decoder_term_bench.sv's 69 and 11.
  localparam int TRELLIS_CYCLES   = STAGES;          // 10
  localparam int TRACEBACK_CYCLES = STAGES;          // 10

  logic                clk = 1'b0;
  logic                reset;
  logic                ready;
  logic [CW_BITS-1:0]  dat;
  wire  [MSG_BITS-1:0] out;

  logic [MSG_BITS-1:0] expected;
  string               vcd_file;

  always #5 clk = ~clk;                 // 100 MHz, no time-zero race

  decoder_folded #(.MSG_BITS(MSG_BITS)) dut (clk, reset, dat, out, ready);

  initial begin
    dat      = 20'b11_11_01_11_01_01_11_00_00_00;  // 1011000 + zero tail
    expected = 7'b1011000;
    vcd_file = "decoder_folded_bench.vcd";

    void'($value$plusargs("DAT=%b", dat));
    void'($value$plusargs("EXP=%b", expected));
    void'($value$plusargs("VCD=%s", vcd_file));

    $dumpfile(vcd_file);
    $dumpvars(0, decoder_folded_bench);

    // All DUT inputs move on negedge, matching decoder_term_bench.
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
      $fatal(1, "decoder_folded_bench: output mismatch");
    end
    $finish;
  end

  initial begin
    #100000;
    $display("FAIL  watchdog timeout");
    $fatal(1, "decoder_folded_bench: timeout");
  end

endmodule
