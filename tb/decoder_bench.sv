// ---------------------------------------------------------------------------
// decoder_bench -- parametrised, self-checking bench for rtl/decoder.sv
//
// The original tb/legacy/decoder_tb.sv is preserved byte-for-byte because it
// is the testbench the published waveforms came from.  This bench is the one
// used for regression: it has a real clock generator, dumps the full design
// hierarchy, takes its stimulus from plusargs, and fails loudly.
//
//   +DAT=<14 binary digits>   received codeword, MSB first        (default: canonical)
//   +EXP=<7 binary digits>    expected decoded message            (default: 1011000)
//   +VCD=<path>               VCD output file
//
// Codeword bit order (see docs/bitorder.md):
//   dat[13-2k] = g1 parity of message bit k,  g1 = 1111
//   dat[12-2k] = g0 parity of message bit k,  g0 = 1011
//   out[6] is the FIRST message bit, out[0] the last.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module decoder_bench;

  // Cycle budget of the decoder FSM, counted from the steps_n/stage_n ladder
  // in rtl/decoder.sv: step 1 takes 1 posedge, step 2 takes 4 (stages 0,2,4,6),
  // steps 3..7 take 8 each  =>  1 + 4 + 5*8 = 45.  Traceback then needs one
  // posedge to pick the surviving state and 7 to emit the message bits.
  localparam int TRELLIS_CYCLES   = 45;
  localparam int TRACEBACK_CYCLES = 8;

  logic        clk = 1'b0;
  logic        reset;
  logic        ready;
  logic [13:0] dat;
  wire  [6:0]  out;

  logic [6:0]  expected;
  string       vcd_file;

  always #5 clk = ~clk;                 // 100 MHz, no time-zero race

  decoder dut (clk, reset, dat, out, ready);

  initial begin
    dat      = 14'b11_11_01_11_01_01_11;   // canonical clean codeword
    expected = 7'b1011000;
    vcd_file = "decoder_bench.vcd";

    void'($value$plusargs("DAT=%b", dat));
    void'($value$plusargs("EXP=%b", expected));
    void'($value$plusargs("VCD=%s", vcd_file));

    $dumpfile(vcd_file);
    $dumpvars(0, decoder_bench);           // explicit full depth

    // DUT inputs change on the negative edge throughout: decoder.sv reads them
    // with blocking assignments inside always @(posedge clk), so driving them
    // at the active edge would race with the DUT's own evaluation.
    reset = 1'b0;                          // active low; also latches data <= dat
    ready = 1'b0;
    repeat (2) @(posedge clk);

    @(negedge clk);
    reset = 1'b1;
    repeat (TRELLIS_CYCLES) @(posedge clk);

    @(negedge clk);
    ready = 1'b1;
    repeat (TRACEBACK_CYCLES) @(posedge clk);

    // `out` is written with a blocking assignment inside the DUT's
    // always @(posedge clk), so sample it away from the active edge.
    @(negedge clk);

    if (out === expected) begin
      $display("PASS  dat=%b  out=%b", dat, out);
    end else begin
      $display("FAIL  dat=%b  out=%b  expected=%b", dat, out, expected);
      $fatal(1, "decoder_bench: output mismatch");
    end
    $finish;
  end

  initial begin
    #100000;
    $display("FAIL  watchdog timeout");
    $fatal(1, "decoder_bench: timeout");
  end

endmodule
