module decoder(clk, reset, dat, out, ready);
 
  input clk;
  input reset;
  input [13:0] dat;
  input ready;
  output reg [6:0] out;
  reg [13:0] data;
  logic high;
  logic low;
  //wire [13:0]data;
  assign high = 1;
  assign low = 0;
  logic toggle_flag;
  logic [4:0]steps_n;
  logic [4:0]stage_n;
  reg[4:0] temp_states[0:7];
  reg[4:0] lowest_value;
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
    logic [1:0] step;
    FinalHammingDistance hammingDistances;
 } HammingTable;
  HammingTable h1, h2, h3, h4, h5, h6, h7;
  FinalHammingDistance oldHam;
  always @ (posedge clk) begin

	      if(!reset) begin
	      	//initialize all memory variables/registers
          integer i;
	  
	        i=0;
          
          for (i = 0;i<8 ;i=i+1 ) begin
          h1.hammingDistances.finalStates[i] =   0;  
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
            h5.hammingDistances.finalStates[i] = 0;
          end
          for (i = 0;i<8 ;i=i+1 ) begin
            h6.hammingDistances.finalStates[i] = 0;
          end
          for (i = 0;i<8 ;i=i+1 ) begin
            h7.hammingDistances.finalStates[i] = 0;
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
          stage_n=0;
          table_counter = 7;
	      end



	      else begin
	      	//begin decoding
          
            if (steps_n==1) begin
              initialize_hamming_table(steps_n, data[13], data[12]);  //populate hamming table h1 partially
              copmute_for_step(stage_n);
              steps_n = steps_n+1;
            end
            else if(steps_n==2) begin
              
              if (stage_n==0) begin
                //h2.aTransition0 + h1.state0
                h2.aTransition[0] = compute_hamming_distance(data[11],data[10],low,low);
                h2.hammingDistances.finalStates[0]= h2.aTransition[0] + h1.hammingDistances.finalStates[0];
                stage_n = stage_n+2;
              end

              else if (stage_n==2) begin
                //
                h2.eTransition[0] = compute_hamming_distance(data[11],data[10],high,high);
                h2.hammingDistances.finalStates[2] = h2.eTransition[0] + h1.hammingDistances.finalStates[4];
                stage_n = stage_n+2;
              end
              else if (stage_n==4) begin
                //a1 + state0
                h2.aTransition[1] = compute_hamming_distance(data[11],data[10],high,high);
                h2.hammingDistances.finalStates[4] = h2.aTransition[1] + h1.hammingDistances.finalStates[0];
                stage_n = stage_n+2;
              end
              else if (stage_n==6) begin
                //e1 + state4
                h2.eTransition[1] = compute_hamming_distance(data[11],data[10],low,low);
                h2.hammingDistances.finalStates[6] = h2.eTransition[1] + h1.hammingDistances.finalStates[4];
                stage_n = 0;
                steps_n = steps_n+1;
              end

            end
            else if(steps_n==3) begin
              if (stage_n==0) begin
                //h3.aTransition0 + h2.state0
                h3.aTransition[0] = compute_hamming_distance(data[9],data[8],low,low);
                h3.hammingDistances.finalStates[0]= h3.aTransition[0] + h2.hammingDistances.finalStates[0];
                stage_n = stage_n+1;
              end
              else if (stage_n==1) begin
                // c0+state2
                h3.cTransition[0] = compute_hamming_distance(data[9],data[8],high,low);
                h3.hammingDistances.finalStates[1] = h3.cTransition[0] + h2.hammingDistances.finalStates[2];
                stage_n = stage_n+1;
              end
              else if (stage_n==2) begin
                //
                h3.eTransition[0] = compute_hamming_distance(data[9],data[8],high,high);
                h3.hammingDistances.finalStates[2] = h3.eTransition[0] + h2.hammingDistances.finalStates[4];
                stage_n = stage_n+1;
              end
              else if (stage_n==3) begin
                //
                h3.gTransition[0] = compute_hamming_distance(data[9],data[8],low,high);
                h3.hammingDistances.finalStates[3] = h3.gTransition[0] + h2.hammingDistances.finalStates[6];
                stage_n = stage_n+1;
              end
              else if (stage_n==4) begin
                //a1 + state0
                h3.aTransition[1] = compute_hamming_distance(data[9],data[8],high,high);
                h3.hammingDistances.finalStates[4] = h3.aTransition[1] + h2.hammingDistances.finalStates[0];
                stage_n = stage_n+1;
              end
              else if (stage_n==5) begin
                //
                h3.cTransition[1] = compute_hamming_distance(data[9],data[8],low,high);
                h3.hammingDistances.finalStates[5] = h3.cTransition[1] + h2.hammingDistances.finalStates[2];
                stage_n = stage_n+1;
              end
              else if (stage_n==6) begin //g
                //e1 + state4
                h3.eTransition[1] = compute_hamming_distance(data[9],data[8],low,low);
                h3.hammingDistances.finalStates[6] = h3.eTransition[1] + h2.hammingDistances.finalStates[4];
                stage_n = stage_n+1;
              end
              else if (stage_n==7) begin //h
                //
                h3.gTransition[1] = compute_hamming_distance(data[9],data[8],high,low);
                h3.hammingDistances.finalStates[7] = h3.gTransition[1] + h2.hammingDistances.finalStates[6];
                stage_n = 0;
                steps_n = steps_n+1;
              end //step 3 complete
            end
            else if(steps_n==4) begin
                if (stage_n==0) begin
                //h3.aTransition0 + h2.state0
                h4.aTransition[0] = compute_hamming_distance(data[7],data[6],low,low);
                h4.bTransition[0] = compute_hamming_distance(data[7],data[6],high,high);
                
                if ((h4.aTransition[0] + h3.hammingDistances.finalStates[0])<(h4.bTransition[0] + h3.hammingDistances.finalStates[1])) begin
                  h4.hammingDistances.finalStates[0]= h4.aTransition[0] + h3.hammingDistances.finalStates[0];
                  h4.bTransition[0]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[0]= h4.bTransition[0] + h3.hammingDistances.finalStates[1];
                  h4.aTransition[0] = 3;
                end
                
                stage_n = stage_n+1;
              end
              else if (stage_n==1) begin
                // c0+state2
                h4.cTransition[0] = compute_hamming_distance(data[7],data[6],high,low);
                h4.dTransition[0] = compute_hamming_distance(data[7],data[6],low,high);
                if ((h4.cTransition[0] + h3.hammingDistances.finalStates[2])<(h4.dTransition[0] + h3.hammingDistances.finalStates[3])) begin
                  h4.hammingDistances.finalStates[1]= h4.cTransition[0] + h3.hammingDistances.finalStates[2];
                  h4.dTransition[0]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[1]= h4.dTransition[0] + h3.hammingDistances.finalStates[3];
                  h4.cTransition[0] = 3;
                end

                stage_n = stage_n+1;
              end
              else if (stage_n==2) begin
                //
                h4.eTransition[0] = compute_hamming_distance(data[7],data[6],high,high);
                h4.fTransition[0] = compute_hamming_distance(data[7],data[6],low,low);
                
                if ((h4.eTransition[0]+h3.hammingDistances.finalStates[4])<(h4.fTransition[0]+h3.hammingDistances.finalStates[5])) begin
                  h4.hammingDistances.finalStates[2]= h4.eTransition[0]+h3.hammingDistances.finalStates[4];
                  h4.fTransition[0]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[2] = h4.fTransition[0]+h3.hammingDistances.finalStates[5];
                  h4.eTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==3) begin
                //
                h4.gTransition[0] = compute_hamming_distance(data[7],data[6],low,high);
                h4.hTransition[0] = compute_hamming_distance(data[7],data[6],high,low);
                h4.hammingDistances.finalStates[3] = ((h4.gTransition[0]+h3.hammingDistances.finalStates[6])<(h4.hTransition[0]+h3.hammingDistances.finalStates[7])) ? (h4.gTransition[0]+h3.hammingDistances.finalStates[6]) : (h4.hTransition[0]+h3.hammingDistances.finalStates[7]);
                if ((h4.gTransition[0]+h3.hammingDistances.finalStates[6])<(h4.hTransition[0]+h3.hammingDistances.finalStates[7])) begin
                  h4.hammingDistances.finalStates[3]= h4.gTransition[0]+h3.hammingDistances.finalStates[6];
                  h4.hTransition[0]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[3]= h4.hTransition[0]+h3.hammingDistances.finalStates[7];
                  h4.gTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==4) begin
                //a1 + state0
                h4.aTransition[1] = compute_hamming_distance(data[7],data[6],high,high);
                h4.bTransition[1] = compute_hamming_distance(data[7],data[6],low,low);
                if ((h4.aTransition[1] + h3.hammingDistances.finalStates[0])<(h4.bTransition[1] + h3.hammingDistances.finalStates[1])) begin
                  h4.hammingDistances.finalStates[4]= h4.aTransition[1] + h3.hammingDistances.finalStates[0];
                  h4.bTransition[1]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[4]= h4.bTransition[1] + h3.hammingDistances.finalStates[1];
                  h4.aTransition[1] = 3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==5) begin
                //
                h4.cTransition[1] = compute_hamming_distance(data[7],data[6],low,high);
                h4.dTransition[1] = compute_hamming_distance(data[7],data[6],high,low);
                if ((h4.cTransition[1] + h3.hammingDistances.finalStates[2])<(h4.dTransition[1] + h3.hammingDistances.finalStates[3])) begin
                  h4.hammingDistances.finalStates[5]= h4.cTransition[1] + h3.hammingDistances.finalStates[2];
                  h4.dTransition[1]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[5]= h4.dTransition[1] + h3.hammingDistances.finalStates[3];
                  h4.cTransition[1] = 3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==6) begin //g
                //e1 + state4
                h4.eTransition[1] = compute_hamming_distance(data[7],data[6],low,low);
                h4.fTransition[1] = compute_hamming_distance(data[7],data[6],high,high);
                if ((h4.eTransition[1] + h3.hammingDistances.finalStates[4])<(h4.fTransition[1] + h3.hammingDistances.finalStates[5])) begin
                  h4.hammingDistances.finalStates[6]= h4.eTransition[1] + h3.hammingDistances.finalStates[4];
                  h4.fTransition[1]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[6]= h4.fTransition[1] + h3.hammingDistances.finalStates[5];
                  h4.eTransition[1]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==7) begin //h
                //
                h4.gTransition[1] = compute_hamming_distance(data[7],data[6],high,low);
                h4.hTransition[1] = compute_hamming_distance(data[7],data[6],low,high);
                if ((h4.gTransition[1] + h3.hammingDistances.finalStates[6])<(h4.hTransition[1] + h3.hammingDistances.finalStates[7])) begin
                  h4.hammingDistances.finalStates[7]= h4.gTransition[1] + h3.hammingDistances.finalStates[6];
                  h4.hTransition[1]=3;
                end
                else begin
                  h4.hammingDistances.finalStates[7]= h4.hTransition[1] + h3.hammingDistances.finalStates[7];
                  h4.gTransition[1]=3;
                end
                stage_n = 0;
                steps_n = steps_n+1;
              end //step 3 complete
            end
            else if(steps_n==5) begin
              if (stage_n==0) begin
                
                h5.aTransition[0] = compute_hamming_distance(data[5],data[4],low,low);
                h5.bTransition[0] = compute_hamming_distance(data[5],data[4],high,high);
                if ((h5.aTransition[0] + h4.hammingDistances.finalStates[0])<(h5.bTransition[0] + h4.hammingDistances.finalStates[1])) begin
                  h5.hammingDistances.finalStates[0]= h5.aTransition[0] + h4.hammingDistances.finalStates[0];
                  h5.bTransition[0]=3;
                end
                else begin
                  h5.hammingDistances.finalStates[0]= h5.bTransition[0] + h4.hammingDistances.finalStates[1];
                  h5.aTransition[0] = 3;
                end
              stage_n = stage_n+1;
            end
            else if (stage_n==1) begin
              
              h5.cTransition[0] = compute_hamming_distance(data[5],data[4],high,low);
              h5.dTransition[0] = compute_hamming_distance(data[5],data[4],low,high);
              if ((h5.cTransition[0] + h4.hammingDistances.finalStates[2])<(h5.dTransition[0] + h4.hammingDistances.finalStates[3])) begin
                h5.hammingDistances.finalStates[1]= h5.cTransition[0] + h4.hammingDistances.finalStates[2];
                h5.dTransition[0]=3;
              end
              else begin
                h5.hammingDistances.finalStates[1]= h5.dTransition[0] + h4.hammingDistances.finalStates[3];
                h5.cTransition[0] = 3;
              end
              stage_n = stage_n+1;
            end
            else if (stage_n==2) begin
              //
              h5.eTransition[0] = compute_hamming_distance(data[5],data[4],high,high);
              h5.fTransition[0] = compute_hamming_distance(data[5],data[4],low,low);
              if ((h5.eTransition[0] + h4.hammingDistances.finalStates[4])<(h5.fTransition[0] + h4.hammingDistances.finalStates[5])) begin
                h5.hammingDistances.finalStates[2]= h5.eTransition[0] + h4.hammingDistances.finalStates[4];
                h5.fTransition[0]=3;
              end
              else begin
                h5.hammingDistances.finalStates[2]= h5.fTransition[0] + h4.hammingDistances.finalStates[5];
                h5.eTransition[0]=3;
              end
              stage_n = stage_n+1;
            end
            else if (stage_n==3) begin
              //
              h5.gTransition[0] = compute_hamming_distance(data[5],data[4],low,high);
              h5.hTransition[0] = compute_hamming_distance(data[5],data[4],high,low);
              if ((h5.gTransition[0] + h4.hammingDistances.finalStates[6])<(h5.hTransition[0] + h4.hammingDistances.finalStates[7])) begin
                h5.hammingDistances.finalStates[3]= h5.gTransition[0] + h4.hammingDistances.finalStates[6];
                h5.hTransition[0]=3;
              end
              else begin
                h5.hammingDistances.finalStates[3]= h5.hTransition[0] + h4.hammingDistances.finalStates[7];
                h5.gTransition[0]=3;
              end
              stage_n = stage_n+1;
            end
            else if (stage_n==4) begin
              //
              h5.aTransition[1] = compute_hamming_distance(data[5],data[4],high,high);
              h5.bTransition[1] = compute_hamming_distance(data[5],data[4],low,low);
              if ((h5.aTransition[1] + h4.hammingDistances.finalStates[0])<(h5.bTransition[1] + h4.hammingDistances.finalStates[1])) begin
                h5.hammingDistances.finalStates[4]= h5.aTransition[1] + h4.hammingDistances.finalStates[0];
                h5.bTransition[1]=3;
              end
              else begin
                h5.hammingDistances.finalStates[4]= h5.bTransition[1] + h4.hammingDistances.finalStates[1];
                h5.aTransition[1] = 3;
              end
              stage_n = stage_n+1;
            end
            else if (stage_n==5) begin
              //
              h5.cTransition[1] = compute_hamming_distance(data[5],data[4],low,high);
              h5.dTransition[1] = compute_hamming_distance(data[5],data[4],high,low);
              if ((h5.cTransition[1] + h4.hammingDistances.finalStates[2])<(h5.dTransition[1] + h4.hammingDistances.finalStates[3])) begin
                h5.hammingDistances.finalStates[5]= h5.cTransition[1] + h4.hammingDistances.finalStates[2];
                h5.dTransition[1]=3;
              end
              else begin
                h5.hammingDistances.finalStates[5]= h5.dTransition[1] + h4.hammingDistances.finalStates[3];
                h5.cTransition[1] = 3;
              end
              stage_n = stage_n+1;
            end
            else if (stage_n==6) begin
              //
              h5.eTransition[1] = compute_hamming_distance(data[5],data[4],low,low);
              h5.fTransition[1] = compute_hamming_distance(data[5],data[4],high,high);
              if ((h5.eTransition[1] + h4.hammingDistances.finalStates[4])<(h5.fTransition[1] + h4.hammingDistances.finalStates[5])) begin
                h5.hammingDistances.finalStates[6]= h5.eTransition[1] + h4.hammingDistances.finalStates[4];
                h5.fTransition[1]=3;
              end
              else begin
                h5.hammingDistances.finalStates[6]= h5.fTransition[1] + h4.hammingDistances.finalStates[5];
                h5.eTransition[1]=3;
              end
              stage_n = stage_n+1;
            end
            else if (stage_n==7) begin
              //
              h5.gTransition[1] = compute_hamming_distance(data[5],data[4],high,low);
              h5.hTransition[1] = compute_hamming_distance(data[5],data[4],low,high);
              if ((h5.gTransition[1] + h4.hammingDistances.finalStates[6])<(h5.hTransition[1] + h4.hammingDistances.finalStates[7])) begin
                h5.hammingDistances.finalStates[7]= h5.gTransition[1] + h4.hammingDistances.finalStates[6];
                h5.hTransition[1]=3;
              end
              else begin
                h5.hammingDistances.finalStates[7]= h5.hTransition[1] + h4.hammingDistances.finalStates[7];
                h5.gTransition[1]=3;
              end
              stage_n = 0;
              steps_n = steps_n+1;
            end
            end 
            else if (steps_n == 6) begin
              if (stage_n==0) begin
                //
                h6.aTransition[0] = compute_hamming_distance(data[3],data[2],low,low);
                h6.bTransition[0] = compute_hamming_distance(data[3],data[2],high,high);
                if ((h6.aTransition[0] + h5.hammingDistances.finalStates[0])<(h6.bTransition[0] + h5.hammingDistances.finalStates[1])) begin
                  h6.hammingDistances.finalStates[0]= h6.aTransition[0] + h5.hammingDistances.finalStates[0];
                  h6.bTransition[0]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[0]= h6.bTransition[0] + h5.hammingDistances.finalStates[1];
                  h6.aTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==1) begin
                //
                h6.cTransition[0] = compute_hamming_distance(data[3],data[2],high,low);
                h6.dTransition[0] = compute_hamming_distance(data[3],data[2],low,high);
                if ((h6.cTransition[0] + h5.hammingDistances.finalStates[2])<(h6.dTransition[0] + h5.hammingDistances.finalStates[3])) begin
                  h6.hammingDistances.finalStates[1]= h6.cTransition[0] + h5.hammingDistances.finalStates[2];
                  h6.dTransition[0]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[1]= h6.dTransition[0] + h5.hammingDistances.finalStates[3];
                  h6.cTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==2) begin
                //
                h6.eTransition[0] = compute_hamming_distance(data[3],data[2],high,high);
                h6.fTransition[0] = compute_hamming_distance(data[3],data[2],low,low);
                if ((h6.eTransition[0] + h5.hammingDistances.finalStates[4])<(h6.fTransition[0] + h5.hammingDistances.finalStates[5])) begin
                  h6.hammingDistances.finalStates[2]= h6.eTransition[0] + h5.hammingDistances.finalStates[4];
                  h6.fTransition[0]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[2]= h6.fTransition[0] + h5.hammingDistances.finalStates[5];
                  h6.eTransition[0]=3;
                end 
                stage_n = stage_n+1;
              end
              else if (stage_n==3) begin
                //
                h6.gTransition[0] = compute_hamming_distance(data[3],data[2],low,high);
                h6.hTransition[0] = compute_hamming_distance(data[3],data[2],high,low);
                if ((h6.gTransition[0] + h5.hammingDistances.finalStates[6])<(h6.hTransition[0] + h5.hammingDistances.finalStates[7])) begin
                  h6.hammingDistances.finalStates[3]= h6.gTransition[0] + h5.hammingDistances.finalStates[6];
                  h6.hTransition[0]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[3]= h6.hTransition[0] + h5.hammingDistances.finalStates[7];
                  h6.gTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==4) begin
                //
                h6.aTransition[1] = compute_hamming_distance(data[3],data[2],high,high);
                h6.bTransition[1] = compute_hamming_distance(data[3],data[2],low,low);
                if ((h6.aTransition[1] + h5.hammingDistances.finalStates[0])<(h6.bTransition[1] + h5.hammingDistances.finalStates[1])) begin
                  h6.hammingDistances.finalStates[4]= h6.aTransition[1] + h5.hammingDistances.finalStates[0];
                  h6.bTransition[1]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[4]= h6.bTransition[1] + h5.hammingDistances.finalStates[1];
                  h6.aTransition[1]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==5) begin
                //
                h6.cTransition[1] = compute_hamming_distance(data[3],data[2],low,high);
                h6.dTransition[1] = compute_hamming_distance(data[3],data[2],high,low);
                if ((h6.cTransition[1] + h5.hammingDistances.finalStates[2])<(h6.dTransition[1] + h5.hammingDistances.finalStates[3])) begin
                  h6.hammingDistances.finalStates[5]= h6.cTransition[1] + h5.hammingDistances.finalStates[2];
                  h6.dTransition[1]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[5]= h6.dTransition[1] + h5.hammingDistances.finalStates[3];
                  h6.cTransition[1]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==6) begin
                //
                h6.eTransition[1] = compute_hamming_distance(data[3],data[2],low,low);
                h6.fTransition[1] = compute_hamming_distance(data[3],data[2],high,high);
                if ((h6.eTransition[1] + h5.hammingDistances.finalStates[4])<(h6.fTransition[1] + h5.hammingDistances.finalStates[5])) begin
                  h6.hammingDistances.finalStates[6]= h6.eTransition[1] + h5.hammingDistances.finalStates[4];
                  h6.fTransition[1]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[6]= h6.fTransition[1] + h5.hammingDistances.finalStates[5];
                  h6.eTransition[1]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==7) begin
                //
                h6.gTransition[1] = compute_hamming_distance(data[3],data[2],high,low);
                h6.hTransition[1] = compute_hamming_distance(data[3],data[2],low,high);
                if ((h6.gTransition[1] + h5.hammingDistances.finalStates[6])<(h6.hTransition[1] + h5.hammingDistances.finalStates[7])) begin
                  h6.hammingDistances.finalStates[7]= h6.gTransition[1] + h5.hammingDistances.finalStates[6];
                  h6.hTransition[1]=3;
                end
                else begin
                  h6.hammingDistances.finalStates[7]= h6.hTransition[1] + h5.hammingDistances.finalStates[7];
                  h6.gTransition[1]=3;
                end
                stage_n = 0;
                steps_n = steps_n+1;
              end
            end
            else if (steps_n==7) begin
              if (stage_n==0) begin
                //
                h7.aTransition[0] = compute_hamming_distance(data[1],data[0],low,low);
                h7.bTransition[0] = compute_hamming_distance(data[1],data[0],high,high);
                if ((h7.aTransition[0] + h6.hammingDistances.finalStates[0])<(h7.bTransition[0] + h6.hammingDistances.finalStates[1])) begin
                  h7.hammingDistances.finalStates[0]= h7.aTransition[0] + h6.hammingDistances.finalStates[0];
                  h7.bTransition[0]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[0]= h7.bTransition[0] + h6.hammingDistances.finalStates[1];
                  h7.aTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==1) begin
                //
                h7.cTransition[0] = compute_hamming_distance(data[1],data[0],high,low);
                h7.dTransition[0] = compute_hamming_distance(data[1],data[0],low,high);
                if ((h7.cTransition[0] + h6.hammingDistances.finalStates[2])<(h7.dTransition[0] + h6.hammingDistances.finalStates[3])) begin
                  h7.hammingDistances.finalStates[1]= h7.cTransition[0] + h6.hammingDistances.finalStates[2];
                  h7.dTransition[0]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[1]= h7.dTransition[0] + h6.hammingDistances.finalStates[3];
                  h7.cTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==2) begin
                //
                h7.eTransition[0] = compute_hamming_distance(data[1],data[0],high,high);
                h7.fTransition[0] = compute_hamming_distance(data[1],data[0],low,low);
                if ((h7.eTransition[0] + h6.hammingDistances.finalStates[4])<(h7.fTransition[0] + h6.hammingDistances.finalStates[5])) begin
                  h7.hammingDistances.finalStates[2]= h7.eTransition[0] + h6.hammingDistances.finalStates[4];
                  h7.fTransition[0]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[2]= h7.fTransition[0] + h6.hammingDistances.finalStates[5];
                  h7.eTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==3) begin
                //
                h7.gTransition[0] = compute_hamming_distance(data[1],data[0],low,high);
                h7.hTransition[0] = compute_hamming_distance(data[1],data[0],high,low);
                if ((h7.gTransition[0] + h6.hammingDistances.finalStates[6])<(h7.hTransition[0] + h6.hammingDistances.finalStates[7])) begin
                  h7.hammingDistances.finalStates[3]= h7.gTransition[0] + h6.hammingDistances.finalStates[6];
                  h7.hTransition[0]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[3]= h7.hTransition[0] + h6.hammingDistances.finalStates[7];
                  h7.gTransition[0]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==4) begin
                //
                h7.aTransition[1] = compute_hamming_distance(data[1],data[0],high,high);
                h7.bTransition[1] = compute_hamming_distance(data[1],data[0],low,low);
                if ((h7.aTransition[1] + h6.hammingDistances.finalStates[0])<(h7.bTransition[1] + h6.hammingDistances.finalStates[1])) begin
                  h7.hammingDistances.finalStates[4]= h7.aTransition[1] + h6.hammingDistances.finalStates[0];
                  h7.bTransition[1]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[4]= h7.bTransition[1] + h6.hammingDistances.finalStates[1];
                  h7.aTransition[1]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==5) begin
                //
                h7.cTransition[1] = compute_hamming_distance(data[1],data[0],low,high);
                h7.dTransition[1] = compute_hamming_distance(data[1],data[0],high,low);
                if ((h7.cTransition[1] + h6.hammingDistances.finalStates[2])<(h7.dTransition[1] + h6.hammingDistances.finalStates[3])) begin
                  h7.hammingDistances.finalStates[5]= h7.cTransition[1] + h6.hammingDistances.finalStates[2];
                  h7.dTransition[1]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[5]= h7.dTransition[1] + h6.hammingDistances.finalStates[3];
                  h7.cTransition[1]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==6) begin
                //
                h7.eTransition[1] = compute_hamming_distance(data[1],data[0],low,low);
                h7.fTransition[1] = compute_hamming_distance(data[1],data[0],high,high);
                if ((h7.eTransition[1] + h6.hammingDistances.finalStates[4])<(h7.fTransition[1] + h6.hammingDistances.finalStates[5])) begin
                  h7.hammingDistances.finalStates[6]= h7.eTransition[1] + h6.hammingDistances.finalStates[4];
                  h7.fTransition[1]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[6]= h7.fTransition[1] + h6.hammingDistances.finalStates[5];
                  h7.eTransition[1]=3;
                end
                stage_n = stage_n+1;
              end
              else if (stage_n==7) begin
                //
                h7.gTransition[1] = compute_hamming_distance(data[1],data[0],high,low);
                h7.hTransition[1] = compute_hamming_distance(data[1],data[0],low,high);
                if ((h7.gTransition[1] + h6.hammingDistances.finalStates[6])<(h7.hTransition[1] + h6.hammingDistances.finalStates[7])) begin
                  h7.hammingDistances.finalStates[7]= h7.gTransition[1] + h6.hammingDistances.finalStates[6];
                  h7.hTransition[1]=3;
                end
                else begin
                  h7.hammingDistances.finalStates[7]= h7.hTransition[1] + h6.hammingDistances.finalStates[7];
                  h7.gTransition[1]=3;
                end
                stage_n = 0;
                steps_n = steps_n+1;
              end
            end //end of step 7
            
        end
                if(ready==1) begin
                              if (counter_for_path==0) begin
                                for (int j =0;j<8;j=j+1) begin
                                  temp_states[j] = h7.hammingDistances.finalStates[j];
                                end
                                lowest_value = temp_states[0];
                                lowest_index = 0;
                                  for (int l = 0; l<8; l=l+1) begin
                                    //find lowest value in temp_states by comparing with h7.hammingDistances.finalStates and store in lowest_value
                                    if (temp_states[l]<lowest_value ) begin
                                      lowest_value = temp_states[l];
                                      lowest_index = l;
                                    end
                                  end
                                  counter_for_path = counter_for_path+1;
                              end //end of counter_for_path==0
                              else if(counter_for_path>=1 && counter_for_path<=7) begin
                                returned_path = getReturnPath(lowest_index, table_counter);
                                set_outputs(lowest_index, returned_path, pinOut);
                                lowest_index = returned_path;
                                table_counter = table_counter-1;
                                pinOut=pinOut+1;
                                counter_for_path = counter_for_path+1;
                              end
                          end
                  end

  // always @(posedge clk) begin
  //         if(ready==1) begin
  //             if (counter_for_path==0) begin
  //               for (int j =0;j<8;j=j+1) begin
  //                 temp_states[j] = h7.hammingDistances.finalStates[j];
  //               end
  //               lowest_value = temp_states[0];
  //               lowest_index = 0;
  //                 for (int l = 0; l<8; l=l+1) begin
  //                   //find lowest value in temp_states by comparing with h7.hammingDistances.finalStates and store in lowest_value
  //                   if (temp_states[l]<lowest_value ) begin
  //                     lowest_value = temp_states[l];
  //                     lowest_index = l;
  //                   end
  //                 end
  //                 counter_for_path = counter_for_path+1;
  //             end //end of counter_for_path==0
  //             else if(counter_for_path>=1 && counter_for_path<=7) begin
  //               returned_path = getReturnPath(lowest_index, table_counter);
  //               set_outputs(lowest_index, returned_path, pinOut);
  //               lowest_index = returned_path;
  //               table_counter = table_counter-1;
  //               pinOut=pinOut+1;
  //               counter_for_path = counter_for_path+1;
  //             end
  //         end
  // end //end of always


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
        if (h1.recievedSequence[0]!= low && h1.recievedSequence[1]!= low) begin
          h1.aTransition[0] = 2+h1.previousHammingDistance[0];
        end
        if(h1.recievedSequence[0]!= low && h1.recievedSequence[1]== low) begin
          h1.aTransition[0] = 1+h1.previousHammingDistance[0];
        end
        if(h1.recievedSequence[0]== low && h1.recievedSequence[1]!= low) begin
          h1.aTransition[0] = 1+h1.previousHammingDistance[0];
        end
        if(h1.recievedSequence[0]== low && h1.recievedSequence[1]== low) begin
          h1.aTransition[0] = h1.previousHammingDistance[0];
        end
        if (h1.recievedSequence[0]!= high && h1.recievedSequence[1]!= high) begin
          h1.aTransition[1] = 2+h1.previousHammingDistance[0];
        end
        if(h1.recievedSequence[0]!= high && h1.recievedSequence[1]== high) begin
          h1.aTransition[1] = 1+h1.previousHammingDistance[0];
        end
        if(h1.recievedSequence[0]== high && h1.recievedSequence[1]!= high) begin
          h1.aTransition[1] = 1+h1.previousHammingDistance[0];
        end
        if(h1.recievedSequence[0]== high && h1.recievedSequence[1]== high) begin
          h1.aTransition[1] = h1.previousHammingDistance[0];
        end
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
                returnPath =3;
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
            default: returnPath= 7;       
          endcase
          return returnPath;
        end //end of if currentTable
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
          endcase
          return returnPath;
        end //end of if currentTable
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
          endcase
          return returnPath;
        end //end of if currentTable
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
          endcase
          return returnPath;
        end //end of if currentTable
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
          endcase
          return returnPath;
        end //end of if currentTable
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
          endcase
          return returnPath;
        end //end of if currentTable
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
          endcase
          return returnPath;
        end //end of if currentTable
     end//
  endfunction 
  task set_outputs(input bit[3:0] from_s, input bit[3:0] at_state,input byte pinNumber); // last to first
     begin //task begin
      if (from_s==0 && at_state==0) begin
         out[pinNumber] = 0;
      end
      else if(from_s==0 && at_state==1 ) begin
         out[pinNumber] = 0;
      end
      else if(from_s==1 && at_state==2 ) begin
         out[pinNumber] = 0;
      end
      else if(from_s==1 && at_state==3 ) begin
         out[pinNumber] = 0;
      end
      else if(from_s==2 && at_state==4 ) begin
         out[pinNumber] = 0;
      end
      else if(from_s==2 && at_state==5 ) begin
         out[pinNumber] = 0;
      end
      else if(from_s==3 && at_state==6 ) begin
         out[pinNumber] = 0;
      end
      else if(from_s==3 && at_state==7 ) begin
         out[pinNumber] = 0;
      end
      else if(from_s==4 && at_state==0 ) begin
         out[pinNumber] = 1;
      end
      else if(from_s==4 && at_state==1 ) begin
         out[pinNumber] = 1;
      end
      else if(from_s==5 && at_state==2 ) begin
         out[pinNumber] = 1;
      end
      else if(from_s==5 && at_state==3 ) begin
         out[pinNumber] = 1;
      end
      else if(from_s==6 && at_state==4 ) begin
         out[pinNumber] = 1;
      end
      else if(from_s==6 && at_state==5 ) begin
         out[pinNumber] = 1;
      end
      else if(from_s==7 && at_state==6 ) begin
         out[pinNumber] = 1;
      end
      else if(from_s==7 && at_state==7 ) begin
         out[pinNumber] = 1;
      end
     end // task end
  endtask

endmodule