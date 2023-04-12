//TODO write assertion check
`timescale 1ns/100ps


module decode_rename(         
	input         					clk,              	
	input         					rst_n,              	

	input  	FETCH_PACKET 			fetch_pkt				[0:`MACHINE_WIDTH-1],
	output  [`MACHINE_WIDTH-1:0]    fetch_pkt_ready								,
	
	output 	RENAME_PACKET 			rename_pkt				[0:`MACHINE_WIDTH-1],
	input	[`MACHINE_WIDTH-1:0]	rename_pkt_ready							,	

	input	[`PRF_WIDTH-1:0] 		retire_prn_prev			[0:`MACHINE_WIDTH-1],
	input	[`MACHINE_WIDTH-1:0]	retire_prn_prev_valid						,	
	output  [`MACHINE_WIDTH-1:0]    retire_prn_prev_ready						,

	input	[`PRF_WIDTH-1:0] 		execute_prn				[0:`ISSUE_WIDTH-1]	,
	input	[`ISSUE_WIDTH-1:0]		execute_valid								,

	input	[`PRF_WIDTH-1:0]		arch_rat				[0:`ARF_DEPTH-1]	,
	input							recov_arch_st
);


	DECODE_PACKET 	decode_pkt	[0:`MACHINE_WIDTH-1];


	wire 	[`ARF_WIDTH-1:0] 		ar_src1			[0:`MACHINE_WIDTH-1];
	wire 	[`ARF_WIDTH-1:0] 		ar_src2			[0:`MACHINE_WIDTH-1];
	wire	[`ARF_WIDTH-1:0] 		ar_dest			[0:`MACHINE_WIDTH-1];
	wire 	[`MACHINE_WIDTH-1:0]	ar_src1_sel							;
	wire 	[`MACHINE_WIDTH-1:0]	ar_src2_sel							;
			DEST_REG_SEL	 		ar_dest_sel		[0:`MACHINE_WIDTH-1];
	wire 	[`MACHINE_WIDTH-1:0]	ar_valid							;	
	wire 	[`MACHINE_WIDTH-1:0]    ar_ready							;	
	wire 	[`PRF_WIDTH-1:0] 		pr_src1			[0:`MACHINE_WIDTH-1];
	wire 	[`PRF_WIDTH-1:0] 		pr_src2			[0:`MACHINE_WIDTH-1];
	wire	[`PRF_WIDTH-1:0] 		pr_dest			[0:`MACHINE_WIDTH-1];
	wire 	[`PRF_WIDTH-1:0] 		pr_dest_prev	[0:`MACHINE_WIDTH-1];
	wire 	[`MACHINE_WIDTH-1:0]	pr_valid							;	
	wire	[`MACHINE_WIDTH-1:0]	pr_ready							;
	
	wire 	[`PRF_WIDTH-1:0] 		free_prn			[0:`MACHINE_WIDTH-1];
	wire 	[`MACHINE_WIDTH-1:0]	free_prn_valid							;	
	wire	[`MACHINE_WIDTH-1:0]	free_prn_ready							;	
	
	wire	[`MACHINE_WIDTH-1:0]	pr_src1_data_ready						;	
	wire	[`MACHINE_WIDTH-1:0]	pr_src2_data_ready						;	
  

	genvar i;
	generate 
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			//always@(posedge clk or negedge rst_n) begin
			//	if(~rst_n) begin
			//		rename_pkt[i].inst				<= 0;
    		//    	rename_pkt[i].pc				<= 0;
    		//    	rename_pkt[i].op_type			<= ALU_ADD;
    		//    	rename_pkt[i].use_op1_prn		<= 0;
    		//    	rename_pkt[i].use_op2_prn		<= 0;
    		//    	rename_pkt[i].dest_arn			<= 0;
    		//    	rename_pkt[i].op1_select		<= OPA_IS_RS1;
    		//    	rename_pkt[i].op2_select		<= OPB_IS_RS2;
    		//    	rename_pkt[i].rd_mem 			<= 0;
    		//    	rename_pkt[i].wr_mem 			<= 0;
    		//    	rename_pkt[i].cond_branch 		<= 0;
    		//    	rename_pkt[i].uncond_branch 	<= 0;
    		//    	rename_pkt[i].halt 				<= 0;
    		//    	rename_pkt[i].illegal 			<= 0;
    		//    //	rename_pkt[i].rob_entry			<= 0;
    		//    	rename_pkt[i].fu_id				<= ALU_0;
			//	end
			//	else begin
			//		rename_pkt[i].inst				<= decode_pkt[i].inst			;
			//		rename_pkt[i].pc				<= decode_pkt[i].pc				;
			//		rename_pkt[i].op_type			<= decode_pkt[i].op_type		;
			//		rename_pkt[i].use_op1_prn		<= decode_pkt[i].use_op1_arn	;
			//		rename_pkt[i].use_op2_prn		<= decode_pkt[i].use_op2_arn	;
    		//    	rename_pkt[i].dest_arn			<= decode_pkt[i].dest_arn		;
			//		rename_pkt[i].op1_select		<= decode_pkt[i].op1_select		;
			//		rename_pkt[i].op2_select		<= decode_pkt[i].op2_select		;
			//		rename_pkt[i].rd_mem 			<= decode_pkt[i].rd_mem 		;
			//		rename_pkt[i].wr_mem 			<= decode_pkt[i].wr_mem 		;
			//		rename_pkt[i].cond_branch 		<= decode_pkt[i].cond_branch 	;
			//		rename_pkt[i].uncond_branch		<= decode_pkt[i].uncond_branch	;
			//		rename_pkt[i].halt 				<= decode_pkt[i].halt 			;
			//		rename_pkt[i].illegal 			<= decode_pkt[i].illegal 		;
    		//    //	rename_pkt[i].rob_entry			<= 0;
			//		rename_pkt[i].fu_id				<= decode_pkt[i].fu_id			;
			//	end
			//end

			assign ar_src1[i] 			= decode_pkt[i].op1_arn			;
			assign ar_src2[i]			= decode_pkt[i].op2_arn			;
			assign ar_dest[i]			= decode_pkt[i].dest_arn		;		
			assign ar_src1_sel[i]		= decode_pkt[i].use_op1_arn		;
			assign ar_src2_sel[i]		= decode_pkt[i].use_op2_arn		;
			assign ar_dest_sel[i]		= decode_pkt[i].dest_select		;
			assign ar_valid[i]			= decode_pkt[i].packet_valid	;   	
			assign fetch_pkt_ready[i] 	= ar_ready[i]					;   

			assign rename_pkt[i].inst			= decode_pkt[i].inst			;
			assign rename_pkt[i].pc				= decode_pkt[i].pc				;
			assign rename_pkt[i].op_type		= decode_pkt[i].op_type		    ;
			assign rename_pkt[i].use_op1_prn	= decode_pkt[i].use_op1_arn	    ;
			assign rename_pkt[i].use_op2_prn	= decode_pkt[i].use_op2_arn	    ;
			assign rename_pkt[i].dest_arn		= decode_pkt[i].dest_arn		;
			assign rename_pkt[i].op1_select		= decode_pkt[i].op1_select		;
			assign rename_pkt[i].op2_select		= decode_pkt[i].op2_select		;
			assign rename_pkt[i].rd_mem 		= decode_pkt[i].rd_mem 		    ;
			assign rename_pkt[i].wr_mem 		= decode_pkt[i].wr_mem 		    ;
			assign rename_pkt[i].cond_branch 	= decode_pkt[i].cond_branch 	;
			assign rename_pkt[i].uncond_branch	= decode_pkt[i].uncond_branch	;
			assign rename_pkt[i].halt 			= decode_pkt[i].halt 			;
			assign rename_pkt[i].illegal 		= decode_pkt[i].illegal 		;
			assign rename_pkt[i].fu_id			= decode_pkt[i].fu_id			;

			assign rename_pkt[i].op1_prn		= pr_src1[i]			;
			assign rename_pkt[i].op2_prn		= pr_src2[i]			;
			assign rename_pkt[i].op1_ready		= pr_src1_data_ready[i]	;
			assign rename_pkt[i].op2_ready		= pr_src2_data_ready[i]	;
			assign rename_pkt[i].dest_prn		= pr_dest[i]			;   
			assign rename_pkt[i].dest_prn_prev	= pr_dest_prev[i]		;   
			assign rename_pkt[i].packet_valid	= pr_valid[i]			;   		
			assign pr_ready[i]					= rename_pkt_ready[i]	;

		end
	endgenerate



	decoder_top u_decoder_top(         
		.clk					(clk				),              	
		.rst_n					(rst_n				),              	
		.fetch_pkt				(fetch_pkt			),
		.decode_pkt				(decode_pkt			)
	);                  		                    
                        		                    
	rat u_rat(          		                    
		.clk					(clk				),
		.rst_n					(rst_n				),
		                		                        	
		.ar_src1				(ar_src1			),
		.ar_src2				(ar_src2			),
		.ar_dest				(ar_dest			),		
		.ar_src1_sel			(ar_src1_sel		),
		.ar_src2_sel			(ar_src2_sel		),
		.ar_dest_sel			(ar_dest_sel		),
		.ar_valid				(ar_valid			),	
		.ar_ready				(ar_ready			),	
		                		                	               
		.pr_src1				(pr_src1			),
		.pr_src2				(pr_src2			),
		.pr_dest				(pr_dest			),
		.pr_dest_prev			(pr_dest_prev		),
		.pr_valid				(pr_valid			),		
		.pr_ready				(pr_ready			),
			            		                
		.free_prn				(free_prn			),
		.free_prn_valid			(free_prn_valid		),		
		.free_prn_ready			(free_prn_ready		),

		.arch_rat				(arch_rat			),	
		.recov_arch_st			(recov_arch_st		)
	);

	free_list u_free_list(
		.clk					(clk					),
		.rst_n					(rst_n					),
    	                                        
		.retire_prn_prev		(retire_prn_prev		),		
		.retire_prn_prev_valid	(retire_prn_prev_valid	),		
		.retire_prn_prev_ready	(retire_prn_prev_ready	),		
    	                                        
		.free_prn				(free_prn				),
		.free_prn_valid			(free_prn_valid			),		
		.free_prn_ready			(free_prn_ready			),

		.arch_rat				(arch_rat				),	
		.recov_arch_st			(recov_arch_st			)	
	);

	busy_table u_busy_table(
		.clk					(clk				),
		.rst_n					(rst_n				),
		.pipe_flush				(recov_arch_st		),
    	                    	
		.free_prn				(free_prn			),
		.free_prn_valid			(free_prn_valid		),	
		.free_prn_ready			(free_prn_ready		),	
    	                    	
		.execute_prn			(execute_prn		),	
		.execute_valid			(execute_valid		),	
    	                    	
		.pr_src1				(pr_src1			),
		.pr_src2				(pr_src2			),
		.pr_src1_data_ready		(pr_src1_data_ready	),	
		.pr_src2_data_ready		(pr_src2_data_ready	)
	);


endmodule
