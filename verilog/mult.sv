`timescale 1ns/100ps

module mult(
	input 			clk,				
	input 			rst_n,				
	input 			pipe_flush,				
	input 	[63:0] 	a,				
	input 	[63:0] 	b,				
	output 	[63:0] 	result				
);
   
	wire [63:0] result_tmp;
	reg [63:0] pipe_reg_0;
	reg [63:0] pipe_reg_1;
	//reg [63:0] pipe_reg_2;
	//reg [63:0] pipe_reg_3;

	assign result_tmp = a*b;
	assign result = pipe_reg_1;

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			pipe_reg_0 <= 0;
			pipe_reg_1 <= 0;
			//pipe_reg_2 <= 0;
			//pipe_reg_3 <= 0;
		end
		else if(pipe_flush) begin
			pipe_reg_0 <= 0;
			pipe_reg_1 <= 0;
		//	pipe_reg_2 <= 0;
		//	pipe_reg_3 <= 0;
		end
		else begin
			pipe_reg_0 <= result_tmp;
			pipe_reg_1 <= pipe_reg_0;
		//	pipe_reg_2 <= pipe_reg_1;
		//	pipe_reg_3 <= pipe_reg_2;
		end
	end

endmodule // mult


