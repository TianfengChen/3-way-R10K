`timescale 1ns/100ps

module pipeline_top(
	//inputs
////////clock&reset
	input      		clock,                    // System clock
	input 			reset,                    // System reset	
////////input from memory
 	input  [3:0]  		mem2proc_response,        // Tag from memory about current request
	input  [63:0] 		mem2proc_data,            // Data coming back from memory
	input  [3:0]  		mem2proc_tag,              // Tag from memory about current reply  
	//outputs
////////error status and commit status 
	output EXCEPTION_CODE				error_status,	
	output logic [3:0]					completed_insts,
	output logic [(`N_WAY)*5-1:0] 		commit_wr_idx,
	output logic [(`N_WAY)*(`XLEN)-1:0] commit_wr_data,
	output logic [`N_WAY-1:0]       	commit_wr_en,
	output logic [(`N_WAY)*(`XLEN)-1:0] commit_NPC,
////////outputs to memory
	output BUS_COMMAND 			proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] 	proc2mem_addr,      // Address sent to memory
	output logic [63:0] 		proc2mem_data,      // Data sent to memory
	output MEM_SIZE				proc2mem_size,          // data size sent to memory	
//////// Outputs from IF-Stage 
	output logic [`XLEN-1:0] 	if_PC_out_2,
	output logic [31:0] 		if_IR_out_2,
	output logic        		if_valid_inst_out_2,
	output logic [`XLEN-1:0] 	if_PC_out_1,
	output logic [31:0] 		if_IR_out_1,
	output logic        		if_valid_inst_out_1,
	output logic [`XLEN-1:0] 	if_PC_out_0,
	output logic [31:0] 		if_IR_out_0,
	output logic        		if_valid_inst_out_0,
	output logic				branch_mispredicted,
//////// Outputs from IF/ID Pipeline Register
	output logic [`XLEN-1:0] 	if_id_PC_2,
	output logic [31:0] 		if_id_IR_2,
	output logic        		if_id_valid_inst_2,
	output logic [`XLEN-1:0] 	if_id_PC_1,
	output logic [31:0] 		if_id_IR_1,
	output logic 		       	if_id_valid_inst_1,
	output logic [`XLEN-1:0] 	if_id_PC_0,
	output logic [31:0] 		if_id_IR_0,
	output logic 		       	if_id_valid_inst_0,
//////// Outputs from ID/EX Pipeline Register
	output logic [`XLEN-1:0] 	id_rs_PC_2,
	output logic [31:0] 		id_rs_IR_2,
	output logic 		       	id_rs_valid_inst_2,
	output logic [`XLEN-1:0] 	id_rs_PC_1,
	output logic [31:0] 		id_rs_IR_1,
	output logic 		       	id_rs_valid_inst_1,
	output logic [`XLEN-1:0] 	id_rs_PC_0,
	output logic [31:0] 		id_rs_IR_0,
	output logic 		       	id_rs_valid_inst_0,
//////// Outputs from RS/FU Pipeline Register
	output [`XLEN-1:0] 			rs_fu_PC_2,
	output [31:0] 				rs_fu_IR_2,
	output         				rs_fu_valid_inst_2,	
	output [`XLEN-1:0] 			rs_fu_PC_1,
	output [31:0] 				rs_fu_IR_1,
	output         				rs_fu_valid_inst_1,	
	output [`XLEN-1:0] 			rs_fu_PC_0,
	output [31:0] 				rs_fu_IR_0,
	output         				rs_fu_valid_inst_0,		
//////// Outputs from FU/CDB* Pipeline Register
	output [`XLEN-1:0] 			fu_cdb_PC_2,
	output [31:0] 				fu_cdb_IR_2,
	output         				fu_cdb_valid_inst_2,	
	output [`XLEN-1:0] 			fu_cdb_PC_1,
	output [31:0] 				fu_cdb_IR_1,
	output         				fu_cdb_valid_inst_1,	
	output [`XLEN-1:0] 			fu_cdb_PC_0,
	output [31:0] 				fu_cdb_IR_0,
	output         				fu_cdb_valid_inst_0,	
