`timescale 1ns/100ps

module rs_top(
	input								clk,
	input								rst,
	input [`N_WAY-1:0]					inst_valid_in ,		//asserted when IF is dispatching instruction
	input [32*(`N_WAY)-1:0] 			inst_in,				// from decoder
	input [32*(`N_WAY)-1:0] 			pc_in,				// from decoder
	input [32*(`N_WAY)-1:0] 			npc_in,				// from decoder
	input [5*(`N_WAY)-1:0] 				op_type_in, 		//from decoder						
	input [(`PRF_WIDTH)*(`N_WAY)-1:0] 	op1_prn_in, 		//from rat					
	input [(`PRF_WIDTH)*(`N_WAY)-1:0] 	op2_prn_in, 		//from rat		
	input [`N_WAY-1:0]					use_op1_prn_in,	//  
	input [`N_WAY-1:0]					use_op2_prn_in,	// 
	input [(`PRF_WIDTH)*(`N_WAY)-1:0] 	dest_prn_in,		//from prf free list 
	input [2*`N_WAY-1:0]				op1_select_in,		
	input [4*`N_WAY-1:0]				op2_select_in,		
	input [`N_WAY-1:0]					rd_mem_in,			
	input [`N_WAY-1:0]					wr_mem_in,			
	input [`N_WAY-1:0]					cond_branch_in,		
	input [`N_WAY-1:0]					uncond_branch_in,		
	input [`N_WAY-1:0]					halt_in,				
	input [`N_WAY-1:0]					illigal_in,			
	input [`N_WAY-1:0] 					op1_ready_in, 					//from prf valid bit
	input [`N_WAY-1:0] 					op2_ready_in, 					//from prf valid bit		
	input [(`ROB_WIDTH)*(`N_WAY)-1:0] 	rob_entry_in,       //from tail of rob (*3)
	input [4*(`N_WAY)-1:0]				fu_type_in,			// from decoder, does this inst use alu, mul, mem or bcond?
	input [(`IMM_WIDTH)*(`N_WAY)-1:0]  	imm_in,				// from decoder, imm value
	input								rs_nuke,			//from controller
	//input								mult_avail,	
	input [`ROB_SIZE-1:0]				load_ready_in,
	input 								miss_waiting_in,
	input								dcache_hit,
	input [`N_WAY-1:0]					cdb_valid ,
	input [(`PRF_WIDTH)*(`N_WAY)-1:0]	cdb_tag,

	output [`N_WAY-1:0]	 				inst_valid_out,    //asserted when rs is issuing inst
	output [32*(`N_WAY)-1:0]			inst_out,    		// feed to alu
	output [32*(`N_WAY)-1:0]			pc_out,    		// feed to alu
	output [32*(`N_WAY)-1:0]			npc_out,    		// feed to alu
	output [5*(`N_WAY)-1:0] 			op_type_out, 
	output [(`PRF_WIDTH)*(`N_WAY)-1:0]  op1_prn_out ,
	output [(`PRF_WIDTH)*(`N_WAY)-1:0]  op2_prn_out ,
	output [(`PRF_WIDTH)*(`N_WAY)-1:0]  dest_prn_out ,
   	output [2*`N_WAY-1:0]				op1_select_out,		
	output [4*`N_WAY-1:0]				op2_select_out,	
	output [`N_WAY-1:0]					rd_mem_out,			
	output [`N_WAY-1:0]					wr_mem_out,			
	output [`N_WAY-1:0]					cond_branch_out,	
	output [`N_WAY-1:0]					uncond_branch_out,	
	output [`N_WAY-1:0]					halt_out,			
	output [`N_WAY-1:0]					illigal_out,		
	output [(`ROB_WIDTH)*(`N_WAY)-1:0] 	rob_entry_out,
	output [4*(`N_WAY)-1:0]			 	fu_type_out, 	//  
	output [(`IMM_WIDTH)*(`N_WAY)-1:0] 	imm_out, 		//  
	output [`RS_WIDTH:0] 				rs_avail_cnt,		//indicates how many rs entries are available, 0~16, require RS_WIDTH+1 number of bits
	output		 						rs_full 			//rs has no available entry, notify other hardwares that rs is full, stop dispatching
);


	wire [`RS_SIZE-1:0] rs1_avail;		//req from rs1*RS_SIZE
	wire [`RS_SIZE-1:0] gnt_dispatch;	//gnt, n_way-hot, the rs# to be dispatched, use the lowest numbered rs avaliable 	
	wire [`RS_SIZE-1:0] rs1_wake_up_alu;	
	wire [`RS_SIZE-1:0] rs1_wake_up_mul;	
	wire [`RS_SIZE-1:0] rs1_wake_up_mem;	
	wire [`RS_SIZE-1:0] rs1_wake_up_bcond;	
	reg  [`RS_SIZE-1:0] gnt_issue;	//gnt, n_way-hot, the rs# to be issued, use the oldest rs avaliable 	
	wire [`RS_SIZE-1:0] gnt_issue_alu_3;	//gnt, n_way-hot, the rs# to be issued, use the oldest rs avaliable 	
	wire [`RS_SIZE-1:0] gnt_issue_alu_2;	//gnt, n_way-hot, the rs# to be issued, use the oldest rs avaliable 	
	wire [`RS_SIZE-1:0] gnt_issue_alu_1;	//gnt, n_way-hot, the rs# to be issued, use the oldest rs avaliable 	
	wire [`RS_SIZE-1:0] gnt_issue_mul;		//gnt, n_way-hot, the rs# to be issued, use the oldest rs avaliable 	
	wire [`RS_SIZE-1:0] gnt_issue_bcond;	//gnt, n_way-hot, the rs# to be issued, use the oldest rs avaliable 	
	wire [`RS_SIZE-1:0] gnt_issue_mem;	//gnt, n_way-hot, the rs# to be issued, use the oldest rs avaliable 	
	wire empty_mul;
	wire empty_bcond;
	wire empty_mem;

	reg [(`RS_SIZE)*(`N_WAY)-1:0] 	gnt_bus_issue;								//selected inst per superscalar lane*n ways
	reg [(`RS_SIZE)*(`N_WAY)-1:0] 	gnt_bus_issue_alu_3;						//selected inst per superscalar lane*n ways
	reg [(`RS_SIZE)*2-1:0] 			gnt_bus_issue_alu_2;						//selected inst per superscalar lane*n ways
	reg [(`RS_SIZE)*1-1:0] 			gnt_bus_issue_alu_1;						//selected inst per superscalar lane*n ways
	reg [(`RS_SIZE)*1-1:0] 			gnt_bus_issue_mul;							//selected inst per superscalar lane*n ways
	reg [(`RS_SIZE)*1-1:0] 			gnt_bus_issue_bcond;						//selected inst per superscalar lane*n ways
	reg [(`RS_SIZE)*1-1:0] 			gnt_bus_issue_mem;						//selected inst per superscalar lane*n ways
	reg [(`RS_SIZE)*(`N_WAY)-1:0] 	gnt_bus_dispatch;							//selected inst per superscalar lane*n ways
	wire [`RS_WIDTH-1:0]			dispatch_index	[0:`N_WAY-1];				//it points to the index number of selected rs slot
	wire [1:0] 						valid_inst_cnt;
	reg [2*(`RS_SIZE)-1:0]			dispatch_select_way;
	reg [`RS_SIZE-1:0] 				rs1_load;

	reg [3:0] mult_issued_delay;
	reg [int'(`MEM_LATENCY_IN_CYCLES)-1:0] load_issued_delay;
	reg mult_avail;
	wire mult_issued;
	wire load_issued;
	wire [15:0] load_issue_req;

	assign load_issue_req = (load_issued_delay[0] | miss_waiting_in) ? 16'b0 : rs1_wake_up_mem;

	assign rs_full = rs1_avail == {`RS_SIZE{1'b0}};  //none available
	assign valid_inst_cnt = inst_valid_in[0]+inst_valid_in[1]+inst_valid_in[2];
	assign rs_avail_cnt = 	rs1_avail[0]+rs1_avail[1]+rs1_avail[2]+rs1_avail[3]+
							rs1_avail[4]+rs1_avail[5]+rs1_avail[6]+rs1_avail[7]+
							rs1_avail[8]+rs1_avail[9]+rs1_avail[10]+rs1_avail[11]+
							rs1_avail[12]+rs1_avail[13]+rs1_avail[14]+rs1_avail[15]-
							inst_valid_in[2]-inst_valid_in[1]-inst_valid_in[0]; //TODO

//	always_comb begin
//		rs_avail_cnt = 0;
//		for(int i=0;i<`RS_SIZE;i++) begin
//			if(rs1_avail[i])
//				rs_avail_cnt = rs_avail_cnt + 1'b1;
//			else
//				rs_avail_cnt = rs_avail_cnt;
//		end
//	end


	//dispatch 3 instructions
	psel_gen #(
		.REQS(`N_WAY),
		.WIDTH(`RS_SIZE)) 
	psel_gen_inst_dispatch(  //dispatch use the lowest numbered rs avaliable 	
		.req(rs1_avail),
		.gnt(), 
		.gnt_bus(gnt_bus_dispatch),			//mux 3 in 16 ctrl signal
		.empty()
	);

	//issue 3 alu instructions
	psel_gen #( 
		.REQS(3),
		.WIDTH(`RS_SIZE)) 
	psel_gen_inst_issue_alu_3( 
		.req(rs1_wake_up_alu),
		.gnt(gnt_issue_alu_3), 
		.gnt_bus(gnt_bus_issue_alu_3),			
		.empty()
	);

	//issue 2 alu instructions
	psel_gen #( 
		.REQS(2),
		.WIDTH(`RS_SIZE)) 
	psel_gen_inst_issue_alu_2( 
		.req(rs1_wake_up_alu),
		.gnt(gnt_issue_alu_2), 
		.gnt_bus(gnt_bus_issue_alu_2),			
		.empty()
	);

	//issue 1 alu instructions
	psel_gen #( 
		.REQS(1),
		.WIDTH(`RS_SIZE)) 
	psel_gen_inst_issue_alu_1( 
		.req(rs1_wake_up_alu),
		.gnt(gnt_issue_alu_1), 
		.gnt_bus(gnt_bus_issue_alu_1),			
		.empty()
	);

	//issue 1 mul instructions
	psel_gen #( 
		.REQS(1),
		.WIDTH(`RS_SIZE)) 
	psel_gen_inst_issue_mul( 
		.req(rs1_wake_up_mul),
		.gnt(gnt_issue_mul), 
		.gnt_bus(gnt_bus_issue_mul),			
		.empty(empty_mul)
	);

	//issue 1 bcond instructions
	psel_gen #( 
		.REQS(1),
		.WIDTH(`RS_SIZE)) 
	psel_gen_inst_issue_bcond( 
		.req(rs1_wake_up_bcond),
		.gnt(gnt_issue_bcond), 
		.gnt_bus(gnt_bus_issue_bcond),			
		.empty(empty_bcond)
	);

	//issue 1 mem instructions
	psel_gen #( 
		.REQS(1),
		.WIDTH(`RS_SIZE)) 
	psel_gen_inst_issue_mem( 
		.req(load_issue_req),
		.gnt(gnt_issue_mem), 
		.gnt_bus(gnt_bus_issue_mem),			
		.empty(empty_mem)
	);

	rs_group rs_group_inst(
		.clk					(clk),          	// the clock 							
		.rst					(rst|rs_nuke),          	// reset signal			
		.rs1_load				(rs1_load),		// load inst into RS
		.rs1_use_en				(gnt_issue),		// send signal to FU
		.inst_in				(inst_in	),		// from decoder
		.pc_in					(pc_in	),		// from decoder
		.npc_in					(npc_in		),		// from decoder
		.op_type_in				(op_type_in		),		// from decoder
		.op1_prn_in				(op1_prn_in		),     // from rat 
		.op2_prn_in				(op2_prn_in		),     // from rat
		.use_op1_prn_in			(use_op1_prn_in ),
		.use_op2_prn_in			(use_op2_prn_in ),
		.dest_prn_in			(dest_prn_in	),    // from decoder
		.op1_select_in			(op1_select_in		),	
		.op2_select_in			(op2_select_in		),	
		.rd_mem_in				(rd_mem_in			),		
		.wr_mem_in				(wr_mem_in			),		
		.cond_branch_in			(cond_branch_in		),	
		.uncond_branch_in		(uncond_branch_in	),
		.halt_in				(halt_in			),		
		.illigal_in				(illigal_in			),		
		.rob_entry_in			(rob_entry_in	),	// from the tail of rob
		.op1_ready_in			(op1_ready_in	),	// from PRF valid bit 
		.op2_ready_in			(op2_ready_in	),	// from PRF valid bit 
		.fu_type_in				(fu_type_in		),	
		.imm_in					(imm_in	   		),		
		.dispatch_select_way	(dispatch_select_way),	// allocate the rs entry
		.issue_select			(gnt_bus_issue),		// issue gnt_bus
	    .load_ready_in			(load_ready_in),	
		.cdb_valid				(cdb_valid),
		.cdb_tag				(cdb_tag),	

		.rs1_wake_up_alu		(rs1_wake_up_alu),   		// This RS is in use and ready to go to EX 
		.rs1_wake_up_mul		(rs1_wake_up_mul),   		// This RS is in use and ready to go to EX 
		.rs1_wake_up_mem		(rs1_wake_up_mem),   		// This RS is in use and ready to go to EX 
		.rs1_wake_up_bcond		(rs1_wake_up_bcond),   		// This RS is in use and ready to go to EX 
		.rs1_avail				(rs1_avail),     		// This RS is available to be dispatched to 
		.rs1_inst_out			(inst_out),    // feed to alu
		.rs1_pc_out				(pc_out),    // feed to alu
		.rs1_npc_out			(npc_out),    // feed to alu
		.rs1_op_type_out		(op_type_out),    // feed to alu
		.rs1_op1_prn_out		(op1_prn_out),   	// feed to PRF 
		.rs1_op2_prn_out		(op2_prn_out),   	// feed to PRF 
		.rs1_dest_prn_out		(dest_prn_out),   // feed to PRF
		.rs1_op1_select_out		(op1_select_out		),		
		.rs1_op2_select_out		(op2_select_out		),	
		.rs1_rd_mem_out			(rd_mem_out			),			
		.rs1_wr_mem_out			(wr_mem_out			),			
		.rs1_cond_branch_out	(cond_branch_out	),	
		.rs1_uncond_branch_out	(uncond_branch_out	),	
		.rs1_halt_out			(halt_out			),			
		.rs1_illigal_out		(illigal_out		),		
		.rs1_rob_entry_out 		(rob_entry_out),// feed to ROB
		.rs1_fu_type_out		(fu_type_out), 	//  
		.rs1_imm_out			(imm_out), 		//  
		.inst_issue_valid		(inst_valid_out)	
	);



