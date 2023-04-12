module dcache_array(
	input 									clk,
	input 									rst_n,
	input 		[`XLEN-1:0]					addr,
	input		[2:0]						size,
	input  		[`DCACHE_BLOCK_WIDTH-1:0] 	refill_line,
	input									refill_en,
	input 		[`XLEN-1:0]					st_data,
	input									st_en,
	output 					 				hit,  
	output 					 				dirty,  
	input 		[`XLEN-1:0]					dirty_addr,
	output	reg	[`XLEN-1:0] 				rd_data 
);

	wire 	[`DCACHE_OFFSET_WIDTH-1:0] 	addr_offset;
	wire 	[`DCACHE_INDEX_WIDTH-1:0] 	addr_index;
	wire 	[`DCACHE_TAG_WIDTH-1:0] 	addr_tag;
	reg 	[`DCACHE_OFFSET_WIDTH-1:0] 	addr_offset_pipe;
	reg 	[`DCACHE_INDEX_WIDTH-1:0] 	addr_index_pipe;
	reg 	[`DCACHE_TAG_WIDTH-1:0] 	addr_tag_pipe;
	reg		[2:0]						size_pipe;

	wire 	[`DCACHE_TAG_WIDTH-1:0] 	rd_tag_N			[0:`DCACHE_WAY_NUM-1];
	wire 	[`DCACHE_BLOCK_WIDTH-1:0] 	rd_block_N		[0:`DCACHE_WAY_NUM-1];
	reg 	[`DCACHE_WAY_NUM-1:0]		rd_valid_N;	
	reg 	[`DCACHE_WAY_NUM-1:0]		rd_dirty_N;	
	wire 	[`DCACHE_WAY_NUM-1:0]		hit_N;
	wire 	[`DCACHE_WAY_NUM-1:0]		wen_N;
	wire 	[`DCACHE_WAY_NUM-1:0]		access_N;			//which way is being accessed (rd/wr)

	wire	[7:0]						rd_data_byte;	
	wire	[15:0]						rd_data_half;	
	wire	[31:0]						rd_data_word;	
	wire 	[`DCACHE_BLOCK_WIDTH-1:0] 	rd_block;	
	reg		[`DCACHE_BLOCK_WIDTH-1:0] 	wr_block;	

	reg									lru_tree_0			[0:`DCACHE_SET_NUM-1];
	reg		[1:0]						lru_tree_1			[0:`DCACHE_SET_NUM-1];
	reg 	[`DCACHE_WAY_WIDTH-1:0]		lru_way				[0:`DCACHE_SET_NUM-1];	//which is the lru way


	assign addr_offset 	= 	addr[`DCACHE_OFFSET_WIDTH-1:0];
	assign addr_index 	= 	addr[`DCACHE_OFFSET_WIDTH+:`DCACHE_INDEX_WIDTH];
	assign addr_tag 	= 	addr[(`DCACHE_OFFSET_WIDTH+`DCACHE_INDEX_WIDTH)+:`DCACHE_TAG_WIDTH];


	assign hit 				= 	hit_N!=0;
	assign dirty			=	rd_dirty_N[lru_way[addr_index_pipe]];
	assign dirty_addr		=	{rd_tag_N[lru_way[addr_index_pipe]],addr_index_pipe,{`DCACHE_OFFSET_WIDTH{1'b0}}};
	assign access_N 		= 	hit_N | wen_N;

    //assign rd_data_byte 	= 	refill_en ? refill_line[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:0]*8+:8]   : rd_block[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:0]*8+:8];
	//assign rd_data_half 	= 	refill_en ? refill_line[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:1]*16+:16] : rd_block[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:1]*16+:16];
	//assign rd_data_word 	= 	refill_en ? refill_line[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:2]*32+:32] : rd_block[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:2]*32+:32];

    assign rd_data_byte 	= 	rd_block[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:0]*8+:8];
	assign rd_data_half 	= 	rd_block[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:1]*16+:16];
	assign rd_data_word 	= 	rd_block[addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:2]*32+:32];

	always@(*) begin
		case(MEM_SIZE'(size_pipe[1:0]))
			BYTE:rd_data = 	~size_pipe[2] ? 
							{{(`XLEN-8){rd_data_byte[7]}}, rd_data_byte} :
							{{(`XLEN-8){1'b0}}, rd_data_byte} ;
			HALF:rd_data = 	~size_pipe[2] ? 
							{{(`XLEN-8){rd_data_half[15]}}, rd_data_half} :
							{{(`XLEN-8){1'b0}}, rd_data_half} ;
			WORD:rd_data = 	rd_data_word;
		endcase
	end


	always@(*) begin
        if(refill_en) begin
            if(st_en) begin
			    wr_block = refill_line;
		        case(MEM_SIZE'(size[1:0]))
		        	BYTE:wr_block[addr_offset[`DCACHE_OFFSET_WIDTH-1:0]*8+:8]   = st_data[7:0]; 
		        	HALF:wr_block[addr_offset[`DCACHE_OFFSET_WIDTH-1:1]*16+:16] = st_data[15:0]; 
		        	WORD:wr_block[addr_offset[`DCACHE_OFFSET_WIDTH-1:2]*32+:32] = st_data[31:0]; 
		        endcase
            end
            else
			    wr_block = refill_line;
        end
        else begin
			wr_block = rd_block;
		    case(MEM_SIZE'(size[1:0]))
		    	BYTE:wr_block[addr_offset[`DCACHE_OFFSET_WIDTH-1:0]*8+:8]   = st_data[7:0]; 
		    	HALF:wr_block[addr_offset[`DCACHE_OFFSET_WIDTH-1:1]*16+:16] = st_data[15:0]; 
		    	WORD:wr_block[addr_offset[`DCACHE_OFFSET_WIDTH-1:2]*32+:32] = st_data[31:0]; 
		    endcase
        end
		
	end


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			addr_offset_pipe 	<= 0;
			addr_index_pipe	 	<= 0;
			addr_tag_pipe 		<= 0;
			size_pipe	    	<= 0;
		end
		else begin
			addr_offset_pipe	<= addr_offset;
			addr_index_pipe 	<= addr_index;
			addr_tag_pipe 		<= addr_tag;	
			size_pipe		    <= size;	
		end
	end


	mux_onehot #(
		.INPUT_NUM(`DCACHE_WAY_NUM),	
		.DATA_WIDTH(`DCACHE_BLOCK_WIDTH))	
	icache_way_mux(
		.onehot(hit_N),				
		.i_data(rd_block_N),					
		.o_data(rd_block)						
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
		//					lru_tree_1[1] 	= 0
		//
		//find the lru way: lru_tree_0 = 0 indicates going up, lru_tree_1[0] = 1 indicates going down
		//so the lru way is way1
		//
		//after filling the cache line:  lru_tree_0: 0->1; lru_tree_1[0]: 1->0 
   		/*************************LRU Algorithm*******************************/

		for(i=0;i<`DCACHE_SET_NUM;i=i+1) begin
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
		reg [`DCACHE_SET_NUM-1:0]	block_valid	[0:`DCACHE_WAY_NUM-1];	//store valid bit in a separate register instead of tag sram
		reg [`DCACHE_SET_NUM-1:0]	block_dirty	[0:`DCACHE_WAY_NUM-1];	//store dirty bit in a separate register instead of tag sram

		for(i=0;i<`DCACHE_WAY_NUM;i=i+1) begin
			//set valid bit if data is written to this block
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					block_valid[i] <= 0;
				else if(wen_N[i])
					block_valid[i][addr_index] <= 1; 
			end
		
			//set dirty bit if the block is modified, clear at refill
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n)
					block_dirty[i] <= 0;
				else if(wen_N[i] && st_en)
					block_dirty[i][addr_index] <= 1;
				else if(wen_N[i] && refill_en)
					block_dirty[i] <= 0;	
			end
		
			//access valid/dirty bit
			always@(posedge clk or negedge rst_n) begin
				if(~rst_n) begin
					rd_valid_N[i] <= 0;
					rd_dirty_N[i] <= 0;
				end
                else if(wen_N[i]) begin
                    rd_valid_N[i] <= 1;
					rd_dirty_N[i] <= 1;
                end
                else begin
                    rd_valid_N[i] <= block_valid[i][addr_index];
					rd_dirty_N[i] <= block_dirty[i][addr_index];
                end
			end

			//access tag
			sram #(
				.WIDTH(`DCACHE_TAG_WIDTH),
				.DEPTH(`DCACHE_SET_NUM))
			tag_sram(
 				.clk		(clk			),
 				.wr_data	(addr_tag		),
				.addr		(addr_index		),
				.wen		(wen_N[i]		),
 				.rd_data	(rd_tag_N[i]	)						
			);

			//access data
			sram #(
				.WIDTH(`DCACHE_BLOCK_WIDTH),
				.DEPTH(`DCACHE_SET_NUM))
			data_sram(
 				.clk		(clk			),
 				.wr_data	(wr_block		),
				.addr		(addr_index		),
				.wen		(wen_N[i]		),
 				.rd_data	(rd_block_N[i]	)						
			);



			//assign hit_N[i] = (rd_tag_N[i]==addr_tag_pipe && rd_valid_N[i]) || wen_N[i];
			assign hit_N[i] = rd_tag_N[i]==addr_tag_pipe && rd_valid_N[i];
			assign wen_N[i] = hit ? (st_en || refill_en) && hit_N[i] : (st_en || refill_en) && i==lru_way[addr_index];
		end


   		/*************************rd_block_mask***************************/
		//for(i=0;i<`DCACHE_WORD_NUM;i=i+1) begin
		//	assign rd_block_mask[i] = (addr_offset_pipe[`DCACHE_OFFSET_WIDTH-1:2] <= i) && hit;
		//end
	


	endgenerate


	//icache access must be 32bit aligned 
	//assert property (@(posedge clk) rst_n==1 |-> addr[1:0] == 2'b00);
endmodule
