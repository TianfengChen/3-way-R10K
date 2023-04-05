# make          <- runs simv (after compiling simv if needed)
# make all      <- runs simv (after compiling simv if needed)
# make simv     <- compile simv if needed (but do not run)
# make syn      <- runs syn_simv (after synthesizing if needed then 
#                                 compiling synsimv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be 
# similar to the information in those scripts but that seems hard to avoid.
#
#

SOURCE = test_progs/sampler.s

CRT = crt.s
LINKERS = linker.lds
ASLINKERS = aslinker.lds

DEBUG_FLAG = -g
CFLAGS =  -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align -mno-div
OFLAGS = -O0
ASFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS = -SD -M no-aliases 
OBJDFLAGS = -SD -M numeric,no-aliases

##########################################################################
# IF YOU AREN'T USING A CAEN MACHINE, CHANGE THIS TO FALSE OR OVERRIDE IT
CAEN = 1
##########################################################################
ifeq (1, $(CAEN))
	GCC = riscv gcc
	OBJDUMP = riscv objdump
	AS = riscv as
	ELF2HEX = riscv elf2hex
else
	GCC = riscv64-unknown-elf-gcc
	OBJDUMP = riscv64-unknown-elf-objdump
	AS = riscv64-unknown-elf-as
	ELF2HEX = elf2hex
endif
all: simv
	./simv | tee program.out

compile: $(CRT) $(LINKERS)
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.elf
	$(GCC) $(CFLAGS) $(DEBUG_FLAG) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.debug.elf
assemble: $(ASLINKERS)
	$(GCC) $(ASFLAGS) $(SOURCE) -T $(ASLINKERS) -o program.elf 
	cp program.elf program.debug.elf
disassemble: program.debug.elf
	$(OBJDUMP) $(OBJFLAGS) program.debug.elf > program.dump
	$(OBJDUMP) $(OBJDFLAGS) program.debug.elf > program.debug.dump
	rm program.debug.elf
hex: program.elf
	$(ELF2HEX) 8 8192 program.elf > program.mem

program: compile disassemble hex
	@:

debug_program:
	gcc -lm -g -std=gnu11 -DDEBUG $(SOURCE) -o debug_bin
assembly: assemble disassemble hex
	@:

VCS = vcs -V -sverilog +vc -Mupdate -line -full64 +vcs+vcdpluson -debug_access+all 
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

# For visual debugger
VISFLAGS = -lncurses


##### 
# Modify starting here
#####

TESTBENCH = 	sys_defs.svh	\
		ISA.svh         \
		testbench/mem.sv  \
		testbench/testbench.sv	\
		testbench/pipe_print.c	 
SIMFILES =	verilog/pipeline_top.sv	\
			verilog/pipeline_front.sv		\
			verilog/pipeline_back.v		\
			verilog/rs1.v		\
			verilog/rs_group.v		\
			verilog/rs_top.v		\
			verilog/ROB.sv		\
			verilog/cdb.v		\
			verilog/fu_alloc.v		\
			verilog/fu_alu.sv		\
			verilog/fu_brcond.sv		\
			verilog/fu_group.sv		\
			verilog/fu_mem.sv		\
			verilog/fu_mult.sv		\
			verilog/fu_top.v		\
			verilog/mult_stage.sv		\
			verilog/mux41.v		\
			verilog/mux_onehot.v		\
			verilog/pipe_mult.sv		\
			verilog/prf.v		\
			verilog/free_list.sv		\
			verilog/rrat.sv		\
			verilog/rat.sv		\
			verilog/if_stage.sv	\
			verilog/cachemem.sv	\
			verilog/icache.sv	\
			verilog/id_stage.sv	\
			verilog/psel_gen.v	\
			verilog/wand_sel.v	\
			verilog/onehot_enc.v	\
			verilog/dcache_mem.sv	\
			verilog/dcache_control.sv

SYNFILES =	synth/pipeline_top.vg

synth/pipeline_top.vg:	verilog/pipeline_top.sv synth/pipeline_front.vg synth/pipeline_back.vg synth/ROB.vg synth/rs_top.vg synth/mult.vg synth/mult_stage.vg synth/pipeline_top_synth.tcl
	cd synth && dc_shell-t -f ./pipeline_top_synth.tcl | tee pipeline_top_synth.out

synth/pipeline_front.vg:	verilog/pipeline_front.sv synth/pipeline_front_synth.tcl
	cd synth && dc_shell-t -f ./pipeline_front_synth.tcl | tee pipeline_front_synth.out

synth/pipeline_back.vg:	verilog/pipeline_back.v synth/ROB.vg synth/rs_top.vg synth/mult.vg synth/mult_stage.vg synth/pipeline_back_synth.tcl
	cd synth && dc_shell-t -f ./pipeline_back_synth.tcl | tee pipeline_back_synth.out

synth/ROB.vg:	verilog/ROB.sv synth/rob_synth.tcl
	cd synth && dc_shell-t -f ./rob_synth.tcl | tee rob_synth.out

synth/rs_top.vg:	verilog/rs_top.v synth/rs_top_synth.tcl
	cd synth && dc_shell-t -f ./rs_top_synth.tcl | tee rs_top_synth.out

synth/mult.vg:	verilog/pipe_mult.sv synth/mult_stage.vg synth/mult.tcl
	cd synth && dc_shell-t -f ./mult.tcl | tee mult_synth.out

synth/mult_stage.vg:	verilog/mult_stage.sv synth/mult_stage.tcl
	cd synth && dc_shell-t -f ./mult_stage.tcl | tee mult_stage_synth.out


# Don't ask me why spell VisUal TestBenchER like this...
VTUBER = sys_defs.svh	\
		ISA.svh         \
		testbench/mem.sv  \
		testbench/visual_testbench.v \
		testbench/visual_c_hooks.cpp \
		testbench/pipe_print.c 

#####
# Should be no need to modify after here
#####
simv:	$(SIMFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SIMFILES)	-o simv

dve:	$(SIMFILES) $(TESTBENCH)
	$(VCS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve -R -gui
.PHONY:	dve

# For visual debugger
vis_simv:	$(SIMFILES) $(VTUBER)
	$(VCS) $(VISFLAGS) $(VTUBER) $(SIMFILES) -o vis_simv 
	./vis_simv

syn_simv:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv 

syn:	syn_simv
	./syn_simv | tee syn_program.out


clean:
	rm -rf *simv *simv.daidir csrc vcs.key program.out *.key
	rm -rf vis_simv vis_simv.daidir
	rm -rf dve* inter.vpd DVEfiles
	rm -rf syn_simv syn_simv.daidir syn_program.out
	rm -rf synsimv synsimv.daidir csrc vcdplus.vpd vcs.key synprog.out pipeline.out writeback.out vc_hdrs.h
	rm -f *.elf *.dump *.mem debug_bin

nuke:	clean
	rm -rf synth/*.vg synth/*.rep synth/*.ddc synth/*.chk synth/command.log synth/*.syn
	rm -rf synth/*.out command.log synth/*.db synth/*.svf synth/*.mr synth/*.pvl
