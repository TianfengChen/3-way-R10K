`timescale 1ns/100ps

module decoder_top(         
	input         			clk,              	
	input         			rst_n,              	
	input  FETCH_PACKET 	fetch_pkt	[0:`MACHINE_WIDTH-1],
	output DECODE_PACKET 	decode_pkt	[0:`MACHINE_WIDTH-1]
);

	
	wire	[`MACHINE_IDX-1:0]	decode_pkt_cnt;
	reg		[`MACHINE_IDX-1:0]	alu_alloc_head;
	wire	[`MACHINE_IDX-1:0]	alu_alloc_ptr	[0:`MACHINE_WIDTH-1];

	
	assign decode_pkt_cnt = decode_pkt[0].packet_valid + 
							decode_pkt[1].packet_valid +
							decode_pkt[2].packet_valid +
							decode_pkt[3].packet_valid;
    
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			alu_alloc_head <= 0;
		else
			alu_alloc_head <= alu_alloc_head + decode_pkt_cnt;
	end


	/*******************dynamic alu allocation****************************/
	assign alu_alloc_ptr[0] = alu_alloc_head;
	assign alu_alloc_ptr[1] = alu_alloc_head + decode_pkt[0].packet_valid;
	assign alu_alloc_ptr[2] = alu_alloc_head + decode_pkt[0].packet_valid + decode_pkt[1].packet_valid;
	assign alu_alloc_ptr[3] = alu_alloc_head + decode_pkt[0].packet_valid + decode_pkt[1].packet_valid + decode_pkt[2].packet_valid;

	

	genvar i;
	generate 
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
		    assign decode_pkt[i].inst = fetch_pkt[i].inst;
    		assign decode_pkt[i].pc   = fetch_pkt[i].pc;

			always@(*) begin
				if(decode_pkt[i].cond_branch || decode_pkt[i].uncond_branch)
					decode_pkt[i].fu_id = BRU_0;
				else if(decode_pkt[i].rd_mem || decode_pkt[i].wr_mem)
					decode_pkt[i].fu_id = AGU_0;
				else if(decode_pkt[i].op_type == ALU_MUL || decode_pkt[i].op_type == ALU_MULH || decode_pkt[i].op_type == ALU_MULHSU || decode_pkt[i].op_type == ALU_MULHU)
					decode_pkt[i].fu_id = MUL_0;
				else begin
					case(alu_alloc_ptr[i])
						0:	decode_pkt[i].fu_id = ALU_0;
						1:	decode_pkt[i].fu_id = ALU_1;
						2:	decode_pkt[i].fu_id = ALU_2;
						3:	decode_pkt[i].fu_id = ALU_3;
					endcase
				end
			end
		end

		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			decoder u_decoder(
				.inst				(fetch_pkt[i].inst				),	 
				.inst_valid_in		(fetch_pkt[i].packet_valid		),
				.op1_arn			(decode_pkt[i].op1_arn			),
				.op2_arn			(decode_pkt[i].op2_arn			),
				.dest_arn			(decode_pkt[i].dest_arn			),
				.use_opa_arn    	(decode_pkt[i].use_op1_arn		),
				.use_opb_arn    	(decode_pkt[i].use_op2_arn		),
				.opa_select			(decode_pkt[i].op1_select		),
				.opb_select			(decode_pkt[i].op2_select		),
				.dest_select		(decode_pkt[i].dest_select		),
				.alu_func			(decode_pkt[i].op_type			),
				.rd_mem				(decode_pkt[i].rd_mem			),
				.wr_mem				(decode_pkt[i].wr_mem			),
				.cond_branch		(decode_pkt[i].cond_branch		),
				.uncond_branch		(decode_pkt[i].uncond_branch	),
				.csr_op				(decode_pkt[i].csr_op			),
				.halt				(decode_pkt[i].halt				),
				.illegal			(decode_pkt[i].illegal			),
				.inst_valid_out		(decode_pkt[i].packet_valid		)
			);  		
		end
	endgenerate
		

	
	

   
endmodule // module id_stage