//////// Outputs of rob head
	output [`XLEN-1:0] 			rob_head_PC_2,
	output [31:0] 				rob_head_IR_2,
	output         				rob_head_commit_2,
	output [`XLEN-1:0] 			rob_head_PC_1,
	output [31:0] 				rob_head_IR_1,
	output         				rob_head_commit_1,	
	output [`XLEN-1:0] 			rob_head_PC_0,
	output [31:0] 				rob_head_IR_0,
	output         				rob_head_commit_0,		
////////output from rat
    output logic [(`ARF_SIZE)*(`PRF_WIDTH)-1:0] rat_rename_table_out,
////////FU branch outputs
	output logic [31:0]	 		branch_target_addr_out,
	output logic 				branch_taken_out,
////////CDB outpus for debug
	output logic [`N_WAY-1:0] 					cdb_valid,
	output logic [32*(`N_WAY)-1:0]				cdb_value,
	output logic [(`PRF_WIDTH)*(`N_WAY)-1:0] 	cdb_tag,
	output logic [(`N_WAY)*(`ROB_WIDTH)-1:0]	cdb_rob,
	output logic [`N_WAY-1:0]					cdb_cond_branch,
	output logic [`N_WAY-1:0]					cdb_uncond_branch,
	output logic [`N_WAY-1:0]					cdb_rd_mem,
	output logic [`N_WAY-1:0]					cdb_wr_mem
);


////////id_rs_packet from ID to back pipeline reg
	ID_EX_PACKET 			id_rs_packet_2; 
	ID_EX_PACKET 			id_rs_packet_1; 
	ID_EX_PACKET 			id_rs_packet_0;
////////output of RPB(to commit and if branch predictor)
	ROB_IF_BRANCH_PACKET		branch_packet_2;
	ROB_IF_BRANCH_PACKET		branch_packet_1;
	ROB_IF_BRANCH_PACKET		branch_packet_0;
	ROB_PACKET			ROB_packet_out_2;	
	ROB_PACKET			ROB_packet_out_1;
	ROB_PACKET			ROB_packet_out_0;
	logic				nuke;
////////output of RRAT
	logic	[(`ARF_SIZE)*(`PRF_WIDTH)-1:0]		rrat_rename_table_out;     
////////structural hazard sign
	logic [`RS_WIDTH:0]	  			rs_avail_cnt;
	logic [`ROB_WIDTH:0]			rob_avail_cnt;
	
	logic [`PRF_SIZE-1:0]			valid_list;
	logic [(`PRF_SIZE)*(`XLEN)-1:0]	prf_data_out;
	
	logic	[1:0]					load_store;	//[1,0] for load, [0,1] for store, [0,0] for BUS_NONE
   	logic 	[1:0] 					proc2Dmem_command;
    	logic 	[31:0]					proc2Dmem_addr;
	logic 	[1:0]					proc2Dmem_size;
	logic 	[63:0]					proc2Dmem_data;

 	logic	[4:0] 					Dmem2proc_idx;
 	logic 	[7:0] 					Dmem2proc_tag;
 	logic 	[63:0] 					Dmem2proc_data;
 	logic 							Dmem2proc_valid;

	assign commit_wr_idx 	= {ROB_packet_out_2.id_packet.dest_reg_idx,ROB_packet_out_1.id_packet.dest_reg_idx,ROB_packet_out_0.id_packet.dest_reg_idx};

	assign commit_wr_en 	= {	ROB_packet_out_2.valid & ROB_packet_out_2.commit & ~ROB_packet_out_2.id_packet.cond_branch & ROB_packet_out_2.id_packet.dest_reg_idx!=`ZERO_REG &
								(ROB_packet_out_2.id_packet.halt | ROB_packet_out_2.id_packet.illegal)==0,
								ROB_packet_out_1.valid & ROB_packet_out_1.commit & ~ROB_packet_out_1.id_packet.cond_branch & ROB_packet_out_1.id_packet.dest_reg_idx!=`ZERO_REG &
								(ROB_packet_out_1.id_packet.halt | ROB_packet_out_1.id_packet.illegal)==0,
								ROB_packet_out_0.valid & ROB_packet_out_0.commit & ~ROB_packet_out_0.id_packet.cond_branch & ROB_packet_out_0.id_packet.dest_reg_idx!=`ZERO_REG &
								(ROB_packet_out_0.id_packet.halt | ROB_packet_out_0.id_packet.illegal)==0};

	assign commit_NPC		= {ROB_packet_out_2.id_packet.NPC,ROB_packet_out_1.id_packet.NPC,ROB_packet_out_0.id_packet.NPC};

	assign commit_wr_data	= {	prf_data_out[(ROB_packet_out_2.id_packet.dest_prf_reg)*(`XLEN)+:`XLEN],
								prf_data_out[(ROB_packet_out_1.id_packet.dest_prf_reg)*(`XLEN)+:`XLEN],
								prf_data_out[(ROB_packet_out_0.id_packet.dest_prf_reg)*(`XLEN)+:`XLEN]};

	assign rob_head_PC_2 		= rob_head_commit_2 ? ROB_packet_out_2.id_packet.PC : 0;
	assign rob_head_IR_2	 	= rob_head_commit_2 ? ROB_packet_out_2.id_packet.inst : 0;
	assign rob_head_commit_2 	= ROB_packet_out_2.commit && ROB_packet_out_2.valid;
	assign rob_head_PC_1 		= rob_head_commit_1 ? ROB_packet_out_1.id_packet.PC : 0;
	assign rob_head_IR_1 		= rob_head_commit_1 ? ROB_packet_out_1.id_packet.inst :0;
	assign rob_head_commit_1 	= ROB_packet_out_1.commit && ROB_packet_out_1.valid;
	assign rob_head_PC_0 		= rob_head_commit_0 ? ROB_packet_out_0.id_packet.PC : 0;
	assign rob_head_IR_0 		= rob_head_commit_0 ? ROB_packet_out_0.id_packet.inst : 0;
	assign rob_head_commit_0 	= ROB_packet_out_0.commit && ROB_packet_out_0.valid;


	pipeline_front pipeline_front_0(
		.clock(clock),
		.reset(reset),
		.mem2proc_response(mem2proc_response),
		.mem2proc_data(mem2proc_data),
		.mem2proc_tag(mem2proc_tag),
		////////IF_stage_inputs (useless after pipeline all connected)
		.branch_packet_2(branch_packet_2),
		.branch_packet_1(branch_packet_1),
		.branch_packet_0(branch_packet_0),
    	.rs_avail_num(rs_avail_cnt),
    	.rob_avail_num(rob_avail_cnt),
		////////ID_stage_inputs (useless after pipeline all connected)
		.prf_valid_list(valid_list),
		////////RAT_inputs (useless after pipeline all connected)
		.rrat_rename_table_in(rrat_rename_table_out),
		////////Freelist inputs
		.ROB_packet_in_2(ROB_packet_out_2),	//from ROB
		.ROB_packet_in_1(ROB_packet_out_1),
		.ROB_packet_in_0(ROB_packet_out_0),
		////////input from ROB
		.nuke(nuke),	//from ROB
		////////input from CDB
		.cdb_valid(cdb_valid),
		.cdb_tag(cdb_tag),
		//inputs from dcache ctrl
    	.load_store			(load_store			),
    	.proc2Dmem_command	(proc2Dmem_command	),
    	.proc2Dmem_addr		(proc2Dmem_addr		),
    	.proc2Dmem_size		(proc2Dmem_size		),
    	.proc2Dmem_data		(proc2Dmem_data		),
		////////
		.proc2mem_command(proc2mem_command),    // command sent to memory
		.proc2mem_addr(proc2mem_addr),      // Address sent to memory
		.proc2mem_data(proc2mem_data),      // Data sent to memory
		.proc2mem_size(proc2mem_size),          // data size sent to memory
	////////Outputs from RAT Pipeline Register	
		.Dmem2proc_idx			(Dmem2proc_idx			),
		.Dmem2proc_tag			(Dmem2proc_tag			),
		.Dmem2proc_data			(Dmem2proc_data			),
		.Dmem2proc_valid		(Dmem2proc_valid		),	
		// Outputs from IF-Stage 
		.if_PC_out_2(if_PC_out_2),
		.if_IR_out_2(if_IR_out_2),
		.if_valid_inst_out_2(if_valid_inst_out_2),
		.if_PC_out_1(if_PC_out_1),
		.if_IR_out_1(if_IR_out_1),
		.if_valid_inst_out_1(if_valid_inst_out_1),
		.if_PC_out_0(if_PC_out_0),
		.if_IR_out_0(if_IR_out_0),
		.if_valid_inst_out_0(if_valid_inst_out_0),
		.branch_mispredicted(branch_mispredicted),
		// Outputs from IF/ID Pipeline Register
		.if_id_PC_2(if_id_PC_2),
		.if_id_IR_2(if_id_IR_2),
		.if_id_valid_inst_2(if_id_valid_inst_2),
		.if_id_PC_1(if_id_PC_1),
		.if_id_IR_1(if_id_IR_1),
		.if_id_valid_inst_1(if_id_valid_inst_1),
		.if_id_PC_0(if_id_PC_0),
		.if_id_IR_0(if_id_IR_0),
		.if_id_valid_inst_0(if_id_valid_inst_0),
		// Outputs from ID/EX Pipeline Register
		.id_rs_PC_2(id_rs_PC_2),
		.id_rs_IR_2(id_rs_IR_2),
		.id_rs_valid_inst_2(id_rs_valid_inst_2),
		.id_rs_PC_1(id_rs_PC_1),
		.id_rs_IR_1(id_rs_IR_1),
		.id_rs_valid_inst_1(id_rs_valid_inst_1),
		.id_rs_PC_0(id_rs_PC_0),
		.id_rs_IR_0(id_rs_IR_0),
		.id_rs_valid_inst_0(id_rs_valid_inst_0),
		.id_rs_packet_2(id_rs_packet_2), 
		.id_rs_packet_1(id_rs_packet_1), 
		.id_rs_packet_0(id_rs_packet_0),
		// Outputs from RAT Pipeline Register	
    	.rat_rename_table_out(rat_rename_table_out)
	
	);



	pipeline_back pipeline_back_0(
		.clk(clock),
		.rst(reset),
		.id_packet_in_2(id_rs_packet_2),
		.id_packet_in_1(id_rs_packet_1),
		.id_packet_in_0(id_rs_packet_0),
		.Dmem2proc_idx	(Dmem2proc_idx	),		
		.Dmem2proc_tag	(Dmem2proc_tag	),		
		.Dmem2proc_data	(Dmem2proc_data	),		
		.Dmem2proc_valid(Dmem2proc_valid),	
		
		.cdb_valid(cdb_valid),
		.cdb_value(cdb_value),
		.cdb_tag(cdb_tag),
		.cdb_rob(cdb_rob),
		.cdb_cond_branch(cdb_cond_branch),
		.cdb_uncond_branch(cdb_uncond_branch),
		.cdb_rd_mem(cdb_rd_mem),
		.cdb_wr_mem(cdb_wr_mem),	
		.branch_target_addr_out(branch_target_addr_out),	
		.branch_taken_out(branch_taken_out),
		.rs_avail_cnt(rs_avail_cnt),
		.rob_avail_cnt(rob_avail_cnt),
		.error_status(error_status),	
		.completed_insts(completed_insts),
		.ROB_packet_out_2(ROB_packet_out_2),	
		.ROB_packet_out_1(ROB_packet_out_1),		
		.ROB_packet_out_0(ROB_packet_out_0),		
		.ROB_branch_out_2(branch_packet_2),	
		.ROB_branch_out_1(branch_packet_1),		
		.ROB_branch_out_0(branch_packet_0),
		.nuke(nuke),
		.rrat_rename_table_out(rrat_rename_table_out),
		.valid_list	(valid_list),
		.prf_data_out(prf_data_out),
		.load_store			(load_store			),	
		.proc2Dmem_command	(proc2Dmem_command	),		
		.proc2Dmem_addr		(proc2Dmem_addr		),		
		.proc2Dmem_size		(proc2Dmem_size		),		
		.proc2Dmem_data		(proc2Dmem_data		),	
		//debug ports
		.rs_fu_PC_2			(rs_fu_PC_2		   ),
		.rs_fu_IR_2			(rs_fu_IR_2		   ),
		.rs_fu_valid_inst_2	(rs_fu_valid_inst_2),	
		.rs_fu_PC_1			(rs_fu_PC_1		   ),
		.rs_fu_IR_1			(rs_fu_IR_1		   ),
		.rs_fu_valid_inst_1	(rs_fu_valid_inst_1),	
		.rs_fu_PC_0			(rs_fu_PC_0		   ),
		.rs_fu_IR_0			(rs_fu_IR_0		   ),
		.rs_fu_valid_inst_0	(rs_fu_valid_inst_0),
		.fu_cdb_PC_2			(fu_cdb_PC_2		   ),
		.fu_cdb_IR_2			(fu_cdb_IR_2		   ),
		.fu_cdb_valid_inst_2	(fu_cdb_valid_inst_2),	
		.fu_cdb_PC_1			(fu_cdb_PC_1		   ),
		.fu_cdb_IR_1			(fu_cdb_IR_1		   ),
		.fu_cdb_valid_inst_1	(fu_cdb_valid_inst_1),	
		.fu_cdb_PC_0			(fu_cdb_PC_0		   ),
		.fu_cdb_IR_0			(fu_cdb_IR_0		   ),
		.fu_cdb_valid_inst_0	(fu_cdb_valid_inst_0)

	);


	
endmodule


