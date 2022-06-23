
// Code your design here
module d_ff(clk, reset, q, d, out);
  input clk;
  input reset;
  input d;
  output [3:0]q;
  output [1:0]out;
  reg  [3:0]q;
  reg [1:0]out;
  always @ (posedge clk) begin
    if(!reset) begin
		q[3]=0;
      		q[2]=0;
		q[1]=0;
		q[0]=0;
		//out[1]=0;
		//out[0]=0;
	end

  	else begin
		q[3]=q[2];
		q[2]=q[1];
		q[1]=q[0];
		q[0]=d;
		
	end
    out[1]=q[0]^q[1]^q[2]^q[3];
    out[0]=q[0]^q[1]^q[3];
	
end

endmodule