`timescale 1ns/100ps

module arch_rat(
	input 								clk,
	input 								rst_n,
	
	input		[`ARF_WIDTH-1:0]		retire_dest_arn	[0:`MACHINE_WIDTH-1],
	input		[`PRF_WIDTH-1:0]		retire_dest_prn	[0:`MACHINE_WIDTH-1],
	input		[`MACHINE_WIDTH-1:0]	retire_valid,
	
	output		[`PRF_WIDTH-1:0]		arch_rat_out	[0:`ARF_DEPTH-1]
);

	reg [`PRF_WIDTH-1:0] arch_rat	[0:`ARF_DEPTH-1];

			
	genvar i;
	generate
		for(i=0;i<`ARF_DEPTH;i=i+1) begin
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					arch_rat[i] <= 0;
				else begin
					if(retire_valid[0] && i==retire_dest_arn[0] && i!=0)
						arch_rat[i] <= retire_dest_prn[0];
					if(retire_valid[1] && i==retire_dest_arn[1] && i!=0)
						arch_rat[i] <= retire_dest_prn[1];
					if(retire_valid[2] && i==retire_dest_arn[2] && i!=0)
						arch_rat[i] <= retire_dest_prn[2];
					if(retire_valid[3] && i==retire_dest_arn[3] && i!=0)
						arch_rat[i] <= retire_dest_prn[3];
				end
			end
			
			//assign arch_rat_out[i] = 	retire_valid[0] && i==retire_dest_arn[0] && i!=0 ? retire_dest_prn[0] :
			//							retire_valid[1] && i==retire_dest_arn[1] && i!=0 ? retire_dest_prn[1] :
			//							retire_valid[2] && i==retire_dest_arn[2] && i!=0 ? retire_dest_prn[2] :
			//							retire_valid[3] && i==retire_dest_arn[3] && i!=0 ? retire_dest_prn[3] :
			//							arch_rat[i];
			assign arch_rat_out[i] = arch_rat[i];
		end

	endgenerate




endmodule
