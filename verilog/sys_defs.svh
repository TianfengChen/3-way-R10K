//`define DEBUG
`define RS_OLDEST_FIRST
//`define LSQ_OLDEST_FIRST	//not help much
//`define LSQ_CONSERVATIVE

`define XLEN 32
`define DCACHE_BLOCK_WIDTH 256
`define DCACHE_SET_NUM 16
`define DCACHE_WAY_NUM 4
`define DCACHE_DOUBLE_NUM (`DCACHE_BLOCK_WIDTH/64)
`define DCACHE_WORD_NUM (`DCACHE_BLOCK_WIDTH/32)
`define DCACHE_BYTE_NUM (`DCACHE_BLOCK_WIDTH/8)
`define DCACHE_OFFSET_WIDTH $clog2(`DCACHE_BYTE_NUM)
`define DCACHE_INDEX_WIDTH $clog2(`DCACHE_SET_NUM)
`define DCACHE_WAY_WIDTH $clog2(`DCACHE_WAY_NUM)
`define DCACHE_TAG_WIDTH (`XLEN-`DCACHE_OFFSET_WIDTH-`DCACHE_INDEX_WIDTH)

`define ICACHE_BLOCK_WIDTH 256
`define ICACHE_SET_NUM 16
`define ICACHE_WAY_NUM 4
`define ICACHE_WORD_NUM (`ICACHE_BLOCK_WIDTH/32)
`define ICACHE_BYTE_NUM (`ICACHE_BLOCK_WIDTH/8)
`define ICACHE_OFFSET_WIDTH $clog2(`ICACHE_BYTE_NUM)
`define ICACHE_INDEX_WIDTH $clog2(`ICACHE_SET_NUM)
`define ICACHE_WAY_WIDTH $clog2(`ICACHE_WAY_NUM)
`define ICACHE_TAG_WIDTH (`XLEN-`ICACHE_OFFSET_WIDTH-`ICACHE_INDEX_WIDTH)

`define RENAME_PACKET_WIDTH $bits(RENAME_PACKET)
`define DISPATCH_RS_PACKET_WIDTH $bits(DISPATCH_RS_PACKET)
`define DISPATCH_ROB_PACKET_WIDTH $bits(DISPATCH_ROB_PACKET)
`define ISSUE_PACKET_WIDTH $bits(ISSUE_PACKET)

`define ARF_DEPTH 32					
`define ROB_DEPTH 64						
`define PRF_DEPTH (`ARF_DEPTH+`ROB_DEPTH+4)	//add four extra prf entries to compensate one-cycle rob retire to freelist update latency(rob retired instrs and turnd from full to ready to accept but freelist is still waiting for retired prn)
`define RS_DEPTH_INT 16
`define RS_DEPTH_MEM 8
`define ARF_WIDTH $clog2(`ARF_DEPTH)
`define ROB_WIDTH $clog2(`ROB_DEPTH)
`define PRF_WIDTH $clog2(`PRF_DEPTH)
`define MACHINE_WIDTH 4
`define MACHINE_IDX $clog2(`MACHINE_WIDTH)
`define ISSUE_WIDTH 7
`define ISSUE_IDX $clog2(`ISSUE_WIDTH)
`define RS_ISSUE_WIDTH_INT 6
`define RS_ISSUE_WIDTH_MEM 1
`define PTAB_DEPTH 16
`define PTAB_WIDTH $clog2(`PTAB_DEPTH)
`define STQ_DEPTH 16
`define LDQ_DEPTH 16
`define STQ_WIDTH $clog2(`STQ_DEPTH)
`define LDQ_WIDTH $clog2(`LDQ_DEPTH)

`define MULT_LATENCY 2
//change mult, mult_top, fu_top

//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know what they are
//////////////////////////////////////////////

typedef enum logic [3:0] {
	INST_ADDR_MISALIGN  = 4'h0,
	INST_ACCESS_FAULT   = 4'h1,
	ILLEGAL_INST        = 4'h2,
	BREAKPOINT          = 4'h3,
	LOAD_ADDR_MISALIGN  = 4'h4,
	LOAD_ACCESS_FAULT   = 4'h5,
	STORE_ADDR_MISALIGN = 4'h6,
	STORE_ACCESS_FAULT  = 4'h7,
	ECALL_U_MODE        = 4'h8,
	ECALL_S_MODE        = 4'h9,
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;


typedef enum logic [`ISSUE_IDX-1:0] {
	ALU_0	= 0,
	ALU_1 	= 1,
	ALU_2 	= 2,
	ALU_3 	= 3,
	MUL_0 	= 4,
	BRU_0 	= 5,
	AGU_0 	= 6
} FU_ID;


typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;


typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;


typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;


typedef enum logic [4:0] {
	ALU_ADD     = 5'h00,
	ALU_SUB     = 5'h01,
	ALU_SLT     = 5'h02,
	ALU_SLTU    = 5'h03,
	ALU_AND     = 5'h04,
	ALU_OR      = 5'h05,
	ALU_XOR     = 5'h06,
	ALU_SLL     = 5'h07,
	ALU_SRL     = 5'h08,
	ALU_SRA     = 5'h09,
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
	ALU_DIV     = 5'h0e,
	ALU_DIVU    = 5'h0f,
	ALU_REM     = 5'h10,
	ALU_REMU    = 5'h11
} ALU_FUNC;


//
// Memory bus commands control signals
//
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;


// A bundle returned by the Front-end which contains some set of consecutive instructions with a mask denoting which instructions are valid, amongst other meta-data related to instruction fetch and branch prediction. The Fetch PC will point to the first valid instruction in the Fetch Packet, as it is the PC used by the Front End to fetch the Fetch Packet
typedef struct packed {
    logic [`XLEN-1:0]			inst			;  
	logic [`XLEN-1:0] 			pc				;
  	logic						branch_mask		;	
  	logic						branch_dir		;	
	logic [`XLEN-1:0] 			branch_addr		;
	logic 						packet_valid	; 
} FETCH_PACKET;


//typedef struct packed {
//    logic [`XLEN-1:0]			inst			;  
//	logic [`XLEN-1:0] 			pc				;  
//	logic 						packet_valid	; 
//} INST_BUF_PACKET;


typedef struct packed {
	logic [31:0]				inst			;
	logic [31:0]				pc		 		;
	ALU_FUNC	 				op_type  		;			
	logic [`ARF_WIDTH-1:0] 		op1_arn 		;			
	logic [`ARF_WIDTH-1:0] 		op2_arn			;
	logic 						use_op1_arn 	;
	logic 						use_op2_arn 	;
	logic [`ARF_WIDTH-1:0] 		dest_arn 		;
	ALU_OPA_SELECT				op1_select		;
	ALU_OPB_SELECT				op2_select		;
	DEST_REG_SEL   				dest_select		;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						cond_branch 	;
	logic 						uncond_branch 	;
	logic 						halt 			;
	logic 						illegal 		;
	logic       				csr_op			;
	FU_ID						fu_id			;
	logic						packet_valid	;
} DECODE_PACKET;


typedef struct packed {
	logic [31:0]				inst			;
	logic [31:0]				pc		 		;
	ALU_FUNC	 				op_type  		;			
	logic [`PRF_WIDTH-1:0] 		op1_prn 		;			
	logic [`PRF_WIDTH-1:0] 		op2_prn			;
	logic 						use_op1_prn 	;
	logic 						use_op2_prn 	;
	logic [`ARF_WIDTH-1:0] 		dest_arn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn_prev 	;
	ALU_OPA_SELECT				op1_select		;
	ALU_OPB_SELECT				op2_select		;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						cond_branch 	;
	logic 						uncond_branch 	;
	logic 						halt 			;
	logic 						illegal 		;
//	logic [`ROB_WIDTH:0] 		rob_entry		;
	logic 						op1_ready 		;
	logic 						op2_ready 		;
	FU_ID						fu_id			;
	logic						packet_valid	;
} RENAME_PACKET;


typedef struct packed {
	logic [31:0]				inst			;
	logic [31:0]				pc		 		;
	ALU_FUNC	 				op_type  		;			
	logic [`PRF_WIDTH-1:0] 		op1_prn 		;			
	logic [`PRF_WIDTH-1:0] 		op2_prn			;
	logic 						use_op1_prn 	;
	logic 						use_op2_prn 	;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
//	logic [`PRF_WIDTH-1:0] 		dest_prn_prev 	;
	ALU_OPA_SELECT				op1_select		;
	ALU_OPB_SELECT				op2_select		;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						cond_branch 	;
	logic 						uncond_branch 	;
//	logic 						halt 			;
//	logic 						illegal 		;
	logic [`ROB_WIDTH:0] 		rob_entry		;
	logic 						op1_ready 		;
	logic 						op2_ready 		;
	FU_ID						fu_id			;
	logic [`PTAB_WIDTH-1:0]		ptab_tag		;
	logic [`STQ_WIDTH-1:0] 		stq_tag		 	;
	logic [`LDQ_WIDTH-1:0]		ldq_tag			;
	logic						packet_valid	;
} DISPATCH_RS_PACKET;


typedef struct packed {
	logic [31:0]				inst			;
	logic [31:0]				pc		 		;
	logic [`ARF_WIDTH-1:0] 		dest_arn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn_prev 	;
	logic [`STQ_WIDTH-1:0] 		stq_tag		 	;
	logic [`LDQ_WIDTH-1:0]		ldq_tag			;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						cond_branch 	;
	logic 						uncond_branch 	;
	logic 						halt 			;
	logic 						illegal 		;
	logic						packet_valid	;
} DISPATCH_ROB_PACKET;



typedef struct packed {
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic						packet_valid	;
} DISPATCH_LSQ_PACKET;


typedef struct packed {
	logic [31:0]				pc		 		;
	logic [`ARF_WIDTH-1:0] 		dest_arn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn_prev 	;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						branch_misp 	;
	logic [31:0]				redirect_pc		;
	EXCEPTION_CODE				exception 		;
	logic [`ROB_WIDTH:0] 		rob_tag		 	;
	logic [`STQ_WIDTH-1:0] 		stq_tag		 	;
	logic [`LDQ_WIDTH-1:0] 		ldq_tag		 	;
	logic						packet_valid	;
} RETIRE_ROB_PACKET;


typedef struct packed {
	logic [31:0]				pc		 		;
	logic [`ARF_WIDTH-1:0] 		dest_arn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
	logic [`PRF_WIDTH-1:0] 		dest_prn_prev 	;
	logic [`STQ_WIDTH-1:0]		stq_tag			;
	logic [`LDQ_WIDTH-1:0]		ldq_tag			;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						branch		 	;
	logic 						branch_misp 	;
	EXCEPTION_CODE				exception 		;
	logic 						complete 		;
	logic						valid			;
} ROB_ENTRY;


typedef struct packed {
	logic [`XLEN-1:0]		addr			;
	logic 					addr_valid		;
	logic [`XLEN-1:0]		data			;
	logic [2:0]				data_size		;
	logic					data_valid		;
	logic					writebacked		;
	logic					fired			;
	logic					order_fail		;
	logic [`STQ_DEPTH-1:0]	st_mask			;
	logic [`STQ_WIDTH-1:0]	st_youngest		;
	logic [`STQ_WIDTH-1:0]	fwd_stq_tag		;
	logic					sleep			;
	logic [`XLEN-1:0]		pc				;
	logic [`PRF_WIDTH-1:0]	dest_prn		;
	logic [`ROB_WIDTH:0]	rob_tag			;
	logic					entry_valid		;
} LDQ_ENTRY;


typedef struct packed {
	logic [`XLEN-1:0]		addr		;
	logic 					addr_valid	;
	logic [`XLEN-1:0]		data	 	;
	logic [2:0]				data_size	;
	logic 					data_valid	;
	logic					retired		;
	logic					entry_valid	;
} STQ_ENTRY;


typedef struct packed {
	logic [31:0]				inst			;
	logic [31:0]				pc		 		;
	ALU_FUNC	 				op_type  		;			
	logic [`PRF_WIDTH-1:0] 		op1_prn 		;			
	logic [`PRF_WIDTH-1:0] 		op2_prn			;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
	ALU_OPA_SELECT				op1_select		;
	ALU_OPB_SELECT				op2_select		;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						cond_branch 	;
	logic 						uncond_branch 	;
//	logic 						halt 			;
//	logic 						illegal 		;
	logic [`ROB_WIDTH:0] 		rob_entry		;
	FU_ID						fu_id			;
	logic [`PTAB_WIDTH-1:0]		ptab_tag		;
	logic [`STQ_WIDTH-1:0]		stq_tag			;
	logic [`LDQ_WIDTH-1:0]		ldq_tag			;
	logic						packet_valid	;
} ISSUE_PACKET;


typedef struct packed {
	logic [31:0]				inst			;
	logic [31:0]				pc		 		;
	ALU_FUNC	 				op_type  		;			
	logic [`XLEN-1:0] 			op1_val 		;			
	logic [`XLEN-1:0]	 		op2_val			;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
	ALU_OPA_SELECT				op1_select		;
	ALU_OPB_SELECT				op2_select		;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						cond_branch 	;
	logic 						uncond_branch 	;
//	logic 						halt 			;
//	logic 						illegal 		;
	logic [`ROB_WIDTH:0] 		rob_entry		;
	FU_ID						fu_id			;
	logic [`PTAB_WIDTH-1:0]		ptab_tag		;
	logic [`STQ_WIDTH-1:0]		stq_tag			;
	logic [`LDQ_WIDTH-1:0]		ldq_tag			;
	logic						packet_valid	;
} REG_READ_PACKET;


typedef struct packed {
	logic [31:0]				inst			;
	logic [31:0]				pc		 		;
	logic [`XLEN-1:0]	 		result			;
	logic [`PRF_WIDTH-1:0] 		dest_prn 		;
	logic 						rd_mem 			;
	logic 						wr_mem 			;
	logic 						cond_branch 	;
	logic 						uncond_branch 	;
//	logic 						halt 			;
//	logic 						illegal 		;
	logic [`ROB_WIDTH:0] 		rob_entry		;
	logic						branch_dir		;
	logic [`XLEN-1:0]			target_pc		;
	logic [`XLEN-1:0]	 		st_data			;
	logic [`STQ_WIDTH-1:0]		stq_tag			;
	logic [`LDQ_WIDTH-1:0]		ldq_tag			;
	logic [2:0]					mem_size		;
	logic						packet_valid	;
} EXECUTE_PACKET;
















//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////

`define CACHE_MODE //removes the byte-level interface from the memory mode, DO NOT MODIFY!
`define NUM_MEM_TAGS           15 //num of outstanding requests the memory can handle

`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

//you can change the clock period to whatever, 10 is just fine
`define VERILOG_CLOCK_PERIOD   15.0
`define SYNTH_CLOCK_PERIOD     15.0 // Clock period for synth and memory latency

`define MEM_LATENCY_IN_CYCLES (100.0/`SYNTH_CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period).  The default behavior for
// float to integer conversion is rounding to nearest

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;


//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
// JK you don't ^^^
//
`define SD #1


// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 5'd0


//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
`define XLEN 32
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
`define NOP 32'h00000013

//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages  
//
//////////////////////////////////////////////

//typedef struct packed {
//	logic valid; // If low, the data in this struct is garbage
//    INST  inst;  // fetched instruction out
//	logic [`XLEN-1:0] NPC; // PC + 4
//	logic [`XLEN-1:0] PC;  // PC 
//} IF_ID_PACKET;

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value                                  
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} ID_EX_PACKET;

typedef struct packed {
	logic [`XLEN-1:0] alu_result; // alu_result
	logic [`XLEN-1:0] NPC; //pc + 4
	logic             take_branch; // is this a taken branch?
	//pass throughs from decode stage
	logic [`XLEN-1:0] rs2_value;
	logic             rd_mem, wr_mem;
	logic [4:0]       dest_reg_idx;
	logic             halt, illegal, csr_op, valid;
	logic [2:0]       mem_size; // byte, half-word or word
} EX_MEM_PACKET;

