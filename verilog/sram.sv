`timescale 1ns/100ps

module sram #(
	parameter WIDTH = 256,
	parameter DEPTH = 64
)
(
 	input								clk,
 	input 		[WIDTH-1:0] 			wr_data,
	input 		[$clog2(DEPTH)-1:0] 	addr,
	input								wen,
 	output	reg [WIDTH-1:0] 			rd_data
);

	reg [WIDTH-1:0] ram [0:DEPTH-1];

//	assign rd_data = ram[addr];

	always@(posedge clk) begin
		if(wen)
			rd_data <= wr_data;
		else
			rd_data <= ram[addr];
	end
	
	always@(posedge clk) begin
		if(wen) begin
			ram[addr] <= wr_data;
		end
	end

endmodule
