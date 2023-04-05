// This is an 4 stage pipelined 
// multiplier that multiplies 2 64-bit integers and returns the low 64 bits 
// of the result.  This is not an ideal multiplier but is sufficient to 
// allow a faster clock period than straight *
// This module instantiates 8 pipeline stages as an array of submodules.

`timescale 1ns/100ps

`define MULT_WIDTH 64
// 8 stage
// `define STAGE_WIDTH 8
// 4 stage
`define STAGE_WIDTH 4
// 2 stage
// `define STAGE_WIDTH 2

module mult(
				input clock, reset,
				input [`MULT_WIDTH-1:0] mcand, mplier,
				input start,
				
				output [`MULT_WIDTH-1:0] product,
				output done
			);

  logic [`MULT_WIDTH-1:0] mcand_out, mplier_out;
  logic [((`STAGE_WIDTH-1)*`MULT_WIDTH)-1:0] internal_products, internal_mcands, internal_mpliers;
  logic [2:0] internal_dones;
  
	mult_stage mstage [`STAGE_WIDTH-1:0]  (
		.clock(clock),
		.reset(reset),
		.product_in({internal_products,`MULT_WIDTH'h0}),
		.mplier_in({internal_mpliers,mplier}),
		.mcand_in({internal_mcands,mcand}),
		.start({internal_dones,start}),
		.product_out({product,internal_products}),
		.mplier_out({mplier_out,internal_mpliers}),
		.mcand_out({mcand_out,internal_mcands}),
		.done({done,internal_dones})
	);

endmodule
