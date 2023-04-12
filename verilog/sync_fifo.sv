module sync_fifo #(
	parameter WIDTH = 8,
	parameter DEPTH = 16					
) 
( 
	input  					clk 			, 
	input  					rst_n 			, 
	input  					wr_en 			,
	input  					rd_en 			, 
	input  		[WIDTH-1:0] data_in 		, 
	output reg	[WIDTH-1:0] data_out 		, 
	output 					empty 			, 
 	output 					full 
); 

	reg [$clog2(DEPTH)-1:0] wr_addr ; 
 	reg [$clog2(DEPTH)-1:0] rd_addr ; 
 	reg [$clog2(DEPTH):0] 	count ; 
 	reg [WIDTH-1:0] 		fifo [0:DEPTH-1] ;  


	assign empty = count == 0;
	assign full = count == DEPTH;	

 
 	always@(posedge clk or negedge rst_n) begin 
 		if(rst_n == 1'b0) 
 			data_out <= 0; 
 		else if(rd_en && empty==0) 
 			data_out<=fifo[rd_addr]; 
 	end
 	
 	always@(posedge clk ) begin 
 		if(wr_en==1 && full==0) 
 			fifo[wr_addr] <= data_in; 
 	end 
 	
 	always@(posedge clk or negedge rst_n) begin 
 		if(rst_n == 1'b0) 
 			rd_addr <= 0; 
 		else if(empty==0 && rd_en==1) 
 			rd_addr <= rd_addr + 1; 
 	end 
 	
 	always@(posedge clk or negedge rst_n) begin 
 		if(rst_n == 1'b0) 
 			wr_addr <= 0; 
 		else if(full==0 && wr_en==1)
 			wr_addr <= wr_addr + 1; 
 	end 
 	
 	always@(posedge clk or negedge rst_n) begin 
 		if(rst_n == 1'b0) 
 			count <= 0; 
 		else begin 
 			case({wr_en,rd_en}) 
 				2'b00: 
					count <= count; 
 				2'b01: 
 					if(~empty) 
 						count <= count - 1; 
 				2'b10: 
 					if(~full) 
 						count <= count + 1; 
 				2'b11: 
					count <= count; 
 			endcase 
 		end 
 	end 
 
endmodule

