# Begin_DVE_Session_Save_Info
# DVE full session
# Saved on Sat Dec 4 23:28:55 2021
# Designs open: 1
#   Sim: dve
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Source.1: testbench
#   Wave.1: 82 signals
#   Group count = 5
#   Group Memory signal count = 6
#   Group ID_STAGE signal count = 7
#   Group id_rs signal count = 15
#   Group ROB INPUT FROM CDB&FU signal count = 18
#   Group ROB signal count = 36
# End_DVE_Session_Save_Info

# DVE version: R-2020.12-SP2-1_Full64
# DVE build date: Jul 18 2021 21:21:42


#<Session mode="Full" path="/afs/umich.edu/user/g/u/guohch/Desktop/EECS470/Project/final_project/milestone3/session.inter.vpd.tcl" type="Debug">

gui_set_loading_session_type Post
gui_continuetime_set

# Close design
if { [gui_sim_state -check active] } {
    gui_sim_terminate
}
gui_close_db -all
gui_expr_clear_all

# Close all windows
gui_close_window -type Console
gui_close_window -type Wave
gui_close_window -type Source
gui_close_window -type Schematic
gui_close_window -type Data
gui_close_window -type DriverLoad
gui_close_window -type List
gui_close_window -type Memory
gui_close_window -type HSPane
gui_close_window -type DLPane
gui_close_window -type Assertion
gui_close_window -type CovHier
gui_close_window -type CoverageTable
gui_close_window -type CoverageMap
gui_close_window -type CovDetail
gui_close_window -type Local
gui_close_window -type Stack
gui_close_window -type Watch
gui_close_window -type Group
gui_close_window -type Transaction



# Application preferences
gui_set_pref_value -key app_default_font -value {Helvetica,10,-1,5,50,0,0,0,0,0}
gui_src_preferences -tabstop 8 -maxbits 24 -windownumber 1
#<WindowLayout>

# DVE top-level session


# Create and position top-level window: TopLevel.1

if {![gui_exist_window -window TopLevel.1]} {
    set TopLevel.1 [ gui_create_window -type TopLevel \
       -icon $::env(DVE)/auxx/gui/images/toolbars/dvewin.xpm] 
} else { 
    set TopLevel.1 TopLevel.1
}
gui_show_window -window ${TopLevel.1} -show_state maximized -rect {{0 64} {2559 1439}}

# ToolBar settings
gui_set_toolbar_attributes -toolbar {TimeOperations} -dock_state top
gui_set_toolbar_attributes -toolbar {TimeOperations} -offset 0
gui_show_toolbar -toolbar {TimeOperations}
gui_hide_toolbar -toolbar {&File}
gui_set_toolbar_attributes -toolbar {&Edit} -dock_state top
gui_set_toolbar_attributes -toolbar {&Edit} -offset 0
gui_show_toolbar -toolbar {&Edit}
gui_hide_toolbar -toolbar {CopyPaste}
gui_set_toolbar_attributes -toolbar {&Trace} -dock_state top
gui_set_toolbar_attributes -toolbar {&Trace} -offset 0
gui_show_toolbar -toolbar {&Trace}
gui_hide_toolbar -toolbar {TraceInstance}
gui_hide_toolbar -toolbar {BackTrace}
gui_set_toolbar_attributes -toolbar {&Scope} -dock_state top
gui_set_toolbar_attributes -toolbar {&Scope} -offset 0
gui_show_toolbar -toolbar {&Scope}
gui_set_toolbar_attributes -toolbar {&Window} -dock_state top
gui_set_toolbar_attributes -toolbar {&Window} -offset 0
gui_show_toolbar -toolbar {&Window}
gui_set_toolbar_attributes -toolbar {Signal} -dock_state top
gui_set_toolbar_attributes -toolbar {Signal} -offset 0
gui_show_toolbar -toolbar {Signal}
gui_set_toolbar_attributes -toolbar {Zoom} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom} -offset 0
gui_show_toolbar -toolbar {Zoom}
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -offset 0
gui_show_toolbar -toolbar {Zoom And Pan History}
gui_set_toolbar_attributes -toolbar {Grid} -dock_state top
gui_set_toolbar_attributes -toolbar {Grid} -offset 0
gui_show_toolbar -toolbar {Grid}
gui_set_toolbar_attributes -toolbar {Simulator} -dock_state top
gui_set_toolbar_attributes -toolbar {Simulator} -offset 0
gui_show_toolbar -toolbar {Simulator}
gui_set_toolbar_attributes -toolbar {Interactive Rewind} -dock_state top
gui_set_toolbar_attributes -toolbar {Interactive Rewind} -offset 0
gui_show_toolbar -toolbar {Interactive Rewind}
gui_set_toolbar_attributes -toolbar {Testbench} -dock_state top
gui_set_toolbar_attributes -toolbar {Testbench} -offset 0
gui_show_toolbar -toolbar {Testbench}

