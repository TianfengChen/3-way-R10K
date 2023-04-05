//`default_nettype none

// dcachemem64x32

`timescale 1ns/100ps

module dcache_mem(
	//inputs
        input 		clock, 
	input 		reset, 
////////write port
	//store write
        input 	[4:0] 	st_wr_idx,
        input 	[7:0] 	st_wr_tag,
        input 	[63:0] 	st_wr_data,
        input 		st_wr_en,
	//load write
        input 	[4:0] 	ld_wr_idx,
        input 	[7:0] 	ld_wr_tag,
		input 	[63:0] 	ld_wr_data, 
		input			ld_wr_en,
////////read port
	//store read
        input 	[4:0] 	st_rd_idx,
        input 	[7:0] 	st_rd_tag,
	//load read
        input 	[4:0] 	ld_rd_idx,
        input 	[7:0] 	ld_rd_tag,
	//outputs
        output 	logic	[63:0] 	st_rd_data,
        output 	logic		st_rd_valid,
        output 	logic	[63:0] 	ld_rd_data,
        output 	logic		ld_rd_valid
      );
	logic [`DC_SIZE-1:0] [63:0] data ;
	logic [`DC_SIZE-1:0] [7:0] tags; 
	logic [`DC_SIZE-1:0] valids;
////////get the store/load read result
	assign st_rd_data = data[st_rd_idx];
	assign st_rd_valid = valids[st_rd_idx] && (tags[st_rd_idx] == st_rd_tag);
	assign ld_rd_data = data[ld_rd_idx];
	assign ld_rd_valid = valids[ld_rd_idx] && (tags[ld_rd_idx] == ld_rd_tag);
////////write store/load data into Dcache
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i=0;i<`DC_SIZE;i=i+1) begin
      				valids[i] <= `SD  1'b0;
				data[i]	  <= `SD  64'b0;
				tags[i]	  <= `SD  8'b0;
			end//for(int i=0;i<`DC_SIZE;i=i+1) begin
		end//if(reset) begin
    		else begin
      			if(ld_wr_en) begin
        			valids[ld_wr_idx]  <= `SD  1;
        			data[ld_wr_idx]    <= `SD ld_wr_data;
        			tags[ld_wr_idx]    <= `SD ld_wr_tag;
      			end//if(ld_wr_en) begin
      			if(st_wr_en) begin
        			valids[st_wr_idx]  <= `SD  1;
        			data[st_wr_idx]    <= `SD st_wr_data;
        			tags[st_wr_idx]    <= `SD st_wr_tag;
      			end//if(st_wr_en) begin
    		end//else begin
	end//always_ff @(posedge clock) begin
endmodule
//`default_nettype wire
