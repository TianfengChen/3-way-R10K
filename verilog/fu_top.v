//`default_nettype none
`timescale 1ns/100ps

module fu_top(
	//****************RS+PRF INPUTS**********************
	input								clk,
	input								rst,
	input [`N_WAY-1:0]	 				inst_valid_in, 
 	input [32*(`N_WAY)-1:0] 			inst_in,			// from decoder
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
	//****************DCACHE CTRL INPUTS*********************
	input [31:0] 						load_data_in,		
	input		 						load_data_valid_in,	

	//*****************OUTPUTS to CDB**********************
	output 			 					inst_valid_alu0_out,    
	output [31:0]  						result_alu0_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_alu0_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_alu0_out,
	output [31:0]  						inst_alu0_out,
	output [31:0]  						pc_alu0_out,

	output 			 					inst_valid_alu1_out,    
	output [31:0]  						result_alu1_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_alu1_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_alu1_out,
	output [31:0]  						inst_alu1_out,
	output [31:0]  						pc_alu1_out,

	output 			 					inst_valid_alu2_out,    
	output [31:0]  						result_alu2_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_alu2_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_alu2_out,
	output [31:0]  						inst_alu2_out,
	output [31:0]  						pc_alu2_out,

	output 			 					inst_valid_mul_out,    
	output [31:0]  						result_mul_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_mul_out,
	output [`ROB_WIDTH-1:0] 			rob_entry_mul_out,
	output [31:0]  						inst_mul_out,
	output [31:0]  						pc_mul_out,

	output 			 					inst_valid_bcond_out,    
	output [31:0]  						link_addr_out,
	output [`PRF_WIDTH-1:0]  			dest_prn_bcond_out,
	output [`ROB_WIDTH-1:0]				rob_entry_bcond_out,
	output [31:0] 						branch_target_addr_out,		
	output 		  						branch_taken_out,	
	output 		  						cond_branch_out,	//this is a branch/jmp inst
	output 		  						uncond_branch_out,	//this is a branch/jmp inst
	output [31:0]  						inst_bcond_out,
	output [31:0]  						pc_bcond_out,
	
	output 			 					inst_valid_mem_out,  //load on cdb  
	output [31:0]						load_data_out,		 //load on cdb
	output [`PRF_WIDTH-1:0]  			dest_prn_mem_out,	 //load on cdb
	output [`ROB_WIDTH-1:0] 			rob_entry_mem_out,	 //load on cdb
	output								rd_mem_out,			 //load on cdb
	output								wr_mem_out,			 //load on cdb
	output [31:0]  						inst_mem_out,		 //load on cdb
	output [31:0]  						pc_mem_out,			 //load on cdb
	//*****************OUTPUTS to rob/dcache ctrl**********************
	output [31:0]  						store_address_mem_out,	//store info to rob
	output [31:0]  						store_data_mem_out,  	//store info to rob
	output [`ROB_WIDTH-1:0]				store_rob_out,			//store info to rob
	output 								store_en_out,			//store info to rob		
	output [31:0]						load_address_mem_out,	//load info to dcache control		
	output [2:0]						load_size_out,			//load info to dcache control
	output  							load_en_out,			//load info to dcache control
	//*****************OUTPUTS to rs**********************
	output reg							miss_waiting

);

	wire 			 		fu_alloc_inst_valid_alu0_out;    
	wire [4:0] 				fu_alloc_op_type_alu0_out; 
	wire [31:0]  			fu_alloc_op1_val_alu0_out;
	wire [31:0]  			fu_alloc_op2_val_alu0_out;
	wire [`PRF_WIDTH-1:0]  	fu_alloc_dest_prn_alu0_out;
	wire [`ROB_WIDTH-1:0]  	fu_alloc_rob_entry_alu0_out;
	wire [31:0]  			fu_alloc_inst_alu0_out;
	wire [31:0]  			fu_alloc_pc_alu0_out;

	wire 			 		fu_alloc_inst_valid_alu1_out;    
	wire [4:0] 				fu_alloc_op_type_alu1_out; 
	wire [31:0]  			fu_alloc_op1_val_alu1_out;
	wire [31:0]  			fu_alloc_op2_val_alu1_out;
	wire [`PRF_WIDTH-1:0]  	fu_alloc_dest_prn_alu1_out;
	wire [`ROB_WIDTH-1:0]  	fu_alloc_rob_entry_alu1_out;
	wire [31:0]  			fu_alloc_inst_alu1_out;
	wire [31:0]  			fu_alloc_pc_alu1_out;    

	wire 			 		fu_alloc_inst_valid_alu2_out;    
	wire [4:0] 				fu_alloc_op_type_alu2_out; 
	wire [31:0]  			fu_alloc_op1_val_alu2_out;
	wire [31:0]  			fu_alloc_op2_val_alu2_out;
	wire [`PRF_WIDTH-1:0]  	fu_alloc_dest_prn_alu2_out;
	wire [`ROB_WIDTH-1:0]  	fu_alloc_rob_entry_alu2_out;
	wire [31:0]  			fu_alloc_inst_alu2_out;
	wire [31:0]  			fu_alloc_pc_alu2_out;     

	wire 			 		fu_alloc_inst_valid_mul_out;    
	wire [4:0] 				fu_alloc_op_type_mul_out; 
	wire [31:0]  			fu_alloc_op1_val_mul_out;
	wire [31:0]  			fu_alloc_op2_val_mul_out;
	wire [`PRF_WIDTH-1:0]  	fu_alloc_dest_prn_mul_out;
	wire [`ROB_WIDTH-1:0]  	fu_alloc_rob_entry_mul_out;
	wire [31:0]  			fu_alloc_inst_mul_out;
	wire [31:0]  			fu_alloc_pc_mul_out;

	wire 			 		fu_alloc_inst_valid_mem_out;    
	wire [4:0] 				fu_alloc_op_type_mem_out; 
	wire [31:0]  			fu_alloc_op1_val_mem_out;
	wire [31:0]  			fu_alloc_op2_val_mem_out;
	wire					fu_alloc_rd_mem_out;
	wire					fu_alloc_wr_mem_out;
	wire [11:0]				fu_alloc_imm_mem_out;
	wire [`PRF_WIDTH-1:0]  	fu_alloc_dest_prn_mem_out;	
	wire [`ROB_WIDTH-1:0]  	fu_alloc_rob_entry_mem_out;	
	wire [31:0]  			fu_alloc_inst_mem_out;		
	wire [31:0]  			fu_alloc_pc_mem_out;		
                            
	wire 			 		fu_alloc_inst_valid_bcond_out;    
	wire [4:0] 				fu_alloc_op_type_bcond_out; 
	wire [31:0]  			fu_alloc_op1_val_bcond_out;
	wire [31:0]  			fu_alloc_op2_val_bcond_out;
	wire [31:0]  			fu_alloc_inst_bcond_out;
	wire [31:0]  			fu_alloc_pc_bcond_out;
	wire [31:0]  			fu_alloc_npc_bcond_out;
	wire [`PRF_WIDTH-1:0]  	fu_alloc_dest_prn_bcond_out;
	wire [`IMM_WIDTH-1:0]  	fu_alloc_imm_branch_out;
	wire 					fu_alloc_cond_branch_out;
	wire 					fu_alloc_uncond_branch_out;
	wire [`ROB_WIDTH-1:0]	fu_alloc_rob_entry_bcond_out;

	wire 					brcond_result;	
	wire [31:0] 			brcond_add;	

	wire [31:0]				address_mem_out;	
	
	wire mult_en;
	reg fu_alloc_inst_valid_mul_out_d0;
	reg [3:0] mult_en_delay;
	reg [`PRF_WIDTH-1:0] dest_prn_mul_d0;
	reg [`PRF_WIDTH-1:0] dest_prn_mul_d1;
	reg [`PRF_WIDTH-1:0] dest_prn_mul_d2;
	reg [`PRF_WIDTH-1:0] dest_prn_mul_d3;
	reg [`ROB_WIDTH-1:0] rob_entry_mul_d0;
	reg [`ROB_WIDTH-1:0] rob_entry_mul_d1;
	reg [`ROB_WIDTH-1:0] rob_entry_mul_d2;
	reg [`ROB_WIDTH-1:0] rob_entry_mul_d3;
	reg [31:0]			 inst_mul_d0; 
	reg [31:0]			 inst_mul_d1; 
	reg [31:0]			 inst_mul_d2; 
	reg [31:0]			 inst_mul_d3; 
	reg [31:0]			 pc_mul_d0; 
	reg [31:0]			 pc_mul_d1; 
	reg [31:0]			 pc_mul_d2; 
	reg [31:0]			 pc_mul_d3;

	reg [`PRF_WIDTH-1:0]  	dest_prn_mem_load;	
	reg [`ROB_WIDTH-1:0] 	rob_entry_mem_load;	
	reg						rd_mem_load;		
	reg						wr_mem_load;		
	reg [31:0]  			inst_mem_load;		
	reg [31:0]  			pc_mem_load;		
	reg [31:0]  			addr_mem_load;		



	assign inst_valid_alu0_out = fu_alloc_inst_valid_alu0_out;
	assign inst_valid_alu1_out = fu_alloc_inst_valid_alu1_out;
	assign inst_valid_alu2_out = fu_alloc_inst_valid_alu2_out;
	assign inst_valid_bcond_out = fu_alloc_inst_valid_bcond_out & fu_alloc_uncond_branch_out;	//write cdb

	assign dest_prn_alu0_out = fu_alloc_dest_prn_alu0_out;
	assign dest_prn_alu1_out = fu_alloc_dest_prn_alu1_out;
	assign dest_prn_alu2_out = fu_alloc_dest_prn_alu2_out;
	assign dest_prn_mul_out = dest_prn_mul_d3;
	assign dest_prn_bcond_out = fu_alloc_dest_prn_bcond_out;


	assign link_addr_out = fu_alloc_npc_bcond_out;
	assign branch_taken_out	= fu_alloc_inst_valid_bcond_out ? fu_alloc_uncond_branch_out|(fu_alloc_cond_branch_out&brcond_result) : 0;
	assign branch_target_addr_out = branch_taken_out ?  brcond_add : 0;
	assign cond_branch_out = fu_alloc_cond_branch_out;
	assign uncond_branch_out = fu_alloc_uncond_branch_out;

	assign rob_entry_alu0_out = fu_alloc_rob_entry_alu0_out;	
	assign rob_entry_alu1_out = fu_alloc_rob_entry_alu1_out;	
	assign rob_entry_alu2_out = fu_alloc_rob_entry_alu2_out;	
	assign rob_entry_mul_out = rob_entry_mul_d3;	
	assign rob_entry_bcond_out = fu_alloc_rob_entry_bcond_out;

	assign inst_alu0_out = fu_alloc_inst_alu0_out;	
	assign inst_alu1_out = fu_alloc_inst_alu1_out;	
	assign inst_alu2_out = fu_alloc_inst_alu2_out;	
	assign inst_mul_out = inst_mul_d3;	
	assign inst_bcond_out = fu_alloc_inst_bcond_out;	

	assign pc_alu0_out = fu_alloc_pc_alu0_out;	
	assign pc_alu1_out = fu_alloc_pc_alu1_out;	
	assign pc_alu2_out = fu_alloc_pc_alu2_out;	
	assign pc_mul_out = pc_mul_d3;	
	assign pc_bcond_out = fu_alloc_pc_bcond_out;


	always@(posedge clk) begin
		if(rst) begin
			dest_prn_mem_load	<= `SD 0;	
			rob_entry_mem_load	<= `SD 0;	
			rd_mem_load			<= `SD 0;		
			wr_mem_load			<= `SD 0;		
			inst_mem_load		<= `SD 0;		
			pc_mem_load			<= `SD 0;
			addr_mem_load		<= `SD 0;	
			miss_waiting        <= `SD 0;	
		end
		else if(rd_mem_in!=0 & ~load_data_valid_in) begin	//cache miss
			dest_prn_mem_load	<= `SD fu_alloc_dest_prn_mem_out	;	
			rob_entry_mem_load	<= `SD fu_alloc_rob_entry_mem_out	;	
			rd_mem_load			<= `SD fu_alloc_rd_mem_out			;		
			wr_mem_load			<= `SD fu_alloc_wr_mem_out 			;			
			inst_mem_load		<= `SD fu_alloc_inst_mem_out		;			
			pc_mem_load			<= `SD fu_alloc_pc_mem_out			;			
			addr_mem_load		<= `SD address_mem_out				;
			miss_waiting		<= `SD 1'b1							;				
		end
		else if(load_data_valid_in)	begin						//clear load enbale once data is loaded in cache 
			miss_waiting        <= `SD 1'b0							;
		end
	end


	assign inst_valid_mem_out 		= load_data_valid_in & (rd_mem_load | rd_mem_in!=0);	 //load on cdb
	assign load_data_out 			= load_data_in;	 //load on cdb
	assign dest_prn_mem_out 		= miss_waiting ? dest_prn_mem_load	: fu_alloc_dest_prn_mem_out	;	 //load on cdb
	assign rob_entry_mem_out 		= miss_waiting ? rob_entry_mem_load	: fu_alloc_rob_entry_mem_out;	 //load on cdb
	assign rd_mem_out 				= miss_waiting ? rd_mem_load		: fu_alloc_rd_mem_out		;	 //load on cdb
	assign wr_mem_out 				= miss_waiting ? wr_mem_load		: fu_alloc_wr_mem_out 		;	 //load on cdb
	assign inst_mem_out 			= miss_waiting ? inst_mem_load		: fu_alloc_inst_mem_out		;	 //load on cdb
	assign pc_mem_out 				= miss_waiting ? pc_mem_load		: fu_alloc_pc_mem_out		;	 //load on cdb
	
	assign store_address_mem_out	= address_mem_out 				;
	assign store_data_mem_out 		= fu_alloc_op2_val_mem_out		;
	assign store_rob_out			= fu_alloc_rob_entry_mem_out	;
	assign store_en_out				= wr_mem_in!=3'b000				;

	assign load_address_mem_out		= miss_waiting ? addr_mem_load 			: address_mem_out 				; 
	assign load_size_out			= miss_waiting ? inst_mem_load[14:12] 	: fu_alloc_inst_mem_out[14:12]	;
	assign load_en_out				= miss_waiting ? 1'b1		 			: rd_mem_in!=0					;		//rd_mem_in stays deasserted until the previous load has finished

	fu_alloc fu_alloc_inst(
		.inst_valid_in					(inst_valid_in		), 
		.inst_in						(inst_in			),				// from decoder
		.pc_in							(pc_in				),				// from decoder
		.npc_in							(npc_in				),				// from decoder
		.op_type_in						(op_type_in			), 
		.op1_val_in						(op1_val_in			),
		.op2_val_in						(op2_val_in			),
		.op1_select_in					(op1_select_in		),		
		.op2_select_in					(op2_select_in		),	
		.rd_mem_in						(rd_mem_in			),			
		.wr_mem_in						(wr_mem_in			),			
		.cond_branch_in					(cond_branch_in		),	
		.uncond_branch_in				(uncond_branch_in	),	
		.halt_in						(halt_in			),			
		.illigal_in						(illigal_in			),		
		.rob_entry_in					(rob_entry_in		),		
		.dest_prn_in					(dest_prn_in		),
		.fu_type_in						(fu_type_in			), 	//  
		.imm_in							(imm_in				), 		//  

		.inst_valid_alu0_out			(fu_alloc_inst_valid_alu0_out	),    
		.op_type_alu0_out				(fu_alloc_op_type_alu0_out		), 
		.op1_val_alu0_out				(fu_alloc_op1_val_alu0_out		),
		.op2_val_alu0_out				(fu_alloc_op2_val_alu0_out		),
		.dest_prn_alu0_out				(fu_alloc_dest_prn_alu0_out		),
		.rob_entry_alu0_out				(fu_alloc_rob_entry_alu0_out	),
		.inst_alu0_out   				(fu_alloc_inst_alu0_out   		),      
        .pc_alu0_out					(fu_alloc_pc_alu0_out			),

		.inst_valid_alu1_out			(fu_alloc_inst_valid_alu1_out	),    
		.op_type_alu1_out				(fu_alloc_op_type_alu1_out		), 
		.op1_val_alu1_out				(fu_alloc_op1_val_alu1_out		),
		.op2_val_alu1_out				(fu_alloc_op2_val_alu1_out		),
		.dest_prn_alu1_out				(fu_alloc_dest_prn_alu1_out		),
		.rob_entry_alu1_out				(fu_alloc_rob_entry_alu1_out	),
  		.inst_alu1_out   				(fu_alloc_inst_alu1_out   		),      
        .pc_alu1_out					(fu_alloc_pc_alu1_out			),    

		.inst_valid_alu2_out			(fu_alloc_inst_valid_alu2_out	),    
		.op_type_alu2_out				(fu_alloc_op_type_alu2_out		), 
		.op1_val_alu2_out				(fu_alloc_op1_val_alu2_out		),
		.op2_val_alu2_out				(fu_alloc_op2_val_alu2_out		),
		.dest_prn_alu2_out				(fu_alloc_dest_prn_alu2_out		),
		.rob_entry_alu2_out				(fu_alloc_rob_entry_alu2_out	),
   		.inst_alu2_out   				(fu_alloc_inst_alu2_out   		),      
        .pc_alu2_out					(fu_alloc_pc_alu2_out			),              

		.inst_valid_mul_out				(fu_alloc_inst_valid_mul_out	),    
		.op_type_mul_out				(fu_alloc_op_type_mul_out		), 
		.op1_val_mul_out				(fu_alloc_op1_val_mul_out		),
		.op2_val_mul_out				(fu_alloc_op2_val_mul_out		),
		.dest_prn_mul_out				(fu_alloc_dest_prn_mul_out		),
		.rob_entry_mul_out				(fu_alloc_rob_entry_mul_out	),
        .inst_mul_out   				(fu_alloc_inst_mul_out   		),      
        .pc_mul_out						(fu_alloc_pc_mul_out			),      

		.inst_valid_mem_out				(fu_alloc_inst_valid_mem_out	),    
		.op_type_mem_out				(fu_alloc_op_type_mem_out		), 
		.op1_val_mem_out				(fu_alloc_op1_val_mem_out		),
		.op2_val_mem_out				(fu_alloc_op2_val_mem_out		),
		.rd_mem_out						(fu_alloc_rd_mem_out			),
		.wr_mem_out						(fu_alloc_wr_mem_out			),
		.imm_mem_out					(fu_alloc_imm_mem_out			),
		.dest_prn_mem_out				(fu_alloc_dest_prn_mem_out		),
		.rob_entry_mem_out				(fu_alloc_rob_entry_mem_out	),
   		.inst_mem_out   				(fu_alloc_inst_mem_out   		),      
        .pc_mem_out						(fu_alloc_pc_mem_out			),   

		.inst_valid_bcond_out			(fu_alloc_inst_valid_bcond_out	),    
		.op_type_bcond_out				(fu_alloc_op_type_bcond_out		), 
		.op1_val_bcond_out				(fu_alloc_op1_val_bcond_out		),
		.op2_val_bcond_out				(fu_alloc_op2_val_bcond_out		),
		.inst_bcond_out					(fu_alloc_inst_bcond_out		),
		.pc_bcond_out					(fu_alloc_pc_bcond_out			),
		.npc_bcond_out					(fu_alloc_npc_bcond_out			),
		.dest_prn_bcond_out				(fu_alloc_dest_prn_bcond_out	),
		.imm_branch_out					(fu_alloc_imm_branch_out		),
		.cond_branch_out				(fu_alloc_cond_branch_out		),	
		.uncond_branch_out				(fu_alloc_uncond_branch_out		),
		.rob_entry_bcond_out			(fu_alloc_rob_entry_bcond_out	)

);




	/*****************generate mul start pulse********************************/
	assign mult_en = fu_alloc_inst_valid_mul_out & ~fu_alloc_inst_valid_mul_out_d0;

	always@(posedge clk) begin 
		if(rst)  
			fu_alloc_inst_valid_mul_out_d0 <= `SD 1'b0;
		else 
			fu_alloc_inst_valid_mul_out_d0 <= `SD fu_alloc_inst_valid_mul_out;
	end


	/*****************generate mul ready signal********************************/
	/*
	always@(posedge clk) begin 
		if(rst)  
			mult_en_delay <= `SD 1'b0;
		else begin
			mult_en_delay[3] <= `SD mult_en;
			mult_en_delay[2] <= `SD mult_en_delay[3];
			mult_en_delay[1] <= `SD mult_en_delay[2];
			mult_en_delay[0] <= `SD mult_en_delay[1];
		end
	end

	always@(posedge clk) begin 
		if(rst)  
			mult_avail <= `SD 1'b1;
		else if(mult_en)
			mult_avail <= `SD 1'b0;
		else if(mult_en_delay[0])			//TODO
			mult_avail <= `SD 1'b1;
	end
	*/
	
	/*****************generate mul dest prn signal*****************************/
	always@(posedge clk) begin 
		if(rst)begin 
			dest_prn_mul_d0 <= `SD 0;
			dest_prn_mul_d1 <= `SD 0;
			dest_prn_mul_d2 <= `SD 0;
			dest_prn_mul_d3 <= `SD 0;

			rob_entry_mul_d0 <= `SD 0;
			rob_entry_mul_d1 <= `SD 0;
			rob_entry_mul_d2 <= `SD 0;
			rob_entry_mul_d3 <= `SD 0;

			inst_mul_d0 <= `SD 0;
			inst_mul_d1 <= `SD 0;
			inst_mul_d2 <= `SD 0;
			inst_mul_d3 <= `SD 0;	

			pc_mul_d0 <= `SD 0;
			pc_mul_d1 <= `SD 0;
			pc_mul_d2 <= `SD 0;
			pc_mul_d3 <= `SD 0;		
		end
		else begin
			dest_prn_mul_d0 <= `SD fu_alloc_dest_prn_mul_out;
			dest_prn_mul_d1 <= `SD dest_prn_mul_d0;
			dest_prn_mul_d2 <= `SD dest_prn_mul_d1;
			dest_prn_mul_d3 <= `SD dest_prn_mul_d2;

			rob_entry_mul_d0 <= `SD fu_alloc_rob_entry_mul_out;
			rob_entry_mul_d1 <= `SD rob_entry_mul_d0;
			rob_entry_mul_d2 <= `SD rob_entry_mul_d1;
			rob_entry_mul_d3 <= `SD rob_entry_mul_d2;

			inst_mul_d0 <= `SD fu_alloc_inst_mul_out;
			inst_mul_d1 <= `SD inst_mul_d0;
			inst_mul_d2 <= `SD inst_mul_d1;
			inst_mul_d3 <= `SD inst_mul_d2;	

			pc_mul_d0 <= `SD fu_alloc_pc_mul_out;
			pc_mul_d1 <= `SD pc_mul_d0;
			pc_mul_d2 <= `SD pc_mul_d1;
			pc_mul_d3 <= `SD pc_mul_d2;				
		end
	end





	fu_group fu_group_inst(
		.clock					(clk),               // system clock
		.reset					(rst),               // system reset

		// Alu module input
		.alu0_opa				(fu_alloc_op1_val_alu0_out),
		.alu0_opb				(fu_alloc_op2_val_alu0_out),
		.func_0					(fu_alloc_op_type_alu0_out),
		.alu1_opa				(fu_alloc_op1_val_alu1_out),
		.alu1_opb				(fu_alloc_op2_val_alu1_out),
		.func_1					(fu_alloc_op_type_alu1_out),
		.alu2_opa				(fu_alloc_op1_val_alu2_out),
		.alu2_opb				(fu_alloc_op2_val_alu2_out),
		.func_2					(fu_alloc_op_type_alu2_out),
		// BrCond module input
		.rs1					(fu_alloc_op1_val_bcond_out),
		.rs2					(fu_alloc_op2_val_bcond_out),
		.inst					(fu_alloc_inst_bcond_out),
		.pc_add					(fu_alloc_pc_bcond_out),
		.imm_add				(fu_alloc_imm_branch_out),
		// Mult module input
		.mcand					(fu_alloc_op1_val_mul_out),
		.mplier					(fu_alloc_op2_val_mul_out),
		.mult_en				(mult_en),
		.mult_func				(fu_alloc_op_type_mul_out),
		// Mem module input
		.op1_val_mem_in			(fu_alloc_op1_val_mem_out),
		.op2_val_mem_in			(fu_alloc_op2_val_mem_out),
		.rd_mem_in				(fu_alloc_rd_mem_out	),
		.wr_mem_in				(fu_alloc_wr_mem_out	),
		.inst_mem_in			(fu_alloc_inst_mem_out	),		
		// Alu module output 
		.alu0_result			(result_alu0_out),
		.alu1_result			(result_alu1_out),
		.alu2_result			(result_alu2_out),

		// BrCond module output
		.brcond_result			(brcond_result	),
		.brcond_add				(brcond_add		),

		// Mult module output
		.mult_result			(result_mul_out),
		.mult_done				(inst_valid_mul_out	),

		// Mem module output
		.address_out			(address_mem_out		)
	);






endmodule
//`default_nettype wire

