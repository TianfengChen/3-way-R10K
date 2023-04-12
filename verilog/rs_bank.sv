`ifndef __RS_BANK_V__
`define __RS_BANK_V__
`timescale 1ns/100ps



module rs_bank #(
	parameter RS_DEPTH = 16
)
(
	input							clk,
	input							rst_n,
	input							pipe_flush,
	input DISPATCH_RS_PACKET		dispatch_pkt 	[0:`MACHINE_WIDTH-1],
	input [`ISSUE_WIDTH-1:0]		cdb_valid,
	input [`PRF_WIDTH-1:0]			cdb_prn		[0:`ISSUE_WIDTH-1],
	                            	
	output ISSUE_PACKET				issue_pkt 	[0:`ISSUE_WIDTH-1],
	output [`MACHINE_WIDTH-1:0]		dispatch_pkt_ready,
	output reg [$clog2(RS_DEPTH):0] rs_avail_cnt, 
	output		 					rs_full
);

	
	reg 	[RS_DEPTH-1:0] 						rs_avail;								//req from rs1*RS_DEPTH
	wire 	[`ROB_WIDTH:0]						rs_age			[0:RS_DEPTH-1];	
	wire 	[`ROB_WIDTH-1:0]					rs_age_tag		[0:RS_DEPTH-1];	
	wire 	[RS_DEPTH-1:0]						rs_age_pos;	
	reg 	[RS_DEPTH-1:0] 						rs_issued;							
	wire 	[`ISSUE_WIDTH-1:0] 					rs_wake_up		[0:RS_DEPTH-1];					
	wire 	[`ISSUE_WIDTH-1:0] 					rs_issue_req	[0:RS_DEPTH-1];			//awake and not issued			
	wire 	[RS_DEPTH-1:0] 						rs_issue_req_N	[0:`ISSUE_WIDTH-1];		//rearrange xy order		
	reg 	[`ISSUE_IDX:0]	 					valid_inst_cnt;
//	reg 	[`MACHINE_IDX:0]	 				issue_ready_cnt;
	wire 	[(RS_DEPTH)*(`MACHINE_WIDTH)-1:0] 	alloc_gnt_bus;							//selected inst per superscalar lane*n ways
	wire 	[$clog2(RS_DEPTH)-1:0]				alloc_index		[0:`MACHINE_WIDTH-1];	//it points to the index number of selected rs slot
	wire 	[`MACHINE_WIDTH-1:0]				alloc_index_valid;	
	reg 	[`MACHINE_WIDTH-1:0] 				alloc_sel		[0:RS_DEPTH-1];			//selected inst per superscalar lane*n ways
	wire 	[RS_DEPTH-1:0] 						issue_sel		[0:`ISSUE_WIDTH-1];	
	reg 	[RS_DEPTH-1:0] 						issue_en;								//global issue enable
	wire 	[RS_DEPTH-1:0] 						issue_en_N		[0:`ISSUE_WIDTH-1];		//local issue enable(per FU)	

	assign rs_full = rs_avail == {RS_DEPTH{1'b0}};  //none available
	assign dispatch_pkt_ready = 	(rs_avail_cnt>=4) ? 4'b1111 : 
								(rs_avail_cnt==3) ? 4'b0111 :
								(rs_avail_cnt==2) ?	4'b0011 :
								(rs_avail_cnt==1) ?	4'b0001 :
													4'b0000;

	always@(*) begin
  		valid_inst_cnt = '0;  
  		foreach(dispatch_pkt[i]) begin
    		valid_inst_cnt += dispatch_pkt[i].packet_valid;
		end
  	end
	//always@(*) begin
  	//	issue_ready_cnt = '0;  
  	//	foreach(issue_pkt_ready[i]) begin
    //		issue_ready_cnt += issue_pkt_ready[i];
	//	end
  	//end
	always@(*) begin
  		rs_avail_cnt = '0;  
  		foreach(rs_avail[i]) begin
    		rs_avail_cnt += rs_avail[i];
		end
		rs_avail_cnt -= valid_inst_cnt;
  	end 




	rs_array #(
		.RS_DEPTH(RS_DEPTH))			
	u_rs_array(
		.clk					(clk				),  // the clock 							
		.rst_n					(rst_n				),  // reset signal	
		.pipe_flush				(pipe_flush			),		
		.rs_use_en				(issue_en			),	// send signal to FU
		.alloc_sel				(alloc_sel			),	// allocate the rs entry
		.issue_sel				(issue_sel			),	// issue gnt_bus
		.cdb_valid				(cdb_valid			),
		.cdb_prn				(cdb_prn			),	
		.dispatch_pkt			(dispatch_pkt		),

		.rs_wake_up				(rs_wake_up			),  // This RS is in use and ready to go to EX 
		.rs_issued				(rs_issued			),  
		.rs_avail				(rs_avail			),  // This RS is available to be dispatched to 
		.rs_age					(rs_age				),   
		.issue_pkt				(issue_pkt			)   // feed to alu
	);


/*******************************allocation entry selection logic*****************************************/
	//alloc use the lowest numbered rs avaliable 
	psel_gen #(
		.REQS(`MACHINE_WIDTH),
		.WIDTH(RS_DEPTH)) 
	psel_gen_inst_alloc(  	
		.req(rs_avail),
		.gnt(), 
		.gnt_bus(alloc_gnt_bus),			
		.empty()
	);

	genvar i,j;
	generate
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign alloc_index_valid[i] = alloc_gnt_bus[RS_DEPTH*i+:RS_DEPTH] != 0;
			onehot_enc #(RS_DEPTH) u_onehot_enc(
				.in(alloc_gnt_bus[RS_DEPTH*i+:RS_DEPTH]),
				.out(alloc_index[i])								
			);
		end

		for(i=0;i<RS_DEPTH;i=i+1) begin
			always_comb begin
				if(i==alloc_index[0] & alloc_index_valid[0])
					alloc_sel[i] = 4'b0001; 
				else if(i==alloc_index[1] & alloc_index_valid[1]) 
					alloc_sel[i] = 4'b0010; 
				else if(i==alloc_index[2] & alloc_index_valid[2]) 
					alloc_sel[i] = 4'b0100;
				else if(i==alloc_index[3] & alloc_index_valid[3]) 
					alloc_sel[i] = 4'b1000;
				else 
					alloc_sel[i] = 4'b0000; 
				end
		end
	endgenerate


/****************************************issue selection logic*****************************************/

	generate
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			for(j=0;j<RS_DEPTH;j=j+1) begin
				assign rs_issue_req_N[i][j] = rs_issue_req[j][i]; 
			end
		end

		for(i=0;i<RS_DEPTH;i=i+1) begin
			assign rs_age_tag[i] 	= rs_age[i][`ROB_WIDTH-1:0];
			assign rs_age_pos[i] 	= rs_age[i][`ROB_WIDTH];
			assign rs_issue_req[i]	= rs_issued[i] ? 0 : rs_wake_up[i];
		end

		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			`ifndef RS_OLDEST_FIRST
			//random issue policy
			psel_gen #(
				.REQS(1),
				.WIDTH(RS_DEPTH)) 
			u_psel_gen_issue(  	
				.req(rs_issue_req_N[i]),
				.gnt(issue_en_N[i]), 
				.gnt_bus(),			
				.empty()
			);
			`else
			//oldest first issue policy
			sort #(
				.REQ_NUM(RS_DEPTH),	
				.DATA_WIDTH(`ROB_WIDTH))
			u_sort(
				.req(rs_issue_req_N[i]),
				.i_data(rs_age_tag),
				.i_pos(rs_age_pos), 
				.gnt(issue_en_N[i]),
				.o_data()
			);
			`endif
		end
	
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			assign issue_sel[i] = issue_en_N[i];
		end

		for(i=0;i<RS_DEPTH;i=i+1) begin
			always@(*) begin
				issue_en[i] = 0;
				for(int k=0;k<`ISSUE_WIDTH;k++) begin
					if(issue_en_N[k][i])
						issue_en[i] = 1;
				end
			end

			//assign issue_en[i] = 	issue_en_N[0][i] | issue_en_N[1][i] | 
			//						issue_en_N[2][i] | issue_en_N[3][i] | 
			//						issue_en_N[4][i] | issue_en_N[5][i] | 
			//						issue_en_N[6][i];
		end
	endgenerate
	




endmodule
`endif //__RS_BANK_V__