/*******************************dispatch entry selection logic*****************************************/
	genvar i;
	generate
		for(i=0;i<`RS_SIZE;i=i+1) begin
			always_comb begin
				if(valid_inst_cnt == 2'd3) begin
					if(i==dispatch_index[0]) 
						dispatch_select_way[i*2+:2] = 0; 
					else if(i==dispatch_index[1]) 
						dispatch_select_way[i*2+:2] = 1; 
					else if(i==dispatch_index[2]) 
						dispatch_select_way[i*2+:2] = 2; 
					else 
						dispatch_select_way[i*2+:2] = 3; //grounded
				end
				else if(valid_inst_cnt == 2'd2) begin
					if(i==dispatch_index[0]) 
						dispatch_select_way[i*2+:2] = inst_valid_in[0] ? 0 : 1;		//the rs entry with the largest idx select way0 if way0 is valid else select way1
					else if(i==dispatch_index[1]) begin 
						if(inst_valid_in[0] & inst_valid_in[1])
							dispatch_select_way[i*2+:2] = 1;   						//the rs entry with the second largest idx select way1 if way0 is valid else select way1
						else if(inst_valid_in[1] & inst_valid_in[2])
							dispatch_select_way[i*2+:2] = 2;
						else
							dispatch_select_way[i*2+:2] = 2;
					end
					else 
						dispatch_select_way[i*2+:2] = 3; //grounded		
				end
				else if(valid_inst_cnt == 2'd1) begin
					if(i==dispatch_index[0]) 
						dispatch_select_way[i*2+:2] = 	inst_valid_in[0] ? 0 : 
														inst_valid_in[1] ? 1 : 2;		
					else
						dispatch_select_way[i*2+:2] = 3; //grounded					
				end
				else
					dispatch_select_way[i*2+:2] = 3; //grounded
			end
		end

		for(i=0;i<`RS_SIZE;i=i+1) begin
			always_comb begin
				if(valid_inst_cnt == 2'd3) begin
					if(~rs_full&(i==dispatch_index[0])|(i==dispatch_index[1])|(i==dispatch_index[2])) 
						rs1_load[i] = 1'b1;
					else
						rs1_load[i] = 1'b0;
				end
				else if(valid_inst_cnt == 2'd2) begin
					if(~rs_full&(i==dispatch_index[0])|(i==dispatch_index[1])) 
						rs1_load[i] = 1'b1;
					else
						rs1_load[i] = 1'b0;
				end
				else if(valid_inst_cnt == 2'd1) begin
					if(~rs_full&(i==dispatch_index[0])) 
						rs1_load[i] = 1'b1;
					else
						rs1_load[i] = 1'b0;
				end
				else
					rs1_load[i] = 1'b0;
			end	
		end		
	endgenerate


	onehot_enc #(`RS_SIZE) onehot_enc_inst0(
		.in(gnt_bus_dispatch[`RS_SIZE*0+:`RS_SIZE]),
		.out(dispatch_index[0])								
	);
	onehot_enc #(`RS_SIZE) onehot_enc_inst1(
		.in(gnt_bus_dispatch[`RS_SIZE*1+:`RS_SIZE]),
		.out(dispatch_index[1])							
	);													
	onehot_enc #(`RS_SIZE) onehot_enc_inst2(
		.in(gnt_bus_dispatch[`RS_SIZE*2+:`RS_SIZE]),
		.out(dispatch_index[2])							
	);


