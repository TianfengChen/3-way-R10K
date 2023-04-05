`timescale 1ns/100ps

//
// fu_group main module
//
module fu_group(
	input clock,               // system clock
	input reset,               // system reset

	// Alu module input
	input [`XLEN-1:0] alu0_opa,
	input [`XLEN-1:0] alu0_opb,
	input [4:0]	func_0,
	input [`XLEN-1:0] alu1_opa,
	input [`XLEN-1:0] alu1_opb,
	input [4:0]	func_1,
	input [`XLEN-1:0] alu2_opa,
	input [`XLEN-1:0] alu2_opb,
	input [4:0]	func_2,

	// BrCond module input
	input [`XLEN-1:0] rs1,
	input [`XLEN-1:0] rs2,
	input [`XLEN-1:0] inst,
	input [`XLEN-1:0] pc_add,
	input [`XLEN-1:0] imm_add,
	//input [2:0] brcond_func,

	// Mult module input
	input [`XLEN-1:0] mcand,
	input [`XLEN-1:0] mplier,
	input logic mult_en,
	input [4:0]	mult_func,

	// Mem module input
	input [31:0] op1_val_mem_in,
	input [31:0] op2_val_mem_in,
	input		 rd_mem_in,
	input		 wr_mem_in,
	input [31:0] inst_mem_in,		

	// Alu module output
	output logic [`XLEN-1:0] alu0_result,
	output logic [`XLEN-1:0] alu1_result,
	output logic [`XLEN-1:0] alu2_result,

	// BrCond module output
	output logic brcond_result,
	output logic [`XLEN-1:0] brcond_add,

	// Mult module output
	output logic [`XLEN-1:0] mult_result,
	output logic mult_done,

	// Mem module output
	output [31:0] address_out
);

	//
	// instantiate the ALU
	// ALU_0
	//
	fu_alu alu_0 (
		// Inputs
		.opa(alu0_opa),
		.opb(alu0_opb),
		.func(func_0),

		// Output
		.result(alu0_result)
	);

	//
	// ALU_1
	//
	fu_alu alu_1 (
		// Inputs
		.opa(alu1_opa),
		.opb(alu1_opb),
		.func(func_1),

		// Output
		.result(alu1_result)
	);

	//
	// ALU_2
	//
	fu_alu alu_2 (
		// Inputs
		.opa(alu2_opa),
		.opb(alu2_opb),
		.func(func_2),

		// Output
		.result(alu2_result)
	);

	//
	// instantiate the branch condition tester
	//
	fu_brcond brcond_0 (
		// Inputs
		.rs1(rs1), 
		.rs2(rs2),
		.inst(inst),
		.pc_add(pc_add),
		.imm_add(imm_add),
		//.func(brcond_func), // inst bits to determine check

		// Output
		.cond(brcond_result),
		.brcond_add(brcond_add)
	);

	//
	// instantiate the multiplier
	//
	fu_mult mult (
		// Inputs
		.clock(clock),
		.reset(reset),
		.mcand(mcand), 
		.mplier(mplier),
		.mult_en(mult_en),
		.mult_func(mult_func), // inst bits to determine check

		// Output
		.mult_result(mult_result),
		.mult_done(mult_done)
	);

	fu_mem fu_mem_inst (
		.op1_val_mem_in	(op1_val_mem_in	),
		.op2_val_mem_in	(op2_val_mem_in	),
		.rd_mem_in		(rd_mem_in		),
		.wr_mem_in		(wr_mem_in		),
		.inst_mem_in	(inst_mem_in	),			
		.address_out	(address_out	)
	);

endmodule // module ex_stage

