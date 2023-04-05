`timescale 1ns/100ps


module mux41 #(	
	parameter WIDTH = 8
)
(
	input [1:0] sel,	
	input [WIDTH-1:0] in0,	
	input [WIDTH-1:0] in1,	
	input [WIDTH-1:0] in2,	
	input [WIDTH-1:0] in3,	
	output reg [WIDTH-1:0] out					
);

	always_comb begin
		case(sel) 
			2'd0: out = in0; 	
			2'd1: out = in1; 	
			2'd2: out = in2; 	
			2'd3: out = in3; 	
		endcase
	end

endmodule
