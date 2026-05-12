# synth.tcl - Run full synthesis on existing project, write reports
open_project pacman-fw/pacman-fw.xpr

# Don't crash my laptop
set_param general.maxThreads 2

# Use digital_core_wrapper as top-level, to only test ASIC emulation
set_property top digital_core_wrapper [get_filesets sources_1]

# Run synthesis
synth_design -top digital_core_wrapper

# Save reports:
write_checkpoint -force post_synth.dcp
report_utilization -file post_synth_util.rpt
report_utilization -hierarchical -file post_synth_util_hier.rpt
report_timing_summary -file post_synth_timing.rpt

close_project
