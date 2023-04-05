//`default_nettype none
`timescale 1ns/100ps

module pipeline_back(
	input									clk,
	input									rst,
	input ID_EX_PACKET						id_packet_in_2,
	input ID_EX_PACKET						id_packet_in_1,
	input ID_EX_PACKET						id_packet_in_0,
    input [4:0] 							Dmem2proc_idx,		//The address index from icache controller
    input [7:0] 							Dmem2proc_tag,		//The address tag from icache controller
   	input [63:0] 							Dmem2proc_data,		//The data from memory
   	input 									Dmem2proc_valid,	//If the data is to be writen in the Dcache


	output [`N_WAY-1:0]						cdb_valid,				 //debug port
	output [32*(`N_WAY)-1:0]				cdb_value,				 //debug port
	output [(`PRF_WIDTH)*(`N_WAY)-1:0]		cdb_tag,				 //debug port
	output [(`N_WAY)*(`ROB_WIDTH)-1:0]		cdb_rob,
	output [`N_WAY-1:0]						cdb_cond_branch,
	output [`N_WAY-1:0]						cdb_uncond_branch,
	output [`N_WAY-1:0]						cdb_rd_mem,
	output [`N_WAY-1:0]						cdb_wr_mem,	
	output [31:0]	 						branch_target_addr_out,	
	output 		  							branch_taken_out,
	output [`RS_WIDTH:0]	  				rs_avail_cnt,
	output [`ROB_WIDTH:0]					rob_avail_cnt,
	output EXCEPTION_CODE   				error_status,	
	output [3:0]							completed_insts,
	output ROB_PACKET						ROB_packet_out_2,	
	output ROB_PACKET						ROB_packet_out_1,		
	output ROB_PACKET						ROB_packet_out_0,		
	output ROB_IF_BRANCH_PACKET				ROB_branch_out_2,	
	output ROB_IF_BRANCH_PACKET				ROB_branch_out_1,		
	output ROB_IF_BRANCH_PACKET				ROB_branch_out_0,
	output									nuke,
	output [(`ARF_SIZE)*(`PRF_WIDTH)-1:0]	rrat_rename_table_out,
    output [`PRF_SIZE-1:0]  				valid_list,
	output [(`PRF_SIZE)*(`XLEN)-1:0]		prf_data_out,
	output	[1:0]							load_store,		//[1,0] for load, [0,1] for store, [0,0] for BUS_NONE
   	output 	[1:0] 							proc2Dmem_command,
    output 	[31:0]							proc2Dmem_addr,
	output 	[1:0]							proc2Dmem_size,
	output 	[63:0]							proc2Dmem_data,

	output [`XLEN-1:0] 						rs_fu_PC_2,
	output [31:0] 							rs_fu_IR_2,
	output         							rs_fu_valid_inst_2,	
	output [`XLEN-1:0] 						rs_fu_PC_1,
	output [31:0] 							rs_fu_IR_1,
	output         							rs_fu_valid_inst_1,	
	output [`XLEN-1:0] 						rs_fu_PC_0,
	output [31:0] 							rs_fu_IR_0,
	output         							rs_fu_valid_inst_0,
	output [`XLEN-1:0] 						fu_cdb_PC_2,
	output [31:0] 							fu_cdb_IR_2,
	output         							fu_cdb_valid_inst_2,	
	output [`XLEN-1:0] 						fu_cdb_PC_1,
	output [31:0] 							fu_cdb_IR_1,
	output         							fu_cdb_valid_inst_1,	
	output [`XLEN-1:0] 						fu_cdb_PC_0,
	output [31:0] 							fu_cdb_IR_0,
	output         							fu_cdb_valid_inst_0		
);








