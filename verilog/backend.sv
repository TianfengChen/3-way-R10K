`timescale 1ns/100ps
		
module backend (
	input									clk,
	input									rst_n,
	//TODO assert branch is onehot
	input  	FETCH_PACKET 					fetch_pkt		[0:`MACHINE_WIDTH-1],
	output  [`MACHINE_WIDTH-1:0]    		fetch_pkt_ready						,
	output									fetch_br_misp						,
	output	[`XLEN-1:0]						fetch_redirect_pc					,				
			
	output	[`XLEN-1:0]						fire_st_addr		 				,
	output	[`XLEN-1:0]						fire_st_data		 				,
	output	[2:0]							fire_st_data_size	 				,
	output 	[`STQ_WIDTH-1:0]				fire_st_stq_tag						,
	output									fire_st_valid		 				,
	input									fire_st_ready		 				,

	output	[`XLEN-1:0]						fire_ld_addr						,
	output	[2:0]							fire_ld_data_size					,
	output	[`LDQ_WIDTH-1:0]				fire_ld_ldq_tag						,
	output									fire_ld_valid						,
	input									fire_ld_ready						,
	output	[`LDQ_DEPTH-1:0]				fire_ld_kill						,

	input	[`XLEN-1:0]						dcache_data							,
	input	[`LDQ_WIDTH-1:0]				dcache_ldq_tag						,
	input									dcache_valid						,	
	output									dcache_ready						

);


	/*************************Decode and Rename Declaration************************/
	FETCH_PACKET 				decode_rename_fetch_pkt		[0:`MACHINE_WIDTH-1];
	wire [`MACHINE_WIDTH-1:0]   decode_rename_ready								;

	RENAME_PACKET				rename_pkt 					[0:`MACHINE_WIDTH-1];
	wire [`MACHINE_WIDTH-1:0]	rename_pkt_ready								;

	wire [`PRF_WIDTH-1:0] 		retire_dest_prn_prev		[0:`MACHINE_WIDTH-1];
	wire [`MACHINE_WIDTH-1:0]	retire_dest_prn_prev_valid						;	
	wire [`MACHINE_WIDTH-1:0]   retire_dest_prn_prev_ready						;

	wire [`PRF_WIDTH-1:0] 		execute_prn					[0:`ISSUE_WIDTH-1]	;
	wire [`ISSUE_WIDTH-1:0]		execute_valid									;

	FETCH_PACKET 				ptab_fetch_pkt				[0:`MACHINE_WIDTH-1];
	wire			 			ptab_ready										;
	wire [`PTAB_WIDTH-1:0]		ptab_tag					[0:`MACHINE_WIDTH-1];
	wire [`PTAB_WIDTH-1:0]		bru_ptab_tag							;
	wire  						bru_branch_dir							;
	wire  [`XLEN-1:0]			bru_target_pc							;
	wire  						bru_valid								;
	wire						bru_branch_misp								;
	wire [`XLEN-1:0]			bru_next_pc									;

	/********************************ROB Declaration*******************************/
	wire [`ROB_WIDTH:0]			rob_tag					[0:`MACHINE_WIDTH-1];
	DISPATCH_RS_PACKET			dispatch_rs_pkt			[0:`MACHINE_WIDTH-1];
	DISPATCH_ROB_PACKET			dispatch_rob_pkt		[0:`MACHINE_WIDTH-1];
	wire [`MACHINE_WIDTH-1:0]	dispatch_rob_pkt_ready						 ;
	wire [`ROB_WIDTH:0]			dispatch_rob_pkt_resp	[0:`MACHINE_WIDTH-1] ;        
	RETIRE_ROB_PACKET			retire_pkt				[0:`MACHINE_WIDTH-1] ;      
	RETIRE_ROB_PACKET			pipe_retire_pkt			[0:`MACHINE_WIDTH-1] ;      

	/********************************LSQ Declaration*******************************/
	DISPATCH_LSQ_PACKET			dispatch_lsq_pkt		[0:`MACHINE_WIDTH-1];
	wire						dispatch_lsq_pkt_ready						;
	wire [`STQ_WIDTH-1:0]		dispatch_stq_resp		[0:`MACHINE_WIDTH-1];	
	wire [`LDQ_WIDTH-1:0]		dispatch_ldq_resp		[0:`MACHINE_WIDTH-1];	

	wire [`XLEN-1:0]			writeback_lsq_data		;
	wire [`XLEN-1:0]			writeback_lsq_pc		;
	wire [`PRF_WIDTH-1:0]		writeback_lsq_dest_prn	;
	wire [`ROB_WIDTH:0]			writeback_lsq_rob_tag	;
	wire						writeback_lsq_valid		;
	wire						writeback_lsq_ready		;

	/*********************************RS Declaration*******************************/
	DISPATCH_RS_PACKET			int_dispatch_pkt 	[0:`MACHINE_WIDTH-1];
	DISPATCH_RS_PACKET			mem_dispatch_pkt 	[0:`MACHINE_WIDTH-1];
	                			
	ISSUE_PACKET				int_issue_pkt 	[0:`ISSUE_WIDTH-1];
	ISSUE_PACKET				mem_issue_pkt 	[0:`ISSUE_WIDTH-1];
	
	wire [`MACHINE_WIDTH-1:0]	int_dispatch_pkt_ready;
	wire [`MACHINE_WIDTH-1:0]	mem_dispatch_pkt_ready;

	/********************************PRF Declaration*******************************/
	wire	[`PRF_WIDTH-1:0] 	rda_addr	[0:`ISSUE_WIDTH-1]	;    
	wire	[`PRF_WIDTH-1:0] 	rdb_addr	[0:`ISSUE_WIDTH-1]	;    
	wire	[`PRF_WIDTH-1:0] 	wr_addr		[0:`ISSUE_WIDTH-1]	;    
  	wire	[`XLEN-1:0] 		wr_data		[0:`ISSUE_WIDTH-1]	;     
  	wire	[`ISSUE_WIDTH-1:0]  wr_en							;
  	wire	[`XLEN-1:0]	 		rda_out		[0:`ISSUE_WIDTH-1]	;    
  	wire 	[`XLEN-1:0] 		rdb_out 	[0:`ISSUE_WIDTH-1]	;

	REG_READ_PACKET	 			pipe_reg_read_pkt	[0:`ISSUE_WIDTH-1]	;    

	/*********************************FU Declaration*******************************/
	EXECUTE_PACKET				execute_pkt			[0:`ISSUE_WIDTH-1]; 
	EXECUTE_PACKET				pipe_execute_pkt	[0:`ISSUE_WIDTH-1]; 
	
	
	/********************************CDB Declaration*******************************/
	wire [`ISSUE_WIDTH-1:0]		cdb_valid;
	wire [`XLEN-1:0]			cdb_pc		[0:`ISSUE_WIDTH-1];
	wire [`ROB_WIDTH:0]			cdb_rob		[0:`ISSUE_WIDTH-1];
	wire [`PRF_WIDTH-1:0]		cdb_prn		[0:`ISSUE_WIDTH-1];
	wire [`XLEN-1:0]			cdb_result	[0:`ISSUE_WIDTH-1];
	wire						cdb_branch_misp;
	wire [`XLEN-1:0]			cdb_redirect_pc;
	//wire [`STQ_WIDTH-1:0]		cdb_st_addr_stq;
	//wire [`STQ_WIDTH-1:0]		cdb_st_data_stq;
	//wire [2:0]				cdb_st_data_size;
	//wire [`XLEN-1:0]			cdb_st_data;
	//wire [`XLEN-1:0]			cdb_st_addr;
	//wire 						cdb_st_data_valid;
	//wire 						cdb_st_addr_valid;

	/******************************Arch_rat Declaration****************************/
	wire [`ARF_WIDTH-1:0]		retire_dest_arn	[0:`MACHINE_WIDTH-1];
	wire [`PRF_WIDTH-1:0]		retire_dest_prn	[0:`MACHINE_WIDTH-1];
	wire [`MACHINE_WIDTH-1:0]	retire_valid						;
	wire [`PRF_WIDTH-1:0]		arch_rat_out	[0:`ARF_DEPTH-1]	;

	wire						retire_exception;
	wire 						retire_br_misp;
	wire [`XLEN-1:0]			retire_redirect_pc;

	/*************************Pipeline control Declaration*************************/
	wire						pipe_flush;
	reg							recov_arch_st;
	reg							sys_exception;


 
