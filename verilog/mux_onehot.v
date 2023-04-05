`timescale 1ns/100ps
module mux_onehot #(
	parameter INPUT_NUM = 16,	
	parameter DATA_WIDTH = 8
)
(
	input [INPUT_NUM-1:0] onehot,	
	input [DATA_WIDTH*INPUT_NUM-1:0] i_data,	
	output logic [DATA_WIDTH-1:0] o_data					
);

	always_comb begin
		o_data = '0;
		for(int i=0;i<INPUT_NUM;i++) begin
			if(onehot==(1<<i))
				o_data = i_data[i*DATA_WIDTH+:DATA_WIDTH];
		end
	end

endmodule
