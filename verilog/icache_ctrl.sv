`ifndef __ICACHE_CTRL_SV__
`define __ICACHE_CTRL_SV__

module icache_ctrl(
    input								clk,
    input   							rst_n,
                                    	
    input	[3:0] 						imem2proc_response,
    input  	[63:0] 						imem2proc_data,
    input   [3:0]						imem2proc_tag,
                                    	
	output	BUS_COMMAND 				proc2imem_command,
	output 	[`XLEN-1:0] 				proc2imem_addr,
 	output 	MEM_SIZE 					proc2imem_size,   
                                    	
    input  	[`XLEN-1:0]					fetch_pc,
    input  	  							fetch_pc_valid,
    output  	  						fetch_pc_ready,

	output 	[`ICACHE_BLOCK_WIDTH-1:0] 	fetch_grp, 	
	output 	[`ICACHE_WORD_NUM-1:0]		fetch_grp_valid,
   	input								fetch_grp_ready	
);

	reg [`ICACHE_BLOCK_WIDTH-1:0]	cache_line_buf;
	reg 							cache_line_buf_valid;
	reg [`ICACHE_OFFSET_WIDTH-1:0]	proc2imem_inst_cnt;
	reg [`ICACHE_OFFSET_WIDTH-1:0]	imem2proc_inst_cnt;
	BUS_COMMAND						proc2imem_command_pipe;
	reg [`ICACHE_OFFSET_WIDTH-1:0]	proc2imem_inst_cnt_pipe;
	reg [3:0]						outstanding_tag		[0:3];

	reg	 [`XLEN-1:0]				curr_fetch_pc;
	wire [`XLEN-1:0]				addr_cache_array;
	wire [`ICACHE_BLOCK_WIDTH-1:0]	rd_block;
	wire [`ICACHE_WORD_NUM-1:0]		rd_block_mask;

	wire hit;




	parameter IDLE				= 4'd0;		//idle
	parameter CHK_HIT			= 4'd1;		//check L1 hit or miss
	parameter HIT_L1_WAIT_RDY 	= 4'd2;  	//L1 hit, but fetch_grp_ready is low
	parameter RD_L2_REQ 		= 4'd3; 	//L1 miss, send addr to L2
	parameter RD_L2_ACK 		= 4'd4;		//L1 miss, accept data from L2 
	parameter WR_L1	 			= 4'd5;		//L1 miss, update L1
	parameter FETCH_AFTER_MISS	= 4'd6;		//this elminates bubble
	parameter MISS_L1_WAIT_RDY	= 4'd7;		//L1 miss, fetch_grp_ready is low
	parameter AFTER_WAIT_RDY	= 4'd8;		//state transits from *_L1_WAIT_RDY to this state if no further fetch req


	reg [3:0] curr_st;
	reg [3:0] next_st;



	icache_array u_icache_array(
		.clk			(clk					),
		.rst_n			(rst_n					),
		.addr			(addr_cache_array		),
		.wr_block		(cache_line_buf			),
		.wen			(cache_line_buf_valid	),
		.hit			(hit					),  
		.rd_block   	(rd_block				),
		.rd_block_mask  (rd_block_mask   		)
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
				if(fetch_pc_valid & fetch_pc_ready)
					next_st = CHK_HIT;
				else		
					next_st = IDLE;
			end
			CHK_HIT: begin
				if(hit) begin//L1 hit
					if(fetch_grp_ready) begin
						if(fetch_pc_valid & fetch_pc_ready) //continue fetching
							next_st = CHK_HIT;
						else
							next_st = IDLE;
					end
					else
						next_st = HIT_L1_WAIT_RDY;
				end
				else	//L1 miss
					next_st = RD_L2_REQ;
			end
			HIT_L1_WAIT_RDY: begin
				if(fetch_grp_ready) begin
					if(fetch_pc_valid) //continue fetching
						next_st = CHK_HIT;
					else
						next_st = AFTER_WAIT_RDY;
				end
				else
					next_st = HIT_L1_WAIT_RDY;
			end
			RD_L2_REQ: begin
				if(proc2imem_inst_cnt == 8-2)
					next_st = RD_L2_ACK;
				else
					next_st = RD_L2_REQ;
			end
			RD_L2_ACK: begin
				if(imem2proc_inst_cnt == 8-2)
					next_st = WR_L1;
				else
					next_st = RD_L2_ACK;
			end
			WR_L1: begin
				if(fetch_grp_ready)		//accepted
					if(fetch_pc_valid) 	//continue fetching
						next_st = FETCH_AFTER_MISS;
					else
						next_st = IDLE;
				else
					next_st = MISS_L1_WAIT_RDY;
			end
			MISS_L1_WAIT_RDY: begin
				if(fetch_grp_ready) begin	//accepted
					if(fetch_pc_valid) 		//continue fetching
						next_st = FETCH_AFTER_MISS;
					else
						next_st = AFTER_WAIT_RDY;
				end
				else
					next_st = MISS_L1_WAIT_RDY;
			end
			FETCH_AFTER_MISS: begin
				next_st = CHK_HIT;
			end
			AFTER_WAIT_RDY: begin
				if(fetch_pc_valid) //continue fetching
					next_st = CHK_HIT;
				else
					next_st = IDLE;
			end
			default: begin 
				next_st = IDLE;
			end
		endcase
	end


	assign fetch_pc_ready 	= fetch_grp_ready ? curr_st == IDLE | curr_st == WR_L1 | (curr_st == CHK_HIT & hit) : 0; 
	assign addr_cache_array	= curr_st == IDLE ? (fetch_pc_valid & fetch_pc_ready ? fetch_pc : curr_fetch_pc) : (curr_st == CHK_HIT & hit ? fetch_pc : curr_fetch_pc); 
	assign fetch_grp_valid 	= (curr_st != IDLE & curr_st != HIT_L1_WAIT_RDY & curr_st != MISS_L1_WAIT_RDY & curr_st != FETCH_AFTER_MISS) ? rd_block_mask : 0;
	assign fetch_grp 		= curr_st != IDLE ? rd_block : 0;


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			proc2imem_command_pipe <= BUS_NONE;
			proc2imem_inst_cnt_pipe <= 0;
		end
		else begin
			proc2imem_command_pipe <= proc2imem_command;
			proc2imem_inst_cnt_pipe <= proc2imem_inst_cnt;
		end
	end

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			curr_fetch_pc <= 0;
		else if(fetch_pc_valid & fetch_pc_ready)
			curr_fetch_pc <= fetch_pc;
		else if(next_st == IDLE)
			curr_fetch_pc <= 0;
	end



	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) 
			proc2imem_inst_cnt <= 0;
		else if(curr_st == RD_L2_REQ)
			proc2imem_inst_cnt <= proc2imem_inst_cnt + 2;
		else
			proc2imem_inst_cnt <= 0;
	end

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			foreach(outstanding_tag[i])
				outstanding_tag[i] = 0;
		end
		else if(proc2imem_command_pipe == BUS_LOAD)
			outstanding_tag[proc2imem_inst_cnt_pipe/2] = imem2proc_response; 
		else if(hit)begin
			foreach(outstanding_tag[i])
				outstanding_tag[i] = 0;
		end
	end	

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			cache_line_buf <= 0;
			imem2proc_inst_cnt <= 0;
			cache_line_buf_valid <= 0;
		end
		else if(cache_line_buf_valid) begin
			imem2proc_inst_cnt <= 0;
			cache_line_buf <= 0;
			cache_line_buf_valid <= 0;
		end
		else if(curr_st == RD_L2_ACK) begin
			if(imem2proc_tag != 0 && imem2proc_tag == outstanding_tag[0])	begin
				imem2proc_inst_cnt <= imem2proc_inst_cnt + 2;
				cache_line_buf[imem2proc_inst_cnt*32+:64] <= imem2proc_data;
			end
			else if(imem2proc_tag != 0 && imem2proc_tag == outstanding_tag[1]) begin
				imem2proc_inst_cnt <= imem2proc_inst_cnt + 2;
				cache_line_buf[imem2proc_inst_cnt*32+:64] <= imem2proc_data;
			end
			else if(imem2proc_tag != 0 && imem2proc_tag == outstanding_tag[2]) begin
				imem2proc_inst_cnt <= imem2proc_inst_cnt + 2;
				cache_line_buf[imem2proc_inst_cnt*32+:64] <= imem2proc_data;
			end	
			else if(imem2proc_tag != 0 && imem2proc_tag == outstanding_tag[3]) begin
				imem2proc_inst_cnt <= imem2proc_inst_cnt + 2;
				cache_line_buf[imem2proc_inst_cnt*32+:64] <= imem2proc_data;
				cache_line_buf_valid <= 1;
			end			
		end
	end


	assign proc2imem_command = curr_st == RD_L2_REQ ? BUS_LOAD : BUS_NONE;
	assign proc2imem_size =  DOUBLE;
	assign proc2imem_addr = curr_st == RD_L2_REQ ? ({curr_fetch_pc[31:`ICACHE_OFFSET_WIDTH],{`ICACHE_OFFSET_WIDTH{1'b0}}} + proc2imem_inst_cnt*4) : 0;


endmodule
`endif //__ICACHE_CTRL_SV__
