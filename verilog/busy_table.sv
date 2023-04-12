//TODO write assertion: free prn must not be the same as execute prn
`timescale 1ns/100ps


module busy_table(
	input 							clk,
	input 							rst_n,
	input 							pipe_flush,

	//set the busy bit when the corresponding register leaves the free list
	input 	[`PRF_WIDTH-1:0] 		free_prn			[0:`MACHINE_WIDTH-1],
	input 	[`MACHINE_WIDTH-1:0]	free_prn_valid,	
	input 	[`MACHINE_WIDTH-1:0]	free_prn_ready,	

	//resets the bit when an execution unit writes a value into this register.
	input 	[`PRF_WIDTH-1:0] 		execute_prn			[0:`ISSUE_WIDTH-1],
	input 	[`ISSUE_WIDTH-1:0]		execute_valid,	

	input 	[`PRF_WIDTH-1:0] 		pr_src1				[0:`MACHINE_WIDTH-1],
	input 	[`PRF_WIDTH-1:0] 		pr_src2				[0:`MACHINE_WIDTH-1],
	output 	[`MACHINE_WIDTH-1:0]	pr_src1_data_ready,	
	output 	[`MACHINE_WIDTH-1:0]	pr_src2_data_ready	
);


	reg		[`PRF_DEPTH-1:0]		busy_table;
	wire	[`MACHINE_WIDTH-1:0]	pr_src1_data_ready_fwd;
	wire	[`MACHINE_WIDTH-1:0]	pr_src2_data_ready_fwd;



	/***********************intra-group dependency check******************************/
	assign pr_src1_data_ready[3] = 	(busy_table[pr_src1[3]] != 1'b1 || pr_src1_data_ready_fwd[3]) 			&&
									~(free_prn_valid[0] && free_prn_ready[0] && free_prn[0]==pr_src1[3])	&&
									~(free_prn_valid[1] && free_prn_ready[1] && free_prn[1]==pr_src1[3])	&&
									~(free_prn_valid[2] && free_prn_ready[2] && free_prn[2]==pr_src1[3])	;

	assign pr_src1_data_ready[2] = 	(busy_table[pr_src1[2]] != 1'b1 || pr_src1_data_ready_fwd[2]) 			&&
									~(free_prn_valid[0] && free_prn_ready[0] && free_prn[0]==pr_src1[2])	&&
									~(free_prn_valid[1] && free_prn_ready[1] && free_prn[1]==pr_src1[2])	;

	assign pr_src1_data_ready[1] = 	(busy_table[pr_src1[1]] != 1'b1 || pr_src1_data_ready_fwd[1]) 			&&
									~(free_prn_valid[0] && free_prn_ready[0] && free_prn[0]==pr_src1[1])	;

	assign pr_src1_data_ready[0] = 	(busy_table[pr_src1[0]] != 1'b1 || pr_src1_data_ready_fwd[0])			;



	assign pr_src2_data_ready[3] = 	(busy_table[pr_src2[3]] != 1'b1 || pr_src2_data_ready_fwd[3]) 			&&
									~(free_prn_valid[0] && free_prn_ready[0] && free_prn[0]==pr_src2[3])	&&
									~(free_prn_valid[1] && free_prn_ready[1] && free_prn[1]==pr_src2[3])	&&
									~(free_prn_valid[2] && free_prn_ready[2] && free_prn[2]==pr_src2[3])	;

	assign pr_src2_data_ready[2] = 	(busy_table[pr_src2[2]] != 1'b1 || pr_src2_data_ready_fwd[2]) 			&&
									~(free_prn_valid[0] && free_prn_ready[0] && free_prn[0]==pr_src2[2])	&&
									~(free_prn_valid[1] && free_prn_ready[1] && free_prn[1]==pr_src2[2])	;

	assign pr_src2_data_ready[1] = 	(busy_table[pr_src2[1]] != 1'b1 || pr_src2_data_ready_fwd[1]) 			&&
									~(free_prn_valid[0] && free_prn_ready[0] && free_prn[0]==pr_src2[1])	;

	assign pr_src2_data_ready[0] = 	(busy_table[pr_src2[0]] != 1'b1 || pr_src2_data_ready_fwd[0])			;




	genvar i;
	generate
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign pr_src1_data_ready_fwd[i] =	pr_src1[i] == execute_prn[0] && execute_valid[0] ||
												pr_src1[i] == execute_prn[1] && execute_valid[1] ||
												pr_src1[i] == execute_prn[2] && execute_valid[2] ||
												pr_src1[i] == execute_prn[3] && execute_valid[3] ||
												pr_src1[i] == execute_prn[4] && execute_valid[4] ||
												pr_src1[i] == execute_prn[5] && execute_valid[5] ||
												pr_src1[i] == execute_prn[6] && execute_valid[6] ;
			assign pr_src2_data_ready_fwd[i] =	pr_src2[i] == execute_prn[0] && execute_valid[0] ||
												pr_src2[i] == execute_prn[1] && execute_valid[1] ||
												pr_src2[i] == execute_prn[2] && execute_valid[2] ||
												pr_src2[i] == execute_prn[3] && execute_valid[3] ||
												pr_src2[i] == execute_prn[4] && execute_valid[4] ||
												pr_src2[i] == execute_prn[5] && execute_valid[5] ||
												pr_src2[i] == execute_prn[6] && execute_valid[6] ;

			//assign pr_src1_data_ready[i] = busy_table[pr_src1[i]] != 1'b1 || pr_src1_data_ready_fwd[i];
			//assign pr_src2_data_ready[i] = busy_table[pr_src2[i]] != 1'b1 || pr_src2_data_ready_fwd[i];
		end

		for(i=0;i<`PRF_DEPTH;i=i+1) begin
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) 
					busy_table[i] <= 0;
				else if(pipe_flush)
					busy_table[i] <= 0;
				else begin
					if(free_prn_valid[0] && free_prn_ready[0] && i==free_prn[0])
						busy_table[i] <= 1'b1;
					if(free_prn_valid[1] && free_prn_ready[1] && i==free_prn[1])
						busy_table[i] <= 1'b1;
					if(free_prn_valid[2] && free_prn_ready[2] && i==free_prn[2])
						busy_table[i] <= 1'b1;
					if(free_prn_valid[3] && free_prn_ready[3] && i==free_prn[3])
						busy_table[i] <= 1'b1;
					
					if(execute_valid[0] && i==execute_prn[0])
						busy_table[i] <= 1'b0;				
					if(execute_valid[1] && i==execute_prn[1])
						busy_table[i] <= 1'b0;		
					if(execute_valid[2] && i==execute_prn[2])
						busy_table[i] <= 1'b0;		
					if(execute_valid[3] && i==execute_prn[3])
						busy_table[i] <= 1'b0;
					if(execute_valid[4] && i==execute_prn[4])
						busy_table[i] <= 1'b0;		
					if(execute_valid[5] && i==execute_prn[5])
						busy_table[i] <= 1'b0;		
					if(execute_valid[6] && i==execute_prn[6])
						busy_table[i] <= 1'b0;
				end
			end
		end
		
	endgenerate



endmodule
