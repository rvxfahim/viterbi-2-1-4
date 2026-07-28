// -------------------------------------------------------------------------
// decoder_term.sv -- GENERATED FILE, DO NOT EDIT
//
// Source:    rtl/gen/decoder.sv.j2
// Generator: scripts/gen_rtl.py
// Regenerate with:  python scripts/gen_rtl.py
//
// Rate 1/2, constraint length K = 4, 8 trellis states.
//   g1 = 1111 (17 octal) -> out[1]
//   g0 = 1011 (13 octal) -> out[0]
//
// Block:     7 message bits + 3 zero tail bits -> 10 trellis stages, 20 code bits
// Decision:  hard
// Trellis:   zero-tail terminated -- the encoder flushes K-1 = 3 zeros, so the
//            survivor is known to end in state 0 and traceback starts there.
// Latency:   69 trellis clocks + 11 traceback clocks
// -------------------------------------------------------------------------

module decoder_term(clk, reset, dat, out, ready);

  input clk;
  input reset;
  input [19:0] dat;
  input ready;
  output reg [6:0] out;
  reg [19:0] data;
  logic high;
  logic low;
  assign high = 1;
  assign low = 0;
  logic [4:0]steps_n;
  logic [4:0]stage_n;
  reg[2:0] lowest_index;
  reg [2:0] returned_path;
  byte counter_for_path;
  byte pinOut;
  byte table_counter;

  typedef struct {
    logic [4:0]finalStates[0:7];
  } FinalHammingDistance;

  typedef struct {
    logic bits[0:1];
    logic decoded;
  } CorrectSequence;

  CorrectSequence bitSequence;

  typedef struct {
    bit recievedSequence[0:1];
    bit[4:0] aTransition[0:1];
    bit[4:0] bTransition[0:1];
    bit[4:0] cTransition[0:1];
    bit[4:0] dTransition[0:1];
    bit[4:0] eTransition[0:1];
    bit[4:0] fTransition[0:1];
    bit[4:0] gTransition[0:1];
    bit[4:0] hTransition[0:1];
    logic [4:0] previousHammingDistance[0:7];
    logic [4:0] step;
    FinalHammingDistance hammingDistances;
  } HammingTable;

  HammingTable h1, h2, h3, h4, h5, h6, h7, h8, h9, h10;
  FinalHammingDistance oldHam;

  always @ (posedge clk ) begin

    if(!reset) begin
      //initialize all memory variables/registers
      integer i;
      i=0;
      for (i = 0;i<8 ;i=i+1 ) begin
        h1.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h2.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h3.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h4.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h5.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h6.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h7.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h8.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h9.hammingDistances.finalStates[i] = 0;
      end
      for (i = 0;i<8 ;i=i+1 ) begin
        h10.hammingDistances.finalStates[i] = 0;
      end
      data = dat;
      pinOut = 0;
      out[0] = 0;
      out[1] = 0;
      out[2] = 0;
      out[3] = 0;
      out[4] = 0;
      out[5] = 0;
      out[6] = 0;
      steps_n = 1;
      stage_n = 0;
      table_counter = 10;
      // The original never cleared counter_for_path here, so a second decode
      // began with a stale counter of 11 and emitted nothing -- the design
      // worked exactly once per power-on.  See docs/known-issues.md #1.
      counter_for_path = 0;
      lowest_index = 0;
      returned_path = 0;
    end

    else begin
      //begin decoding

      if (steps_n==1) begin
        initialize_hamming_table(steps_n, data[19], data[18]);  //populate hamming table h1 partially
        copmute_for_step(stage_n);
        steps_n = steps_n+1;
      end
      else if(steps_n==2) begin
if (stage_n==0) begin
          h2.aTransition[0] = compute_hamming_distance(data[17],data[16],low,low);
          h2.hammingDistances.finalStates[0] = h2.aTransition[0] + h1.hammingDistances.finalStates[0];
          stage_n = stage_n+2;
        end
else if (stage_n==2) begin
          h2.eTransition[0] = compute_hamming_distance(data[17],data[16],high,high);
          h2.hammingDistances.finalStates[2] = h2.eTransition[0] + h1.hammingDistances.finalStates[4];
          stage_n = stage_n+2;
        end
else if (stage_n==4) begin
          h2.aTransition[1] = compute_hamming_distance(data[17],data[16],high,high);
          h2.hammingDistances.finalStates[4] = h2.aTransition[1] + h1.hammingDistances.finalStates[0];
          stage_n = stage_n+2;
        end
else if (stage_n==6) begin
          h2.eTransition[1] = compute_hamming_distance(data[17],data[16],low,low);
          h2.hammingDistances.finalStates[6] = h2.eTransition[1] + h1.hammingDistances.finalStates[4];
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 2
      else if(steps_n==3) begin
if (stage_n==0) begin
          h3.aTransition[0] = compute_hamming_distance(data[15],data[14],low,low);
          h3.hammingDistances.finalStates[0] = h3.aTransition[0] + h2.hammingDistances.finalStates[0];
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h3.cTransition[0] = compute_hamming_distance(data[15],data[14],high,low);
          h3.hammingDistances.finalStates[1] = h3.cTransition[0] + h2.hammingDistances.finalStates[2];
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h3.eTransition[0] = compute_hamming_distance(data[15],data[14],high,high);
          h3.hammingDistances.finalStates[2] = h3.eTransition[0] + h2.hammingDistances.finalStates[4];
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h3.gTransition[0] = compute_hamming_distance(data[15],data[14],low,high);
          h3.hammingDistances.finalStates[3] = h3.gTransition[0] + h2.hammingDistances.finalStates[6];
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h3.aTransition[1] = compute_hamming_distance(data[15],data[14],high,high);
          h3.hammingDistances.finalStates[4] = h3.aTransition[1] + h2.hammingDistances.finalStates[0];
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h3.cTransition[1] = compute_hamming_distance(data[15],data[14],low,high);
          h3.hammingDistances.finalStates[5] = h3.cTransition[1] + h2.hammingDistances.finalStates[2];
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h3.eTransition[1] = compute_hamming_distance(data[15],data[14],low,low);
          h3.hammingDistances.finalStates[6] = h3.eTransition[1] + h2.hammingDistances.finalStates[4];
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h3.gTransition[1] = compute_hamming_distance(data[15],data[14],high,low);
          h3.hammingDistances.finalStates[7] = h3.gTransition[1] + h2.hammingDistances.finalStates[6];
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 3
      else if(steps_n==4) begin
