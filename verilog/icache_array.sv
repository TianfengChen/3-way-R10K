module icache_array(
	input 								clk,
	input 								rst_n,
	input 	[`XLEN-1:0]					addr,
	input  	[`ICACHE_BLOCK_WIDTH-1:0] 	wr_block,
	input								wen,
	output 					 			hit,  
	output 	[`ICACHE_BLOCK_WIDTH-1:0] 	rd_block, 
	output 	[`ICACHE_WORD_NUM-1:0] 		rd_block_mask  //32bit granularity
);

	wire 	[`ICACHE_OFFSET_WIDTH-1:0] 	addr_offset;
	wire 	[`ICACHE_INDEX_WIDTH-1:0] 	addr_index;
	wire 	[`ICACHE_TAG_WIDTH-1:0] 	addr_tag;
	reg 	[`ICACHE_OFFSET_WIDTH-1:0] 	addr_offset_pipe;
	reg 	[`ICACHE_INDEX_WIDTH-1:0] 	addr_index_pipe;
	reg 	[`ICACHE_TAG_WIDTH-1:0] 	addr_tag_pipe;


	wire 	[`ICACHE_TAG_WIDTH-1:0] 	cache_tag_N			[0:`ICACHE_WAY_NUM-1];
	wire 	[`ICACHE_BLOCK_WIDTH-1:0] 	cache_block_data_N	[0:`ICACHE_WAY_NUM-1];
	reg 	[`ICACHE_WAY_NUM-1:0]		block_valid_N;	
	wire 	[`ICACHE_WAY_NUM-1:0]		hit_N;
	wire 	[`ICACHE_WAY_NUM-1:0]		wen_N;
	wire 	[`ICACHE_WAY_NUM-1:0]		access_N;		//which way is being accessed (rd/wr)
	
	wire 	[`ICACHE_BLOCK_WIDTH-1:0] 	cache_block_data;

	reg									lru_tree_0			[0:`ICACHE_SET_NUM-1];
	reg		[1:0]						lru_tree_1			[0:`ICACHE_SET_NUM-1];
	reg 	[`ICACHE_WAY_WIDTH-1:0]		lru_way				[0:`ICACHE_SET_NUM-1];	//which is the lru way

	assign addr_offset 	= addr[`ICACHE_OFFSET_WIDTH-1:0];
	assign addr_index 	= addr[`ICACHE_OFFSET_WIDTH+:`ICACHE_INDEX_WIDTH];
	assign addr_tag 	= addr[(`ICACHE_OFFSET_WIDTH+`ICACHE_INDEX_WIDTH)+:`ICACHE_TAG_WIDTH];

	assign hit = hit_N != 0 | wen;
	assign access_N = hit_N | wen_N;
	assign rd_block = 	wen ? wr_block 			: 
						hit ? cache_block_data 	: 0;

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			addr_offset_pipe 	<= 0;
			addr_index_pipe	 	<= 0;
			addr_tag_pipe 		<= 0;
		end
		else begin
			addr_offset_pipe	<= addr_offset;
			addr_index_pipe 	<= addr_index;
			addr_tag_pipe 		<= addr_tag;		
		end
	end


	mux_onehot #(
		.INPUT_NUM(`ICACHE_WAY_NUM),	
		.DATA_WIDTH(`ICACHE_BLOCK_WIDTH))	
	icache_way_mux(
		.onehot(hit_N),				
		.i_data(cache_block_data_N),					
		.o_data(cache_block_data)						
	);



	genvar i;
	generate
   		/*************************LRU Algorithm*******************************/
		//
        //			
		//							   way0
		//							 / 
        //				lru_tree_1[0]
        //			  /				 \ 
        //			 /				   way1
		//	lru_tree_0				   
        //		   	 \				   way2
		//			  \              /
		//			    lru_tree_1[1]
		//							 \ 
		//							   way3
		//
		//EXAMPLE:
		//inital condition: lru_tree_0 		= 0
		//					lru_tree_1[0] 	= 1
		//					lru_tree_1[0] 	= 0
		//
		//find the lru way: lru_tree_0 = 0 indicates going up, lru_tree_1[0] = 1 indicates going down
		//so the lru way is way1
		//
		//after filling the cache line:  lru_tree_0: 0->1; lru_tree_1[0]: 1->0 
   		/*************************LRU Algorithm*******************************/

		for(i=0;i<`ICACHE_SET_NUM;i=i+1) begin
			always@(*) begin
				if(addr_index == i) begin
					casez({lru_tree_0[i],lru_tree_1[i]})
						3'b0?0:		lru_way[i] = 0;
						3'b0?1:		lru_way[i] = 1;
						3'b10?:		lru_way[i] = 2;
						3'b11?:		lru_way[i] = 3;
						default:	lru_way[i] = 0;
					endcase
				end
				else
					lru_way[i] = 0;
			end 
    		
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) begin
					lru_tree_0[i] <= 0;
					lru_tree_1[i] <= 0;
				end
				else if(addr_index == i)begin
					case(access_N)
						4'b0001: begin	
							lru_tree_0[i]		<= 1;
							lru_tree_1[i][0]	<= 1;
						end
						4'b0010: begin	
							lru_tree_0[i] 		<= 1;
							lru_tree_1[i][0] 	<= 0;
						end
						4'b0100: begin	
							lru_tree_0[i] 		<= 0;
							lru_tree_1[i][1] 	<= 1;
						end
						4'b1000: begin	
							lru_tree_0[i] 		<= 0;
							lru_tree_1[i][1] 	<= 0;
						end
						default: begin
							lru_tree_0[i]		<= lru_tree_0[i];
							lru_tree_1[i]		<= lru_tree_1[i];
						end
					endcase
				end
			end
		end


   		/*************************Cache SRAM*******************************/
		reg [`ICACHE_SET_NUM-1:0]	block_valid	[0:`ICACHE_WAY_NUM-1];	//store valid bit in a separate register instead of tag sram

		for(i=0;i<`ICACHE_WAY_NUM;i=i+1) begin
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					block_valid[i] <= 0;
				else if(wen_N[i])
					block_valid[i][addr_index] <= 1; 
			end

			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					block_valid_N[i] <= 0;
				else 
					block_valid_N[i] <= block_valid[i][addr_index];
			end

			sram #(
				.WIDTH(`ICACHE_TAG_WIDTH),
				.DEPTH(`ICACHE_SET_NUM))
			tag_sram(
 				.clk		(clk			),
 				.wr_data	(addr_tag		),
				.addr		(addr_index		),
				.wen		(wen_N[i]		),
 				.rd_data	(cache_tag_N[i]	)						
			);

			sram #(
				.WIDTH(`ICACHE_BLOCK_WIDTH),
				.DEPTH(`ICACHE_SET_NUM))
			data_sram(
 				.clk		(clk					),
 				.wr_data	(wr_block				),
				.addr		(addr_index				),
				.wen		(wen_N[i]				),
 				.rd_data	(cache_block_data_N[i]	)						
			);



			//assign hit_N[i] = ((cache_tag_N[i] == addr_tag_pipe) & (block_valid_N[i] == 1)) | (wen_N[i] == 1); //avoid comb loop, forwarded hit should not depends on addr;	
			assign hit_N[i] = (cache_tag_N[i] == addr_tag_pipe) & (block_valid_N[i] == 1); //avoid comb loop	
			assign wen_N[i] = wen & lru_way[addr_index]==i;
		end


   		/*************************rd_block_mask***************************/
		for(i=0;i<`ICACHE_WORD_NUM;i=i+1) begin
			assign rd_block_mask[i] = (addr_offset_pipe[`ICACHE_OFFSET_WIDTH-1:2] <= i) && hit;
		end
	


	endgenerate


	//icache access must be 32bit aligned 
	assert property (@(posedge clk) rst_n==1 |-> addr[1:0] == 2'b00);
endmodule
