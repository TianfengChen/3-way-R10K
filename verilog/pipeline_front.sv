/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline_front.v                                    //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps

module pipeline_front (

	input         				clock,
	input         				reset,
////////input from main memory
	input  	[3:0]   			mem2proc_response,
	input  	[63:0]  			mem2proc_data,
	input  	[3:0]   			mem2proc_tag,
////////IF_stage_inputs (useless after pipeline all connected)
	input  	ROB_IF_BRANCH_PACKET		branch_packet_2,
	input  	ROB_IF_BRANCH_PACKET		branch_packet_1,
	input  	ROB_IF_BRANCH_PACKET		branch_packet_0,
    	input  	[`RS_WIDTH:0]  			rs_avail_num,
    	input  	[`ROB_WIDTH:0] 			rob_avail_num,
////////ID_stage_inputs (useless after pipeline all connected)
	input  	[`PRF_SIZE-1:0] 		prf_valid_list,
////////RAT_inputs (useless after pipeline all connected)
	input  	[(`ARF_SIZE)*(`PRF_WIDTH)-1:0] 	rrat_rename_table_in,
////////Freelist inputs
	input	ROB_PACKET			ROB_packet_in_2,
	input	ROB_PACKET			ROB_packet_in_1,
	input	ROB_PACKET			ROB_packet_in_0,
////////input from ROB
	input					nuke,	//from ROB
////////input from CDB
	input 	[`N_WAY-1:0]			cdb_valid,
	input 	[(`PRF_WIDTH)*(`N_WAY)-1:0]	cdb_tag,
////////input from Dcache controller
    	input  	[1:0] 		 		load_store,
    	input  	[1:0]				proc2Dmem_command,
    	input  	[31:0] 				proc2Dmem_addr,
    	input  	[1:0]				proc2Dmem_size,
    	input  	[63:0] 				proc2Dmem_data,
////////Outputs to main memory
	output 	logic 	[1:0]  			proc2mem_command,
	output 	logic 	[`XLEN-1:0] 		proc2mem_addr,
	output 	logic 	[63:0] 			proc2mem_data,
	output 	logic 	[1:0] 			proc2mem_size,
////////Outputs from IF-Stage 
	output 	logic 	[`XLEN-1:0] 		if_PC_out_2,
	output 	logic 	[31:0] 			if_IR_out_2,
	output 	logic        			if_valid_inst_out_2,
	output 	logic 	[`XLEN-1:0] 		if_PC_out_1,
	output 	logic 	[31:0] 			if_IR_out_1,
	output 	logic        			if_valid_inst_out_1,
	output 	logic 	[`XLEN-1:0] 		if_PC_out_0,
	output 	logic 	[31:0] 			if_IR_out_0,
	output 	logic        			if_valid_inst_out_0,
	output 	logic				branch_mispredicted,
////////Outputs from IF/ID Pipeline Register
	output 	logic	[`XLEN-1:0] 		if_id_PC_2,
	output 	logic 	[31:0] 			if_id_IR_2,
	output 	logic        			if_id_valid_inst_2,
	output 	logic 	[`XLEN-1:0] 		if_id_PC_1,
	output 	logic 	[31:0] 			if_id_IR_1,
	output 	logic 		       		if_id_valid_inst_1,
	output 	logic 	[`XLEN-1:0] 		if_id_PC_0,
	output 	logic 	[31:0] 			if_id_IR_0,
	output 	logic 		       		if_id_valid_inst_0,
////////Outputs from ID-Stage (need to beleted after rat connection)
////////Outputs from ID/EX Pipeline Register
	output 	logic 	[`XLEN-1:0] 		id_rs_PC_2,
	output 	logic 	[31:0] 			id_rs_IR_2,
	output	logic 		       		id_rs_valid_inst_2,
	output 	logic 	[`XLEN-1:0] 		id_rs_PC_1,
	output 	logic 	[31:0] 			id_rs_IR_1,
	output 	logic 		       		id_rs_valid_inst_1,
	output 	logic 	[`XLEN-1:0] 		id_rs_PC_0,
	output 	logic 	[31:0] 			id_rs_IR_0,
	output 	logic 		       		id_rs_valid_inst_0,
	output	ID_EX_PACKET 			id_rs_packet_2, 
	output	ID_EX_PACKET 			id_rs_packet_1, 
	output	ID_EX_PACKET 			id_rs_packet_0,
////////Outputs from RAT Pipeline Register	
    	output 	logic 	[(`ARF_SIZE)*(`PRF_WIDTH)-1:0] rat_rename_table_out,
////////outputs from icache controller
    	output 	logic	[4:0] 			Dmem2proc_idx,
    	output 	logic 	[7:0] 			Dmem2proc_tag,
   	output 	logic 	[63:0] 			Dmem2proc_data,
    	output 	logic 				Dmem2proc_valid
	
);

	// Pipeline register enables
	logic   if_id_enable, id_ex_enable, ex_mem_enable, mem_wb_enable;
	
	// Outputs from IF-Stage
	logic 		  rs_rob_haz_stall;
	IF_ID_PACKET      if_packet_out_2, if_packet_out_1, if_packet_out_0;

	// Outputs from IF/ID Pipeline Register
	IF_ID_PACKET if_id_packet_2, if_id_packet_1, if_id_packet_0;

	// Outputs from ID stage
	logic [`N_WIDTH-1:0]    inst_avail_num;
	logic [`N_WAY*5-1:0]    dest_arf_idx_array;
	logic [`N_WAY-1:0]     	dest_arf_idx_valid;
	logic [`N_WAY*5-1:0] 	opa_arf_idx_array;
	logic [`N_WAY*5-1:0] 	opb_arf_idx_array;

	ID_EX_PACKET id_packet_out_2, id_packet_out_1, id_packet_out_0;
	// Outputs from RAT Pipeline Register
	logic  [(`N_WAY)*(`PRF_WIDTH)-1:0]   	dest_prf_idx;
    	logic  [`N_WAY-1:0]   			dest_prn_valid_out;
	logic  [(`N_WAY)*(`PRF_WIDTH)-1:0]   	opa_prf_idx;
	logic  [(`N_WAY)*(`PRF_WIDTH)-1:0]   	opb_prf_idx;
	logic  [(`N_WAY) * (`PRF_WIDTH)-1:0]    rat_pre_dest_prn_out;       // feed to rs and RoB  

	//outputs from freelist
    	logic  [`PRF_SIZE-1:0]   		prf_free_list; 


//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////
	//these are debug signals that are now included in the packet,
	//breaking them out to support the legacy debug modes
	assign if_PC_out_2        = if_packet_out_2.PC;
	assign if_IR_out_2         = if_packet_out_2.inst;
	assign if_valid_inst_out_2 = if_packet_out_2.valid;
	assign if_PC_out_1        = if_packet_out_1.PC;
	assign if_IR_out_1         = if_packet_out_1.inst;
	assign if_valid_inst_out_1 = if_packet_out_1.valid;
	assign if_PC_out_0        = if_packet_out_0.PC;
	assign if_IR_out_0         = if_packet_out_0.inst;
	assign if_valid_inst_out_0 = if_packet_out_0.valid;
	
	if_stage if_stage_0(
		//inputs
		.clock(clock),
		.reset(reset),
	/////////branch packet to the predictor and next_PC                 
		.branch_packet_2(branch_packet_2),
		.branch_packet_1(branch_packet_1),
		.branch_packet_0(branch_packet_0),
	/////////Data coming back from instruction-memory			
  		.Imem2proc_response(mem2proc_response),
		.Imem2proc_data(mem2proc_data),
    		.Imem2proc_tag(mem2proc_tag),
	/////////RS&ROB stru hazard signal
    		.rs_avail_num(rs_avail_num),
    		.rob_avail_num(rob_avail_num),
		.inst_avail_num(inst_avail_num),
	/////////the nuke signal from ROB
		.nuke(nuke),
	/////////Data from Dcache controller
    		.load_store(load_store),
    		.proc2Dmem_command(proc2Dmem_command),
		.proc2Dmem_addr(proc2Dmem_addr),
		.proc2Dmem_size(proc2Dmem_size),
		.proc2Dmem_data(proc2Dmem_data),
		//outputs
	/////////the stru hazard signal
		.rs_rob_haz_stall(rs_rob_haz_stall),
	/////////Request sent to Instruction memory
		.proc2mem_addr(proc2mem_addr),
		.proc2mem_command(proc2mem_command),
		.proc2mem_data(proc2mem_data),
		.proc2mem_size(proc2mem_size),
	/////////Output to Dcache controller
		.last_index(Dmem2proc_idx),
		.last_tag(Dmem2proc_tag),
		.load_data(Dmem2proc_data),
		.data_write_enable_load(Dmem2proc_valid),
	/////////Output data packet from IF going to ID    
		.branch_mispredicted(branch_mispredicted),
		.if_packet_out_2(if_packet_out_2),
		.if_packet_out_1(if_packet_out_1), 
		.if_packet_out_0(if_packet_out_0)
	);
//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////
	assign if_id_PC_2         = if_id_packet_2.PC;
	assign if_id_IR_2         = if_id_packet_2.inst;
	assign if_id_valid_inst_2 = if_id_packet_2.valid;
	assign if_id_PC_1         = if_id_packet_1.PC;
	assign if_id_IR_1         = if_id_packet_1.inst;
	assign if_id_valid_inst_1 = if_id_packet_1.valid;
	assign if_id_PC_0         = if_id_packet_0.PC;
	assign if_id_IR_0         = if_id_packet_0.inst;
	assign if_id_valid_inst_0 = if_id_packet_0.valid;

	assign if_id_enable = ~rs_rob_haz_stall;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | nuke) begin 
			if_id_packet_2.inst  <= `SD `NOP;
			if_id_packet_2.valid <= `SD 0;
            		if_id_packet_2.NPC   <= `SD 0;
            		if_id_packet_2.PC    <= `SD 0;
			if_id_packet_2.branch_predicted_taken <= `SD 0;
			if_id_packet_2.branch_predicted_PC    <= `SD 0;
			if_id_packet_1.inst  <= `SD `NOP;
			if_id_packet_1.valid <= `SD 0;
            		if_id_packet_1.NPC   <= `SD 0;
            		if_id_packet_1.PC    <= `SD 0;
			if_id_packet_1.branch_predicted_taken <= `SD 0;
			if_id_packet_1.branch_predicted_PC    <= `SD 0;
			if_id_packet_0.inst  <= `SD `NOP;
			if_id_packet_0.valid <= `SD 0;
            		if_id_packet_0.NPC   <= `SD 0;
            		if_id_packet_0.PC    <= `SD 0;
			if_id_packet_0.branch_predicted_taken <= `SD 0;
			if_id_packet_0.branch_predicted_PC    <= `SD 0;
		end else if (if_id_enable) begin// if (reset)	
			if_id_packet_2 <= `SD if_packet_out_2; 
			if_id_packet_1 <= `SD if_packet_out_1; 
			if_id_packet_0 <= `SD if_packet_out_0; 
		end
	end // always	
//////////////////////////////////////////////////
//                                              //
//                  ID-Stage                    //
//                                              //
//////////////////////////////////////////////////
	id_stage id_stage_0(
		//inputs         
		.clock(clock),
		.reset(reset),
		.dest_prf_idx(dest_prf_idx),
		.opa_prf_idx(opa_prf_idx),
		.opb_prf_idx(opb_prf_idx),
		.dest_old_prn(rat_pre_dest_prn_out),
		.if_id_packet_in_2(if_id_packet_2),
		.if_id_packet_in_1(if_id_packet_1),
		.if_id_packet_in_0(if_id_packet_0),
		.prf_valid_list(prf_valid_list),
		.cdb_valid(cdb_valid),
		.cdb_tag(cdb_tag),
		//outputs
		.id_packet_out_2(id_packet_out_2),
		.id_packet_out_1(id_packet_out_1),
		.id_packet_out_0(id_packet_out_0),
		.dest_arf_idx_array(dest_arf_idx_array),
		.dest_arf_idx_valid(dest_arf_idx_valid),
		.opa_arf_idx_array(opa_arf_idx_array),
		.opb_arf_idx_array(opb_arf_idx_array),
		.inst_avail_num(inst_avail_num)
	);	
//////////////////////////////////////////////////
//                                              //
//            ID/EX Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign id_rs_PC_2         = id_rs_packet_2.PC;
	assign id_rs_IR_2         = id_rs_packet_2.inst;
	assign id_rs_valid_inst_2 = id_rs_packet_2.valid;
	assign id_rs_PC_1         = id_rs_packet_1.PC;
	assign id_rs_IR_1         = id_rs_packet_1.inst;
	assign id_rs_valid_inst_1 = id_rs_packet_1.valid;
	assign id_rs_PC_0         = id_rs_packet_0.PC;
	assign id_rs_IR_0         = id_rs_packet_0.inst;
	assign id_rs_valid_inst_0 = id_rs_packet_0.valid;

	assign id_ex_enable = ~rs_rob_haz_stall;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | nuke | ~id_ex_enable) begin
			id_rs_packet_2 <= `SD '{
				{`XLEN{1'b0}},		//NPC
				{`XLEN{1'b0}}, 		//PC
				{4'b0001},			//FU_type
				{`PRF_WIDTH{1'b0}},	//rs1_prf_value
				1'b0,			//rs1_use_prf
				1'b0,			//rs1_prf_valid
				{`XLEN{1'b0}}, 		//rs1_nprf_value
				1'b0,			//rs1_is_nprf
				{`PRF_WIDTH{1'b0}}, 	//rs2_prf_value
				1'b0,			//rs2_use_prf
				1'b0,			//rs2_prf_valid
				{`XLEN{1'b0}}, 			//rs2_nprf_value
				1'b0,			//rs2_is_imm
				OPA_IS_RS1, 		//opa_select
				OPB_IS_RS2, 		//opb_select
				`NOP,			//inst
				`ZERO_REG,		//dest_reg_idx
				{`PRF_WIDTH{1'b0}}, 	//dest_prf_reg
				{`PRF_WIDTH{1'b0}},	//dest_old_prn
				ALU_ADD, 		//alu_func
				1'b0, 			//rd_mem
				1'b0, 			//wr_mem
				1'b0, 			//cond
				1'b0, 			//uncond
				1'b0,			//branch_predict
				{`XLEN{1'b0}},		//predict_PC
				1'b0, 			//halt
				1'b0, 			//illegal
				1'b0, 			//csr_op
				1'b0 			//valid
			}; 
			id_rs_packet_1 <= `SD '{
				{`XLEN{1'b0}},		//NPC
				{`XLEN{1'b0}}, 		//PC
				{4'b0001},			//FU_type
				{`PRF_WIDTH{1'b0}},	//rs1_prf_value
				1'b0,			//rs1_use_prf
				1'b0,			//rs1_prf_valid
				{`XLEN{1'b0}}, 		//rs1_nprf_value
				1'b0,			//rs1_is_nprf
				{`PRF_WIDTH{1'b0}}, 	//rs2_prf_value
				1'b0,			//rs2_use_prf
				1'b0,			//rs2_prf_valid
				{`XLEN{1'b0}}, 			//rs2_nprf_value
				1'b0,			//rs2_is_imm
				OPA_IS_RS1, 		//opa_select
				OPB_IS_RS2, 		//opb_select
				`NOP,			//inst
				`ZERO_REG,		//dest_reg_idx
				{`PRF_WIDTH{1'b0}}, 	//dest_prf_reg
				{`PRF_WIDTH{1'b0}},	//dest_old_prn
				ALU_ADD, 		//alu_func
				1'b0, 			//rd_mem
				1'b0, 			//wr_mem
				1'b0, 			//cond
				1'b0, 			//uncond
				1'b0,			//branch_predict
				{`XLEN{1'b0}},		//predict_PC
				1'b0, 			//halt
				1'b0, 			//illegal
				1'b0, 			//csr_op
				1'b0 			//valid
			}; 
			id_rs_packet_0 <= `SD '{
				{`XLEN{1'b0}},		//NPC
				{`XLEN{1'b0}}, 		//PC
				{4'b0001},			//FU_type
				{`PRF_WIDTH{1'b0}},	//rs1_prf_value
				1'b0,			//rs1_use_prf
				1'b0,			//rs1_prf_valid
				{`XLEN{1'b0}}, 		//rs1_nprf_value
				1'b0,			//rs1_is_nprf
				{`PRF_WIDTH{1'b0}}, 	//rs2_prf_value
				1'b0,			//rs2_use_prf
				1'b0,			//rs2_prf_valid
				{`XLEN{1'b0}}, 			//rs2_nprf_value
				1'b0,			//rs2_is_imm
				OPA_IS_RS1, 		//opa_select
				OPB_IS_RS2, 		//opb_select
				`NOP,			//inst
				`ZERO_REG,		//dest_reg_idx
				{`PRF_WIDTH{1'b0}}, 	//dest_prf_reg
				{`PRF_WIDTH{1'b0}},	//dest_old_prn
				ALU_ADD, 		//alu_func
				1'b0, 			//rd_mem
				1'b0, 			//wr_mem
				1'b0, 			//cond
				1'b0, 			//uncond
				1'b0,			//branch_predict
				{`XLEN{1'b0}},		//predict_PC
				1'b0, 			//halt
				1'b0, 			//illegal
				1'b0, 			//csr_op
				1'b0 			//valid
			}; 
		end else begin // if (reset)
			id_rs_packet_2 <= `SD id_packet_out_2;
			id_rs_packet_1 <= `SD id_packet_out_0;
			id_rs_packet_0 <= `SD id_packet_out_1;
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//            RAT Pipeline Register             //
//                                              //
//////////////////////////////////////////////////
	rat rat_0(
		//inputs
		.clock(clock), 				
		.reset(reset),	
		.op1_arn_in(opa_arf_idx_array),
		.op2_arn_in(opb_arf_idx_array), 
		.dest_arn_in(dest_arf_idx_array), 
  		.rrat_rename_table_in(rrat_rename_table_in),
    		.prf_free_list(prf_free_list),
    		.rat_mispredict(nuke),
    		.inst_valid_in({id_packet_out_2.valid,id_packet_out_1.valid,id_packet_out_0.valid}),
		.dest_arn_valid_in(dest_arf_idx_valid),
		.rs_rob_haz_stall(rs_rob_haz_stall),
		//outputs
		.rat_op1_prn_out(opa_prf_idx),
		.rat_op2_prn_out(opb_prf_idx),
		.rat_dest_prn_out(dest_prf_idx),
		.dest_prn_valid_out(dest_prn_valid_out),
    		.rat_rename_table_out(rat_rename_table_out), 
		.rat_pre_dest_prn_out(rat_pre_dest_prn_out)   
	);
//////////////////////////////////////////////////
//                                              //
//           Freelist Pipeline Register         //
//                                              //
//////////////////////////////////////////////////
	free_list free_list_0(
		//inputs
        	.reset(reset),
        	.clock(clock),
////////input signals from rat (renaming logic)
        	.rat_dest_prn_in(dest_prf_idx),//destination renaming reg from rat
		.rat_inst_valid_in(dest_arf_idx_valid),//from ID, that the rat dest reg is valid
////////input signals from ROB (commit logic)
		.ROB_packet_in_2(ROB_packet_in_2),
		.ROB_packet_in_1(ROB_packet_in_1),
		.ROB_packet_in_0(ROB_packet_in_0),
////////squash logic
		.squash(nuke),
    		.rrat_rename_table_in(rrat_rename_table_in),
	//outputs
        	.free_list(prf_free_list)
);


endmodule  // module verisimple_
