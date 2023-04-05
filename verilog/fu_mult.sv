`timescale 1ns/100ps

//
// Multiplier module
//
module fu_mult(
	input clock, reset,
	input [`XLEN-1:0] mcand,
	input [`XLEN-1:0] mplier,
	input mult_en,
	input [4:0] mult_func,

	output logic [`XLEN-1:0] mult_result,
	output logic mult_done
);
	logic [`XLEN-1:0] mcand_in, mplier_in;
    logic signed [`XLEN-1:0] signed_mcand_in, signed_mplier_in;
    
    logic [2*`XLEN-1:0] product_out;
	logic signed [2*`XLEN-1:0] signed_product_out;

	logic signed_done, done;

	reg [4:0 ] mult_func_d0;
	reg [4:0 ] mult_func_d1;
	reg [4:0 ] mult_func_d2;
	reg [4:0 ] mult_func_d3;

	assign mcand_in = mcand;
    assign mplier_in = mplier;
    assign signed_mcand_in = mcand;
    assign signed_mplier_in = mplier;
	assign mult_done = done | signed_done;

	always@(posedge clock) begin 
		if(reset)begin 
			mult_func_d0 <= `SD 32'b0;
			mult_func_d1 <= `SD 32'b0;
			mult_func_d2 <= `SD 32'b0;
			mult_func_d3 <= `SD 32'b0;
		end
		else begin
			mult_func_d0 <= `SD mult_func;
			mult_func_d1 <= `SD mult_func_d0;
			mult_func_d2 <= `SD mult_func_d1;
			mult_func_d3 <= `SD mult_func_d2;
		end
	end


    always_comb begin
        case(mult_func_d3)
            5'h0a:	begin
            	mult_result = signed_product_out[`XLEN-1:0];
            end    
            ALU_MULH:	begin
            	mult_result = signed_product_out[2*`XLEN-1:`XLEN];
            end   
            ALU_MULHSU:	begin
            	mult_result = product_out[2*`XLEN-1:`XLEN];
            end
            ALU_MULHU:	begin
            	mult_result = product_out[2*`XLEN-1:`XLEN];
            end  
            default:	begin
            	mult_result = `XLEN'hfacebeec;  // here to prevent latches
            end    
        endcase
    end

	mult signed_multi(
	.clock(clock),
	.reset(reset),
	.mcand({{32{signed_mcand_in[31]}},signed_mcand_in}),
	.mplier({{32{signed_mplier_in[31]}},signed_mplier_in}),
	.start(mult_en),

	.product(signed_product_out),
	.done(signed_done));

	mult unsigned_multi(
	.clock(clock),
	.reset(reset),
	.mcand({32'b0,mcand_in}),
	.mplier({32'b0,mplier_in}),
	.start(mult_en),

	.product(product_out),
	.done(done)
	
);

endmodule

