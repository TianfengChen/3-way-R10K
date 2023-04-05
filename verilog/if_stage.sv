/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps
//`default_nettype none
module stall_rs_rob_haz(
    	input [`RS_WIDTH:0] rs_avail_num,
    	input [`ROB_WIDTH:0] rob_avail_num,
	input [`N_WIDTH-1:0]   inst_avail_num,

	output logic	       rs_rob_haz_stall
);

	always_comb begin
		if(rs_avail_num >= rob_avail_num) begin
			if(rob_avail_num >= inst_avail_num) begin
				rs_rob_haz_stall = 0;
			end
			else begin
				rs_rob_haz_stall = 1;
			end
		end
		else begin
			if(rs_avail_num >= inst_avail_num) begin
				rs_rob_haz_stall = 0;
			end
			else begin
				rs_rob_haz_stall = 1;
			end		
		end
	end
endmodule //module stall_rsrob_haz

module is_branch(
	//inputs
	input INST inst,
	input inst_valid,
	//outputs
	output logic is_branch,
	output logic uncond,
	output logic cond
);
	always_comb begin
		if(inst_valid) begin
			casez(inst)
				`RV32_JAL, `RV32_JALR: begin
					is_branch = 1;
					uncond    = 1;
					cond	  = 0;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					is_branch = 1;
					uncond    = 0;
					cond	  = 1;
				end
				default: begin
					is_branch = 0;
					uncond	  = 0;
					cond	  = 0;
				end
			endcase
		end
		else begin
			is_branch = 0;
			uncond    = 0;
			cond	  = 0;
		end
	end
endmodule

module branch_predictor_controller(
	//inputs
	input				clock,
	input				reset,
////////renew the predictor
	input	ROB_IF_BRANCH_PACKET	branch_packet_2,
	input	ROB_IF_BRANCH_PACKET	branch_packet_1,
	input	ROB_IF_BRANCH_PACKET	branch_packet_0,
////////searching for branch target address
	input	[`N_WAY-1:0]		is_branch,
	input	[`N_WAY-1:0]		cond,
	input	[`N_WAY-1:0]		uncond,
	input   [(`N_WAY)*(`XLEN)-1:0]	branch_PC,
	//outputs
	output	[`N_WAY-1:0]		branch_predicted_taken, // branch taken/not taken
	output	[(`N_WAY)*(`XLEN)-1:0]	branch_predicted_PC	// branch predicted target PC (0 for not taken)
);

	local_branch_predictor local_branch_predictor_0(
		//inputs
		.clock(clock),
		.reset(reset),
	////////renew the predictor
		.branch_packet_2(branch_packet_2),
		.branch_packet_1(branch_packet_1),
		.branch_packet_0(branch_packet_0),
	////////searching for branch taken
		.is_branch(is_branch),
		.branch_PC(branch_PC),
		//outputs
		.branch_predicted_taken(branch_predicted_taken) // branch taken/not taken
	);

	BTB BTB_0(
		//inputs
		.clock(clock),
		.reset(reset),
	////////renew the BTB
		.branch_packet_2(branch_packet_2),
		.branch_packet_1(branch_packet_1),
		.branch_packet_0(branch_packet_0),
	////////searching for branch target address
		.is_branch(is_branch),
		.branch_PC(branch_PC),
		//outputs
		.branch_predicted_PC(branch_predicted_PC)	// branch predicted target PC (0 for not taken)
	);


endmodule //module branch_precictor_controller

module BTB(
	//inputs
	input				clock,
	input				reset,
////////renew the BTB
	input	ROB_IF_BRANCH_PACKET	branch_packet_2,
	input	ROB_IF_BRANCH_PACKET	branch_packet_1,
	input	ROB_IF_BRANCH_PACKET	branch_packet_0,
////////searching for branch target address
	input	[`N_WAY-1:0]		is_branch,
	input   [(`N_WAY)*(`XLEN)-1:0]	branch_PC,
	//outputs
	output	[(`N_WAY)*(`XLEN)-1:0]	branch_predicted_PC	// branch predicted target PC (0 for not taken)
);
////////The BTB and next_BTB
	logic	[`XLEN-1:0]		BTB 		[0:`BTB_SIZE-1];
	logic	[`XLEN-1:0]		next_BTB 	[0:`BTB_SIZE-1];