if (stage_n==0) begin
          h4.aTransition[0] = compute_hamming_distance(data[13],data[12],low,low);
          h4.bTransition[0] = compute_hamming_distance(data[13],data[12],high,high);
          if ((h4.aTransition[0] + h3.hammingDistances.finalStates[0])<(h4.bTransition[0] + h3.hammingDistances.finalStates[1])) begin
            h4.hammingDistances.finalStates[0] = h4.aTransition[0] + h3.hammingDistances.finalStates[0];
            h4.bTransition[0] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[0] = h4.bTransition[0] + h3.hammingDistances.finalStates[1];
            h4.aTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h4.cTransition[0] = compute_hamming_distance(data[13],data[12],high,low);
          h4.dTransition[0] = compute_hamming_distance(data[13],data[12],low,high);
          if ((h4.cTransition[0] + h3.hammingDistances.finalStates[2])<(h4.dTransition[0] + h3.hammingDistances.finalStates[3])) begin
            h4.hammingDistances.finalStates[1] = h4.cTransition[0] + h3.hammingDistances.finalStates[2];
            h4.dTransition[0] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[1] = h4.dTransition[0] + h3.hammingDistances.finalStates[3];
            h4.cTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h4.eTransition[0] = compute_hamming_distance(data[13],data[12],high,high);
          h4.fTransition[0] = compute_hamming_distance(data[13],data[12],low,low);
          if ((h4.eTransition[0] + h3.hammingDistances.finalStates[4])<(h4.fTransition[0] + h3.hammingDistances.finalStates[5])) begin
            h4.hammingDistances.finalStates[2] = h4.eTransition[0] + h3.hammingDistances.finalStates[4];
            h4.fTransition[0] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[2] = h4.fTransition[0] + h3.hammingDistances.finalStates[5];
            h4.eTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h4.gTransition[0] = compute_hamming_distance(data[13],data[12],low,high);
          h4.hTransition[0] = compute_hamming_distance(data[13],data[12],high,low);
          if ((h4.gTransition[0] + h3.hammingDistances.finalStates[6])<(h4.hTransition[0] + h3.hammingDistances.finalStates[7])) begin
            h4.hammingDistances.finalStates[3] = h4.gTransition[0] + h3.hammingDistances.finalStates[6];
            h4.hTransition[0] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[3] = h4.hTransition[0] + h3.hammingDistances.finalStates[7];
            h4.gTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h4.aTransition[1] = compute_hamming_distance(data[13],data[12],high,high);
          h4.bTransition[1] = compute_hamming_distance(data[13],data[12],low,low);
          if ((h4.aTransition[1] + h3.hammingDistances.finalStates[0])<(h4.bTransition[1] + h3.hammingDistances.finalStates[1])) begin
            h4.hammingDistances.finalStates[4] = h4.aTransition[1] + h3.hammingDistances.finalStates[0];
            h4.bTransition[1] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[4] = h4.bTransition[1] + h3.hammingDistances.finalStates[1];
            h4.aTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h4.cTransition[1] = compute_hamming_distance(data[13],data[12],low,high);
          h4.dTransition[1] = compute_hamming_distance(data[13],data[12],high,low);
          if ((h4.cTransition[1] + h3.hammingDistances.finalStates[2])<(h4.dTransition[1] + h3.hammingDistances.finalStates[3])) begin
            h4.hammingDistances.finalStates[5] = h4.cTransition[1] + h3.hammingDistances.finalStates[2];
            h4.dTransition[1] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[5] = h4.dTransition[1] + h3.hammingDistances.finalStates[3];
            h4.cTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h4.eTransition[1] = compute_hamming_distance(data[13],data[12],low,low);
          h4.fTransition[1] = compute_hamming_distance(data[13],data[12],high,high);
          if ((h4.eTransition[1] + h3.hammingDistances.finalStates[4])<(h4.fTransition[1] + h3.hammingDistances.finalStates[5])) begin
            h4.hammingDistances.finalStates[6] = h4.eTransition[1] + h3.hammingDistances.finalStates[4];
            h4.fTransition[1] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[6] = h4.fTransition[1] + h3.hammingDistances.finalStates[5];
            h4.eTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h4.gTransition[1] = compute_hamming_distance(data[13],data[12],high,low);
          h4.hTransition[1] = compute_hamming_distance(data[13],data[12],low,high);
          if ((h4.gTransition[1] + h3.hammingDistances.finalStates[6])<(h4.hTransition[1] + h3.hammingDistances.finalStates[7])) begin
            h4.hammingDistances.finalStates[7] = h4.gTransition[1] + h3.hammingDistances.finalStates[6];
            h4.hTransition[1] = 3;
          end
          else begin
            h4.hammingDistances.finalStates[7] = h4.hTransition[1] + h3.hammingDistances.finalStates[7];
            h4.gTransition[1] = 3;
          end
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 4
      else if(steps_n==5) begin
