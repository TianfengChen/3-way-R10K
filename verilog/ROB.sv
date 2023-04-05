//////////////////////////////////////////////////////////////////////////////
//                                                                          //
//   Modulename :  ROB.sv                                                    //
//                                                                          //
//  Description :  This module creates the Reorder Buffer reordering        // 
//                 instruction after out of order execution to address the  //
//                 control hazard in R10K Tomasulo Algorithm with superscal-// 
//                 ar and early branch resolusion                           //
//                 programmer: Tianfeng Chen (tfchen)                       //
//////////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps

module ROB(
	//inputs
        input	clock,
        input	reset,
////////input signals from ID stage
	input	ID_EX_PACKET 			id_packet_in_2,
	input	ID_EX_PACKET 			id_packet_in_1,
	input	ID_EX_PACKET 			id_packet_in_0,
////////input signals from CDB
	input	[`N_WAY-1:0]			cdb_valid,
	input	[(`N_WAY)*32-1:0]		cdb_value,
	input	[(`N_WAY)*(`PRF_WIDTH)-1:0]	cdb_tag,
	input	[(`N_WAY)*(`ROB_WIDTH)-1:0]	cdb_rob,
	input	[`N_WAY-1:0]			cdb_cond_branch,
	input	[`N_WAY-1:0]			cdb_uncond_branch,
////////input signals from FU
	input	[`XLEN-1:0]			FU_branch_target_addr,		
	input 		  			FU_branch_taken,
	input	[`XLEN-1:0]			FU_store_addr,
	input	[63:0]				FU_store_data,
	input					FU_store_en,
	input	[`ROB_WIDTH-1:0]		FU_rob,
////////input signals from Dcache_controller
	input					store_commit_valid,
	//outputs
	output	logic	[(`N_WAY)*(`ROB_WIDTH)-1:0] ROB_num,	//to RS
	output	logic	[`ROB_WIDTH:0]		rob_hazard_num,
	output	logic				nuke,
	output	EXCEPTION_CODE   		error_status,
	output	logic	[3:0]			completed_insts,
	output	ROB_PACKET			ROB_packet_out_2,
	output	ROB_PACKET			ROB_packet_out_1,
	output 	ROB_PACKET			ROB_packet_out_0,
	output	ROB_IF_BRANCH_PACKET		ROB_branch_out_2,
	output	ROB_IF_BRANCH_PACKET		ROB_branch_out_1,
	output	ROB_IF_BRANCH_PACKET		ROB_branch_out_0,
	output	logic	[`ROB_SIZE-1:0]		load_ready
);
////////ROB state machine
	logic	[`ROB_WIDTH-1:0]	head;
	logic	[`ROB_WIDTH-1:0]	tail;
	ROB_PACKET			ROB		[`ROB_SIZE];
	logic	[`ROB_WIDTH-1:0]	next_head;
	logic	[`ROB_WIDTH-1:0]	next_tail;
	ROB_PACKET			next_ROB	[`ROB_SIZE];
	logic				next_nuke;
////////3-way superscalar dispatch
	logic	[`N_WAY-1:0] [`ROB_WIDTH-1:0]	next_3_tail;
	logic	[`N_WAY-1:0] [`ROB_WIDTH-1:0]	next_3_head;
////////3-way commit
	logic	[`N_WAY-1:0]		illegal_array;
	logic	[`N_WAY-1:0]		halt_array;
	logic	[`N_WAY-1:0]		commit_array;
	logic	[`N_WAY-1:0]		nuke_array;
	logic	[`N_WAY-1:0]		store_array;
////////Store counter
	logic	[`N_WIDTH-1:0]		fetch_cnt	[`N_WAY];
	logic	[`N_WIDTH-1:0]		commit_cnt;
	logic	[`ROB_WIDTH-1:0]	tail_cnt;
	logic	[`ROB_WIDTH-1:0]	next_tail_cnt;
	logic	[(`ROB_SIZE)*(`ROB_WIDTH)-1:0]	store_cnt;
	logic	[(`ROB_SIZE)*(`ROB_WIDTH)-1:0]	next_store_cnt;
////////Store commit
	logic	[`N_WAY-1:0]		is_load;