# End ToolBar settings

# Docked window settings
set HSPane.1 [gui_create_window -type HSPane -parent ${TopLevel.1} -dock_state left -dock_on_new_line true -dock_extent 335]
catch { set Hier.1 [gui_share_window -id ${HSPane.1} -type Hier] }
gui_set_window_pref_key -window ${HSPane.1} -key dock_width -value_type integer -value 335
gui_set_window_pref_key -window ${HSPane.1} -key dock_height -value_type integer -value -1
gui_set_window_pref_key -window ${HSPane.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${HSPane.1} {{left 0} {top 0} {width 334} {height 1145} {dock_state left} {dock_on_new_line true} {child_hier_colhier 237} {child_hier_coltype 174} {child_hier_colpd 0} {child_hier_col1 0} {child_hier_col2 1} {child_hier_col3 -1}}
set DLPane.1 [gui_create_window -type DLPane -parent ${TopLevel.1} -dock_state left -dock_on_new_line true -dock_extent 298]
catch { set Data.1 [gui_share_window -id ${DLPane.1} -type Data] }
gui_set_window_pref_key -window ${DLPane.1} -key dock_width -value_type integer -value 298
gui_set_window_pref_key -window ${DLPane.1} -key dock_height -value_type integer -value 1136
gui_set_window_pref_key -window ${DLPane.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${DLPane.1} {{left 0} {top 0} {width 297} {height 1145} {dock_state left} {dock_on_new_line true} {child_data_colvariable 210} {child_data_colvalue 38} {child_data_coltype 101} {child_data_col1 0} {child_data_col2 1} {child_data_col3 2}}
set Console.1 [gui_create_window -type Console -parent ${TopLevel.1} -dock_state bottom -dock_on_new_line true -dock_extent 156]
gui_set_window_pref_key -window ${Console.1} -key dock_width -value_type integer -value 2500
gui_set_window_pref_key -window ${Console.1} -key dock_height -value_type integer -value 156
gui_set_window_pref_key -window ${Console.1} -key dock_offset -value_type integer -value 0
gui_update_layout -id ${Console.1} {{left 0} {top 0} {width 2559} {height 155} {dock_state bottom} {dock_on_new_line true}}
#### Start - Readjusting docked view's offset / size
set dockAreaList { top left right bottom }
foreach dockArea $dockAreaList {
  set viewList [gui_ekki_get_window_ids -active_parent -dock_area $dockArea]
  foreach view $viewList {
      if {[lsearch -exact [gui_get_window_pref_keys -window $view] dock_width] != -1} {
        set dockWidth [gui_get_window_pref_value -window $view -key dock_width]
        set dockHeight [gui_get_window_pref_value -window $view -key dock_height]
        set offset [gui_get_window_pref_value -window $view -key dock_offset]
        if { [string equal "top" $dockArea] || [string equal "bottom" $dockArea]} {
          gui_set_window_attributes -window $view -dock_offset $offset -width $dockWidth
        } else {
          gui_set_window_attributes -window $view -dock_offset $offset -height $dockHeight
        }
      }
  }
}
#### End - Readjusting docked view's offset / size
gui_sync_global -id ${TopLevel.1} -option true

# MDI window settings
set Source.1 [gui_create_window -type {Source}  -parent ${TopLevel.1}]
gui_show_window -window ${Source.1} -show_state maximized
gui_update_layout -id ${Source.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false}}

# End MDI window settings


# Create and position top-level window: TopLevel.2

if {![gui_exist_window -window TopLevel.2]} {
    set TopLevel.2 [ gui_create_window -type TopLevel \
       -icon $::env(DVE)/auxx/gui/images/toolbars/dvewin.xpm] 
} else { 
    set TopLevel.2 TopLevel.2
}
gui_show_window -window ${TopLevel.2} -show_state maximized -rect {{1 297} {2560 1672}}

# ToolBar settings
gui_set_toolbar_attributes -toolbar {TimeOperations} -dock_state top
gui_set_toolbar_attributes -toolbar {TimeOperations} -offset 0
gui_show_toolbar -toolbar {TimeOperations}
gui_hide_toolbar -toolbar {&File}
gui_set_toolbar_attributes -toolbar {&Edit} -dock_state top
gui_set_toolbar_attributes -toolbar {&Edit} -offset 0
gui_show_toolbar -toolbar {&Edit}
gui_hide_toolbar -toolbar {CopyPaste}
gui_set_toolbar_attributes -toolbar {&Trace} -dock_state top
gui_set_toolbar_attributes -toolbar {&Trace} -offset 0
gui_show_toolbar -toolbar {&Trace}
gui_hide_toolbar -toolbar {TraceInstance}
gui_hide_toolbar -toolbar {BackTrace}
gui_set_toolbar_attributes -toolbar {&Scope} -dock_state top
gui_set_toolbar_attributes -toolbar {&Scope} -offset 0
gui_show_toolbar -toolbar {&Scope}
gui_set_toolbar_attributes -toolbar {&Window} -dock_state top
gui_set_toolbar_attributes -toolbar {&Window} -offset 0
gui_show_toolbar -toolbar {&Window}
gui_set_toolbar_attributes -toolbar {Signal} -dock_state top
gui_set_toolbar_attributes -toolbar {Signal} -offset 0
gui_show_toolbar -toolbar {Signal}
gui_set_toolbar_attributes -toolbar {Zoom} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom} -offset 0
gui_show_toolbar -toolbar {Zoom}
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -dock_state top
gui_set_toolbar_attributes -toolbar {Zoom And Pan History} -offset 0
gui_show_toolbar -toolbar {Zoom And Pan History}
gui_set_toolbar_attributes -toolbar {Grid} -dock_state top
gui_set_toolbar_attributes -toolbar {Grid} -offset 0
gui_show_toolbar -toolbar {Grid}
gui_set_toolbar_attributes -toolbar {Simulator} -dock_state top
gui_set_toolbar_attributes -toolbar {Simulator} -offset 0
gui_show_toolbar -toolbar {Simulator}
gui_set_toolbar_attributes -toolbar {Interactive Rewind} -dock_state top
gui_set_toolbar_attributes -toolbar {Interactive Rewind} -offset 0
gui_show_toolbar -toolbar {Interactive Rewind}
gui_set_toolbar_attributes -toolbar {Testbench} -dock_state top
gui_set_toolbar_attributes -toolbar {Testbench} -offset 0
gui_show_toolbar -toolbar {Testbench}