if (stage_n==0) begin
          h5.aTransition[0] = compute_hamming_distance(data[11],data[10],low,low);
          h5.bTransition[0] = compute_hamming_distance(data[11],data[10],high,high);
          if ((h5.aTransition[0] + h4.hammingDistances.finalStates[0])<(h5.bTransition[0] + h4.hammingDistances.finalStates[1])) begin
            h5.hammingDistances.finalStates[0] = h5.aTransition[0] + h4.hammingDistances.finalStates[0];
            h5.bTransition[0] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[0] = h5.bTransition[0] + h4.hammingDistances.finalStates[1];
            h5.aTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h5.cTransition[0] = compute_hamming_distance(data[11],data[10],high,low);
          h5.dTransition[0] = compute_hamming_distance(data[11],data[10],low,high);
          if ((h5.cTransition[0] + h4.hammingDistances.finalStates[2])<(h5.dTransition[0] + h4.hammingDistances.finalStates[3])) begin
            h5.hammingDistances.finalStates[1] = h5.cTransition[0] + h4.hammingDistances.finalStates[2];
            h5.dTransition[0] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[1] = h5.dTransition[0] + h4.hammingDistances.finalStates[3];
            h5.cTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h5.eTransition[0] = compute_hamming_distance(data[11],data[10],high,high);
          h5.fTransition[0] = compute_hamming_distance(data[11],data[10],low,low);
          if ((h5.eTransition[0] + h4.hammingDistances.finalStates[4])<(h5.fTransition[0] + h4.hammingDistances.finalStates[5])) begin
            h5.hammingDistances.finalStates[2] = h5.eTransition[0] + h4.hammingDistances.finalStates[4];
            h5.fTransition[0] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[2] = h5.fTransition[0] + h4.hammingDistances.finalStates[5];
            h5.eTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h5.gTransition[0] = compute_hamming_distance(data[11],data[10],low,high);
          h5.hTransition[0] = compute_hamming_distance(data[11],data[10],high,low);
          if ((h5.gTransition[0] + h4.hammingDistances.finalStates[6])<(h5.hTransition[0] + h4.hammingDistances.finalStates[7])) begin
            h5.hammingDistances.finalStates[3] = h5.gTransition[0] + h4.hammingDistances.finalStates[6];
            h5.hTransition[0] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[3] = h5.hTransition[0] + h4.hammingDistances.finalStates[7];
            h5.gTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h5.aTransition[1] = compute_hamming_distance(data[11],data[10],high,high);
          h5.bTransition[1] = compute_hamming_distance(data[11],data[10],low,low);
          if ((h5.aTransition[1] + h4.hammingDistances.finalStates[0])<(h5.bTransition[1] + h4.hammingDistances.finalStates[1])) begin
            h5.hammingDistances.finalStates[4] = h5.aTransition[1] + h4.hammingDistances.finalStates[0];
            h5.bTransition[1] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[4] = h5.bTransition[1] + h4.hammingDistances.finalStates[1];
            h5.aTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h5.cTransition[1] = compute_hamming_distance(data[11],data[10],low,high);
          h5.dTransition[1] = compute_hamming_distance(data[11],data[10],high,low);
          if ((h5.cTransition[1] + h4.hammingDistances.finalStates[2])<(h5.dTransition[1] + h4.hammingDistances.finalStates[3])) begin
            h5.hammingDistances.finalStates[5] = h5.cTransition[1] + h4.hammingDistances.finalStates[2];
            h5.dTransition[1] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[5] = h5.dTransition[1] + h4.hammingDistances.finalStates[3];
            h5.cTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h5.eTransition[1] = compute_hamming_distance(data[11],data[10],low,low);
          h5.fTransition[1] = compute_hamming_distance(data[11],data[10],high,high);
          if ((h5.eTransition[1] + h4.hammingDistances.finalStates[4])<(h5.fTransition[1] + h4.hammingDistances.finalStates[5])) begin
            h5.hammingDistances.finalStates[6] = h5.eTransition[1] + h4.hammingDistances.finalStates[4];
            h5.fTransition[1] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[6] = h5.fTransition[1] + h4.hammingDistances.finalStates[5];
            h5.eTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h5.gTransition[1] = compute_hamming_distance(data[11],data[10],high,low);
          h5.hTransition[1] = compute_hamming_distance(data[11],data[10],low,high);
          if ((h5.gTransition[1] + h4.hammingDistances.finalStates[6])<(h5.hTransition[1] + h4.hammingDistances.finalStates[7])) begin
            h5.hammingDistances.finalStates[7] = h5.gTransition[1] + h4.hammingDistances.finalStates[6];
            h5.hTransition[1] = 3;
          end
          else begin
            h5.hammingDistances.finalStates[7] = h5.hTransition[1] + h4.hammingDistances.finalStates[7];
            h5.gTransition[1] = 3;
          end
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 5
      else if(steps_n==6) begin