//////////////////////////////////////////////////
//                                              //
//           Decode and Rename Stage	  	    //
//                                              //
//////////////////////////////////////////////////
	decode_rename u_decode_rename(         
		.clk					(clk						),              	
		.rst_n					(rst_n						),              	
    	                		                			
		.fetch_pkt				(decode_rename_fetch_pkt	),
		.fetch_pkt_ready		(decode_rename_ready		),
		                		                			
		.rename_pkt				(rename_pkt					),
		.rename_pkt_ready		(rename_pkt_ready			),	
    	                	                	
		.retire_prn_prev		(retire_dest_prn_prev		),
		.retire_prn_prev_valid	(retire_dest_prn_prev_valid	),	
		.retire_prn_prev_ready	(retire_dest_prn_prev_ready	),

		.execute_prn			(execute_prn				),		
		.execute_valid			(execute_valid				),

		.arch_rat				(arch_rat_out				),
		.recov_arch_st			(recov_arch_st				)	
	);


	ptab u_ptab(         
		.clk					(clk					),
		.rst_n					(rst_n					),
		.pipe_flush				(pipe_flush				),
		.fetch_pkt				(ptab_fetch_pkt			),
		.fetch_pkt_ready		(ptab_ready				),
		.ptab_tag				(ptab_tag				),
    	                                               
		.bru_ptab_tag			(bru_ptab_tag			),
		.bru_branch_dir			(bru_branch_dir			),
		.bru_target_pc			(bru_target_pc			),
		.bru_valid				(bru_valid				),
		.bru_branch_misp		(bru_branch_misp		),
		.bru_next_pc            (bru_next_pc            )
	);                          


	assign bru_ptab_tag		= pipe_reg_read_pkt[5].ptab_tag;				
	assign bru_branch_dir	= execute_pkt[5].branch_dir;					
	assign bru_target_pc	= execute_pkt[5].target_pc;						
	assign bru_valid		= execute_pkt[5].packet_valid;						


	assign fetch_pkt_ready = ptab_ready ? decode_rename_ready : 0;

	genvar i;
	generate	
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			assign execute_prn[i] 	= cdb_prn[i]; 
			assign execute_valid[i] = cdb_valid[i]; 
		end

		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign retire_dest_prn_prev[i]			= pipe_retire_pkt[i].dest_prn_prev; 
			assign retire_dest_prn_prev_valid[i]	= pipe_retire_pkt[i].packet_valid; 
			
			assign decode_rename_fetch_pkt[i] = fetch_pkt[i].packet_valid && ptab_ready ? fetch_pkt[i] : 0;
			assign ptab_fetch_pkt[i] = fetch_pkt[i].packet_valid && decode_rename_ready==4'b1111 ? fetch_pkt[i] : 0;
		end
	endgenerate


