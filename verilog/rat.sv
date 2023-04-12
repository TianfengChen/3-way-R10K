`timescale 1ns/100ps

module rat(
	input clk,
	input rst_n,

	input 		[`ARF_WIDTH-1:0] 		ar_src1			[0:`MACHINE_WIDTH-1],
	input 		[`ARF_WIDTH-1:0] 		ar_src2			[0:`MACHINE_WIDTH-1],
	input 		[`ARF_WIDTH-1:0] 		ar_dest			[0:`MACHINE_WIDTH-1],
	input 		[`MACHINE_WIDTH-1:0]	ar_src1_sel,	//does this inst use src1
	input 		[`MACHINE_WIDTH-1:0]	ar_src2_sel,	//does this inst use src2
	input 		DEST_REG_SEL	 		ar_dest_sel		[0:`MACHINE_WIDTH-1],	//does this inst has dest reg
	input 		[`MACHINE_WIDTH-1:0]	ar_valid,	
	output  	[`MACHINE_WIDTH-1:0]    ar_ready,	

	output 		[`PRF_WIDTH-1:0] 		pr_src1			[0:`MACHINE_WIDTH-1],
	output 		[`PRF_WIDTH-1:0] 		pr_src2			[0:`MACHINE_WIDTH-1],
	output 		[`PRF_WIDTH-1:0] 		pr_dest			[0:`MACHINE_WIDTH-1],
	output 		[`PRF_WIDTH-1:0] 		pr_dest_prev	[0:`MACHINE_WIDTH-1],
	output 		[`MACHINE_WIDTH-1:0]	pr_valid,										
	input		[`MACHINE_WIDTH-1:0]	pr_ready,

	input 		[`PRF_WIDTH-1:0] 		free_prn		[0:`MACHINE_WIDTH-1],
	input 		[`MACHINE_WIDTH-1:0]	free_prn_valid						,		
	output		[`MACHINE_WIDTH-1:0]	free_prn_ready						,

	input		[`PRF_WIDTH-1:0]		arch_rat		[0:`ARF_DEPTH-1]	,
	input								recov_arch_st
);


	reg		[`PRF_WIDTH-1:0]		rat					[0:`ARF_DEPTH-1]	;

	reg		[`PRF_WIDTH-1:0] 		next_pr_src1		[0:`MACHINE_WIDTH-1];
	reg		[`PRF_WIDTH-1:0] 		next_pr_src2		[0:`MACHINE_WIDTH-1];
	wire	[`PRF_WIDTH-1:0] 		next_pr_dest		[0:`MACHINE_WIDTH-1];
	reg		[`PRF_WIDTH-1:0] 		next_pr_dest_prev	[0:`MACHINE_WIDTH-1];
	wire	[`MACHINE_WIDTH-1:0]	next_pr_valid							;							
	
	
				




	genvar i;
	generate
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin
			//TODO sel can be removed
			assign next_pr_dest[i] 		= ar_dest_sel[i]==DEST_RD && ar_dest[i]!=`ZERO_REG ? free_prn[i] : 0;
			assign next_pr_valid[i] 	= ar_valid[i]; //accept a free entry

			assign pr_src1[i] 			= next_pr_src1[i]		;
			assign pr_src2[i] 			= next_pr_src2[i] 		;
			assign pr_dest[i] 			= next_pr_dest[i] 		;
			assign pr_dest_prev[i] 		= next_pr_dest_prev[i]  ;
			assign pr_valid[i] 			= next_pr_valid[i] 	 	;

			//always@(posedge clk or negedge rst_n) begin
			//	if(~rst_n) begin
			//		pr_src1[i] 		<= 0;
			//		pr_src2[i] 		<= 0;
			//		pr_dest[i] 		<= 0;
			//		pr_dest_prev[i] <= 0;
			//		pr_valid[i] 	<= 0;
			//	end
			//	else begin
			//		pr_src1[i] 		<= next_pr_src1[i]		 ;
			//		pr_src2[i] 		<= next_pr_src2[i] 		 ;
			//		pr_dest[i] 		<= next_pr_dest[i] 		 ;
			//		pr_dest_prev[i] <= next_pr_dest_prev[i]  ;
			//		pr_valid[i] 	<= next_pr_valid[i] 	 ;
			//	end
			//end

			//ready when an inst is accepted and this inst has a dest reg and the dest reg is not x0
			assign free_prn_ready[i] = ar_dest_sel[i]==DEST_RD & ar_dest[i]!=`ZERO_REG & ar_valid[i] & ar_ready==4'b1111;//TODO 
			assign ar_ready[i] = pr_ready[i];
			

		end

		for(i=0;i<`ARF_DEPTH;i=i+1) begin	
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) 
					rat[i] <= 0;
				else if(recov_arch_st)
					rat[i] <= arch_rat[i];
				else begin 
					//for WAW, write down the latest ar-pr maping
					//ar_dest[0] --> ar_dest[3], oldest --> latest 
					if(free_prn_valid[0] & free_prn_ready[0] & i==ar_dest[0]) //accept a free entry
						rat[i] <= free_prn[0];
					if(free_prn_valid[1] & free_prn_ready[1] & i==ar_dest[1]) //accept a free entry
						rat[i] <= free_prn[1];
					if(free_prn_valid[2] & free_prn_ready[2] & i==ar_dest[2]) //accept a free entry
						rat[i] <= free_prn[2];
					if(free_prn_valid[3] & free_prn_ready[3] & i==ar_dest[3]) //accept a free entry
						rat[i] <= free_prn[3];
				end
			end

		end
	
	endgenerate


	//zero ar must be mapped to zero pr
	assert property (@(posedge clk) rst_n==1 |-> rat[0] == 0);

	
	
	/***********************intra-group dependency check******************************/
	always@(*) begin
		if(ar_src1_sel[3]==1 && ar_dest_sel[2]==DEST_RD && ar_src1[3]==ar_dest[2])
			next_pr_src1[3] = next_pr_dest[2];
		else if(ar_src1_sel[3]==1 && ar_dest_sel[1]==DEST_RD && ar_src1[3]==ar_dest[1])
			next_pr_src1[3] = next_pr_dest[1];
		else if(ar_src1_sel[3]==1 && ar_dest_sel[0]==DEST_RD && ar_src1[3]==ar_dest[0])
			next_pr_src1[3] = next_pr_dest[0];
		else
			next_pr_src1[3] = ar_src1_sel[3] ? rat[ar_src1[3]] : 0;
	end

	always@(*) begin
		if(ar_src1_sel[2]==1 && ar_dest_sel[1]==DEST_RD && ar_src1[2]==ar_dest[1])
			next_pr_src1[2] = next_pr_dest[1];
		else if(ar_src1_sel[2]==1 && ar_dest_sel[0]==DEST_RD && ar_src1[2]==ar_dest[0])
			next_pr_src1[2] = next_pr_dest[0];
		else
			next_pr_src1[2] = ar_src1_sel[2] ? rat[ar_src1[2]] : 0;
	end

	always@(*) begin
		if(ar_src1_sel[1]==1 && ar_dest_sel[0]==DEST_RD && ar_src1[1]==ar_dest[0])
			next_pr_src1[1] = next_pr_dest[0];
		else
			next_pr_src1[1] = ar_src1_sel[1] ? rat[ar_src1[1]] : 0;
	end

	always@(*) begin
		next_pr_src1[0] = ar_src1_sel[0] ? rat[ar_src1[0]] : 0;
	end




	always@(*) begin
		if(ar_src2_sel[3]==1 && ar_dest_sel[2]==DEST_RD && ar_src2[3]==ar_dest[2])
			next_pr_src2[3] = next_pr_dest[2];
		else if(ar_src2_sel[3]==1 && ar_dest_sel[1]==DEST_RD && ar_src2[3]==ar_dest[1])
			next_pr_src2[3] = next_pr_dest[1];
		else if(ar_src2_sel[3]==1 && ar_dest_sel[0]==DEST_RD && ar_src2[3]==ar_dest[0])
			next_pr_src2[3] = next_pr_dest[0];
		else
			next_pr_src2[3] = ar_src2_sel[3] ? rat[ar_src2[3]] : 0;
	end

	always@(*) begin
		if(ar_src2_sel[2]==1 && ar_dest_sel[1]==DEST_RD && ar_src2[2]==ar_dest[1])
			next_pr_src2[2] = next_pr_dest[1];
		else if(ar_src2_sel[2]==1 && ar_dest_sel[0]==DEST_RD && ar_src2[2]==ar_dest[0])
			next_pr_src2[2] = next_pr_dest[0];
		else
			next_pr_src2[2] = ar_src2_sel[2] ? rat[ar_src2[2]] : 0;
	end

	always@(*) begin
		if(ar_src2_sel[1]==1 && ar_dest_sel[0]==DEST_RD && ar_src2[1]==ar_dest[0])
			next_pr_src2[1] = next_pr_dest[0];
		else
			next_pr_src2[1] = ar_src2_sel[1] ? rat[ar_src2[1]] : 0;
	end

	always@(*) begin
		next_pr_src2[0] = ar_src2_sel[0] ? rat[ar_src2[0]] : 0;
	end




	always@(*) begin
		if(ar_dest_sel[3]==DEST_RD && ar_dest_sel[2]==DEST_RD && ar_dest[3]==ar_dest[2])
			next_pr_dest_prev[3] = next_pr_dest[2];
		else if(ar_dest_sel[3]==DEST_RD && ar_dest_sel[1]==DEST_RD && ar_dest[3]==ar_dest[1])
			next_pr_dest_prev[3] = next_pr_dest[1];
		else if(ar_dest_sel[3]==DEST_RD && ar_dest_sel[0]==DEST_RD && ar_dest[3]==ar_dest[0])
			next_pr_dest_prev[3] = next_pr_dest[0];
		else
			next_pr_dest_prev[3] = ar_dest_sel[3]==DEST_RD ? rat[ar_dest[3]] : 0;
	end

	always@(*) begin
		if(ar_dest_sel[2]==DEST_RD && ar_dest_sel[1]==DEST_RD && ar_dest[2]==ar_dest[1])
			next_pr_dest_prev[2] = next_pr_dest[1];
		else if(ar_dest_sel[2]==DEST_RD && ar_dest_sel[0]==DEST_RD && ar_dest[2]==ar_dest[0])
			next_pr_dest_prev[2] = next_pr_dest[0];
		else
			next_pr_dest_prev[2] = ar_dest_sel[2]==DEST_RD ? rat[ar_dest[2]] : 0;
	end

	always@(*) begin
		if(ar_dest_sel[1]==DEST_RD && ar_dest_sel[0]==DEST_RD && ar_dest[1]==ar_dest[0])
			next_pr_dest_prev[1] = next_pr_dest[0];
		else
			next_pr_dest_prev[1] = ar_dest_sel[1]==DEST_RD ? rat[ar_dest[1]] : 0;
	end

	always@(*) begin
		next_pr_dest_prev[0] = ar_dest_sel[0]==DEST_RD ? rat[ar_dest[0]] : 0;
	end

	/***********************intra-group dependency check******************************/

endmodule
