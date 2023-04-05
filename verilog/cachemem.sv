// cachemem32x64

`timescale 1ns/100ps

module cache(
        input clock, reset, wr1_en,
        input  [4:0] wr1_idx, rd1_idx_2, rd1_idx_1, rd1_idx_0,
        input  [7:0] wr1_tag, rd1_tag_2, rd1_tag_1, rd1_tag_0,
        input [63:0] wr1_data, 

        output [63:0] rd1_data_2,
        output [63:0] rd1_data_1,
        output [63:0] rd1_data_0,
        output [`N_WAY-1:0] rd1_valid
        
      );



  logic [63:0] data [0:31];
  logic [7:0] tags [0:31]; 
  logic [31:0]        valids;

  assign rd1_data_2 = data[rd1_idx_2];
  assign rd1_data_1 = data[rd1_idx_1];
  assign rd1_data_0 = data[rd1_idx_0];
  assign rd1_valid[2] = valids[rd1_idx_2] && (tags[rd1_idx_2] == rd1_tag_2);
  assign rd1_valid[1] = valids[rd1_idx_1] && (tags[rd1_idx_1] == rd1_tag_1);
  assign rd1_valid[0] = valids[rd1_idx_0] && (tags[rd1_idx_0] == rd1_tag_0);

  always_ff @(posedge clock) begin
    if(reset)
      valids <= `SD 31'b0;
    else if(wr1_en) 
      valids[wr1_idx] <= `SD 1;
  end
  
  always_ff @(posedge clock) begin
    if(wr1_en) begin
      data[wr1_idx] <= `SD wr1_data;
      tags[wr1_idx] <= `SD wr1_tag;
    end
  end

endmodule

