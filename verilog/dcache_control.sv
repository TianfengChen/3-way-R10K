//`default_nettype none
module dcache_control(
	//inputs
	input   		clock,
    	input   		reset,
////////inputs from rob, store instruction
	input	ROB_PACKET	ROB_packet_out_2,
	input	ROB_PACKET	ROB_packet_out_1,
	input 	ROB_PACKET	ROB_packet_out_0,
////////inputs coming from fu, load instruction
   	input 	[31:0] 		fu_load_addr,
   	input 	 		fu_load_en,
    	input 	[2:0]	 	fu_load_size,
////////inputs from icache controller
    	input 	[4:0] 		Dmem2proc_idx,		//The address index from icache controller
    	input 	[7:0] 		Dmem2proc_tag,		//The address tag from icache controller
   	input 	[63:0] 		Dmem2proc_data,		//The data from memory
    	input 			Dmem2proc_valid,	//If the data is to be writen in the Dcache
////////inputs from dcache
        input 	[63:0]		st_rd_data,
        input 			st_rd_valid,
        input 	[63:0] 		ld_rd_data,
        input 			ld_rd_valid,
    	//outputs
////////outputs to ROB
	output 	logic		store_commit_valid,	//when cache hit, the store inst can commit from ROB
////////outputs to fu
    	output 	logic 	[`XLEN-1:0] 	Dcache_data_out,
    	output 	logic  			Dcache_valid_out,
////////outputs to memory
	output	logic	[1:0]	load_store,		//[1,0] for load, [0,1] for store, [0,0] for BUS_NONE
   	output 	logic 	[1:0] 	proc2Dmem_command,
    	output 	logic 	[31:0]	proc2Dmem_addr,
	output 	logic	[1:0]	proc2Dmem_size,
	output 	logic	[63:0]	proc2Dmem_data,
////////outputs to the Dcache
	//store read
        output 	logic	[4:0] 	st_rd_idx,
        output	logic 	[7:0] 	st_rd_tag,
	//load read
        output 	logic	[4:0] 	ld_rd_idx,
        output 	logic	[7:0] 	ld_rd_tag,
	//store write
      	output 	logic	[4:0] 	st_wr_idx,
        output 	logic	[7:0] 	st_wr_tag,
        output 	logic	[63:0] 	st_wr_data,
        output 	logic		st_wr_en,
	//load write
        output 	logic	[4:0] 	wr_idx,
        output 	logic	[7:0] 	wr_tag,
	output 	logic	[63:0] 	wr_data, 
	output	logic		wr_en
	);
////////From ROB: determine store inst
	logic	[`N_WAY-1:0]	store_valid_array;	//determine which superscalar way is a valid store
	logic			is_store;		//determine if there is a store inst to commit
	logic	[`XLEN-1:0]	store_addr;		//the store address
	logic	[63:0]		store_data;		//the store data
	logic	[1:0]		store_size;		//the store size
	logic 	[1:0]		store_command;		//store command(bus_none if no store, bus_write if is_store)
////////From FU: determine load inst
	logic			is_load;		//determine if the load read request needs to be sent to memory
	logic	[`XLEN-1:0]	load_addr;		//the load address
	logic	[63:0]		load_data;		//the load data
	logic	[1:0]		load_size;		//the load size
	logic 	[1:0]		load_command;		//load command(bus_none if no load or load hit, bus_load if load miss)
////////Store commit
	//get store inst from ROB_packet when commit
	assign	store_valid_array[2] = ROB_packet_out_2.valid & ROB_packet_out_2.commit & ROB_packet_out_2.id_packet.wr_mem;
	assign	store_valid_array[1] = ROB_packet_out_1.valid & ROB_packet_out_1.commit & ROB_packet_out_1.id_packet.wr_mem;
	assign	store_valid_array[0] = ROB_packet_out_0.valid & ROB_packet_out_0.commit & ROB_packet_out_0.id_packet.wr_mem;
	assign 	is_store 	= store_valid_array[2] | store_valid_array[1] | store_valid_array[0];
	assign	store_addr 	= store_valid_array[2] ? ROB_packet_out_2.proc2mem_addr : (store_valid_array[1] ? ROB_packet_out_1.proc2mem_addr : (store_valid_array[0] ? ROB_packet_out_1.proc2mem_addr : {`XLEN{1'b0}}));
	assign	store_data 	= store_valid_array[2] ? ROB_packet_out_2.proc2mem_data : (store_valid_array[1] ? ROB_packet_out_1.proc2mem_data : (store_valid_array[0] ? ROB_packet_out_1.proc2mem_data : 64'b0));	
	assign	store_size	= store_valid_array[2] ? ROB_packet_out_2.proc2mem_size[1:0] : (store_valid_array[1] ? ROB_packet_out_1.proc2mem_size[1:0] : (store_valid_array[0] ? ROB_packet_out_1.proc2mem_size[1:0] : DOUBLE));	
	assign 	store_command	= is_store ? (st_rd_valid ? BUS_STORE : BUS_LOAD) : BUS_NONE;
	assign	store_commit_valid = st_rd_valid;
	//get store inst index & tag
	assign 	st_rd_idx	= store_addr[7:3];
	assign 	st_rd_tag	= store_addr[15:8];
	//get store read information from Dcache and write back to Dcache 
	assign	st_wr_en	= is_store & st_rd_valid;
	assign	st_wr_idx	= st_rd_idx;
	assign	st_wr_tag	= st_rd_tag;
	always_comb begin
		if(st_wr_en) begin
			casez(store_size)
				BYTE : begin
					st_wr_data = store_addr[2] ? 	(store_addr[1] ? 	(store_addr[0] ? {store_data[7:0],st_rd_data[55:0]} : {st_rd_data[63:56],store_data[7:0],st_rd_data[47:0]}) : 
												(store_addr[0] ? {st_rd_data[63:48],store_data[7:0],st_rd_data[39:0]} : {st_rd_data[63:40],store_data[7:0],st_rd_data[31:0]})) : 
									(store_addr[1] ? 	(store_addr[0] ? {st_rd_data[63:32],store_data[7:0],st_rd_data[23:0]} : {st_rd_data[63:24],store_data[7:0],st_rd_data[15:0]}) : 
												(store_addr[0] ? {st_rd_data[63:16],store_data[7:0],st_rd_data[7:0]} : {st_rd_data[63:8],store_data[7:0]}));
				end
				HALF : begin
					st_wr_data = store_addr[2] ? 	(store_addr[1] ? {store_data[15:0],st_rd_data[47:0]} : {st_rd_data[63:48],store_data[15:0],st_rd_data[31:0]}) : 
									(store_addr[1] ? {st_rd_data[63:32],store_data[15:0],st_rd_data[15:0]} : {st_rd_data[63:16],store_data[15:0]});
				end
				WORD : begin
					st_wr_data = store_addr[2] ? 	{store_data[31:0],st_rd_data[31:0]} : {st_rd_data[63:32],store_data[31:0]};
				end
				DOUBLE : begin
					st_wr_data = store_data;
				end
				default : begin
					st_wr_data = 64'b0;
				end
			endcase
		end//if(st_wr_en) begin
		else begin
			st_wr_data = 64'b0;
		end//else begin
	end
////////Load execution
	//get load inst index & tag
	assign 	ld_rd_idx	= fu_load_addr[7:3];
	assign 	ld_rd_tag	= fu_load_addr[15:8];
	//determine load output to FU
	assign	Dcache_valid_out= fu_load_en & ld_rd_valid;
	always_comb begin
		if(Dcache_valid_out) begin
			if(~fu_load_size[2]) begin	//is this an signed/unsigned load?
				casez(fu_load_size[1:0])
					BYTE : begin
						Dcache_data_out = load_addr[2] ? 	(load_addr[1] ? (load_addr[0] ? {{(`XLEN-8){ld_rd_data[63]}}, ld_rd_data[63:56]} : {{(`XLEN-8){ld_rd_data[55]}}, ld_rd_data[55:48]}) : 
													(load_addr[0] ? {{(`XLEN-8){ld_rd_data[47]}}, ld_rd_data[47:40]} : {{(`XLEN-8){ld_rd_data[39]}}, ld_rd_data[39:32]})) : 
											(load_addr[1] ? (load_addr[0] ? {{(`XLEN-8){ld_rd_data[31]}}, ld_rd_data[31:24]} : {{(`XLEN-8){ld_rd_data[23]}}, ld_rd_data[23:16]}) : 
													(load_addr[0] ? {{(`XLEN-8){ld_rd_data[15]}}, ld_rd_data[15:8]} : {{(`XLEN-8){ld_rd_data[7]}}, ld_rd_data[7:0]}));
					end
					HALF : begin
						Dcache_data_out = load_addr[2] ? 	(load_addr[1] ? {{(`XLEN-16){ld_rd_data[63]}}, ld_rd_data[63:48]} : {{(`XLEN-16){ld_rd_data[47]}}, ld_rd_data[47:32]}) : 
											(load_addr[1] ? {{(`XLEN-16){ld_rd_data[31]}}, ld_rd_data[31:16]} : {{(`XLEN-16){ld_rd_data[15]}}, ld_rd_data[15:0]});
					end
					WORD : begin
						Dcache_data_out = load_addr[2] ? ld_rd_data[63:32] : ld_rd_data[31:0];
					end
					default : begin
						Dcache_data_out = 32'b0;
					end
				endcase
			end//if(fu_load_size[2]) begin
			else begin
				casez(fu_load_size[1:0])
					BYTE : begin
						Dcache_data_out = load_addr[2] ? 	(load_addr[1] ? (load_addr[0] ? {{(`XLEN-8){1'b0}}, ld_rd_data[63:56]} : {{(`XLEN-8){1'b0}}, ld_rd_data[55:48]}) : 
													(load_addr[0] ? {{(`XLEN-8){1'b0}}, ld_rd_data[47:40]} : {{(`XLEN-8){1'b0}}, ld_rd_data[39:32]})) : 
											(load_addr[1] ? (load_addr[0] ? {{(`XLEN-8){1'b0}}, ld_rd_data[31:24]} : {{(`XLEN-8){1'b0}}, ld_rd_data[23:16]}) : 
													(load_addr[0] ? {{(`XLEN-8){1'b0}}, ld_rd_data[15:8]} : {{(`XLEN-8){1'b0}}, ld_rd_data[7:0]}));
					end
					HALF : begin
						Dcache_data_out = load_addr[2] ? 	(load_addr[1] ? {{(`XLEN-16){1'b0}}, ld_rd_data[63:48]} : {{(`XLEN-16){1'b0}}, ld_rd_data[47:32]}) : 
											(load_addr[1] ? {{(`XLEN-16){1'b0}}, ld_rd_data[31:16]} : {{(`XLEN-16){1'b0}}, ld_rd_data[15:0]});
					end
					WORD : begin
						Dcache_data_out = load_addr[2] ? ld_rd_data[63:32] :  ld_rd_data[31:0];
					end
					default : begin
						Dcache_data_out = 32'b0;
					end
				endcase
			end//else begin
		end//if(st_wr_en) begin
		else begin
			Dcache_data_out = 32'b0;
		end//else begin
	end
	//determine load read request to memory
	assign	is_load		= fu_load_en & ~ld_rd_valid;
	assign	load_addr	= fu_load_addr;
	assign	load_data	= 64'b0;
	assign	load_size	= fu_load_size[1:0];
	assign	load_command	= is_load ? BUS_LOAD : BUS_NONE;
	//determine the load write to Dcache
	assign	wr_idx		= Dmem2proc_idx;
        assign	wr_tag		= Dmem2proc_tag;
	assign 	wr_data		= Dmem2proc_data; 
	assign	wr_en		= Dmem2proc_valid;
////////request to memory
	assign	load_store	= is_store ? 2'b01 : (is_load ? 2'b10 : 2'b00);
	always_comb begin
		casez(load_store)
			2'b01 : begin	//store sent to mem
				proc2Dmem_command 	= store_command;
    				proc2Dmem_addr		= store_addr;
				proc2Dmem_size		= store_size;
				proc2Dmem_data		= st_rd_valid ? st_wr_data : store_data;
			end
			2'b10 : begin	//load sent to mem
				proc2Dmem_command 	= load_command;
    				proc2Dmem_addr		= load_addr;
				proc2Dmem_size		= load_size;
				proc2Dmem_data		= load_data;
			end
			2'b00 : begin	//none sent to mem
				proc2Dmem_command 	= BUS_NONE;
    				proc2Dmem_addr		= {`XLEN{1'b0}};
				proc2Dmem_size		= DOUBLE;
				proc2Dmem_data		= 64'B0;
			end
			default : begin
				proc2Dmem_command 	= BUS_NONE;
    				proc2Dmem_addr		= {`XLEN{1'b0}};
				proc2Dmem_size		= DOUBLE;
				proc2Dmem_data		= 64'B0;
			end
		endcase
	end
endmodule
//`default_nettype wire