# End ToolBar settings

# Docked window settings
gui_sync_global -id ${TopLevel.2} -option true

# MDI window settings
set Wave.1 [gui_create_window -type {Wave}  -parent ${TopLevel.2}]
gui_show_window -window ${Wave.1} -show_state maximized
gui_update_layout -id ${Wave.1} {{show_state maximized} {dock_state undocked} {dock_on_new_line false} {child_wave_left 743} {child_wave_right 1811} {child_wave_colname 369} {child_wave_colvalue 370} {child_wave_col1 0} {child_wave_col2 1}}

# End MDI window settings

gui_set_env TOPLEVELS::TARGET_FRAME(Source) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Schematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(PathSchematic) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(Wave) none
gui_set_env TOPLEVELS::TARGET_FRAME(List) none
gui_set_env TOPLEVELS::TARGET_FRAME(Memory) ${TopLevel.1}
gui_set_env TOPLEVELS::TARGET_FRAME(DriverLoad) none
gui_update_statusbar_target_frame ${TopLevel.1}
gui_update_statusbar_target_frame ${TopLevel.2}

#</WindowLayout>

#<Database>

# DVE Open design session: 

if { [llength [lindex [gui_get_db -design Sim] 0]] == 0 } {
gui_set_env SIMSETUP::SIMARGS {{ -V +vc +memcbk -ucligui}}
gui_set_env SIMSETUP::SIMEXE {dve}
gui_set_env SIMSETUP::ALLOW_POLL {0}
if { ![gui_is_db_opened -db {dve}] } {
gui_sim_run Ucli -exe dve -args { -V +vc +memcbk -ucligui} -dir ../milestone3 -nosource
}
}
if { ![gui_sim_state -check active] } {error "Simulator did not start correctly" error}
gui_set_precision 100ps
gui_set_time_units 100ps
#</Database>

