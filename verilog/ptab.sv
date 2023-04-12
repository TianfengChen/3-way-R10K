`timescale 1ns/100ps

module ptab(         
	input         				clk									,
	input         				rst_n								,
	input         				pipe_flush							,
	input  	FETCH_PACKET 		fetch_pkt		[0:`MACHINE_WIDTH-1],
	output  			 		fetch_pkt_ready						,
	output	[`PTAB_WIDTH-1:0]	ptab_tag		[0:`MACHINE_WIDTH-1],

	input	[`PTAB_WIDTH-1:0]	bru_ptab_tag						,
	input						bru_branch_dir						,
	input	[`XLEN-1:0]			bru_target_pc						,
	input						bru_valid							,
	output	reg					bru_branch_misp						,
	output	reg [`XLEN-1:0]		bru_next_pc
);

	typedef struct packed {
		logic					predict_dir	;
		logic [`XLEN-1:0]		predict_pc	;
		logic [`XLEN-1:0]		next_pc	 	;
		logic					valid		;
	} PTAB_ENTRY;


	PTAB_ENTRY ptab_entry [0:`PTAB_DEPTH-1];
		

	reg		[`PTAB_WIDTH:0]		ptab_avail_cnt;
	wire	[`PTAB_DEPTH-1:0]	ptab_avail_N;
	wire	[`PTAB_DEPTH-1:0]	ptab_alloc_N	[0:`MACHINE_WIDTH-1];
	wire	[`PTAB_DEPTH*`MACHINE_WIDTH-1:0]	ptab_alloc_bus_N;

	
	always_comb begin
		ptab_avail_cnt = 0;
		for(int i=0;i<`PTAB_DEPTH;i++) begin
			if(ptab_avail_N[i])
				ptab_avail_cnt = ptab_avail_cnt + 1'b1;
			else
				ptab_avail_cnt = ptab_avail_cnt;
		end
	end


	always@(*) begin
		if(bru_valid && bru_branch_dir==0) begin //actually not taken
			if(ptab_entry[bru_ptab_tag].valid && ptab_entry[bru_ptab_tag].predict_dir) begin //but predict taken
				bru_branch_misp = 1;
				bru_next_pc = ptab_entry[bru_ptab_tag].next_pc; 
			end
			else begin
				bru_branch_misp = 0;
				bru_next_pc = 0;
			end
		end
		else if(bru_valid && bru_branch_dir==1) begin //actually taken
			if(ptab_entry[bru_ptab_tag].valid && ptab_entry[bru_ptab_tag].predict_dir) begin //predict taken
				if(ptab_entry[bru_ptab_tag].predict_pc!=bru_target_pc) begin //but predicted target pc is wrong
					bru_branch_misp = 1; 
					bru_next_pc = bru_target_pc;
				end
				else begin
					bru_branch_misp = 0;
					bru_next_pc = 0;
				end
			end
			else begin
				bru_branch_misp = 1;
				bru_next_pc = bru_target_pc;
			end
		end	
		else begin
			bru_branch_misp = 0;
			bru_next_pc = 0;
		end
	end





	assign fetch_pkt_ready = ptab_avail_cnt>=4;
//	assign next_pc = ptab_entry[bru_ptab_tag].next_pc;


	psel_gen #(
		.REQS(`MACHINE_WIDTH),
		.WIDTH(`PTAB_DEPTH)) 
	u_psel_gen_ptab(  	
		.req(ptab_avail_N),
		.gnt(), 
		.gnt_bus(ptab_alloc_bus_N),			
		.empty()
	);



	genvar i;
	generate	
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign ptab_alloc_N[i] = ptab_alloc_bus_N[i*`PTAB_DEPTH+:`PTAB_DEPTH];
		
			onehot_enc #(`PTAB_DEPTH) u_onehot_enc_ptag(
				.in(ptab_alloc_N[i]),
				.out(ptab_tag[i])							
			);
		end

		for(i=0;i<`PTAB_DEPTH;i=i+1) begin
			assign ptab_avail_N[i] = ~ptab_entry[i].valid;

			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) 
					ptab_entry[i].valid <= 0;
				else if(pipe_flush)
					ptab_entry[i].valid <= 0;
				//clear entry after verifying the prediction
				else if(bru_valid && i==bru_ptab_tag) begin
					ptab_entry[i].valid <= 0;
				end
				else if(fetch_pkt_ready)begin //allocate this entry 
					//write prediction info
					if(i==ptab_tag[0] && fetch_pkt[0].packet_valid && fetch_pkt[0].branch_mask) begin
						ptab_entry[i].valid 		<= 1;
						ptab_entry[i].predict_dir	<= fetch_pkt[0].branch_dir;
						ptab_entry[i].predict_pc	<= fetch_pkt[0].branch_addr;
						ptab_entry[i].next_pc		<= fetch_pkt[0].pc+4;
					end
					else if(i==ptab_tag[1] && fetch_pkt[1].packet_valid && fetch_pkt[1].branch_mask) begin
						ptab_entry[i].valid 		<= 1;
						ptab_entry[i].predict_dir	<= fetch_pkt[1].branch_dir;
						ptab_entry[i].predict_pc 	<= fetch_pkt[1].branch_addr;
						ptab_entry[i].next_pc		<= fetch_pkt[1].pc+4;
					end
					else if(i==ptab_tag[2] && fetch_pkt[2].packet_valid && fetch_pkt[2].branch_mask) begin
						ptab_entry[i].valid 		<= 1;
						ptab_entry[i].predict_dir	<= fetch_pkt[2].branch_dir;
						ptab_entry[i].predict_pc 	<= fetch_pkt[2].branch_addr;
						ptab_entry[i].next_pc		<= fetch_pkt[2].pc+4;
					end				
					else if(i==ptab_tag[3] && fetch_pkt[3].packet_valid && fetch_pkt[3].branch_mask) begin
						ptab_entry[i].valid 		<= 1;
						ptab_entry[i].predict_dir	<= fetch_pkt[3].branch_dir;
						ptab_entry[i].predict_pc 	<= fetch_pkt[3].branch_addr;
						ptab_entry[i].next_pc		<= fetch_pkt[3].pc+4;
					end
				end


			end
		end
	endgenerate
	


endmodule
