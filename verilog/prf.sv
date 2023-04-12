`ifndef __PRF_V__
`define __PRF_V__
`timescale 1ns/100ps



module prf(
	input								clk								,
	input								rst_n							,
	input			[`PRF_WIDTH-1:0] 	rda_addr	[0:`ISSUE_WIDTH-1]	,    
	input			[`PRF_WIDTH-1:0] 	rdb_addr	[0:`ISSUE_WIDTH-1]	,    
	input			[`PRF_WIDTH-1:0] 	wr_addr		[0:`ISSUE_WIDTH-1]	,    
  	input  			[`XLEN-1:0] 		wr_data		[0:`ISSUE_WIDTH-1]	,     
  	input   		[`ISSUE_WIDTH-1:0]  wr_en							,
  	output logic	[`XLEN-1:0]	 		rda_out		[0:`ISSUE_WIDTH-1]	,    
  	output logic 	[`XLEN-1:0] 		rdb_out 	[0:`ISSUE_WIDTH-1]	   
);
  
  	reg	[`XLEN-1:0] registers [0:`PRF_DEPTH-1];  


	genvar i;
	generate
		for(i=0;i<`ISSUE_WIDTH;i=i+1) begin
			always_comb begin
    			if (rda_addr[i] == `ZERO_REG)
    		  		rda_out[i] = 0;
    			else if (wr_en[i] && (wr_addr[i] == rda_addr[i]))
    		  		rda_out[i] = wr_data[i];  // internal forwarding
    			else
    		  		rda_out[i] = registers[rda_addr[i]];
			end
    		
  			always_comb begin
    			if (rdb_addr[i] == `ZERO_REG)
    			  	rdb_out[i] = 0;
    			else if (wr_en[i] && (wr_addr[i] == rdb_addr[i]))
    			  	rdb_out[i] = wr_data[i];  // internal forwarding
    			else
    			  	rdb_out[i] = registers[rdb_addr[i]];
			end
		end
	endgenerate


  	always_ff @(posedge clk) begin
		for(int i=0;i<`ISSUE_WIDTH;i++) begin
    		if (wr_en[i] && wr_addr[i]!=`ZERO_REG) begin
      			registers[wr_addr[i]] <= wr_data[i];
    		end
		end
	end


endmodule // regfile

`endif //__PRF_V__
