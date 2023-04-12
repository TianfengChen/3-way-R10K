`timescale 1ns/100ps
//TODO assert only one br is retired per cycle
module rob(	//TODO ready accept
	input 								clk											,
	input 								rst_n										,
	input 								pipe_flush									,

	input		DISPATCH_ROB_PACKET		dispatch_pkt			[0:`MACHINE_WIDTH-1],
	output	reg	[`MACHINE_WIDTH-1:0]	dispatch_pkt_ready							,
	output	reg	[`ROB_WIDTH:0]			dispatch_pkt_resp		[0:`MACHINE_WIDTH-1],	//rob entry#
	output		RETIRE_ROB_PACKET		retire_pkt				[0:`MACHINE_WIDTH-1],

	input		[`ROB_WIDTH:0]			writeback_rob_tag		[0:`ISSUE_WIDTH-1]	,
	input		[`ISSUE_WIDTH-1:0]		writeback_valid								,
	input								writeback_br_misp							,
	input		[`XLEN-1:0]				writeback_redirect_pc
);


	ROB_ENTRY						rob_entry		[0:`ROB_DEPTH-1];
	ROB_ENTRY						dispatch_2_rob	[0:`MACHINE_WIDTH-1];

	reg		[`ROB_WIDTH-1:0]		head_ptr;	
	reg		[`ROB_WIDTH-1:0]		tail_ptr;
	reg								head_position_bit;
	reg								tail_position_bit;
	wire	[`ROB_WIDTH-1:0]		next_head_ptr;	
	wire	[`ROB_WIDTH-1:0]		next_tail_ptr;
	wire							next_head_position_bit;
	wire							next_tail_position_bit;
	wire							head_ptr_overflow;	
	wire							tail_ptr_overflow;	
	reg		[`ROB_WIDTH-1:0]		head_ptr_plus1;	
	reg		[`ROB_WIDTH-1:0]		head_ptr_plus2;	
	reg		[`ROB_WIDTH-1:0]		head_ptr_plus3;	
	reg		[`ROB_WIDTH-1:0]		tail_ptr_plus1;	
	reg		[`ROB_WIDTH-1:0]		tail_ptr_plus2;	
	reg		[`ROB_WIDTH-1:0]		tail_ptr_plus3;	

	wire	[`MACHINE_WIDTH:0]		dispatch_pkt_cnt;

	wire	[`MACHINE_WIDTH-1:0]	retire_en;
	wire	[`MACHINE_WIDTH:0]		retire_en_cnt;
	wire  	[`MACHINE_WIDTH-1:0]	br_mask;	//only one branch instr is allowed to retire every cycle
	wire	[`MACHINE_WIDTH-1:0]	flush_en_N;	//flush_en per way
	wire							flush_en;

	reg		[`ROB_WIDTH:0]			misp_rob; //the rob tag of misp br
	reg								branch_misp; //there are unretired misp br	
	reg		[`XLEN-1:0]				redirect_pc; //the correct next pc for pipeline


	assign dispatch_pkt_cnt = 		dispatch_pkt[3].packet_valid +
									dispatch_pkt[2].packet_valid +
									dispatch_pkt[1].packet_valid +
									dispatch_pkt[0].packet_valid ;

	assign retire_en_cnt = 			retire_en[3] +
									retire_en[2] +
									retire_en[1] +
									retire_en[0] ;

	//TODO
	assign retire_en[0]	=	rob_entry[head_ptr].valid && rob_entry[head_ptr].complete && br_mask[0];
	assign retire_en[1]	=	retire_en[0] && ~flush_en_N[0] && rob_entry[head_ptr_plus1].valid && rob_entry[head_ptr_plus1].complete && br_mask[1];
	assign retire_en[2]	=	retire_en[1] && ~flush_en_N[1] && rob_entry[head_ptr_plus2].valid && rob_entry[head_ptr_plus2].complete && br_mask[2];
	assign retire_en[3]	=	retire_en[2] && ~flush_en_N[2] && rob_entry[head_ptr_plus3].valid && rob_entry[head_ptr_plus3].complete && br_mask[3];

	assign br_mask[0]	= 	1'b1;
	assign br_mask[1]	=  	rob_entry[head_ptr].branch + 
							rob_entry[head_ptr_plus1].branch <= 1;
	assign br_mask[2]	=  	rob_entry[head_ptr].branch + 
							rob_entry[head_ptr_plus1].branch +  
							rob_entry[head_ptr_plus2].branch <= 1;  
	assign br_mask[3]	=  	rob_entry[head_ptr].branch +
							rob_entry[head_ptr_plus1].branch +
   							rob_entry[head_ptr_plus2].branch +
							rob_entry[head_ptr_plus3].branch <= 1;
									
	assign next_tail_ptr = tail_ptr + dispatch_pkt_cnt;
	assign next_head_ptr = head_ptr + retire_en_cnt;
	assign next_tail_position_bit = tail_ptr_overflow ? ~tail_position_bit : tail_position_bit;
	assign next_head_position_bit = head_ptr_overflow ? ~head_position_bit : head_position_bit;

	//TODO dont have to be 4'b1111
	//assign tail_ptr_overflow = tail_ptr[5:2]==4'b1111 && next_tail_ptr[5]==0;
	//assign head_ptr_overflow = head_ptr[5:2]==4'b1111 && next_head_ptr[5]==0;
	assign head_ptr_overflow = head_ptr[`ROB_WIDTH-1:`MACHINE_IDX]=={(`ROB_WIDTH-`MACHINE_IDX){1'b1}} && next_head_ptr[`ROB_WIDTH-1]==0;
	assign tail_ptr_overflow = tail_ptr[`ROB_WIDTH-1:`MACHINE_IDX]=={(`ROB_WIDTH-`MACHINE_IDX){1'b1}} && next_tail_ptr[`ROB_WIDTH-1]==0;

	assign flush_en = flush_en_N != 0;	

	assign head_ptr_plus1 = head_ptr + 1;
	assign head_ptr_plus2 = head_ptr + 2;
	assign head_ptr_plus3 = head_ptr + 3;
	assign tail_ptr_plus1 = tail_ptr + 1;
	assign tail_ptr_plus2 = tail_ptr + 2;
	assign tail_ptr_plus3 = tail_ptr + 3;
			



	always@(*) begin
		if(branch_misp) begin
		//if(sys_exception|retire_exception) begin  //remove branch_misp to expose more bugs
			dispatch_pkt_ready[0] =	0;
			dispatch_pkt_ready[1] =	0;
			dispatch_pkt_ready[2] =	0;
			dispatch_pkt_ready[3] =	0;
		end
		else if(next_head_position_bit==next_tail_position_bit) begin
			dispatch_pkt_ready[0] =	~((next_head_ptr+`ROB_DEPTH-next_tail_ptr)==0); 
            dispatch_pkt_ready[1] =	~((next_head_ptr+`ROB_DEPTH-next_tail_ptr)<=1);
            dispatch_pkt_ready[2] =	~((next_head_ptr+`ROB_DEPTH-next_tail_ptr)<=2);
            dispatch_pkt_ready[3] =	~((next_head_ptr+`ROB_DEPTH-next_tail_ptr)<=3);
		end
		else begin
			dispatch_pkt_ready[0] =	~((next_head_ptr-next_tail_ptr)==0); 
            dispatch_pkt_ready[1] =	~((next_head_ptr-next_tail_ptr)<=1);
            dispatch_pkt_ready[2] =	~((next_head_ptr-next_tail_ptr)<=2);
            dispatch_pkt_ready[3] =	~((next_head_ptr-next_tail_ptr)<=3);
		end
	end


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			tail_ptr <= 0;
			head_ptr <= 0;
		end
		else if(pipe_flush) begin
			tail_ptr <= 0;
			head_ptr <= 0;
		end
		else begin
			tail_ptr <= next_tail_ptr;
			head_ptr <= next_head_ptr;
		end
	end


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			tail_position_bit <= 0;
		else if(pipe_flush)
			tail_position_bit <= 0;
		else
			tail_position_bit <= next_tail_position_bit;
	end


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			head_position_bit <= 0;
		else if(pipe_flush)
			head_position_bit <= 0;
		else
			head_position_bit <= next_head_position_bit;
	end


	always@(posedge clk) begin
		if(~rst_n)
			branch_misp <= 0;
		if(pipe_flush) begin
			branch_misp <= 0;
			redirect_pc <= 0;
			misp_rob	<= 0;
		end
		else if(writeback_valid && writeback_br_misp) begin //only update the first misp br target pc
			if(~branch_misp) begin
				branch_misp <= 1;
				redirect_pc <= writeback_redirect_pc;
				misp_rob	<= writeback_rob_tag[5];
			end
			//update redirect pc if a younger misp br is found
			else if((misp_rob[`ROB_WIDTH]==writeback_rob_tag[5][`ROB_WIDTH] && 
					writeback_rob_tag[5][`ROB_WIDTH-1:0]<misp_rob[`ROB_WIDTH-1:0]) ||
					(misp_rob[`ROB_WIDTH]!=writeback_rob_tag[5][`ROB_WIDTH] && 
					writeback_rob_tag[5][`ROB_WIDTH-1:0]>misp_rob[`ROB_WIDTH-1:0])) begin	
					redirect_pc <= writeback_redirect_pc;
					misp_rob	<= writeback_rob_tag[5];
			end
		end
	end


	genvar i;
	generate
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign dispatch_2_rob[i].pc 			=	dispatch_pkt[i].pc 							;
			assign dispatch_2_rob[i].dest_arn 		= 	dispatch_pkt[i].dest_arn 					;
			assign dispatch_2_rob[i].dest_prn 		= 	dispatch_pkt[i].dest_prn 					;
			assign dispatch_2_rob[i].dest_prn_prev 	= 	dispatch_pkt[i].dest_prn_prev 				;
			assign dispatch_2_rob[i].stq_tag 		= 	dispatch_pkt[i].stq_tag		 				;
			assign dispatch_2_rob[i].ldq_tag 		= 	dispatch_pkt[i].ldq_tag		 				;
			assign dispatch_2_rob[i].rd_mem			= 	dispatch_pkt[i].rd_mem						;
			assign dispatch_2_rob[i].wr_mem 		= 	dispatch_pkt[i].wr_mem 						;
			assign dispatch_2_rob[i].branch			= 	dispatch_pkt[i].cond_branch | 
													   	dispatch_pkt[i].uncond_branch				;
			assign dispatch_2_rob[i].branch_misp 	= 	1'b0						 				;
			assign dispatch_2_rob[i].exception 		= 	dispatch_pkt[i].halt 	? 	HALTED_ON_WFI 	:
				 							   		   	dispatch_pkt[i].illegal ? 	ILLEGAL_INST	:
				 							   	   	 								NO_ERROR		;
			assign dispatch_2_rob[i].complete 		= 	dispatch_pkt[i].inst == `NOP ||
														dispatch_2_rob[i].exception != NO_ERROR		;	
			assign dispatch_2_rob[i].valid 			= 	dispatch_pkt[i].packet_valid 				;

			assign flush_en_N[i] = (retire_pkt[i].packet_valid && (retire_pkt[i].branch_misp || retire_pkt[i].exception!=NO_ERROR));			
		end


		for(i=0;i<`ROB_DEPTH;i=i+1) begin
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					rob_entry[i] <= 0;
				else if(pipe_flush)
					rob_entry[i] <= 0;
				else begin
					/************************writeback***********************/
					if(rob_entry[i].valid && ~rob_entry[i].complete) begin
						rob_entry[i].complete	<=	(i==writeback_rob_tag[0][`ROB_WIDTH-1:0] && writeback_valid[0])	||
											 		(i==writeback_rob_tag[1][`ROB_WIDTH-1:0] && writeback_valid[1])	||
											 		(i==writeback_rob_tag[2][`ROB_WIDTH-1:0] && writeback_valid[2])	||
											 		(i==writeback_rob_tag[3][`ROB_WIDTH-1:0] && writeback_valid[3])	||
											 		(i==writeback_rob_tag[4][`ROB_WIDTH-1:0] && writeback_valid[4])	||
											 		(i==writeback_rob_tag[5][`ROB_WIDTH-1:0] && writeback_valid[5])	||
											 		(i==writeback_rob_tag[6][`ROB_WIDTH-1:0] && writeback_valid[6]);
                    	                                                          
						rob_entry[i].branch_misp <= (i==writeback_rob_tag[5][`ROB_WIDTH-1:0] && writeback_valid[5] && writeback_br_misp);
					end

					/*************************retire*************************/
					if(retire_en[0] && i==head_ptr)
						rob_entry[i].valid <= 0;
					if(retire_en[1] && i==head_ptr_plus1)
						rob_entry[i].valid <= 0;
					if(retire_en[2] && i==head_ptr_plus2)
						rob_entry[i].valid <= 0;
					if(retire_en[3] && i==head_ptr_plus3)
						rob_entry[i].valid <= 0;



					/************************allocate************************/
					if(dispatch_pkt[0].packet_valid) begin	//1111/0111/0011/0001 instr are valid
						if(i==tail_ptr)
							rob_entry[i] <= dispatch_2_rob[0];
						else if(i==tail_ptr_plus1 && dispatch_2_rob[1].valid)
							rob_entry[i] <= dispatch_2_rob[1];
						else if(i==tail_ptr_plus2 && dispatch_2_rob[2].valid)
							rob_entry[i] <= dispatch_2_rob[2];							
						else if(i==tail_ptr_plus3 && dispatch_2_rob[3].valid)
							rob_entry[i] <= dispatch_2_rob[3];
					end
					else if(dispatch_pkt[1].packet_valid) begin	//1110/0110/0010 instr are valid
						if(i==tail_ptr)
							rob_entry[i] <= dispatch_2_rob[1];
						else if(i==tail_ptr_plus1 && dispatch_2_rob[2].valid)
							rob_entry[i] <= dispatch_2_rob[2];
						else if(i==tail_ptr_plus2 && dispatch_2_rob[3].valid)
							rob_entry[i] <= dispatch_2_rob[3];							
					end
					else if(dispatch_pkt[2].packet_valid) begin	//1100/0100 instr are valid
						if(i==tail_ptr)
							rob_entry[i] <= dispatch_2_rob[2];
						else if(i==tail_ptr_plus1 && dispatch_2_rob[3].valid)
							rob_entry[i] <= dispatch_2_rob[3];
					end
					else if(dispatch_pkt[3].packet_valid) begin	//1000 instr are valid
						if(i==tail_ptr)
							rob_entry[i] <= dispatch_2_rob[3];
					end
				end	    		
			end	
		
		end
	endgenerate



	assign retire_pkt[0].pc 						= rob_entry[head_ptr].pc;
	assign retire_pkt[0].dest_arn 					= rob_entry[head_ptr].dest_arn;
	assign retire_pkt[0].dest_prn 					= rob_entry[head_ptr].dest_prn;
	assign retire_pkt[0].dest_prn_prev 				= rob_entry[head_ptr].dest_prn_prev;
	assign retire_pkt[0].stq_tag	 				= rob_entry[head_ptr].stq_tag;
	assign retire_pkt[0].ldq_tag	 				= rob_entry[head_ptr].ldq_tag;
	assign retire_pkt[0].rd_mem						= rob_entry[head_ptr].rd_mem;
	assign retire_pkt[0].wr_mem						= rob_entry[head_ptr].wr_mem;
	assign retire_pkt[0].branch_misp				= rob_entry[head_ptr].branch_misp;
	assign retire_pkt[0].redirect_pc				= redirect_pc;
	assign retire_pkt[0].exception					= rob_entry[head_ptr].exception;
	assign retire_pkt[0].rob_tag[`ROB_WIDTH]	 	= head_position_bit;
	assign retire_pkt[0].rob_tag[`ROB_WIDTH-1:0]	= head_ptr;
	assign retire_pkt[0].packet_valid				= retire_en[0];

	assign retire_pkt[1].pc 						= rob_entry[head_ptr_plus1].pc;
	assign retire_pkt[1].dest_arn 					= rob_entry[head_ptr_plus1].dest_arn;
	assign retire_pkt[1].dest_prn 					= rob_entry[head_ptr_plus1].dest_prn;
	assign retire_pkt[1].dest_prn_prev 				= rob_entry[head_ptr_plus1].dest_prn_prev;
	assign retire_pkt[1].stq_tag	 				= rob_entry[head_ptr_plus1].stq_tag;
	assign retire_pkt[1].ldq_tag	 				= rob_entry[head_ptr_plus1].ldq_tag;
	assign retire_pkt[1].rd_mem						= rob_entry[head_ptr_plus1].rd_mem;
	assign retire_pkt[1].wr_mem						= rob_entry[head_ptr_plus1].wr_mem;
	assign retire_pkt[1].branch_misp				= rob_entry[head_ptr_plus1].branch_misp;
	assign retire_pkt[1].redirect_pc				= redirect_pc;
	assign retire_pkt[1].exception					= rob_entry[head_ptr_plus1].exception;
	assign retire_pkt[1].rob_tag[`ROB_WIDTH]	 	= head_position_bit;
	assign retire_pkt[1].rob_tag[`ROB_WIDTH-1:0]	= head_ptr_plus1;
	assign retire_pkt[1].packet_valid				= retire_en[1];

	assign retire_pkt[2].pc 						= rob_entry[head_ptr_plus2].pc;
	assign retire_pkt[2].dest_arn 					= rob_entry[head_ptr_plus2].dest_arn;
	assign retire_pkt[2].dest_prn 					= rob_entry[head_ptr_plus2].dest_prn;
	assign retire_pkt[2].dest_prn_prev 				= rob_entry[head_ptr_plus2].dest_prn_prev;
	assign retire_pkt[2].stq_tag	 				= rob_entry[head_ptr_plus2].stq_tag;
	assign retire_pkt[2].ldq_tag	 				= rob_entry[head_ptr_plus2].ldq_tag;
	assign retire_pkt[2].rd_mem						= rob_entry[head_ptr_plus2].rd_mem;
	assign retire_pkt[2].wr_mem						= rob_entry[head_ptr_plus2].wr_mem;
	assign retire_pkt[2].branch_misp				= rob_entry[head_ptr_plus2].branch_misp;
	assign retire_pkt[2].redirect_pc				= redirect_pc;
	assign retire_pkt[2].exception					= rob_entry[head_ptr_plus2].exception;
	assign retire_pkt[2].rob_tag[`ROB_WIDTH]	 	= head_position_bit;
	assign retire_pkt[2].rob_tag[`ROB_WIDTH-1:0]	= head_ptr_plus2;
	assign retire_pkt[2].packet_valid				= retire_en[2];

	assign retire_pkt[3].pc 						= rob_entry[head_ptr_plus3].pc;
	assign retire_pkt[3].dest_arn 					= rob_entry[head_ptr_plus3].dest_arn;
	assign retire_pkt[3].dest_prn 					= rob_entry[head_ptr_plus3].dest_prn;
	assign retire_pkt[3].dest_prn_prev 				= rob_entry[head_ptr_plus3].dest_prn_prev;
	assign retire_pkt[3].stq_tag	 				= rob_entry[head_ptr_plus3].stq_tag;
	assign retire_pkt[3].ldq_tag	 				= rob_entry[head_ptr_plus3].ldq_tag;
	assign retire_pkt[3].rd_mem						= rob_entry[head_ptr_plus3].rd_mem;
	assign retire_pkt[3].wr_mem						= rob_entry[head_ptr_plus3].wr_mem;
	assign retire_pkt[3].branch_misp				= rob_entry[head_ptr_plus3].branch_misp;
	assign retire_pkt[3].redirect_pc				= redirect_pc;
	assign retire_pkt[3].exception					= rob_entry[head_ptr_plus3].exception;
	assign retire_pkt[3].rob_tag[`ROB_WIDTH]	 	= head_position_bit;
	assign retire_pkt[3].rob_tag[`ROB_WIDTH-1:0]	= head_ptr_plus3;
	assign retire_pkt[3].packet_valid				= retire_en[3];


	always@(*) begin
		if(dispatch_pkt[0].packet_valid) begin	//1111 instr are valid
			dispatch_pkt_resp[0][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr<4 ? ~tail_position_bit : tail_position_bit ;				
			dispatch_pkt_resp[1][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr_plus1<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[2][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr_plus2<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[3][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr_plus3<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[0][`ROB_WIDTH-1:0]	= tail_ptr;	
			dispatch_pkt_resp[1][`ROB_WIDTH-1:0]	= tail_ptr_plus1;	
			dispatch_pkt_resp[2][`ROB_WIDTH-1:0]	= tail_ptr_plus2;	
			dispatch_pkt_resp[3][`ROB_WIDTH-1:0]	= tail_ptr_plus3;	
		end
		else if(dispatch_pkt[1].packet_valid) begin	//1110 instr are valid
			dispatch_pkt_resp[0][`ROB_WIDTH] 		= 0;				
			dispatch_pkt_resp[1][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[2][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr_plus1<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[3][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr_plus2<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[0][`ROB_WIDTH-1:0]	= 0;	
			dispatch_pkt_resp[1][`ROB_WIDTH-1:0]	= tail_ptr;	
			dispatch_pkt_resp[2][`ROB_WIDTH-1:0]	= tail_ptr_plus1;	
			dispatch_pkt_resp[3][`ROB_WIDTH-1:0]	= tail_ptr_plus2;	
		end
		else if(dispatch_pkt[2].packet_valid) begin	//1100 instr are valid
			dispatch_pkt_resp[0][`ROB_WIDTH] 		= 0;				
			dispatch_pkt_resp[1][`ROB_WIDTH] 		= 0;				
			dispatch_pkt_resp[2][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[3][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr_plus1<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[0][`ROB_WIDTH-1:0]	= 0;	
			dispatch_pkt_resp[1][`ROB_WIDTH-1:0]	= 0;	
			dispatch_pkt_resp[2][`ROB_WIDTH-1:0]	= tail_ptr;	
			dispatch_pkt_resp[3][`ROB_WIDTH-1:0]	= tail_ptr_plus1;	
		end
		else if(dispatch_pkt[3].packet_valid) begin	//1000 instr are valid
			dispatch_pkt_resp[0][`ROB_WIDTH] 		= 0;				
			dispatch_pkt_resp[1][`ROB_WIDTH] 		= 0;				
			dispatch_pkt_resp[2][`ROB_WIDTH] 		= 0;				
			dispatch_pkt_resp[3][`ROB_WIDTH] 		= tail_ptr_overflow && tail_ptr<4 ? ~tail_position_bit : tail_position_bit;				
			dispatch_pkt_resp[0][`ROB_WIDTH-1:0]	= 0;	
			dispatch_pkt_resp[1][`ROB_WIDTH-1:0]	= 0;	
			dispatch_pkt_resp[2][`ROB_WIDTH-1:0]	= 0;	
			dispatch_pkt_resp[3][`ROB_WIDTH-1:0]	= tail_ptr;	
		end
	end



endmodule