//////////////////////////////////////////////////
//                                              //
//      Rename/Dispatch Pipeline Register       //
//                                              //
//////////////////////////////////////////////////
	RENAME_PACKET			pipe_rename_pkt 	[0:`MACHINE_WIDTH-1];
	reg [`PTAB_WIDTH-1:0]	pipe_ptab_tag		[0:`MACHINE_WIDTH-1];

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin 
			foreach(pipe_rename_pkt[i]) begin
				pipe_rename_pkt[i] 	<= 0;
				pipe_ptab_tag[i] 	<= 0;
			end
		end
		else if(pipe_flush)begin
			foreach(pipe_rename_pkt[i]) begin
				pipe_rename_pkt[i] 	<= 0;
				pipe_ptab_tag[i] 	<= 0;
			end
		end
		else if(rename_pkt_ready==4'b1111)begin
			pipe_rename_pkt <= rename_pkt;
			pipe_ptab_tag 	<= ptab_tag;
		end
		else begin
			foreach(pipe_rename_pkt[i]) begin
				pipe_rename_pkt[i] 	<= 0;
				pipe_ptab_tag[i] 	<= 0;
			end
		end
	end

//////////////////////////////////////////////////
//                                              //
//          	  Dispatch Stage	  	        //
//                                              //
//////////////////////////////////////////////////
	rob u_rob(
		.clk					(clk				   ),
		.rst_n					(rst_n				   ),
		.pipe_flush				(pipe_flush			   ),
		                                               
		.dispatch_pkt			(dispatch_rob_pkt	   ),
		.dispatch_pkt_ready		(dispatch_rob_pkt_ready),
		.dispatch_pkt_resp		(dispatch_rob_pkt_resp ),	
		.retire_pkt				(retire_pkt			   ),
		                                               
		.writeback_rob_tag		(cdb_rob	   		   ),
		.writeback_valid		(cdb_valid			   ),
		.writeback_br_misp      (cdb_branch_misp	   ),
		.writeback_redirect_pc	(cdb_redirect_pc	   )
	);


	lsq u_lsq(	
		.clk					(clk					),
		.rst_n					(rst_n					),
		.pipe_flush				(pipe_flush				),
		                    	                    
		.dispatch_pkt			(dispatch_lsq_pkt		),
		.dispatch_pkt_ready		(dispatch_lsq_pkt_ready	),
		.dispatch_stq_resp		(dispatch_stq_resp		),
		.dispatch_ldq_resp		(dispatch_ldq_resp		),
		.execute_pkt			(pipe_execute_pkt[6]	),
		.retire_pkt				(pipe_retire_pkt		),
		                    	                    
		.fire_st_addr			(fire_st_addr			),
		.fire_st_data			(fire_st_data			),
		.fire_st_data_size		(fire_st_data_size		),
		.fire_st_stq_tag		(fire_st_stq_tag		),
		.fire_st_valid			(fire_st_valid			),
		.fire_st_ready			(fire_st_ready			),
		                    	                    	
		.fire_ld_addr			(fire_ld_addr			),
		.fire_ld_data_size		(fire_ld_data_size		),
		.fire_ld_ldq_tag		(fire_ld_ldq_tag		),
		.fire_ld_valid			(fire_ld_valid			),
		.fire_ld_ready			(fire_ld_ready			),
		.fire_ld_kill       	(fire_ld_kill       	),

		.dcache_data			(dcache_data			),
		.dcache_ldq_tag			(dcache_ldq_tag			),
		.dcache_valid			(dcache_valid			),
		.dcache_ready			(dcache_ready			),
		                   	                       	
		.writeback_data			(writeback_lsq_data		),
		.writeback_pc			(writeback_lsq_pc		),
		.writeback_dest_prn		(writeback_lsq_dest_prn	),
		.writeback_rob_tag		(writeback_lsq_rob_tag	),	
		.writeback_valid		(writeback_lsq_valid	),
		.writeback_ready		(writeback_lsq_ready	)

	);
	
	



	generate	
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign dispatch_lsq_pkt[i].rd_mem			=	pipe_rename_pkt[i].rd_mem 		;
			assign dispatch_lsq_pkt[i].wr_mem			=	pipe_rename_pkt[i].wr_mem 		;
			assign dispatch_lsq_pkt[i].packet_valid		=	pipe_rename_pkt[i].packet_valid	;  

			assign dispatch_rob_pkt[i].inst		 		=	pipe_rename_pkt[i].inst		 	;  
			assign dispatch_rob_pkt[i].pc		 		=	pipe_rename_pkt[i].pc		 	;  
			assign dispatch_rob_pkt[i].dest_arn 		=	pipe_rename_pkt[i].dest_arn 		;  
			assign dispatch_rob_pkt[i].dest_prn 		=	pipe_rename_pkt[i].dest_prn 		;  
			assign dispatch_rob_pkt[i].dest_prn_prev 	=	pipe_rename_pkt[i].dest_prn_prev ;  
			assign dispatch_rob_pkt[i].stq_tag 			=	dispatch_stq_resp[i] ;  
			assign dispatch_rob_pkt[i].ldq_tag 			=	dispatch_ldq_resp[i] ;  
			assign dispatch_rob_pkt[i].rd_mem 			=	pipe_rename_pkt[i].rd_mem 		;  
			assign dispatch_rob_pkt[i].wr_mem 			=	pipe_rename_pkt[i].wr_mem 		;  
			assign dispatch_rob_pkt[i].cond_branch 		=	pipe_rename_pkt[i].cond_branch 	;  
			assign dispatch_rob_pkt[i].uncond_branch 	=	pipe_rename_pkt[i].uncond_branch ;  
			assign dispatch_rob_pkt[i].halt 			=	pipe_rename_pkt[i].halt 			;  
			assign dispatch_rob_pkt[i].illegal 			=	pipe_rename_pkt[i].illegal 		;  
			assign dispatch_rob_pkt[i].packet_valid		=	pipe_rename_pkt[i].packet_valid	;  


			assign dispatch_rs_pkt[i].inst				=	pipe_rename_pkt[i].inst			;	
			assign dispatch_rs_pkt[i].pc		 		=	pipe_rename_pkt[i].pc	 		;    
			assign dispatch_rs_pkt[i].op_type  			=	pipe_rename_pkt[i].op_type  		;       
			assign dispatch_rs_pkt[i].op1_prn 			=	pipe_rename_pkt[i].op1_prn 		;    
			assign dispatch_rs_pkt[i].op2_prn			=	pipe_rename_pkt[i].op2_prn		;    
			assign dispatch_rs_pkt[i].use_op1_prn 		=	pipe_rename_pkt[i].use_op1_prn   ;    
			assign dispatch_rs_pkt[i].use_op2_prn 		=	pipe_rename_pkt[i].use_op2_prn   ;    
			assign dispatch_rs_pkt[i].dest_prn 			=	pipe_rename_pkt[i].dest_prn 		;       
			assign dispatch_rs_pkt[i].op1_select		=	pipe_rename_pkt[i].op1_select	;    
			assign dispatch_rs_pkt[i].op2_select		=	pipe_rename_pkt[i].op2_select	;    
			assign dispatch_rs_pkt[i].rd_mem 			=	pipe_rename_pkt[i].rd_mem 		;    
			assign dispatch_rs_pkt[i].wr_mem 			=	pipe_rename_pkt[i].wr_mem 		;    
			assign dispatch_rs_pkt[i].cond_branch 		=	pipe_rename_pkt[i].cond_branch   ;    
			assign dispatch_rs_pkt[i].uncond_branch 	=	pipe_rename_pkt[i].uncond_branch ;    
			assign dispatch_rs_pkt[i].rob_entry			=	dispatch_rob_pkt_resp[i]	;   
			assign dispatch_rs_pkt[i].op1_ready 		=	pipe_rename_pkt[i].op1_ready 	;    
			assign dispatch_rs_pkt[i].op2_ready 		=	pipe_rename_pkt[i].op2_ready 	;    
			assign dispatch_rs_pkt[i].fu_id				=	pipe_rename_pkt[i].fu_id			;       
			assign dispatch_rs_pkt[i].ptab_tag			=	pipe_ptab_tag[i]					;       
			assign dispatch_rs_pkt[i].stq_tag 			=	dispatch_stq_resp[i] ;  
			assign dispatch_rs_pkt[i].ldq_tag 			=	dispatch_ldq_resp[i] ;  
			//discard illegal, halt and nop instr     	
			assign dispatch_rs_pkt[i].packet_valid		=	pipe_rename_pkt[i].packet_valid &&
		   													~pipe_rename_pkt[i].halt &&	  
		   													~pipe_rename_pkt[i].illegal &&
															pipe_rename_pkt[i].inst!=`NOP;  
		end
	endgenerate






	generate	//allocate instrs
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign int_dispatch_pkt[i] = dispatch_rs_pkt[i].fu_id != AGU_0 ? dispatch_rs_pkt[i] : 0;
			assign mem_dispatch_pkt[i] = dispatch_rs_pkt[i].fu_id == AGU_0 ? dispatch_rs_pkt[i] : 0;
		end
	endgenerate

	rs_bank #(
		.RS_DEPTH(`RS_DEPTH_INT))
	u_rs_bank_int(
		.clk					(clk					),
		.rst_n					(rst_n					),
		.pipe_flush				(pipe_flush				),
		.dispatch_pkt			(int_dispatch_pkt		),
		.dispatch_pkt_ready		(int_dispatch_pkt_ready	),
		.cdb_valid				(cdb_valid				),
		.cdb_prn				(cdb_prn				),
		                    	                   
		.issue_pkt				(int_issue_pkt			),
		.rs_avail_cnt			(), 
		.rs_full				()
	);

 
	rs_bank #(
		.RS_DEPTH(`RS_DEPTH_MEM))
	u_rs_bank_mem(
		.clk					(clk					),
		.rst_n					(rst_n					),
		.pipe_flush				(pipe_flush				),
		.dispatch_pkt			(mem_dispatch_pkt		),
		.dispatch_pkt_ready		(mem_dispatch_pkt_ready	),
		.cdb_valid				(cdb_valid				),
		.cdb_prn				(cdb_prn				),
		                    	                   
		.issue_pkt				(mem_issue_pkt			),
		.rs_avail_cnt			(), 
		.rs_full				()
	);


	ISSUE_PACKET				issue_pkt 	[0:`ISSUE_WIDTH-1];
	assign issue_pkt[0:5]	=	int_issue_pkt[0:5];
	assign issue_pkt[6]		=	mem_issue_pkt[6];
	assign rename_pkt_ready	=	sys_exception|retire_exception|~dispatch_lsq_pkt_ready ? 4'b0000 :
								int_dispatch_pkt_ready & 
								mem_dispatch_pkt_ready & 
								dispatch_rob_pkt_ready ;





//////////////////////////////////////////////////
//                                              //
//       Issue/Read Reg Pipeline Register       //
//                                              //
//////////////////////////////////////////////////
	ISSUE_PACKET			pipe_issue_pkt 	[0:`ISSUE_WIDTH-1];

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin 
			foreach(pipe_issue_pkt[i])
				pipe_issue_pkt[i] <= 0;
		end
		else if(pipe_flush) begin
			foreach(pipe_issue_pkt[i])
				pipe_issue_pkt[i] <= 0;
		end
		else begin
			pipe_issue_pkt <= issue_pkt;
		end
	end