if (stage_n==0) begin
          h6.aTransition[0] = compute_hamming_distance(data[9],data[8],low,low);
          h6.bTransition[0] = compute_hamming_distance(data[9],data[8],high,high);
          if ((h6.aTransition[0] + h5.hammingDistances.finalStates[0])<(h6.bTransition[0] + h5.hammingDistances.finalStates[1])) begin
            h6.hammingDistances.finalStates[0] = h6.aTransition[0] + h5.hammingDistances.finalStates[0];
            h6.bTransition[0] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[0] = h6.bTransition[0] + h5.hammingDistances.finalStates[1];
            h6.aTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h6.cTransition[0] = compute_hamming_distance(data[9],data[8],high,low);
          h6.dTransition[0] = compute_hamming_distance(data[9],data[8],low,high);
          if ((h6.cTransition[0] + h5.hammingDistances.finalStates[2])<(h6.dTransition[0] + h5.hammingDistances.finalStates[3])) begin
            h6.hammingDistances.finalStates[1] = h6.cTransition[0] + h5.hammingDistances.finalStates[2];
            h6.dTransition[0] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[1] = h6.dTransition[0] + h5.hammingDistances.finalStates[3];
            h6.cTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h6.eTransition[0] = compute_hamming_distance(data[9],data[8],high,high);
          h6.fTransition[0] = compute_hamming_distance(data[9],data[8],low,low);
          if ((h6.eTransition[0] + h5.hammingDistances.finalStates[4])<(h6.fTransition[0] + h5.hammingDistances.finalStates[5])) begin
            h6.hammingDistances.finalStates[2] = h6.eTransition[0] + h5.hammingDistances.finalStates[4];
            h6.fTransition[0] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[2] = h6.fTransition[0] + h5.hammingDistances.finalStates[5];
            h6.eTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h6.gTransition[0] = compute_hamming_distance(data[9],data[8],low,high);
          h6.hTransition[0] = compute_hamming_distance(data[9],data[8],high,low);
          if ((h6.gTransition[0] + h5.hammingDistances.finalStates[6])<(h6.hTransition[0] + h5.hammingDistances.finalStates[7])) begin
            h6.hammingDistances.finalStates[3] = h6.gTransition[0] + h5.hammingDistances.finalStates[6];
            h6.hTransition[0] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[3] = h6.hTransition[0] + h5.hammingDistances.finalStates[7];
            h6.gTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h6.aTransition[1] = compute_hamming_distance(data[9],data[8],high,high);
          h6.bTransition[1] = compute_hamming_distance(data[9],data[8],low,low);
          if ((h6.aTransition[1] + h5.hammingDistances.finalStates[0])<(h6.bTransition[1] + h5.hammingDistances.finalStates[1])) begin
            h6.hammingDistances.finalStates[4] = h6.aTransition[1] + h5.hammingDistances.finalStates[0];
            h6.bTransition[1] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[4] = h6.bTransition[1] + h5.hammingDistances.finalStates[1];
            h6.aTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h6.cTransition[1] = compute_hamming_distance(data[9],data[8],low,high);
          h6.dTransition[1] = compute_hamming_distance(data[9],data[8],high,low);
          if ((h6.cTransition[1] + h5.hammingDistances.finalStates[2])<(h6.dTransition[1] + h5.hammingDistances.finalStates[3])) begin
            h6.hammingDistances.finalStates[5] = h6.cTransition[1] + h5.hammingDistances.finalStates[2];
            h6.dTransition[1] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[5] = h6.dTransition[1] + h5.hammingDistances.finalStates[3];
            h6.cTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h6.eTransition[1] = compute_hamming_distance(data[9],data[8],low,low);
          h6.fTransition[1] = compute_hamming_distance(data[9],data[8],high,high);
          if ((h6.eTransition[1] + h5.hammingDistances.finalStates[4])<(h6.fTransition[1] + h5.hammingDistances.finalStates[5])) begin
            h6.hammingDistances.finalStates[6] = h6.eTransition[1] + h5.hammingDistances.finalStates[4];
            h6.fTransition[1] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[6] = h6.fTransition[1] + h5.hammingDistances.finalStates[5];
            h6.eTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h6.gTransition[1] = compute_hamming_distance(data[9],data[8],high,low);
          h6.hTransition[1] = compute_hamming_distance(data[9],data[8],low,high);
          if ((h6.gTransition[1] + h5.hammingDistances.finalStates[6])<(h6.hTransition[1] + h5.hammingDistances.finalStates[7])) begin
            h6.hammingDistances.finalStates[7] = h6.gTransition[1] + h5.hammingDistances.finalStates[6];
            h6.hTransition[1] = 3;
          end
          else begin
            h6.hammingDistances.finalStates[7] = h6.hTransition[1] + h5.hammingDistances.finalStates[7];
            h6.gTransition[1] = 3;
          end
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 6
      else if(steps_n==7) begin
if (stage_n==0) begin
          h7.aTransition[0] = compute_hamming_distance(data[7],data[6],low,low);
          h7.bTransition[0] = compute_hamming_distance(data[7],data[6],high,high);
          if ((h7.aTransition[0] + h6.hammingDistances.finalStates[0])<(h7.bTransition[0] + h6.hammingDistances.finalStates[1])) begin
            h7.hammingDistances.finalStates[0] = h7.aTransition[0] + h6.hammingDistances.finalStates[0];
            h7.bTransition[0] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[0] = h7.bTransition[0] + h6.hammingDistances.finalStates[1];
            h7.aTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h7.cTransition[0] = compute_hamming_distance(data[7],data[6],high,low);
          h7.dTransition[0] = compute_hamming_distance(data[7],data[6],low,high);
          if ((h7.cTransition[0] + h6.hammingDistances.finalStates[2])<(h7.dTransition[0] + h6.hammingDistances.finalStates[3])) begin
            h7.hammingDistances.finalStates[1] = h7.cTransition[0] + h6.hammingDistances.finalStates[2];
            h7.dTransition[0] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[1] = h7.dTransition[0] + h6.hammingDistances.finalStates[3];
            h7.cTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h7.eTransition[0] = compute_hamming_distance(data[7],data[6],high,high);
          h7.fTransition[0] = compute_hamming_distance(data[7],data[6],low,low);
          if ((h7.eTransition[0] + h6.hammingDistances.finalStates[4])<(h7.fTransition[0] + h6.hammingDistances.finalStates[5])) begin
            h7.hammingDistances.finalStates[2] = h7.eTransition[0] + h6.hammingDistances.finalStates[4];
            h7.fTransition[0] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[2] = h7.fTransition[0] + h6.hammingDistances.finalStates[5];
            h7.eTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h7.gTransition[0] = compute_hamming_distance(data[7],data[6],low,high);
          h7.hTransition[0] = compute_hamming_distance(data[7],data[6],high,low);
          if ((h7.gTransition[0] + h6.hammingDistances.finalStates[6])<(h7.hTransition[0] + h6.hammingDistances.finalStates[7])) begin
            h7.hammingDistances.finalStates[3] = h7.gTransition[0] + h6.hammingDistances.finalStates[6];
            h7.hTransition[0] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[3] = h7.hTransition[0] + h6.hammingDistances.finalStates[7];
            h7.gTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h7.aTransition[1] = compute_hamming_distance(data[7],data[6],high,high);
          h7.bTransition[1] = compute_hamming_distance(data[7],data[6],low,low);
          if ((h7.aTransition[1] + h6.hammingDistances.finalStates[0])<(h7.bTransition[1] + h6.hammingDistances.finalStates[1])) begin
            h7.hammingDistances.finalStates[4] = h7.aTransition[1] + h6.hammingDistances.finalStates[0];
            h7.bTransition[1] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[4] = h7.bTransition[1] + h6.hammingDistances.finalStates[1];
            h7.aTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h7.cTransition[1] = compute_hamming_distance(data[7],data[6],low,high);
          h7.dTransition[1] = compute_hamming_distance(data[7],data[6],high,low);
          if ((h7.cTransition[1] + h6.hammingDistances.finalStates[2])<(h7.dTransition[1] + h6.hammingDistances.finalStates[3])) begin
            h7.hammingDistances.finalStates[5] = h7.cTransition[1] + h6.hammingDistances.finalStates[2];
            h7.dTransition[1] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[5] = h7.dTransition[1] + h6.hammingDistances.finalStates[3];
            h7.cTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h7.eTransition[1] = compute_hamming_distance(data[7],data[6],low,low);
          h7.fTransition[1] = compute_hamming_distance(data[7],data[6],high,high);
          if ((h7.eTransition[1] + h6.hammingDistances.finalStates[4])<(h7.fTransition[1] + h6.hammingDistances.finalStates[5])) begin
            h7.hammingDistances.finalStates[6] = h7.eTransition[1] + h6.hammingDistances.finalStates[4];
            h7.fTransition[1] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[6] = h7.fTransition[1] + h6.hammingDistances.finalStates[5];
            h7.eTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h7.gTransition[1] = compute_hamming_distance(data[7],data[6],high,low);
          h7.hTransition[1] = compute_hamming_distance(data[7],data[6],low,high);
          if ((h7.gTransition[1] + h6.hammingDistances.finalStates[6])<(h7.hTransition[1] + h6.hammingDistances.finalStates[7])) begin
            h7.hammingDistances.finalStates[7] = h7.gTransition[1] + h6.hammingDistances.finalStates[6];
            h7.hTransition[1] = 3;
          end
          else begin
            h7.hammingDistances.finalStates[7] = h7.hTransition[1] + h6.hammingDistances.finalStates[7];
            h7.gTransition[1] = 3;
          end
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 7
      else if(steps_n==8) begin
