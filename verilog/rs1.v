`timescale 1ns/100ps
				
module rs1(
	input        					clk,          	// the clock 							
	input        					rst,          	// reset signal			
	input							rs1_use_en,		//send signal to FU
	input			        		rs1_load,		// load inst into RS
	input [31:0]	        		inst_in,		// 
	input [31:0]	        		pc_in,			// 
	input [31:0]		        	npc_in,			// 
	input [4:0] 					op_type_in,		// from decoder
	input [`PRF_WIDTH-1:0] 			op1_prn_in,     // from rat 
	input [`PRF_WIDTH-1:0] 			op2_prn_in,     // from rat
	input 							op1_ready_in,	// from PRF valid bit 
	input 							op2_ready_in,	// from PRF valid bit 
	input 							use_op1_prn_in,	//  
	input 							use_op2_prn_in,	//  
	input [`PRF_WIDTH-1:0] 			dest_prn_in,    // from decoder
	input [1:0]						op1_select_in,
	input [3:0]						op2_select_in,
	input 							rd_mem_in,
	input 							wr_mem_in,
	input							cond_branch_in,
	input							uncond_branch_in,
	input							halt_in,
	input							illigal_in,
	input [`ROB_WIDTH-1:0]  		rob_entry_in,	// from the tail of rob
	input [3:0]				  		fu_type_in,		// from decoder, does this inst use alu, mul, mem or bcond?
	input [`IMM_WIDTH-1:0]  		imm_in,			// from decoder, imm value
	input [`ROB_SIZE-1:0]  			load_ready_in,			
	input [`N_WAY-1:0]				cdb_valid,
	input [`PRF_WIDTH*`N_WAY-1:0]	cdb_tag,

	output reg     	 				rs1_wake_up_alu,   	// This RS is in use, stores alu inst, and ready to go to EX 
	output reg     	 				rs1_wake_up_mul,   	// This RS is in use, stores mul inst, and ready to go to EX 
	output reg     	 				rs1_wake_up_mem,   	// This RS is in use, stores mem inst, and ready to go to EX 
	output reg     	 				rs1_wake_up_bcond,  // This RS is in use, stores bcond inst, and ready to go to EX 
	output       	 				rs1_avail,     		// This RS is available to be dispatched to 
	output [31:0]					rs1_inst_out,   	// feed to fu
	output [31:0]					rs1_pc_out,    		// feed to fu
	output [31:0]					rs1_npc_out,    	// feed to fu
	output [4:0]					rs1_op_type_out,    // feed to fu
	output [`PRF_WIDTH-1:0] 		rs1_op1_prn_out,   	// feed to PRF 
	output [`PRF_WIDTH-1:0] 		rs1_op2_prn_out,   	// feed to PRF
	output [`PRF_WIDTH-1:0] 		rs1_dest_prn_out,   // feed to PRF 
	output [1:0]					rs1_op1_select_out,		
	output [3:0]					rs1_op2_select_out,		
	output 							rs1_rd_mem_out,			
	output 							rs1_wr_mem_out,			
	output							rs1_cond_branch_out,	
	output							rs1_uncond_branch_out,	
	output							rs1_halt_out,			
	output							rs1_illigal_out,		
	output [`ROB_WIDTH-1:0]		    rs1_rob_entry_out,	// feed to ROB
	output [3:0]				  	rs1_fu_type_out,	// feed to fu, does this inst use alu, mul, mem or bcond?
	output [`IMM_WIDTH-1:0]  		rs1_imm_out			// feed to fu, imm value
);

	reg [31:0]	        	inst;
	reg [31:0]	        	pc;
	reg [31:0]	        	npc;
	reg	[4:0] 				op_type;           
	reg [`PRF_WIDTH-1:0] 	op1_prn;       	// the physical register number the opa is pointed to
	reg [`PRF_WIDTH-1:0] 	op2_prn;       	// the physical register number the opb is pointed to 
	reg       				op1_ready;    	// Operand a Value is now ready in prf
	reg       				op2_ready;     	// Operand b Value is now ready in prf
	reg						use_op1_prn;
	reg						use_op2_prn;
	reg	[1:0]				op1_select;		
	reg	[3:0]				op2_select;		
	reg						rd_mem;			
	reg						wr_mem;			
	reg						cond_branch;	
	reg						uncond_branch;	
	reg						halt;			
	reg						illigal;		
	reg       				in_use;        	// InUse bit 
	reg [`PRF_WIDTH-1:0] 	dest_prn;		// Destination physical register number 
	reg [`ROB_WIDTH-1:0]	rob_entry;		// ROB entry #
	reg [3:0]				fu_type;		// does this inst use alu, mul, mem or bcond?
	reg [`IMM_WIDTH-1:0]  	imm;			// imm value

	reg						wake_up_alu_tmp_d0; //wake_up_tmp delay by one cycle
	reg						wake_up_mul_tmp_d0; //wake_up_tmp delay by one cycle
	reg						wake_up_mem_tmp_d0; //wake_up_tmp delay by one cycle
	reg						wake_up_bcond_tmp_d0; //wake_up_tmp delay by one cycle

 	wire loadAfromPRF;			
 	wire loadBfromPRF;		
	wire op1_ready_fwd;
	wire op2_ready_fwd;
	wire rs1_free;
	wire wake_up_alu_tmp;
	wire wake_up_mul_tmp;
	wire wake_up_mem_tmp;
	wire wake_up_bcond_tmp;
	wire wake_up_alu_posedge;
	wire wake_up_mul_posedge;
	wire wake_up_mem_posedge;
	wire wake_up_bcond_posedge;

	assign wake_up_alu_tmp			= in_use & (op1_ready | ~use_op1_prn) & (op2_ready | ~use_op2_prn) & fu_type[0]; 
	assign wake_up_mul_tmp			= in_use & (op1_ready | ~use_op1_prn) & (op2_ready | ~use_op2_prn) & fu_type[1]; 
	assign wake_up_mem_tmp			= in_use & (op1_ready | ~use_op1_prn) & (op2_ready | ~use_op2_prn) & fu_type[2] & (load_ready_in[rob_entry] | wr_mem); 
	assign wake_up_bcond_tmp		= in_use & (op1_ready | ~use_op1_prn) & (op2_ready | ~use_op2_prn) & fu_type[3]; 
	assign rs1_avail				= ~in_use;
	assign rs1_inst_out 			= rs1_use_en ? inst : 32'b0;
	assign rs1_pc_out 				= rs1_use_en ? pc : 32'b0;
	assign rs1_npc_out 				= rs1_use_en ? npc : 32'b0;
	assign rs1_op_type_out 			= rs1_use_en ? op_type : 5'b0;
	assign rs1_op1_prn_out 			= rs1_use_en ? op1_prn : {`PRF_WIDTH{1'b0}};
	assign rs1_op2_prn_out 			= rs1_use_en ? op2_prn : {`PRF_WIDTH{1'b0}};
	assign rs1_dest_prn_out 		= rs1_use_en ? dest_prn : {`PRF_WIDTH{1'b0}};
	assign rs1_op1_select_out		= rs1_use_en ? op1_select : 0;			
	assign rs1_op2_select_out		= rs1_use_en ? op2_select : 0;		
	assign rs1_rd_mem_out			= rs1_use_en ? rd_mem : 0;			
	assign rs1_wr_mem_out			= rs1_use_en ? wr_mem : 0;			
	assign rs1_cond_branch_out		= rs1_use_en ? cond_branch : 0;	
	assign rs1_uncond_branch_out	= rs1_use_en ? uncond_branch : 0;	
	assign rs1_halt_out				= rs1_use_en ? halt : 0;			
	assign rs1_illigal_out			= rs1_use_en ? illigal : 0;		
	assign rs1_rob_entry_out 		= rs1_use_en ? rob_entry : {`ROB_WIDTH{1'b0}};
	assign rs1_fu_type_out			= rs1_use_en ? fu_type : 4'b0;
	assign rs1_imm_out 				= rs1_use_en ? imm : {`IMM_WIDTH{1'b0}};

 	assign loadAfromPRF = ((cdb_tag[`PRF_WIDTH*0+:`PRF_WIDTH] == op1_prn) & cdb_valid[0]) |
						  ((cdb_tag[`PRF_WIDTH*1+:`PRF_WIDTH] == op1_prn) & cdb_valid[1]) |
						  ((cdb_tag[`PRF_WIDTH*2+:`PRF_WIDTH] == op1_prn) & cdb_valid[2]) & !op1_ready & use_op1_prn & in_use;
 	assign loadBfromPRF = ((cdb_tag[`PRF_WIDTH*0+:`PRF_WIDTH] == op2_prn) & cdb_valid[0]) |
						  ((cdb_tag[`PRF_WIDTH*1+:`PRF_WIDTH] == op2_prn) & cdb_valid[1]) |
						  ((cdb_tag[`PRF_WIDTH*2+:`PRF_WIDTH] == op2_prn) & cdb_valid[2]) & !op2_ready & use_op2_prn & in_use;

	assign op1_ready_fwd = ((cdb_tag[`PRF_WIDTH*0+:`PRF_WIDTH] == op1_prn_in) & cdb_valid[0]) |
						   ((cdb_tag[`PRF_WIDTH*1+:`PRF_WIDTH] == op1_prn_in) & cdb_valid[1]) |
						   ((cdb_tag[`PRF_WIDTH*2+:`PRF_WIDTH] == op1_prn_in) & cdb_valid[2]) & !op1_ready_in & use_op1_prn_in & ~in_use;

	assign op2_ready_fwd = ((cdb_tag[`PRF_WIDTH*0+:`PRF_WIDTH] == op2_prn_in) & cdb_valid[0]) |
						   ((cdb_tag[`PRF_WIDTH*1+:`PRF_WIDTH] == op2_prn_in) & cdb_valid[1]) |
						   ((cdb_tag[`PRF_WIDTH*2+:`PRF_WIDTH] == op2_prn_in) & cdb_valid[2]) & !op2_ready_in & use_op2_prn_in & ~in_use;
					   	   
	assign rs1_free = 	  ((cdb_tag[`PRF_WIDTH*0+:`PRF_WIDTH] == dest_prn) & cdb_valid[0]) & dest_prn!=0 |  //free signal must be generated from cdb, not the change of prf valid bit 
						  ((cdb_tag[`PRF_WIDTH*1+:`PRF_WIDTH] == dest_prn) & cdb_valid[1]) & dest_prn!=0 |
						  ((cdb_tag[`PRF_WIDTH*2+:`PRF_WIDTH] == dest_prn) & cdb_valid[2]) & dest_prn!=0 |
						   (rs1_use_en & (cond_branch | wr_mem | inst == `NOP));
 


	/*****************generate wake_up_posedge********************************/
	assign wake_up_alu_posedge 		= wake_up_alu_tmp & ~wake_up_alu_tmp_d0;
	assign wake_up_mul_posedge 		= wake_up_mul_tmp & ~wake_up_mul_tmp_d0;
	assign wake_up_mem_posedge 		= wake_up_mem_tmp & ~wake_up_mem_tmp_d0;
	assign wake_up_bcond_posedge 	= wake_up_bcond_tmp & ~wake_up_bcond_tmp_d0;

	always@(posedge clk) begin 
		if(rst) begin 
			wake_up_alu_tmp_d0 <= 1'b0;
			wake_up_mul_tmp_d0 <= 1'b0;
			wake_up_mem_tmp_d0 <= 1'b0;
			wake_up_bcond_tmp_d0 <= 1'b0;
		end
		else begin
			wake_up_alu_tmp_d0 <= wake_up_alu_tmp;
			wake_up_mul_tmp_d0 <= wake_up_mul_tmp;
			wake_up_mem_tmp_d0 <= wake_up_mem_tmp;
			wake_up_bcond_tmp_d0 <= wake_up_bcond_tmp;
		end
	end
	/*****************generate wake_up_posedge********************************/



	always@(posedge clk) begin //deassert wake up once it has been sent to FU, avoid double selection
    	if(rst) begin 
			rs1_wake_up_alu <= `SD 1'b0;
			rs1_wake_up_mul <= `SD 1'b0;
			rs1_wake_up_mem <= `SD 1'b0;
			rs1_wake_up_bcond <= `SD 1'b0;
		end
		else begin
			if(wake_up_alu_posedge | wake_up_mul_posedge | wake_up_mem_posedge | wake_up_bcond_posedge) begin
				rs1_wake_up_alu <= `SD wake_up_alu_posedge;
				rs1_wake_up_mul <= `SD wake_up_mul_posedge;
				rs1_wake_up_mem <= `SD wake_up_mem_posedge;
				rs1_wake_up_bcond <= `SD wake_up_bcond_posedge;
			end
			else if(rs1_use_en) begin
				rs1_wake_up_alu <= `SD 1'b0;
				rs1_wake_up_mul <= `SD 1'b0;
				rs1_wake_up_mem <= `SD 1'b0;
				rs1_wake_up_bcond <= `SD 1'b0;
			end
		end
	end

	always@(posedge clk) begin 
    	if(rst) begin
	   		inst <= `SD 0;	
	   		pc <= `SD 0;	
	   		npc <= `SD 0;	
            op_type <= `SD 0;
            op1_prn <= `SD 0;             
            op2_prn <= `SD 0; 
            op1_ready <= `SD 0; 
            op2_ready <= `SD 0;
    		use_op1_prn <= `SD 0;
            use_op2_prn <= `SD 0;
            in_use <= `SD 1'b0; 
            dest_prn <= `SD 0; 
            rob_entry <= `SD 0;
			fu_type <= `SD 0;
			imm <= `SD 0;
			op1_select <= `SD 0;		
            op2_select <= `SD 0;		
            rd_mem <= `SD 0;			
            wr_mem <= `SD 0;			
            cond_branch <= `SD 0;	
            uncond_branch <= `SD 0;	
            halt <= `SD 0;			
            illigal <= `SD 0;		
    	end 
		else begin
			if(rs1_load) begin       // load the inst into rs
	   			inst <= `SD inst_in;	
	   			pc <= `SD pc_in;	
	   			npc <= `SD npc_in;			
            	op_type <= `SD op_type_in; 
           		op1_prn <= `SD op1_prn_in; 
           		op2_prn <= `SD op2_prn_in; 
           		op1_ready <= `SD op1_ready_in | op1_ready_fwd; 
           		op2_ready <= `SD op2_ready_in | op2_ready_fwd; 
				use_op1_prn <= `SD use_op1_prn_in; 
                use_op2_prn <= `SD use_op2_prn_in; 
           		in_use <= `SD 1'b1; 
           		dest_prn <= `SD dest_prn_in; 
           		rob_entry <= `SD rob_entry_in;
				fu_type <= `SD fu_type_in;
				imm <= `SD imm_in;
				op1_select <= `SD op1_select_in;		 
                op2_select <= `SD op2_select_in;		
                rd_mem <= `SD rd_mem_in;			
                wr_mem <= `SD wr_mem_in;			
                cond_branch <= `SD cond_branch_in;	
                uncond_branch <= `SD uncond_branch_in;	
                halt <= `SD halt_in;			
                illigal <= `SD illigal_in;		
      		end 
			else begin 
				if(loadAfromPRF)  
					op1_ready  <= `SD 1'b1;
				if(loadBfromPRF)  
					op2_ready <= `SD 1'b1;
			end

			if(rs1_free)
	           		in_use <= `SD 1'b0; 
		end					
	end

		
endmodule 

