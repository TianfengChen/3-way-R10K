`timescale 1ns/100ps

module lsq(	
	input 							clk											,
	input 							rst_n										,
	input 							pipe_flush									,

	input	DISPATCH_LSQ_PACKET		dispatch_pkt			[0:`MACHINE_WIDTH-1],
	output							dispatch_pkt_ready							,
	output	[`STQ_WIDTH-1:0]		dispatch_stq_resp		[0:`MACHINE_WIDTH-1],
	output	[`LDQ_WIDTH-1:0]		dispatch_ldq_resp		[0:`MACHINE_WIDTH-1],
	input	EXECUTE_PACKET			execute_pkt									,
	input	RETIRE_ROB_PACKET		retire_pkt				[0:`MACHINE_WIDTH-1],

	output	[`XLEN-1:0]				fire_st_addr,
	output	[`XLEN-1:0]				fire_st_data,
	output	[2:0]					fire_st_data_size,
	output	[`STQ_WIDTH-1:0]		fire_st_stq_tag,
	output							fire_st_valid,
	input							fire_st_ready,

	output	[`XLEN-1:0]				fire_ld_addr,
	output	[2:0]					fire_ld_data_size,
	output	[`LDQ_WIDTH-1:0]		fire_ld_ldq_tag,
	output							fire_ld_valid,
	input							fire_ld_ready,
	output	[`LDQ_DEPTH-1:0]		fire_ld_kill,

	input	[`XLEN-1:0]				dcache_data,
	input	[`LDQ_WIDTH-1:0]		dcache_ldq_tag,
	input							dcache_valid,
	output							dcache_ready,

	output	[`XLEN-1:0]				writeback_data,
	output	[`XLEN-1:0]				writeback_pc,
	output	[`PRF_WIDTH-1:0]		writeback_dest_prn,
	output	[`ROB_WIDTH:0]			writeback_rob_tag,	
	output							writeback_valid,
	input							writeback_ready
);

	STQ_ENTRY						stq_entry					[0:`STQ_DEPTH-1]	;	
	LDQ_ENTRY						ldq_entry					[0:`LDQ_DEPTH-1]	;

	wire	[`MACHINE_WIDTH-1:0]	dispatch_stq_valid								;
	wire							dispatch_stq_ready								;
	wire	[`MACHINE_WIDTH-1:0]	dispatch_ldq_valid								;
	wire							dispatch_ldq_ready								;
	//current stq states
	wire	[`STQ_DEPTH-1:0]		dispatch_stq_st_mask							;
	wire	[`STQ_WIDTH-1:0]		dispatch_stq_st_youngest						;
	//intra-group st-ld dependency
	wire	[`STQ_DEPTH-1:0]		dispatch_ldq_st_mask		[0:`MACHINE_WIDTH-1];
	wire	[`STQ_WIDTH-1:0]		dispatch_ldq_st_youngest	[0:`MACHINE_WIDTH-1];

	wire	[`XLEN-1:0]				fwd_data			 ;
	wire							fwd_valid			 ;
	wire							fwd_sleep			 ;
	wire	[`LDQ_WIDTH-1:0]		fwd_ldq_tag		 	 ;
	wire	[`STQ_WIDTH-1:0]		fwd_stq_tag		 	 ;
	wire 	[`STQ_DEPTH-1:0]		fire_ld_st_mask		 ;
	wire	[`STQ_WIDTH-1:0]		fire_ld_st_youngest	 ;                                                  
	wire 							execute_stq_valid	 ;
	wire 							execute_ldq_valid	 ;
  



	assign execute_stq_valid	=	execute_pkt.packet_valid && execute_pkt.wr_mem;
	assign execute_ldq_valid	=	execute_pkt.packet_valid && execute_pkt.rd_mem;
	assign dispatch_pkt_ready 	=	dispatch_stq_ready && dispatch_ldq_ready;






	genvar i;
	generate	
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin   	
			assign dispatch_stq_valid[i] 	= 	dispatch_pkt[i].packet_valid && 
												dispatch_pkt[i].wr_mem;
			assign dispatch_ldq_valid[i] 	= 	dispatch_pkt[i].packet_valid && 
												dispatch_pkt[i].rd_mem;
		end
	endgenerate




	/********************intra-group dependency check*******************/
	assign dispatch_ldq_st_youngest[0] 	= 	dispatch_stq_st_youngest;
	assign dispatch_ldq_st_youngest[1] 	= 	dispatch_stq_st_mask!=0 ?
											(dispatch_pkt[0].packet_valid && dispatch_pkt[0].wr_mem) +
   											dispatch_stq_st_youngest :	
											(dispatch_pkt[0].packet_valid && dispatch_pkt[0].wr_mem) +
											dispatch_stq_st_youngest-1;
	assign dispatch_ldq_st_youngest[2] 	= 	dispatch_stq_st_mask!=0 ?
											(dispatch_pkt[0].packet_valid && dispatch_pkt[0].wr_mem) +
											(dispatch_pkt[1].packet_valid && dispatch_pkt[1].wr_mem) +
   											dispatch_stq_st_youngest :
											(dispatch_pkt[0].packet_valid && dispatch_pkt[0].wr_mem) +
											(dispatch_pkt[1].packet_valid && dispatch_pkt[1].wr_mem) +
											dispatch_stq_st_youngest-1;
	assign dispatch_ldq_st_youngest[3] 	= 	dispatch_stq_st_mask!=0 ?
											(dispatch_pkt[0].packet_valid && dispatch_pkt[0].wr_mem) +
											(dispatch_pkt[1].packet_valid && dispatch_pkt[1].wr_mem) +
											(dispatch_pkt[2].packet_valid && dispatch_pkt[2].wr_mem) +
   											dispatch_stq_st_youngest :
											(dispatch_pkt[0].packet_valid && dispatch_pkt[0].wr_mem) +
											(dispatch_pkt[1].packet_valid && dispatch_pkt[1].wr_mem) +
											(dispatch_pkt[2].packet_valid && dispatch_pkt[2].wr_mem) +
											dispatch_stq_st_youngest-1;								
									


	generate	
		for(i=0;i<`STQ_DEPTH;i=i+1) begin   	
			assign dispatch_ldq_st_mask[0][i]	=	dispatch_stq_st_mask[i];
			assign dispatch_ldq_st_mask[1][i]	=	dispatch_pkt[0].packet_valid && dispatch_pkt[0].wr_mem && i==dispatch_ldq_st_youngest[1] ? 1'b1 : dispatch_ldq_st_mask[0][i];
			assign dispatch_ldq_st_mask[2][i]	=	dispatch_pkt[1].packet_valid && dispatch_pkt[1].wr_mem && i==dispatch_ldq_st_youngest[2] ? 1'b1 : dispatch_ldq_st_mask[1][i];
			assign dispatch_ldq_st_mask[3][i]	=	dispatch_pkt[2].packet_valid && dispatch_pkt[2].wr_mem && i==dispatch_ldq_st_youngest[3] ? 1'b1 : dispatch_ldq_st_mask[2][i];
		end
	endgenerate

 



	stq u_stq(	
		.clk						(clk						),
		.rst_n						(rst_n						),
		.pipe_flush					(pipe_flush					),
		                        	                        	
		.dispatch_valid				(dispatch_stq_valid			),
		.dispatch_ready				(dispatch_stq_ready			),
		.dispatch_resp				(dispatch_stq_resp			),
		.dispatch_st_mask			(dispatch_stq_st_mask		),
		.dispatch_st_youngest		(dispatch_stq_st_youngest	),	                                                
	
		.execute_st_addr			(execute_pkt.result			),
		.execute_st_addr_stq_tag	(execute_pkt.stq_tag		),
		.execute_st_addr_valid		(execute_stq_valid			),
		.execute_st_data			(execute_pkt.st_data		),
		.execute_st_data_size		(execute_pkt.mem_size		),
		.execute_st_data_stq_tag	(execute_pkt.stq_tag		),
		.execute_st_data_valid		(execute_stq_valid			),
		                                                	
		.retire_pkt					(retire_pkt					),
		                        	                        	
		.fire_st_addr				(fire_st_addr				),
		.fire_st_data				(fire_st_data				),
		.fire_st_data_size			(fire_st_data_size			),
		.fire_st_stq_tag			(fire_st_stq_tag			),
		.fire_st_valid				(fire_st_valid				),
		.fire_st_ready				(fire_st_ready				),
		                        	                        	
		.fire_ld_addr				(fire_ld_addr				),
		.fire_ld_data_size			(fire_ld_data_size			),
		.fire_ld_ldq_tag			(fire_ld_ldq_tag			),
		.fire_ld_st_mask			(fire_ld_st_mask			),	
		.fire_ld_st_youngest		(fire_ld_st_youngest		),	
		.fire_ld_valid				(fire_ld_valid				),
		                        	                        	
		.fwd_data					(fwd_data					),
		.fwd_valid					(fwd_valid					),
		.fwd_sleep					(fwd_sleep					),
		.fwd_ldq_tag				(fwd_ldq_tag				),
		.fwd_stq_tag				(fwd_stq_tag				),
                                	                        	
		.stq_entry					(stq_entry					)
	);



	`ifndef LSQ_CONSERVATIVE
	ldq u_ldq(	
		.clk						(clk						),
		.rst_n						(rst_n						),
		.pipe_flush					(pipe_flush					),
		                        	                        	
		.dispatch_valid				(dispatch_ldq_valid			),
		.dispatch_ready				(dispatch_ldq_ready			),
		.dispatch_resp				(dispatch_ldq_resp			),	
		.dispatch_st_mask			(dispatch_ldq_st_mask		),
		.dispatch_st_youngest		(dispatch_ldq_st_youngest	),
		                        	                        
		.execute_ld_addr			(execute_pkt.result			),
		.execute_ld_ldq_tag			(execute_pkt.ldq_tag		),
		.execute_ld_data_size		(execute_pkt.mem_size		),
		.execute_ld_pc				(execute_pkt.pc				),
		.execute_ld_prn				(execute_pkt.dest_prn		),
		.execute_ld_rob_tag			(execute_pkt.rob_entry		),
		.execute_ld_valid			(execute_ldq_valid			),
		.execute_st_addr			(execute_pkt.result			),
		.execute_st_addr_stq_tag	(execute_pkt.stq_tag		),
		.execute_st_addr_valid		(execute_stq_valid			),

		.fire_ld_addr				(fire_ld_addr				),
		.fire_ld_data_size			(fire_ld_data_size			),
		.fire_ld_ldq_tag			(fire_ld_ldq_tag			),
		.fire_ld_st_mask			(fire_ld_st_mask			),
		.fire_ld_st_youngest		(fire_ld_st_youngest		),
		.fire_ld_valid				(fire_ld_valid				),
		.fire_ld_kill				(fire_ld_kill				),
		.fire_ld_ready				(fire_ld_ready 				),
		                   	    	                   	    	
		.fire_st_stq_tag			(fire_st_stq_tag			),
		.fire_st_valid				(fire_st_valid				),            	
		.fire_st_ready				(fire_st_ready				), 
                                	
		.fwd_data					(fwd_data					),
		.fwd_valid					(fwd_valid					),
		.fwd_sleep					(fwd_sleep					),
		.fwd_ldq_tag				(fwd_ldq_tag				),
		.fwd_stq_tag				(fwd_stq_tag				),     
                                	
		.dcache_data				(dcache_data				),
		.dcache_ldq_tag				(dcache_ldq_tag				),
		.dcache_valid				(dcache_valid				),
		.dcache_ready				(dcache_ready				),
                                	
		.writeback_data				(writeback_data				),
		.writeback_pc				(writeback_pc				),
		.writeback_dest_prn			(writeback_dest_prn			),
		.writeback_rob_tag			(writeback_rob_tag			),	
		.writeback_valid			(writeback_valid			),
		.writeback_ready			(writeback_ready			),
                                	
		.retire_pkt					(retire_pkt					),
                                	                        	
		.stq_entry					(stq_entry					),
		.ldq_entry					(ldq_entry					)
			
	);
					
	`else

	ldq_conservative u_ldq(	
		.clk						(clk						),
		.rst_n						(rst_n						),
		.pipe_flush					(pipe_flush					),
		                        	                        	
		.dispatch_valid				(dispatch_ldq_valid			),
		.dispatch_ready				(dispatch_ldq_ready			),
		.dispatch_resp				(dispatch_ldq_resp			),	
		.dispatch_st_mask			(dispatch_ldq_st_mask		),
		.dispatch_st_youngest		(dispatch_ldq_st_youngest	),
		                        	                        
		.execute_ld_addr			(execute_pkt.result			),
		.execute_ld_ldq_tag			(execute_pkt.ldq_tag		),
		.execute_ld_data_size		(execute_pkt.mem_size		),
		.execute_ld_pc				(execute_pkt.pc				),
		.execute_ld_prn				(execute_pkt.dest_prn		),
		.execute_ld_rob_tag			(execute_pkt.rob_entry		),
		.execute_ld_valid			(execute_ldq_valid			),
		                   	    	                   	    	
		.fire_ld_addr				(fire_ld_addr				),
		.fire_ld_data_size			(fire_ld_data_size			),
		.fire_ld_ldq_tag			(fire_ld_ldq_tag			),
		.fire_ld_st_mask			(fire_ld_st_mask			),
		.fire_ld_st_youngest		(fire_ld_st_youngest		),
		.fire_ld_valid				(fire_ld_valid				),
		.fire_ld_kill				(fire_ld_kill				),
		.fire_ld_ready				(fire_ld_ready 				),
		                   	    	                   	    	
		.fire_st_stq_tag			(fire_st_stq_tag			),
		.fire_st_valid				(fire_st_valid				),            	
		.fire_st_ready				(fire_st_ready				), 
                                	
		.fwd_data					(fwd_data					),
		.fwd_valid					(fwd_valid					),
		.fwd_sleep					(fwd_sleep					),
		.fwd_ldq_tag				(fwd_ldq_tag				),
		.fwd_stq_tag				(fwd_stq_tag				),     
                                	
		.dcache_data				(dcache_data				),
		.dcache_ldq_tag				(dcache_ldq_tag				),
		.dcache_valid				(dcache_valid				),
		.dcache_ready				(dcache_ready				),
                                	
		.writeback_data				(writeback_data				),
		.writeback_pc				(writeback_pc				),
		.writeback_dest_prn			(writeback_dest_prn			),
		.writeback_rob_tag			(writeback_rob_tag			),	
		.writeback_valid			(writeback_valid			),
		.writeback_ready			(writeback_ready			),
                                	
		.retire_pkt					(retire_pkt					),
                                	                        	
		.stq_entry					(stq_entry					),
		.ldq_entry					(ldq_entry					)
			
	);	
	`endif


endmodule
