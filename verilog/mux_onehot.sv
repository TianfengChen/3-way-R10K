`ifndef __MUX_ONEHOT_V__
`define __MUX_ONEHOT_V__
`timescale 1ns/100ps


module mux_onehot #(
	parameter INPUT_NUM = 16,	
	parameter DATA_WIDTH = 8
)
(
	input [INPUT_NUM-1:0] onehot,	
	input [DATA_WIDTH-1:0] i_data [0:INPUT_NUM-1],	
	output logic [DATA_WIDTH-1:0] o_data					
);

	always_comb begin
		o_data = '0;
		for(int i=0;i<INPUT_NUM;i++) begin
			if(onehot==(1<<i))
				o_data = i_data[i];
		end
	end

endmodule
`endif //__MUX_ONEHOT_V__
