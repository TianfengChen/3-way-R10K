`ifndef __DCACHE_CTRL_SV__
`define __DCACHE_CTRL_SV__

module dcache_ctrl(
    input								clk,
    input   							rst_n,
                                    	
	output	BUS_COMMAND 				proc2dmem_command,
	output 	[`XLEN-1:0] 				proc2dmem_addr,
 	output 	MEM_SIZE 					proc2dmem_size,  
                                        
    input	[3:0] 						dmem2proc_response,
    input  	[63:0] 						dmem2proc_data,
    input   [3:0]						dmem2proc_tag,
 
    input  	[`XLEN-1:0]					req_addr,
	input	[2:0]						req_size,
    input  	[`XLEN-1:0]					req_st_data,
	input	BUS_COMMAND 				req_command,
	input	[`LDQ_WIDTH-1:0]			req_tag,
    input  	  							req_valid,
    output  	  						req_ready,

	output 	[`DCACHE_WORD_NUM-1:0]		rsp_data,
	output	[`LDQ_WIDTH-1:0]			rsp_tag,
	output								rsp_valid,
                                        
	input								kill_req
);

	reg		[`DCACHE_BLOCK_WIDTH-1:0]			refill_buf;					
	reg 	[`DCACHE_DOUBLE_NUM-1:0]			refill_buf_valid;
	reg 	[$clog2(`DCACHE_DOUBLE_NUM)-1:0]	refill_req_ptr;
	reg 	[$clog2(`DCACHE_DOUBLE_NUM)-1:0]	refill_rsp_ptr;
	reg 	[3:0]								refill_mem_tag		[0:`DCACHE_DOUBLE_NUM-1];
	reg 	[$clog2(`DCACHE_DOUBLE_NUM)-1:0]	writeback_ptr;
	BUS_COMMAND									proc2dmem_command_pipe;
                                        	
    reg		[`XLEN-1:0]							curr_req_addr	;
	reg 	[2:0]								curr_req_size	;
    reg 	[`XLEN-1:0]							curr_req_st_data;
	BUS_COMMAND 								curr_req_command;
	reg 	[`LDQ_WIDTH-1:0]					curr_req_tag	;
			
	wire hit;

	wire	[`XLEN-1:0]							st_data;
	wire	[`XLEN-1:0]							rd_data;
	wire	[`XLEN-1:0]							dirty_addr;



	parameter IDLE				= 4'd0;		//idle
	parameter CHK_HIT			= 4'd1;		//check L1 hit or miss
	parameter DIRTY_WB			= 4'd2;		//L1 miss, writeback dirty cache line
	parameter RD_L2_REQ 		= 4'd3; 	//L1 miss, send addr to L2
	parameter RD_L2_ACK 		= 4'd4;		//L1 miss, accept data from L2 
	parameter WR_L1	 			= 4'd5;		//L1 miss, update L1
	parameter FETCH_AFTER_MISS	= 4'd6;		//this elminates bubble


	reg [3:0] curr_st;
	reg [3:0] next_st;



	/********************refill buffer*********************/
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) 
			refill_req_ptr <= 0;
		else if(refill_buf_valid == {`DCACHE_DOUBLE_NUM{1'b1}})
			refill_req_ptr <= 0;
		else if(proc2dmem_command==BUS_LOAD)
			refill_req_ptr <= refill_req_ptr + 1;			
	end	

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) 
			refill_rsp_ptr <= 0;
		else if(refill_buf_valid == {`DCACHE_DOUBLE_NUM{1'b1}})
			refill_rsp_ptr <= 0;
		else if(dmem2proc_response!=0 && curr_st==RD_L2_REQ)
			refill_rsp_ptr <= refill_rsp_ptr + 1;			
	end	

	genvar i;
	generate
		for(i=0;i<`DCACHE_DOUBLE_NUM;i=i+1) begin
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					refill_mem_tag[i]	<= 0;
				else if(refill_buf_valid == {`DCACHE_DOUBLE_NUM{1'b1}})
					refill_mem_tag[i] 	<= 0;
				else if(i==refill_rsp_ptr && proc2dmem_command_pipe==BUS_LOAD && dmem2proc_response!=0)
					refill_mem_tag[i] 	<= dmem2proc_response; 
			end

			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) begin
					refill_buf[i*64+:64] 	<= 0;
					refill_buf_valid[i]		<= 0;
				end
				else if(dmem2proc_tag!=0 && dmem2proc_tag==refill_mem_tag[i]) begin
					refill_buf[i*64+:64] 	<= dmem2proc_data;
					refill_buf_valid[i]		<= 1;
				end
				else if(curr_st==WR_L1) begin
					refill_buf[i*64+:64] 	<= 0;
					refill_buf_valid[i] 	<= 0;
				end				
			end

		end
	endgenerate



	/********************dirty data writeback*******************/
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) 
			writeback_ptr <= 0;
		else if(writeback_ptr==4)
			writeback_ptr <= 0;
		else if(proc2dmem_command_pipe==BUS_STORE && dmem2proc_response!=0)
			writeback_ptr <= writeback_ptr + 1;

	end	





	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			curr_req_addr 		<= 0;
			curr_req_size 		<= 0;
			curr_req_st_data 	<= 0;
			curr_req_command 	<= BUS_NONE;
			curr_req_tag	 	<= 0;
		end
		else if(req_valid && req_ready) begin
			curr_req_addr 		<= req_addr		;
			curr_req_size 		<= req_size		;
			curr_req_st_data 	<= req_st_data 	;
			curr_req_command 	<= req_command 	;
			curr_req_tag	 	<= req_tag	 	;
		end
		else if(next_st==IDLE) begin
			curr_req_addr		<= 0;
			curr_req_size 		<= 0;
			curr_req_st_data 	<= 0;
			curr_req_command 	<= BUS_NONE;
			curr_req_tag	 	<= 0;			
		end
	end	



	assign req_ready 		= curr_st == IDLE | curr_st == WR_L1 | (curr_st == CHK_HIT & hit); 
	assign rsp_valid 		= hit;
	assign rsp_data	 		= rd_data;



	assign proc2dmem_command 	= 	curr_st==RD_L2_REQ 	?	BUS_LOAD	: 
									curr_st==DIRTY_WB	?	BUS_STORE	:
															BUS_NONE	;
	assign proc2dmem_size 		=  	DOUBLE;
	assign proc2dmem_addr 		= 	curr_st==RD_L2_REQ 	? 	{curr_req_addr[31:`DCACHE_OFFSET_WIDTH],{`DCACHE_OFFSET_WIDTH{1'b0}}} + refill_req_ptr*8 	: 
									curr_st==DIRTY_WB	?	{dirty_addr[31:`DCACHE_OFFSET_WIDTH],{`DCACHE_OFFSET_WIDTH{1'b0}}} + writeback_ptr*8 		:
															0;

	assign st_en				=	(curr_st==CHK_HIT && hit && curr_req_command==BUS_STORE) ||
									(curr_st==WR_L1 && curr_req_command==BUS_STORE);
	assign st_data				=	curr_req_st_data;
	//assign refill_en			=	refill_buf_valid==4'b1111;
	assign refill_en			=	curr_st==WR_L1;


	dcache_array u_dcache_array(
		.clk			(clk			),
		.rst_n			(rst_n			),
		.addr			(curr_req_addr	),
		.size			(curr_req_size	),
		.refill_line	(refill_buf		),
		.refill_en		(refill_en		),
		.st_data		(st_data		),
		.st_en			(st_en			),
		.hit			(hit			),  
		.dirty			(dirty			),  
		.dirty_addr		(dirty_addr		),  
		.rd_data    	(rd_data    	)
	);

	
	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			curr_st <= IDLE;
		else
			curr_st <= next_st;
	end	

	
	always@(*) begin
		case(curr_st)
			IDLE: begin
				if(req_valid & req_ready)
					next_st = CHK_HIT;
				else		
					next_st = IDLE;
			end
			CHK_HIT: begin
				if(hit) begin		//L1 hit
					if(req_valid & req_ready) //continue fetching
						next_st = CHK_HIT;
					else
						next_st = IDLE;
				end
				else if(dirty) 		//L1 miss and dirty
					next_st = DIRTY_WB;
				else				//L1 miss and not dirty
					next_st = RD_L2_REQ;	
			end
			DIRTY_WB: begin
				if(writeback_ptr==4)
					next_st = 	RD_L2_REQ;
				else
					next_st = 	DIRTY_WB;
			end
			RD_L2_REQ: begin
				if(refill_req_ptr==`DCACHE_DOUBLE_NUM-1)
					next_st = RD_L2_ACK;
				else
					next_st = RD_L2_REQ;
			end
			RD_L2_ACK: begin
				if(refill_buf_valid=={`DCACHE_DOUBLE_NUM{1'b1}})
					next_st = WR_L1;
				else
					next_st = RD_L2_ACK;
			end
			WR_L1: begin
				if(req_valid) 	//continue fetching
					next_st = FETCH_AFTER_MISS;
				else
					next_st = IDLE;
			end
			FETCH_AFTER_MISS: begin
				next_st = CHK_HIT;
			end
			default: begin 
				next_st = IDLE;
			end
		endcase
	end








	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			proc2dmem_command_pipe <= BUS_NONE;
		end
		else begin
			proc2dmem_command_pipe <= proc2dmem_command;
		end
	end






endmodule
`endif //__DCACHE_CTRL_SV__
