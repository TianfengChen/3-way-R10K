//`default_nettype none
module icache(
    //inputs
    input   clock,
    input   reset,
////input from memory
    input   [3:0] Imem2proc_response,
    input  [63:0] Imem2proc_data,
    input   [3:0] Imem2proc_tag,
////from if_stage: search for the inst for 3 superscalar ways
    input  [63:0] proc2Icache_addr_2,
    input  [63:0] proc2Icache_addr_1,
    input  [63:0] proc2Icache_addr_0,
////The inst fetch request to memory
    input  [63:0] inst_fetch_addr,
    input  [63:0] inst_fetch_data,
    input  	  inst_fetch_valid,
////The load/store request to memory
    input  [1:0]  load_store,		//[1,0] for load, [0,1] for store, [0,0] for BUS_NONE
    input  [1:0]  proc2Dmem_command,
    input  [31:0] proc2Dmem_addr,
    input  [1:0]  proc2Dmem_size,
    input  [63:0] proc2Dmem_data,
    //outputs
////Output to memory
    output logic [1:0]  proc2Imem_command,
    output logic [63:0] proc2Imem_addr,
    output logic [63:0] proc2Imem_data,
    output logic [1:0] 	proc2Imem_size,   
////INST fetch cache search result
    output logic [63:0] Icache_data_out, // value is memory[proc2Icache_addr]
    output logic  Icache_valid_out,      // when this is high
////index and tag of 3-way inst fetch
    output logic  [4:0] cashmem_rd_idx_2,
    output logic  [4:0] cashmem_rd_idx_1,
    output logic  [4:0] cashmem_rd_idx_0,
    output logic  [7:0] cashmem_rd_tag_2,
    output logic  [7:0] cashmem_rd_tag_1,
    output logic  [7:0] cashmem_rd_tag_0,
////request information in cache controller
    output logic  [4:0] current_index,
    output logic  [7:0] current_tag,
    output logic  [4:0] last_index,
    output logic  [7:0] last_tag,
    output logic  [63:0] load_data,
    output logic  data_write_enable_fetch,
    output logic  data_write_enable_load
  );
  logic	[1:0] 	current_request;	//00 for inst fetch, 01 for write, 10 for load 
  logic [1:0] 	last_request;
  logic	      	data_write_enable;
  logic	[63:0] 	proc2Icache_addr;
  logic	[63:0] 	proc2Icache_data;
  logic	[1:0] 	proc2Icache_command;
  logic	[1:0] 	proc2Icache_size;
  logic  	cachemem_valid;

  logic [3:0] current_mem_tag;

  logic miss_outstanding;

  assign proc2Icache_addr = (load_store[1] | load_store[0]) ? {32'b0,proc2Dmem_addr} : inst_fetch_addr;
  assign proc2Icache_command = (load_store[1] | load_store[0]) ? proc2Dmem_command : BUS_LOAD;
  assign proc2Icache_data = (load_store[1] | load_store[0]) ? proc2Dmem_data : 64'b0;
  assign proc2Icache_size = (load_store[1] | load_store[0]) ? proc2Dmem_size : DOUBLE;
  assign cachemem_valid = (load_store[1] | load_store[0]) ? 1'b0 : inst_fetch_valid;	
  assign current_request = (load_store == 2'b01) ? 2'b01 : (load_store == 2'b10) ? 2'b10 : 2'b00;
  assign data_write_enable_fetch = data_write_enable & (last_request == 2'b00);
  assign data_write_enable_load  = data_write_enable & (last_request == 2'b10 | last_request == 2'b01);
  assign load_data = Imem2proc_data;

  assign current_index 	  = proc2Icache_addr[7:3];
  assign current_tag	  = proc2Icache_addr[15:8];
  assign cashmem_rd_idx_2 = proc2Icache_addr_2[7:3];
  assign cashmem_rd_idx_1 = proc2Icache_addr_1[7:3];
  assign cashmem_rd_idx_0 = proc2Icache_addr_0[7:3];
  assign cashmem_rd_tag_2 = proc2Icache_addr_2[15:8];
  assign cashmem_rd_tag_1 = proc2Icache_addr_1[15:8];
  assign cashmem_rd_tag_0 = proc2Icache_addr_0[15:8];


  wire changed_addr = (current_index != last_index) || (current_tag != last_tag) || (current_request != last_request);

  wire send_request = miss_outstanding && !changed_addr;

  assign Icache_data_out = inst_fetch_data;

  assign Icache_valid_out = cachemem_valid; 

  assign proc2Imem_addr = {proc2Icache_addr[63:3],3'b0};
  assign proc2Imem_command = (load_store[0] & proc2Dmem_command == BUS_STORE) ? BUS_STORE : ((miss_outstanding && !changed_addr) ?  proc2Icache_command :
                                                                    BUS_NONE);
  assign proc2Imem_data = proc2Icache_data;
  assign proc2Imem_size = proc2Icache_size;

  assign data_write_enable =  (current_mem_tag == Imem2proc_tag) &&
                              (current_mem_tag != 0);

  wire update_mem_tag = changed_addr || miss_outstanding || data_write_enable;

  wire unanswered_miss = changed_addr ? !Icache_valid_out :
                                        miss_outstanding && (Imem2proc_response == 0);

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if(reset) begin
      last_request     <= `SD 2'b11;
      last_index       <= `SD -1;   // These are -1 to get ball rolling when
      last_tag         <= `SD -1;   // reset goes low because addr "changes"
      current_mem_tag  <= `SD 0;              
      miss_outstanding <= `SD 0;
    end else begin
      last_request     <= `SD current_request;
      last_index       <= `SD current_index;
      last_tag         <= `SD current_tag;
      miss_outstanding <= `SD unanswered_miss;
      
      if(update_mem_tag)
        current_mem_tag <= `SD Imem2proc_response;
    end
  end

endmodule
//`default_nettype wire
