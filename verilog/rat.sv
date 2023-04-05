`timescale 1ns/100ps

module rat(
	input        				clock,          	                // the clock 							
	input        				reset,          	                // reset signal			
	input [(`N_WAY) * (`ARF_WIDTH)-1:0] 	op1_arn_in,       // from decoder
	input [(`N_WAY) * (`ARF_WIDTH)-1:0] 	op2_arn_in,       // from decoder
	input [(`N_WAY) * (`ARF_WIDTH)-1:0] 	dest_arn_in,       // from decoder
  	input [(`ARF_SIZE) * (`PRF_WIDTH)-1:0] 	rrat_rename_table_in,    // from rrat
    	input [`PRF_SIZE-1:0]   		prf_free_list,           // from prf
    	input                   		rat_mispredict,          // from controller
    	input [`N_WAY-1:0]   			inst_valid_in,       //asserted when IF is dispatching instruction
    	input [`N_WAY-1:0]   			dest_arn_valid_in,       //asserted when IF is dispatching instruction
 	input 								rs_rob_haz_stall,
   	

	output logic [(`N_WAY) * (`PRF_WIDTH)-1:0]    rat_op1_prn_out,   	// feed to rs
	output logic [(`N_WAY) * (`PRF_WIDTH)-1:0]    rat_op2_prn_out,   	// feed to rs
	output logic [(`N_WAY) * (`PRF_WIDTH)-1:0]    rat_dest_prn_out,       // feed to rs and RoB
    	output logic [`N_WAY-1:0]   			dest_prn_valid_out,
    	output logic [(`ARF_SIZE) * (`PRF_WIDTH)-1:0] rat_rename_table_out, 
	output logic [(`N_WAY) * (`PRF_WIDTH)-1:0]    rat_pre_dest_prn_out       // feed to rs and RoB    
);
	logic [`PRF_WIDTH-1:0] 		rename_table 		[0:`ARF_SIZE-1];       	// rename table
    	logic [`PRF_WIDTH-1:0] 		rrat_rename_table 	[0:`ARF_SIZE-1];
    	logic [`PRF_WIDTH-1:0]    	next_dest_prn 		[0:`N_WAY-1];       //get the dest_prn in rename_table
    	logic [`PRF_WIDTH-1:0]    	next_op1_prn 		[0:`N_WAY-1];       // ensure the corresponding prn of op1
    	logic [`PRF_WIDTH-1:0]    	next_op2_prn 		[0:`N_WAY-1];       // ensure the corresponding prn of op2
    	logic [`PRF_WIDTH-1:0]     	pre_dest_prn		[0:`N_WAY-1];       //get the dest_prn in rename_table
    	logic [`ARF_WIDTH-1:0]    	op1_arn			[0:`N_WAY-1];
    	logic [`ARF_WIDTH-1:0]     	op2_arn			[0:`N_WAY-1];
    	logic [`ARF_WIDTH-1:0]     	dest_arn		[0:`N_WAY-1];

    	logic [(`PRF_SIZE) * (`N_WAY)-1:0] 	next_prf_entry_sel_bus;			//selected inst per superscalar lane*n ways
    	logic [`PRF_SIZE-1:0] 			next_prf_entry_sel;
    	logic [`PRF_SIZE-1:0] 			next_prf_entry_sel_bus_split	[0:`N_WAY-1];
	logic [`PRF_WIDTH-1:0]			next_prf_entry_num		[0:`N_WAY-1];

    	logic [`N_WAY-1:0]   			inst_valid;

    

    psel_gen #(.REQS(`N_WAY), .WIDTH(`PRF_SIZE)) psel_sel_prf_entry(  	//select the top 2 entries and lowest 1 entry  //N in M
		.req(prf_free_list),
		.gnt(next_prf_entry_sel), 		//mux 3 in 96 ctrl signal
		.gnt_bus(next_prf_entry_sel_bus),	//mux 3 in 96 ctrl signal
		.empty()
	);
    // split next_prf_entry_sel_bus into N_WAY
    always_comb begin
	for(int i=0;i<`N_WAY;i=i+1) begin
		next_prf_entry_sel_bus_split[i] = next_prf_entry_sel_bus[i*`PRF_SIZE +: `PRF_SIZE];	//split next_prf_entry_sel_bus
		op1_arn[i]  = op1_arn_in[i*`ARF_WIDTH +: `ARF_WIDTH];
		op2_arn[i]  = op2_arn_in[i*`ARF_WIDTH +: `ARF_WIDTH];
		dest_arn[i] = dest_arn_in[i*`ARF_WIDTH +: `ARF_WIDTH];
	end
    end

    onehot_enc #(`PRF_SIZE) onehot_enc_2(
	.in(next_prf_entry_sel_bus_split[2]),
	.out(next_prf_entry_num[2])
    );
    onehot_enc #(`PRF_SIZE) onehot_enc_1(
	.in(next_prf_entry_sel_bus_split[1]),
	.out(next_prf_entry_num[1])
    );
    onehot_enc #(`PRF_SIZE) onehot_enc_0(
	.in(next_prf_entry_sel_bus_split[0]),
	.out(next_prf_entry_num[0])
    );

    always_comb begin
	for(int i=0;i<`ARF_SIZE;i=i+1) begin
		rrat_rename_table[i] = rrat_rename_table_in[i*`PRF_WIDTH +: `PRF_WIDTH];
	end
    end

    always_comb begin
	inst_valid = inst_valid_in;
	if((inst_valid_in[1] & dest_arn_valid_in[1]) & (inst_valid_in[2] & dest_arn_valid_in[2]) & (dest_arn[1]==dest_arn[2])) begin
		inst_valid[2] = 1'b0;
	end
	if((inst_valid_in[0] & dest_arn_valid_in[0]) & (inst_valid_in[2] & dest_arn_valid_in[2]) & (dest_arn[0]==dest_arn[2])) begin
		inst_valid[2] = 1'b0;
	end
	if((inst_valid_in[0] & dest_arn_valid_in[0]) & (inst_valid_in[1] & dest_arn_valid_in[1]) & (dest_arn[0]==dest_arn[1])) begin
		inst_valid[0] = 1'b0;
	end
    end
    // write modify ARN->PRN, 1.reset,  2. misprediction, 3. normal case
    always_ff @(posedge clock) begin
        if(reset) begin
		for(int i=0;i<`ARF_SIZE;i=i+1) begin
               		rename_table[i] <= `SD {`PRF_WIDTH{1'b0}};
		end
        end// if(reset)

        else if(rat_mispredict) begin
                rename_table <= `SD rrat_rename_table;
        end// if(rat_mispredict)
		
        else begin
            for(int k=0;k<`N_WAY;k=k+1) begin
                if(~rs_rob_haz_stall & inst_valid[k] & dest_arn_valid_in[k])begin
                	rename_table[dest_arn[k]] <= `SD next_prf_entry_num[k];
		end
	    end
	end
    end

    always_comb begin
            pre_dest_prn[2] = rename_table[dest_arn[2]];
            pre_dest_prn[1] = rename_table[dest_arn[1]];
            pre_dest_prn[0] = rename_table[dest_arn[0]];
	    if(dest_arn_valid_in[1] & dest_arn_valid_in[2] & (dest_arn[1]==dest_arn[2])) begin
		pre_dest_prn[1] = next_prf_entry_num[2];
	    end
	    if(dest_arn_valid_in[0] & dest_arn_valid_in[2] & (dest_arn[0]==dest_arn[2])) begin
		pre_dest_prn[0] = next_prf_entry_num[2];
	    end
	    if(dest_arn_valid_in[0] & dest_arn_valid_in[1] & (dest_arn[0]==dest_arn[1])) begin
		pre_dest_prn[1] = next_prf_entry_num[0];
	    end
    end

    always_comb begin
        if(reset) begin // if reset
		for(int i=0;i<`N_WAY;i=i+1) begin
               		next_op1_prn[i]  = {`PRF_WIDTH{1'b0}};
                	next_op2_prn[i]  = {`PRF_WIDTH{1'b0}};
                	next_dest_prn[i] = {`PRF_WIDTH{1'b0}};
		end
        end
        else if(rat_mispredict) begin // if rat_nuke
            for(int i=0;i<`N_WAY;i=i+1) begin
                next_op1_prn[i] = rrat_rename_table[op1_arn[i]];
                next_op2_prn[i] = rrat_rename_table[op2_arn[i]];
                next_dest_prn[i] = rrat_rename_table[dest_arn[i]];
            end
        end
        else begin
	    for(int i=0; i<`N_WAY; i=i+1) begin
                if(~rs_rob_haz_stall & inst_valid_in[i]) begin
                    next_dest_prn[i] = next_prf_entry_num[i];
                    next_op1_prn[i]  = rename_table[op1_arn[i]];
                    next_op2_prn[i]  = rename_table[op2_arn[i]];
                end
	        	else begin
                    next_dest_prn[i] = {`PRF_WIDTH{1'b0}};
                    next_op1_prn[i]  = {`PRF_WIDTH{1'b0}};
                    next_op2_prn[i]  = {`PRF_WIDTH{1'b0}};
	        end
	    end
        end


        if(~rs_rob_haz_stall & inst_valid_in[0] & inst_valid_in[2] & dest_arn_valid_in[2]) begin // internal forwarding among op1_arn[1], op2_arn[1] and dest_arn[0]
            if(op1_arn[0] == dest_arn[2])
                next_op1_prn[0] = next_dest_prn[2];
            if(op2_arn[0] == dest_arn[2])
                next_op2_prn[0] = next_dest_prn[2];
        end
        
        if(~rs_rob_haz_stall & inst_valid_in[1] & inst_valid_in[2] & dest_arn_valid_in[2]) begin // internal forwarding among op1_arn[2], op2_arn[2] and dest_arn[0]
            if (op1_arn[1] == dest_arn[2])
                next_op1_prn[1] = next_dest_prn[2];
            if (op2_arn[1] == dest_arn[2])
                next_op2_prn[1] = next_dest_prn[2];
        end

        if(~rs_rob_haz_stall & inst_valid_in[1] & inst_valid_in[0] & dest_arn_valid_in[0])begin // internal forwarding among op1_arn[2], op2_arn[2] and dest_arn[1]
            if (op1_arn[1] == dest_arn[0])
                next_op1_prn[1] = next_dest_prn[0];
            if (op2_arn[1] == dest_arn[0])
                next_op2_prn[1] = next_dest_prn[0];
        end
        
    end


    assign rat_op1_prn_out = {next_op1_prn[2], next_op1_prn[1], next_op1_prn[0]};
    assign rat_op2_prn_out = {next_op2_prn[2], next_op2_prn[1], next_op2_prn[0]};
    assign rat_dest_prn_out = {next_dest_prn[2], next_dest_prn[1], next_dest_prn[0]};
    assign rat_pre_dest_prn_out = {pre_dest_prn[2], pre_dest_prn[1], pre_dest_prn[0]};
    assign dest_prn_valid_out = dest_arn_valid_in & ~rs_rob_haz_stall;

    always_comb begin
	for(int i=0;i<`ARF_SIZE;i=i+1) begin
		rat_rename_table_out[i*(`PRF_WIDTH) +: `PRF_WIDTH] = rename_table[i];
	end
    end

endmodule