//////////////////////////////////////////////////
//                                              //
//             Register Read Stage		        //
//                                              //
//////////////////////////////////////////////////
  	REG_READ_PACKET	 		reg_read_pkt	[0:`ISSUE_WIDTH-1]	;  

	generate	
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			assign rda_addr[i] = pipe_issue_pkt[i].op1_prn;
			assign rdb_addr[i] = pipe_issue_pkt[i].op2_prn;
		end
	endgenerate

	assign wr_addr		= cdb_prn;
	assign wr_data		= cdb_result;
	assign wr_en		= cdb_valid;

	prf u_prf(
		.clk		 (clk		),
		.rst_n		 (rst_n		),
		.rda_addr	 (rda_addr	),    
		.rdb_addr	 (rdb_addr	),    
		.wr_addr	 (wr_addr	),    
  		.wr_data	 (wr_data	),     
  		.wr_en		 (wr_en		),
  		.rda_out	 (rda_out	),    
  		.rdb_out 	 (rdb_out 	)
	);

	generate	
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			assign reg_read_pkt[i].inst				=	pipe_issue_pkt[i].inst			;
			assign reg_read_pkt[i].pc		 		=	pipe_issue_pkt[i].pc		 	;
			assign reg_read_pkt[i].op_type  		=	pipe_issue_pkt[i].op_type  		;
			assign reg_read_pkt[i].op1_val 			=	rda_out[i] 		   			    ;
			assign reg_read_pkt[i].op2_val			=	rdb_out[i]			   			;
			assign reg_read_pkt[i].dest_prn 		=	pipe_issue_pkt[i].dest_prn 		;
			assign reg_read_pkt[i].op1_select		=	pipe_issue_pkt[i].op1_select	;
			assign reg_read_pkt[i].op2_select		=	pipe_issue_pkt[i].op2_select	;
			assign reg_read_pkt[i].rd_mem 			=	pipe_issue_pkt[i].rd_mem 		;
			assign reg_read_pkt[i].wr_mem 			=	pipe_issue_pkt[i].wr_mem 		;
			assign reg_read_pkt[i].cond_branch 		=	pipe_issue_pkt[i].cond_branch 	;
			assign reg_read_pkt[i].uncond_branch	=	pipe_issue_pkt[i].uncond_branch	;
		//	assign reg_read_pkt[i].halt 			=	pipe_issue_pkt[i].halt 			;
		//	assign reg_read_pkt[i].illegal 			=	pipe_issue_pkt[i].illegal 		;
			assign reg_read_pkt[i].rob_entry		=	pipe_issue_pkt[i].rob_entry		;
			assign reg_read_pkt[i].fu_id			=	pipe_issue_pkt[i].fu_id			;
			assign reg_read_pkt[i].ptab_tag			=	pipe_issue_pkt[i].ptab_tag		;
			assign reg_read_pkt[i].stq_tag			=	pipe_issue_pkt[i].stq_tag		;
			assign reg_read_pkt[i].ldq_tag			=	pipe_issue_pkt[i].ldq_tag		;
			assign reg_read_pkt[i].packet_valid		=	pipe_issue_pkt[i].packet_valid	;
		end
	endgenerate



                                        
//////////////////////////////////////////////////
//                                              //
//             PRF/FU Pipeline Register         //
//                                              //
//////////////////////////////////////////////////
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
	   		foreach(pipe_reg_read_pkt[i])
				pipe_reg_read_pkt[i] <= 0;	
		end
		else if(pipe_flush) begin
	   		foreach(pipe_reg_read_pkt[i])
				pipe_reg_read_pkt[i] <= 0;	
		end
		else begin
			pipe_reg_read_pkt	<= reg_read_pkt	;
		end
	end



//////////////////////////////////////////////////
//                                              //
//             	 Execution Stage		        //
//                                              //
//////////////////////////////////////////////////

	fu_top u_fu_top(
		.clk			(clk				),
		.rst_n			(rst_n				),
		.pipe_flush		(pipe_flush			),
  		.reg_read_pkt	(pipe_reg_read_pkt	),    
  		.execute_pkt	(execute_pkt		)	 
	);


//////////////////////////////////////////////////
//                                              //
//             FU/WB Pipeline Register          //
//                                              //
//////////////////////////////////////////////////
	reg				pipe_bru_branch_misp;
	reg	[`XLEN-1:0]	pipe_bru_redirect_pc;

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
	   		foreach(pipe_execute_pkt[i])
				pipe_execute_pkt[i] <= 0;
			pipe_bru_branch_misp <= 0;
			pipe_bru_redirect_pc <= 0;
		end
		else if(pipe_flush)begin
	   		foreach(pipe_execute_pkt[i])
				pipe_execute_pkt[i] <= 0;
			pipe_bru_branch_misp <= 0;
			pipe_bru_redirect_pc <= 0;
		end
		else begin
			pipe_execute_pkt	 <= execute_pkt	;
			pipe_bru_branch_misp <= bru_branch_misp;
			pipe_bru_redirect_pc <= bru_next_pc;
		end
	end	


