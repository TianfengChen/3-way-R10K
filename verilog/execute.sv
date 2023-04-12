`timescale 1ns/100ps

module execute (
	input									clk,
	input									rst_n,
	input									rs_nuke,
	input									dcache_hit,
	input RENAME_PACKET						rename_pkt 		[0:`MACHINE_WIDTH-1],
                                    		
//	output [`ISSUE_WIDTH-1:0]				cdb_valid,  	
//	output [`PRF_WIDTH-1:0]					cdb_tag			[0:`ISSUE_WIDTH-1],
	output reg [$clog2(`RS_DEPTH_INT):0] 	rs_avail_cnt, 
	output		 							rs_full
);


	/*********************************RS Declaration*******************************/
	RENAME_PACKET				int_rename_pkt 	[0:`MACHINE_WIDTH-1];
	RENAME_PACKET				mem_rename_pkt 	[0:`MACHINE_WIDTH-1];
	                			
	ISSUE_PACKET				int_issue_pkt 	[0:`ISSUE_WIDTH-1];
	ISSUE_PACKET				mem_issue_pkt 	[0:`ISSUE_WIDTH-1];
	
	wire [`MACHINE_WIDTH-1:0]	int_rename_pkt_ready;
	wire [`MACHINE_WIDTH-1:0]	mem_rename_pkt_ready;

	/********************************PRF Declaration*******************************/
	wire	[`PRF_WIDTH-1:0] 	rda_addr	[0:`ISSUE_WIDTH-1]	;    
	wire	[`PRF_WIDTH-1:0] 	rdb_addr	[0:`ISSUE_WIDTH-1]	;    
	wire	[`PRF_WIDTH-1:0] 	wr_addr		[0:`ISSUE_WIDTH-1]	;    
  	wire	[`XLEN-1:0] 		wr_data		[0:`ISSUE_WIDTH-1]	;     
  	wire	[`ISSUE_WIDTH-1:0]  wr_en							;
  	wire	[`XLEN-1:0]	 		rda_out		[0:`ISSUE_WIDTH-1]	;    
  	wire 	[`XLEN-1:0] 		rdb_out 	[0:`ISSUE_WIDTH-1]	;

	/*********************************FU Declaration*******************************/
	
	
	/********************************CDB Declaration*******************************/
	wire [`ISSUE_WIDTH-1:0]		cdb_valid;
	wire [`PRF_WIDTH-1:0]		cdb_tag		[0:`ISSUE_WIDTH-1];
	wire [`XLEN-1:0]			cdb_data	[0:`ISSUE_WIDTH-1];










//////////////////////////////////////////////////
//                                              //
//           	  Issue Stage	   			    //
//                                              //
//////////////////////////////////////////////////
	genvar i;
	generate	//allocate instrs
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign int_rename_pkt[i] = rename_pkt[i].fu_id != AGU_0 ?  rename_pkt[i] : 0;
			assign mem_rename_pkt[i] = rename_pkt[i].fu_id == AGU_0 ?  rename_pkt[i] : 0;
		end
	endgenerate

	rs_bank #(
		.RS_DEPTH(`RS_DEPTH_INT))
	u_rs_bank_int(
		.clk					(clk					),
		.rst_n					(rst_n					),
		.rename_pkt				(int_rename_pkt			),
		.rs_nuke				(rs_nuke				),
		.dcache_hit				(dcache_hit				),
		.cdb_valid				(cdb_valid				),
		.cdb_tag				(cdb_tag				),
		                    	                   
		.issue_pkt				(int_issue_pkt			),
		.rename_pkt_ready		(int_rename_pkt_ready	),
		.rs_avail_cnt			(), 
		.rs_full				()
	);

 
	rs_bank #(
		.RS_DEPTH(`RS_DEPTH_MEM))
	u_rs_bank_mem(
		.clk					(clk					),
		.rst_n					(rst_n					),
		.rename_pkt				(mem_rename_pkt			),
		.rs_nuke				(rs_nuke				),
		.dcache_hit				(dcache_hit				),
		.cdb_valid				(cdb_valid				),
		.cdb_tag				(cdb_tag				),
		                    	                   
		.issue_pkt				(mem_issue_pkt			),
		.rename_pkt_ready		(mem_rename_pkt_ready	),
		.rs_avail_cnt			(), 
		.rs_full				()
	);


	ISSUE_PACKET				issue_pkt 	[0:`ISSUE_WIDTH-1];
	assign issue_pkt[0:5]	=	int_issue_pkt[0:5];
	assign issue_pkt[6]		=	mem_issue_pkt[6];

//////////////////////////////////////////////////
//                                              //
//             RS/PRF Pipeline Register         //
//                                              //
//////////////////////////////////////////////////
	ISSUE_PACKET				pipe_issue_pkt 	[0:`ISSUE_WIDTH-1];

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin 
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

	assign wr_addr		= cdb_tag;
	assign wr_data		= cdb_data;
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
			assign reg_read_pkt[i].npc				=	pipe_issue_pkt[i].npc		 	;
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
			assign reg_read_pkt[i].halt 			=	pipe_issue_pkt[i].halt 			;
			assign reg_read_pkt[i].illegal 			=	pipe_issue_pkt[i].illegal 		;
			assign reg_read_pkt[i].rob_entry		=	pipe_issue_pkt[i].rob_entry		;
			assign reg_read_pkt[i].fu_id			=	pipe_issue_pkt[i].fu_id			;
			assign reg_read_pkt[i].packet_valid		=	pipe_issue_pkt[i].packet_valid	;
		end
	endgenerate



                                        
//////////////////////////////////////////////////
//                                              //
//             PRF/FU Pipeline Register         //
//                                              //
//////////////////////////////////////////////////
  	REG_READ_PACKET	 		pipe_reg_read_pkt	[0:`ISSUE_WIDTH-1]	;    

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
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
	EXECUTE_PACKET	execute_pkt	[0:`ISSUE_WIDTH-1]; 

	fu_top u_fu_top(
		.clk			(clk				),
		.rst_n			(rst_n				),
  		.reg_read_pkt	(pipe_reg_read_pkt	),    
  		.execute_pkt	(execute_pkt		)	 
	);


//////////////////////////////////////////////////
//                                              //
//             FU/WB Pipeline Register          //
//                                              //
//////////////////////////////////////////////////
	EXECUTE_PACKET	pipe_execute_pkt	[0:`ISSUE_WIDTH-1]; 

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
	   		foreach(pipe_execute_pkt[i])
				pipe_execute_pkt[i] <= 0;	
		end
		else begin
			pipe_execute_pkt	<= execute_pkt	;
		end
	end	


//////////////////////////////////////////////////
//                                              //
//             	 Writeback Stage		        //
//                                              //
//////////////////////////////////////////////////
	generate	
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			assign	cdb_data[i]		=	pipe_execute_pkt[i].result;	 
			assign	cdb_tag[i]		=	pipe_execute_pkt[i].dest_prn;	 
			assign	cdb_valid[i]	=	pipe_execute_pkt[i].packet_valid;	 
		end
	endgenerate



endmodule
