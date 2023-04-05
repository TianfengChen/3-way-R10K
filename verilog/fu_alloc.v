`timescale 1ns/100ps

module fu_alloc(
	input [`N_WAY-1:0]	 				inst_valid_in, 
 	input [32*(`N_WAY)-1:0] 			inst_in,				// from decoder
 	input [32*(`N_WAY)-1:0] 			pc_in,				// from decoder
 	input [32*(`N_WAY)-1:0] 			npc_in,				// from decoder
	input [5*(`N_WAY)-1:0] 				op_type_in, 
	input [32*(`N_WAY)-1:0]  			op1_val_in,
	input [32*(`N_WAY)-1:0]  			op2_val_in,
   	input [2*`N_WAY-1:0]				op1_select_in,		
	input [4*`N_WAY-1:0]				op2_select_in,	
	input [`N_WAY-1:0]					rd_mem_in,			
	input [`N_WAY-1:0]					wr_mem_in,			
	input [`N_WAY-1:0]					cond_branch_in,	
	input [`N_WAY-1:0]					uncond_branch_in,	
	input [`N_WAY-1:0]					halt_in,			
	input [`N_WAY-1:0]					illigal_in,	
	input [(`ROB_WIDTH)*(`N_WAY)-1:0] 	rob_entry_in,
	input [(`PRF_WIDTH)*(`N_WAY)-1:0]  	dest_prn_in,
	input [4*(`N_WAY)-1:0]			 	fu_type_in, 	//  
	input [(`IMM_WIDTH)*(`N_WAY)-1:0] 	imm_in, 		//  

	output 			 					inst_valid_alu0_out,    
	output [4:0] 						op_type_alu0_out, 
	output [31:0]  						op1_val_alu0_out,
	output [31:0]  						op2_val_alu0_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_alu0_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_alu0_out,
	output [31:0]  						inst_alu0_out,
	output [31:0]  						pc_alu0_out,

	output 			 					inst_valid_alu1_out,    
	output [4:0] 						op_type_alu1_out, 
	output [31:0]  						op1_val_alu1_out,
	output [31:0]  						op2_val_alu1_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_alu1_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_alu1_out,
	output [31:0]  						inst_alu1_out,
	output [31:0]  						pc_alu1_out,

	output 			 					inst_valid_alu2_out,    
	output [4:0] 						op_type_alu2_out, 
	output [31:0]  						op1_val_alu2_out,
	output [31:0]  						op2_val_alu2_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_alu2_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_alu2_out,
	output [31:0]  						inst_alu2_out,
	output [31:0]  						pc_alu2_out,

	output 			 					inst_valid_mul_out,    
	output [4:0] 						op_type_mul_out, 
	output [31:0]  						op1_val_mul_out,
	output [31:0]  						op2_val_mul_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_mul_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_mul_out,
	output [31:0]  						inst_mul_out,
	output [31:0]  						pc_mul_out,

	output 			 					inst_valid_mem_out,    
	output [4:0] 						op_type_mem_out, 
	output [31:0]  						op1_val_mem_out,
	output [31:0]  						op2_val_mem_out,
	output								rd_mem_out,
	output								wr_mem_out,
	output [11:0]						imm_mem_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_mem_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_mem_out,
	output [31:0]  						inst_mem_out,
	output [31:0]  						pc_mem_out, 


	output 			 					inst_valid_bcond_out,    
	output [4:0] 						op_type_bcond_out, 
	output [31:0]  						op1_val_bcond_out,
	output [31:0]  						op2_val_bcond_out,
	output [31:0]  						inst_bcond_out,
	output [31:0]  						pc_bcond_out,
	output [31:0]  						npc_bcond_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_bcond_out,
	output [`IMM_WIDTH-1:0]  			imm_branch_out,
	output 					  			cond_branch_out,
	output 					  			uncond_branch_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_bcond_out
);

	wire [31:0]							inst_in_way		 	[0:`N_WAY-1];
	wire [31:0]							pc_in_way		 	[0:`N_WAY-1];
	wire [31:0]							npc_in_way		 	[0:`N_WAY-1];
	wire [4:0] 							op_type_in_way   	[0:`N_WAY-1];			
	wire [31:0] 						op1_val_in_way   	[0:`N_WAY-1];			
	wire [31:0] 						op2_val_in_way   	[0:`N_WAY-1];
	wire [`PRF_WIDTH-1:0] 				dest_prn_in_way	 	[0:`N_WAY-1];
	wire [1:0]							op1_select_in_way	[0:`N_WAY-1];
	wire [3:0]							op2_select_in_way	[0:`N_WAY-1];
	wire [3:0]			 				fu_type_in_way 	 	[0:`N_WAY-1];
	wire [`IMM_WIDTH-1:0]			 	imm_in_way	 	 	[0:`N_WAY-1];
	wire [`ROB_WIDTH-1:0]			 	rob_entry_in_way 	[0:`N_WAY-1];
	wire [`DATABUS_FU_ALLOC-1:0]	 		fu_databus_in_way [0:`N_WAY-1];
	wire [(`DATABUS_FU_ALLOC)*(`N_WAY)-1:0]	fu_databus_in_3way;
	wire [`DATABUS_FU_ALLOC-1:0]	 		databus_mul;
	wire [`DATABUS_FU_ALLOC-1:0]	 		databus_mem;
	wire [`DATABUS_FU_ALLOC-1:0]	 		databus_bcond;



	wire [2:0] mul_way_sel;
	wire [2:0] mem_way_sel;
	wire [2:0] bcond_way_sel;

	reg [31:0] op1_mux_out [0:`N_WAY-1];
	reg [31:0] op2_mux_out [0:`N_WAY-1];

	assign {inst_in_way[2],inst_in_way[1],inst_in_way[0]} 					= inst_in;
	assign {pc_in_way[2],pc_in_way[1],pc_in_way[0]} 						= pc_in;
	assign {npc_in_way[2],npc_in_way[1],npc_in_way[0]} 						= npc_in;
	assign {op_type_in_way[2],op_type_in_way[1],op_type_in_way[0]} 			= op_type_in;
	assign {op1_val_in_way[2],op1_val_in_way[1],op1_val_in_way[0]} 			= op1_val_in;
	assign {op2_val_in_way[2],op2_val_in_way[1],op2_val_in_way[0]} 			= op2_val_in;
	assign {dest_prn_in_way[2],dest_prn_in_way[1],dest_prn_in_way[0]} 		= dest_prn_in;
	assign {op1_select_in_way[2],op1_select_in_way[1],op1_select_in_way[0]} = op1_select_in;
	assign {op2_select_in_way[2],op2_select_in_way[1],op2_select_in_way[0]} = op2_select_in;
	assign {fu_type_in_way[2],fu_type_in_way[1],fu_type_in_way[0]} 			= fu_type_in;
	assign {imm_in_way[2],imm_in_way[1],imm_in_way[0]} 						= imm_in;
	assign {rob_entry_in_way[2],rob_entry_in_way[1],rob_entry_in_way[0]} 	= rob_entry_in;

	assign mul_way_sel 		= {fu_type_in_way[2][1],fu_type_in_way[1][1],fu_type_in_way[0][1]};
	assign mem_way_sel 		= {fu_type_in_way[2][2],fu_type_in_way[1][2],fu_type_in_way[0][2]};
	assign bcond_way_sel 	= {fu_type_in_way[2][3],fu_type_in_way[1][3],fu_type_in_way[0][3]};

	assign fu_databus_in_3way = {fu_databus_in_way[2],fu_databus_in_way[1],fu_databus_in_way[0]};

	genvar i;
	generate
		for(i=0;i<`N_WAY;i=i+1) begin
			assign fu_databus_in_way[i] = {inst_in_way[i],rob_entry_in_way[i],pc_in_way[i],npc_in_way[i],op_type_in_way[i],op1_mux_out[i],op2_mux_out[i],
										   rd_mem_in[i],wr_mem_in[i],cond_branch_in[i],uncond_branch_in[i],
										   halt_in[i],illigal_in[i],dest_prn_in_way[i],imm_in_way[i]};
		end
		for(i=0;i<`N_WAY;i=i+1) begin
			always_comb begin
				op1_mux_out[i] = `XLEN'hdeadfbac;
				case (op1_select_in_way[i])
					OPA_IS_RS1:  op1_mux_out[i] = op1_val_in_way[i];
					OPA_IS_NPC:  op1_mux_out[i] = npc_in_way[i];
					OPA_IS_PC:   op1_mux_out[i] = pc_in_way[i];
					OPA_IS_ZERO: op1_mux_out[i] = 0;
				endcase
			end
		end
		for(i=0;i<`N_WAY;i=i+1) begin
			always_comb begin
				// Default value, Set only because the case isnt full.  If you see this
				// value on the output of the mux you have an invalid opb_select
				op2_mux_out[i] = `XLEN'hfacefeed;
				case (op2_select_in_way[i])
					OPB_IS_RS2:   op2_mux_out[i] = op2_val_in_way[i];
					OPB_IS_I_IMM: op2_mux_out[i] = `RV32_signext_Iimm(inst_in_way[i]);
					OPB_IS_S_IMM: op2_mux_out[i] = `RV32_signext_Simm(inst_in_way[i]);
					OPB_IS_B_IMM: op2_mux_out[i] = `RV32_signext_Bimm(inst_in_way[i]);
					OPB_IS_U_IMM: op2_mux_out[i] = `RV32_signext_Uimm(inst_in_way[i]);
					OPB_IS_J_IMM: op2_mux_out[i] = `RV32_signext_Jimm(inst_in_way[i]);
				endcase 
			end
		end
	endgenerate


	assign inst_valid_alu0_out 	= inst_valid_in[0] & fu_type_in_way[0][0];
	assign op_type_alu0_out		= inst_valid_alu0_out ? op_type_in_way[0] : 0;
	assign op1_val_alu0_out		= inst_valid_alu0_out ? fu_databus_in_way[0][108:77] : 0;
	assign op2_val_alu0_out		= inst_valid_alu0_out ? fu_databus_in_way[0][76:45 ] : 0;
	assign dest_prn_alu0_out	= inst_valid_alu0_out ? dest_prn_in_way[0] : 0;
	assign rob_entry_alu0_out	= inst_valid_alu0_out ? rob_entry_in_way[0] : 0;
	assign inst_alu0_out		= inst_valid_alu0_out ? inst_in_way[0] : 0;
	assign pc_alu0_out			= inst_valid_alu0_out ? pc_in_way[0] : 0;


	assign inst_valid_alu1_out 	= inst_valid_in[1] & fu_type_in_way[1][0];
	assign op_type_alu1_out		= inst_valid_alu1_out ? op_type_in_way[1] : 0;
	assign op1_val_alu1_out		= inst_valid_alu1_out ? fu_databus_in_way[1][108:77] : 0;
	assign op2_val_alu1_out		= inst_valid_alu1_out ? fu_databus_in_way[1][76:45 ] : 0;
	assign dest_prn_alu1_out	= inst_valid_alu1_out ? dest_prn_in_way[1] : 0;
	assign rob_entry_alu1_out	= inst_valid_alu1_out ? rob_entry_in_way[1] : 0;
	assign inst_alu1_out		= inst_valid_alu1_out ? inst_in_way[1] : 0;
	assign pc_alu1_out			= inst_valid_alu1_out ? pc_in_way[1] : 0;

	assign inst_valid_alu2_out 	= inst_valid_in[2] & fu_type_in_way[2][0];
	assign op_type_alu2_out		= inst_valid_alu2_out ? op_type_in_way[2] : 0;
	assign op1_val_alu2_out		= inst_valid_alu2_out ? fu_databus_in_way[2][108:77] : 0;
	assign op2_val_alu2_out		= inst_valid_alu2_out ? fu_databus_in_way[2][76:45 ] : 0;
	assign dest_prn_alu2_out	= inst_valid_alu2_out ? dest_prn_in_way[2] : 0;
	assign rob_entry_alu2_out	= inst_valid_alu2_out ? rob_entry_in_way[2] : 0;
	assign inst_alu2_out		= inst_valid_alu2_out ? inst_in_way[2] : 0;
	assign pc_alu2_out			= inst_valid_alu2_out ? pc_in_way[2] : 0;

	assign inst_valid_mul_out 	= (fu_type_in_way[2][1]&inst_valid_in[2]) | (fu_type_in_way[1][1]&inst_valid_in[1]) | (fu_type_in_way[0][1]&inst_valid_in[0]);
	assign op_type_mul_out		= inst_valid_mul_out ? databus_mul[113:109] : 0;
	assign op1_val_mul_out		= inst_valid_mul_out ? databus_mul[108:77] : 0; 
	assign op2_val_mul_out		= inst_valid_mul_out ? databus_mul[76:45 ] : 0; 
	assign dest_prn_mul_out		= inst_valid_mul_out ? databus_mul[63:32] : 0;	
	assign rob_entry_mul_out	= inst_valid_mul_out ? databus_mul[183:178] : 0;
	assign inst_mul_out			= inst_valid_mul_out ? databus_mul[215:184] : 0;
	assign pc_mul_out			= inst_valid_mul_out ? databus_mul[177:146] : 0;

	assign inst_valid_mem_out 	= (fu_type_in_way[2][2]&inst_valid_in[2]) | (fu_type_in_way[1][2]&inst_valid_in[1]) | (fu_type_in_way[0][2]&inst_valid_in[0]);
	assign op_type_mem_out		= inst_valid_mem_out ? databus_mem[113:109] : 0;
	assign op1_val_mem_out		= inst_valid_mem_out ? databus_mem[108:77] : 0; 
	assign op2_val_mem_out		= inst_valid_mem_out ? databus_mem[76:45 ] : 0; 
	assign dest_prn_mem_out		= inst_valid_mem_out ? databus_mem[63:32] : 0;	
	assign rob_entry_mem_out	= inst_valid_mem_out ? databus_mem[183:178] : 0;
	assign inst_mem_out			= inst_valid_mem_out ? databus_mem[215:184] : 0;
	assign pc_mem_out			= inst_valid_mem_out ? databus_mem[177:146] : 0;
	assign wr_mem_out			= inst_valid_mem_out ? databus_mem[43] : 0;
	assign rd_mem_out			= inst_valid_mem_out ? databus_mem[44] : 0;

	assign inst_valid_bcond_out	= (fu_type_in_way[2][3]&inst_valid_in[2]) | (fu_type_in_way[1][3]&inst_valid_in[1]) | (fu_type_in_way[0][3]&inst_valid_in[0]);
	assign op_type_bcond_out	= inst_valid_bcond_out ? databus_bcond[113:109] : 0;
	assign op1_val_bcond_out	= inst_valid_bcond_out ? databus_bcond[108:77] : 0; 
	assign op2_val_bcond_out	= inst_valid_bcond_out ? databus_bcond[76:45 ] : 0; 
	assign dest_prn_bcond_out	= inst_valid_bcond_out ? databus_bcond[63:32] : 0;	
	assign inst_bcond_out		= inst_valid_bcond_out ? databus_bcond[215:184] : 0;	
	assign pc_bcond_out			= inst_valid_bcond_out ? (databus_bcond[190:184] == 7'b1100111 ? op1_val_bcond_out : databus_bcond[177:146]) : 0;	
	assign npc_bcond_out		= inst_valid_bcond_out ? databus_bcond[145:114] : 0;	
	assign cond_branch_out		= inst_valid_bcond_out ? databus_bcond[42] : 0;	
	assign uncond_branch_out	= inst_valid_bcond_out ? databus_bcond[41] : 0;	
	assign imm_branch_out		= inst_valid_bcond_out ? databus_bcond[31:0] : 0;	//TODO	
	assign rob_entry_bcond_out	= inst_valid_bcond_out ? databus_bcond[183:178] : 0;	
                                             

	mux_onehot #(
		.INPUT_NUM(`N_WAY),
		.DATA_WIDTH(`DATABUS_FU_ALLOC))	
	mux_onehot_mul_alloc(
		.onehot(mul_way_sel),				
		.i_data(fu_databus_in_3way),					
		.o_data(databus_mul)						
	);				

	mux_onehot #(
		.INPUT_NUM(`N_WAY),
		.DATA_WIDTH(`DATABUS_FU_ALLOC))	
	mux_onehot_mem_alloc(
		.onehot(mem_way_sel),				
		.i_data(fu_databus_in_3way),					
		.o_data(databus_mem)						
	);

	mux_onehot #(
		.INPUT_NUM(`N_WAY),
		.DATA_WIDTH(`DATABUS_FU_ALLOC))	
	mux_onehot_bcond_alloc(
		.onehot(bcond_way_sel),				
		.i_data(fu_databus_in_3way),					
		.o_data(databus_bcond)						
	);	



endmodule