if (stage_n==0) begin
          h8.aTransition[0] = compute_hamming_distance(data[5],data[4],low,low);
          h8.bTransition[0] = compute_hamming_distance(data[5],data[4],high,high);
          if ((h8.aTransition[0] + h7.hammingDistances.finalStates[0])<(h8.bTransition[0] + h7.hammingDistances.finalStates[1])) begin
            h8.hammingDistances.finalStates[0] = h8.aTransition[0] + h7.hammingDistances.finalStates[0];
            h8.bTransition[0] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[0] = h8.bTransition[0] + h7.hammingDistances.finalStates[1];
            h8.aTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h8.cTransition[0] = compute_hamming_distance(data[5],data[4],high,low);
          h8.dTransition[0] = compute_hamming_distance(data[5],data[4],low,high);
          if ((h8.cTransition[0] + h7.hammingDistances.finalStates[2])<(h8.dTransition[0] + h7.hammingDistances.finalStates[3])) begin
            h8.hammingDistances.finalStates[1] = h8.cTransition[0] + h7.hammingDistances.finalStates[2];
            h8.dTransition[0] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[1] = h8.dTransition[0] + h7.hammingDistances.finalStates[3];
            h8.cTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h8.eTransition[0] = compute_hamming_distance(data[5],data[4],high,high);
          h8.fTransition[0] = compute_hamming_distance(data[5],data[4],low,low);
          if ((h8.eTransition[0] + h7.hammingDistances.finalStates[4])<(h8.fTransition[0] + h7.hammingDistances.finalStates[5])) begin
            h8.hammingDistances.finalStates[2] = h8.eTransition[0] + h7.hammingDistances.finalStates[4];
            h8.fTransition[0] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[2] = h8.fTransition[0] + h7.hammingDistances.finalStates[5];
            h8.eTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h8.gTransition[0] = compute_hamming_distance(data[5],data[4],low,high);
          h8.hTransition[0] = compute_hamming_distance(data[5],data[4],high,low);
          if ((h8.gTransition[0] + h7.hammingDistances.finalStates[6])<(h8.hTransition[0] + h7.hammingDistances.finalStates[7])) begin
            h8.hammingDistances.finalStates[3] = h8.gTransition[0] + h7.hammingDistances.finalStates[6];
            h8.hTransition[0] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[3] = h8.hTransition[0] + h7.hammingDistances.finalStates[7];
            h8.gTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h8.aTransition[1] = compute_hamming_distance(data[5],data[4],high,high);
          h8.bTransition[1] = compute_hamming_distance(data[5],data[4],low,low);
          if ((h8.aTransition[1] + h7.hammingDistances.finalStates[0])<(h8.bTransition[1] + h7.hammingDistances.finalStates[1])) begin
            h8.hammingDistances.finalStates[4] = h8.aTransition[1] + h7.hammingDistances.finalStates[0];
            h8.bTransition[1] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[4] = h8.bTransition[1] + h7.hammingDistances.finalStates[1];
            h8.aTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h8.cTransition[1] = compute_hamming_distance(data[5],data[4],low,high);
          h8.dTransition[1] = compute_hamming_distance(data[5],data[4],high,low);
          if ((h8.cTransition[1] + h7.hammingDistances.finalStates[2])<(h8.dTransition[1] + h7.hammingDistances.finalStates[3])) begin
            h8.hammingDistances.finalStates[5] = h8.cTransition[1] + h7.hammingDistances.finalStates[2];
            h8.dTransition[1] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[5] = h8.dTransition[1] + h7.hammingDistances.finalStates[3];
            h8.cTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h8.eTransition[1] = compute_hamming_distance(data[5],data[4],low,low);
          h8.fTransition[1] = compute_hamming_distance(data[5],data[4],high,high);
          if ((h8.eTransition[1] + h7.hammingDistances.finalStates[4])<(h8.fTransition[1] + h7.hammingDistances.finalStates[5])) begin
            h8.hammingDistances.finalStates[6] = h8.eTransition[1] + h7.hammingDistances.finalStates[4];
            h8.fTransition[1] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[6] = h8.fTransition[1] + h7.hammingDistances.finalStates[5];
            h8.eTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h8.gTransition[1] = compute_hamming_distance(data[5],data[4],high,low);
          h8.hTransition[1] = compute_hamming_distance(data[5],data[4],low,high);
          if ((h8.gTransition[1] + h7.hammingDistances.finalStates[6])<(h8.hTransition[1] + h7.hammingDistances.finalStates[7])) begin
            h8.hammingDistances.finalStates[7] = h8.gTransition[1] + h7.hammingDistances.finalStates[6];
            h8.hTransition[1] = 3;
          end
          else begin
            h8.hammingDistances.finalStates[7] = h8.hTransition[1] + h7.hammingDistances.finalStates[7];
            h8.gTransition[1] = 3;
          end
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 8
      else if(steps_n==9) begin
