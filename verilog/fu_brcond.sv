`timescale 1ns/100ps

module fu_brcond(// Inputs
	input [`XLEN-1:0] rs1,    // Value to check against condition
	input [`XLEN-1:0] rs2,
	input [`XLEN-1:0] inst,
	input [`XLEN-1:0] pc_add,
	input [31:0] imm_add,
	//input [2:0]  func,  // Specifies which condition to check

	output [`XLEN-1:0] brcond_add,
	output logic cond    // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	assign brcond_add = inst[6:0] == 7'b1100011 ? (pc_add + `RV32_signext_Bimm(inst)) : inst[6:0] == 7'b1100111 ? (rs1 + `RV32_signext_Iimm(inst)) : (pc_add + `RV32_signext_Jimm(inst));
	always_comb begin
		cond = 0;
		case (inst[14:12])
			3'b000: cond = signed_rs1 == signed_rs2;  // BEQ
			3'b001: cond = signed_rs1 != signed_rs2;  // BNE
			3'b100: cond = signed_rs1 < signed_rs2;   // BLT
			3'b101: cond = signed_rs1 >= signed_rs2;  // BGE
			3'b110: cond = rs1 < rs2;                 // BLTU
			3'b111: cond = rs1 >= rs2;                // BGEU
		endcase
	end
	
endmodule // brcond
