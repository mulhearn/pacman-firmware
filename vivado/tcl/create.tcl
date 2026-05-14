#
# create.tcl:  tcl-based vivado project creation for PACMAN
#

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir [file dirname [info script]]/..


# Obtain required HW version (e.g. hw1v5)
if {[llength $argv] != 1} {
    puts "ERROR: the hardware version must be provided via -tclargs <HW version>"
    exit 1
}

set hw_version [lindex $argv 0]
puts "INFO:  creating PACMAN project for hardware version: $hw_version"

# Set the project name
set proj_name "pacman-fw"

# Create project
create_project $proj_name $origin_dir/$proj_name -part xc7z020clg484-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/$proj_name.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/${proj_name}.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
#set_property -name "source_mgmt_mode" -value "DisplayOnly" -objects $obj
set_property -name "source_mgmt_mode" -value "All" -objects $obj
set_property -name "target_language" -value "VHDL" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_MEMORY" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Create the txfifo IP:
source $origin_dir/tcl/regbus.tcl

# Set IP repository paths
set obj [get_filesets sources_1]
if { $obj != {} } {
   set_property "ip_repo_paths" "[file normalize "$origin_dir/ip_repo"] [file normalize "$origin_dir/gen/ip"]" $obj

   # Rebuild user ip_repo's index before adding any source files
   update_ip_catalog -rebuild
}


# Write project source files to 'sources_1' fileset:
set obj [get_filesets sources_1]

# Include external ASIC emulation if available:
set asic_dir [file normalize $origin_dir/src/external/larpix_v3c]
set asic_src_dir $asic_dir/src
set asic_files [glob -nocomplain $asic_src_dir/*.sv]
set use_asic_rtl [expr {[llength $asic_files] > 0}]

if {$use_asic_rtl} {
    puts "INFO: ASIC RTL: including [llength $asic_files] file(s) from $asic_src_dir"
    add_files -norecurse -fileset sources_1 $asic_files
    set asic_file_objs [get_files -of_objects [get_filesets sources_1] $asic_src_dir/*.sv]
    set_property file_type SystemVerilog $asic_file_objs
    # These files are include fragments, not standalone modules
    set header_files {larpix_constants.sv config_regfile_assign.sv priority_onehot.sv}
    foreach hf $header_files {
        set fobj [get_files $asic_src_dir/$hf]
        if {$fobj ne ""} {
            set_property file_type {Verilog Header} $fobj
            puts "INFO: ASIC RTL: marked $hf as Verilog Header"
        }
    }
    set_property include_dirs $asic_src_dir [get_filesets sources_1]
} else {
    puts "INFO: ASIC RTL: no files found in $asic_src_dir, skipping"
}

# add all vhd files in src/hdl to project (excluding digital_core if ASIC emulation is in use):
set files {}
foreach file [glob src/hdl/*.vhd src/hdl/$hw_version/*.vhd] {
    if {$use_asic_rtl && [file tail $file] eq "digital_core.vhd"} continue
    if {$use_asic_rtl && [file tail $file] eq "uart_tx.vhd"} continue
    lappend files [file normalize $file]
}
puts "HDL files:  $files"
add_files -norecurse -fileset sources_1 $files

# determine version info at project creation, and record:
source $origin_dir/tcl/version_info.tcl
add_files -fileset sources_1 gen/hdl/version_info_pkg.vhd

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property -name "top" -value "zsys_wrapper" -objects $obj

#Create block design
source $origin_dir/src/bd/$hw_version/zsys.tcl

# Generate the wrapper
set design_name [get_bd_designs]
make_wrapper -files [get_files ${design_name}.bd] -top -import

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}
set obj [get_filesets constrs_1]
set files {}
foreach file [glob src/constraints/*.xdc src/constraints/$hw_version/*.xdc] {lappend files [file normalize $file]}
puts "Constraint files:  $files"
add_files -norecurse -fileset $obj $files

set file_obj [get_files -of_objects [get_filesets constrs_1]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

#update_compile_order -fileset sources_1