//////////////////////////////////////////////////
//                                              //
//           Stage3: RS+ROB+PRF+RRAT            //
//                                              //
//////////////////////////////////////////////////

	//input of rs
	wire [`N_WAY-1:0]					rs_inst_valid_in ;		//asserted when IF is dispatching instruction
	wire [32*(`N_WAY)-1:0] 				rs_inst_in;			// from decoder
	wire [32*(`N_WAY)-1:0] 				rs_pc_in;				// from decoder
	wire [32*(`N_WAY)-1:0] 				rs_npc_in;				// from decoder
	wire [5*(`N_WAY)-1:0] 				rs_op_type_in; 		//from decoder						
	wire [(`PRF_WIDTH)*(`N_WAY)-1:0] 	rs_op1_prn_in; 		//from rat					
	wire [(`PRF_WIDTH)*(`N_WAY)-1:0] 	rs_op2_prn_in; 		//from rat		
	wire [`N_WAY-1:0]					rs_use_op1_prn_in;	//  
	wire [`N_WAY-1:0]					rs_use_op2_prn_in;	// 
	wire [(`PRF_WIDTH)*(`N_WAY)-1:0] 	rs_dest_prn_in;		//from prf free list 
	wire [2*`N_WAY-1:0]					rs_op1_select_in;		
	wire [4*`N_WAY-1:0]					rs_op2_select_in;		
	wire [`N_WAY-1:0]					rs_rd_mem_in;			
	wire [`N_WAY-1:0]					rs_wr_mem_in;			
	wire [`N_WAY-1:0]					rs_cond_branch_in;		
	wire [`N_WAY-1:0]					rs_uncond_branch_in;		
	wire [`N_WAY-1:0]					rs_halt_in;				
	wire [`N_WAY-1:0]					rs_illigal_in;			
	wire [`N_WAY-1:0] 					rs_op1_ready_in; 					//from prf valid bit
	wire [`N_WAY-1:0] 					rs_op2_ready_in; 					//from prf valid bit		
	wire [4*(`N_WAY)-1:0]				rs_fu_type_in;			// from decoder; does this inst use alu; mul; mem or bcond?
	wire [(`IMM_WIDTH)*(`N_WAY)-1:0]  	rs_imm_in;				// from decoder, imm value
	wire [`ROB_SIZE-1:0]				load_ready_in;
	assign rs_inst_valid_in		= {id_packet_in_2.valid,id_packet_in_1.valid,id_packet_in_0.valid};		//asserted when IF is dispatching instruction
	assign rs_inst_in		 	= {id_packet_in_2.inst,id_packet_in_1.inst,id_packet_in_0.inst};			// from decoder
	assign rs_pc_in				= {id_packet_in_2.PC,id_packet_in_1.PC,id_packet_in_0.PC};				// from decoder
	assign rs_npc_in			= {id_packet_in_2.NPC,id_packet_in_1.NPC,id_packet_in_0.NPC};				// from decoder
	assign rs_op_type_in		= {id_packet_in_2.alu_func,id_packet_in_1.alu_func,id_packet_in_0.alu_func}; 		//from decoder						
	assign rs_op1_prn_in		= {id_packet_in_2.rs1_prf_value,id_packet_in_1.rs1_prf_value,id_packet_in_0.rs1_prf_value}; 		//from rat					
	assign rs_op2_prn_in		= {id_packet_in_2.rs2_prf_value,id_packet_in_1.rs2_prf_value,id_packet_in_0.rs2_prf_value}; 		//from rat		
	assign rs_use_op1_prn_in	= {id_packet_in_2.rs1_use_prf,id_packet_in_1.rs1_use_prf,id_packet_in_0.rs1_use_prf};	//  
	assign rs_use_op2_prn_in	= {id_packet_in_2.rs2_use_prf,id_packet_in_1.rs2_use_prf,id_packet_in_0.rs2_use_prf};	// 
	assign rs_dest_prn_in		= {id_packet_in_2.dest_prf_reg,id_packet_in_1.dest_prf_reg,id_packet_in_0.dest_prf_reg};		//from prf free list 
	assign rs_op1_select_in		= {id_packet_in_2.opa_select,id_packet_in_1.opa_select,id_packet_in_0.opa_select};		
	assign rs_op2_select_in		= {id_packet_in_2.opb_select,id_packet_in_1.opb_select,id_packet_in_0.opb_select};		
	assign rs_rd_mem_in			= {id_packet_in_2.rd_mem,id_packet_in_1.rd_mem,id_packet_in_0.rd_mem};			
	assign rs_wr_mem_in			= {id_packet_in_2.wr_mem,id_packet_in_1.wr_mem,id_packet_in_0.wr_mem};			
	assign rs_cond_branch_in	= {id_packet_in_2.cond_branch,id_packet_in_1.cond_branch,id_packet_in_0.cond_branch};		
	assign rs_uncond_branch_in	= {id_packet_in_2.uncond_branch,id_packet_in_1.uncond_branch,id_packet_in_0.uncond_branch};		
	assign rs_halt_in			= {id_packet_in_2.halt,id_packet_in_1.halt,id_packet_in_0.halt};				
	assign rs_illigal_in		= {id_packet_in_2.illegal,id_packet_in_1.illegal,id_packet_in_0.illegal};			
	assign rs_op1_ready_in		= {id_packet_in_2.rs1_prf_valid,id_packet_in_1.rs1_prf_valid,id_packet_in_0.rs1_prf_valid}; 					//from prf valid bit
	assign rs_op2_ready_in		= {id_packet_in_2.rs2_prf_valid,id_packet_in_1.rs2_prf_valid,id_packet_in_0.rs2_prf_valid}; 					//from prf valid bit		
	assign rs_fu_type_in		= {id_packet_in_2.FU_type,id_packet_in_1.FU_type,id_packet_in_0.FU_type};			// from decoder, does this inst use alu, mul, mem or bcond?
	assign rs_imm_in			= {id_packet_in_2.rs2_nprf_value,id_packet_in_1.rs2_nprf_value,id_packet_in_0.rs2_nprf_value};				// from decoder, imm value
	//output of rs
	wire [`N_WAY-1:0]	 				rs_inst_valid_out		;
	wire [32*(`N_WAY)-1:0]				rs_inst_out				;
	wire [32*(`N_WAY)-1:0]				rs_pc_out				;
	wire [32*(`N_WAY)-1:0]				rs_npc_out				;
	wire [5*(`N_WAY)-1:0] 				rs_op_type_out			;
	wire [(`PRF_WIDTH)*(`N_WAY)-1:0]  	rs_op1_prn_out 			;	//to prf
	wire [(`PRF_WIDTH)*(`N_WAY)-1:0]  	rs_op2_prn_out 			;	//to prf
	wire [(`PRF_WIDTH)*(`N_WAY)-1:0]  	rs_dest_prn_out 		;
   	wire [2*`N_WAY-1:0]					rs_op1_select_out		;
	wire [4*`N_WAY-1:0]					rs_op2_select_out		;
	wire [`N_WAY-1:0]					rs_rd_mem_out			;
	wire [`N_WAY-1:0]					rs_wr_mem_out			;
	wire [`N_WAY-1:0]					rs_cond_branch_out		;
	wire [`N_WAY-1:0]					rs_uncond_branch_out	;
	wire [`N_WAY-1:0]					rs_halt_out				;
	wire [`N_WAY-1:0]					rs_illigal_out			;
	wire [(`ROB_WIDTH)*(`N_WAY)-1:0] 	rs_rob_entry_out		;
	wire [4*(`N_WAY)-1:0]			 	rs_fu_type_out			;
	wire [(`IMM_WIDTH)*(`N_WAY)-1:0] 	rs_imm_out				;
	wire		 						rs_full 				;	//to


	//input of prf
  	wire [2:0]                          ROB_commit_valid;		
	wire [(`N_WAY)*(`PRF_WIDTH)-1:0]    rob_old_prn_width_in;
	assign ROB_commit_valid = 			{ROB_packet_out_2.commit,ROB_packet_out_1.commit,ROB_packet_out_0.commit};
	assign rob_old_prn_width_in = 		{ROB_packet_out_2.id_packet.dest_old_prn,ROB_packet_out_1.id_packet.dest_old_prn,ROB_packet_out_0.id_packet.dest_old_prn};

	//output of prf
    wire [(`N_WAY)*(`XLEN)-1:0] 		prf_op1_value_out;
    wire [(`N_WAY)*(`XLEN)-1:0] 		prf_op2_value_out;

	//input of rrat
	wire [(`N_WAY)*(`ARF_WIDTH)-1:0]	rrat_dest_arn_in;     // from RoB
   	wire [`N_WAY-1:0]                   rrat_inst_valid_in;       //commit
    wire [(`N_WAY)*(`PRF_WIDTH)-1:0]    rrat_dest_prn_in;       // from RoB
	assign rrat_dest_arn_in = 			{ROB_packet_out_2.id_packet.dest_reg_idx,ROB_packet_out_1.id_packet.dest_reg_idx,ROB_packet_out_0.id_packet.dest_reg_idx}; 
	assign rrat_inst_valid_in = 		{ROB_packet_out_2.commit,ROB_packet_out_1.commit,ROB_packet_out_0.commit};
	assign rrat_dest_prn_in = 			{ROB_packet_out_2.id_packet.dest_prf_reg,ROB_packet_out_1.id_packet.dest_prf_reg,ROB_packet_out_0.id_packet.dest_prf_reg}; 

	//output of rob	
	wire [(`N_WAY)*(`ROB_WIDTH)-1:0] 	rs_ROB_num; 

	//connect fu and rob
	wire [31:0]  			fu_store_address_mem_out;	//store info to rob
	wire [31:0]  			fu_store_data_mem_out	;  //store info to rob
	wire [`ROB_WIDTH-1:0]	fu_store_rob_out		;	//store info to rob
	wire 					fu_store_en_out			;	//store info to rob	

	wire 					fu_miss_waiting			;
	wire					store_commit_valid		;	//when cache hit; the store inst can commit from ROB
  	wire					Dcache_valid_out		;

	rs_top rs_top_inst(
		.clk				(clk				),
		.rst				(rst				),
		.inst_valid_in 		(rs_inst_valid_in 		),		//asserted when IF is dispatching instruction
		.inst_in			(rs_inst_in),
		.pc_in				(rs_pc_in),
		.npc_in				(rs_npc_in),
		.op_type_in			(rs_op_type_in			), 		//from decoder						
		.op1_prn_in			(rs_op1_prn_in			), 		//from rat					
		.op2_prn_in			(rs_op2_prn_in			), 		//from rat	
		.use_op1_prn_in		(rs_use_op1_prn_in	),
        .use_op2_prn_in		(rs_use_op2_prn_in	),
		.dest_prn_in		(rs_dest_prn_in		),		//from prf free list
		.op1_select_in		(rs_op1_select_in		),		
		.op2_select_in		(rs_op2_select_in		),		
		.rd_mem_in			(rs_rd_mem_in			),			
		.wr_mem_in			(rs_wr_mem_in			),			
		.cond_branch_in		(rs_cond_branch_in		),		
		.uncond_branch_in	(rs_uncond_branch_in	),	 
		.halt_in			(rs_halt_in			),			 
		.illigal_in			(rs_illigal_in			),			
		.op1_ready_in		(rs_op1_ready_in		), 					//from prf valid bit
		.op2_ready_in		(rs_op2_ready_in		), 					//from prf valid bit		
		.rob_entry_in		(rs_ROB_num		),       //from tail of rob (*3)
		.fu_type_in	 		(rs_fu_type_in			),
		.imm_in	  	 		(rs_imm_in	   			),
		.rs_nuke			(nuke			),			//from controller
		//.mult_avail			(fu_mult_avail		),			//from controller
		.load_ready_in		(load_ready_in		),
		.miss_waiting_in	(fu_miss_waiting	),
		.dcache_hit			(Dcache_valid_out	),
		.cdb_valid 			(cdb_valid 			),
		.cdb_tag			(cdb_tag			),		
    	                                        
		.inst_valid_out		(rs_inst_valid_out	),    //asserted when rs is issuing inst
		.inst_out			(rs_inst_out		),
		.pc_out				(rs_pc_out			),
		.npc_out			(rs_npc_out			),
		.op_type_out		(rs_op_type_out		), 
		.op1_prn_out 		(rs_op1_prn_out 	),
		.op2_prn_out 		(rs_op2_prn_out 	),
		.dest_prn_out 		(rs_dest_prn_out 	),
		.op1_select_out		(rs_op1_select_out	),		
		.op2_select_out		(rs_op2_select_out	),	
		.rd_mem_out			(rs_rd_mem_out		),			
		.wr_mem_out			(rs_wr_mem_out		),			
		.cond_branch_out	(rs_cond_branch_out	),	
		.uncond_branch_out	(rs_uncond_branch_out),	
		.halt_out			(rs_halt_out		),			
		.illigal_out		(rs_illigal_out		),		
		.rob_entry_out		(rs_rob_entry_out	),
		.fu_type_out		(rs_fu_type_out		), 
		.imm_out    		(rs_imm_out    		),
		.rs_avail_cnt       (rs_avail_cnt		),
		.rs_full 			(rs_full 			)
	);



	prf prf_inst(
        .clock					(clk),
        .reset					(rst),
        
        .rrat_rename_table_in	(rrat_rename_table_out	),	
        .squash_en				(nuke					),
        
        .ROB_commit_valid		(ROB_commit_valid		),		
        .rob_old_prn_width_in	(rob_old_prn_width_in	),
        
        .dest_prn_width			(cdb_tag			),//dest. prf addr to write the value
        .CDB_dest_prf_value		(cdb_value			),//write corresponding value to prf
        .CDB_done				(cdb_valid			),
        
        .op1_prf_in				(rs_op1_prn_out		),//op1 prf addr to read the value
        .op2_prf_in				(rs_op2_prn_out		),//op2 prf addr to read the value
        .op1_value_out			(prf_op1_value_out	),
        .op2_value_out			(prf_op2_value_out	),
        
        .valid_list				(valid_list			),
		.prf_data_out			(prf_data_out		)
      );
	
	rrat rrat_inst(
		.clk					(clk					),          	   // the clock 							
		.rst					(rst					),            	   // reset signal	                
		.dest_arn_in			(rrat_dest_arn_in		),         // from RoB
		.inst_valid_in			(rrat_inst_valid_in		),         // commit
		.dest_prn_in			(rrat_dest_prn_in		),         // from RoB
		
		.rrat_rename_table_out	(rrat_rename_table_out	)       
	);



	ROB ROB_inst(
		//inputs
		.clock					(clk),
		.reset					(rst),
		////////input signals from ID stage     		
		.id_packet_in_2			(id_packet_in_2					),
		.id_packet_in_1			(id_packet_in_1					),
		.id_packet_in_0			(id_packet_in_0					),
		////////input signals from CDB          			
		.cdb_valid				(cdb_valid						),
		.cdb_value				(cdb_value						),
		.cdb_tag				(cdb_tag						),
		.cdb_rob				(cdb_rob						),
		.cdb_cond_branch		(cdb_cond_branch				),
		.cdb_uncond_branch		(cdb_uncond_branch				),
		////////input signals from FU       				
		.FU_branch_target_addr	(branch_target_addr_out 		),		
		.FU_branch_taken		(branch_taken_out       		),
		.FU_store_addr			(fu_store_address_mem_out		),
		.FU_store_data			({32'b0,fu_store_data_mem_out}	),
		.FU_store_en			(fu_store_en_out				),
		.FU_rob					(fu_store_rob_out				),
		.store_commit_valid     (store_commit_valid				),
		//outputs                                           	
		.ROB_num				(rs_ROB_num						),	//to RS
		.rob_hazard_num			(rob_avail_cnt					),  //to if
		.nuke					(nuke							),	//to all
		.error_status			(error_status					),
		.completed_insts		(completed_insts				),
		.ROB_packet_out_2		(ROB_packet_out_2				),	//
		.ROB_packet_out_1		(ROB_packet_out_1				),
		.ROB_packet_out_0		(ROB_packet_out_0				),
		.ROB_branch_out_2		(ROB_branch_out_2				),//to predictor
		.ROB_branch_out_1		(ROB_branch_out_1				),
		.ROB_branch_out_0       (ROB_branch_out_0       		),
		.load_ready				(load_ready_in					)
);








//////////////////////////////////////////////////
//                                              //
//           RS+RF/FU Pipeline Register         //
//                                              //
//////////////////////////////////////////////////


	reg [`N_WAY-1:0]	 				rf_fu_inst_valid		; 
	reg [32*(`N_WAY)-1:0]				rf_fu_inst				; 
	reg [32*(`N_WAY)-1:0]				rf_fu_pc				; 
	reg [32*(`N_WAY)-1:0]				rf_fu_npc				; 
	reg [5*(`N_WAY)-1:0] 				rf_fu_op_type			; 
	reg [32*(`N_WAY)-1:0]  				rf_fu_op1_val 			; 
	reg [32*(`N_WAY)-1:0]  				rf_fu_op2_val 			; 
	reg [(`PRF_WIDTH)*(`N_WAY)-1:0]  	rf_fu_dest_prn 			; 
	reg [2*`N_WAY-1:0]					rf_fu_op1_select		; 
	reg [4*`N_WAY-1:0]					rf_fu_op2_select		;
	reg [`N_WAY-1:0]					rf_fu_rd_mem			;
	reg [`N_WAY-1:0]					rf_fu_wr_mem			;
	reg [`N_WAY-1:0]					rf_fu_cond_branch		;
	reg [`N_WAY-1:0]					rf_fu_uncond_branch		;
	reg [`N_WAY-1:0]					rf_fu_halt				; 
	reg [`N_WAY-1:0]					rf_fu_illigal			; 
	reg [(`ROB_WIDTH)*(`N_WAY)-1:0] 	rf_fu_rob_entry			;
	reg [4*(`N_WAY)-1:0]			 	rf_fu_fu_type			;
	reg [(`IMM_WIDTH)*(`N_WAY)-1:0] 	rf_fu_imm				;
	reg [`RS_WIDTH:0] 					rf_fu_avail_cnt			;
	reg    	 							rf_fu_full 				;

	always_ff @(posedge clk) begin
		if (rst|nuke) begin				
			rf_fu_inst_valid		<= `SD 0;	
			rf_fu_inst				<= `SD 0;			
			rf_fu_pc				<= `SD 0;			
			rf_fu_npc				<= `SD 0;		
			rf_fu_op_type			<= `SD 0;	
			rf_fu_op1_val 			<= `SD 0;	
			rf_fu_op2_val 			<= `SD 0;	
			rf_fu_dest_prn 			<= `SD 0;		
			rf_fu_op1_select		<= `SD 0;	
			rf_fu_op2_select		<= `SD 0;
			rf_fu_rd_mem			<= `SD 0;
			rf_fu_wr_mem			<= `SD 0;
			rf_fu_cond_branch		<= `SD 0;
			rf_fu_uncond_branch		<= `SD 0;
			rf_fu_halt				<= `SD 0;	
			rf_fu_illigal			<= `SD 0;	
			rf_fu_rob_entry			<= `SD 0;
			rf_fu_fu_type			<= `SD 0;
			rf_fu_imm				<= `SD 0;
			rf_fu_avail_cnt			<= `SD 0;
			rf_fu_full 				<= `SD 0;
		end 
		else begin 
			rf_fu_inst_valid		<= `SD rs_inst_valid_out		;	
			rf_fu_inst				<= `SD rs_inst_out				;			
			rf_fu_pc				<= `SD rs_pc_out				;			
			rf_fu_npc				<= `SD rs_npc_out				;		
			rf_fu_op_type			<= `SD rs_op_type_out			;	
			rf_fu_op1_val 			<= `SD prf_op1_value_out		;	
			rf_fu_op2_val 			<= `SD prf_op2_value_out		;	
			rf_fu_dest_prn 			<= `SD rs_dest_prn_out 			;		
			rf_fu_op1_select		<= `SD rs_op1_select_out		;	
			rf_fu_op2_select		<= `SD rs_op2_select_out		;
			rf_fu_rd_mem			<= `SD rs_rd_mem_out			;
			rf_fu_wr_mem			<= `SD rs_wr_mem_out			;
			rf_fu_cond_branch		<= `SD rs_cond_branch_out		;
			rf_fu_uncond_branch		<= `SD rs_uncond_branch_out		;
			rf_fu_halt				<= `SD rs_halt_out				;	
			rf_fu_illigal			<= `SD rs_illigal_out			;	
			rf_fu_rob_entry			<= `SD rs_rob_entry_out			;
			rf_fu_fu_type			<= `SD rs_fu_type_out			;
			rf_fu_imm				<= `SD rs_imm_out				;
			rf_fu_avail_cnt			<= `SD rs_avail_cnt				;
			rf_fu_full 				<= `SD rs_full 					;
		end 
	end 	






//////////////////////////////////////////////////
//                                              //
//                  Stage4-7: FU                //
//                                              //
//////////////////////////////////////////////////

	//output of fu	
	wire 			 		fu_inst_valid_alu0_out		 ;
	wire [31:0]  			fu_result_alu0_out			 ;
	wire [`PRF_WIDTH-1:0] 	fu_dest_prn_alu0_out		 ;
	wire [`ROB_WIDTH-1:0] 	fu_rob_entry_alu0_out		 ;
	wire [31:0]				fu_inst_alu0_out			 ;
	wire [31:0]				fu_pc_alu0_out				 ;    

	wire 			 		fu_inst_valid_alu1_out		 ;
	wire [31:0]  			fu_result_alu1_out			 ;
	wire [`PRF_WIDTH-1:0] 	fu_dest_prn_alu1_out		 ;
	wire [`ROB_WIDTH-1:0] 	fu_rob_entry_alu1_out		 ;
	wire [31:0]				fu_inst_alu1_out			 ;
	wire [31:0]				fu_pc_alu1_out				 ;    

	wire 			 		fu_inst_valid_alu2_out		 ;
	wire [31:0]  			fu_result_alu2_out			 ;
	wire [`PRF_WIDTH-1:0] 	fu_dest_prn_alu2_out		 ;
	wire [`ROB_WIDTH-1:0] 	fu_rob_entry_alu2_out		 ;
	wire [31:0]				fu_inst_alu2_out			 ;
	wire [31:0]				fu_pc_alu2_out				 ;    

	wire 			 		fu_inst_valid_mul_out		 ;
	wire [31:0]  			fu_result_mul_out			 ;
	wire [`PRF_WIDTH-1:0] 	fu_dest_prn_mul_out		     ;
	wire [`ROB_WIDTH-1:0] 	fu_rob_entry_mul_out		 ;
	wire [31:0]				fu_inst_mul_out				 ;
	wire [31:0]				fu_pc_mul_out				 ;


	wire 			 		fu_inst_valid_bcond_out	     ;
	wire [31:0]  			fu_link_addr_out			 ;
	wire [`PRF_WIDTH-1:0] 	fu_dest_prn_bcond_out		 ;
	wire [`ROB_WIDTH-1:0] 	fu_rob_entry_bcond_out		 ;
	wire [31:0] 			fu_branch_target_addr_out	 ;
	wire 		  			fu_branch_taken_out		     ;
	wire				    fu_cond_branch_out			 ;	//this is a branch/jmp inst
	wire 					fu_uncond_branch_out		 ;
	wire [31:0]				fu_inst_bcond_out			 ;
	wire [31:0]				fu_pc_bcond_out				 ;
//	wire 					fu_mult_avail				 ;
	                                                     
	wire 			 		fu_inst_valid_mem_out		 ;
	wire [31:0]  			fu_load_data_out			 ;
	wire [`PRF_WIDTH-1:0] 	fu_dest_prn_mem_out		     ;
	wire [`ROB_WIDTH-1:0] 	fu_rob_entry_mem_out		 ;
	wire					fu_rd_mem_out				 ;	                                    
	wire					fu_wr_mem_out				 ;	                                    
	wire [31:0]				fu_inst_mem_out				 ;
	wire [31:0]				fu_pc_mem_out				 ;


	wire [31:0]				fu_load_address_mem_out		 ;	//load info to dcache control		
	wire [2:0]				fu_load_size_out			 ;	//load info to dcache control
	wire					fu_load_en_out				 ;	//load info to dcache control
                                                         

	//dcache ctrl i/o
    wire 	[63:0]			st_rd_data;
    wire 					st_rd_valid;
    wire 	[63:0] 			ld_rd_data;
    wire 					ld_rd_valid;
    wire	[`XLEN-1:0] 	Dcache_data_out;
    wire	[4:0] 			st_rd_idx;
    wire	[7:0] 			st_rd_tag;
    wire	[4:0] 			ld_rd_idx;
    wire	[7:0] 			ld_rd_tag;
    wire	[4:0] 			st_wr_idx;
    wire	[7:0] 			st_wr_tag;
    wire	[63:0] 			st_wr_data;
    wire					st_wr_en;
    wire	[4:0] 			wr_idx;
    wire	[7:0] 			wr_tag;
	wire	[63:0] 			wr_data; 
	wire					wr_en;
 	wire 	[4:0] 			ld_wr_idx;
 	wire 	[7:0] 			ld_wr_tag;
 	wire 	[63:0] 			ld_wr_data; 
 	wire					ld_wr_en;





/**********************randon cache miss/hit ****************************
	wire test_signal_hit;
	wire [31:0]test_signal_data;
	reg [31:0] cnt;

	always@(posedge clk) begin
		if(rst)
			cnt <= 0;
		else if(fu_miss_waiting)
			cnt <= cnt + 1;
		else
			cnt <= 0;
	end

	assign test_signal_hit 	= fu_load_en_out&!fu_miss_waiting ? $urandom_range(0,1) : cnt==9;
	assign test_signal_data = test_signal_hit ? fu_pc_mem_out : 0;

****************************************************/



	fu_top fu_top_inst(
		.clk					(clk						),
		.rst					(rst|nuke					),
		.inst_valid_in			(rf_fu_inst_valid			), 
 		.inst_in				(rf_fu_inst					),				// from decoder
 		.pc_in					(rf_fu_pc					),				// from decoder
 		.npc_in					(rf_fu_npc					),				// from decoder
		.op_type_in				(rf_fu_op_type				), 
		.op1_val_in				(rf_fu_op1_val 		 		),
		.op2_val_in				(rf_fu_op2_val 				),
   		.op1_select_in			(rf_fu_op1_select			),		
		.op2_select_in			(rf_fu_op2_select			),	
		.rd_mem_in				(rf_fu_rd_mem				),			
		.wr_mem_in				(rf_fu_wr_mem				),			
		.cond_branch_in			(rf_fu_cond_branch			),	
		.uncond_branch_in		(rf_fu_uncond_branch		),	
		.halt_in				(rf_fu_halt					),			
		.illigal_in				(rf_fu_illigal				),		
		.rob_entry_in			(rf_fu_rob_entry			),		
		.dest_prn_in			(rf_fu_dest_prn				),
		.fu_type_in				(rf_fu_fu_type				), 	
		.imm_in					(rf_fu_imm					), 		 
		.load_data_in			(Dcache_data_out		    ),		
		.load_data_valid_in		(Dcache_valid_out			),	
		//.load_data_in			(test_signal_data),		
		//.load_data_valid_in		(test_signal_hit),	

		//to cdb
		.inst_valid_alu0_out	(fu_inst_valid_alu0_out		),    
		.result_alu0_out		(fu_result_alu0_out			),
		.dest_prn_alu0_out		(fu_dest_prn_alu0_out		),
		.rob_entry_alu0_out		(fu_rob_entry_alu0_out		),
		.inst_alu0_out			(fu_inst_alu0_out			),
		.pc_alu0_out			(fu_pc_alu0_out				),  

		.inst_valid_alu1_out	(fu_inst_valid_alu1_out		),    
		.result_alu1_out		(fu_result_alu1_out			),
		.dest_prn_alu1_out		(fu_dest_prn_alu1_out		),
		.rob_entry_alu1_out		(fu_rob_entry_alu1_out		),
		.inst_alu1_out			(fu_inst_alu1_out			),
		.pc_alu1_out			(fu_pc_alu1_out				),       

		.inst_valid_alu2_out	(fu_inst_valid_alu2_out		),    
		.result_alu2_out		(fu_result_alu2_out			),
		.dest_prn_alu2_out		(fu_dest_prn_alu2_out		),
		.rob_entry_alu2_out		(fu_rob_entry_alu2_out		),
		.inst_alu2_out			(fu_inst_alu2_out			),
		.pc_alu2_out			(fu_pc_alu2_out				), 
                                                        
		.inst_valid_mul_out		(fu_inst_valid_mul_out		),    
		.result_mul_out			(fu_result_mul_out			),
		.dest_prn_mul_out		(fu_dest_prn_mul_out		),
		.rob_entry_mul_out		(fu_rob_entry_mul_out		),
   		.inst_mul_out			(fu_inst_mul_out			),
		.pc_mul_out				(fu_pc_mul_out				),          

		.inst_valid_bcond_out	(fu_inst_valid_bcond_out	),    
		.link_addr_out			(fu_link_addr_out			),
		.dest_prn_bcond_out		(fu_dest_prn_bcond_out		),
		.rob_entry_bcond_out	(fu_rob_entry_bcond_out		),
		.branch_target_addr_out	(fu_branch_target_addr_out	),		
		.branch_taken_out		(fu_branch_taken_out		),
		.cond_branch_out		(fu_cond_branch_out			),	
		.uncond_branch_out		(fu_uncond_branch_out		),
		.inst_bcond_out			(fu_inst_bcond_out			),
		.pc_bcond_out			(fu_pc_bcond_out			),		
		//.mult_avail				(fu_mult_avail				),
		
		.inst_valid_mem_out	 	(fu_inst_valid_mem_out		),    
		.load_data_out		 	(fu_load_data_out			),
		.dest_prn_mem_out	 	(fu_dest_prn_mem_out		),
		.rob_entry_mem_out	 	(fu_rob_entry_mem_out		),
  		.rd_mem_out				(fu_rd_mem_out				),
		.wr_mem_out				(fu_wr_mem_out				),
		.inst_mem_out		 	(fu_inst_mem_out			),
		.pc_mem_out				(fu_pc_mem_out				), 

		.store_address_mem_out	(fu_store_address_mem_out	),	//store info to rob
		.store_data_mem_out		(fu_store_data_mem_out		),  //store info to rob
		.store_rob_out			(fu_store_rob_out			),	//store info to rob
		.store_en_out			(fu_store_en_out			),	//store info to rob		
		.load_address_mem_out	(fu_load_address_mem_out	),	//load info to dcache control		
		.load_size_out			(fu_load_size_out			),	//load info to dcache control
		.load_en_out			(fu_load_en_out				),	//load info to dcache control	

		.miss_waiting			(fu_miss_waiting			)		
	);


	dcache_control dcache_control_0(
		//inputs
		.clock(clk),
	   	.reset(rst),
		////////inputs from rob, store instruction
		.ROB_packet_out_2	(ROB_packet_out_2),
		.ROB_packet_out_1	(ROB_packet_out_1),
		.ROB_packet_out_0	(ROB_packet_out_0),
		////////inputs coming from fu, load instruction
	   	.fu_load_addr		(fu_load_address_mem_out	),
	   	.fu_load_en			(fu_load_en_out				),
	   	.fu_load_size		(fu_load_size_out			),
		////////inputs from icache controller
	   	.Dmem2proc_idx		(Dmem2proc_idx		),
	   	.Dmem2proc_tag		(Dmem2proc_tag		),
	  	.Dmem2proc_data		(Dmem2proc_data		),
	   	.Dmem2proc_valid	(Dmem2proc_valid	),
		////////inputs from dcache
	    .st_rd_data			(st_rd_data),
	    .st_rd_valid		(st_rd_valid),
  		.ld_rd_data			(ld_rd_data),
		.ld_rd_valid		(ld_rd_valid),
	   	//outputs
		////////outputs to ROB
		.store_commit_valid	(store_commit_valid),
		////////outputs to fu
	    .Dcache_data_out	(Dcache_data_out),
	    .Dcache_valid_out	(Dcache_valid_out),
		////////outputs to icache ctrl
		.load_store			(load_store),
	   	.proc2Dmem_command	(proc2Dmem_command),
	   	.proc2Dmem_addr		(proc2Dmem_addr),
		.proc2Dmem_size		(proc2Dmem_size),
		.proc2Dmem_data		(proc2Dmem_data),
		////////outputs to the Dcache
		//store read
	    .st_rd_idx			(st_rd_idx),
	    .st_rd_tag			(st_rd_tag),
		//load read
	    .ld_rd_idx			(ld_rd_idx),
	    .ld_rd_tag			(ld_rd_tag),
		//store write
	    .st_wr_idx			(st_wr_idx),
	    .st_wr_tag			(st_wr_tag),
	    .st_wr_data			(st_wr_data),
	    .st_wr_en			(st_wr_en),
		//load write
	    .wr_idx				(ld_wr_idx),
	    .wr_tag				(ld_wr_tag),
		.wr_data			(ld_wr_data), 
		.wr_en				(ld_wr_en)
	);
	
	dcache_mem dcache_mem_0(
		//inputs
	    .clock(clk), 
		.reset(rst), 
	////////write port
		//store write
	    .st_wr_idx(st_wr_idx),
	    .st_wr_tag(st_wr_tag),
	    .st_wr_data(st_wr_data),
	    .st_wr_en(st_wr_en),
		//load write
	    .ld_wr_idx(ld_wr_idx),
	    .ld_wr_tag(ld_wr_tag),
		.ld_wr_data(ld_wr_data), 
		.ld_wr_en(ld_wr_en),
	////////read port
		//store read
	    .st_rd_idx(st_rd_idx),
	    .st_rd_tag(st_rd_tag),
		//load read
	    .ld_rd_idx(ld_rd_idx),
	    .ld_rd_tag(ld_rd_tag),
		//outputs
	    .st_rd_data(st_rd_data),
	    .st_rd_valid(st_rd_valid),
	    .ld_rd_data(ld_rd_data),
		.ld_rd_valid(ld_rd_valid)
	);







//////////////////////////////////////////////////
//                                              //
//           FU/CDB Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	reg 			 		fu_cdb_inst_valid_alu0		;
	reg [31:0]  			fu_cdb_result_alu0			;
	reg [`PRF_WIDTH-1:0] 	fu_cdb_dest_prn_alu0		;
	reg [`ROB_WIDTH-1:0] 	fu_cdb_rob_entry_alu0		;
	reg [31:0] 				fu_cdb_inst_alu0			;
	reg [31:0] 				fu_cdb_pc_alu0				;
	                                                
	reg 			 		fu_cdb_inst_valid_alu1		;
	reg [31:0]  			fu_cdb_result_alu1			;
	reg [`PRF_WIDTH-1:0] 	fu_cdb_dest_prn_alu1		;
	reg [`ROB_WIDTH-1:0] 	fu_cdb_rob_entry_alu1		;
	reg [31:0] 				fu_cdb_inst_alu1			;
	reg [31:0] 				fu_cdb_pc_alu1				;


	reg 			 		fu_cdb_inst_valid_alu2		;
	reg [31:0]  			fu_cdb_result_alu2			;
	reg [`PRF_WIDTH-1:0] 	fu_cdb_dest_prn_alu2		;
	reg [`ROB_WIDTH-1:0] 	fu_cdb_rob_entry_alu2		;
	reg [31:0] 				fu_cdb_inst_alu2			;
	reg [31:0] 				fu_cdb_pc_alu2				;


	reg 			 		fu_cdb_inst_valid_mul		;
	reg [31:0]  			fu_cdb_result_mul			;
	reg [`PRF_WIDTH-1:0] 	fu_cdb_dest_prn_mul		    ;
	reg [`ROB_WIDTH-1:0] 	fu_cdb_rob_entry_mul		;
	reg [31:0] 				fu_cdb_inst_mul				;
	reg [31:0] 				fu_cdb_pc_mul				;
	

	reg 			 		fu_cdb_inst_valid_mem	 	;
	reg [31:0]				fu_cdb_load_data		 	;
	reg [`PRF_WIDTH-1:0]	fu_cdb_dest_prn_mem		 	;
	reg [`ROB_WIDTH-1:0]   	fu_cdb_rob_entry_mem	 	;	                                    
	reg						fu_cdb_rd_mem			 	;	                                    
 	reg 	 				fu_cdb_wr_mem			 	;
	reg [31:0] 				fu_cdb_inst_mem			 	;
    reg [31:0]              fu_cdb_pc_mem			 	;

	reg 			 		fu_cdb_inst_valid_bcond	    ;
	reg [31:0]  			fu_cdb_link_addr			;
	reg [`PRF_WIDTH-1:0] 	fu_cdb_dest_prn_bcond		;
	reg [`ROB_WIDTH-1:0] 	fu_cdb_rob_entry_bcond		;
	reg [31:0] 				fu_cdb_branch_target_addr	;
	reg 		  			fu_cdb_branch_taken		    ;
	reg				  	  	fu_cdb_cond_branch			;	//this is a branch/jmp inst
	reg 					fu_cdb_uncond_branch		;
	reg [31:0] 				fu_cdb_inst_bcond			;
	reg [31:0] 				fu_cdb_pc_bcond				;


	always_ff @(posedge clk) begin
		if (rst|nuke) begin
			fu_cdb_inst_valid_alu0		  <= `SD 0;
			fu_cdb_result_alu0			  <= `SD 0;
			fu_cdb_dest_prn_alu0		  <= `SD 0;
			fu_cdb_rob_entry_alu0		  <= `SD 0;
			fu_cdb_inst_alu0		 	  <= `SD 0;
			fu_cdb_pc_alu0			 	  <= `SD 0;
			                        
			fu_cdb_inst_valid_alu1		  <= `SD 0;
			fu_cdb_result_alu1			  <= `SD 0;
			fu_cdb_dest_prn_alu1		  <= `SD 0;
			fu_cdb_rob_entry_alu1		  <= `SD 0;
			fu_cdb_inst_alu1		 	  <= `SD 0;
			fu_cdb_pc_alu1			 	  <= `SD 0;

			fu_cdb_inst_valid_alu2		  <= `SD 0;
			fu_cdb_result_alu2			  <= `SD 0;
			fu_cdb_dest_prn_alu2		  <= `SD 0;
			fu_cdb_rob_entry_alu2		  <= `SD 0;
			fu_cdb_inst_alu2		 	  <= `SD 0;
			fu_cdb_pc_alu2			 	  <= `SD 0;	

			fu_cdb_inst_valid_mul		  <= `SD 0;
			fu_cdb_result_mul			  <= `SD 0;
			fu_cdb_dest_prn_mul		      <= `SD 0;
			fu_cdb_rob_entry_mul		  <= `SD 0;
			fu_cdb_inst_mul			 	  <= `SD 0;
			fu_cdb_pc_mul			 	  <= `SD 0;		

			fu_cdb_inst_valid_mem	 	  <= `SD 0;
			fu_cdb_load_data		 	  <= `SD 0;
			fu_cdb_dest_prn_mem		 	  <= `SD 0;
			fu_cdb_rob_entry_mem	 	  <= `SD 0;
			fu_cdb_rd_mem			 	  <= `SD 0;
			fu_cdb_wr_mem			 	  <= `SD 0;
			fu_cdb_inst_mem			 	  <= `SD 0;
			fu_cdb_pc_mem			 	  <= `SD 0;

			fu_cdb_inst_valid_bcond	      <= `SD 0;
			fu_cdb_link_addr			  <= `SD 0;
			fu_cdb_dest_prn_bcond		  <= `SD 0;
			fu_cdb_rob_entry_bcond		  <= `SD 0;
			fu_cdb_branch_target_addr	  <= `SD 0;
			fu_cdb_branch_taken		      <= `SD 0;
			fu_cdb_cond_branch			  <= `SD 0;
			fu_cdb_uncond_branch		  <= `SD 0;
			fu_cdb_inst_bcond		 	  <= `SD 0;
			fu_cdb_pc_bcond			 	  <= `SD 0;
		end 
		else begin 
			fu_cdb_inst_valid_alu0		  <= `SD fu_inst_valid_alu0_out		  ;
			fu_cdb_result_alu0			  <= `SD fu_result_alu0_out			  ;
			fu_cdb_dest_prn_alu0		  <= `SD fu_dest_prn_alu0_out		  ;
			fu_cdb_rob_entry_alu0		  <= `SD fu_rob_entry_alu0_out		  ;
			fu_cdb_inst_alu0		 	  <= `SD fu_inst_alu0_out			  ;
			fu_cdb_pc_alu0			 	  <= `SD fu_pc_alu0_out			      ;
			                        
			fu_cdb_inst_valid_alu1		  <= `SD fu_inst_valid_alu1_out		  ;
			fu_cdb_result_alu1			  <= `SD fu_result_alu1_out			  ;
			fu_cdb_dest_prn_alu1		  <= `SD fu_dest_prn_alu1_out		  ;
			fu_cdb_rob_entry_alu1		  <= `SD fu_rob_entry_alu1_out		  ;
			fu_cdb_inst_alu1		 	  <= `SD fu_inst_alu1_out			  ;
			fu_cdb_pc_alu1			 	  <= `SD fu_pc_alu1_out			      ;
	

			fu_cdb_inst_valid_alu2		  <= `SD fu_inst_valid_alu2_out		  ;
			fu_cdb_result_alu2			  <= `SD fu_result_alu2_out			  ;
			fu_cdb_dest_prn_alu2		  <= `SD fu_dest_prn_alu2_out		  ;
			fu_cdb_rob_entry_alu2		  <= `SD fu_rob_entry_alu2_out		  ;
			fu_cdb_inst_alu2		 	  <= `SD fu_inst_alu2_out			  ;
			fu_cdb_pc_alu2			 	  <= `SD fu_pc_alu2_out			      ;


			fu_cdb_inst_valid_mul		  <= `SD fu_inst_valid_mul_out		  ;
			fu_cdb_result_mul			  <= `SD fu_result_mul_out			  ;
			fu_cdb_dest_prn_mul		      <= `SD fu_dest_prn_mul_out		  ;
			fu_cdb_rob_entry_mul		  <= `SD fu_rob_entry_mul_out		  ;
			fu_cdb_inst_mul			 	  <= `SD fu_inst_mul_out			  ;
			fu_cdb_pc_mul			 	  <= `SD fu_pc_mul_out			      ;


			fu_cdb_inst_valid_mem	 	  <= `SD fu_inst_valid_mem_out		  ;  
			fu_cdb_load_data		 	  <= `SD fu_load_data_out			  ;
			fu_cdb_dest_prn_mem		 	  <= `SD fu_dest_prn_mem_out		  ;
			fu_cdb_rob_entry_mem	 	  <= `SD fu_rob_entry_mem_out		  ;
			fu_cdb_rd_mem			 	  <= `SD fu_rd_mem_out				  ;
			fu_cdb_wr_mem			 	  <= `SD fu_wr_mem_out				  ;
			fu_cdb_inst_mem			 	  <= `SD fu_inst_mem_out			  ;
			fu_cdb_pc_mem			 	  <= `SD fu_pc_mem_out				  ;

			                            
			fu_cdb_inst_valid_bcond	      <= `SD fu_inst_valid_bcond_out	  ;
			fu_cdb_link_addr			  <= `SD fu_link_addr_out			  ;
			fu_cdb_dest_prn_bcond		  <= `SD fu_dest_prn_bcond_out		  ;
			fu_cdb_rob_entry_bcond		  <= `SD fu_rob_entry_bcond_out		  ;
			fu_cdb_branch_target_addr	  <= `SD fu_branch_target_addr_out	  ;
			fu_cdb_branch_taken		      <= `SD fu_branch_taken_out		  ;
			fu_cdb_cond_branch			  <= `SD fu_cond_branch_out			  ;
			fu_cdb_uncond_branch		  <= `SD fu_uncond_branch_out		  ;
			fu_cdb_inst_bcond		 	  <= `SD fu_inst_bcond_out			  ;
			fu_cdb_pc_bcond			 	  <= `SD fu_pc_bcond_out		      ;

		end 
	end 	





//////////////////////////////////////////////////
//                                              //
//                  Stage8: CDB                 //
//                                              //
//////////////////////////////////////////////////

	wire [(`N_WAY)*32-1:0] 	cdb_inst;
	wire [(`N_WAY)*32-1:0] 	cdb_pc;


	cdb cdb_inst_0(
		.inst_valid_alu0_in		(fu_cdb_inst_valid_alu0		  ),    
		.result_alu0_in			(fu_cdb_result_alu0			  ),
		.dest_prn_alu0_in		(fu_cdb_dest_prn_alu0		  ),
		.rob_entry_alu0_in		(fu_cdb_rob_entry_alu0		  ),
		.inst_alu0_in			(fu_cdb_inst_alu0			  ),
		.pc_alu0_in				(fu_cdb_pc_alu0				  ),  
	
		.inst_valid_alu1_in		(fu_cdb_inst_valid_alu1		  ),    
		.result_alu1_in			(fu_cdb_result_alu1			  ),
		.dest_prn_alu1_in		(fu_cdb_dest_prn_alu1		  ),
		.rob_entry_alu1_in		(fu_cdb_rob_entry_alu1		  ),
		.inst_alu1_in			(fu_cdb_inst_alu1			  ),
		.pc_alu1_in				(fu_cdb_pc_alu1				  ),  

		.inst_valid_alu2_in		(fu_cdb_inst_valid_alu2		  ),    
		.result_alu2_in			(fu_cdb_result_alu2			  ),
		.dest_prn_alu2_in		(fu_cdb_dest_prn_alu2		  ),
		.rob_entry_alu2_in		(fu_cdb_rob_entry_alu2		  ),
		.inst_alu2_in			(fu_cdb_inst_alu2			  ),
		.pc_alu2_in				(fu_cdb_pc_alu2				  ),  		
	                                                           
		.inst_valid_mul_in		(fu_cdb_inst_valid_mul		  ),    
		.result_mul_in			(fu_cdb_result_mul			  ),
		.dest_prn_mul_in		(fu_cdb_dest_prn_mul		  ),
		.rob_entry_mul_in		(fu_cdb_rob_entry_mul		  ),
		.inst_mul_in			(fu_cdb_inst_mul			  ),
		.pc_mul_in				(fu_cdb_pc_mul				  ),  
	                                                         
		.inst_valid_mem_in		(fu_cdb_inst_valid_mem	 	  ),    
		.result_mem_in			(fu_cdb_load_data		 	  ),
		.dest_prn_mem_in		(fu_cdb_dest_prn_mem		  ),
		.rob_entry_mem_in		(fu_cdb_rob_entry_mem	 	  ),
		.rd_mem_in				(fu_cdb_rd_mem			 	  ),
		.wr_mem_in				(fu_cdb_wr_mem			 	  ),
		.inst_mem_in			(fu_cdb_inst_mem		 	  ),
		.pc_mem_in				(fu_cdb_pc_mem			 	  ),  	

		.inst_valid_bcond_in	(fu_cdb_inst_valid_bcond	  ),    
		.link_addr_in			(fu_cdb_link_addr			  ),
		.dest_prn_bcond_in		(fu_cdb_dest_prn_bcond		  ),
		.rob_entry_bcond_in		(fu_cdb_rob_entry_bcond		  ),
		.cond_branch_in			(fu_cdb_cond_branch			  ),	//this is a branch/jmp inst
		.uncond_branch_in		(fu_cdb_uncond_branch		  ),	//this is a branch/jmp inst
     	.inst_bcond_in			(fu_cdb_inst_bcond			  ),
		.pc_bcond_in			(fu_cdb_pc_bcond			  ),          

		.cdb_valid				(cdb_valid				),
		.cdb_value				(cdb_value				),
		.cdb_tag				(cdb_tag				),
		.cdb_rob				(cdb_rob				),
		.cdb_cond_branch		(cdb_cond_branch		),
		.cdb_uncond_branch		(cdb_uncond_branch		),
		.cdb_rd_mem				(cdb_rd_mem				),
		.cdb_wr_mem	            (cdb_wr_mem	            ),
		.cdb_inst	            (cdb_inst	            ),
		.cdb_pc		            (cdb_pc		            )
	);

	assign branch_target_addr_out 	= fu_cdb_branch_target_addr	;	
    assign branch_taken_out       	= fu_cdb_branch_taken    	;

	



	//debug ports
	assign rs_fu_PC_2			= rf_fu_pc[2*32+:32];
	assign rs_fu_IR_2			= rf_fu_inst[2*32+:32]; 
	assign rs_fu_valid_inst_2	= rf_fu_inst_valid[2];  	
	assign rs_fu_PC_1			= rf_fu_pc[1*32+:32];    
	assign rs_fu_IR_1			= rf_fu_inst[1*32+:32];  
	assign rs_fu_valid_inst_1	= rf_fu_inst_valid[1];   	
	assign rs_fu_PC_0			= rf_fu_pc[0*32+:32];    
	assign rs_fu_IR_0			= rf_fu_inst[0*32+:32];  	
	assign rs_fu_valid_inst_0	= rf_fu_inst_valid[0];   	

	assign fu_cdb_PC_2			= cdb_pc[2*32+:32];
	assign fu_cdb_IR_2			= cdb_inst[2*32+:32]; 
	assign fu_cdb_valid_inst_2	= cdb_valid[2];  	
	assign fu_cdb_PC_1			= cdb_pc[1*32+:32];    
	assign fu_cdb_IR_1			= cdb_inst[1*32+:32];  
	assign fu_cdb_valid_inst_1	= cdb_valid[1];   	
	assign fu_cdb_PC_0			= cdb_pc[0*32+:32];    
	assign fu_cdb_IR_0			= cdb_inst[0*32+:32];  	
	assign fu_cdb_valid_inst_0	= cdb_valid[0]; 



	assign dctrl_load_data_in		= 0;			 
	assign dctrl_load_data_valid_in	= 0; 


endmodule

//`default_nettype wire
