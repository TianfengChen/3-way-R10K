`timescale 1ns/100ps

module cdb(
	input 			 					inst_valid_alu0_in,    
	input [31:0]  						result_alu0_in,
	input [`PRF_WIDTH-1:0]  			dest_prn_alu0_in,
	input [`ROB_WIDTH-1:0] 				rob_entry_alu0_in,
	input [31:0]						inst_alu0_in,
	input [31:0]						pc_alu0_in,

	input 			 					inst_valid_alu1_in,    
	input [31:0]  						result_alu1_in,
	input [`PRF_WIDTH-1:0]  			dest_prn_alu1_in,
	input [`ROB_WIDTH-1:0] 				rob_entry_alu1_in,
	input [31:0]						inst_alu1_in,
	input [31:0]						pc_alu1_in,

	input 			 					inst_valid_alu2_in,    
	input [31:0]  						result_alu2_in,
	input [`PRF_WIDTH-1:0]  			dest_prn_alu2_in,
	input [`ROB_WIDTH-1:0] 				rob_entry_alu2_in,
	input [31:0]						inst_alu2_in,
	input [31:0]						pc_alu2_in,

	input 			 					inst_valid_mul_in,    
	input [31:0]  						result_mul_in,
	input [`PRF_WIDTH-1:0]  			dest_prn_mul_in,
	input [`ROB_WIDTH-1:0] 				rob_entry_mul_in,
	input [31:0]						inst_mul_in,
	input [31:0]						pc_mul_in,

	input 			 					inst_valid_mem_in,    
	input [31:0]  						result_mem_in,
	input [`PRF_WIDTH-1:0]  			dest_prn_mem_in,
	input [`ROB_WIDTH-1:0] 				rob_entry_mem_in,
	input								rd_mem_in,
	input								wr_mem_in,
	input [31:0]						inst_mem_in,
	input [31:0]						pc_mem_in,	

	input 			 					inst_valid_bcond_in,    
	input [31:0]  						link_addr_in,
	input [`PRF_WIDTH-1:0]  			dest_prn_bcond_in,
	input [`ROB_WIDTH-1:0]				rob_entry_bcond_in,
	input 		  						cond_branch_in,	//this is a branch/jmp inst
	input 		  						uncond_branch_in,	//this is a branch/jmp inst
	input [31:0]						inst_bcond_in,
	input [31:0]						pc_bcond_in,

	output [`N_WAY-1:0]					cdb_valid,
	output [(`N_WAY)*32-1:0]			cdb_value,
	output [(`N_WAY)*(`PRF_WIDTH)-1:0]	cdb_tag,
	output [(`N_WAY)*(`ROB_WIDTH)-1:0]	cdb_rob,
	output [`N_WAY-1:0]					cdb_cond_branch,
	output [`N_WAY-1:0]					cdb_uncond_branch,
	output [`N_WAY-1:0]					cdb_rd_mem,
	output [`N_WAY-1:0]					cdb_wr_mem,
	output [(`N_WAY)*32-1:0]			cdb_inst,
	output [(`N_WAY)*32-1:0]			cdb_pc
);

	wire [`FU_CNT-1:0] 				cdb_select;
	wire [(`N_WAY)*(`FU_CNT)-1:0] 	gnt_bus_cdb_select;
	wire [`FU_CNT-1:0] 				cdb_select_onehot [0:`N_WAY-1];

	wire [`CDB_DATABUS_OUT_WIDTH-1:0] cdb_databus_alu0;
	wire [`CDB_DATABUS_OUT_WIDTH-1:0] cdb_databus_alu1;
	wire [`CDB_DATABUS_OUT_WIDTH-1:0] cdb_databus_alu2;
	wire [`CDB_DATABUS_OUT_WIDTH-1:0] cdb_databus_mul;
	wire [`CDB_DATABUS_OUT_WIDTH-1:0] cdb_databus_mem;
	wire [`CDB_DATABUS_OUT_WIDTH-1:0] cdb_databus_bcond;
	wire [(`FU_CNT)*(`CDB_DATABUS_OUT_WIDTH)-1:0] cdb_databus_x6;
	wire [`CDB_DATABUS_OUT_WIDTH-1:0] cdb_databus_out [0:`N_WAY-1];

	//assign cdb_select = {inst_valid_alu0_in,inst_valid_alu1_in,inst_valid_alu2_in,inst_valid_mul_in,(inst_valid_mem_in|rd_mem_in|wr_mem_in),(inst_valid_bcond_in|cond_branch_in|uncond_branch_in)};
	assign cdb_select = {inst_valid_alu0_in,inst_valid_alu1_in,inst_valid_alu2_in,inst_valid_mul_in,inst_valid_mem_in,(inst_valid_bcond_in|cond_branch_in|uncond_branch_in)};
	assign {cdb_select_onehot[2],cdb_select_onehot[1],cdb_select_onehot[0]} = gnt_bus_cdb_select;

	//result,prn,rob,cond,uncond,rd,wr
	assign cdb_databus_alu0 = {inst_alu0_in,pc_alu0_in,result_alu0_in,dest_prn_alu0_in,rob_entry_alu0_in,1'b0,1'b0,1'b0,1'b0};
	assign cdb_databus_alu1 = {inst_alu1_in,pc_alu1_in,result_alu1_in,dest_prn_alu1_in,rob_entry_alu1_in,1'b0,1'b0,1'b0,1'b0};
	assign cdb_databus_alu2 = {inst_alu2_in,pc_alu2_in,result_alu2_in,dest_prn_alu2_in,rob_entry_alu2_in,1'b0,1'b0,1'b0,1'b0};
	assign cdb_databus_mul = {inst_mul_in,pc_mul_in,result_mul_in,dest_prn_mul_in,rob_entry_mul_in,1'b0,1'b0,1'b0,1'b0};
	assign cdb_databus_mem = {inst_mem_in,pc_mem_in,result_mem_in,dest_prn_mem_in,rob_entry_mem_in,1'b0,1'b0,rd_mem_in,wr_mem_in};
	assign cdb_databus_bcond = {inst_bcond_in,pc_bcond_in,link_addr_in,dest_prn_bcond_in,rob_entry_bcond_in,cond_branch_in,uncond_branch_in,1'b0,1'b0};
	assign cdb_databus_x6 = {cdb_databus_alu0,cdb_databus_alu1,cdb_databus_alu2,cdb_databus_mul,cdb_databus_mem,cdb_databus_bcond};


	genvar i;
	generate
		for(i=0;i<`N_WAY;i=i+1) begin
			assign cdb_valid[i] 							= cdb_select_onehot[i]!=0 & ~cdb_databus_out[i][3] & ~cdb_databus_out[i][0];
			assign cdb_value[i*(`XLEN)+:(`XLEN)] 			= cdb_valid[i] ? cdb_databus_out[i][48:17] : 0;
			assign cdb_tag[i*(`PRF_WIDTH)+:(`PRF_WIDTH)] 	= cdb_valid[i] ? cdb_databus_out[i][16:10] : 0;
			assign cdb_rob[i*(`ROB_WIDTH)+:(`ROB_WIDTH)] 	= (cdb_valid[i]|cdb_databus_out[i][3]) ? cdb_databus_out[i][9:4] : 0;
			assign cdb_cond_branch[i] 						= cdb_databus_out[i][3];
			assign cdb_uncond_branch[i] 					= cdb_databus_out[i][2];
			assign cdb_rd_mem[i] 							= cdb_databus_out[i][1];
			assign cdb_wr_mem[i] 							= cdb_databus_out[i][0];
			assign cdb_pc[i*(`XLEN)+:(`XLEN)] 				= cdb_databus_out[i][80:49];
			assign cdb_inst[i*(`XLEN)+:(`XLEN)]				= cdb_databus_out[i][111:81];
		end
	endgenerate

	psel_gen #(
		.REQS(`N_WAY),
		.WIDTH(`FU_CNT)) 
	psel_gen_inst_cdb_alloc(  //dispatch use the lowest numbered rs avaliable 	
		.req(cdb_select),
		.gnt(), 
		.gnt_bus(gnt_bus_cdb_select),			//mux 3 in 16 ctrl signal
		.empty()
	);



	mux_onehot #(
		.INPUT_NUM(`FU_CNT),	//6 fu
		.DATA_WIDTH(`CDB_DATABUS_OUT_WIDTH))	
	mux_onehot_cdb0(
		.onehot(cdb_select_onehot[0]),				
		.i_data(cdb_databus_x6),					
		.o_data(cdb_databus_out[0])						
	);

	mux_onehot #(
		.INPUT_NUM(`FU_CNT),
		.DATA_WIDTH(`CDB_DATABUS_OUT_WIDTH))	
	mux_onehot_cdb1(
		.onehot(cdb_select_onehot[1]),				
		.i_data(cdb_databus_x6),					
		.o_data(cdb_databus_out[1])						
	);

	mux_onehot #(
		.INPUT_NUM(`FU_CNT),
		.DATA_WIDTH(`CDB_DATABUS_OUT_WIDTH))	
	mux_onehot_cdb2(
		.onehot(cdb_select_onehot[2]),				
		.i_data(cdb_databus_x6),					
		.o_data(cdb_databus_out[2])						
	);
	


	always@(*) begin
		assert(cdb_select[5]+cdb_select[4]+cdb_select[3]+cdb_select[2]+cdb_select[1]+cdb_select[0]<=3) else $finish;
	end

endmodule

