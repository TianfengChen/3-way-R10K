`ifndef __BRU_SV__
`define __BRU_SV__
`timescale 1ns/100ps



module bru(// Inputs
	input [`XLEN-1:0] rs1,    // Value to check against condition
	input [`XLEN-1:0] rs2,
	output [`XLEN-1:0] rd,	//dest reg for jal/jalr
	input [`XLEN-1:0] op1,
	input [`XLEN-1:0] op2,
	input cond_branch,
	input uncond_branch,
	input [`XLEN-1:0] pc,	//use this to calculate dest reg for jal/jalr
	input [`XLEN-1:0] inst,
	output [`XLEN-1:0] target_pc,
	output logic branch_taken    // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	assign target_pc = op1 + op2;
	assign rd = pc + 4;
	//assign target_pc = inst[6:0] == 7'b1100011 ? (pc + `RV32_signext_Bimm(inst)) : inst[6:0] == 7'b1100111 ? (rs1 + `RV32_signext_Iimm(inst)) : (pc + `RV32_signext_Jimm(inst));
	always_comb begin
		if(cond_branch) begin
			case (inst[14:12])
				3'b000: branch_taken = signed_rs1 == signed_rs2;  // BEQ
				3'b001: branch_taken = signed_rs1 != signed_rs2;  // BNE
				3'b100: branch_taken = signed_rs1 < signed_rs2;   // BLT
				3'b101: branch_taken = signed_rs1 >= signed_rs2;  // BGE
				3'b110: branch_taken = rs1 < rs2;                 // BLTU
				3'b111: branch_taken = rs1 >= rs2;                // BGEU
				default:branch_taken = 0;
			endcase
		end
		else if(uncond_branch)
			branch_taken = 1;
		else
			branch_taken = 0;
	end


	
endmodule // brcond
`endif //__BRU_SV__