//////////////////////////////////////////////////
//                                              //
//             	 Writeback Stage		        //
//                                              //
//////////////////////////////////////////////////
   	assign  cdb_branch_misp 	=   pipe_bru_branch_misp;	
	assign  cdb_redirect_pc 	=   pipe_bru_redirect_pc;	

	//assign	cdb_st_addr			=	pipe_execute_pkt[6].result;
	//assign	cdb_st_addr_stq		=	pipe_execute_pkt[6].stq_tag;
	//assign	cdb_st_addr_valid	=	pipe_execute_pkt[6].packet_valid;
	//assign	cdb_st_data			=	pipe_execute_pkt[6].st_data;
	//assign	cdb_st_data_stq		=	pipe_execute_pkt[6].stq_tag;
	//assign	cdb_st_data_size	=	pipe_execute_pkt[6].mem_size;	
	//assign	cdb_st_data_valid	=	pipe_execute_pkt[6].packet_valid;

	//if store is broadcasting on cdb then load data must wait until cdb is free
	assign writeback_lsq_ready = ~(pipe_execute_pkt[6].packet_valid && pipe_execute_pkt[6].wr_mem);

	generate	
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			if(i==6) begin
				//only broadcast store coming from the execute stage
				assign	cdb_result[i]	=	pipe_execute_pkt[i].packet_valid && pipe_execute_pkt[i].wr_mem ? pipe_execute_pkt[i].result	  		: writeback_lsq_data 	    ;
				assign	cdb_pc[i]		=	pipe_execute_pkt[i].packet_valid && pipe_execute_pkt[i].wr_mem ? pipe_execute_pkt[i].pc	      		: writeback_lsq_pc	 	    ;
				assign	cdb_rob[i]		=	pipe_execute_pkt[i].packet_valid && pipe_execute_pkt[i].wr_mem ? pipe_execute_pkt[i].rob_entry   	: writeback_lsq_rob_tag 	;  
				assign	cdb_prn[i]		=	pipe_execute_pkt[i].packet_valid && pipe_execute_pkt[i].wr_mem ? pipe_execute_pkt[i].dest_prn		: writeback_lsq_dest_prn	;
				assign	cdb_valid[i]	=	pipe_execute_pkt[i].packet_valid && pipe_execute_pkt[i].wr_mem ? pipe_execute_pkt[i].packet_valid	: writeback_lsq_valid 		;
			end
			else begin
				assign	cdb_result[i]	=	pipe_execute_pkt[i].result;	 
				assign	cdb_pc[i]		=	pipe_execute_pkt[i].pc;	 
				assign	cdb_rob[i]		=	pipe_execute_pkt[i].rob_entry;	 
				assign	cdb_prn[i]		=	pipe_execute_pkt[i].dest_prn;	
				assign	cdb_valid[i]	=	pipe_execute_pkt[i].packet_valid;	
			end
		end
	endgenerate

	//assert property (@(posedge clk) pipe_execute_pkt[6].packet_valid&&pipe_execute_pkt[6].wr_mem |-> writeback_lsq_valid==0);


