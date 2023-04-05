
/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                                       int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
                                          int proc2mem_addr_hi, int proc2mem_addr_lo,
						 			     int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void print_close();

module testbench;

	// variables used in the testbench
	logic        clock;
	logic        reset;
	logic [31:0] clock_count;
	logic [31:0] instr_count;
	int          wb_fileno;
	logic [63:0] debug_counter;
	
	BUS_COMMAND  proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0] proc2mem_data;
	MEM_SIZE     proc2mem_size;

	logic  [3:0] mem2proc_response;
	logic [63:0] mem2proc_data;
	logic  [3:0] mem2proc_tag;
	//IF_STAGE_inputs
	ROB_IF_BRANCH_PACKET		branch_packet_2;
	ROB_IF_BRANCH_PACKET		branch_packet_1;
	ROB_IF_BRANCH_PACKET		branch_packet_0;
	//ID_STAGE_INPUTS
	logic [`PRF_SIZE-1:0] prf_valid_list;
	//RAT_INPUTS
	logic  [(`ARF_SIZE) * (`PRF_WIDTH)-1:0] rrat_rename_table_in;
    logic  [`PRF_SIZE-1:0]   		prf_free_list;

	// Outputs from IF-Stage 
	logic [`XLEN-1:0] 	if_PC_out_2;
	logic [31:0] 		if_IR_out_2;
	logic        		if_valid_inst_out_2;
	logic [`XLEN-1:0] 	if_PC_out_1;
	logic [31:0] 		if_IR_out_1;
	logic        		if_valid_inst_out_1;
	logic [`XLEN-1:0] 	if_PC_out_0;
	logic [31:0] 		if_IR_out_0;
	logic        		if_valid_inst_out_0;
	logic			branch_mispredicted;
	// Outputs from IF/ID Pipeline Register
	logic [`XLEN-1:0] 	if_id_PC_2;
	logic [31:0] 		if_id_IR_2;
	logic        		if_id_valid_inst_2;
	logic [`XLEN-1:0] 	if_id_PC_1;
	logic [31:0] 		if_id_IR_1;
	logic 		       	if_id_valid_inst_1;
	logic [`XLEN-1:0] 	if_id_PC_0;
	logic [31:0] 		if_id_IR_0;
	logic 		       	if_id_valid_inst_0;
	// Outputs from ID/RS Pipeline Register
	logic [`XLEN-1:0] 	id_rs_PC_2;
	logic [31:0] 		id_rs_IR_2;
	logic 		       	id_rs_valid_inst_2;
	logic [`XLEN-1:0] 	id_rs_PC_1;
	logic [31:0] 		id_rs_IR_1;
	logic 		       	id_rs_valid_inst_1;
	logic [`XLEN-1:0] 	id_rs_PC_0;
	logic [31:0] 		id_rs_IR_0;
	logic 		       	id_rs_valid_inst_0;
	// Outputs from RS/FU Pipeline Register
	logic [`XLEN-1:0] 	rs_fu_PC_2;
	logic [31:0] 		rs_fu_IR_2;
	logic         		rs_fu_valid_inst_2;
	logic [`XLEN-1:0] 	rs_fu_PC_1;
	logic [31:0] 		rs_fu_IR_1;
	logic         		rs_fu_valid_inst_1;
	logic [`XLEN-1:0] 	rs_fu_PC_0;
	logic [31:0] 		rs_fu_IR_0;
	logic         		rs_fu_valid_inst_0;
	// Outputs from FU/CDB Pipeline Register
	logic [`XLEN-1:0] 	fu_cdb_PC_2;
	logic [31:0] 		fu_cdb_IR_2;
	logic         		fu_cdb_valid_inst_2;	
	logic [`XLEN-1:0] 	fu_cdb_PC_1;
	logic [31:0] 		fu_cdb_IR_1;
	logic         		fu_cdb_valid_inst_1;	
	logic [`XLEN-1:0] 	fu_cdb_PC_0;
	logic [31:0] 		fu_cdb_IR_0;
	logic         		fu_cdb_valid_inst_0;	
	//////// Outputs of rob head
	logic [`XLEN-1:0] 	rob_head_PC_2;
	logic [31:0] 		rob_head_IR_2;
	logic         		rob_head_commit_2;
	logic [`XLEN-1:0] 	rob_head_PC_1;
	logic [31:0] 		rob_head_IR_1;
	logic         		rob_head_commit_1;	
	logic [`XLEN-1:0] 	rob_head_PC_0;
	logic [31:0] 		rob_head_IR_0;
	logic         		rob_head_commit_0;		
	// Outputs from RAT Pipeline Register	
    logic [(`ARF_SIZE)*(`PRF_WIDTH)-1:0]	rat_rename_table_out; 
    logic [(`N_WAY)*(`PRF_WIDTH)-1:0]   	rat_pre_op1_prn_out;
	logic [(`N_WAY)*(`PRF_WIDTH)-1:0]    	rat_pre_op2_prn_out;
	// Inputs from pipeline back
	logic					rs_nuke;
	logic [(`ROB_WIDTH)*(`N_WAY)-1:0]	rob_entry_in;
	// Outputs from pipeline back
	logic [`N_WAY-1:0]			cdb_valid;
	logic [32*(`N_WAY)-1:0]			cdb_value;
	logic [(`PRF_WIDTH)*(`N_WAY)-1:0]	cdb_tag;
	logic [(`N_WAY)*(`ROB_WIDTH)-1:0]	cdb_rob;
	logic [`N_WAY-1:0]			cdb_cond_branch;
	logic [`N_WAY-1:0]			cdb_uncond_branch;
	logic [`N_WAY-1:0]			cdb_rd_mem;
	logic [`N_WAY-1:0]			cdb_wr_mem;
	logic [31:0]	 			branch_target_addr_out;
	logic 		  			branch_taken_out;
	// Inputs from ROB
	// Outputs from ROB
	logic [3:0]		pipeline_completed_insts;
	EXCEPTION_CODE   	pipeline_error_status;
	logic [(`N_WAY)*5-1:0] 		pipeline_commit_wr_idx;
	logic [(`N_WAY)*(`XLEN)-1:0] pipeline_commit_wr_data;
	logic [`N_WAY-1:0]       	pipeline_commit_wr_en;
	logic [(`N_WAY)*(`XLEN)-1:0] pipeline_commit_NPC;


	// Instantiate the Pipeline
	pipeline_top pipeline_top_0(
		//inputs
		////////clock&reset
		.clock(clock),
		.reset(reset),	
		////////input from memory
		.mem2proc_response(mem2proc_response),
		.mem2proc_data(mem2proc_data),
		.mem2proc_tag(mem2proc_tag), 
		//outputs
		////////error status and inst counter ROB outputs
		.error_status(pipeline_error_status),	
		.completed_insts(pipeline_completed_insts),
		.commit_wr_idx	(pipeline_commit_wr_idx	),
		.commit_wr_data	(pipeline_commit_wr_data),
		.commit_wr_en	(pipeline_commit_wr_en	),
		.commit_NPC		(pipeline_commit_NPC	),
		////////outputs to memory
		.proc2mem_command(proc2mem_command),
		.proc2mem_addr(proc2mem_addr),
		.proc2mem_data(proc2mem_data),
		.proc2mem_size(proc2mem_size),
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
		// Outputs from RS/FU Pipeline Register
		.rs_fu_PC_2			(rs_fu_PC_2		   ),
		.rs_fu_IR_2			(rs_fu_IR_2		   ),
		.rs_fu_valid_inst_2	(rs_fu_valid_inst_2),	
		.rs_fu_PC_1			(rs_fu_PC_1		   ),
		.rs_fu_IR_1			(rs_fu_IR_1		   ),
		.rs_fu_valid_inst_1	(rs_fu_valid_inst_1),	
		.rs_fu_PC_0			(rs_fu_PC_0		   ),
		.rs_fu_IR_0			(rs_fu_IR_0		   ),
		.rs_fu_valid_inst_0	(rs_fu_valid_inst_0),
		// Outputs from FU/CDB* Pipeline Register
		.fu_cdb_PC_2			(fu_cdb_PC_2		   ),
		.fu_cdb_IR_2			(fu_cdb_IR_2		   ),
		.fu_cdb_valid_inst_2	(fu_cdb_valid_inst_2),	
		.fu_cdb_PC_1			(fu_cdb_PC_1		   ),
		.fu_cdb_IR_1			(fu_cdb_IR_1		   ),
		.fu_cdb_valid_inst_1	(fu_cdb_valid_inst_1),	
		.fu_cdb_PC_0			(fu_cdb_PC_0		   ),
		.fu_cdb_IR_0			(fu_cdb_IR_0		   ),
		.fu_cdb_valid_inst_0	(fu_cdb_valid_inst_0),
	//////// Outputs of rob head
		.rob_head_PC_2		(rob_head_PC_2		),
		.rob_head_IR_2		(rob_head_IR_2		),
		.rob_head_commit_2	(rob_head_commit_2	),
		.rob_head_PC_1		(rob_head_PC_1		),
		.rob_head_IR_1		(rob_head_IR_1		),
		.rob_head_commit_1	(rob_head_commit_1	),	
		.rob_head_PC_0		(rob_head_PC_0		),
		.rob_head_IR_0		(rob_head_IR_0		),
		.rob_head_commit_0	(rob_head_commit_0	),		
		////////output from rat
    	.rat_rename_table_out(rat_rename_table_out), 
		////////FU branch outputs
		.branch_target_addr_out(branch_target_addr_out),	
		.branch_taken_out(branch_taken_out),
		////////CDB outpus for debug
		.cdb_valid(cdb_valid),
		.cdb_value(cdb_value),
		.cdb_tag(cdb_tag),
		.cdb_rob(cdb_rob),
		.cdb_cond_branch(cdb_cond_branch),
		.cdb_uncond_branch(cdb_uncond_branch),
		.cdb_rd_mem(cdb_rd_mem),
		.cdb_wr_mem(cdb_wr_mem)
	);




	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
		`ifndef CACHE_MODE
		.proc2mem_size     (proc2mem_size),
		`endif
		// Outputs
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);