if (stage_n==0) begin
          h9.aTransition[0] = compute_hamming_distance(data[3],data[2],low,low);
          h9.bTransition[0] = compute_hamming_distance(data[3],data[2],high,high);
          if ((h9.aTransition[0] + h8.hammingDistances.finalStates[0])<(h9.bTransition[0] + h8.hammingDistances.finalStates[1])) begin
            h9.hammingDistances.finalStates[0] = h9.aTransition[0] + h8.hammingDistances.finalStates[0];
            h9.bTransition[0] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[0] = h9.bTransition[0] + h8.hammingDistances.finalStates[1];
            h9.aTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h9.cTransition[0] = compute_hamming_distance(data[3],data[2],high,low);
          h9.dTransition[0] = compute_hamming_distance(data[3],data[2],low,high);
          if ((h9.cTransition[0] + h8.hammingDistances.finalStates[2])<(h9.dTransition[0] + h8.hammingDistances.finalStates[3])) begin
            h9.hammingDistances.finalStates[1] = h9.cTransition[0] + h8.hammingDistances.finalStates[2];
            h9.dTransition[0] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[1] = h9.dTransition[0] + h8.hammingDistances.finalStates[3];
            h9.cTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h9.eTransition[0] = compute_hamming_distance(data[3],data[2],high,high);
          h9.fTransition[0] = compute_hamming_distance(data[3],data[2],low,low);
          if ((h9.eTransition[0] + h8.hammingDistances.finalStates[4])<(h9.fTransition[0] + h8.hammingDistances.finalStates[5])) begin
            h9.hammingDistances.finalStates[2] = h9.eTransition[0] + h8.hammingDistances.finalStates[4];
            h9.fTransition[0] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[2] = h9.fTransition[0] + h8.hammingDistances.finalStates[5];
            h9.eTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h9.gTransition[0] = compute_hamming_distance(data[3],data[2],low,high);
          h9.hTransition[0] = compute_hamming_distance(data[3],data[2],high,low);
          if ((h9.gTransition[0] + h8.hammingDistances.finalStates[6])<(h9.hTransition[0] + h8.hammingDistances.finalStates[7])) begin
            h9.hammingDistances.finalStates[3] = h9.gTransition[0] + h8.hammingDistances.finalStates[6];
            h9.hTransition[0] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[3] = h9.hTransition[0] + h8.hammingDistances.finalStates[7];
            h9.gTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h9.aTransition[1] = compute_hamming_distance(data[3],data[2],high,high);
          h9.bTransition[1] = compute_hamming_distance(data[3],data[2],low,low);
          if ((h9.aTransition[1] + h8.hammingDistances.finalStates[0])<(h9.bTransition[1] + h8.hammingDistances.finalStates[1])) begin
            h9.hammingDistances.finalStates[4] = h9.aTransition[1] + h8.hammingDistances.finalStates[0];
            h9.bTransition[1] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[4] = h9.bTransition[1] + h8.hammingDistances.finalStates[1];
            h9.aTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h9.cTransition[1] = compute_hamming_distance(data[3],data[2],low,high);
          h9.dTransition[1] = compute_hamming_distance(data[3],data[2],high,low);
          if ((h9.cTransition[1] + h8.hammingDistances.finalStates[2])<(h9.dTransition[1] + h8.hammingDistances.finalStates[3])) begin
            h9.hammingDistances.finalStates[5] = h9.cTransition[1] + h8.hammingDistances.finalStates[2];
            h9.dTransition[1] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[5] = h9.dTransition[1] + h8.hammingDistances.finalStates[3];
            h9.cTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h9.eTransition[1] = compute_hamming_distance(data[3],data[2],low,low);
          h9.fTransition[1] = compute_hamming_distance(data[3],data[2],high,high);
          if ((h9.eTransition[1] + h8.hammingDistances.finalStates[4])<(h9.fTransition[1] + h8.hammingDistances.finalStates[5])) begin
            h9.hammingDistances.finalStates[6] = h9.eTransition[1] + h8.hammingDistances.finalStates[4];
            h9.fTransition[1] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[6] = h9.fTransition[1] + h8.hammingDistances.finalStates[5];
            h9.eTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h9.gTransition[1] = compute_hamming_distance(data[3],data[2],high,low);
          h9.hTransition[1] = compute_hamming_distance(data[3],data[2],low,high);
          if ((h9.gTransition[1] + h8.hammingDistances.finalStates[6])<(h9.hTransition[1] + h8.hammingDistances.finalStates[7])) begin
            h9.hammingDistances.finalStates[7] = h9.gTransition[1] + h8.hammingDistances.finalStates[6];
            h9.hTransition[1] = 3;
          end
          else begin
            h9.hammingDistances.finalStates[7] = h9.hTransition[1] + h8.hammingDistances.finalStates[7];
            h9.gTransition[1] = 3;
          end
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 9
      else if(steps_n==10) begin
