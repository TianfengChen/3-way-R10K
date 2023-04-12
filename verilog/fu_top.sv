`timescale 1ns/100ps

module fu_top(
	input	clk,
	input	rst_n,
	input	pipe_flush,
  	input	REG_READ_PACKET		reg_read_pkt	[0:`ISSUE_WIDTH-1],    
  	output 	EXECUTE_PACKET		execute_pkt		[0:`ISSUE_WIDTH-1]
);

	REG_READ_PACKET		reg_read_pkt_pipe	[0:`MULT_LATENCY-1]	;
	reg		[`XLEN-1:0]	op1_mux_out 		[0:`ISSUE_WIDTH-1]	;
	reg		[`XLEN-1:0]	op2_mux_out 		[0:`ISSUE_WIDTH-1]	;
	wire	[`XLEN-1:0] npc					[0:`ISSUE_WIDTH-1]	;


	genvar i;
	generate
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			assign npc[i] = reg_read_pkt[i].pc + 3'd4;

			always_comb begin
				op1_mux_out[i] = `XLEN'hdeadfbac;
				case (reg_read_pkt[i].op1_select)
					OPA_IS_RS1:  op1_mux_out[i] = reg_read_pkt[i].op1_val;
					OPA_IS_NPC:  op1_mux_out[i] = npc[i];
					OPA_IS_PC:   op1_mux_out[i] = reg_read_pkt[i].pc;
					OPA_IS_ZERO: op1_mux_out[i] = 0;
				endcase
			end
		end
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			always_comb begin
				// Default value, Set only because the case isnt full.  If you see this
				// value on the output of the mux you have an invalid opb_select
				op2_mux_out[i] = `XLEN'hfacefeed;
				case (reg_read_pkt[i].op2_select)
					OPB_IS_RS2:   op2_mux_out[i] = reg_read_pkt[i].op2_val;
					OPB_IS_I_IMM: op2_mux_out[i] = `RV32_signext_Iimm(reg_read_pkt[i].inst);
					OPB_IS_S_IMM: op2_mux_out[i] = `RV32_signext_Simm(reg_read_pkt[i].inst);
					OPB_IS_B_IMM: op2_mux_out[i] = `RV32_signext_Bimm(reg_read_pkt[i].inst);
					OPB_IS_U_IMM: op2_mux_out[i] = `RV32_signext_Uimm(reg_read_pkt[i].inst);
					OPB_IS_J_IMM: op2_mux_out[i] = `RV32_signext_Jimm(reg_read_pkt[i].inst);
				endcase 
			end
		end
	endgenerate

	alu u_alu_0 (
		.opa(op1_mux_out[0]),
		.opb(op2_mux_out[0]),
		.func(reg_read_pkt[0].op_type),
		.result(execute_pkt[0].result)
	);

	alu u_alu_1 (
		.opa(op1_mux_out[1]),
		.opb(op2_mux_out[1]),
		.func(reg_read_pkt[1].op_type),
		.result(execute_pkt[1].result)
	);

	alu u_alu_2 (
		.opa(op1_mux_out[2]),
		.opb(op2_mux_out[2]),
		.func(reg_read_pkt[2].op_type),
		.result(execute_pkt[2].result)
	);	

	alu u_alu_3 (
		.opa(op1_mux_out[3]),
		.opb(op2_mux_out[3]),
		.func(reg_read_pkt[3].op_type),
		.result(execute_pkt[3].result)
	);

	mult_top u_mult_0(
		.clk		(clk),				
		.rst_n		(rst_n),				
		.pipe_flush	(pipe_flush),				
		.mcand		(op1_mux_out[4]),				
		.mplier		(op2_mux_out[4]),
		.func		(reg_read_pkt[4].op_type),		
		.result		(execute_pkt[4].result)
	);

	bru u_bru_0 (
		.rs1(reg_read_pkt[5].op1_val), 
		.rs2(reg_read_pkt[5].op2_val), 
		.rd(execute_pkt[5].result), //this is trash when it is cond br, x0=rd 
		.op1(op1_mux_out[5]), 
		.op2(op2_mux_out[5]),
		.cond_branch(reg_read_pkt[5].cond_branch), 
		.uncond_branch(reg_read_pkt[5].uncond_branch), 
		.pc(reg_read_pkt[5].pc), 
		.inst(reg_read_pkt[5].inst), 
		.target_pc(execute_pkt[5].target_pc),
		.branch_taken(execute_pkt[5].branch_dir)
	);

	agu u_agu_0(
		.opa(op1_mux_out[6]),
		.opb(op2_mux_out[6]),
		.result(execute_pkt[6].result)
	);


	//cond branch/store must has zero reg
	assert property (@(posedge clk) rst_n==1&&execute_pkt[5].cond_branch |-> execute_pkt[5].dest_prn==0);
	assert property (@(posedge clk) rst_n==1&&execute_pkt[6].wr_mem |-> execute_pkt[6].dest_prn==0);
	

	always@(posedge clk or negedge rst_n) begin	
		if(~rst_n) begin
			reg_read_pkt_pipe[0] <= 0;
			reg_read_pkt_pipe[1] <= 0;
			//reg_read_pkt_pipe[2] <= 0;
			//reg_read_pkt_pipe[3] <= 0;
		end
		else if(pipe_flush) begin
			reg_read_pkt_pipe[0] <= 0;
			reg_read_pkt_pipe[1] <= 0;
			//reg_read_pkt_pipe[2] <= 0;
			//reg_read_pkt_pipe[3] <= 0;
		end
		else begin
			reg_read_pkt_pipe[0] <= reg_read_pkt[4];
			reg_read_pkt_pipe[1] <= reg_read_pkt_pipe[0];
			//reg_read_pkt_pipe[2] <= reg_read_pkt_pipe[1];
			//reg_read_pkt_pipe[3] <= reg_read_pkt_pipe[2];
		end
	end



	
	//propagate other metadata
	generate		
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			if(i==4) begin//mult delay other metadata by 2 cycles
				assign execute_pkt[i].inst			=	reg_read_pkt_pipe[1].inst			;
				assign execute_pkt[i].pc		 	=   reg_read_pkt_pipe[1].pc		 	 	;
				assign execute_pkt[i].dest_prn 	 	=   reg_read_pkt_pipe[1].dest_prn 	 	;
				assign execute_pkt[i].rd_mem 		=   reg_read_pkt_pipe[1].rd_mem 		;
				assign execute_pkt[i].wr_mem 		=   reg_read_pkt_pipe[1].wr_mem 		;
				assign execute_pkt[i].cond_branch 	=   reg_read_pkt_pipe[1].cond_branch 	;
				assign execute_pkt[i].uncond_branch =	reg_read_pkt_pipe[1].uncond_branch 	;
			//	assign execute_pkt[i].halt 			=	reg_read_pkt_pipe[1].halt			;
			//	assign execute_pkt[i].illegal 		=	reg_read_pkt_pipe[1].illegal 		;
				assign execute_pkt[i].rob_entry	 	=   reg_read_pkt_pipe[1].rob_entry	 	;
				assign execute_pkt[i].st_data	 	=   reg_read_pkt_pipe[1].op2_val		;
				assign execute_pkt[i].stq_tag	 	=   reg_read_pkt_pipe[1].stq_tag		;
				assign execute_pkt[i].ldq_tag	 	=   reg_read_pkt_pipe[1].ldq_tag		;
				assign execute_pkt[i].mem_size	 	=  	reg_read_pkt_pipe[1].inst[14:12]	;
				assign execute_pkt[i].packet_valid	=   reg_read_pkt_pipe[1].packet_valid	;
			end
			else begin
				assign execute_pkt[i].inst			=	reg_read_pkt[i].inst			;
				assign execute_pkt[i].pc		 	=   reg_read_pkt[i].pc		 	 	;
				assign execute_pkt[i].dest_prn 	 	=   reg_read_pkt[i].dest_prn 	 	;
				assign execute_pkt[i].rd_mem 		=   reg_read_pkt[i].rd_mem 			;
				assign execute_pkt[i].wr_mem 		=   reg_read_pkt[i].wr_mem 			;
				assign execute_pkt[i].cond_branch 	=   reg_read_pkt[i].cond_branch 	;
				assign execute_pkt[i].uncond_branch =	reg_read_pkt[i].uncond_branch 	;
			//	assign execute_pkt[i].halt 			=	reg_read_pkt[i].halt			;
			//	assign execute_pkt[i].illegal 		=	reg_read_pkt[i].illegal 		;
				assign execute_pkt[i].rob_entry	 	=   reg_read_pkt[i].rob_entry	 	;
				assign execute_pkt[i].st_data	 	=   reg_read_pkt[i].op2_val	 		;
				assign execute_pkt[i].stq_tag	 	=   reg_read_pkt[i].stq_tag	 		;
				assign execute_pkt[i].ldq_tag	 	=   reg_read_pkt[i].ldq_tag	 		;
				assign execute_pkt[i].mem_size	 	=  	reg_read_pkt[i].inst[14:12]		;
				assign execute_pkt[i].packet_valid	=   reg_read_pkt[i].packet_valid	;
			end
		end
	endgenerate


endmodule
