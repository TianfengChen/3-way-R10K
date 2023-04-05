`timescale 1ns/100ps

module free_list(
	//inputs
        input                     reset,
        input                     clock,
////////input signals from rat (renaming logic)
        input   [(`N_WAY)*(`PRF_WIDTH)-1:0]	rat_dest_prn_in,//destination renaming reg from rat
	input	[`N_WAY-1:0]			rat_inst_valid_in,//from ID, that the rat dest reg is valid
////////input signals from ROB (commit logic)
	input	ROB_PACKET			ROB_packet_in_2,
	input	ROB_PACKET			ROB_packet_in_1,
	input	ROB_PACKET			ROB_packet_in_0,
////////squash logic
	input					squash,
    	input	[(`ARF_SIZE)*(`PRF_WIDTH)-1:0]	rrat_rename_table_in,
	//outputs
        output	logic [`PRF_SIZE-1:0] 		free_list
);
	logic	[`PRF_WIDTH-1:0]		rat_dest_prn [0:`N_WAY-1];
	logic	[`PRF_WIDTH-1:0]		rrat_rename_table[0:`ARF_SIZE-1];
	logic	[`PRF_SIZE-1:0] 		next_free_list;

	always_comb begin
		for (int i = 0; i < `ARF_SIZE; i++) begin
			rrat_rename_table[i] = rrat_rename_table_in[i*`PRF_WIDTH +: `PRF_WIDTH];
		end
	end

	always_comb begin
		for (int i = 0; i < `N_WAY; i++) begin
			rat_dest_prn[i]	  = rat_dest_prn_in[i * `PRF_WIDTH +: `PRF_WIDTH];
		end
	end

	always_comb begin
////////////////squash logic
		if(squash) begin
			next_free_list = {{(`PRF_SIZE-1){1'b1}},{1'b0}};
			for(int i=0;i<`ARF_SIZE;i=i+1) begin
				next_free_list[rrat_rename_table[i]] = 0;
			end
		end
		else begin
			next_free_list = free_list;
////////////////////////renaming logic
			next_free_list[rat_dest_prn[2]] = rat_inst_valid_in[2] ? 0 : free_list[rat_dest_prn[2]];
			next_free_list[rat_dest_prn[1]] = rat_inst_valid_in[1] ? 0 : free_list[rat_dest_prn[1]];
			next_free_list[rat_dest_prn[0]] = rat_inst_valid_in[0] ? 0 : free_list[rat_dest_prn[0]];
////////////////////////commit logic
			next_free_list[ROB_packet_in_2.id_packet.dest_old_prn] = (ROB_packet_in_2.commit & ROB_packet_in_2.id_packet.dest_reg_idx != `ZERO_REG) ? 1 : free_list[ROB_packet_in_2.id_packet.dest_old_prn];
			next_free_list[ROB_packet_in_1.id_packet.dest_old_prn] = (ROB_packet_in_1.commit & ROB_packet_in_1.id_packet.dest_reg_idx != `ZERO_REG) ? 1 : free_list[ROB_packet_in_1.id_packet.dest_old_prn];
			next_free_list[ROB_packet_in_0.id_packet.dest_old_prn] = (ROB_packet_in_0.commit & ROB_packet_in_0.id_packet.dest_reg_idx != `ZERO_REG) ? 1 : free_list[ROB_packet_in_0.id_packet.dest_old_prn];
		end
	end

    	always@(posedge clock) begin
		if (reset)
			free_list <= `SD {{(`PRF_SIZE-1){1'b1}},{1'b0}};
		else
        		free_list <= `SD next_free_list;
 	end
      
endmodule