///////// Generate System Clock
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
///////// Task to display # of elapsed clock edges
	task show_clk_count;
		real cpi;
		
		begin
			cpi = (clock_count + 1.0) / instr_count;
			$display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
			          clock_count+1, instr_count, cpi);
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`VERILOG_CLOCK_PERIOD);
		end
	endtask  // task show_clk_count 
///////// Show contents of a range of Unified Memory, in both hex and decimal


	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
				                                            memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask  // task show_mem_with_decimal




	initial begin
		$dumpvars;

		clock = 1'b0;
		reset = 1'b0;

		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);
		
		$readmemh("program.mem", memory.unified_memory);
		
		@(posedge clock);
		@(posedge clock);
		`SD;
		// This reset is at an odd time to avoid the pos & neg clock edges
		
		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);
		
		wb_fileno = $fopen("writeback.out");

		//Open header AFTER throwing the reset otherwise the reset state is displayed
	//	print_header("                                                                           	 										D-MEM Bus &\n");
		print_header("Cycle:  lane      IF      |     ID      |     RS      |     FU      |		CDB		|     COMMIT     |	Reg Result	D-MEM Bus");
	end




	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + pipeline_completed_insts);
		end
	end  



	always @(negedge clock) begin
        if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
            debug_counter <= 0;
        end else begin
			`SD;
			`SD;
			 // print the piepline stuff via c code to the pipeline.out
			 print_cycles();
			 print_header("  way2");
			 print_stage(" ", if_IR_out_2, if_PC_out_2[31:0], {31'b0,if_valid_inst_out_2});
			 print_stage("|", if_id_IR_2, if_id_PC_2[31:0], {31'b0,if_id_valid_inst_2});
			 print_stage("|", id_rs_IR_2, id_rs_PC_2[31:0], {31'b0,id_rs_valid_inst_2});
			 print_stage("|", rs_fu_IR_2, rs_fu_PC_2[31:0], {31'b0,rs_fu_valid_inst_2});
			 print_stage("|", fu_cdb_IR_2, fu_cdb_PC_2[31:0], {31'b0,fu_cdb_valid_inst_2});
			 print_stage("|", rob_head_IR_2, rob_head_PC_2[31:0], {31'b0,rob_head_commit_2});
			 print_reg(32'b0, pipeline_commit_wr_data[2*32+:32],
				{27'b0,pipeline_commit_wr_idx[2*5+:5]}, {31'b0,pipeline_commit_wr_en[2]});
			 print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
				32'b0, proc2mem_addr[31:0],
				proc2mem_data[63:32], proc2mem_data[31:0]);
			 //print_header("\n");

			 print_cycles();
			 print_header("  way1");
			 print_stage(" ", if_IR_out_1, if_PC_out_1[31:0], {31'b0,if_valid_inst_out_1});
			 print_stage("|", if_id_IR_1, if_id_PC_1[31:0], {31'b0,if_id_valid_inst_1});
			 print_stage("|", id_rs_IR_1, id_rs_PC_1[31:0], {31'b0,id_rs_valid_inst_1});
			 print_stage("|", rs_fu_IR_1, rs_fu_PC_1[31:0], {31'b0,rs_fu_valid_inst_1});
			 print_stage("|", fu_cdb_IR_1, fu_cdb_PC_1[31:0], {31'b0,fu_cdb_valid_inst_1});
			 print_stage("|", rob_head_IR_1, rob_head_PC_1[31:0], {31'b0,rob_head_commit_1});
			 print_reg(32'b0, pipeline_commit_wr_data[1*32+:32],
				{27'b0,pipeline_commit_wr_idx[1*5+:5]}, {31'b0,pipeline_commit_wr_en[1]});
			 print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
				32'b0, proc2mem_addr[31:0],
				proc2mem_data[63:32], proc2mem_data[31:0]);
			 //print_header("\n");

			 print_cycles();
			 print_header("  way0");
			 print_stage(" ", if_IR_out_0, if_PC_out_0[31:0], {31'b0,if_valid_inst_out_0});
			 print_stage("|", if_id_IR_0, if_id_PC_0[31:0], {31'b0,if_id_valid_inst_0});
			 print_stage("|", id_rs_IR_0, id_rs_PC_0[31:0], {31'b0,id_rs_valid_inst_0});
			 print_stage("|", rs_fu_IR_0, rs_fu_PC_0[31:0], {31'b0,rs_fu_valid_inst_0});
			 print_stage("|", fu_cdb_IR_0, fu_cdb_PC_0[31:0], {31'b0,fu_cdb_valid_inst_0});
			 print_stage("|", rob_head_IR_0, rob_head_PC_0[31:0], {31'b0,rob_head_commit_0});
			 print_reg(32'b0, pipeline_commit_wr_data[0*32+:32],
				{27'b0,pipeline_commit_wr_idx[0*5+:5]}, {31'b0,pipeline_commit_wr_en[0]});
			 print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
				32'b0, proc2mem_addr[31:0],
				proc2mem_data[63:32], proc2mem_data[31:0]);
			 print_header("\n");




			 // print the writeback information to writeback.out
			if(pipeline_completed_insts>0) begin
				if(pipeline_commit_wr_en != 0) begin 
					if(pipeline_commit_wr_en[2])
						$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
							pipeline_commit_NPC[2*`XLEN+:`XLEN]-4,
							pipeline_commit_wr_idx[2*5+:5],
							pipeline_commit_wr_data[2*`XLEN+:`XLEN]);
					else if(pipeline_completed_insts>=1)
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[2*`XLEN+:`XLEN]-4);	//way2 is halt or illegal
					if(pipeline_commit_wr_en[1])
						$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
							pipeline_commit_NPC[1*`XLEN+:`XLEN]-4,
							pipeline_commit_wr_idx[1*5+:5],
							pipeline_commit_wr_data[1*`XLEN+:`XLEN]);
					else if(pipeline_completed_insts>=2)
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[1*`XLEN+:`XLEN]-4);	//way2 is halt or illegal
					if(pipeline_commit_wr_en[0])
						$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
							pipeline_commit_NPC[0*`XLEN+:`XLEN]-4,
							pipeline_commit_wr_idx[0*5+:5],
							pipeline_commit_wr_data[0*`XLEN+:`XLEN]);
					else if(pipeline_completed_insts>=3)
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[0*`XLEN+:`XLEN]-4);	//way2 is halt or illegal	
				end
				else begin
					if(pipeline_completed_insts==3) begin
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[2*`XLEN+:`XLEN]-4);	
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[1*`XLEN+:`XLEN]-4);	
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[0*`XLEN+:`XLEN]-4);	
					end
					else if(pipeline_completed_insts==2) begin
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[2*`XLEN+:`XLEN]-4);	
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[1*`XLEN+:`XLEN]-4);	
					end
					else
						$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC[2*`XLEN+:`XLEN]-4);	
				end
			end





			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
				// 8Bytes per line, 16kB total
				
				$display("@@  %t : System halted\n@@", $realtime);
				
				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:  
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:          
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default: 
						$display("@@@ System halted on unknown error code %x", 
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count;
				print_close(); // close the pipe_print output file
				$fclose(wb_fileno);

				$display("DATABUS_FU_ALLOC", `DATABUS_FU_ALLOC);

				#50 $finish;
			end
            debug_counter <= debug_counter + 1;
		end  // if(reset)   
	end 

endmodule  // module testbench