if (stage_n==0) begin
          h10.aTransition[0] = compute_hamming_distance(data[1],data[0],low,low);
          h10.bTransition[0] = compute_hamming_distance(data[1],data[0],high,high);
          if ((h10.aTransition[0] + h9.hammingDistances.finalStates[0])<(h10.bTransition[0] + h9.hammingDistances.finalStates[1])) begin
            h10.hammingDistances.finalStates[0] = h10.aTransition[0] + h9.hammingDistances.finalStates[0];
            h10.bTransition[0] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[0] = h10.bTransition[0] + h9.hammingDistances.finalStates[1];
            h10.aTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==1) begin
          h10.cTransition[0] = compute_hamming_distance(data[1],data[0],high,low);
          h10.dTransition[0] = compute_hamming_distance(data[1],data[0],low,high);
          if ((h10.cTransition[0] + h9.hammingDistances.finalStates[2])<(h10.dTransition[0] + h9.hammingDistances.finalStates[3])) begin
            h10.hammingDistances.finalStates[1] = h10.cTransition[0] + h9.hammingDistances.finalStates[2];
            h10.dTransition[0] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[1] = h10.dTransition[0] + h9.hammingDistances.finalStates[3];
            h10.cTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==2) begin
          h10.eTransition[0] = compute_hamming_distance(data[1],data[0],high,high);
          h10.fTransition[0] = compute_hamming_distance(data[1],data[0],low,low);
          if ((h10.eTransition[0] + h9.hammingDistances.finalStates[4])<(h10.fTransition[0] + h9.hammingDistances.finalStates[5])) begin
            h10.hammingDistances.finalStates[2] = h10.eTransition[0] + h9.hammingDistances.finalStates[4];
            h10.fTransition[0] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[2] = h10.fTransition[0] + h9.hammingDistances.finalStates[5];
            h10.eTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==3) begin
          h10.gTransition[0] = compute_hamming_distance(data[1],data[0],low,high);
          h10.hTransition[0] = compute_hamming_distance(data[1],data[0],high,low);
          if ((h10.gTransition[0] + h9.hammingDistances.finalStates[6])<(h10.hTransition[0] + h9.hammingDistances.finalStates[7])) begin
            h10.hammingDistances.finalStates[3] = h10.gTransition[0] + h9.hammingDistances.finalStates[6];
            h10.hTransition[0] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[3] = h10.hTransition[0] + h9.hammingDistances.finalStates[7];
            h10.gTransition[0] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==4) begin
          h10.aTransition[1] = compute_hamming_distance(data[1],data[0],high,high);
          h10.bTransition[1] = compute_hamming_distance(data[1],data[0],low,low);
          if ((h10.aTransition[1] + h9.hammingDistances.finalStates[0])<(h10.bTransition[1] + h9.hammingDistances.finalStates[1])) begin
            h10.hammingDistances.finalStates[4] = h10.aTransition[1] + h9.hammingDistances.finalStates[0];
            h10.bTransition[1] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[4] = h10.bTransition[1] + h9.hammingDistances.finalStates[1];
            h10.aTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==5) begin
          h10.cTransition[1] = compute_hamming_distance(data[1],data[0],low,high);
          h10.dTransition[1] = compute_hamming_distance(data[1],data[0],high,low);
          if ((h10.cTransition[1] + h9.hammingDistances.finalStates[2])<(h10.dTransition[1] + h9.hammingDistances.finalStates[3])) begin
            h10.hammingDistances.finalStates[5] = h10.cTransition[1] + h9.hammingDistances.finalStates[2];
            h10.dTransition[1] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[5] = h10.dTransition[1] + h9.hammingDistances.finalStates[3];
            h10.cTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==6) begin
          h10.eTransition[1] = compute_hamming_distance(data[1],data[0],low,low);
          h10.fTransition[1] = compute_hamming_distance(data[1],data[0],high,high);
          if ((h10.eTransition[1] + h9.hammingDistances.finalStates[4])<(h10.fTransition[1] + h9.hammingDistances.finalStates[5])) begin
            h10.hammingDistances.finalStates[6] = h10.eTransition[1] + h9.hammingDistances.finalStates[4];
            h10.fTransition[1] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[6] = h10.fTransition[1] + h9.hammingDistances.finalStates[5];
            h10.eTransition[1] = 3;
          end
          stage_n = stage_n+1;
        end