//////////////////////////////////////////////////
//                                              //
//          	   Retire Stage	  	            //
//                                              //
//////////////////////////////////////////////////
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
	   		foreach(pipe_retire_pkt[i])
				pipe_retire_pkt[i] <= 0;	
		end
		else if(pipe_flush) begin
	   		foreach(pipe_retire_pkt[i])
				pipe_retire_pkt[i] <= 0;	
		end
		else begin
			pipe_retire_pkt	<= retire_pkt;
		end
	end



	assign retire_exception = 	(pipe_retire_pkt[0].packet_valid && pipe_retire_pkt[0].exception!=NO_ERROR) ||
								(pipe_retire_pkt[1].packet_valid && pipe_retire_pkt[1].exception!=NO_ERROR) ||
								(pipe_retire_pkt[2].packet_valid && pipe_retire_pkt[2].exception!=NO_ERROR) ||
								(pipe_retire_pkt[3].packet_valid && pipe_retire_pkt[3].exception!=NO_ERROR) ;
	assign retire_br_misp = 	(pipe_retire_pkt[0].packet_valid && pipe_retire_pkt[0].branch_misp) ||
								(pipe_retire_pkt[1].packet_valid && pipe_retire_pkt[1].branch_misp) ||
								(pipe_retire_pkt[2].packet_valid && pipe_retire_pkt[2].branch_misp) ||
								(pipe_retire_pkt[3].packet_valid && pipe_retire_pkt[3].branch_misp) ;
	assign retire_redirect_pc = (pipe_retire_pkt[0].packet_valid && pipe_retire_pkt[0].branch_misp) ? pipe_retire_pkt[0].redirect_pc :
								(pipe_retire_pkt[1].packet_valid && pipe_retire_pkt[1].branch_misp) ? pipe_retire_pkt[1].redirect_pc :
								(pipe_retire_pkt[2].packet_valid && pipe_retire_pkt[2].branch_misp) ? pipe_retire_pkt[2].redirect_pc :
								(pipe_retire_pkt[3].packet_valid && pipe_retire_pkt[3].branch_misp) ? pipe_retire_pkt[3].redirect_pc :
								0;
							
	assign fetch_br_misp 		= retire_br_misp;
	assign fetch_redirect_pc 	= retire_redirect_pc;
	assign pipe_flush 			= retire_br_misp || retire_exception;
	

	
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			recov_arch_st <= 0;  
		else if(pipe_flush)
			recov_arch_st <= 1; //must be 1 cycle behind flush, wait retired instr updates arch rat before recovery
								//T_back_recv < T_front_recov
		else
			recov_arch_st <= 0;
	end

	generate	
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign retire_dest_arn[i] 	= pipe_retire_pkt[i].dest_arn;
			assign retire_dest_prn[i] 	= pipe_retire_pkt[i].dest_prn;
			assign retire_valid[i] 		= pipe_retire_pkt[i].packet_valid;
		end                                         
	endgenerate

	arch_rat u_arch_rat(
		.clk				(clk				),
		.rst_n				(rst_n				),
		                                        
		.retire_dest_arn	(retire_dest_arn	),
		.retire_dest_prn	(retire_dest_prn	),
		.retire_valid		(retire_valid		),
		                                        
		.arch_rat_out		(arch_rat_out		)	
	);

	

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			sys_exception <= 0;
		else if(retire_exception)	
			sys_exception <= 1;
	end




endmodule
