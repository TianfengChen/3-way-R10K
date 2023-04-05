`default_nettype none
module prefecther(
    	//inputs
	input   		clock,
	input   		reset,
////////input from memory
	input  	[3:0] 		Imem2proc_response,
	input  	[63:0] 		Imem2proc_data,
	input   [3:0] 		Imem2proc_tag,
////////The inst fetch request to memory
    	input  	[63:0] 		inst_fetch_addr,
    	input  	[63:0] 		inst_fetch_data,
    	input  	  		inst_fetch_valid,
////////input from icache controller to memory request
    	input 	[1:0]  		proc2Imem_command,
    	input 	[63:0] 		proc2Imem_addr,
    	input  	[63:0] 		proc2Imem_data,
   	input	[1:0] 		proc2Imem_size,   
////////The nuke signal
	input			nuke,
    	//outputs
////////Output to memory
    	output 	logic 	[1:0]  	proc2mem_command,
    	output 	logic 	[63:0] 	proc2mem_addr,
    	output 	logic 	[63:0] 	proc2mem_data,
    	output 	logic 	[1:0] 	proc2mem_size,   
////////data to be writen to icache
    	output 	logic  	[4:0] 	wr_idx,
    	output 	logic  	[7:0] 	wr_tag,
    	output 	logic  	[63:0] 	wr_data,
    	output 	logic  		wr_enable
  );
////////The prefetcher FIFO
	PREFETCHER_PACKET		prefetcher	[`PREFET_SIZE];
	PREFETCHER_PACKET		next_prefetcher	[`PREFET_SIZE];
////////Determine if new request are needed to sent to prefetcher FIFO
	logic	[4:0] 			last_idx;
	logic	[7:0] 			last_tag;
	logic	[4:0] 			current_idx;
	logic	[7:0] 			current_tag;
	logic				change_addr;
////////hazard signal(structual hazard of prefetcher size and with inst fetch & store/load inst)
	logic	[`PREFET_WIDTH-1:0]	prefet_haz_num;
	logic				request_haz;
	logic				next_request_haz;
	logic				tag_valid;
	logic				request_send;
	logic				next_request_send;
	logic	[2:0]	[`XLEN-1:0]	next_addr;
	logic				is_haz;
	logic				next_is_haz;
////////determine head and tail
	logic	[`PREFET_WIDTH-1:0]	head;
	logic	[`PREFET_WIDTH-1:0]	tail;
	logic	[`PREFET_WIDTH-1:0]	send;
	logic	[`PREFET_WIDTH-1:0]	next_head;
	logic	[`[REFET_WIDTH-1:0]	next_tail;
	logic	[`PREFET_WIDTH-1:0]	next_send;
	logic	[2:0] [`ROB_WIDTH-1:0]	next_possi_tail;	//the possible number for tail,head and send
	logic	[`ROB_WIDTH-1:0]	next_possi_head;
	logic	[`ROB_WIDTH-1:0]	next_possi_send;
////////
////////determine the idx&tag
	assign	current_idx	=	inst_fetch_addr[7:3];
	assign	current_tag	=	inst_fetch_addr[15:8];
////////determine the head,tail and send
	always_comb begin
		casez({`PREFET_WIDTH{1'b1}}-tail)
			0: begin
				next_possi_tail[2] = 0;
				next_possi_tail[1] = 1;
				next_possi_tail[0] = 2;
			end	
			1: begin
				next_possi_tail[2] = {`PREFET_WIDTH{1'b1}};
				next_possi_tail[1] = 0;
				next_possi_tail[0] = 1;
			end
			2: begin
				next_possi_tail[2] = {{(`PREFET_WIDTH-1){1'b1}},1'b0};
				next_possi_tail[1] = {`PREFET_WIDTH{1'b1}};
				next_possi_tail[0] = 0;
			end
			default: begin
				next_possi_tail[2] = tail+1;
				next_possi_tail[1] = tail+2;
				next_possi_tail[0] = tail+3;
			end
		endcase
	end
	assign	next_possi_head	=	({`PREFET_WIDTH{1'b1}}-head == 0) ? 0 : head+1;
	assign	next_possi_send	=	({`PREFET_WIDTH{1'b1}}-send == 0) ? 0 : send+1;
////////determine the hazard signals
	always_comb begin
		if(head > tail) begin
			prefet_haz_num = head - tail;
		end
		else if(head < tail) begin
			prefet_haz_num = {{1'b1},{`PREFET_WIDTH{1'b0}}} - (tail - head);
		end
		else if(prefetcher[head].valid) begin
			prefet_haz_num = {{1'b0},{`PREFET_WIDTH{1'b0}}};
		end
		else begin
			prefet_haz_num = {{1'b1},{`PREFET_WIDTH{1'b0}}};
		end
	end
	assign	next_request_haz	=	(proc2Imem_command != BUS_NONE);
	assign	tag_valid		=	~requset_haz & request_send & (Imem2proc_response != 0);
	assign	next_is_haz		=	(prefet_haz_num<3);
////////inst request dispatch into prefetcher
	assign	change_addr		=	(current_idx!=last_idx)|(current_tag!=last_tag) | is_haz;
	assign	next_addr[2]		=	inst_fetch_addr;
	assign	next_addr[1]		=	inst_fetch_addr+8;
	assign	next_addr[0]		=	inst_fetch_addr+16;
	alwasy_comb begin
		next_prefetcher	=	prefetcher;
		for(int i=0;i<`PREFET_SIZE;i=i+1) begin
		////////prefetcher dispatch
			if(change_addr & ~inst_fetch_valid & ~next_is_haz) begin
				next_prefetcher[tail].valid			=	1'b1;
				next_prefetcher[tail].send			=	1'b0;
				next_prefetcher[tail].mem_tag			=	4'b0;
				next_prefetcher[tail].addr			=	next_addr[2];
				next_prefetcher[tail].idx			=	next_addr[2][7:3];
				next_prefetcher[tail].tag			=	next_addr[2][15:8];
				next_prefetcher[tail].wr_en			=	1'b0;
				next_prefetcher[next_possi_tail[2]].valid	=	1'b1;
				next_prefetcher[next_possi_tail[2]].send	=	1'b0;
				next_prefetcher[next_possi_tail[2]].mem_tag	=	4'b0;
				next_prefetcher[next_possi_tail[2]].addr	=	next_addr[2];
				next_prefetcher[next_possi_tail[2]].idx		=	next_addr[2][7:3];
				next_prefetcher[next_possi_tail[2]].tag		=	next_addr[2][15:8];
				next_prefetcher[next_possi_tail[2]].wr_en	=	1'b0;
				next_prefetcher[next_possi_tail[1]].valid	=	1'b1;
				next_prefetcher[next_possi_tail[1]].send	=	1'b0;
				next_prefetcher[next_possi_tail[1]].mem_tag	=	4'b0;
				next_prefetcher[next_possi_tail[1]].addr	=	next_addr[2];
				next_prefetcher[next_possi_tail[1]].idx		=	next_addr[2][7:3];
				next_prefetcher[next_possi_tail[1]].tag		=	next_addr[2][15:8];
				next_prefetcher[next_possi_tail[1]].wr_en	=	1'b0;
			end
		////////prefetcher send memory to 
		end	
////////
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset | nuke) begin
			head     	<= `SD {`PREFET_WIDTH{1'b0}};
			tail     	<= `SD {`PREFET_WIDTH{1'b0}};
			send     	<= `SD {`PREFET_WIDTH{1'b0}};
	      		last_idx  	<= `SD 5'b0;              
	      		current_tag 	<= `SD 8'b0;
			request_haz	<= `SD 1'b0;
			request_send	<= `SD 1'b0;
			is_haz		<= `SD 1'b0;
			for(int i=0;i<`PREFET_SIZE;i=i+1) begin
				prefetcher[i]	<= `SD {1'b0,		//valid
							1'b0, 		//send
							4'b0,		//mem_tag
							{`XLEN{1'b0}},	//addr
							5'b0,		//idx
							8'b0,		//tag
							64'b0,		//data
							1'b0		//write_en
							};
			end//for(int i=0;i<`PREFET_SIZE;i=i+1) begin
	    	end//if(reset | nuke) begin
		else begin
	      		last_index	<= `SD current_index;
	      		last_tag	<= `SD current_tag;
	      		head		<= `SD next_head;
	      		tail		<= `SD next_tail;
	      		send		<= `SD next_send;
	      		request_haz	<= `SD next_request_haz;
			request_send	<= `SD next_request_send;
			is_haz		<= `SD next_is_haz;
	      		prefetcher	<= `SD next_prefetcher;
	    	end//else begin
	end

endmodule
`default_nettype wire