# DVE Global setting session: 


# Global: Breakpoints

# Global: Bus

# Global: Expressions
gui_expr_create {cdb_tag[6:0]}  -name EXP:CDB_TAG_0 -type Verilog -scope testbench.pipeline_top_0.pipeline_back_0.ROB_inst
gui_expr_create {cdb_tag[13:7]}  -name EXP:CDB_TAG_1 -type Verilog -scope testbench.pipeline_top_0.pipeline_back_0.ROB_inst
gui_expr_create {cdb_tag[20:14]}  -name EXP:CDB_TAG_2 -type Verilog -scope testbench.pipeline_top_0.pipeline_back_0.ROB_inst
gui_expr_create {cdb_rob[5:0]}  -name EXP:CDB_ROB_0 -type Verilog -scope testbench.pipeline_top_0.pipeline_back_0.ROB_inst
gui_expr_create {cdb_rob[11:6]}  -name EXP:CDB_ROB_1 -type Verilog -scope testbench.pipeline_top_0.pipeline_back_0.ROB_inst
gui_expr_create {cdb_rob[17:12]}  -name EXP:CDB_ROB_2 -type Verilog -scope testbench.pipeline_top_0.pipeline_back_0.ROB_inst

# Global: Signal Time Shift

# Global: Signal Compare

# Global: Signal Groups
gui_load_child_values {testbench.pipeline_top_0.pipeline_back_0.ROB_inst}
gui_load_child_values {testbench.pipeline_top_0.pipeline_front_0}
gui_load_child_values {testbench.pipeline_top_0.pipeline_front_0.id_stage_0}
gui_load_child_values {testbench.memory}


set _session_group_16 Memory
gui_sg_create "$_session_group_16"
set Memory "$_session_group_16"

gui_sg_addsignal -group "$_session_group_16" { testbench.memory.proc2mem_addr testbench.memory.proc2mem_data testbench.memory.proc2mem_command testbench.memory.mem2proc_response testbench.memory.mem2proc_data testbench.memory.mem2proc_tag }

set _session_group_17 ID_STAGE
gui_sg_create "$_session_group_17"
set ID_STAGE "$_session_group_17"

gui_sg_addsignal -group "$_session_group_17" { testbench.pipeline_top_0.pipeline_front_0.id_stage_0.id_packet_out_2 testbench.pipeline_top_0.pipeline_front_0.id_stage_0.id_packet_out_1 testbench.pipeline_top_0.pipeline_front_0.id_stage_0.id_packet_out_0 testbench.pipeline_top_0.pipeline_front_0.inst_avail_num testbench.pipeline_top_0.pipeline_front_0.if_stage_0.rs_rob_haz_stall testbench.pipeline_top_0.pipeline_back_0.ROB_inst.rob_hazard_num testbench.pipeline_top_0.pipeline_front_0.if_stage_0.rs_avail_num }
gui_set_radix -radix {decimal} -signals {Sim:testbench.pipeline_top_0.pipeline_back_0.ROB_inst.rob_hazard_num}
gui_set_radix -radix {unsigned} -signals {Sim:testbench.pipeline_top_0.pipeline_back_0.ROB_inst.rob_hazard_num}
gui_set_radix -radix {decimal} -signals {Sim:testbench.pipeline_top_0.pipeline_front_0.if_stage_0.rs_avail_num}
gui_set_radix -radix {unsigned} -signals {Sim:testbench.pipeline_top_0.pipeline_front_0.if_stage_0.rs_avail_num}

