
module rrat(
	input        			                clk,          	   // the clock 							
	input        			                rst,          	   // reset signal	                
	input  [(`N_WAY)*(`ARF_WIDTH)-1:0]	dest_arn_in,       // from RoB
   	input  [`N_WAY-1:0]                     inst_valid_in,       //commit
    input  [(`N_WAY)*(`PRF_WIDTH)-1:0]      dest_prn_in,       // from RoB
   	output logic [(`ARF_SIZE)*(`PRF_WIDTH)-1:0]	rrat_rename_table_out     
);
    logic  [`ARF_WIDTH-1:0] dest_arn	[0 : `N_WAY-1];
    logic  [`PRF_WIDTH-1:0] dest_prn	[0 : `N_WAY-1];
	logic  [`PRF_WIDTH-1:0] rename_table	[0 : `ARF_SIZE-1];       	// rename table
   	logic  [`N_WAY-1:0]                     inst_valid;       //commit
    

    assign  {dest_arn[2],dest_arn[1],dest_arn[0]}  = dest_arn_in;
    assign  {dest_prn[2],dest_prn[1],dest_prn[0]}  = dest_prn_in;
	always_comb begin
		for(int i=0;i<`ARF_SIZE;i=i+1) begin
    		rrat_rename_table_out[i*`PRF_WIDTH +: `PRF_WIDTH] = rename_table[i];
		end
	end
	
	always_comb begin
		inst_valid = inst_valid_in;
		if(inst_valid_in[2] & inst_valid_in[1] & (dest_arn[1] == dest_arn[2])) begin
			inst_valid[2] = 0;
		end
		if(inst_valid_in[2] & inst_valid_in[0] & (dest_arn[0] == dest_arn[2])) begin
			inst_valid[2] = 0;
		end
		if(inst_valid_in[0] & inst_valid_in[1] & (dest_arn[1] == dest_arn[0])) begin
			inst_valid[1] = 0;
		end		
	end

    // write modify ARN->PRN, 1.reset,  2. normal case
    always_ff @(posedge clk)begin
        if(rst) begin
			for(int i=0;i<`ARF_SIZE;i=i+1) begin
				rename_table[i] <= `SD {`PRF_WIDTH{1'b0}}; // clear
			end
        end// if(rst)
        else	begin
		for(int i=0; i<`N_WAY; i=i+1) begin
			if(dest_arn[i] != `ZERO_REG & inst_valid[i] == 1) begin
				rename_table[ dest_arn[i] ] <= `SD dest_prn[i];
			end
		end//for(int i=0; i<`N_WAY; i=i+1)begin
	end//else begin
    end//always_ff@(posedge clk)begin

endmodule

