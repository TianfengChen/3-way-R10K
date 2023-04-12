`ifndef __ONEHOT_ENC_V__
`define __ONEHOT_ENC_V__
`timescale 1ns/100ps



module onehot_enc #(
	parameter WIDTH = 16
)
(
 	input [WIDTH-1:0] in,
	output logic [$clog2(WIDTH)-1:0] out							
);

	always_comb begin
		out = 0;
		for(int i=0;i<WIDTH;i++) begin
			if(in[i])
				out = i;
		end
	end

endmodule
`endif //__ONEHOT_ENC_V__
