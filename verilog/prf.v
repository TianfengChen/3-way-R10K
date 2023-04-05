//////////////////////////////////////////////////////////////////////////////
//                                                                          //
//   Modulename :  PRF.v                                                    //
//                                                                          //
//  Description :  This module creates the Physical Register Files storing  // 
//                 data in R10K Tomasulo Algorithm                          //
//                 programmer: Tianfeng Chen (tfchen), Nan Chen             //
//////////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps

module prf(
        input              		  clock,
        input                     reset,
        
        //squash valid list
        input	[(`ARF_SIZE)*(`PRF_WIDTH)-1:0]  rrat_rename_table_in,	
        input   				                squash_en,

        //commit
        input [2:0]                             ROB_commit_valid,		
        input [(`N_WAY)*(`PRF_WIDTH)-1:0]       rob_old_prn_width_in,
        
        //store
        input	[(`N_WAY)*(`PRF_WIDTH)-1:0]	    dest_prn_width,//dest. prf addr to write the value
        input	[(`N_WAY)*(`XLEN)-1:0]	        CDB_dest_prf_value,//write corresponding value to prf
        input   [`N_WAY-1:0]                    CDB_done,

        //load
        input	[(`N_WAY)*(`PRF_WIDTH)-1:0]	    op1_prf_in,//op1 prf addr to read the value
        input	[(`N_WAY)*(`PRF_WIDTH)-1:0]	    op2_prf_in,//op2 prf addr to read the value
        output logic [(`N_WAY)*(`XLEN)-1:0]     op1_value_out,
        output logic [(`N_WAY)*(`XLEN)-1:0]     op2_value_out,
        
        output logic [`PRF_SIZE-1:0]  			valid_list,
		output logic [(`PRF_SIZE)*(`XLEN)-1:0]	prf_data_out
      );

    //or all dest_prn_size
    logic [`PRF_SIZE-1:0] combine_dest_prn_size;
    logic [`PRF_SIZE-1:0] combine_rob_old_prn;
    logic [`PRF_SIZE-1:0] combine_rob_dest_prn;
    logic [`PRF_SIZE-1:0] combine_squash_prn;

    logic [`XLEN-1:0] registers [0:`PRF_SIZE-1];   // 32, 64-bit Registers
    logic [`PRF_SIZE-1:0] next_valid_list;
    logic [2:0] [`XLEN-1:0] op1_reg;
    logic [2:0] [`XLEN-1:0] op2_reg;



	assign op1_value_out[31:0] = registers[op1_prf_in[6:0]];
	assign op1_value_out[63:32] = registers[op1_prf_in[13:7]];
	assign op1_value_out[95:64] = registers[op1_prf_in[20:14]];
   
	assign op2_value_out[31:0] = registers[op2_prf_in[6:0]];
	assign op2_value_out[63:32] = registers[op2_prf_in[13:7]];
	assign op2_value_out[95:64] = registers[op2_prf_in[20:14]];


	genvar i;
	generate
		for(i=0;i<`PRF_SIZE;i=i+1) begin
			assign prf_data_out[i*(`XLEN)+:`XLEN] = registers[i];
		end
	endgenerate



    integer M,N,k,p;

  always_comb
  begin
    //decode width to size

    combine_dest_prn_size = {`PRF_SIZE{1'b0}};
    for (M=0; M<`N_WAY; M++)
    begin
        if (CDB_done[M] ==1)
        begin
            for (N=0; N<`PRF_SIZE; N++)
            begin
                if (dest_prn_width[M*(`PRF_WIDTH)+:`PRF_WIDTH]==N)
                    combine_dest_prn_size[N]=1;
            end
        end
    end



    combine_rob_old_prn = {`PRF_SIZE{1'b0}};
    for (M=0; M<`N_WAY; M++)
    begin
		if(ROB_commit_valid[M]) begin
        	for (N=0; N<`PRF_SIZE; N++)
        	begin
        	    if (rob_old_prn_width_in[M*(`PRF_WIDTH)+:`PRF_WIDTH]==N & N!=0)	//rrat entries all reset with prn0, which cannot be set valid=0!!!!!
        	        combine_rob_old_prn[N]=1;
        	end
		end
    end

/*

    combine_squash_prn = {`PRF_SIZE{1'b0}};
    //for (M=0; M<`ROB_SIZE; M++)
    //begin
		if(squash_en) begin
        	for (N=0; N<`ARF_SIZE; N++) begin
        		combine_squash_prn[rrat_rename_table_in[N]]=1;
			end
		end
    //end
*/
  end

//  assign next_valid_list = (~valid_list & combine_dest_prn_size)|(valid_list &(~(combine_squash_prn|combine_rob_old_prn)));
 // assign valid_list_to_rob = ~valid_list & combine_dest_prn_size;
 

  	always_comb begin
		if(squash_en)
			next_valid_list = {combine_squash_prn[95:1],1'b1};
		else begin 
			if(ROB_commit_valid == 3'b000)
				next_valid_list = valid_list | combine_dest_prn_size;
			else
				next_valid_list = (valid_list & ~combine_rob_old_prn) | combine_dest_prn_size ;		
		end
	end

  always_comb begin
    combine_squash_prn = {`PRF_SIZE{1'b0}};
	if(squash_en) begin
    	for (p=0; p<`ARF_SIZE; p++) begin
    		combine_squash_prn[rrat_rename_table_in[p*(`PRF_WIDTH)+:(`PRF_WIDTH)]]=1;
		end
	end
  end

  // Write 
  always_ff @(posedge clock)
  begin
    if (reset==1'b1)
    begin
        valid_list <= `SD {{(`PRF_SIZE-1){1'b0}},1'b1};
        for (k=0;k<`PRF_SIZE;k++)
        begin
            registers[k]  <= `SD 0;
        end
    end
    else
    begin
        valid_list <= `SD next_valid_list;
        for (k=0;k<3;k++)
        begin
            if ((CDB_done[k]==1'b1) && (dest_prn_width[k*(`PRF_WIDTH)+:(`PRF_WIDTH)] != `ZERO_REG))
            //if (CDB_done[k]==1'b1)
            registers[dest_prn_width[k*(`PRF_WIDTH)+:(`PRF_WIDTH)]] <= `SD CDB_dest_prf_value[k*(`XLEN)+:(`XLEN)];
        end
    end
  end

endmodule // regfile

//`endif //__REGFILE_V__
