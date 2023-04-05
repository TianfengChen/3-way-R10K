/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  id_stage.v                                          //
//                                                                     //
//  Description :  instruction decode (ID) stage of the pipeline;      // 
//                 decode the instruction fetch register operands, and // 
//                 compute immediate operand (if applicable)           // 
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps
  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
module decoder(

	//input [31:0] inst,
	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	input IF_ID_PACKET if_packet,

	output logic [3:0] FU_type,
	output logic	   rs1_use_prf, 
	output logic	   rs2_use_prf,

	output ALU_OPA_SELECT opa_select,
	output ALU_OPB_SELECT opb_select,
	output DEST_REG_SEL   dest_reg, // mux selects
	output ALU_FUNC       alu_func,
	output logic rd_mem, 
	output logic wr_mem, 
	output logic cond_branch, 
	output logic uncond_branch,
	output logic csr_op,    // used for CSR operations, we only used this as 
	                        //a cheap way to get the return code out
	output logic halt,      // non-zero on a halt
	output logic illegal,    // non-zero on an illegal instruction
	output logic valid_inst  // for counting valid instructions executed
	                        // and for making the fetch stage die on halts/
	                        // keeping track of when to allow the next
	                        // instruction out of fetch
	                        // 0 for HALT and illegal instructions (die on halt)

);

	INST inst;
	logic valid_inst_in;
	
	assign inst          = if_packet.inst;
	assign valid_inst_in = if_packet.valid;
	assign valid_inst    = valid_inst_in;
	
	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		FU_type	   = 4'b0001;
		rs1_use_prf= 1;
		rs2_use_prf= 1;
		opa_select = OPA_IS_RS1;
		opb_select = OPB_IS_RS2;
		alu_func = ALU_ADD;
		dest_reg = DEST_NONE;
		csr_op = `FALSE;
		rd_mem = `FALSE;
		wr_mem = `FALSE;
		cond_branch = `FALSE;
		uncond_branch = `FALSE;
		halt = `FALSE;
		illegal = `FALSE;
		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_ZERO;
					opb_select = OPB_IS_U_IMM;
					rs1_use_prf= 0;
					rs2_use_prf= 0;
				end
				`RV32_AUIPC: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_PC;
					opb_select = OPB_IS_U_IMM;
					rs1_use_prf= 0;
					rs2_use_prf= 0;
				end
				`RV32_JAL: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_PC;
					opb_select    = OPB_IS_J_IMM;
					uncond_branch = `TRUE;
					rs1_use_prf= 0;
					rs2_use_prf= 0;
					FU_type	   = 4'b1000;
				end
				`RV32_JALR: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_RS1;
					opb_select    = OPB_IS_I_IMM;
					uncond_branch = `TRUE;
					rs2_use_prf= 0;
					FU_type	   = 4'b1000;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					opa_select  = OPA_IS_RS1;
					opb_select  = OPB_IS_RS2;
					cond_branch = `TRUE;
					FU_type	    = 4'b1000;
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					rd_mem     = `TRUE;
					FU_type	    = 4'b0100;
					rs2_use_prf= 0;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					opb_select = OPB_IS_RS2;
					wr_mem     = `TRUE;
					FU_type	    = 4'b0100;
				end
				`RV32_ADDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					rs2_use_prf= 0;
				end
				`RV32_SLTI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLT;
					rs2_use_prf= 0;
				end
				`RV32_SLTIU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLTU;
					rs2_use_prf= 0;
				end
				`RV32_ANDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_AND;
					rs2_use_prf= 0;
				end
				`RV32_ORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_OR;
					rs2_use_prf= 0;
				end
				`RV32_XORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_XOR;
					rs2_use_prf= 0;
				end
				`RV32_SLLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLL;
					rs2_use_prf= 0;
				end
				`RV32_SRLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRL;
					rs2_use_prf= 0;
				end
				`RV32_SRAI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRA;
					rs2_use_prf= 0;
				end
				`RV32_ADD: begin
					dest_reg   = DEST_RD;
				end
				`RV32_SUB: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SUB;
				end
				`RV32_SLT: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLT;
				end
				`RV32_SLTU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLTU;
				end
				`RV32_AND: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_AND;
				end
				`RV32_OR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_OR;
				end
				`RV32_XOR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_XOR;
				end
				`RV32_SLL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLL;
				end
				`RV32_SRL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRL;
				end
				`RV32_SRA: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRA;
				end
				`RV32_MUL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MUL;
					FU_type	    = 4'b0010;
				end
				`RV32_MULH: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULH;
					FU_type	    = 4'b0010;
				end
				`RV32_MULHSU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHSU;
					FU_type	    = 4'b0010;
				end
				`RV32_MULHU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHU;
					FU_type	    = 4'b0010;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					csr_op = `TRUE;
					rs1_use_prf= 0;
					rs2_use_prf= 0;

				end
				`WFI: begin
					halt = `TRUE;
					rs1_use_prf= 0;
					rs2_use_prf= 0;
				end
				default: illegal = `TRUE;

		endcase // casez (inst)
		end // if(valid_inst_in)
	end // always
endmodule // decoder

module rs_value_decoder(
	//inputs
	input ALU_OPA_SELECT opa_select,
	input ALU_OPB_SELECT opb_select,
	input INST	      inst,
	input [`XLEN-1:0] NPC,
	input [`XLEN-1:0] PC,
	//outputs
	output logic [`XLEN-1:0] rs1_nprf_value,
	output logic		  rs1_is_nprf, 
	output logic [`XLEN-1:0] rs2_nprf_value,
	output logic		  rs2_is_imm

);
	always_comb begin
		rs1_nprf_value = `XLEN'hdeadfbac;
		rs1_is_nprf    = 0;
		case (opa_select)
			OPA_IS_RS1:  rs1_nprf_value = 1'b0;
			OPA_IS_NPC:  begin 
				     rs1_nprf_value = NPC; 
				     rs1_is_nprf    = 1'b1; 
			end
			OPA_IS_PC:   begin 
				     rs1_nprf_value = PC; 
				     rs1_is_nprf    = 1'b1;
			end
			OPA_IS_ZERO: begin
				     rs1_nprf_value = 1'b0;
				     rs1_is_nprf    = 1'b1;
			end
		endcase
	end

	 //
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		rs2_nprf_value = 32'hfeed_beef;
		rs2_is_imm     = 0;
		case (opb_select)
			OPB_IS_RS2:   rs2_nprf_value = 0;
			OPB_IS_I_IMM: begin
				      rs2_nprf_value = `RV32_signext_Iimm(inst);
				      rs2_is_imm     = 1;
			end
			OPB_IS_S_IMM: begin
				      rs2_nprf_value = `RV32_signext_Simm(inst);
				      rs2_is_imm     = 1;
			end
			OPB_IS_B_IMM: begin
				      rs2_nprf_value = `RV32_signext_Bimm(inst);
				      rs2_is_imm     = 1;
			end
			OPB_IS_U_IMM: begin
				      rs2_nprf_value = `RV32_signext_Uimm(inst);
				      rs2_is_imm     = 1;
			end
			OPB_IS_J_IMM: begin
				      rs2_nprf_value = `RV32_signext_Jimm(inst);
				      rs2_is_imm     = 1;
			end
		endcase 
	end

endmodule // rs_value_decoder

module id_stage(         
	input         clock,              // system clock
	input         reset,              // system reset

	input [(`N_WAY)*(`PRF_WIDTH)-1:0]   dest_prf_idx,   // from RAT: the disctributed PRF value for dest regs
	input [(`N_WAY)*(`PRF_WIDTH)-1:0]   opa_prf_idx,    // from RAT: the corresponding PRF idx for operand a and b
	input [(`N_WAY)*(`PRF_WIDTH)-1:0]   opb_prf_idx,    // from RAT: the corresponding PRF idx for operand a and b
	input [(`N_WAY)*(`PRF_WIDTH)-1:0]   dest_old_prn,   // old prn value of the destination register

	input  IF_ID_PACKET if_id_packet_in_2,
	input  IF_ID_PACKET if_id_packet_in_1,
	input  IF_ID_PACKET if_id_packet_in_0,

	input  [`PRF_SIZE-1:0] prf_valid_list,

	input [`N_WAY-1:0]			cdb_valid,
	input [(`PRF_WIDTH)*(`N_WAY)-1:0]	cdb_tag,
	
	output ID_EX_PACKET id_packet_out_2,
	output ID_EX_PACKET id_packet_out_1,
	output ID_EX_PACKET id_packet_out_0,

	output logic [`N_WAY*5-1:0]   dest_arf_idx_array,   // to RAT: the destination register arf index
	output logic [`N_WAY-1:0]     dest_arf_idx_valid,   // to RAT: the destination register valid bit
	output logic [`N_WAY*5-1:0]   opa_arf_idx_array,    // to RAT: the arf idx for operant a and b
	output logic [`N_WAY*5-1:0]   opb_arf_idx_array,    // to RAT: the arf idx for operant a and b
	output logic [`N_WIDTH-1:0]   inst_avail_num
);

    assign id_packet_out_2.inst = if_id_packet_in_2.inst;
    assign id_packet_out_2.NPC  = if_id_packet_in_2.NPC;
    assign id_packet_out_2.PC   = if_id_packet_in_2.PC;
    assign id_packet_out_1.inst = if_id_packet_in_1.inst;
    assign id_packet_out_1.NPC  = if_id_packet_in_1.NPC;
    assign id_packet_out_1.PC   = if_id_packet_in_1.PC;
    assign id_packet_out_0.inst = if_id_packet_in_0.inst;
    assign id_packet_out_0.NPC  = if_id_packet_in_0.NPC;
    assign id_packet_out_0.PC   = if_id_packet_in_0.PC;

    assign id_packet_out_2.rs1_prf_value  = opa_prf_idx[2*`PRF_WIDTH +: `PRF_WIDTH];
    assign id_packet_out_2.rs2_prf_value  = opb_prf_idx[2*`PRF_WIDTH +: `PRF_WIDTH];
    assign id_packet_out_1.rs1_prf_value  = opa_prf_idx[1*`PRF_WIDTH +: `PRF_WIDTH];
    assign id_packet_out_1.rs2_prf_value  = opb_prf_idx[1*`PRF_WIDTH +: `PRF_WIDTH];
    assign id_packet_out_0.rs1_prf_value  = opa_prf_idx[0*`PRF_WIDTH +: `PRF_WIDTH];
    assign id_packet_out_0.rs2_prf_value  = opb_prf_idx[0*`PRF_WIDTH +: `PRF_WIDTH];

    assign id_packet_out_2.rs1_prf_valid  = prf_valid_list[opa_prf_idx[2*`PRF_WIDTH +: `PRF_WIDTH]] | ((cdb_valid[2] & cdb_tag[2*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_2.rs1_prf_value)|(cdb_valid[1] & cdb_tag[1*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_2.rs1_prf_value)|(cdb_valid[0] & cdb_tag[0*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_2.rs1_prf_value));
    assign id_packet_out_2.rs2_prf_valid  = prf_valid_list[opb_prf_idx[2*`PRF_WIDTH +: `PRF_WIDTH]] | ((cdb_valid[2] & cdb_tag[2*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_2.rs2_prf_value)|(cdb_valid[1] & cdb_tag[1*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_2.rs2_prf_value)|(cdb_valid[0] & cdb_tag[0*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_2.rs2_prf_value));
    assign id_packet_out_1.rs1_prf_valid  = prf_valid_list[opa_prf_idx[1*`PRF_WIDTH +: `PRF_WIDTH]] | ((cdb_valid[2] & cdb_tag[2*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_1.rs1_prf_value)|(cdb_valid[1] & cdb_tag[1*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_1.rs1_prf_value)|(cdb_valid[0] & cdb_tag[0*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_1.rs1_prf_value));
    assign id_packet_out_1.rs2_prf_valid  = prf_valid_list[opb_prf_idx[1*`PRF_WIDTH +: `PRF_WIDTH]] | ((cdb_valid[2] & cdb_tag[2*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_1.rs2_prf_value)|(cdb_valid[1] & cdb_tag[1*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_1.rs2_prf_value)|(cdb_valid[0] & cdb_tag[0*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_1.rs2_prf_value));
    assign id_packet_out_0.rs1_prf_valid  = prf_valid_list[opa_prf_idx[0*`PRF_WIDTH +: `PRF_WIDTH]] | ((cdb_valid[2] & cdb_tag[2*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_0.rs1_prf_value)|(cdb_valid[1] & cdb_tag[1*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_0.rs1_prf_value)|(cdb_valid[0] & cdb_tag[0*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_0.rs1_prf_value));
    assign id_packet_out_0.rs2_prf_valid  = prf_valid_list[opb_prf_idx[0*`PRF_WIDTH +: `PRF_WIDTH]] | ((cdb_valid[2] & cdb_tag[2*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_0.rs2_prf_value)|(cdb_valid[1] & cdb_tag[1*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_0.rs2_prf_value)|(cdb_valid[0] & cdb_tag[0*`PRF_WIDTH +: `PRF_WIDTH]==id_packet_out_0.rs2_prf_value));

    assign id_packet_out_2.dest_prf_reg   = dest_arf_idx_valid[2] ? dest_prf_idx[2*`PRF_WIDTH +: `PRF_WIDTH] : {`PRF_WIDTH{1'b0}};
    assign id_packet_out_2.dest_old_prn   = dest_old_prn[2*`PRF_WIDTH +: `PRF_WIDTH];
    assign id_packet_out_1.dest_prf_reg   = dest_arf_idx_valid[1] ? dest_prf_idx[1*`PRF_WIDTH +: `PRF_WIDTH] : {`PRF_WIDTH{1'b0}};
    assign id_packet_out_1.dest_old_prn   = dest_old_prn[1*`PRF_WIDTH +: `PRF_WIDTH];
    assign id_packet_out_0.dest_prf_reg   = dest_arf_idx_valid[0] ? dest_prf_idx[0*`PRF_WIDTH +: `PRF_WIDTH] : {`PRF_WIDTH{1'b0}};
    assign id_packet_out_0.dest_old_prn   = dest_old_prn[0*`PRF_WIDTH +: `PRF_WIDTH];

    assign id_packet_out_2.branch_predict = if_id_packet_in_2.branch_predicted_taken;
    assign id_packet_out_2.predict_PC     = if_id_packet_in_2.branch_predicted_PC;
    assign id_packet_out_1.branch_predict = if_id_packet_in_1.branch_predicted_taken;
    assign id_packet_out_1.predict_PC     = if_id_packet_in_1.branch_predicted_PC;
    assign id_packet_out_0.branch_predict = if_id_packet_in_0.branch_predicted_taken;
    assign id_packet_out_0.predict_PC     = if_id_packet_in_0.branch_predicted_PC;

	DEST_REG_SEL dest_reg_select_2; 
	DEST_REG_SEL dest_reg_select_1; 
	DEST_REG_SEL dest_reg_select_0; 

    assign dest_arf_idx_array	= {id_packet_out_2.dest_reg_idx, id_packet_out_1.dest_reg_idx, id_packet_out_0.dest_reg_idx};
    assign dest_arf_idx_valid[2]= id_packet_out_2.valid & (dest_reg_select_2 == DEST_RD) & id_packet_out_2.dest_reg_idx != `ZERO_REG;
    assign dest_arf_idx_valid[1]= id_packet_out_1.valid & (dest_reg_select_1 == DEST_RD) & id_packet_out_1.dest_reg_idx != `ZERO_REG;
    assign dest_arf_idx_valid[0]= id_packet_out_0.valid & (dest_reg_select_0 == DEST_RD) & id_packet_out_0.dest_reg_idx != `ZERO_REG;

    assign opa_arf_idx_array={if_id_packet_in_2.inst.r.rs1, if_id_packet_in_1.inst.r.rs1,  if_id_packet_in_0.inst.r.rs1};
    assign opb_arf_idx_array={if_id_packet_in_2.inst.r.rs2, if_id_packet_in_1.inst.r.rs2, if_id_packet_in_0.inst.r.rs2};

	// Instantiate the register file used by this pipeline
	rs_value_decoder rs_value_decoder_2(
		//inputs
		.opa_select(id_packet_out_2.opa_select),
		.opb_select(id_packet_out_2.opb_select),
		.inst(id_packet_out_2.inst),
		.NPC(id_packet_out_2.NPC),
		.PC(id_packet_out_2.PC),
		//outputs
		.rs1_nprf_value(id_packet_out_2.rs1_nprf_value),
		.rs1_is_nprf(id_packet_out_2.rs1_is_nprf), 
		.rs2_nprf_value(id_packet_out_2.rs2_nprf_value),
		.rs2_is_imm(id_packet_out_2.rs2_is_imm)
	);
	rs_value_decoder rs_value_decoder_1(
		//inputs
		.opa_select(id_packet_out_1.opa_select),
		.opb_select(id_packet_out_1.opb_select),
		.inst(id_packet_out_1.inst),
		.NPC(id_packet_out_1.NPC),
		.PC(id_packet_out_1.PC),
		//outputs
		.rs1_nprf_value(id_packet_out_1.rs1_nprf_value),
		.rs1_is_nprf(id_packet_out_1.rs1_is_nprf), 
		.rs2_nprf_value(id_packet_out_1.rs2_nprf_value),
		.rs2_is_imm(id_packet_out_1.rs2_is_imm)
	);
	rs_value_decoder rs_value_decoder_0(
		//inputs
		.opa_select(id_packet_out_0.opa_select),
		.opb_select(id_packet_out_0.opb_select),
		.inst(id_packet_out_0.inst),
		.NPC(id_packet_out_0.NPC),
		.PC(id_packet_out_0.PC),
		//outputs
		.rs1_nprf_value(id_packet_out_0.rs1_nprf_value),
		.rs1_is_nprf(id_packet_out_0.rs1_is_nprf), 
		.rs2_nprf_value(id_packet_out_0.rs2_nprf_value),
		.rs2_is_imm(id_packet_out_0.rs2_is_imm)
	);
	// instantiate the instruction decoder
	decoder decoder_2 (
		.if_packet(if_id_packet_in_2),	 
		// Outputs
		.FU_type(id_packet_out_2.FU_type),
		.rs1_use_prf(id_packet_out_2.rs1_use_prf), 
		.rs2_use_prf(id_packet_out_2.rs2_use_prf),
		.opa_select(id_packet_out_2.opa_select),
		.opb_select(id_packet_out_2.opb_select),
		.alu_func(id_packet_out_2.alu_func),
		.dest_reg(dest_reg_select_2),
		.rd_mem(id_packet_out_2.rd_mem),
		.wr_mem(id_packet_out_2.wr_mem),
		.cond_branch(id_packet_out_2.cond_branch),
		.uncond_branch(id_packet_out_2.uncond_branch),
		.csr_op(id_packet_out_2.csr_op),
		.halt(id_packet_out_2.halt),
		.illegal(id_packet_out_2.illegal),
		.valid_inst(id_packet_out_2.valid)
	);
	decoder decoder_1 (
		.if_packet(if_id_packet_in_1),	 
		// Outputs
		.FU_type(id_packet_out_1.FU_type),
		.rs1_use_prf(id_packet_out_1.rs1_use_prf), 
		.rs2_use_prf(id_packet_out_1.rs2_use_prf),
		.opa_select(id_packet_out_1.opa_select),
		.opb_select(id_packet_out_1.opb_select),
		.alu_func(id_packet_out_1.alu_func),
		.dest_reg(dest_reg_select_1),
		.rd_mem(id_packet_out_1.rd_mem),
		.wr_mem(id_packet_out_1.wr_mem),
		.cond_branch(id_packet_out_1.cond_branch),
		.uncond_branch(id_packet_out_1.uncond_branch),
		.csr_op(id_packet_out_1.csr_op),
		.halt(id_packet_out_1.halt),
		.illegal(id_packet_out_1.illegal),
		.valid_inst(id_packet_out_1.valid)
	);
	decoder decoder_0 (
		.if_packet(if_id_packet_in_0),	 
		// Outputs
		.FU_type(id_packet_out_0.FU_type),
		.rs1_use_prf(id_packet_out_0.rs1_use_prf), 
		.rs2_use_prf(id_packet_out_0.rs2_use_prf),
		.opa_select(id_packet_out_0.opa_select),
		.opb_select(id_packet_out_0.opb_select),
		.alu_func(id_packet_out_0.alu_func),
		.dest_reg(dest_reg_select_0),
		.rd_mem(id_packet_out_0.rd_mem),
		.wr_mem(id_packet_out_0.wr_mem),
		.cond_branch(id_packet_out_0.cond_branch),
		.uncond_branch(id_packet_out_0.uncond_branch),
		.csr_op(id_packet_out_0.csr_op),
		.halt(id_packet_out_0.halt),
		.illegal(id_packet_out_0.illegal),
		.valid_inst(id_packet_out_0.valid)
	);

	// mux to generate dest_reg_idx based on
	// the dest_reg_select output from decoder
	always_comb begin
		case (dest_reg_select_2)
			DEST_RD:    id_packet_out_2.dest_reg_idx = if_id_packet_in_2.inst.r.rd;
			DEST_NONE:  id_packet_out_2.dest_reg_idx = `ZERO_REG;
			default:    id_packet_out_2.dest_reg_idx = `ZERO_REG; 
		endcase
		case (dest_reg_select_1)
			DEST_RD:    id_packet_out_1.dest_reg_idx = if_id_packet_in_1.inst.r.rd;
			DEST_NONE:  id_packet_out_1.dest_reg_idx = `ZERO_REG;
			default:    id_packet_out_1.dest_reg_idx = `ZERO_REG; 
		endcase
		case (dest_reg_select_0)
			DEST_RD:    id_packet_out_0.dest_reg_idx = if_id_packet_in_0.inst.r.rd;
			DEST_NONE:  id_packet_out_0.dest_reg_idx = `ZERO_REG;
			default:    id_packet_out_0.dest_reg_idx = `ZERO_REG; 
		endcase
	end
	always_comb begin
		inst_avail_num = 0;
		inst_avail_num = id_packet_out_2.valid + id_packet_out_1.valid + id_packet_out_0.valid;
	end
   
endmodule // module id_stage