////////variables for branch target address searching
	logic	[`BTB_WIDTH-1:0] 	branch_idx_srch 	[0:`N_WAY-1];
////////variables for BTB renew
	logic	[`BTB_WIDTH-1:0] 	branch_idx_rn	 	[0:`N_WAY-1];
	logic	[`N_WAY-1:0]		is_valid_branch_rn;	//1. is branch? 2. branch taken? 3. no previous branch mispredicted?
	logic	[`N_WAY-1:0]		branch_rn;		//can the target address of this branch be renewed to BTB?
////////searching for branch target address
	assign	branch_idx_srch[2] = branch_PC[2*`XLEN+3 +: `BTB_WIDTH];
	assign	branch_idx_srch[1] = branch_PC[1*`XLEN+3 +: `BTB_WIDTH];
	assign	branch_idx_srch[0] = branch_PC[0*`XLEN+3 +: `BTB_WIDTH];
	assign	branch_predicted_PC[2*`XLEN +: `XLEN] = is_branch[2] ? BTB[branch_idx_srch[2]] : {`XLEN{1'b0}};
	assign	branch_predicted_PC[1*`XLEN +: `XLEN] = is_branch[1] ? BTB[branch_idx_srch[1]] : {`XLEN{1'b0}};
	assign	branch_predicted_PC[0*`XLEN +: `XLEN] = is_branch[0] ? BTB[branch_idx_srch[0]] : {`XLEN{1'b0}};
////////renew the BTB
	assign	branch_idx_rn[2] = branch_packet_2.branch_PC[3 +: `BTB_WIDTH];
	assign	branch_idx_rn[1] = branch_packet_1.branch_PC[3 +: `BTB_WIDTH];
	assign	branch_idx_rn[0] = branch_packet_0.branch_PC[3 +: `BTB_WIDTH];
	assign	is_valid_branch_rn[2] = (branch_packet_2.uncond_branch | branch_packet_2.cond_branch) & branch_packet_2.branch_true_taken;
	assign	is_valid_branch_rn[1] = (branch_packet_1.uncond_branch | branch_packet_1.cond_branch) & branch_packet_1.branch_true_taken & ~branch_packet_2.branch_misprediction;
	assign	is_valid_branch_rn[0] = (branch_packet_0.uncond_branch | branch_packet_0.cond_branch) & branch_packet_0.branch_true_taken & ~branch_packet_2.branch_misprediction & ~branch_packet_1.branch_misprediction;
	assign	branch_rn[2] = (is_valid_branch_rn[0] & branch_idx_rn[2] == branch_idx_rn[0]) ? 1'b0 : ((is_valid_branch_rn[1] & branch_idx_rn[2] == branch_idx_rn[1]) ? 0 : is_valid_branch_rn[2]);
	assign	branch_rn[1] = (is_valid_branch_rn[0] & branch_idx_rn[1] == branch_idx_rn[0]) ? 1'b0 : is_valid_branch_rn[1];
	assign	branch_rn[0] = is_valid_branch_rn[0];

	always_comb begin
		next_BTB = BTB;
		if(branch_rn[2]) begin
			next_BTB[branch_idx_rn[2]] = branch_packet_2.branch_true_target_PC; 
		end
		if(branch_rn[1]) begin
			next_BTB[branch_idx_rn[1]] = branch_packet_1.branch_true_target_PC; 
		end
		if(branch_rn[0]) begin
			next_BTB[branch_idx_rn[0]] = branch_packet_0.branch_true_target_PC; 
		end
	end
////////refresh BTB with next_BTB
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i=0;i<`BTB_SIZE;i=i+1) begin
				BTB[i] <= `SD {`XLEN{1'b0}};
			end
		end
		else begin
			BTB <= `SD next_BTB;
		end
	end
endmodule //module BTB

module local_branch_predictor(
	//inputs
	input				clock,
	input				reset,
////////renew the predictor
	input	ROB_IF_BRANCH_PACKET	branch_packet_2,
	input	ROB_IF_BRANCH_PACKET	branch_packet_1,
	input	ROB_IF_BRANCH_PACKET	branch_packet_0,
////////searching for branch taken
	input	[`N_WAY-1:0]		is_branch,
	input   [(`N_WAY)*(`XLEN)-1:0]	branch_PC,
	//outputs
	output	[`N_WAY-1:0]		branch_predicted_taken // branch taken/not taken
);
////////The BHT & PHT
	logic	[`PHT_WIDTH-1:0]	BHT		[0:`BHT_SIZE-1];
	logic	[`PHT_SIZE-1:0]		PHT		[0:`BHT_SIZE-1];
	logic	[`PHT_WIDTH-1:0]	next_BHT_2	[0:`BHT_SIZE-1];
	logic	[`PHT_SIZE-1:0]		next_PHT_2	[0:`BHT_SIZE-1];
	logic	[`PHT_WIDTH-1:0]	next_BHT_1	[0:`BHT_SIZE-1];
	logic	[`PHT_SIZE-1:0]		next_PHT_1	[0:`BHT_SIZE-1];
	logic	[`PHT_WIDTH-1:0]	next_BHT_0	[0:`BHT_SIZE-1];
	logic	[`PHT_SIZE-1:0]		next_PHT_0	[0:`BHT_SIZE-1];
////////variables for branch taken searching
	logic	[`BHT_WIDTH-1:0] 	branch_idx_srch [0:`N_WAY-1];
////////variables for BTB renew
	logic	[`BHT_WIDTH-1:0] 	branch_idx_rn	 	[0:`N_WAY-1];
	logic	[`N_WAY-1:0]		is_valid_branch_rn;	//1. is branch? 2. no previous branch mispredicted?
	logic	[`N_WAY-1:0]		branch_taken_rn;	//1. is branch? 2. no previous branch mispredicted?
////////searching for branch taken
	assign	branch_idx_srch[2] = branch_PC[2*`XLEN+3 +: `BHT_WIDTH];
	assign	branch_idx_srch[1] = branch_PC[1*`XLEN+3 +: `BHT_WIDTH];
	assign	branch_idx_srch[0] = branch_PC[0*`XLEN+3 +: `BHT_WIDTH];
	assign	branch_predicted_taken[2] = is_branch[2] ? PHT[branch_idx_srch[2]][BHT[branch_idx_srch[2]]] : 1'b0;
	assign	branch_predicted_taken[1] = is_branch[1] ? PHT[branch_idx_srch[1]][BHT[branch_idx_srch[1]]] : 1'b0;
	assign	branch_predicted_taken[0] = is_branch[0] ? PHT[branch_idx_srch[0]][BHT[branch_idx_srch[0]]] : 1'b0;
////////renew the predictor
	assign	branch_idx_rn[2] = branch_packet_2.branch_PC[3 +: `BHT_WIDTH];
	assign	branch_idx_rn[1] = branch_packet_1.branch_PC[3 +: `BHT_WIDTH];
	assign	branch_idx_rn[0] = branch_packet_0.branch_PC[3 +: `BHT_WIDTH];
	assign	is_valid_branch_rn[2] = (branch_packet_2.uncond_branch | branch_packet_2.cond_branch);
	assign	is_valid_branch_rn[1] = (branch_packet_1.uncond_branch | branch_packet_1.cond_branch) & ~branch_packet_2.branch_misprediction;
	assign	is_valid_branch_rn[0] = (branch_packet_0.uncond_branch | branch_packet_0.cond_branch) & ~branch_packet_2.branch_misprediction & ~branch_packet_1.branch_misprediction;
	assign	branch_taken_rn[2] = branch_packet_2.branch_true_taken;
	assign	branch_taken_rn[1] = branch_packet_1.branch_true_taken;
	assign	branch_taken_rn[0] = branch_packet_0.branch_true_taken;

	always_comb begin
		next_BHT_2 = BHT;
		next_PHT_2 = PHT;
		if(is_valid_branch_rn[2]) begin
			next_PHT_2[branch_idx_rn[2]][BHT[branch_idx_rn[2]]] = branch_taken_rn[2];
			next_BHT_2[branch_idx_rn[2]] = {branch_taken_rn[2],BHT[branch_idx_rn[2]][1 +: `PHT_WIDTH-1]}; 
		end
	end
	always_comb begin
		next_BHT_1 = next_BHT_2;
		next_PHT_1 = next_PHT_2;
		if(is_valid_branch_rn[1]) begin
			next_PHT_1[branch_idx_rn[1]][next_BHT_2[branch_idx_rn[1]]] = branch_taken_rn[1];
			next_BHT_1[branch_idx_rn[1]] = {branch_taken_rn[1],next_BHT_2[branch_idx_rn[1]][1 +: `PHT_WIDTH-1]}; 
		end
	end
	always_comb begin
		next_BHT_0 = next_BHT_1;
		next_PHT_0 = next_PHT_1;
		if(is_valid_branch_rn[0]) begin
			next_PHT_0[branch_idx_rn[0]][next_BHT_1[branch_idx_rn[0]]] = branch_taken_rn[0];
			next_BHT_0[branch_idx_rn[0]] = {branch_taken_rn[0],next_BHT_1[branch_idx_rn[0]][1 +: `PHT_WIDTH-1]}; 
		end
	end
////////refresh BHT&PHT with next_BHT&next_PHT
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i=0;i<`BHT_SIZE;i=i+1) begin
				BHT[i] <= `SD {`PHT_WIDTH{1'b0}};
				PHT[i] <= `SD {`PHT_SIZE{1'b0}};
			end
		end
		else begin
			BHT <= `SD next_BHT_0;
			PHT <= `SD next_PHT_0;
		end
	end
endmodule //module local_branch_predictor

module if_stage(
	//inputs
////////system clock&reset
	input				clock,                 
	input				reset, 
////////branch packet to the predictor and next_PC                 
	input	ROB_IF_BRANCH_PACKET	branch_packet_2,			
	input	ROB_IF_BRANCH_PACKET	branch_packet_1,			
	input	ROB_IF_BRANCH_PACKET	branch_packet_0,
////////Data coming back from instruction-memory			
    	input	[3:0]			Imem2proc_response,
	input	[63:0]			Imem2proc_data,         
    	input	[3:0]			Imem2proc_tag,
////////RS&ROB stru hazard signal
    	input	[`RS_WIDTH:0]		rs_avail_num,
    	input	[`ROB_WIDTH:0]		rob_avail_num,
	input	[`N_WIDTH-1:0]		inst_avail_num,
////////the nuke signal from ROB
	input				nuke,
////////Data from Dcache controller
    	input  	[1:0] 		 	load_store,
    	input  	[1:0]			proc2Dmem_command,
    	input  	[31:0] 			proc2Dmem_addr,
    	input  	[1:0]			proc2Dmem_size,
    	input  	[63:0] 			proc2Dmem_data,
	//outputs
////////the stru hazard signal
	output	logic			rs_rob_haz_stall,
////////Request sent to Instruction memory
	output	logic [`XLEN-1:0] 	proc2mem_addr,    
	output	logic [1:0]	 	proc2mem_command,
	output 	logic [63:0] 		proc2mem_data,
	output 	logic [1:0] 		proc2mem_size,  
////////Output to Dcache controller
	output	logic	[4:0]  		last_index,
	output	logic	[7:0]  		last_tag, 
    	output 	logic	[63:0] 		load_data,
	output 	logic			data_write_enable_load,
////////Output data packet from IF going to ID    
	output	logic			branch_mispredicted,
	output	IF_ID_PACKET 		if_packet_out_2,        
	output	IF_ID_PACKET 		if_packet_out_1, 
	output	IF_ID_PACKET 		if_packet_out_0
);
//////// next_PC-make-sure-signals
	logic	[`XLEN-1:0]    		PC_reg		[`N_WAY];	// PC we are currently fetching
	logic	[`XLEN-1:0]    		PC_plus_4	[`N_WAY];
	logic	[`XLEN-1:0]   		next_PC		[`N_WAY];
	logic	[`XLEN-1:0]    		PC_wo_branch	[`N_WAY];	// PC without branch taken
	logic	[`XLEN-1:0]    		PC_w_branch	[`N_WAY];	// PC with branch predicted
	logic				PC_enable;
//////// instruction_valid-signals
	logic	[`N_WAY-1:0]   		inst_avail_icash;
	logic	[`N_WAY-1:0]		inst_avail_w_branch;		// instruction is unavailable once the instruction ahead is predicted taken
	logic	[`N_WAY-1:0]		inst_avail;			// final availability of the instructions (cache read & branch predict)
//////// input/output variables from icash and cashmem
	// input data to cache controller
        logic	[4:0]  			cashmem_idx_2, cashmem_idx_1, cashmem_idx_0;
        logic	[7:0]  			cashmem_tag_2, cashmem_tag_1, cashmem_tag_0;
	// output data from cache controller
        logic	[63:0] 			cashmem_data_2;
        logic	[63:0] 			cashmem_data_1;
        logic	[63:0] 			cashmem_data_0;
        logic	[`N_WAY-1:0] 		rd1_valid;
	logic	[63:0] 			Icache_data_out;
	logic	      			Icache_valid_out; 
	logic	[`XLEN-1:0] 		zero_reg;	//used when output port don't match
	// input data to icache
	logic	[`N_WIDTH-1:0] 		PC2mem_way;	
	logic	[`XLEN-1:0]    		PC2mem;
	logic	[`XLEN-1:0]    		PC2mem_pre;
        logic	[63:0] 			cashmem_data;
        logic	      			cashmem_valid;
	// input to icache & output from cache controller
	logic	[4:0]  			current_index;
	logic	[7:0]  			current_tag;
 	logic  	      			data_write_enable_fetch;
//////// which mispredicted branch is selected to squash
	logic	[`XLEN-1:0]		branch_true_PC;
//////// input/output variables to branch_predictor
	// input data to branch predictor
	logic	[`N_WAY-1:0]		is_branch;
	logic	[`N_WAY-1:0]		uncond;
	logic	[`N_WAY-1:0]		cond;
	// output data from branch precictor
	logic	[`N_WAY-1:0]		branch_avail_taken; 		// inst valid list & branch taken/not taken from predictor
	logic	[`N_WAY-1:0]		branch_predicted_taken; 	// branch taken/not taken from predictor
	logic	[(`N_WAY)*(`XLEN)-1:0]	branch_predicted_PC;		// branch predicted target PC (0 for not taken)
//////// determine which instruction is sent to imem
	assign PC2mem_way	= rd1_valid[2] ?  (rd1_valid[0] ? 1 : 0) : 2;
	assign PC2mem		= rd1_valid[2] ? (rd1_valid[0] ? (rd1_valid[1] ? PC2mem_pre : PC_reg[1]) : PC_reg[0]) : PC_reg[2];
	assign cashmem_data	= rd1_valid[2] ?  (rd1_valid[0] ? (rd1_valid[1] ? 32'h0 : if_packet_out_1.inst) : if_packet_out_0.inst) : if_packet_out_2.inst;
	assign cashmem_valid	= rd1_valid[PC2mem_way];
//////// default next PC value
	assign PC_plus_4[2]	= PC_reg[2] + 4;
	assign PC_plus_4[0]	= PC_reg[0] + 4;
	assign PC_plus_4[1]	= PC_reg[1] + 4;
//////// The instruction is able to be dispatched if the instructions above are all available
	assign inst_avail_icash[2]	= rd1_valid[2];
	assign inst_avail_icash[0]	= rd1_valid[2] & rd1_valid[0];
	assign inst_avail_icash[1]	= rd1_valid[2] & rd1_valid[0] & rd1_valid[1];
//////// instrucion availability after branch prediction
	assign inst_avail_w_branch[2]	= 1'b1;
	assign inst_avail_w_branch[0]	= ~branch_predicted_taken[2];
	assign inst_avail_w_branch[1]	= ~branch_predicted_taken[2] & ~branch_predicted_taken[0];
//////// the final availability of the instructions
	assign inst_avail 	= inst_avail_icash & inst_avail_w_branch;
//////// The next pc is considered according to the availavility of the current instructions
	assign PC_wo_branch[2]	= inst_avail_icash[1] ? PC_reg[1]+4 : (inst_avail_icash[0] ? PC_reg[1] : (inst_avail_icash[2] ? PC_reg[0] : PC_reg[2]));
	assign PC_wo_branch[0]	= PC_wo_branch[2]+4;
	assign PC_wo_branch[1]	= PC_wo_branch[2]+8;
//////// If branch is taken, the next_PC is the target PC
	assign branch_avail_taken = inst_avail & branch_predicted_taken;
	assign PC_w_branch[2]	= branch_avail_taken[2] ? branch_predicted_PC[2*`XLEN +: `XLEN] : (branch_avail_taken[0] ? branch_predicted_PC[0*`XLEN +: `XLEN] : (branch_avail_taken[1] ? branch_predicted_PC[1*`XLEN +: `XLEN] : PC_wo_branch[2]));
	assign PC_w_branch[0]	= PC_w_branch[2]+4;
	assign PC_w_branch[1]	= PC_w_branch[2]+8;
//////// branch misprediction has the highest priority to change the next_PC
	assign branch_mispredicted	= branch_packet_2.branch_misprediction | branch_packet_1.branch_misprediction | branch_packet_0.branch_misprediction;
	assign branch_true_PC	= branch_packet_2.branch_misprediction ? branch_packet_2.branch_true_PC : (branch_packet_1.branch_misprediction ? branch_packet_1.branch_true_PC : (branch_packet_0.branch_misprediction ? branch_packet_0.branch_true_PC : {`XLEN{1'b0}}));
	assign next_PC[2]	= branch_mispredicted ? branch_true_PC   : PC_w_branch[2];
	assign next_PC[0]	= branch_mispredicted ? branch_true_PC+4 : PC_w_branch[0];
	assign next_PC[1]	= branch_mispredicted ? branch_true_PC+8 : PC_w_branch[1];	
//////// IF_PACKET_OUT creation
	assign if_packet_out_2.valid	= inst_avail[2]; 
	assign if_packet_out_1.valid	= inst_avail[1]; 
	assign if_packet_out_0.valid	= inst_avail[0];
	assign if_packet_out_2.inst 	= PC_reg[2][2] ? cashmem_data_2[63:32] : cashmem_data_2[31:0];
	assign if_packet_out_1.inst 	= PC_reg[1][2] ? cashmem_data_1[63:32] : cashmem_data_1[31:0];
	assign if_packet_out_0.inst 	= PC_reg[0][2] ? cashmem_data_0[63:32] : cashmem_data_0[31:0];
	assign if_packet_out_2.NPC   	= PC_plus_4[2];
	assign if_packet_out_1.NPC   	= PC_plus_4[1];
	assign if_packet_out_0.NPC   	= PC_plus_4[0];
	assign if_packet_out_2.PC    	= PC_reg[2];
	assign if_packet_out_1.PC    	= PC_reg[1];
	assign if_packet_out_0.PC    	= PC_reg[0];
	assign if_packet_out_2.branch_predicted_taken	= branch_predicted_taken[2];
	assign if_packet_out_1.branch_predicted_taken	= branch_predicted_taken[1];
	assign if_packet_out_0.branch_predicted_taken	= branch_predicted_taken[0];
	assign if_packet_out_2.branch_predicted_PC	= branch_predicted_PC[2*`XLEN +: `XLEN];
	assign if_packet_out_1.branch_predicted_PC	= branch_predicted_PC[1*`XLEN +: `XLEN];
	assign if_packet_out_0.branch_predicted_PC	= branch_predicted_PC[0*`XLEN +: `XLEN];
////////

	assign PC_enable = ~rs_rob_haz_stall & ~nuke | branch_mispredicted;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)begin
			PC_reg[2] <= `SD 32'h0000_0000;       // initial PC value is 0
			PC_reg[0] <= `SD 32'h0000_0004;       // initial PC value is 0
			PC_reg[1] <= `SD 32'h0000_0008;       // initial PC value is 0
			PC2mem_pre<= `SD 32'h0000_0000;
        end
		else if(PC_enable)
			PC_reg <= `SD next_PC; // transition to next PC
			PC2mem_pre<= `SD PC2mem;
	end  // always

	stall_rs_rob_haz stall_rs_rob_haz_0(
		//inputs
    		.rs_avail_num(rs_avail_num),
    		.rob_avail_num(rob_avail_num),
		.inst_avail_num(inst_avail_num),
		//outputs
		.rs_rob_haz_stall(rs_rob_haz_stall)
	);
	icache icache_0(
		//inputs
		.clock(clock),
 		.reset(reset),
	/////////input from memory
		.Imem2proc_response(Imem2proc_response),
		.Imem2proc_data(Imem2proc_data),
		.Imem2proc_tag(Imem2proc_tag),
	/////////from if_stage: search for inst for 3 superscalar ways
 		.proc2Icache_addr_2({32'b0,PC_reg[2]}),
		.proc2Icache_addr_1({32'b0,PC_reg[1]}),
		.proc2Icache_addr_0({32'b0,PC_reg[0]}),
	/////////The inst fetch request to memory
		.inst_fetch_addr({32'b0,PC2mem}),
		.inst_fetch_data(cashmem_data),
		.inst_fetch_valid(cashmem_valid),
	/////////The load/store request to memory
		.load_store(load_store),
		.proc2Dmem_command(proc2Dmem_command),
		.proc2Dmem_addr(proc2Dmem_addr),
		.proc2Dmem_size(proc2Dmem_size),
		.proc2Dmem_data(proc2Dmem_data),
		//outputs
	/////////Output to memory
		.proc2Imem_command(proc2mem_command),
		.proc2Imem_addr({zero_reg,proc2mem_addr}),
		.proc2Imem_data(proc2mem_data),
		.proc2Imem_size(proc2mem_size),
	/////////INST fetch cache search result
		.Icache_data_out(Icache_data_out),
		.Icache_valid_out(Icache_valid_out),
	/////////index and tag of 3-way inst fetch
		.cashmem_rd_idx_2(cashmem_idx_2),
		.cashmem_rd_idx_1(cashmem_idx_1),
		.cashmem_rd_idx_0(cashmem_idx_0),
		.cashmem_rd_tag_2(cashmem_tag_2),
		.cashmem_rd_tag_1(cashmem_tag_1),
		.cashmem_rd_tag_0(cashmem_tag_0),
	/////////request information in cache controller
		.current_index(current_index),
		.current_tag(current_tag),
		.last_index(last_index),
		.last_tag(last_tag),
		.load_data(load_data),
    		.data_write_enable_fetch(data_write_enable_fetch),
    		.data_write_enable_load(data_write_enable_load)
	);
	cache cash_0(
		//inputs
        	.clock(clock), .reset(reset), 
		.rd1_idx_2(cashmem_idx_2), 
		.rd1_idx_1(cashmem_idx_1), 
		.rd1_idx_0(cashmem_idx_0),
		.rd1_tag_2(cashmem_tag_2), 
		.rd1_tag_1(cashmem_tag_1), 
		.rd1_tag_0(cashmem_tag_0),
		.wr1_en(data_write_enable_fetch),
        	.wr1_idx(last_index), 
        	.wr1_tag(last_tag), 
        	.wr1_data(Imem2proc_data), 
		//outputs
        	.rd1_data_2(cashmem_data_2),
        	.rd1_data_1(cashmem_data_1),
        	.rd1_data_0(cashmem_data_0),
        	.rd1_valid(rd1_valid)
	);
	is_branch is_branch_2(
		//inputs
		.inst(if_packet_out_2.inst),
		.inst_valid(inst_avail_icash[2]),
		//outputs
		.is_branch(is_branch[2]),
		.uncond(uncond[2]),
		.cond(cond[2])
	);
	is_branch is_branch_1(
		//inputs
		.inst(if_packet_out_1.inst),
		.inst_valid(inst_avail_icash[1]),
		//outputs
		.is_branch(is_branch[1]),
		.uncond(uncond[1]),
		.cond(cond[1])
	);
	is_branch is_branch_0(
		//inputs
		.inst(if_packet_out_0.inst),
		.inst_valid(inst_avail_icash[0]),
		//outputs
		.is_branch(is_branch[0]),
		.uncond(uncond[0]),
		.cond(cond[0])
	);
	branch_predictor_controller bran_pred_cont_0(
		//inputs
		.clock(clock),
		.reset(reset),
		.branch_packet_2(branch_packet_2),
		.branch_packet_1(branch_packet_1),
		.branch_packet_0(branch_packet_0),
		.is_branch(is_branch),
		.cond(cond),
		.uncond(uncond),
		.branch_PC({PC_reg[2],PC_reg[1],PC_reg[0]}),
		//outputs
		.branch_predicted_taken(branch_predicted_taken),
		.branch_predicted_PC(branch_predicted_PC)
	);
endmodule  // module if_stage
//`default_nettype wire
