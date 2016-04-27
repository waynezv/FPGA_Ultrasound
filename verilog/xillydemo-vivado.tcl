# Xillydemo project generation script for Vivado 2014.4 and up

set origin_dir [file dirname [info script]]

if {[string first { } $origin_dir] >= 0} {
send_msg_id xillydemo-1 error "The path to the the project directory contains white space(s): \"$origin_dir\". This is known to cause problems with Vivado. Please move the project to a path without white spaces, and try again."
}

set proj_name xillydemo
set proj_dir "[file normalize $origin_dir/vivado]"
set thepart "xc7z020clg484-1"

# Set the directory for essentials for Vivado
set essentials_dir "[file normalize "$origin_dir/../vivado-essentials"]"

# Create project
create_project $proj_name "$proj_dir/"

# Set project properties
set obj [get_projects $proj_name]
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" $thepart $obj
set_property "simulator_language" "Mixed" $obj
set_property "source_mgmt_mode" "DisplayOnly" $obj
set_property target_language Verilog $obj
set_property "ip_repo_paths" "$essentials_dir/vivado-ip" $obj
update_ip_catalog

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property "edif_extra_search_paths" "[file normalize "$origin_dir/../cores"]" $obj
set_property "top" "xillydemo" $obj

# Add files to 'sources_1' fileset
set obj [get_filesets sources_1]
set files [list \
 $origin_dir/src/xillydemo.v \
 $origin_dir/src/smbus.v \
 $origin_dir/src/i2s_audio.v \
 $origin_dir/src/xillybus.v \
 $origin_dir/src/xillybus_core.v \
 $essentials_dir/system.v \
 $essentials_dir/vga_fifo/vga_fifo.xci \
 $essentials_dir/fifo_8x2048/fifo_8x2048.xci \
 $essentials_dir/fifo_32x512/fifo_32x512.xci \
 $essentials_dir/vivado_system/vivado_system.bd \
]
add_files -norecurse -fileset $obj $files

upgrade_ip [get_ips]

# A bug in Vivado drops one slave interface on the AXI4-Lite to AXI3
# crossbar when vivado_system.bd is loaded. So AXI4-Lite slaves are
# connected with the Tcl commands below.

open_bd_design $essentials_dir/vivado_system/vivado_system.bd
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins xillybus_ip_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins xillyvga_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins xillybus_lite_0/S_AXI]
set_property range 4K [get_bd_addr_segs {processing_system7_0/Data/SEG_xillybus_ip_0_reg0}]
set_property range 4K [get_bd_addr_segs {processing_system7_0/Data/SEG_xillyvga_0_reg0}]
set_property range 4K [get_bd_addr_segs {processing_system7_0/Data/SEG_xillybus_lite_0_reg0}]
set_property offset 0x50000000 [get_bd_addr_segs {processing_system7_0/Data/SEG_xillybus_ip_0_reg0}]
set_property offset 0x50001000 [get_bd_addr_segs {processing_system7_0/Data/SEG_xillyvga_0_reg0}]
set_property offset 0x50002000 [get_bd_addr_segs {processing_system7_0/Data/SEG_xillybus_lite_0_reg0}]
endgroup
save_bd_design
close_bd_design vivado_system

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Add files to 'constrs_1' fileset
set obj [get_filesets constrs_1]
add_files -fileset $obj -norecurse $essentials_dir/xillydemo.xdc

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets sim_1] ""]} {
  create_fileset -simset sim_1
}

# Add files to 'sim_1' fileset
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property "top" "unknown" $obj
set_property "xsim.simulate.runtime" "1000 ns" $obj
set_property "xsim.simulate.uut" "UUT" $obj

# Create 'synth_1' run (if not found)
if {[string equal [get_runs synth_1] ""]} {
  create_run -name synth_1 -part $thepart -flow {Vivado Synthesis 2013} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
}
set obj [get_runs synth_1]
set_property "part" $thepart $obj

# Create 'impl_1' run (if not found)
if {[string equal [get_runs impl_1] ""]} {
  create_run -name impl_1 -part $thepart -flow {Vivado Implementation 2013} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
}
set obj [get_runs impl_1]
set_property "part" $thepart $obj
set_property STEPS.ROUTE_DESIGN.TCL.POST "$essentials_dir/showstopper.tcl" $obj

# Calm down critical warnings for issues that are known to be OK
set_msg_config -new_severity "INFO" -id {BD 41-968} -string {{xillybus_S_AXI} } 
set_msg_config -new_severity "INFO" -id {BD 41-967} -string {{xillybus_ip_0/xillybus_M_AXI} } 
set_msg_config -new_severity "INFO" -id {BD 41-967} -string {{xillybus_ip_0/xillybus_S_AXI} } 
set_msg_config -new_severity "INFO" -id {BD 41-678} -string {{xillybus_S_AXI/Reg} } 
set_msg_config -new_severity "INFO" -id {BD 41-1356} -string {{xillybus_S_AXI/Reg} }
set_msg_config -new_severity "INFO" -id {BD 41-759} -string {{xlconcat_0/In} }
set_msg_config -new_severity "INFO" -id {BD 41-759} -string {{xlconcat_0/In} }

# The processor's native pads are detached in the logic design to prevent
# Vivado from confusing itself. This causes a lot of critical warnings about
# meaningless contraints not being applied. So drop the warnings.
set_msg_config -new_severity "INFO" -id {Netlist 29-160} -string {{vivado_system_processing_system7} }

puts "INFO: Project created: $proj_name"

# Uncomment the two following lines for a full implementation
#launch_runs -jobs 8 impl_1 -to_step write_bitstream
#wait_on_run impl_1