////////For DVE
	logic	[`ROB_WIDTH-1:0]	next_store_cnt_dve	[`ROB_SIZE];
	logic	[`ROB_WIDTH-1:0]	store_cnt_dve		[`ROB_SIZE];	
	always_comb begin
		for(int i=0;i<`ROB_SIZE;i=i+1) begin
			next_store_cnt_dve[i] = next_store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH];
			store_cnt_dve[i]      = store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH];			
		end
	end
////////determine tails
	always_comb begin
		casez({`ROB_WIDTH{1'b1}}-tail)
			0: begin
				next_3_tail[2] = 0;
				next_3_tail[1] = 1;
				next_3_tail[0] = 2;
			end	
			1: begin
				next_3_tail[2] = {`ROB_WIDTH{1'b1}};
				next_3_tail[1] = 0;
				next_3_tail[0] = 1;
			end
			2: begin
				next_3_tail[2] = {{(`ROB_WIDTH-1){1'b1}},1'b0};
				next_3_tail[1] = {`ROB_WIDTH{1'b1}};
				next_3_tail[0] = 0;
			end
			default: begin
				next_3_tail[2] = tail+1;
				next_3_tail[1] = tail+2;
				next_3_tail[0] = tail+3;
			end
		endcase
	end
////////determing heads	
	always_comb begin
		casez({`ROB_WIDTH{1'b1}}-head)
			0: begin
				next_3_head[2] = 0;
				next_3_head[1] = 1;
				next_3_head[0] = 2;
			end	
			1: begin
				next_3_head[2] = {`ROB_WIDTH{1'b1}};
				next_3_head[1] = 0;
				next_3_head[0] = 1;
			end
			2: begin
				next_3_head[2] = {{(`ROB_WIDTH-1){1'b1}},1'b0};
				next_3_head[1] = {`ROB_WIDTH{1'b1}};
				next_3_head[0] = 0;
			end
			default: begin
				next_3_head[2] = head+1;
				next_3_head[1] = head+2;
				next_3_head[0] = head+3;
			end
		endcase
	end

	always_comb begin
		for(int i=0;i<`ROB_SIZE;i=i+1) begin
			next_ROB[i] = ROB[i];
////////////////////////ROB fetch
			if(i==tail) begin
				if(id_packet_in_2.valid) begin
					next_ROB[i].id_packet			= id_packet_in_2;
					next_ROB[i].valid	   		= id_packet_in_2.valid;
					next_ROB[i].commit			= (id_packet_in_2.halt | id_packet_in_2.illegal) ? 1 : 0;
					next_ROB[i].branch_true_taken 		= 1'b0;
					next_ROB[i].branch_true_target_PC 	= {`XLEN{1'b0}};
					next_ROB[i].branch_mispredict 		= 1'b0;
					next_ROB[i].branch_true_PC 		= {`XLEN{1'b0}};
					next_ROB[i].proc2mem_addr 		= {`XLEN{1'b0}};
					next_ROB[i].proc2mem_data 		= 64'b0;
					next_ROB[i].proc2mem_size 		= DOUBLE;
				end
			end//if(i==tail)
			if(i==next_3_tail[2]) begin
				if(id_packet_in_1.valid) begin
					next_ROB[i].id_packet 			= id_packet_in_1;
					next_ROB[i].valid	 		= id_packet_in_1.valid;
					next_ROB[i].commit    			= (id_packet_in_1.halt | id_packet_in_1.illegal) ? 1 : 0;
					next_ROB[i].branch_true_taken 		= 1'b0;
					next_ROB[i].branch_true_target_PC 	= {`XLEN{1'b0}};
					next_ROB[i].branch_mispredict 		= 1'b0;
					next_ROB[i].branch_true_PC 		= {`XLEN{1'b0}};
					next_ROB[i].proc2mem_addr 		= {`XLEN{1'b0}};
					next_ROB[i].proc2mem_data 		= 64'b0;
					next_ROB[i].proc2mem_size 		= DOUBLE;
				end
			end//if(i==next_3_tail[2])
			if(i==next_3_tail[1]) begin
				if(id_packet_in_0.valid) begin
					next_ROB[i].id_packet 			= id_packet_in_0;
					next_ROB[i].valid	   		= id_packet_in_0.valid;
					next_ROB[i].commit    			= (id_packet_in_0.halt | id_packet_in_0.illegal) ? 1 : 0;
					next_ROB[i].branch_true_taken 		= 1'b0;
					next_ROB[i].branch_true_target_PC 	= {`XLEN{1'b0}};
					next_ROB[i].branch_mispredict 		= 1'b0;
					next_ROB[i].branch_true_PC		= {`XLEN{1'b0}};
					next_ROB[i].proc2mem_addr 		= {`XLEN{1'b0}};
					next_ROB[i].proc2mem_data 		= 64'b0;
					next_ROB[i].proc2mem_size 		= DOUBLE;
				end
			end//if(i==next_3_tail[1])
////////////////////////ROB get CDB broadcast
			for(int a=0;a<`N_WAY;a=a+1) begin
				if(i==cdb_rob[a*`ROB_WIDTH +: `ROB_WIDTH]) begin
					if(cdb_valid[a] | cdb_cond_branch[a]) begin
						next_ROB[i].commit = 1'b1;
					end//if(cdb_valid[a])
					if((cdb_valid[a] | cdb_cond_branch[a]) & (cdb_uncond_branch[a] | cdb_cond_branch[a])) begin
						next_ROB[i].branch_true_taken 		= FU_branch_taken;
						next_ROB[i].branch_true_target_PC 	= FU_branch_target_addr;
						if(ROB[i].id_packet.branch_predict) begin
							if(FU_branch_taken) begin
								if(ROB[i].id_packet.predict_PC == FU_branch_target_addr) begin
									next_ROB[i].branch_mispredict 	= 1'b0;
									next_ROB[i].branch_true_PC	= FU_branch_target_addr;
								end//PC is same
								else begin
									next_ROB[i].branch_mispredict 	= 1'b1;
									next_ROB[i].branch_true_PC 	= FU_branch_target_addr;
								end//PC is not same
							end//actuall taken
							else begin
								next_ROB[i].branch_mispredict 	= 1'b1;
								next_ROB[i].branch_true_PC 	= ROB[i].id_packet.NPC;
							end//actually not taken
						end//predicted taken
						else begin
							if(FU_branch_taken) begin
								next_ROB[i].branch_mispredict 	= 1'b1;
								next_ROB[i].branch_true_PC 	= FU_branch_target_addr;
							end//actually taken
							else begin
								next_ROB[i].branch_mispredict 	= 1'b0;
								next_ROB[i].branch_true_PC 	= ROB[i].id_packet.NPC;
							end//actully not taken
						end//predicted not taken
					end//if((cdb_valid[a] | cdb_cond_branch[a]) & (cdb_uncond_branch[a] | cdb_cond_branch[a]))
				end//if(i=cdb_rob[a])
				if(i==FU_rob & FU_store_en) begin
					next_ROB[i].commit = 1'b1;
					next_ROB[i].proc2mem_addr = FU_store_addr;
					next_ROB[i].proc2mem_data = FU_store_data;
					next_ROB[i].proc2mem_size = ROB[i].id_packet.inst.r.funct3; 
				end//if(i==FU_rob & FU_store_en) begin
			end//for(int a=0;a<`N_WAY;a=a+1)
////////////////////////ROB commit
			if(i==head) begin
				if(commit_array[2]) begin
					if(is_load[2] & store_commit_valid==0) begin
						next_ROB[i].commit = 1'b1;
						next_ROB[i].valid  = 1'b1;	
					end
					else begin
						next_ROB[i].commit = 1'b0;
						next_ROB[i].valid  = 1'b0;	
					end
				end
			end//if(i==head)
			if(i==next_3_head[2]) begin
				if(commit_array[1]) begin
					if(is_load[1] & store_commit_valid==0) begin
						next_ROB[i].commit = 1'b1;
						next_ROB[i].valid  = 1'b1;
					end
					else if(is_load[2]) begin
						next_ROB[i].commit = 1'b1;
						next_ROB[i].valid  = 1'b1;
					end
					else begin
						next_ROB[i].commit = 1'b0;
						next_ROB[i].valid  = 1'b0;	
					end
				end
			end//if(i==next_3_head[2])
			if(i==next_3_head[1]) begin
				if(commit_array[0]) begin
					if(is_load[0] & store_commit_valid==0) begin
						next_ROB[i].commit = 1'b1;
						next_ROB[i].valid  = 1'b1;
					end
					else if(is_load[2] | is_load[1]) begin
						next_ROB[i].commit = 1'b1;
						next_ROB[i].valid  = 1'b1;
					end
					else begin
						next_ROB[i].commit = 1'b0;
						next_ROB[i].valid  = 1'b0;	
					end
				end
			end//if(i==next_3_head[1])
		end//for(int i=0;i<`ROB_SIZE;i=i+1)
	end
////////ROB commit
	assign	commit_array[2]  = ROB[head].valid & ROB[head].commit & ~nuke;
	assign	illegal_array[2] = commit_array[2] & ROB[head].id_packet.illegal;
	assign	halt_array[2]	 = commit_array[2] & ~illegal_array[2] & ROB[head].id_packet.halt;
	assign	nuke_array[2]	 = commit_array[2] & (halt_array[2] | illegal_array[2] | ROB[head].branch_mispredict);

	assign	commit_array[1]  = ROB[next_3_head[2]].valid & ROB[next_3_head[2]].commit & commit_array[2] & ~nuke_array[2] & ~ROB[head].id_packet.wr_mem & ~ROB[next_3_head[2]].id_packet.halt;
	assign	illegal_array[1] = commit_array[1] & ROB[next_3_head[2]].id_packet.illegal;
	assign	halt_array[1]	 = commit_array[1] & ~illegal_array[1] & ROB[next_3_head[2]].id_packet.halt;
	assign	nuke_array[1]	 = commit_array[1] & (halt_array[1] | illegal_array[1] | ROB[next_3_head[2]].branch_mispredict);

	assign	commit_array[0]  = ROB[next_3_head[1]].valid & ROB[next_3_head[1]].commit & commit_array[1] & ~nuke_array[1] & ~(ROB[head].id_packet.wr_mem | ROB[next_3_head[2]].id_packet.wr_mem) & ~ROB[next_3_head[1]].id_packet.halt;
	assign	illegal_array[0] = commit_array[0] & ROB[next_3_head[1]].id_packet.illegal;
	assign	halt_array[0]	 = commit_array[0] & ~illegal_array[0] & ROB[next_3_head[1]].id_packet.halt;
	assign	nuke_array[0]	 = commit_array[0] & (halt_array[0] | illegal_array[0] | ROB[next_3_head[1]].branch_mispredict);

	assign	is_load		 = {commit_array[2]&ROB[head].id_packet.wr_mem,commit_array[1]&ROB[next_3_head[2]].id_packet.wr_mem,commit_array[0]&ROB[next_3_head[1]].id_packet.wr_mem};

	always_comb begin
		ROB_packet_out_2 = ROB[head];
		ROB_packet_out_1 = ROB[next_3_head[2]];
		ROB_packet_out_0 = ROB[next_3_head[1]];
		if(commit_array[2] == 0 | illegal_array[2] == 1)
			ROB_packet_out_2.commit = 1'b0;
		if(commit_array[1] == 0 | illegal_array[1] == 1)
			ROB_packet_out_1.commit = 1'b0;
		if(commit_array[0] == 0 | illegal_array[0] == 1)
			ROB_packet_out_0.commit = 1'b0;
	end

	always_comb begin
		if(commit_array[2]) begin
			ROB_branch_out_2.uncond_branch = ROB[head].id_packet.uncond_branch;
			ROB_branch_out_2.cond_branch = ROB[head].id_packet.cond_branch;
			ROB_branch_out_2.branch_is_taken = ROB[head].id_packet.branch_predict;
			ROB_branch_out_2.branch_PC = ROB[head].id_packet.PC;
			ROB_branch_out_2.branch_target_PC = ROB[head].id_packet.predict_PC;
			ROB_branch_out_2.branch_true_taken = ROB[head].branch_true_taken;
			ROB_branch_out_2.branch_true_target_PC = ROB[head].branch_true_target_PC;
			ROB_branch_out_2.branch_misprediction = ROB[head].branch_mispredict;
			ROB_branch_out_2.branch_true_PC = ROB[head].branch_true_PC;
		end
		else begin
			ROB_branch_out_2 = {
				1'b0,		//uncond_branch
				1'b0,		//cond_branch
				1'b0,		//branch_is_taken
				{`XLEN{1'b0}},	//branch_PC
				{`XLEN{1'b0}},	//branch_target_PC
				1'b0,		//branch_true_taken
				{`XLEN{1'b0}},	//branch_true_target_PC
				1'b0,		//branch_misprediction
				{`XLEN{1'b0}}	//branch_true_PC
				};
		end

		if(commit_array[1]) begin
			ROB_branch_out_1.uncond_branch = ROB[next_3_head[2]].id_packet.uncond_branch;
			ROB_branch_out_1.cond_branch = ROB[next_3_head[2]].id_packet.cond_branch;
			ROB_branch_out_1.branch_is_taken = ROB[next_3_head[2]].id_packet.branch_predict;
			ROB_branch_out_1.branch_PC = ROB[next_3_head[2]].id_packet.PC;
			ROB_branch_out_1.branch_target_PC = ROB[next_3_head[2]].id_packet.predict_PC;
			ROB_branch_out_1.branch_true_taken = ROB[next_3_head[2]].branch_true_taken;
			ROB_branch_out_1.branch_true_target_PC = ROB[next_3_head[2]].branch_true_target_PC;
			ROB_branch_out_1.branch_misprediction = ROB[next_3_head[2]].branch_mispredict;
			ROB_branch_out_1.branch_true_PC = ROB[next_3_head[2]].branch_true_PC;
		end
		else begin
			ROB_branch_out_1 = {
				1'b0,		//uncond_branch
				1'b0,		//cond_branch
				1'b0,		//branch_is_taken
				{`XLEN{1'b0}},	//branch_PC
				{`XLEN{1'b0}},	//branch_target_PC
				1'b0,		//branch_true_taken
				{`XLEN{1'b0}},	//branch_true_target_PC
				1'b0,		//branch_misprediction
				{`XLEN{1'b0}}	//branch_true_PC
				};
		end

		if(commit_array[0]) begin
			ROB_branch_out_0.uncond_branch = ROB[next_3_head[1]].id_packet.uncond_branch;
			ROB_branch_out_0.cond_branch = ROB[next_3_head[1]].id_packet.cond_branch;
			ROB_branch_out_0.branch_is_taken = ROB[next_3_head[1]].id_packet.branch_predict;
			ROB_branch_out_0.branch_PC = ROB[next_3_head[1]].id_packet.PC;
			ROB_branch_out_0.branch_target_PC = ROB[next_3_head[1]].id_packet.predict_PC;
			ROB_branch_out_0.branch_true_taken = ROB[next_3_head[1]].branch_true_taken;
			ROB_branch_out_0.branch_true_target_PC = ROB[next_3_head[1]].branch_true_target_PC;
			ROB_branch_out_0.branch_misprediction = ROB[next_3_head[1]].branch_mispredict;
			ROB_branch_out_0.branch_true_PC = ROB[next_3_head[1]].branch_true_PC;
		end
		else begin
			ROB_branch_out_0 = {
				1'b0,		//uncond_branch
				1'b0,		//cond_branch
				1'b0,		//branch_is_taken
				{`XLEN{1'b0}},	//branch_PC
				{`XLEN{1'b0}},	//branch_target_PC
				1'b0,		//branch_true_taken
				{`XLEN{1'b0}},	//branch_true_target_PC
				1'b0,		//branch_misprediction
				{`XLEN{1'b0}}	//branch_true_PC
				};
		end
	end
////////next_head & next_tail
	assign	next_tail = id_packet_in_0.valid ? next_3_tail[0] : (id_packet_in_1.valid ? next_3_tail[1] : (id_packet_in_2.valid ? next_3_tail[2] : tail)); 
	assign	next_head = (commit_array[0] & !next_ROB[next_3_head[1]].commit) ? next_3_head[0] : ((commit_array[1] & !next_ROB[next_3_head[2]].commit) ? next_3_head[1] : ((commit_array[2] & !next_ROB[head].commit) ? next_3_head[2] : head));
	assign	ROB_num	  = {tail,next_3_tail[2],next_3_tail[1]};
////////Load&store
	assign fetch_cnt[2] = id_packet_in_2.valid & id_packet_in_2.wr_mem;
	assign fetch_cnt[1] = fetch_cnt[2] + (id_packet_in_1.valid & id_packet_in_1.wr_mem);
	assign fetch_cnt[0] = fetch_cnt[1] + (id_packet_in_0.valid & id_packet_in_0.wr_mem);
	assign commit_cnt   = 	(commit_array[2] & ROB_packet_out_2.id_packet.wr_mem & !next_ROB[head].commit) + 
							(commit_array[1] & ROB_packet_out_1.id_packet.wr_mem & !next_ROB[next_3_head[2]].commit) + 
							(commit_array[0] & ROB_packet_out_0.id_packet.wr_mem & !next_ROB[next_3_head[1]].commit);
	assign next_tail_cnt= tail_cnt + fetch_cnt[0] - commit_cnt;
	//counting the store before each instruction
	always_comb begin
		for(int i=0;i<`ROB_SIZE;i=i+1) begin
			if(((next_head<tail)&(i>=next_head)&(i<tail)) | ((next_head>tail)&((i>=next_head)|(i<tail))) | ((next_head==tail)&ROB[next_head].valid)) begin
				next_store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH] =  store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH] - commit_cnt;
			end
			else if(i==tail) begin
				next_store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH] =  tail_cnt - commit_cnt;
			end
			else if(i==next_3_tail[2]) begin
				next_store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH] =  tail_cnt + fetch_cnt[2] - commit_cnt;
			end
			else if(i==next_3_tail[1]) begin
				next_store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH] =  tail_cnt + fetch_cnt[1] - commit_cnt;
			end
			else begin
				next_store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH] =  next_tail_cnt;				
			end
		end
	end
	//determing which load inst can be issued
	always_comb begin
		for(int i=0;i<`ROB_SIZE;i=i+1) begin
			load_ready[i] = (store_cnt[i*`ROB_WIDTH +: `ROB_WIDTH]=={`ROB_WIDTH{1'b0}}) & ROB[i].valid & ROB[i].id_packet.rd_mem;
		end
	end
////////ROB_hazard_num
	always_comb begin
		if(next_head > next_tail) begin
			rob_hazard_num = next_head - next_tail;
		end
		else if(next_head < next_tail) begin
			rob_hazard_num = {{1'b1},{`ROB_WIDTH{1'b0}}} - (next_tail - next_head);
		end
		else if(next_ROB[next_head].valid) begin
			rob_hazard_num = {{1'b0},{`ROB_WIDTH{1'b0}}};
		end
		else begin
			rob_hazard_num = {{1'b1},{`ROB_WIDTH{1'b0}}};
		end
	end
////////pipeline error status & completed instructions
	always_comb begin
		if(illegal_array[2]) begin
			error_status = ILLEGAL_INST;
		end//if(illegal_array[2])
		else begin
			if(halt_array[2]) begin
				error_status = HALTED_ON_WFI;
			end//if(halt_array[2])
			else if(illegal_array[1]) begin
				error_status = ILLEGAL_INST;
			end//else if(illegal_array[1])
			else begin
				if(halt_array[1]) begin
					error_status = HALTED_ON_WFI;
				end//if(halt_array[1])
				else if(illegal_array[0]) begin
					error_status = ILLEGAL_INST;
				end//else if(illegal_array[0])
				else if(halt_array[0]) begin
					error_status = HALTED_ON_WFI;
				end//else if(halt_array[0])
				else begin
					error_status = NO_ERROR;
				end
			end//else
		end//else
	end
	assign completed_insts 	= 	(commit_array[2] & ~(ROB[head].id_packet.wr_mem & ~store_commit_valid)) + 
								(commit_array[1] & ~(ROB[next_3_head[2]].id_packet.wr_mem & ~store_commit_valid)) + 
								(commit_array[0] & ~(ROB[next_3_head[1]].id_packet.wr_mem & ~store_commit_valid));
	
////////nuke signal 
	assign	next_nuke = nuke_array[2] | nuke_array[1] | nuke_array[0];

	
	always_ff @(posedge clock) begin
		if(reset | nuke) begin
			head <= `SD 1'b0;
			tail <= `SD 1'b0;
			for(int i=0; i<`ROB_SIZE; i=i+1) begin
				ROB[i].valid				<= `SD 1'b0;
				ROB[i].commit				<= `SD 1'b0;
				ROB[i].branch_true_taken 		<= `SD 1'b0;
				ROB[i].branch_true_target_PC 		<= `SD {`XLEN{1'b0}};
				ROB[i].branch_mispredict 		<= `SD 1'b0;
				ROB[i].branch_true_PC 			<= `SD {`XLEN{1'b0}};
				ROB[i].proc2mem_addr 			<= `SD {`XLEN{1'b0}};
				ROB[i].proc2mem_data 			<= `SD 64'b0;
				ROB[i].proc2mem_size 			<= `SD DOUBLE;
				ROB[i].id_packet 			<= `SD {{`XLEN{1'b0}},		//NPC
													{`XLEN{1'b0}}, 		//PC
													{4'b0001},		//FU_type
													{`PRF_WIDTH{1'b0}},	//rs1_prf_value
													1'b0,			//rs1_use_prf
													1'b0,			//rs1_prf_valid
													{`XLEN{1'b0}}, 		//rs1_nprf_value
													1'b0,			//rs1_is_nprf
													{`PRF_WIDTH{1'b0}}, 	//rs2_prf_value
													1'b0,			//rs2_use_prf
													1'b0,			//rs2_prf_valid
													20'b0, 			//rs2_nprf_value
													1'b0,			//rs2_is_imm
													OPA_IS_RS1, 		//opa_select
													OPB_IS_RS2, 		//opb_select
													`NOP,			//inst
													`ZERO_REG,		//dest_reg_idx
													{`PRF_WIDTH{1'b0}}, 	//dest_prf_reg
													{`PRF_WIDTH{1'b0}},	//dest_old_prn
													ALU_ADD, 		//alu_func
													1'b0, 			//rd_mem
													1'b0, 			//wr_mem
													1'b0, 			//cond
													1'b0, 			//uncond
													1'b0,			//branch_predict
													{`XLEN{1'b0}},		//predict_PC
													1'b0, 			//halt
													1'b0, 			//illegal
													1'b0, 			//csr_op
													1'b0 			//valid
													};
			end
			nuke 		<= `SD 1'b0;
			tail_cnt 	<= `SD {`ROB_WIDTH{1'b0}};
			store_cnt	<= `SD {((`ROB_SIZE)*(`ROB_WIDTH)){1'b0}};
		end
		else begin
			head <= `SD next_head;
			tail <= `SD next_tail;
			ROB  <= `SD next_ROB;
			nuke <= `SD next_nuke;
			tail_cnt  <= `SD next_tail_cnt;
			store_cnt <= `SD next_store_cnt;
		end
	end	

endmodule

