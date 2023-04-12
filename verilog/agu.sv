`timescale 1ns/100ps

//
// Mem module
//

module agu(// Inputs
	input [31:0]  						opa,
	input [31:0]  						opb,		
	output reg [31:0]					result
);

	assign result = opa + opb;
	

endmodule 
