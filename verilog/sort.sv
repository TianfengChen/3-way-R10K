`timescale 1ns/100ps

module sort #(
	parameter REQ_NUM = 16,	//must be 32/16/8/4	
	parameter DATA_WIDTH = 6
)
(
	input		[REQ_NUM-1:0]		req,
	input		[DATA_WIDTH-1:0] 	i_data		[0:REQ_NUM-1],
	input		[REQ_NUM-1:0]		i_pos,
 	output reg	[REQ_NUM-1:0]		gnt,
	output reg 	[DATA_WIDTH-1:0] 	o_data
);



	reg [DATA_WIDTH-1:0] data_tmp_5 [0:32-1];
	reg [DATA_WIDTH-1:0] data_tmp_4 [0:16-1];
	reg [DATA_WIDTH-1:0] data_tmp_3 [0:8-1];
	reg [DATA_WIDTH-1:0] data_tmp_2 [0:4-1];
	reg [DATA_WIDTH-1:0] data_tmp_1 [0:2-1];
	reg [DATA_WIDTH-1:0] data_tmp_0 [0:1-1];

	reg [$clog2(REQ_NUM)-1:0] idx_tmp_5 [0:32-1];
	reg [$clog2(REQ_NUM)-1:0] idx_tmp_4 [0:16-1];
	reg [$clog2(REQ_NUM)-1:0] idx_tmp_3 [0:8-1];
	reg [$clog2(REQ_NUM)-1:0] idx_tmp_2 [0:4-1];
	reg [$clog2(REQ_NUM)-1:0] idx_tmp_1 [0:2-1];
	reg [$clog2(REQ_NUM)-1:0] idx_tmp_0 [0:1-1];

	wire [32-1:0]	req_tmp_5;
	wire [16-1:0]	req_tmp_4;
	wire [8-1:0] 	req_tmp_3;
	wire [4-1:0] 	req_tmp_2;
	wire [2-1:0] 	req_tmp_1;
	wire [1-1:0] 	req_tmp_0;

	reg [32-1:0]	pos_tmp_5;
	reg [16-1:0]	pos_tmp_4;
	reg [8-1:0] 	pos_tmp_3;
	reg [4-1:0] 	pos_tmp_2;
	reg [2-1:0] 	pos_tmp_1;
	reg [1-1:0] 	pos_tmp_0;

	assign o_data = data_tmp_0[0];



	genvar i;
	generate 
		/***********************************generate gnt************************************/
		for(i=0;i<REQ_NUM;i=i+1) begin
			assign gnt[i] = (i==idx_tmp_0[0] & req_tmp_0[0]) ? 1'b1 : 1'b0;
		end



		/******************************assign comparator tree input ********************************/
		case(REQ_NUM)
			32: begin	
				assign data_tmp_5 	= i_data;
				assign pos_tmp_5 	= i_pos;
				assign req_tmp_5 	= req;
				for(i=0;i<REQ_NUM;i=i+1) 
					assign idx_tmp_5[i] = i;
			end			
			16: begin	
				assign data_tmp_4 	= i_data;
				assign pos_tmp_4 	= i_pos;
				assign req_tmp_4 	= req;
				for(i=0;i<REQ_NUM;i=i+1) 
					assign idx_tmp_4[i] = i;
			end
			8: begin	
				assign data_tmp_3 	= i_data;
				assign pos_tmp_3 	= i_pos;
				assign req_tmp_3 	= req;
				for(i=0;i<REQ_NUM;i=i+1) 
					assign idx_tmp_3[i] = i;				
			end
			4: begin	
				assign data_tmp_2 	= i_data;
				assign pos_tmp_2 	= i_pos;
				assign req_tmp_2 	= req;
				for(i=0;i<REQ_NUM;i=i+1) 
					assign idx_tmp_2[i] = i;				
			end
			default: begin	
				assign data_tmp_4 	= i_data;
				assign pos_tmp_4 	= i_pos;
				assign req_tmp_4 	= req;
				for(i=0;i<REQ_NUM;i=i+1) 
					assign idx_tmp_4[i] = i;				
			end
		endcase



		/***********************************comparator tree*****************************************/	
		if(REQ_NUM > 16) begin
			for(i=0;i<16;i=i+1) begin
	   			always@(*) begin	
					case({req_tmp_5[i*2],req_tmp_5[i*2+1]})	
						2'b00: begin
							data_tmp_4[i] 	= 0;
							pos_tmp_4[i] 	= 0;
							idx_tmp_4[i] 	= 0;
						end
						2'b01: begin 
							data_tmp_4[i] 	= data_tmp_5[i*2+1];
							pos_tmp_4[i] 	= pos_tmp_5[i*2+1];
							idx_tmp_4[i] 	= idx_tmp_5[i*2+1];
						end
						2'b10: begin 
							data_tmp_4[i] 	= data_tmp_5[i*2];
							pos_tmp_4[i] 	= pos_tmp_5[i*2];
							idx_tmp_4[i] 	= idx_tmp_5[i*2];
						end
						2'b11: begin 
							data_tmp_4[i] 	= pos_tmp_5[i*2]==pos_tmp_5[i*2+1] ?	
											  (data_tmp_5[i*2]<data_tmp_5[i*2+1] ? data_tmp_5[i*2] : data_tmp_5[i*2+1]) :
											  (data_tmp_5[i*2]>data_tmp_5[i*2+1] ? data_tmp_5[i*2] : data_tmp_5[i*2+1]) ;
							idx_tmp_4[i] 	= pos_tmp_5[i*2]==pos_tmp_5[i*2+1] ?
											  (data_tmp_5[i*2]<data_tmp_5[i*2+1] ? idx_tmp_5[i*2] : idx_tmp_5[i*2+1]) :
											  (data_tmp_5[i*2]>data_tmp_5[i*2+1] ? idx_tmp_5[i*2] : idx_tmp_5[i*2+1]) ;
						end
					endcase
				end
				assign req_tmp_4[i] = req_tmp_5[i*2] | req_tmp_5[i*2+1];
			end
		end

		if(REQ_NUM > 8) begin
			for(i=0;i<8;i=i+1) begin
	   			always@(*) begin	
					case({req_tmp_4[i*2],req_tmp_4[i*2+1]})	
						2'b00: begin
							data_tmp_3[i] 	= 0;
							pos_tmp_3[i] 	= 0;
							idx_tmp_3[i] 	= 0;
						end
						2'b01: begin 
							data_tmp_3[i] 	= data_tmp_4[i*2+1];
							pos_tmp_3[i] 	= pos_tmp_4[i*2+1];
							idx_tmp_3[i] 	= idx_tmp_4[i*2+1];
						end
						2'b10: begin 
							data_tmp_3[i] 	= data_tmp_4[i*2];
							pos_tmp_3[i] 	= pos_tmp_4[i*2];
							idx_tmp_3[i] 	= idx_tmp_4[i*2];
						end
						2'b11: begin 
							data_tmp_3[i] 	= pos_tmp_4[i*2]==pos_tmp_4[i*2+1] ? 
											  (data_tmp_4[i*2]<data_tmp_4[i*2+1] ? data_tmp_4[i*2] : data_tmp_4[i*2+1]) :
											  (data_tmp_4[i*2]>data_tmp_4[i*2+1] ? data_tmp_4[i*2] : data_tmp_4[i*2+1]) ;
							idx_tmp_3[i] 	= pos_tmp_4[i*2]==pos_tmp_4[i*2+1] ?
											  (data_tmp_4[i*2]<data_tmp_4[i*2+1] ? idx_tmp_4[i*2] : idx_tmp_4[i*2+1]) :
											  (data_tmp_4[i*2]>data_tmp_4[i*2+1] ? idx_tmp_4[i*2] : idx_tmp_4[i*2+1]) ;
						end
					endcase
				end
				assign req_tmp_3[i] = req_tmp_4[i*2] | req_tmp_4[i*2+1];
			end
		end

		if(REQ_NUM > 4) begin
			for(i=0;i<4;i=i+1) begin 
	   			always@(*) begin	
					case({req_tmp_3[i*2],req_tmp_3[i*2+1]})	
						2'b00: begin
							data_tmp_2[i] 	= 0;
							pos_tmp_2[i] 	= 0;
							idx_tmp_2[i] 	= 0;
						end
						2'b01: begin 
							data_tmp_2[i] 	= data_tmp_3[i*2+1];
							pos_tmp_2[i] 	= pos_tmp_3[i*2+1];
							idx_tmp_2[i] 	= idx_tmp_3[i*2+1];
						end
						2'b10: begin 
							data_tmp_2[i] 	= data_tmp_3[i*2];
							pos_tmp_2[i] 	= pos_tmp_3[i*2];
							idx_tmp_2[i] 	= idx_tmp_3[i*2];
						end
						2'b11: begin 
							data_tmp_2[i] 	= pos_tmp_3[i*2]==pos_tmp_3[i*2+1] ? 
											  (data_tmp_3[i*2]<data_tmp_3[i*2+1] ? data_tmp_3[i*2] : data_tmp_3[i*2+1]) :
											  (data_tmp_3[i*2]>data_tmp_3[i*2+1] ? data_tmp_3[i*2] : data_tmp_3[i*2+1]) ;
							idx_tmp_2[i] 	= pos_tmp_3[i*2]==pos_tmp_3[i*2+1] ? 
											  (data_tmp_3[i*2]<data_tmp_3[i*2+1] ? idx_tmp_3[i*2] : idx_tmp_3[i*2+1]) :
											  (data_tmp_3[i*2]>data_tmp_3[i*2+1] ? idx_tmp_3[i*2] : idx_tmp_3[i*2+1]) ;
						end
					endcase
				end
				assign req_tmp_2[i] = req_tmp_3[i*2] | req_tmp_3[i*2+1];
			end
		end

		for(i=0;i<2;i=i+1) begin 
	   		always@(*) begin	
				case({req_tmp_2[i*2],req_tmp_2[i*2+1]})	
					2'b00: begin
						data_tmp_1[i] 	= 0;
						pos_tmp_1[i] 	= 0;
						idx_tmp_1[i] 	= 0;
					end
					2'b01: begin 
						data_tmp_1[i] 	= data_tmp_2[i*2+1];
						pos_tmp_1[i] 	= pos_tmp_2[i*2+1];
						idx_tmp_1[i] 	= idx_tmp_2[i*2+1];
					end
					2'b10: begin
						data_tmp_1[i] 	= data_tmp_2[i*2];
						pos_tmp_1[i] 	= pos_tmp_2[i*2];
						idx_tmp_1[i] 	= idx_tmp_2[i*2];
					end
					2'b11: begin 
						data_tmp_1[i] 	= pos_tmp_2[i*2]==pos_tmp_2[i*2+1] ? 
										  (data_tmp_2[i*2]<data_tmp_2[i*2+1] ? data_tmp_2[i*2] : data_tmp_2[i*2+1]) :
										  (data_tmp_2[i*2]>data_tmp_2[i*2+1] ? data_tmp_2[i*2] : data_tmp_2[i*2+1]) ;
						idx_tmp_1[i] 	= pos_tmp_2[i*2]==pos_tmp_2[i*2+1] ?
										  (data_tmp_2[i*2]<data_tmp_2[i*2+1] ? idx_tmp_2[i*2] : idx_tmp_2[i*2+1]) :
										  (data_tmp_2[i*2]>data_tmp_2[i*2+1] ? idx_tmp_2[i*2] : idx_tmp_2[i*2+1]) ;
					end
				endcase
			end
			assign req_tmp_1[i] = req_tmp_2[i*2] | req_tmp_2[i*2+1];
		end

		for(i=0;i<1;i=i+1) begin 
	   		always@(*) begin	
				case({req_tmp_1[i*2],req_tmp_1[i*2+1]})	
					2'b00: begin
						data_tmp_0[i] 	= 0;
						pos_tmp_0[i] 	= 0;
						idx_tmp_0[i] 	= 0;
					end
					2'b01: begin 
						data_tmp_0[i] 	= data_tmp_1[i*2+1];
						pos_tmp_0[i] 	= pos_tmp_1[i*2+1];
						idx_tmp_0[i] 	= idx_tmp_1[i*2+1];
					end
					2'b10: begin
						data_tmp_0[i] 	= data_tmp_1[i*2];
						pos_tmp_0[i] 	= pos_tmp_1[i*2];
						idx_tmp_0[i] 	= idx_tmp_1[i*2];
					end
					2'b11: begin
						data_tmp_0[i] 	= pos_tmp_1[i*2]==pos_tmp_1[i*2+1] ? 
										  (data_tmp_1[i*2]<data_tmp_1[i*2+1] ? data_tmp_1[i*2] : data_tmp_1[i*2+1]) :
										  (data_tmp_1[i*2]>data_tmp_1[i*2+1] ? data_tmp_1[i*2] : data_tmp_1[i*2+1]) ;
						idx_tmp_0[i] 	= pos_tmp_1[i*2]==pos_tmp_1[i*2+1] ?
										  (data_tmp_1[i*2]<data_tmp_1[i*2+1] ? idx_tmp_1[i*2] : idx_tmp_1[i*2+1]) :
										  (data_tmp_1[i*2]>data_tmp_1[i*2+1] ? idx_tmp_1[i*2] : idx_tmp_1[i*2+1]) ;
					end
				endcase
			end
			assign req_tmp_0[i] = req_tmp_1[i*2] | req_tmp_1[i*2+1];
		end
	endgenerate



endmodule
