`timescale 1ns/100ps

module rob_bank(
	input 							clk						,
	input 							rst_n					,
                                                        	
	input	ROB_ENTRY 				rob_entry_in 			,
	output	ROB_ENTRY 				rob_entry_out 			,
	input	[`ROB_WIDTH_BANK-1:0]	head_ptr				,
	input	[`ROB_WIDTH_BANK-1:0]	tail_ptr				,
    
	input	[`ROB_WIDTH_TAG-1:0]	writeback_rob			[0:`ISSUE_WIDTH-1],
	input							writeback_br_misp		, 
	input	[`ISSUE_WIDTH-1:0]		writeback_valid			,

	output							head_complete			,
	input							head_complete_accept	

);

	ROB_ENTRY	rob_entry	[0:`ROB_DEPTH_BANK-1];

	assign head_complete = rob_entry[head_ptr].complete && rob_entry[head_ptr].valid;

	genvar i;
	generate
		for(i=0;i<`MACHINE_WIDTH;i=i+1) begin

		end

		for(i=0;i<`ROB_WIDTH_BANK;i=i+1) begin	
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					rob_entry[i] <= 0;
				else begin
					if(head_complete_accept && i==head_ptr)
						rob_entry[i].valid <= 1'b0;	//clear entry after retirement

					if(i==tail_ptr)
						rob_entry[i] <= rob_entry_in //allocate a new entry

					if(writeback_valid[5] && writeback_br_misp)
						rob_entry[i].branch_misp <=	1'b1;

					rob_entry[i].complete 		<=	(i==writeback_rob[0] && writeback_valid[0])	||
											 		(i==writeback_rob[1] && writeback_valid[1])	||
											 		(i==writeback_rob[2] && writeback_valid[2])	||
											 		(i==writeback_rob[3] && writeback_valid[3])	||
											 		(i==writeback_rob[4] && writeback_valid[4])	||
											 		(i==writeback_rob[5] && writeback_valid[5])	||
											 		(i==writeback_rob[6] && writeback_valid[6]);
				end
			end
		end
	endgenerate


endmodule
