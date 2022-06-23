// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module dff_tb();
  reg clk;
  reg reset;
  reg d;
  wire [3:0] q;
  wire [1:0] out;
  d_ff d_ff0(clk,reset,q,d,out);
  
  initial begin
 	$dumpfile("dump.vcd"); 
    	$dumpvars(1);
	clk<=~clk;
	reset<=0;
	#2 clk<=~clk;
	#1 reset<=1;
        #1 clk<=~clk;
	repeat(14) begin
	#2 clk<=~clk;
	end
   end
  
  initial begin
  
	//#5.5 d<=1;
//	#3.5 d<=0;
//	#3.5 d<=1;
//	#3.5 d<=1;
	//#3.5 d<=0;
//	#3.5 d<=0;
	//#3.5 d<=0;
	#5.5 d<=1;
	#3.5 d<=0;
	#3.5 d<=0;
	#3.5 d<=1;
	#3.5 d<=1;
	#3.5 d<=0;
	#3.5 d<=1;
  end
	initial begin
	clk<=0;
	end

  
endmodule