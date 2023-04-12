//potential issue(SOLVED with solution1): lack of retire_prn_prev to free_prn bypassing
//solution 1: forwarding the retire prn
//solution 2: add 4 dummy prn to prf(96+4)
//also adopt solution2 to solve the one cycle rob retire to freelist update delay (rob retired instrs and turnd from full to ready to accept but freelist is still waiting for retired prn)
`timescale 1ns/100ps

module free_list(
	input clk,
	input rst_n,

	input 	[`PRF_WIDTH-1:0] 		retire_prn_prev			[0:`MACHINE_WIDTH-1],
	input 	[`MACHINE_WIDTH-1:0]	retire_prn_prev_valid,	
	output  [`MACHINE_WIDTH-1:0]    retire_prn_prev_ready,	

	output 	[`PRF_WIDTH-1:0] 		free_prn				[0:`MACHINE_WIDTH-1],
	output 	[`MACHINE_WIDTH-1:0]	free_prn_valid,		
	input	[`MACHINE_WIDTH-1:0]	free_prn_ready,

	input		[`PRF_WIDTH-1:0]	arch_rat				[0:`ARF_DEPTH-1],
	input							recov_arch_st	
);


	reg		[`PRF_DEPTH-1:0]				free_list;
	wire	[`PRF_DEPTH*`MACHINE_WIDTH-1:0]	gnt_bus;
	wire	[`PRF_DEPTH-1:0]				free_prn_oh_N	[0:`MACHINE_WIDTH-1];
	wire	[`PRF_DEPTH-1:0]				free_list_retire_fwd; 


	psel_gen #(
		.REQS(`MACHINE_WIDTH),
		.WIDTH(`PRF_DEPTH)) 
	u_psel_gen_free_prn(			//select 4 free entries  	
		.req(free_list_retire_fwd),
		.gnt(), 
		.gnt_bus(gnt_bus),			
		.empty()
	);




	genvar i;
	generate
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			assign free_prn_oh_N[i] = gnt_bus[i*`PRF_DEPTH+:`PRF_DEPTH];
			assign free_prn_valid[i] = free_prn_oh_N[i] != 0;
			assign retire_prn_prev_ready[i] = 1;
		   		
			onehot_enc #(
				.WIDTH(`PRF_DEPTH)) 
			u_onehot_enc_free_list(
				.in(free_prn_oh_N[i]),
				.out(free_prn[i])								
			);
		end
		


		for(i=0;i<`PRF_DEPTH;i=i+1) begin
			assign free_list_retire_fwd[i] = free_list[i] 												 || 
											 (retire_prn_prev_valid[0] && i==retire_prn_prev[0] && i!=0) ||
											 (retire_prn_prev_valid[1] && i==retire_prn_prev[1] && i!=0) ||
											 (retire_prn_prev_valid[2] && i==retire_prn_prev[2] && i!=0) ||
											 (retire_prn_prev_valid[3] && i==retire_prn_prev[3] && i!=0) ;
		end
		
		
		
		for(i=0;i<`PRF_DEPTH;i=i+1) begin
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					free_list[i] <= i!=0;	//set zero reg always free (1=free, 0=busy)
				else if(recov_arch_st) begin
					if(	i==arch_rat[0] 	|| i==arch_rat[1]  || i==arch_rat[2]  || i==arch_rat[3]  ||
						i==arch_rat[4] 	|| i==arch_rat[5]  || i==arch_rat[6]  || i==arch_rat[7]  ||					
						i==arch_rat[8] 	|| i==arch_rat[9]  || i==arch_rat[10] || i==arch_rat[11] ||					
						i==arch_rat[12] || i==arch_rat[13] || i==arch_rat[14] || i==arch_rat[15] ||					
						i==arch_rat[16] || i==arch_rat[17] || i==arch_rat[18] || i==arch_rat[19] ||					
						i==arch_rat[20] || i==arch_rat[21] || i==arch_rat[22] || i==arch_rat[23] ||					
						i==arch_rat[24] || i==arch_rat[25] || i==arch_rat[26] || i==arch_rat[27] ||					
						i==arch_rat[28] || i==arch_rat[29] || i==arch_rat[30] || i==arch_rat[31] )					
						free_list[i] <= 0;
					else
						free_list[i] <= 1;
				end
				else begin 
					//recycle used prn
					if(retire_prn_prev_valid[0] && i==retire_prn_prev[0] && i!=0)
						free_list[i] <= 1;
					if(retire_prn_prev_valid[1] && i==retire_prn_prev[1] && i!=0)
						free_list[i] <= 1;
					if(retire_prn_prev_valid[2] && i==retire_prn_prev[2] && i!=0)
						free_list[i] <= 1;						
					if(retire_prn_prev_valid[3] && i==retire_prn_prev[3] && i!=0)
						free_list[i] <= 1;
					//set the chosen prn to 1
					if(free_prn_oh_N[0][i] && free_prn_ready[0])
						free_list[i] <= 0;		
					if(free_prn_oh_N[1][i] && free_prn_ready[1])
						free_list[i] <= 0;		
					if(free_prn_oh_N[2][i] && free_prn_ready[2])
						free_list[i] <= 0;		
					if(free_prn_oh_N[3][i] && free_prn_ready[3])
						free_list[i] <= 0;		
				end
			end
		end


	endgenerate




endmodule
