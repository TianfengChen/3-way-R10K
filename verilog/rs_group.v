`timescale 1ns/100ps

module rs_group(
	input        						clk,          		// the clock 							
	input        						rst,          		// reset signal			
	input [`RS_SIZE-1:0]    			rs1_load,			// load inst into RS
	input [`RS_SIZE-1:0] 				rs1_use_en,			// send signal to FU
	input [32*(`N_WAY)-1:0] 			inst_in,			// from decoder
	input [32*(`N_WAY)-1:0] 			pc_in,				// from decoder
	input [32*(`N_WAY)-1:0] 			npc_in,				// from decoder
	input [5*(`N_WAY)-1:0] 				op_type_in,			// from decoder
	input [(`PRF_WIDTH)*(`N_WAY)-1:0] 	op1_prn_in,     	// from rat 
	input [(`PRF_WIDTH)*(`N_WAY)-1:0] 	op2_prn_in,     	// from rat
	input [`N_WAY-1:0]					use_op1_prn_in,	//  
	input [`N_WAY-1:0]					use_op2_prn_in,	// 
	input [(`PRF_WIDTH)*(`N_WAY)-1:0] 	dest_prn_in,    	// from decoder
	input [2*`N_WAY-1:0]				op1_select_in,
	input [4*`N_WAY-1:0]				op2_select_in,
	input [`N_WAY-1:0]					rd_mem_in,
	input [`N_WAY-1:0]					wr_mem_in,
	input [`N_WAY-1:0]					cond_branch_in,
	input [`N_WAY-1:0]					uncond_branch_in,
	input [`N_WAY-1:0]					halt_in,
	input [`N_WAY-1:0]					illigal_in,
	input [(`ROB_WIDTH)*(`N_WAY)-1:0]   rob_entry_in,		// from the tail of rob
	input [`N_WAY-1:0]					op1_ready_in,		// from PRF valid bit 
	input [`N_WAY-1:0]					op2_ready_in,		// from PRF valid bit 
	input [4*(`N_WAY)-1:0]				fu_type_in,			// from decoder, does this inst use alu, mul, mem or bcond?
	input [(`IMM_WIDTH)*(`N_WAY)-1:0]  	imm_in,				// from decoder, imm value
	input [2*(`RS_SIZE)-1:0]			dispatch_select_way,// allocate the rs entry
	input [(`RS_SIZE)*(`N_WAY)-1:0]		issue_select,		// issue gnt_bus 
	input [`ROB_SIZE-1:0]  				load_ready_in,			
	input [`N_WAY-1:0]					cdb_valid,
	input [(`PRF_WIDTH)*(`N_WAY)-1:0]	cdb_tag,

	output [`RS_SIZE-1:0]  				rs1_wake_up_alu, 	// This RS is in use and ready to go to EX 
	output [`RS_SIZE-1:0]  				rs1_wake_up_mul, 	// This RS is in use and ready to go to EX 
	output [`RS_SIZE-1:0]  				rs1_wake_up_mem, 	// This RS is in use and ready to go to EX 
	output [`RS_SIZE-1:0]  				rs1_wake_up_bcond, 	// This RS is in use and ready to go to EX 
	output [`RS_SIZE-1:0]  				rs1_avail,     		// This RS is available to be dispatched to 
	output [32*(`N_WAY)-1:0]			rs1_inst_out,    	// feed to alu
	output [32*(`N_WAY)-1:0]			rs1_pc_out,    		// feed to alu
	output [32*(`N_WAY)-1:0]			rs1_npc_out,    	// feed to alu
	output [5*(`N_WAY)-1:0]				rs1_op_type_out,    // feed to alu
	output [(`PRF_WIDTH)*(`N_WAY)-1:0] 	rs1_op1_prn_out,   	//  
	output [(`PRF_WIDTH)*(`N_WAY)-1:0] 	rs1_op2_prn_out,   	//  
	output [(`PRF_WIDTH)*(`N_WAY)-1:0] 	rs1_dest_prn_out,   // 
   	output [2*`N_WAY-1:0]				rs1_op1_select_out,		
	output [4*`N_WAY-1:0]				rs1_op2_select_out,	
	output [`N_WAY-1:0]					rs1_rd_mem_out,			
	output [`N_WAY-1:0]					rs1_wr_mem_out,			
	output [`N_WAY-1:0]					rs1_cond_branch_out,	
	output [`N_WAY-1:0]					rs1_uncond_branch_out,	
	output [`N_WAY-1:0]					rs1_halt_out,			
	output [`N_WAY-1:0]					rs1_illigal_out,		
	output [(`ROB_WIDTH)*(`N_WAY)-1:0] 	rs1_rob_entry_out, 	//  
	output [4*(`N_WAY)-1:0]			 	rs1_fu_type_out, 	//  
	output [(`IMM_WIDTH)*(`N_WAY)-1:0] 	rs1_imm_out, 		//  
	output [`N_WAY-1:0] 				inst_issue_valid 	//  
);	


	wire [31:0]							inst_in_way		 	[0:`N_WAY-1];
	wire [31:0]							pc_in_way		 	[0:`N_WAY-1];
	wire [31:0]							npc_in_way		 	[0:`N_WAY-1];
	wire [4:0] 							op_type_in_way   	[0:`N_WAY-1];			//op type*3
	wire [`PRF_WIDTH-1:0] 				op1_prn_in_way   	[0:`N_WAY-1];			//op1 prn*3
	wire [`PRF_WIDTH-1:0] 				op2_prn_in_way   	[0:`N_WAY-1];
	wire [`PRF_WIDTH-1:0] 				dest_prn_in_way	 	[0:`N_WAY-1];
	wire [1:0]							op1_select_in_way	[0:`N_WAY-1];
	wire [3:0]							op2_select_in_way	[0:`N_WAY-1];
	wire [`ROB_WIDTH-1:0] 				rob_entry_in_way 	[0:`N_WAY-1];
	wire [3:0]			 				fu_type_in_way 	 	[0:`N_WAY-1];
	wire [`IMM_WIDTH-1:0]			 	imm_in_way	 	 	[0:`N_WAY-1];
	wire [`RS1_DATABUS_IN_WIDTH-1:0] 	rs1_databus_in_way 	[0:`N_WAY-1];	//databus*3
	wire [`RS1_DATABUS_IN_WIDTH-1:0] 	rs1_databus 		[0:`RS_SIZE-1];
	wire [1:0] 							mux_select_way 		[0:`RS_SIZE-1];						//each rs1 chooses a superscalar lane out of three lanes

	wire [(`RS1_DATABUS_OUT_WIDTH)*(`RS_SIZE)-1:0] 	i_data; //output of rs1 databus x16
	wire [`RS1_DATABUS_OUT_WIDTH-1:0]		 		i_data_tmp [0:`RS_SIZE-1]; 
	wire [`RS1_DATABUS_OUT_WIDTH-1:0] 				o_data_0;
	wire [`RS1_DATABUS_OUT_WIDTH-1:0] 				o_data_1;
	wire [`RS1_DATABUS_OUT_WIDTH-1:0] 				o_data_2;

	wire [31:0] 		  rs1_inst_out_tmp			[0:`RS_SIZE-1]; 
	wire [31:0] 		  rs1_pc_out_tmp			[0:`RS_SIZE-1]; 
	wire [31:0] 		  rs1_npc_out_tmp			[0:`RS_SIZE-1]; 
	wire [4:0] 			  rs1_op_type_out_tmp		[0:`RS_SIZE-1]; 
    wire [`PRF_WIDTH-1:0] rs1_op1_prn_out_tmp		[0:`RS_SIZE-1]; 
    wire [`PRF_WIDTH-1:0] rs1_op2_prn_out_tmp		[0:`RS_SIZE-1]; 
    wire [`PRF_WIDTH-1:0] rs1_dest_prn_out_tmp		[0:`RS_SIZE-1];
   	wire [1:0]			  rs1_op1_select_out_tmp	[0:`RS_SIZE-1];
   	wire [3:0]			  rs1_op2_select_out_tmp	[0:`RS_SIZE-1];
    wire [`ROB_WIDTH-1:0] rs1_rob_entry_out_tmp		[0:`RS_SIZE-1]; 
	wire [`RS_SIZE-1:0]	  rs1_rd_mem_out_tmp;						
	wire [`RS_SIZE-1:0]	  rs1_wr_mem_out_tmp;						
	wire [`RS_SIZE-1:0]	  rs1_cond_branch_out_tmp;		
	wire [`RS_SIZE-1:0]	  rs1_uncond_branch_out_tmp;			
	wire [`RS_SIZE-1:0]	  rs1_halt_out_tmp;				
	wire [`RS_SIZE-1:0]	  rs1_illigal_out_tmp;			
    wire [3:0] 			  rs1_fu_type_out_tmp		[0:`RS_SIZE-1]; 
    wire [`IMM_WIDTH-1:0] rs1_imm_out_tmp			[0:`RS_SIZE-1]; 


	assign {inst_in_way[2],inst_in_way[1],inst_in_way[0]} 					= inst_in;
	assign {pc_in_way[2],pc_in_way[1],pc_in_way[0]} 						= pc_in;
	assign {npc_in_way[2],npc_in_way[1],npc_in_way[0]} 						= npc_in;
	assign {op_type_in_way[2],op_type_in_way[1],op_type_in_way[0]} 			= op_type_in;
	assign {op1_prn_in_way[2],op1_prn_in_way[1],op1_prn_in_way[0]} 			= op1_prn_in;
	assign {op2_prn_in_way[2],op2_prn_in_way[1],op2_prn_in_way[0]} 			= op2_prn_in;
	assign {dest_prn_in_way[2],dest_prn_in_way[1],dest_prn_in_way[0]} 		= dest_prn_in;
	assign {op1_select_in_way[2],op1_select_in_way[1],op1_select_in_way[0]} = op1_select_in;
	assign {op2_select_in_way[2],op2_select_in_way[1],op2_select_in_way[0]} = op2_select_in;
	assign {rob_entry_in_way[2],rob_entry_in_way[1],rob_entry_in_way[0]} 	= rob_entry_in;
	assign {fu_type_in_way[2],fu_type_in_way[1],fu_type_in_way[0]} 			= fu_type_in;
	assign {imm_in_way[2],imm_in_way[1],imm_in_way[0]} 						= imm_in;

	assign rs1_databus_in_way[0] = {inst_in_way[0],pc_in_way[0],npc_in_way[0],op_type_in_way[0],op1_prn_in_way[0],op2_prn_in_way[0],use_op1_prn_in[0],use_op2_prn_in[0],dest_prn_in_way[0],
									op1_select_in_way[0],op2_select_in_way[0],rd_mem_in[0],wr_mem_in[0],cond_branch_in[0],uncond_branch_in[0],halt_in[0],illigal_in[0],
									rob_entry_in_way[0],op1_ready_in[0],op2_ready_in[0],fu_type_in_way[0],imm_in_way[0]};

	assign rs1_databus_in_way[1] = {inst_in_way[1],pc_in_way[1],npc_in_way[1],op_type_in_way[1],op1_prn_in_way[1],op2_prn_in_way[1],use_op1_prn_in[1],use_op2_prn_in[1],dest_prn_in_way[1],
									op1_select_in_way[1],op2_select_in_way[1],rd_mem_in[1],wr_mem_in[1],cond_branch_in[1],uncond_branch_in[1],halt_in[1],illigal_in[1],
									rob_entry_in_way[1],op1_ready_in[1],op2_ready_in[1],fu_type_in_way[1],imm_in_way[1]};

	assign rs1_databus_in_way[2] = {inst_in_way[2],pc_in_way[2],npc_in_way[2],op_type_in_way[2],op1_prn_in_way[2],op2_prn_in_way[2],use_op1_prn_in[2],use_op2_prn_in[2],dest_prn_in_way[2],
									op1_select_in_way[2],op2_select_in_way[2],rd_mem_in[2],wr_mem_in[2],cond_branch_in[2],uncond_branch_in[2],halt_in[2],illigal_in[2],
									rob_entry_in_way[2],op1_ready_in[2],op2_ready_in[2],fu_type_in_way[2],imm_in_way[2]};


	assign rs1_inst_out 		= {o_data_2[175:144	]	,o_data_1[175:144	]	,o_data_0[175:144	]}; 
	assign rs1_pc_out 			= {o_data_2[143:112	]	,o_data_1[143:112	]	,o_data_0[143:112	]}; 
	assign rs1_npc_out 			= {o_data_2[111:80	]	,o_data_1[111:80	]	,o_data_0[111:80	]}; 
	assign rs1_op_type_out 		= {o_data_2[79:75	]	,o_data_1[79:75		]	,o_data_0[79:75		]}; //TODO
	assign rs1_op1_prn_out	 	= {o_data_2[74:68	]	,o_data_1[74:68		]	,o_data_0[74:68		]};
	assign rs1_op2_prn_out 		= {o_data_2[67:61	]	,o_data_1[67:61		]	,o_data_0[67:61		]};
	assign rs1_dest_prn_out 	= {o_data_2[60:54	]	,o_data_1[60:54		]	,o_data_0[60:54		]};
	assign rs1_op1_select_out	= {o_data_2[53:52	]	,o_data_1[53:52		]	,o_data_0[53:52		]};	
	assign rs1_op2_select_out	= {o_data_2[51:48	]	,o_data_1[51:48		]	,o_data_0[51:48		]};
	assign rs1_rd_mem_out		= {o_data_2[47		]	,o_data_1[47		]	,o_data_0[47		]};
	assign rs1_wr_mem_out		= {o_data_2[46		]	,o_data_1[46		]	,o_data_0[46		]};
	assign rs1_cond_branch_out  = {o_data_2[45		]	,o_data_1[45		]	,o_data_0[45		]};
	assign rs1_uncond_branch_out= {o_data_2[44		]	,o_data_1[44		]	,o_data_0[44		]};	
	assign rs1_halt_out			= {o_data_2[43		]	,o_data_1[43		]	,o_data_0[43		]};
	assign rs1_illigal_out		= {o_data_2[42		]	,o_data_1[42		]	,o_data_0[42		]};
	assign rs1_rob_entry_out	= {o_data_2[41:36	]	,o_data_1[41:36		]	,o_data_0[41:36		]};
	assign rs1_fu_type_out 		= {o_data_2[35:32	]	,o_data_1[35:32		]	,o_data_0[35:32		]};
	assign rs1_imm_out 			= {o_data_2[31:0	]	,o_data_1[31:0		]	,o_data_0[31:0		]};

	assign inst_issue_valid 	= {issue_select[47:32]!=0,issue_select[31:16]!=0,issue_select[15:0]!=0};

	assign i_data = {i_data_tmp[15],i_data_tmp[14],i_data_tmp[13],i_data_tmp[12],i_data_tmp[11],i_data_tmp[10],i_data_tmp[9],i_data_tmp[8],
					 i_data_tmp[7],i_data_tmp[6],i_data_tmp[5],i_data_tmp[4],i_data_tmp[3],i_data_tmp[2],i_data_tmp[1],i_data_tmp[0]};

	mux_onehot #(
		.INPUT_NUM(`RS_SIZE),
		.DATA_WIDTH(`RS1_DATABUS_OUT_WIDTH))	
	mux_onehot_issue0(
		.onehot(issue_select[15:0]),				
		.i_data(i_data),					
		.o_data(o_data_0)						
	);

	mux_onehot #(
		.INPUT_NUM(`RS_SIZE),
		.DATA_WIDTH(`RS1_DATABUS_OUT_WIDTH))	
	mux_onehot_issue1(
		.onehot(issue_select[31:16]),				
		.i_data(i_data),					
		.o_data(o_data_1)						
	);

	mux_onehot #(
		.INPUT_NUM(`RS_SIZE),
		.DATA_WIDTH(`RS1_DATABUS_OUT_WIDTH))	
	mux_onehot_issue2(
		.onehot(issue_select[47:32]),				
		.i_data(i_data),					
		.o_data(o_data_2)						
	);

	genvar i;
		generate
			for(i=0;i<`RS_SIZE;i=i+1) begin

				assign mux_select_way[i] = dispatch_select_way[i*2+:2];
				assign i_data_tmp[i] = {rs1_inst_out_tmp[i],rs1_pc_out_tmp[i],rs1_npc_out_tmp[i],rs1_op_type_out_tmp[i],rs1_op1_prn_out_tmp[i],rs1_op2_prn_out_tmp[i],rs1_dest_prn_out_tmp[i],
										rs1_op1_select_out_tmp[i],rs1_op2_select_out_tmp[i],rs1_rd_mem_out_tmp[i],rs1_wr_mem_out_tmp[i],rs1_cond_branch_out_tmp[i],rs1_uncond_branch_out_tmp[i],
										rs1_halt_out_tmp[i],rs1_illigal_out_tmp[i],rs1_rob_entry_out_tmp[i],rs1_fu_type_out_tmp[i],rs1_imm_out_tmp[i]};

				mux41 #(`RS1_DATABUS_IN_WIDTH)	mux41_dispatch(
					.sel(mux_select_way[i]),						
					.in0(rs1_databus_in_way[0]),						
					.in1(rs1_databus_in_way[1]),						
					.in2(rs1_databus_in_way[2]),						
					.in3('0),						
					.out(rs1_databus[i])					
				);

				rs1 rs1_inst(
					.clk					(clk),         
					.rst					(rst),         
					.rs1_load				(rs1_load[i]),
			   		.rs1_use_en         	(rs1_use_en[i]),	
					.inst_in				(rs1_databus[i][179:148]),	
					.pc_in					(rs1_databus[i][147:116]),	
					.npc_in					(rs1_databus[i][115:84]),	
					.op_type_in				(rs1_databus[i][83:79]),	 
					.op1_prn_in				(rs1_databus[i][78:72]),  //TODO
					.op2_prn_in				(rs1_databus[i][71:65]),  
					.use_op1_prn_in			(rs1_databus[i][64]), 
					.use_op2_prn_in			(rs1_databus[i][63]), 
					.dest_prn_in			(rs1_databus[i][62:56]), 
					.op1_select_in			(rs1_databus[i][55:54]),
					.op2_select_in			(rs1_databus[i][53:50]),
					.rd_mem_in				(rs1_databus[i][49]),
					.wr_mem_in				(rs1_databus[i][48]),
					.cond_branch_in			(rs1_databus[i][47]),
					.uncond_branch_in		(rs1_databus[i][46]),
					.halt_in				(rs1_databus[i][45]),
					.illigal_in				(rs1_databus[i][44]),
					.rob_entry_in			(rs1_databus[i][43:38]),
					.op1_ready_in			(rs1_databus[i][37]),
					.op2_ready_in			(rs1_databus[i][36]),
					.fu_type_in				(rs1_databus[i][35:32]),		
					.imm_in					(rs1_databus[i][31:0]),	
					.load_ready_in			(load_ready_in),		
					.cdb_valid 				(cdb_valid),
                    .cdb_tag				(cdb_tag),
					.rs1_wake_up_alu		(rs1_wake_up_alu[i]),  
					.rs1_wake_up_mul		(rs1_wake_up_mul[i]),  
					.rs1_wake_up_mem		(rs1_wake_up_mem[i]),  
					.rs1_wake_up_bcond		(rs1_wake_up_bcond[i]),  
					.rs1_avail				(rs1_avail[i]), 
				 	.rs1_inst_out			(rs1_inst_out_tmp[i]),	
				 	.rs1_pc_out				(rs1_pc_out_tmp[i]),	
				 	.rs1_npc_out			(rs1_npc_out_tmp[i]),	
					.rs1_op_type_out		(rs1_op_type_out_tmp[i]), //connect to the input of mux16_1  3 in 16
					.rs1_op1_prn_out		(rs1_op1_prn_out_tmp[i]),
					.rs1_op2_prn_out		(rs1_op2_prn_out_tmp[i]),
					.rs1_dest_prn_out		(rs1_dest_prn_out_tmp[i]),
					.rs1_op1_select_out		(rs1_op1_select_out_tmp[i]),		
                    .rs1_op2_select_out		(rs1_op2_select_out_tmp[i]),	
                    .rs1_rd_mem_out			(rs1_rd_mem_out_tmp[i]),			
                    .rs1_wr_mem_out			(rs1_wr_mem_out_tmp[i]),			
                    .rs1_cond_branch_out 	(rs1_cond_branch_out_tmp[i]),	
                    .rs1_uncond_branch_out	(rs1_uncond_branch_out_tmp[i]),	
                    .rs1_halt_out			(rs1_halt_out_tmp[i]),			
                    .rs1_illigal_out		(rs1_illigal_out_tmp[i]),		
					.rs1_rob_entry_out		(rs1_rob_entry_out_tmp[i]),
					.rs1_fu_type_out		(rs1_fu_type_out_tmp[i]),
					.rs1_imm_out			(rs1_imm_out_tmp[i])
				);
			end	
		endgenerate
	
endmodule

