`ifndef __MULT_TOP_SV__
`define __MULT_TOP_SV__
`timescale 1ns/100ps



//
// Multiplier module
//
module mult_top(
	input 							clk, 
	input							rst_n,
	input							pipe_flush,
	input 			[`XLEN-1:0] 	mcand,
	input 			[`XLEN-1:0] 	mplier,
	input 			ALU_FUNC 		func,
	output logic 	[`XLEN-1:0] 	result
);
	logic [`XLEN-1:0] mcand_in, mplier_in;
    logic signed [`XLEN-1:0] signed_mcand_in, signed_mplier_in;
    
    logic [2*`XLEN-1:0] product_out;
	logic signed [2*`XLEN-1:0] signed_product_out;


	ALU_FUNC func_d0;
	ALU_FUNC func_d1;
	//ALU_FUNC func_d2;
	//ALU_FUNC func_d3;

	assign mcand_in = mcand;
    assign mplier_in = mplier;
    assign signed_mcand_in = mcand;
    assign signed_mplier_in = mplier;

	always@(posedge clk or negedge rst_n) begin 
		if(~rst_n)begin 
			func_d0 <= ALU_ADD;
			func_d1 <= ALU_ADD;
			//func_d2 <= ALU_ADD;
			//func_d3 <= ALU_ADD;
		end
		else if(pipe_flush)begin
			func_d0 <= ALU_ADD;
			func_d1 <= ALU_ADD;
			//func_d2 <= ALU_ADD;
			//func_d3 <= ALU_ADD;
		end
		else begin
			func_d0 <= func;
			func_d1 <= func_d0;
			//func_d2 <= func_d1;
			//func_d3 <= func_d2;
		end
	end


    always_comb begin
        //case(func_d3)
        case(func_d1)
            ALU_MUL:	begin
            	result = signed_product_out[`XLEN-1:0];
            end    
            ALU_MULH:	begin
            	result = signed_product_out[2*`XLEN-1:`XLEN];
            end   
            ALU_MULHSU:	begin
            	result = product_out[2*`XLEN-1:`XLEN];
            end
            ALU_MULHU:	begin
            	result = product_out[2*`XLEN-1:`XLEN];
            end  
            default:	begin
            	result = `XLEN'hfacebeec;  // here to prevent latches
            end    
        endcase
    end

	mult u_mult_signed(
		.clk(clk),
		.rst_n(rst_n),
		.pipe_flush(pipe_flush),
		.a({{32{signed_mcand_in[31]}},signed_mcand_in}),
		.b({{32{signed_mplier_in[31]}},signed_mplier_in}),
		.result(signed_product_out)
	);

	mult u_mult_unsigned(
		.clk(clk),
		.rst_n(rst_n),
		.pipe_flush(pipe_flush),
		.a({32'b0,mcand_in}),
		.b({32'b0,mplier_in}),
		.result(product_out)
	);

endmodule
`endif //__MULT_TOP_SV__
