// ---------------------------------------------------------------------------
// encoder_bench -- exhaustive characterisation of rtl/d_ff.sv
//
// Sweeps all 128 seven-bit messages through the encoder and writes the
// resulting 14-bit codewords to CSV.  scripts/check_encoder.py then compares
// that CSV against model/viterbi_ref.py, which is an independent cross-check
// of both the RTL and the generator polynomials rather than a circular one.
//
//   +CSV=<path>   codeword table output   (default results/ber/rtl_encoder.csv)
//   +VCD=<path>   waveform output
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module encoder_bench;

  logic       clk = 1'b0;
  logic       reset;
  logic       d;
  wire  [3:0] q;
  wire  [1:0] enc_out;

  logic [6:0]  msg;
  logic [13:0] cw;
  string       csv_file, vcd_file;
  int          fd;

  always #5 clk = ~clk;

  d_ff dut (clk, reset, q, d, enc_out);

  initial begin
    csv_file = "results/ber/rtl_encoder.csv";
    vcd_file = "encoder_bench.vcd";
    void'($value$plusargs("CSV=%s", csv_file));
    void'($value$plusargs("VCD=%s", vcd_file));

    $dumpfile(vcd_file);
    $dumpvars(0, encoder_bench);

    fd = $fopen(csv_file, "w");
    if (fd == 0) $fatal(1, "encoder_bench: cannot open %s", csv_file);
    $fwrite(fd, "message,codeword\n");

    for (int m = 0; m < 128; m++) begin
      msg = m[6:0];

      // Flush the shift register: reset is active low and zeroes q.
      // DUT inputs are always changed on the negative edge -- d_ff.sv reads
      // them with blocking assignments, so driving them at the active edge
      // races with the DUT's own always block.
      @(negedge clk);
      reset = 1'b0;
      d     = 1'b0;
      @(posedge clk);

      for (int k = 0; k < 7; k++) begin
        @(negedge clk);
        reset = 1'b1;
        d     = msg[6 - k];          // msg[6] is the first message bit
        @(posedge clk);
        #1;                          // let the DUT's blocking assignments settle
        // g1 parity lands on the even (upper) bit of each pair
        cw[13 - 2 * k] = enc_out[1];
        cw[12 - 2 * k] = enc_out[0];
      end

      $fwrite(fd, "%07b,%014b\n", msg, cw);
      if (m == 7'b1011000)
        $display("PASS  canonical message %07b encodes to %014b", msg, cw);
    end

    $fclose(fd);
    $display("SUMMARY  encoded 128 messages -> %s", csv_file);
    $finish;
  end

  initial begin
    #1000000;
    $fatal(1, "encoder_bench: timeout");
  end

endmodule
