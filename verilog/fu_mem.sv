`timescale 1ns/100ps

//
// Mem module
//

module fu_mem(// Inputs
	input [31:0]  						op1_val_mem_in,
	input [31:0]  						op2_val_mem_in,
	input								rd_mem_in,
	input								wr_mem_in,
	input [31:0]  						inst_mem_in,		
	output reg [31:0]					address_out
);


		
	always_comb begin
		if(wr_mem_in)
			address_out	= op1_val_mem_in + `RV32_signext_Simm(inst_mem_in);
		else if(rd_mem_in)
			address_out	= op1_val_mem_in + `RV32_signext_Iimm(inst_mem_in);
		else
			address_out = 0;
	end
	

endmodule 
