`timescale 1ns/100ps

module stq(	
	input 								clk											,
	input 								rst_n										,
	input 								pipe_flush									,

	input		[`MACHINE_WIDTH-1:0]	dispatch_valid								,
	output								dispatch_ready								,
	output	reg	[`STQ_WIDTH-1:0]		dispatch_resp			[0:`MACHINE_WIDTH-1],
	output		[`STQ_DEPTH-1:0]		dispatch_st_mask,
	output		[`STQ_WIDTH-1:0]		dispatch_st_youngest,

	input		[`XLEN-1:0]				execute_st_addr,
	input		[`STQ_WIDTH-1:0]		execute_st_addr_stq_tag,
	input								execute_st_addr_valid,
	input		[`XLEN-1:0]				execute_st_data,
	input		[2:0]					execute_st_data_size,
	input		[`STQ_WIDTH-1:0]		execute_st_data_stq_tag,
	input								execute_st_data_valid,
            	
	input		RETIRE_ROB_PACKET		retire_pkt				[0:`MACHINE_WIDTH-1],
            	
	output	reg	[`XLEN-1:0]				fire_st_addr,
	output	reg	[`XLEN-1:0]				fire_st_data,
	output	reg	[2:0]					fire_st_data_size,
	output	reg	[`STQ_WIDTH-1:0]		fire_st_stq_tag,
	output	reg							fire_st_valid,
	input								fire_st_ready,
                                        
	input		[`XLEN-1:0]				fire_ld_addr,
	input		[2:0]					fire_ld_data_size,
	input		[`LDQ_WIDTH-1:0]		fire_ld_ldq_tag,
	input		[`STQ_DEPTH-1:0]		fire_ld_st_mask,	
	input		[`STQ_WIDTH-1:0]		fire_ld_st_youngest,	
	input								fire_ld_valid,

	output	reg	[`XLEN-1:0]				fwd_data,
	output	reg							fwd_valid,
	output	reg							fwd_sleep,
	output	reg	[`LDQ_WIDTH-1:0]		fwd_ldq_tag,
	output	reg	[`STQ_WIDTH-1:0]		fwd_stq_tag,

	output		STQ_ENTRY				stq_entry				[0:`STQ_DEPTH-1]

);




	reg		[`STQ_WIDTH-1:0]		head_ptr;	
	reg		[`STQ_WIDTH-1:0]		tail_ptr;
	reg		[`STQ_WIDTH-1:0]		retired_ptr;	
	reg								head_pos_bit;
	reg								tail_pos_bit;
	reg								retired_pos_bit;
	reg		[`STQ_WIDTH-1:0]		next_head_ptr;	
	reg		[`STQ_WIDTH-1:0]		next_tail_ptr;
	wire	[`STQ_WIDTH-1:0]		next_retired_ptr;
	reg								next_head_pos_bit;
	reg								next_tail_pos_bit;
	wire							next_retired_pos_bit;
	wire							head_ptr_overflow;
	wire							tail_ptr_overflow;
	wire							retired_ptr_overflow;
	wire	[`STQ_WIDTH-1:0]		tail_ptr_plus1;	
	wire	[`STQ_WIDTH-1:0]		tail_ptr_plus2;	
	wire	[`STQ_WIDTH-1:0]		tail_ptr_plus3;	

	wire	[`MACHINE_WIDTH:0]		dispatch_cnt;
	wire	[`MACHINE_WIDTH:0]		retire_cnt;
	wire							fire_st_accept;
	wire	[`STQ_DEPTH-1:0]		st_wakeup_N;		//wakeup when it is retired and is the head of stq
	wire	[`STQ_DEPTH-1:0]		update_retire_N;

	wire	[`STQ_DEPTH-1:0]		age_mask;			//generating mask that zeroes out anything younger than tail
	wire	[`STQ_DEPTH-1:0]		match;				//bit vector of stq entries whose addr/size match the incoming load
	wire	[`STQ_DEPTH*2-1:0]		match_double;		//double length
	wire							addr_conflict;		//addr match but size does not
	reg								found_match;		//can forward
   	reg		[`STQ_WIDTH:0]			fwd_stq_idx_double;	//the youngest st double length	
   	wire	[`STQ_WIDTH-1:0]		fwd_stq_idx;		//the youngest st	
	wire	[`XLEN-1:0]				fwd_4B_aligned;
	reg		[7:0]					fwd_byte;
	reg		[15:0]					fwd_half;
	reg		[31:0]					fwd_word;
	wire	[1:0]					ld_offset_start;
	wire	[1:0]					ld_offset_end;
	wire	[1:0]					st_offset_start;
	wire	[1:0]					st_offset_end;





	assign dispatch_cnt = 		dispatch_valid[3] +
								dispatch_valid[2] +
								dispatch_valid[1] +
								dispatch_valid[0] ;
                            	
	assign retire_cnt	=		(retire_pkt[0].packet_valid && retire_pkt[0].wr_mem) +
								(retire_pkt[1].packet_valid && retire_pkt[1].wr_mem) +
								(retire_pkt[2].packet_valid && retire_pkt[2].wr_mem) +
								(retire_pkt[3].packet_valid && retire_pkt[3].wr_mem) ;


	assign dispatch_st_youngest	=	head_ptr==tail_ptr && head_pos_bit==tail_pos_bit ? tail_ptr : tail_ptr-1;
	assign dispatch_ready 		= 	next_head_pos_bit==next_tail_pos_bit ? 
									(next_head_ptr+`STQ_DEPTH-next_tail_ptr)>=4 :
									(next_head_ptr-next_tail_ptr)>=4;

	
	assign tail_ptr_plus1 		= 	tail_ptr + 1;
	assign tail_ptr_plus2 		= 	tail_ptr + 2;
	assign tail_ptr_plus3 		= 	tail_ptr + 3;


	assign head_ptr_overflow 	= 	head_ptr[`STQ_WIDTH-1]==1 &&
   									next_head_ptr[`STQ_WIDTH-1]==0;
	assign tail_ptr_overflow 	= 	tail_ptr[`STQ_WIDTH-1]==1 && 
									next_tail_ptr[`STQ_WIDTH-1]==0;
	assign retired_ptr_overflow = 	retired_ptr[`STQ_WIDTH-1]==1 && 
									next_retired_ptr[`STQ_WIDTH-1]==0;

	assign next_retired_ptr 	= 	retired_ptr + retire_cnt;
	assign next_retired_pos_bit = 	retired_ptr_overflow ? ~retired_pos_bit : retired_pos_bit;	



	always@(*) begin
		if(pipe_flush) begin
			if(head_ptr==next_retired_ptr && head_pos_bit==next_retired_pos_bit) begin //no retired st
				next_head_ptr 		= head_ptr;
				next_tail_ptr 		= head_ptr;
				next_head_pos_bit 	= head_pos_bit;
				next_tail_pos_bit 	= head_pos_bit;
			end
			else begin
				next_head_ptr 		= head_ptr + fire_st_accept;
				next_tail_ptr 		= next_retired_ptr;
				next_head_pos_bit 	= head_ptr_overflow ? ~head_pos_bit : head_pos_bit;
				next_tail_pos_bit 	= next_retired_ptr=={`STQ_DEPTH{1'b1}} ? ~next_retired_pos_bit : next_retired_pos_bit;
			end
		end
		else begin
			next_head_ptr 		= head_ptr + fire_st_accept;
			next_tail_ptr 		= tail_ptr + dispatch_cnt;
			next_head_pos_bit 	= head_ptr_overflow ? ~head_pos_bit : head_pos_bit;
			next_tail_pos_bit 	= tail_ptr_overflow ? ~tail_pos_bit : tail_pos_bit;
		end

	end



	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			tail_ptr 		<= 0;
			head_ptr 		<= 0;
			retired_ptr 	<= 0;
			tail_pos_bit 	<= 0;
			head_pos_bit 	<= 0;
			retired_pos_bit <= 0;
		end
		else begin
			tail_ptr 		<= next_tail_ptr;
			head_ptr 		<= next_head_ptr;
			retired_ptr 	<= next_retired_ptr;
			tail_pos_bit 	<= next_tail_pos_bit;
			head_pos_bit 	<= next_head_pos_bit;
			retired_pos_bit <= next_retired_pos_bit;
		end
	end





	/***************************fire store request logic**************************/
	genvar i;
	generate
		for(i=0;i<`STQ_DEPTH;i=i+1) begin
			assign st_wakeup_N[i]	=	stq_entry[i].entry_valid && stq_entry[i].retired && ~fire_st_accept;
		end
	endgenerate


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			fire_st_valid <= 0;
		else if(pipe_flush)
			fire_st_valid <= 0;
		else
			fire_st_valid <= st_wakeup_N != 0;
	end


	always@(posedge clk) begin
		fire_st_stq_tag		<=	head_ptr;
		fire_st_addr		<=	stq_entry[head_ptr].addr;
		fire_st_data		<=	stq_entry[head_ptr].data;
		fire_st_data_size	<=	stq_entry[head_ptr].data_size;
	end


	assign fire_st_accept	= 	fire_st_valid && fire_st_ready;




	/*************************Store to load forwaring logic***********************/

	generate
		for(i=0;i<`STQ_DEPTH;i=i+1) begin
			//generating mask that zeroes out anything younger than tail
			assign age_mask[i]		=	i>fire_ld_st_youngest ? 1'b0 : 1'b1;
			assign match[i]			=	(fire_ld_addr[`XLEN-1:2]==stq_entry[i].addr[`XLEN-1:2]) && 
										fire_ld_st_mask[i] &&
										fire_ld_valid &&
										stq_entry[i].addr_valid &&
										stq_entry[i].entry_valid ;
										//~(fire_st_accept && i==fire_st_stq_tag);
		end
	endgenerate


	assign ld_offset_start 	= 	fire_ld_addr[1:0];
	assign ld_offset_end 	= 	MEM_SIZE'(fire_ld_data_size)==BYTE	?	ld_offset_start+0 :
							 	MEM_SIZE'(fire_ld_data_size)==HALF	? 	ld_offset_start+1 :
							 	MEM_SIZE'(fire_ld_data_size)==WORD 	? 	ld_offset_start+3 : 
																		ld_offset_start+3 ;
	assign st_offset_start	=	stq_entry[fwd_stq_idx].addr[1:0];
	assign st_offset_end	= 	MEM_SIZE'(stq_entry[fwd_stq_idx].data_size)==BYTE 	? 	st_offset_start+0 :
								MEM_SIZE'(stq_entry[fwd_stq_idx].data_size)==HALF	? 	st_offset_start+1 :
								MEM_SIZE'(stq_entry[fwd_stq_idx].data_size)==WORD 	? 	st_offset_start+3 : 
																						st_offset_start+3 ;

	//load start addr must be greater or equal to store start addr
	//load end addr must be less or equal to store end addr
	assign addr_conflict	=	found_match && ~(ld_offset_start>=st_offset_start && ld_offset_end<=st_offset_end) ;

	//if addr is partial match, fire_ld will be
	//killed and the ldq entry will go to sleep, wakeup untill the
	//store is writebacked to dcache
	
	assign match_double		=	{match & age_mask, match};
	
	//look for youngest, approach from the oldest side, let the last one found stick
	always_comb begin
		fwd_stq_idx_double = 0;
		found_match = 0;
		for(int i=0;i<`STQ_DEPTH*2;i++) begin
			if(match_double[i]) begin
				fwd_stq_idx_double = i;
				found_match = 1;
			end
		end
	end


	assign fwd_4B_aligned = stq_entry[fwd_stq_idx].data << (stq_entry[fwd_stq_idx].addr[1:0]*8);

	always@(*) begin
		case(fire_ld_addr[1:0])
			2'b00 : begin
				fwd_byte = fwd_4B_aligned[0*8+:8]	;
				fwd_half = fwd_4B_aligned[0*16+:16];
				fwd_word = fwd_4B_aligned[0*32+:32];
			end
			2'b01 : begin
				fwd_byte = fwd_4B_aligned[1*8+:8]	;
				fwd_half = fwd_4B_aligned[0*16+:16];	//force 2byte alignment
				fwd_word = fwd_4B_aligned[0*32+:32];	//force 4byte alignment
			end
			2'b10 : begin
				fwd_byte = fwd_4B_aligned[2*8+:8]	;
				fwd_half = fwd_4B_aligned[1*16+:16];
				fwd_word = fwd_4B_aligned[0*32+:32];	//force 4byte alignment
			end
			2'b11 : begin
				fwd_byte = fwd_4B_aligned[3*8+:8]	;
				fwd_half = fwd_4B_aligned[1*16+:16];	//force 2byte alignment
				fwd_word = fwd_4B_aligned[0*32+:32];	//force 4byte alignment
			end			
		endcase
	end


	always@(posedge clk) begin
		case(MEM_SIZE'(fire_ld_data_size[1:0]))
			BYTE:	fwd_data <= 	~fire_ld_data_size[2] ? 
									{{(`XLEN-8){fwd_byte[7]}}, fwd_byte} :
									{{(`XLEN-8){1'b0}}, fwd_byte} ;
			HALF:	fwd_data <= 	~fire_ld_data_size[2] ? 
									{{(`XLEN-16){fwd_half[15]}}, fwd_half} :
									{{(`XLEN-16){1'b0}}, fwd_half} ;
			WORD:	fwd_data <= 	fwd_word;
			default:fwd_data <= 	32'hdeadbeef;
		endcase
	end

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			fwd_valid 	<= 0;
			fwd_sleep 	<= 0;
			fwd_ldq_tag <= 0;
			fwd_stq_tag <= 0;
		end
		else if(pipe_flush) begin
			fwd_valid 	<= 0;
			fwd_sleep 	<= 0;
			fwd_ldq_tag <= 0;
			fwd_stq_tag <= 0;
		end
		else begin
			fwd_valid 	<= stq_entry[fwd_stq_idx].data_valid && found_match && ~addr_conflict;
			fwd_sleep 	<= addr_conflict && ~(fire_st_accept && fire_st_stq_tag==fwd_stq_idx);
			//fwd_sleep 	<= addr_conflict;
			fwd_ldq_tag <= fire_ld_ldq_tag;
			fwd_stq_tag <= fwd_stq_idx;
		end
	end
	
	assign fwd_stq_idx	=	fwd_stq_idx_double[`STQ_WIDTH-1:0];
	
	assert property (@(posedge clk) fwd_sleep |-> fwd_valid==0);








	generate
		for(i=0;i<`STQ_DEPTH;i=i+1) begin
			assign update_retire_N[i] 	= 	(i==retire_pkt[0].stq_tag && retire_pkt[0].packet_valid && retire_pkt[0].wr_mem) ||
											(i==retire_pkt[1].stq_tag && retire_pkt[1].packet_valid && retire_pkt[1].wr_mem) ||
											(i==retire_pkt[2].stq_tag && retire_pkt[2].packet_valid && retire_pkt[2].wr_mem) ||
											(i==retire_pkt[3].stq_tag && retire_pkt[3].packet_valid && retire_pkt[3].wr_mem) ;
			
			assign dispatch_st_mask[i]	=	stq_entry[i].entry_valid;


			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) begin
					stq_entry[i].entry_valid	<= 0;
					stq_entry[i].addr_valid 	<= 0;
					stq_entry[i].data_valid 	<= 0;
					stq_entry[i].retired 		<= 0;
				end
				else if(pipe_flush && stq_entry[i].entry_valid && ~stq_entry[i].retired && ~update_retire_N[i]) begin
					stq_entry[i].entry_valid	<= 0;
					stq_entry[i].addr_valid 	<= 0;
					stq_entry[i].data_valid	 	<= 0;
					stq_entry[i].retired 		<= 0;
				end
				else begin
					/************************allocate************************/
					case(dispatch_cnt)
						1: begin
							if(i==tail_ptr)
								stq_entry[i].entry_valid <= 1;
						end
						2: begin
							if(i==tail_ptr)
								stq_entry[i].entry_valid <= 1;
							else if(i==tail_ptr_plus1)
								stq_entry[i].entry_valid <= 1;
						end
						3: begin
							if(i==tail_ptr)
								stq_entry[i].entry_valid <= 1;
							else if(i==tail_ptr_plus1)
								stq_entry[i].entry_valid <= 1;
							else if(i==tail_ptr_plus2)
								stq_entry[i].entry_valid <= 1;
						end
						4: begin
							if(i==tail_ptr)
								stq_entry[i].entry_valid <= 1;
							else if(i==tail_ptr_plus1)
								stq_entry[i].entry_valid <= 1;
							else if(i==tail_ptr_plus2)
								stq_entry[i].entry_valid <= 1;
							else if(i==tail_ptr_plus3)
								stq_entry[i].entry_valid <= 1;
						end
						default: begin
							stq_entry[i].entry_valid <= stq_entry[i].entry_valid;
						end
					endcase

					/***********************write addr***********************/
					if(i==execute_st_addr_stq_tag && execute_st_addr_valid) begin
						stq_entry[i].addr 		<= execute_st_addr;	
						stq_entry[i].addr_valid <= 1;	
					end

					/***********************write data***********************/
					if(i==execute_st_data_stq_tag && execute_st_data_valid) begin
						stq_entry[i].data 		<= execute_st_data;	
						stq_entry[i].data_size	<= execute_st_data_size;	
						stq_entry[i].data_valid <= 1;	
					end

					/**********************update retire*********************/
					if(update_retire_N[i])
						stq_entry[i].retired <= 1;

					/************************fire mem************************/
					if(i==head_ptr && fire_st_accept) begin
						stq_entry[i].addr_valid <= 0;	
						stq_entry[i].data_valid <= 0;	
						stq_entry[i].retired <= 0;	
						stq_entry[i].entry_valid <= 0;	
					end

				end
			end
		end
	endgenerate


	always@(*) begin
		dispatch_resp[0] = 0;
		dispatch_resp[1] = 0;
		dispatch_resp[2] = 0;
		dispatch_resp[3] = 0;
		case(dispatch_valid)
			4'b0001:	dispatch_resp[0] = tail_ptr;
			4'b0010:	dispatch_resp[1] = tail_ptr;
			4'b0100:	dispatch_resp[2] = tail_ptr;
			4'b1000:	dispatch_resp[3] = tail_ptr;
			4'b0011: begin
				dispatch_resp[0] = tail_ptr;
				dispatch_resp[1] = tail_ptr_plus1;
			end
			4'b0101: begin
				dispatch_resp[0] = tail_ptr;
				dispatch_resp[2] = tail_ptr_plus1;
			end
			4'b1001: begin
				dispatch_resp[0] = tail_ptr;
				dispatch_resp[3] = tail_ptr_plus1;
			end
			4'b0110: begin
				dispatch_resp[1] = tail_ptr;
				dispatch_resp[2] = tail_ptr_plus1;
			end
			4'b1010: begin
				dispatch_resp[1] = tail_ptr;
				dispatch_resp[3] = tail_ptr_plus1;
			end
			4'b1100: begin
				dispatch_resp[2] = tail_ptr;
				dispatch_resp[3] = tail_ptr_plus1;
			end
			4'b0111: begin
				dispatch_resp[0] = tail_ptr;
				dispatch_resp[1] = tail_ptr_plus1;
				dispatch_resp[2] = tail_ptr_plus2;
			end
			4'b1011: begin
				dispatch_resp[0] = tail_ptr;
				dispatch_resp[1] = tail_ptr_plus1;
				dispatch_resp[3] = tail_ptr_plus2;
			end
			4'b1101: begin
				dispatch_resp[0] = tail_ptr;
				dispatch_resp[2] = tail_ptr_plus1;
				dispatch_resp[3] = tail_ptr_plus2;
			end
			4'b1110: begin
				dispatch_resp[1] = tail_ptr;
				dispatch_resp[2] = tail_ptr_plus1;
				dispatch_resp[3] = tail_ptr_plus2;
			end
			4'b1111: begin
				dispatch_resp[0] = tail_ptr;
				dispatch_resp[1] = tail_ptr_plus1;
				dispatch_resp[2] = tail_ptr_plus2;
				dispatch_resp[3] = tail_ptr_plus3;
			end
		endcase
	end

	//assert new info must be allocted to valid==0 entry
	//assert write addr/data to a valid entry
	//assert addr/data must be valid at retirement
	
	
endmodule