set _session_group_18 id_rs
gui_sg_create "$_session_group_18"
set id_rs "$_session_group_18"

gui_sg_addsignal -group "$_session_group_18" { testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_2 testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_2.PC testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_2.rd_mem testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_2.wr_mem testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_2.valid testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_1 testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_1.PC testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_1.rd_mem testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_1.wr_mem testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_1.valid testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_0 testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_0.PC testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_0.rd_mem testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_0.wr_mem testbench.pipeline_top_0.pipeline_front_0.id_rs_packet_0.valid }

set _session_group_19 {ROB INPUT FROM CDB&FU}
gui_sg_create "$_session_group_19"
set {ROB INPUT FROM CDB&FU} "$_session_group_19"

gui_sg_addsignal -group "$_session_group_19" { testbench.pipeline_top_0.pipeline_back_0.ROB_inst.cdb_valid testbench.pipeline_top_0.pipeline_back_0.ROB_inst.cdb_value testbench.pipeline_top_0.pipeline_back_0.ROB_inst.cdb_tag EXP:CDB_TAG_2 EXP:CDB_TAG_1 EXP:CDB_TAG_0 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.cdb_rob EXP:CDB_ROB_2 EXP:CDB_ROB_1 EXP:CDB_ROB_0 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.cdb_cond_branch testbench.pipeline_top_0.pipeline_back_0.ROB_inst.cdb_uncond_branch testbench.pipeline_top_0.pipeline_back_0.ROB_inst.FU_branch_target_addr testbench.pipeline_top_0.pipeline_back_0.ROB_inst.FU_branch_taken testbench.pipeline_top_0.pipeline_back_0.ROB_inst.FU_store_addr testbench.pipeline_top_0.pipeline_back_0.ROB_inst.FU_store_en testbench.pipeline_top_0.pipeline_back_0.ROB_inst.FU_rob testbench.pipeline_top_0.pipeline_back_0.ROB_inst.FU_store_data }

set _session_group_20 ROB
gui_sg_create "$_session_group_20"
set ROB "$_session_group_20"

gui_sg_addsignal -group "$_session_group_20" { testbench.pipeline_top_0.pipeline_back_0.ROB_inst.store_cnt_dve testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_store_cnt_dve testbench.pipeline_top_0.pipeline_back_0.ROB_inst.commit_cnt testbench.pipeline_top_0.pipeline_back_0.ROB_inst.fetch_cnt testbench.pipeline_top_0.pipeline_back_0.ROB_inst.load_ready testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_2 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_2.id_packet.PC testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_2.valid testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_2.commit testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_2.id_packet.rd_mem testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_2.id_packet.wr_mem testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_1 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_1.id_packet.PC testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_1.valid testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_1.commit testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_1.id_packet.rd_mem testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_1.id_packet.wr_mem testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_0 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_0.id_packet.PC testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_0.valid testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_0.commit testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_0.id_packet.rd_mem testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_packet_out_0.id_packet.wr_mem testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_branch_out_2 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_branch_out_1 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB_branch_out_0 testbench.pipeline_top_0.pipeline_back_0.ROB_inst.head testbench.pipeline_top_0.pipeline_back_0.ROB_inst.tail testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_head testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_tail testbench.pipeline_top_0.pipeline_back_0.ROB_inst.ROB testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_ROB {testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_ROB[4]} testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_nuke testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_3_tail testbench.pipeline_top_0.pipeline_back_0.ROB_inst.next_3_head }

# Global: Highlighting

# Global: Stack
gui_change_stack_mode -mode list

# Post database loading setting...

# Restore C1 time
gui_set_time -C1_only 739603



# Save global setting...

# Wave/List view global setting
gui_list_create_group_when_add -wave -enable
gui_cov_show_value -switch false

# Close all empty TopLevel windows
foreach __top [gui_ekki_get_window_ids -type TopLevel] {
    if { [llength [gui_ekki_get_window_ids -parent $__top]] == 0} {
        gui_close_window -window $__top
    }
}
gui_set_loading_session_type noSession
# DVE View/pane content session: 