else if (stage_n==7) begin
          h10.gTransition[1] = compute_hamming_distance(data[1],data[0],high,low);
          h10.hTransition[1] = compute_hamming_distance(data[1],data[0],low,high);
          if ((h10.gTransition[1] + h9.hammingDistances.finalStates[6])<(h10.hTransition[1] + h9.hammingDistances.finalStates[7])) begin
            h10.hammingDistances.finalStates[7] = h10.gTransition[1] + h9.hammingDistances.finalStates[6];
            h10.hTransition[1] = 3;
          end
          else begin
            h10.hammingDistances.finalStates[7] = h10.hTransition[1] + h9.hammingDistances.finalStates[7];
            h10.gTransition[1] = 3;
          end
          stage_n = 0;
          steps_n = steps_n+1;
        end
      end //end of step 10

      // The original evaluated this block outside the reset if/else, so it ran
      // on reset edges too and was safe only because the testbenches held
      // ready low during reset.  See docs/known-issues.md #2.
      if(ready==1) begin
        if (counter_for_path==0) begin
          // Terminated trellis: the survivor ends in state 0 by construction,
          // so there is nothing to search for.
          lowest_index = 0;
          counter_for_path = counter_for_path+1;
        end //end of counter_for_path==0
        else if(counter_for_path>=1 && counter_for_path<=10) begin
          returned_path = getReturnPath(lowest_index, table_counter);
          // Traceback walks stage 10 down to 1, so the first 3 bits it
          // recovers are the zero tail.  They carried no message and are dropped.
          if (pinOut >= 3) begin
            set_outputs(lowest_index, returned_path, pinOut-3);
          end
          lowest_index = returned_path;
          table_counter = table_counter-1;
          pinOut=pinOut+1;
          counter_for_path = counter_for_path+1;
        end
      end

    end
  end


  task initialize_hamming_table(input int steps, input bit bits0, input bit bits1);
    if (steps_n==1) begin
      for (int i = 0;i<8 ;i=i+1 ) begin
        h1.previousHammingDistance[i] = 0;
      end
      h1.recievedSequence[0] = bits0;
      h1.recievedSequence[1] = bits1;
      h1.step = steps;
    end
  endtask


  task copmute_for_step(input int stage_n);
    if (stage_n==0) begin
      h1.aTransition[0] = compute_hamming_distance(h1.recievedSequence[0],h1.recievedSequence[1],low,low)
                          + h1.previousHammingDistance[0];
      h1.aTransition[1] = compute_hamming_distance(h1.recievedSequence[0],h1.recievedSequence[1],high,high)
                          + h1.previousHammingDistance[0];
      h1.hammingDistances.finalStates[0] = h1.aTransition[0];
      h1.hammingDistances.finalStates[4] = h1.aTransition[1];
    end
  endtask


  function bit[4:0] compute_hamming_distance(input bit data_msb, input bit data_lsb, input bit compare_msb, input bit compare_lsb);
    begin
      if (data_msb != compare_msb && data_lsb!=compare_lsb) begin
        return 2;
      end
      else if (data_msb!=compare_msb && data_lsb==compare_lsb) begin
        return 1;
      end
      else if (data_msb==compare_msb && data_lsb!=compare_lsb) begin
        return 1;
      end
      else
        begin
          return 0;
        end
    end
  endfunction


  function bit[2:0] getReturnPath(input bit [2:0] currentState, input bit [3:0] currentTable);
    begin
      bit[2:0] returnPath;
      if (currentTable==1) begin
        case(currentState)
          0: begin
            if (h1.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h1.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h1.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h1.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h1.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h1.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h1.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h1.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==2) begin
        case(currentState)
          0: begin
            if (h2.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h2.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h2.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h2.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h2.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h2.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h2.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h2.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==3) begin
        case(currentState)
          0: begin
            if (h3.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h3.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h3.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h3.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h3.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h3.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h3.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h3.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==4) begin
        case(currentState)
          0: begin
            if (h4.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h4.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h4.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h4.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h4.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h4.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h4.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h4.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==5) begin
        case(currentState)
          0: begin
            if (h5.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h5.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h5.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h5.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h5.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h5.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h5.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h5.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==6) begin
        case(currentState)
          0: begin
            if (h6.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h6.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h6.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h6.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h6.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h6.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h6.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h6.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==7) begin
        case(currentState)
          0: begin
            if (h7.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h7.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h7.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h7.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h7.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h7.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h7.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h7.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==8) begin
        case(currentState)
          0: begin
            if (h8.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h8.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h8.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h8.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h8.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h8.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h8.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h8.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==9) begin
        case(currentState)
          0: begin
            if (h9.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h9.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h9.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h9.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h9.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h9.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h9.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h9.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      if (currentTable==10) begin
        case(currentState)
          0: begin
            if (h10.aTransition[0]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          1: begin
            if (h10.cTransition[0]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          2: begin
            if (h10.eTransition[0]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          3: begin
            if (h10.gTransition[0]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          4: begin
            if (h10.aTransition[1]!=3) begin
              returnPath = 0;
            end
            else begin
              returnPath = 1;
            end
          end
          5: begin
            if (h10.cTransition[1]!=3) begin
              returnPath = 2;
            end
            else begin
              returnPath = 3;
            end
          end
          6: begin
            if (h10.eTransition[1]!=3) begin
              returnPath = 4;
            end
            else begin
              returnPath = 5;
            end
          end
          7: begin
            if (h10.gTransition[1]!=3) begin
              returnPath = 6;
            end
            else begin
              returnPath = 7;
            end
          end
          default: returnPath = 7;
        endcase
        return returnPath;
      end
      return 0;
    end
  endfunction


  task set_outputs(input bit[3:0] from_s, input bit[3:0] at_state,input byte pinNumber); // last to first
    begin //task begin
if(from_s==0 && at_state==0) begin
        out[pinNumber] = 0;
      end
else if(from_s==0 && at_state==1) begin
        out[pinNumber] = 0;
      end
else if(from_s==1 && at_state==2) begin
        out[pinNumber] = 0;
      end
else if(from_s==1 && at_state==3) begin
        out[pinNumber] = 0;
      end
else if(from_s==2 && at_state==4) begin
        out[pinNumber] = 0;
      end
else if(from_s==2 && at_state==5) begin
        out[pinNumber] = 0;
      end
else if(from_s==3 && at_state==6) begin
        out[pinNumber] = 0;
      end
else if(from_s==3 && at_state==7) begin
        out[pinNumber] = 0;
      end
else if(from_s==4 && at_state==0) begin
        out[pinNumber] = 1;
      end
else if(from_s==4 && at_state==1) begin
        out[pinNumber] = 1;
      end
else if(from_s==5 && at_state==2) begin
        out[pinNumber] = 1;
      end
else if(from_s==5 && at_state==3) begin
        out[pinNumber] = 1;
      end
else if(from_s==6 && at_state==4) begin
        out[pinNumber] = 1;
      end
else if(from_s==6 && at_state==5) begin
        out[pinNumber] = 1;
      end
else if(from_s==7 && at_state==6) begin
        out[pinNumber] = 1;
      end
else if(from_s==7 && at_state==7) begin
        out[pinNumber] = 1;
      end
    end // task end
  endtask

endmodule