/****************************************issue selection logic*****************************************/
	always_comb begin
		if((~empty_mul & mult_avail) & ~empty_bcond & ~empty_mem & ~load_issued_delay[7]) begin	//mul, mem and bcond want to issue
			gnt_bus_issue = {gnt_bus_issue_mem,gnt_bus_issue_mul,gnt_bus_issue_bcond};		
		end
		else if((~empty_mul & mult_avail) & ~empty_bcond) begin	//both mul and bcond want to issue
			if(gnt_issue_alu_1 & ~load_issued_delay[7]) begin
				gnt_issue = gnt_issue_mul | gnt_issue_bcond | gnt_issue_alu_1;
				gnt_bus_issue = {gnt_bus_issue_alu_1,gnt_bus_issue_mul,gnt_bus_issue_bcond};
			end
			else begin
				gnt_issue = gnt_issue_mul | gnt_issue_bcond;
				gnt_bus_issue = {gnt_bus_issue_mul,gnt_bus_issue_bcond};
			end
		end
		else if((~empty_mul & mult_avail) & empty_bcond & empty_mem) begin	//only mul wants to issue
			if(mult_issued_delay[0] | load_issued_delay[7]) begin //cdb hazard
				gnt_issue = gnt_issue_mul | gnt_issue_alu_1;
				gnt_bus_issue = {gnt_bus_issue_alu_1,gnt_bus_issue_mul};
			end
			else begin
				gnt_issue = gnt_issue_mul | gnt_issue_alu_2;
				gnt_bus_issue = {gnt_bus_issue_alu_2,gnt_bus_issue_mul};
			end
		end
		else if((empty_mul | ~mult_avail) & ~empty_bcond & empty_mem) begin	//only bcond wants to issue
			if(mult_issued_delay[0] | load_issued_delay[7]) begin //cdb hazard
				gnt_issue = gnt_issue_bcond | gnt_issue_alu_1;
				gnt_bus_issue = {gnt_bus_issue_alu_1,gnt_bus_issue_bcond};
			end
			else begin 
				gnt_issue = gnt_issue_bcond | gnt_issue_alu_2;
				gnt_bus_issue = {gnt_bus_issue_alu_2,gnt_bus_issue_bcond};
			end
		end
		else if( ~empty_mem) begin	//mem wants to issue
			if(mult_issued_delay[0] | load_issued_delay[7]) begin //cdb hazard
				gnt_issue = gnt_issue_mem | gnt_issue_alu_1;
				gnt_bus_issue = {gnt_bus_issue_alu_1,gnt_bus_issue_mem};
			end
			else begin 
				gnt_issue = gnt_issue_mem | gnt_issue_alu_2;
				gnt_bus_issue = {gnt_bus_issue_alu_2,gnt_bus_issue_mem};
			end
		end
		else begin
			if(mult_issued_delay[0] | load_issued_delay[7]) begin //cdb hazard
				gnt_issue = gnt_issue_alu_2;
				gnt_bus_issue = {{`RS_SIZE{1'b0}},gnt_bus_issue_alu_2};
			end
			else begin
				gnt_issue = gnt_issue_alu_3;
				gnt_bus_issue = gnt_bus_issue_alu_3;
			end
		end
	end


/***********************************multiplication issue delay logic************************************/
	assign mult_issued = fu_type_out[1] | fu_type_out[5] | fu_type_out[9];

	always@(posedge clk) begin 
		if(rst)  
			mult_issued_delay <= `SD 0;
		else begin
			mult_issued_delay[3] <= `SD mult_issued;
			mult_issued_delay[2] <= `SD mult_issued_delay[3];
			mult_issued_delay[1] <= `SD mult_issued_delay[2];
			mult_issued_delay[0] <= `SD mult_issued_delay[1];
		end
	end

	always@(posedge clk) begin 
		if(rst)  
			mult_avail <= `SD 1'b1;
		else if(mult_issued)
			mult_avail <= `SD 1'b0;
		else if(mult_issued_delay[0])			//TODO
			mult_avail <= `SD 1'b1;
	end




/***********************************load issue delay logic************************************/
	assign load_issued = (fu_type_out[2] | fu_type_out[6] | fu_type_out[10]) & rd_mem_out!=0;

	always@(posedge clk) begin 
		if(rst)  
			load_issued_delay <= `SD 0;
		else if(dcache_hit)
			load_issued_delay <= `SD 0; //indicate cache hit
		else begin
			load_issued_delay[0] <= `SD load_issued;
			for(int i=0;i<`MEM_LATENCY_IN_CYCLES-1;i++)
				load_issued_delay[i+1] <= `SD load_issued_delay[i];
		end
	end


endmodule