# Hier 'Hier.1'
gui_show_window -window ${Hier.1}
gui_list_set_filter -id ${Hier.1} -list { {Package 1} {All 0} {Process 1} {VirtPowSwitch 0} {UnnamedProcess 1} {UDP 0} {Function 1} {Block 1} {SrsnAndSpaCell 0} {OVA Unit 1} {LeafScCell 1} {LeafVlgCell 1} {Interface 1} {LeafVhdCell 1} {$unit 1} {NamedBlock 1} {Task 1} {VlgPackage 1} {ClassDef 1} {VirtIsoCell 0} }
gui_list_set_filter -id ${Hier.1} -text {*}
gui_hier_list_init -id ${Hier.1}
gui_change_design -id ${Hier.1} -design Sim
catch {gui_list_expand -id ${Hier.1} testbench}
catch {gui_list_expand -id ${Hier.1} testbench.pipeline_top_0}
catch {gui_list_expand -id ${Hier.1} testbench.pipeline_top_0.pipeline_front_0}
catch {gui_list_select -id ${Hier.1} {testbench.pipeline_top_0.pipeline_front_0.if_stage_0}}
gui_view_scroll -id ${Hier.1} -vertical -set 0
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Data 'Data.1'
gui_list_set_filter -id ${Data.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {LowPower 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Data.1} -text {*}
gui_list_show_data -id ${Data.1} {testbench.pipeline_top_0.pipeline_front_0.if_stage_0}
gui_show_window -window ${Data.1}
catch { gui_list_select -id ${Data.1} {testbench.pipeline_top_0.pipeline_front_0.if_stage_0.rs_avail_num }}
gui_view_scroll -id ${Data.1} -vertical -set 0
gui_view_scroll -id ${Data.1} -horizontal -set 0
gui_view_scroll -id ${Hier.1} -vertical -set 0
gui_view_scroll -id ${Hier.1} -horizontal -set 0

# Source 'Source.1'
gui_src_value_annotate -id ${Source.1} -switch false
gui_set_env TOGGLE::VALUEANNOTATE 0
gui_open_source -id ${Source.1}  -replace -active testbench testbench/testbench.sv
gui_view_scroll -id ${Source.1} -vertical -set 6210
gui_src_set_reusable -id ${Source.1}

# View 'Wave.1'
gui_wv_sync -id ${Wave.1} -switch false
set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 738448 741035
gui_list_add_group -id ${Wave.1} -after {New Group} {Memory}
gui_list_add_group -id ${Wave.1} -after {New Group} {ID_STAGE}
gui_list_add_group -id ${Wave.1} -after {New Group} {id_rs}
gui_list_add_group -id ${Wave.1} -after {New Group} {{ROB INPUT FROM CDB&FU}}
gui_list_add_group -id ${Wave.1} -after {New Group} {ROB}
gui_list_select -id ${Wave.1} {EXP:CDB_TAG_2 }
gui_seek_criteria -id ${Wave.1} {Any Edge}



gui_set_env TOGGLE::DEFAULT_WAVE_WINDOW ${Wave.1}
gui_set_pref_value -category Wave -key exclusiveSG -value $groupExD
gui_list_set_height -id Wave -height $origWaveHeight
if {$origGroupCreationState} {
	gui_list_create_group_when_add -wave -enable
}
if { $groupExD } {
 gui_msg_report -code DVWW028
}
gui_list_set_filter -id ${Wave.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Wave.1} -text {*}
gui_list_set_insertion_bar  -id ${Wave.1} -group {ROB INPUT FROM CDB&FU}  -item EXP:CDB_TAG_2 -position below

gui_marker_move -id ${Wave.1} {C1} 739603
gui_view_scroll -id ${Wave.1} -vertical -set 334
gui_show_grid -id ${Wave.1} -enable false
# Restore toplevel window zorder
# The toplevel window could be closed if it has no view/pane
if {[gui_exist_window -window ${TopLevel.1}]} {
	gui_set_active_window -window ${TopLevel.1}
	gui_set_active_window -window ${Source.1}
	gui_set_active_window -window ${DLPane.1}
}
if {[gui_exist_window -window ${TopLevel.2}]} {
	gui_set_active_window -window ${TopLevel.2}
	gui_set_active_window -window ${Wave.1}
}
#</Session>

