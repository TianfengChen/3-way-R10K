`timescale 1ns/100ps

module ldq(	
	input 								clk											,
	input 								rst_n										,
	input 								pipe_flush									,

	input		[`MACHINE_WIDTH-1:0]	dispatch_valid								,
	output								dispatch_ready								,
	output	reg	[`LDQ_WIDTH-1:0]		dispatch_resp			[0:`MACHINE_WIDTH-1],	
	input		[`STQ_DEPTH-1:0]		dispatch_st_mask		[0:`MACHINE_WIDTH-1],
	input		[`STQ_WIDTH-1:0]		dispatch_st_youngest	[0:`MACHINE_WIDTH-1],

	input		[`XLEN-1:0]				execute_ld_addr,
	input		[`LDQ_WIDTH-1:0]		execute_ld_ldq_tag,
	input		[2:0]					execute_ld_data_size,
	input		[`XLEN-1:0]				execute_ld_pc,				
	input 		[`PRF_WIDTH-1:0]		execute_ld_prn,			
	input		[`ROB_WIDTH:0]			execute_ld_rob_tag,		
	input								execute_ld_valid,
	input		[`XLEN-1:0]				execute_st_addr,
	input		[`LDQ_WIDTH-1:0]		execute_st_addr_stq_tag,
	input								execute_st_addr_valid,

	output	reg	[`XLEN-1:0]				fire_ld_addr,
	output	reg	[2:0]					fire_ld_data_size,
	output	reg	[`LDQ_WIDTH-1:0]		fire_ld_ldq_tag,
	output	reg	[`STQ_DEPTH-1:0]		fire_ld_st_mask,
	output	reg	[`STQ_WIDTH-1:0]		fire_ld_st_youngest,
	output	reg							fire_ld_valid,
	output		[`LDQ_DEPTH-1:0]		fire_ld_kill,
	input								fire_ld_ready,

	input		[`STQ_WIDTH-1:0]		fire_st_stq_tag,
	input								fire_st_valid,            	
	input								fire_st_ready,            	

	input		[`XLEN-1:0]				fwd_data,
	input								fwd_valid,
	input								fwd_sleep,		//let the ld sleep untill the conflict st fired
	input		[`LDQ_WIDTH-1:0]		fwd_ldq_tag,
	input		[`STQ_WIDTH-1:0]		fwd_stq_tag,

	input		[`XLEN-1:0]				dcache_data,
	input		[`LDQ_WIDTH-1:0]		dcache_ldq_tag,
	input								dcache_valid,
	output								dcache_ready,
            	
	output		[`XLEN-1:0]				writeback_data,
	output		[`XLEN-1:0]				writeback_pc,
	output		[`PRF_WIDTH-1:0]		writeback_dest_prn,
	output		[`ROB_WIDTH:0]			writeback_rob_tag,	
	output								writeback_valid,
	input								writeback_ready,

	input		RETIRE_ROB_PACKET		retire_pkt				[0:`MACHINE_WIDTH-1],

	input		STQ_ENTRY				stq_entry				[0:`STQ_DEPTH-1],	
	output		LDQ_ENTRY				ldq_entry				[0:`LDQ_DEPTH-1]	
);



	reg		[`LDQ_WIDTH-1:0]		head_ptr;	
	reg		[`LDQ_WIDTH-1:0]		tail_ptr;
	reg								head_pos_bit;
	reg								tail_pos_bit;
	reg		[`LDQ_WIDTH-1:0]		next_head_ptr;	
	reg		[`LDQ_WIDTH-1:0]		next_tail_ptr;
	reg								next_head_pos_bit;
	reg								next_tail_pos_bit;
	wire							head_ptr_overflow;
	wire							tail_ptr_overflow;
	wire	[`LDQ_WIDTH-1:0]		head_ptr_plus1;	
	wire	[`LDQ_WIDTH-1:0]		head_ptr_plus2;	
	wire	[`LDQ_WIDTH-1:0]		head_ptr_plus3;	
	wire	[`LDQ_WIDTH-1:0]		tail_ptr_plus1;	
	wire	[`LDQ_WIDTH-1:0]		tail_ptr_plus2;	
	wire	[`LDQ_WIDTH-1:0]		tail_ptr_plus3;

	wire	[`MACHINE_WIDTH:0]		dispatch_cnt;
	wire	[`MACHINE_WIDTH:0]		retire_cnt;
	
	wire	[`STQ_DEPTH-1:0]		stq_addr_valid;
	wire	[`LDQ_DEPTH-1:0]		st_ld_violation_N;
	wire	[`LDQ_DEPTH-1:0]		ld_wakeup_N;		//wakeup when 1)ld addr known 2) all dependent store addr known 3)not fired
	wire	[`LDQ_DEPTH-1:0]		ld_writeback_N;		//writeback when 1)ld data valid 2) not writebacked
	reg		[`LDQ_WIDTH-1:0]		writeback_ldq_idx;	//select 1 out of n unwritebacked entry
	reg		[`LDQ_WIDTH-1:0]		fire_ldq_idx;		//select 1 out of n wakeup entry
	wire							fire_ld_accept;
	wire	[`LDQ_DEPTH-1:0]		dcache_data_accept;
	wire	[`LDQ_DEPTH-1:0]		fwd_data_accept;



	assign dispatch_cnt 		= 	dispatch_valid[3] +
									dispatch_valid[2] +
									dispatch_valid[1] +
									dispatch_valid[0] ;

	assign retire_cnt			=	(retire_pkt[0].packet_valid && retire_pkt[0].rd_mem) +
									(retire_pkt[1].packet_valid && retire_pkt[1].rd_mem) +
									(retire_pkt[2].packet_valid && retire_pkt[2].rd_mem) +
									(retire_pkt[3].packet_valid && retire_pkt[3].rd_mem) ;

	assign dispatch_ready 		= 	next_head_pos_bit==next_tail_pos_bit ? 
									(next_head_ptr+`LDQ_DEPTH-next_tail_ptr)>=4 :
									(next_head_ptr-next_tail_ptr)>=4;

	assign head_ptr_plus1 		= 	head_ptr + 1;
	assign head_ptr_plus2 		= 	head_ptr + 2;
	assign head_ptr_plus3 		= 	head_ptr + 3;	
	assign tail_ptr_plus1 		= 	tail_ptr + 1;
	assign tail_ptr_plus2 		= 	tail_ptr + 2;
	assign tail_ptr_plus3 		= 	tail_ptr + 3;

	assign head_ptr_overflow 	= 	head_ptr[`LDQ_WIDTH-1]==1 &&
   									next_head_ptr[`LDQ_WIDTH-1]==0;
	assign tail_ptr_overflow 	= 	tail_ptr[`LDQ_WIDTH-1]==1 && 
									next_tail_ptr[`LDQ_WIDTH-1]==0;

	always@(*) begin
		next_head_ptr 		= head_ptr + retire_cnt;
		next_tail_ptr 		= tail_ptr + dispatch_cnt;
		next_head_pos_bit 	= head_ptr_overflow ? ~head_pos_bit : head_pos_bit;
		next_tail_pos_bit 	= tail_ptr_overflow ? ~tail_pos_bit : tail_pos_bit;
	end



	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			tail_ptr 		<= 0;
			head_ptr 		<= 0;
			tail_pos_bit 	<= 0;
			head_pos_bit 	<= 0;
		end
		else if(pipe_flush) begin
			tail_ptr 		<= 0;
			head_ptr 		<= 0;
			tail_pos_bit 	<= 0;
			head_pos_bit 	<= 0;
		end		
		else begin
			tail_ptr 		<= next_tail_ptr;
			head_ptr 		<= next_head_ptr;
			tail_pos_bit 	<= next_tail_pos_bit;
			head_pos_bit 	<= next_head_pos_bit;
		end
	end





	/***************store-load violation check***************/
	//check ordering failure when a store addr is written to stq
	//ordering failure occurs when
	//1) ld st addr match
	//2) st is in front of the ld
	//3) ld has data(by fwd) or fired
	genvar i;
	generate
		for(i=0;i<`LDQ_DEPTH;i=i+1) begin
			assign st_ld_violation_N[i] = 	ldq_entry[i].addr[`XLEN-1:2]==execute_st_addr[`XLEN-1:2] && 
											ldq_entry[i].addr_valid && execute_st_addr_valid &&
											ldq_entry[i].st_mask[execute_st_addr_stq_tag] &&
											(ldq_entry[i].data_valid || (i==fwd_ldq_tag && fwd_valid) || 
											ldq_entry[i].fired || (fire_ld_accept && i==fire_ld_ldq_tag)); //already get data(fwd) or fired
		end
	endgenerate





	/***************************fire load logic***********************/
	generate
		for(i=0;i<`LDQ_DEPTH;i=i+1) begin
			assign ld_wakeup_N[i]	= 	//ldq_entry[i].entry_valid && 
										(ldq_entry[i].addr_valid || (execute_ld_valid && i==execute_ld_ldq_tag)) &&
										~ldq_entry[i].data_valid &&
							   			~ldq_entry[i].sleep &&	
										~(ldq_entry[i].fired || (fire_ld_accept && i==fire_ld_ldq_tag)) &&
									   	~(fwd_valid && i==fwd_ldq_tag && ~ldq_entry[i].order_fail) ;
		end
	endgenerate


	//select 1 out of n wakeup entry
	`ifndef LSQ_OLDEST_FIRST
	always_comb begin
		fire_ldq_idx = 0;
		for(int i=`STQ_DEPTH-1;i>=0;i--) begin
			if(ld_wakeup_N[i]) begin
				fire_ldq_idx = i;
			end
		end
	end
	`else
	wire 	[`LDQ_DEPTH-1:0]	wakeup_age_mask;
	wire 	[`LDQ_DEPTH*2-1:0]	wakeup_double;
	reg 	[`LDQ_WIDTH:0]		fire_ldq_idx_double;

	assign wakeup_double	=	{ld_wakeup_N, ld_wakeup_N & wakeup_age_mask};
	assign fire_ldq_idx 	=	fire_ldq_idx_double[`LDQ_WIDTH-1:0];

	generate
		for(i=0;i<`LDQ_DEPTH;i=i+1) begin
			assign wakeup_age_mask[i]	=	i<head_ptr ? 1'b0 : 1'b1;
		end
	endgenerate

	always_comb begin
		fire_ldq_idx_double = 0;
		for(int i=`LDQ_DEPTH*2-1;i>=0;i--) begin
			if(wakeup_double[i]) begin
				fire_ldq_idx_double = i;
			end
		end
	end
	`endif



	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			fire_ld_valid <= 0;
		else if(pipe_flush)
			fire_ld_valid <= 0;
		else
			fire_ld_valid <= ld_wakeup_N[fire_ldq_idx];
	end


	always@(posedge clk) begin
		fire_ld_addr		<=	ldq_entry[fire_ldq_idx].addr_valid ? ldq_entry[fire_ldq_idx].addr			:	execute_ld_addr			;
		fire_ld_data_size	<=	ldq_entry[fire_ldq_idx].addr_valid ? ldq_entry[fire_ldq_idx].data_size		: 	execute_ld_data_size	;
		fire_ld_st_mask		<=	ldq_entry[fire_ldq_idx].st_mask		;
		fire_ld_st_youngest	<=	ldq_entry[fire_ldq_idx].st_youngest	;
		fire_ld_ldq_tag		<=	fire_ldq_idx;	                                                                      	
	end
	
	assign fire_ld_accept 		= 	fire_ld_valid && fire_ld_ready;
	assign dcache_ready			= 	1;	


	generate
		for(i=0;i<`LDQ_DEPTH;i=i+1) begin
			assign fire_ld_kill[i]	=	(i==fwd_ldq_tag && (fwd_valid || fwd_sleep)) || 
										(st_ld_violation_N[i] && ~ldq_entry[i].data_valid) ; 
		end
	endgenerate







	/*************************writeback selection***********************/
	//writeback when
	//1) all dependent store addr are valid (performed st-ld dependency check) and
	//2) ldq has unwritebacked data or 
	//3) stq is forwarding data or
	//4) dcache is returning data
	generate
		for(i=0;i<`LDQ_DEPTH;i=i+1) begin
			assign ld_writeback_N[i]	=	(ldq_entry[i].st_mask & stq_addr_valid)==ldq_entry[i].st_mask && 
											((ldq_entry[i].data_valid && ~ldq_entry[i].writebacked)||
											fwd_data_accept[i] ||
											dcache_data_accept[i]);
		end
	endgenerate

	//select 1 out of n data_valid but not writebacked entry
	`ifndef LSQ_OLDEST_FIRST
	always_comb begin
		writeback_ldq_idx = 0;
		for(int i=`LDQ_DEPTH-1;i>=0;i--) begin
			if(ld_writeback_N[i]) begin
				writeback_ldq_idx = i;
			end
		end
	end
	`else 
	wire [`LDQ_DEPTH-1:0]	writeback_age_mask;
	wire [`LDQ_DEPTH*2-1:0]	writeback_double;
	reg [`LDQ_WIDTH:0]		writeback_ldq_idx_double;

	assign writeback_double		=	{ld_writeback_N, ld_writeback_N & writeback_age_mask};
	assign writeback_ldq_idx	= 	writeback_ldq_idx_double[`LDQ_WIDTH-1:0];

	generate
		for(i=0;i<`LDQ_DEPTH;i=i+1) begin
			assign writeback_age_mask[i]	=	i<head_ptr ? 1'b0 : 1'b1;
		end
	endgenerate
	
	always_comb begin
		writeback_ldq_idx_double = 0;
		for(int i=`LDQ_DEPTH*2-1;i>=0;i--) begin
			if(writeback_double[i]) begin
				writeback_ldq_idx_double = i;
			end
		end
	end
	`endif


	assign writeback_valid		=	ld_writeback_N!=0;
	assign writeback_data		=	writeback_ldq_idx==fwd_ldq_tag && fwd_valid ? fwd_data : 
									writeback_ldq_idx==dcache_ldq_tag && dcache_valid && ~fire_ld_kill[dcache_ldq_tag] ? dcache_data :
									ldq_entry[writeback_ldq_idx].data;
	assign writeback_pc			=	ldq_entry[writeback_ldq_idx].pc			;
	assign writeback_dest_prn	=	ldq_entry[writeback_ldq_idx].dest_prn	;
	assign writeback_rob_tag	=	ldq_entry[writeback_ldq_idx].rob_tag	;








	generate
		for(i=0;i<`STQ_DEPTH;i=i+1) begin
			assign stq_addr_valid[i] 		=	stq_entry[i].addr_valid && stq_entry[i].entry_valid;
			assign dcache_data_accept[i]	=	i==dcache_ldq_tag && dcache_valid && ~fire_ld_kill[dcache_ldq_tag];
			assign fwd_data_accept[i]		=	i==fwd_ldq_tag && fwd_valid && ~ldq_entry[i].order_fail;
		end

		for(i=0;i<`LDQ_DEPTH;i=i+1) begin
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) begin
					ldq_entry[i].entry_valid		<= 0;
					ldq_entry[i].addr_valid 		<= 0;
					ldq_entry[i].st_mask	 		<= 0;
					ldq_entry[i].st_youngest		<= 0;
					ldq_entry[i].fwd_stq_tag		<= 0;
					ldq_entry[i].sleep				<= 0;
					ldq_entry[i].fired		 		<= 0;
					ldq_entry[i].data_valid	 		<= 0;
					ldq_entry[i].writebacked 		<= 0;
					ldq_entry[i].order_fail 		<= 0;
				end
				else if(pipe_flush) begin
					ldq_entry[i].entry_valid		<= 0;
					ldq_entry[i].addr_valid 		<= 0;
					ldq_entry[i].st_mask	 		<= 0;
					ldq_entry[i].st_youngest		<= 0;
					ldq_entry[i].fwd_stq_tag		<= 0;
					ldq_entry[i].sleep				<= 0;
					ldq_entry[i].fired		 		<= 0;
					ldq_entry[i].data_valid	 		<= 0;
					ldq_entry[i].writebacked 		<= 0;
					ldq_entry[i].order_fail 		<= 0;
				end
				else begin
					/************************allocate************************/
					case(dispatch_valid)
						4'b0001: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid 	<= 1;	
							end				
						end	
						4'b0010: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid 	<= 1;	
							end				
						end	
						4'b0100: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid 	<= 1;	
							end				
						end	
						4'b1000: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid 	<= 1;	
							end				
						end	
						4'b0011: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid 	<= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b0101: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid 	<= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b1001: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid 	<= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b0110: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid 	<= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid 	<= 1;
							end
						end
						4'b1010: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid 	<= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b1100: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid 	<= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b0111: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus2) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b1011: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus2) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b1101: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus2) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b1110: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus2) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						4'b1111: begin
							if(i==tail_ptr) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[0];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[0];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus1) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[1];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[1];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus2) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[2];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[2];	
								ldq_entry[i].entry_valid <= 1;
							end
							else if(i==tail_ptr_plus3) begin
								ldq_entry[i].st_mask 		<= dispatch_st_mask[3];	
								ldq_entry[i].st_youngest 		<= dispatch_st_youngest[3];	
								ldq_entry[i].entry_valid <= 1;
							end
						end
						default: begin
							ldq_entry[i].st_mask 			<= ldq_entry[i].st_mask;	
							ldq_entry[i].entry_valid 		<= ldq_entry[i].entry_valid;
						end
					endcase


	


					/*******************write addr and size******************/
					if(i==execute_ld_ldq_tag && execute_ld_valid) begin
						ldq_entry[i].data_size	<= execute_ld_data_size;	
						ldq_entry[i].addr 		<= execute_ld_addr;	
						ldq_entry[i].addr_valid <= 1;
						ldq_entry[i].pc 		<= execute_ld_pc;
						ldq_entry[i].dest_prn	<= execute_ld_prn;
						ldq_entry[i].rob_tag 	<= execute_ld_rob_tag;
					end
					
					assert property (@(posedge clk) i==execute_ld_ldq_tag && execute_ld_valid |-> ldq_entry[i].entry_valid);


					/**********************update st_mask********************/
					if(fire_st_valid && fire_st_ready)
						ldq_entry[i].st_mask[fire_st_stq_tag] <= 0;


					/***********************update sleep*********************/
					if(st_ld_violation_N[i]) begin
						ldq_entry[i].sleep <= 0;
					end
					else if(i==fwd_ldq_tag && fwd_sleep) begin
						if(fire_st_valid && fire_st_ready && fire_st_stq_tag==fwd_stq_tag) begin //discard sleep if fire st and sleep is asserted at the same time
							ldq_entry[i].sleep 			<= 0;
						end
						else begin
							ldq_entry[i].sleep 			<= 1;
							ldq_entry[i].fwd_stq_tag 	<= fwd_stq_tag;
						end
					end
					else if(ldq_entry[i].fwd_stq_tag==fire_st_stq_tag && fire_st_valid && fire_st_ready) begin
						ldq_entry[i].sleep 			<= 0;
					end
					
					assert property (@(posedge clk) i==fwd_ldq_tag && fwd_sleep |-> ldq_entry[i].entry_valid);
	

					/********************update order fail*******************/
					if(st_ld_violation_N[i]) 
						ldq_entry[i].order_fail <= 1;
					else if(i==fire_ld_ldq_tag && fire_ld_valid && ~fire_ld_kill[i])	//clear the bit at refire
						ldq_entry[i].order_fail <= 0;


					/*********************update fire mem********************/
					if(st_ld_violation_N[i]) begin
						ldq_entry[i].fired <= 0;
					end
					else if(i==fire_ld_ldq_tag && fire_ld_accept) begin //set fired=1 when req is accept by dcache
						if(fire_ld_kill[i])								//ignore if the fire ld in the current cycle is killed
							ldq_entry[i].fired <= 0;
						else
							ldq_entry[i].fired <= 1;
					end
					else if(i==fwd_ldq_tag && fwd_sleep) 				//reset on sleep
						ldq_entry[i].fired <= 0;
					
					assert property (@(posedge clk) i==fire_ld_ldq_tag && fire_ld_accept |-> ldq_entry[i].entry_valid);
					

					/***********************write data************************/
					if(st_ld_violation_N[i]) begin															
						ldq_entry[i].data_valid 	<= 0;
					end
					else if(fwd_data_accept[i]) begin				//accepted from fwd
						ldq_entry[i].data 			<= fwd_data;
						ldq_entry[i].data_valid 	<= 1;
					end
					else if(dcache_data_accept[i]) begin	//accepted from dcache
						ldq_entry[i].data 			<= dcache_data;
						ldq_entry[i].data_valid 	<= 1;
					end
				
					assert property (@(posedge clk) dcache_data_accept[i] |-> ldq_entry[i].entry_valid);
					assert property (@(posedge clk) dcache_data_accept[i] |-> ldq_entry[i].fired);
					assert property (@(posedge clk) ldq_entry[i].data_valid |-> ldq_entry[i].entry_valid);
					assert property (@(posedge clk) ldq_entry[i].data_valid |-> ldq_entry[i].addr_valid);
						

					/***********************writeback************************/
					if(i==writeback_ldq_idx && writeback_valid && writeback_ready)	
						ldq_entry[i].writebacked	<= 1;

					assert property (@(posedge clk) i==writeback_ldq_idx && writeback_valid |-> ldq_entry[i].entry_valid);


					/*************************retire*************************/
					if(i==retire_pkt[0].ldq_tag && retire_pkt[0].rd_mem && retire_pkt[0].packet_valid) begin
						ldq_entry[i].addr_valid 	<= 0;
						ldq_entry[i].st_mask	 	<= 0;
						ldq_entry[i].fired		 	<= 0;
						ldq_entry[i].data_valid	 	<= 0;
						ldq_entry[i].writebacked 	<= 0;
						ldq_entry[i].entry_valid	<= 0;
					end
					if(i==retire_pkt[1].ldq_tag && retire_pkt[1].rd_mem && retire_pkt[1].packet_valid) begin
						ldq_entry[i].addr_valid 	<= 0;
						ldq_entry[i].st_mask	 	<= 0;
						ldq_entry[i].fired		 	<= 0;
						ldq_entry[i].data_valid	 	<= 0;
						ldq_entry[i].writebacked 	<= 0;
						ldq_entry[i].entry_valid	<= 0;
					end
					if(i==retire_pkt[2].ldq_tag && retire_pkt[2].rd_mem && retire_pkt[2].packet_valid) begin
						ldq_entry[i].addr_valid 	<= 0;
						ldq_entry[i].st_mask	 	<= 0;
						ldq_entry[i].fired		 	<= 0;
						ldq_entry[i].data_valid	 	<= 0;
						ldq_entry[i].writebacked 	<= 0;
						ldq_entry[i].entry_valid	<= 0;
					end
					if(i==retire_pkt[3].ldq_tag && retire_pkt[3].rd_mem && retire_pkt[3].packet_valid) begin
						ldq_entry[i].addr_valid 	<= 0;
						ldq_entry[i].st_mask	 	<= 0;
						ldq_entry[i].fired		 	<= 0;
						ldq_entry[i].data_valid	 	<= 0;
						ldq_entry[i].writebacked 	<= 0;
						ldq_entry[i].entry_valid	<= 0;
					end
					
					assert property (@(posedge clk) i==retire_pkt[0].ldq_tag && retire_pkt[0].rd_mem && retire_pkt[0].packet_valid |-> ldq_entry[i].order_fail==0);
					assert property (@(posedge clk) i==retire_pkt[1].ldq_tag && retire_pkt[1].rd_mem && retire_pkt[1].packet_valid |-> ldq_entry[i].order_fail==0);
					assert property (@(posedge clk) i==retire_pkt[2].ldq_tag && retire_pkt[2].rd_mem && retire_pkt[2].packet_valid |-> ldq_entry[i].order_fail==0);
					assert property (@(posedge clk) i==retire_pkt[3].ldq_tag && retire_pkt[3].rd_mem && retire_pkt[3].packet_valid |-> ldq_entry[i].order_fail==0);
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

	
endmodule
