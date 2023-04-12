`ifndef __RS1_V__
`define __RS1_V__
`timescale 1ns/100ps


				
module rs1 (
	input        						clk,          	// the clock 							
	input        						rst_n,         	// reset signal	
	input								pipe_flush,	
	input								rs1_use_en,		// send signal to FU
	input			        			rs1_load,		// load inst into RS
	input [31:0]	        			inst_in,		// 
	input [31:0]	        			pc_in,			// 
	input ALU_FUNC 						op_type_in,		// from decoder
	input [`PRF_WIDTH-1:0] 				op1_prn_in,     // from rat 
	input [`PRF_WIDTH-1:0] 				op2_prn_in,     // from rat
	input 								op1_ready_in,	// from PRF valid bit 
	input 								op2_ready_in,	// from PRF valid bit 
	input 								use_op1_prn_in,	//  
	input 								use_op2_prn_in,	//  
	input [`PRF_WIDTH-1:0] 				dest_prn_in,    // from decoder
	input ALU_OPA_SELECT				op1_select_in,
	input ALU_OPB_SELECT				op2_select_in,
	input 								rd_mem_in,
	input 								wr_mem_in,
	input								cond_branch_in,
	input								uncond_branch_in,
	input [`ROB_WIDTH:0]  				rob_entry_in,	// from the tail of rob
	input FU_ID				 			fu_id_in,		// from decoder, does this inst use alu, mul, mem or bcond?
	input [`PTAB_WIDTH-1:0]				ptab_tag_in,
	input [`STQ_WIDTH-1:0]				stq_tag_in,
	input [`LDQ_WIDTH-1:0]				ldq_tag_in,
	input [`ISSUE_WIDTH-1:0]			cdb_valid,
	input [`PRF_WIDTH-1:0]				cdb_prn		[0:`ISSUE_WIDTH-1],
                                    	
	output reg [`ISSUE_WIDTH-1:0]		rs1_wake_up,   		// This RS is in use and ready to go to EX 
	output reg 							rs1_issued,   		 
	output       	 					rs1_avail,     		// This RS is available to be dispatched to
   	output [`ROB_WIDTH:0]				rs1_age,	
	output [31:0]						rs1_inst_out,   	// feed to fu
	output [31:0]						rs1_pc_out,    		// feed to fu
	output ALU_FUNC						rs1_op_type_out,    // feed to fu
	output [`PRF_WIDTH-1:0] 			rs1_op1_prn_out,   	// feed to PRF 
	output [`PRF_WIDTH-1:0] 			rs1_op2_prn_out,   	// feed to PRF
	output [`PRF_WIDTH-1:0] 			rs1_dest_prn_out,   // feed to PRF 
	output ALU_OPA_SELECT				rs1_op1_select_out,		
	output ALU_OPB_SELECT				rs1_op2_select_out,		
	output 								rs1_rd_mem_out,			
	output 								rs1_wr_mem_out,			
	output								rs1_cond_branch_out,	
	output								rs1_uncond_branch_out,	
	output [`ROB_WIDTH:0]		    	rs1_rob_entry_out,	// feed to ROB
	output FU_ID				  		rs1_fu_id_out,	// feed to fu, does this inst use alu, mul, mem or bcond?
	output [`PTAB_WIDTH-1:0]			rs1_ptab_tag_out,
	output [`STQ_WIDTH-1:0]				rs1_stq_tag_out,
	output [`LDQ_WIDTH-1:0]				rs1_ldq_tag_out
);

	reg [31:0]	        		inst;
	reg [31:0]	        		pc;
	ALU_FUNC					op_type;           
	reg [`PRF_WIDTH-1:0] 		op1_prn;       	// the physical register number the opa is pointed to
	reg [`PRF_WIDTH-1:0] 		op2_prn;       	// the physical register number the opb is pointed to 
	reg       					op1_ready;    	// Operand a Value is now ready in prf
	reg       					op2_ready;     	// Operand b Value is now ready in prf
	reg							use_op1_prn;
	reg							use_op2_prn;
	ALU_OPA_SELECT				op1_select;		
	ALU_OPB_SELECT				op2_select;		
	reg							rd_mem;			
	reg							wr_mem;			
	reg							cond_branch;	
	reg							uncond_branch;	
	reg       					in_use;        	// InUse bit 
	reg [`PRF_WIDTH-1:0] 		dest_prn;		// Destination physical register number 
	reg [`ROB_WIDTH:0]			rob_entry;		// ROB entry #
	FU_ID						fu_id;			// does this inst use alu, mul, mem or bcond?
	reg [`PTAB_WIDTH-1:0]		ptab_tag;
	reg [`STQ_WIDTH-1:0]		stq_tag;
	reg [`LDQ_WIDTH-1:0]		ldq_tag;
                            	

 	wire loadAfromPRF;			
 	wire loadBfromPRF;		
	wire op1_ready_fwd_cdb;
	wire op2_ready_fwd_cdb;
	wire rs1_free;
	wire [`ISSUE_WIDTH-1:0]		wake_up_tmp;

	wire [`ISSUE_WIDTH-1:0] 	op1_cdb_match;
	wire [`ISSUE_WIDTH-1:0] 	op2_cdb_match;
	wire [`ISSUE_WIDTH-1:0] 	op1_cdb_match_fwd;
	wire [`ISSUE_WIDTH-1:0] 	op2_cdb_match_fwd;
	wire [`ISSUE_WIDTH-1:0] 	dest_cdb_match;

	assign rs1_avail				= ~in_use;
	assign rs1_age					= rob_entry;
	assign rs1_inst_out 			= rs1_use_en ? inst : 32'b0;
	assign rs1_pc_out 				= rs1_use_en ? pc : 32'b0;
	assign rs1_op_type_out 			= rs1_use_en ? op_type : ALU_ADD;
	assign rs1_op1_prn_out 			= rs1_use_en ? op1_prn : {`PRF_WIDTH{1'b0}};
	assign rs1_op2_prn_out 			= rs1_use_en ? op2_prn : {`PRF_WIDTH{1'b0}};
	assign rs1_dest_prn_out 		= rs1_use_en ? dest_prn : {`PRF_WIDTH{1'b0}};
	assign rs1_op1_select_out		= rs1_use_en ? op1_select : OPA_IS_RS1;			
	assign rs1_op2_select_out		= rs1_use_en ? op2_select : OPB_IS_RS2;		
	assign rs1_rd_mem_out			= rs1_use_en ? rd_mem : 0;			
	assign rs1_wr_mem_out			= rs1_use_en ? wr_mem : 0;			
	assign rs1_cond_branch_out		= rs1_use_en ? cond_branch : 0;	
	assign rs1_uncond_branch_out	= rs1_use_en ? uncond_branch : 0;	
	assign rs1_rob_entry_out 		= rs1_use_en ? rob_entry : 0;
	assign rs1_fu_id_out			= rs1_use_en ? fu_id : ALU_0;
	assign rs1_ptab_tag_out			= rs1_use_en ? ptab_tag : 0;
	assign rs1_stq_tag_out			= rs1_use_en ? stq_tag : 0;
	assign rs1_ldq_tag_out			= rs1_use_en ? ldq_tag : 0;

 	assign loadAfromPRF = op1_cdb_match!=0 & !op1_ready & use_op1_prn & in_use;
 	assign loadBfromPRF = op2_cdb_match!=0 & !op2_ready & use_op2_prn & in_use;

	assign op1_ready_fwd_cdb = op1_cdb_match_fwd!=0 & !op1_ready_in & use_op1_prn_in & ~in_use;
	assign op2_ready_fwd_cdb = op2_cdb_match_fwd!=0 & !op2_ready_in & use_op2_prn_in & ~in_use;
			
	//free when execution finish policy	
	//assign rs1_free = dest_cdb_match!=0 | (rs1_use_en & (cond_branch | (uncond_branch & dest_prn == 0) | wr_mem));
	
	//free at issue policy //TODO ld_mask: speculative wakeup
	assign rs1_free = rs1_use_en;

	genvar i; 
	generate
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			assign op1_cdb_match[i] 	= ((cdb_prn[i] == op1_prn) & cdb_valid[i]);
			assign op2_cdb_match[i] 	= ((cdb_prn[i] == op2_prn) & cdb_valid[i]);
			assign op1_cdb_match_fwd[i] = ((cdb_prn[i] == op1_prn_in) & cdb_valid[i]);	
			assign op2_cdb_match_fwd[i] = ((cdb_prn[i] == op2_prn_in) & cdb_valid[i]);
			assign dest_cdb_match[i]	= (((cdb_prn[i] == dest_prn) & cdb_valid[i]) & (dest_prn!=0) & in_use);
		end
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
		//	assign wake_up_tmp[i]		= 	(in_use & (op1_ready | ~use_op1_prn) & (op2_ready | ~use_op2_prn) & i==fu_id) || //TODO this can improve cpi by ~1%, but may slow down freq 
		//	 								(rs1_load & (op1_ready_in | op1_ready_fwd_cdb | ~use_op1_prn_in) & (op2_ready_in | op2_ready_fwd_cdb | ~use_op2_prn_in) & i==fu_id_in) ;
			assign wake_up_tmp[i]		= 	(in_use & (op1_ready | ~use_op1_prn) & (op2_ready | ~use_op2_prn) & i==fu_id) ||
			 								(rs1_load & (op1_ready_in | ~use_op1_prn_in) & (op2_ready_in | ~use_op2_prn_in) & i==fu_id_in) ;

		end
	endgenerate




	always@(posedge clk or negedge rst_n) begin 
    	if(~rst_n) 
			rs1_wake_up <= 0;
		else if(pipe_flush)
			rs1_wake_up <= 0;
		else if(rs1_free)
			rs1_wake_up <= 0;
		else if(wake_up_tmp!=0)
			rs1_wake_up <= wake_up_tmp;
	end


	always@(posedge clk or negedge rst_n) begin 	
    	if(~rst_n)
	   		rs1_issued <= 0;
		else if(pipe_flush)
	   		rs1_issued <= 0;
		else if(rs1_free)
			rs1_issued <= 0;			
		else if(rs1_use_en)
			rs1_issued <= 1;
	end


	always@(posedge clk or negedge rst_n) begin 
    	if(~rst_n)
            in_use <= 1'b0; 
	   	else if(pipe_flush)
	       	in_use <= 1'b0; 
		else if(rs1_free)
	       	in_use <= 1'b0; 
		else if(rs1_load) begin       // load the inst into rs
	   		inst 			<= inst_in;	
	   		pc 				<= pc_in;	
        	op_type 		<= op_type_in; 
        	op1_prn 		<= op1_prn_in; 
        	op2_prn 		<= op2_prn_in; 
        	op1_ready 		<= op1_ready_in | op1_ready_fwd_cdb; 
        	op2_ready 		<= op2_ready_in | op2_ready_fwd_cdb; 
			use_op1_prn 	<= use_op1_prn_in; 
            use_op2_prn 	<= use_op2_prn_in; 
        	in_use 			<= 1'b1; 
        	dest_prn 		<= dest_prn_in; 
        	rob_entry 		<= rob_entry_in;
			fu_id 			<= fu_id_in;
			op1_select 		<= op1_select_in;		 
            op2_select 		<= op2_select_in;		
            rd_mem 			<= rd_mem_in;			
            wr_mem 			<= wr_mem_in;			
            cond_branch 	<= cond_branch_in;	
            uncond_branch 	<= uncond_branch_in;
			ptab_tag 		<= ptab_tag_in;	
			stq_tag 		<= stq_tag_in;	
			ldq_tag 		<= ldq_tag_in;	
      	end 
		else begin 
			if(loadAfromPRF)  
				op1_ready  	<= 1'b1;
			if(loadBfromPRF)  
				op2_ready 	<= 1'b1;
		end
	end

	//always@(posedge clk or negedge rst_n) begin
	//	if(rst_n) begin
	//		assert(rs1_free+rs1_load<=1) else #50 $finish;
	//	end
	//end
    //
	//always@(posedge clk or negedge rst_n) begin
	//	if(rst_n) begin
	//		if(rs1_use_en)
	//			assert(in_use) else #50 $finish;
	//	end
	//end
    //
	//always@(posedge clk or negedge rst_n) begin
	//	if(rst_n) begin
	//		if(rs1_load)
	//			assert(~in_use) else #50 $finish;
	//	end
	//end	




endmodule 
`endif //__RS1_V__
