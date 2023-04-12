`ifndef __RS_ARRAY_V__
`define __RS_ARRAY_V__
`timescale 1ns/100ps



module rs_array #(
	parameter RS_DEPTH
)
(
	input        				clk,          					// the clock 		
	input        				rst_n,          					// reset signal			
	input        				pipe_flush,		
	input [RS_DEPTH-1:0] 		rs_use_en,						// send signal to FU
	input [`MACHINE_WIDTH-1:0]	alloc_sel		[0:RS_DEPTH-1],	// allocate the rs entry
	input [RS_DEPTH-1:0]		issue_sel		[0:`ISSUE_WIDTH-1],	// issue gnt_bus 
	input [`ISSUE_WIDTH-1:0]	cdb_valid,  	
	input [`PRF_WIDTH-1:0]		cdb_prn			[0:`ISSUE_WIDTH-1],
	input DISPATCH_RS_PACKET	dispatch_pkt	[0:`MACHINE_WIDTH-1],	
                                
	output [`ISSUE_WIDTH-1:0] 	rs_wake_up		[0:RS_DEPTH-1], // This RS is in use and ready to go to EX 
	output [RS_DEPTH-1:0]  		rs_issued,     		
	output [RS_DEPTH-1:0]  		rs_avail,     		// This RS is available to be allocated 
	output [`ROB_WIDTH:0]  		rs_age			[0:RS_DEPTH-1],     		// This RS is available to be allocated 
	output ISSUE_PACKET			issue_pkt		[0:`ISSUE_WIDTH-1]
);	

	ISSUE_PACKET 		issue_pkt_N		[0:RS_DEPTH-1];
	DISPATCH_RS_PACKET 	dispatch_pkt_N	[0:RS_DEPTH-1];
	wire [`ROB_WIDTH:0] rob_tag_N		[0:RS_DEPTH-1];


	xbar#(
		.INPUT_NUM(`MACHINE_WIDTH),
		.OUTPUT_NUM(RS_DEPTH),
		.DATA_WIDTH(`DISPATCH_RS_PACKET_WIDTH))	
	u_xbar_rs_alloc_dispatch(	
		.xbar_sel	(alloc_sel),
		.i_data		(dispatch_pkt),
		.o_data		(dispatch_pkt_N)
	);

	xbar#(
		.INPUT_NUM(RS_DEPTH),
		.OUTPUT_NUM(`ISSUE_WIDTH),
		.DATA_WIDTH(`ISSUE_PACKET_WIDTH))	
	u_xbar_rs_issue(	
		.xbar_sel	(issue_sel),
		.i_data		(issue_pkt_N),
		.o_data		(issue_pkt)
	);

	genvar i;
	generate
		for(i=0;i<RS_DEPTH;i=i+1) begin: gen_rs1
			assign issue_pkt_N[i].packet_valid = rs_use_en[i];
			rs1 u_rs1(
				.clk					(clk							),         
				.rst_n					(rst_n							),         
				.pipe_flush				(pipe_flush						),         
				.rs1_load				(dispatch_pkt_N[i].packet_valid	),
		   		.rs1_use_en         	(rs_use_en[i]					),	
				.inst_in				(dispatch_pkt_N[i].inst			),	
				.pc_in					(dispatch_pkt_N[i].pc				),	
			//	.npc_in					(dispatch_pkt_N[i].npc			),	
				.op_type_in				(dispatch_pkt_N[i].op_type		),	 
				.op1_prn_in				(dispatch_pkt_N[i].op1_prn		),  
				.op2_prn_in				(dispatch_pkt_N[i].op2_prn		),  
				.use_op1_prn_in			(dispatch_pkt_N[i].use_op1_prn	), 
				.use_op2_prn_in			(dispatch_pkt_N[i].use_op2_prn	), 
				.dest_prn_in			(dispatch_pkt_N[i].dest_prn		), 
				.op1_select_in			(dispatch_pkt_N[i].op1_select		),
				.op2_select_in			(dispatch_pkt_N[i].op2_select		),
				.rd_mem_in				(dispatch_pkt_N[i].rd_mem			),
				.wr_mem_in				(dispatch_pkt_N[i].wr_mem			),
				.cond_branch_in			(dispatch_pkt_N[i].cond_branch	),
				.uncond_branch_in		(dispatch_pkt_N[i].uncond_branch	),
			//	.halt_in				(dispatch_pkt_N[i].halt			),
			//	.illegal_in				(dispatch_pkt_N[i].illegal		),
				.rob_entry_in			(dispatch_pkt_N[i].rob_entry		),
				.op1_ready_in			(dispatch_pkt_N[i].op1_ready		),
				.op2_ready_in			(dispatch_pkt_N[i].op2_ready		),
				.fu_id_in				(dispatch_pkt_N[i].fu_id			),		
				.ptab_tag_in			(dispatch_pkt_N[i].ptab_tag			),		
				.stq_tag_in				(dispatch_pkt_N[i].stq_tag			),		
				.ldq_tag_in				(dispatch_pkt_N[i].ldq_tag			),		
				.cdb_valid 				(cdb_valid						),
                .cdb_prn				(cdb_prn						),
				.rs1_wake_up			(rs_wake_up[i]					),  
				.rs1_issued				(rs_issued[i]					),  
				.rs1_avail				(rs_avail[i]					), 
				.rs1_age				(rs_age[i]						), 
			 	.rs1_inst_out			(issue_pkt_N[i].inst			),	
			 	.rs1_pc_out				(issue_pkt_N[i].pc				),	
			// 	.rs1_npc_out			(issue_pkt_N[i].npc				),	
				.rs1_op_type_out		(issue_pkt_N[i].op_type			), 
				.rs1_op1_prn_out		(issue_pkt_N[i].op1_prn			),
				.rs1_op2_prn_out		(issue_pkt_N[i].op2_prn			),
				.rs1_dest_prn_out		(issue_pkt_N[i].dest_prn		),
				.rs1_op1_select_out		(issue_pkt_N[i].op1_select		),		
                .rs1_op2_select_out		(issue_pkt_N[i].op2_select		),	
                .rs1_rd_mem_out			(issue_pkt_N[i].rd_mem			),			
                .rs1_wr_mem_out			(issue_pkt_N[i].wr_mem			),			
                .rs1_cond_branch_out 	(issue_pkt_N[i].cond_branch		),	
                .rs1_uncond_branch_out	(issue_pkt_N[i].uncond_branch	),	
            //  .rs1_halt_out			(issue_pkt_N[i].halt			),			
            //  .rs1_illegal_out		(issue_pkt_N[i].illegal			),		
				.rs1_rob_entry_out		(issue_pkt_N[i].rob_entry		),
				.rs1_fu_id_out			(issue_pkt_N[i].fu_id			),
				.rs1_ptab_tag_out		(issue_pkt_N[i].ptab_tag		),
				.rs1_stq_tag_out		(issue_pkt_N[i].stq_tag			),
				.rs1_ldq_tag_out		(issue_pkt_N[i].ldq_tag			)
			);
		end	
	endgenerate
	
endmodule
`endif //__RS_ARRAY_V__
