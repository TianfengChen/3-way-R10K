`timescale 1ns/100ps

module xbar #(
	parameter INPUT_NUM = 16,	
	parameter OUTPUT_NUM = 16,	
	parameter DATA_WIDTH = 8
)
(
 	input	[INPUT_NUM-1:0]		xbar_sel 	[0:OUTPUT_NUM-1],
	input	[DATA_WIDTH-1:0] 	i_data 		[0:INPUT_NUM-1],
	output	[DATA_WIDTH-1:0] 	o_data 		[0:OUTPUT_NUM-1]
);

	genvar i;
	generate
   		for(i=0;i<OUTPUT_NUM;i=i+1) begin	
			mux_onehot #(
				.INPUT_NUM(INPUT_NUM),
				.DATA_WIDTH(DATA_WIDTH))	
			mux_onehot_xbar(
				.onehot(xbar_sel[i]),				
				.i_data(i_data),					
				.o_data(o_data[i])						
			);
		end
	endgenerate



endmodule
