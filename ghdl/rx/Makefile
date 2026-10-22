# the opening comment block of a testbench, without the leading "-- "
TBDOC = sed -n '/^--/!q; /^---\{1,\}$$/{p;d;}; s/^-- \{0,1\}//p'

all: modules-a modules-e testbenches

modules-a:
	ghdl -a --warn-all ../integration/common.vhd
	ghdl -a --warn-all ../integration/register_map.vhd
	ghdl -a --warn-all ../axi/axis_write.vhd
	ghdl -a --warn-all pattern.vhd
	ghdl -a --warn-all rx_data_mux.vhd
	ghdl -a --warn-all rx_timestamp_mux.vhd
	ghdl -a --warn-all rx_header.vhd
	ghdl -a --warn-all rx_registers.vhd
	ghdl -a --warn-all rx_chan.vhd
	ghdl -a --warn-all heartbeat.vhd
	ghdl -a --warn-all rollover.vhd
	ghdl -a --warn-all marker.vhd
	ghdl -a --warn-all rx_buffer.vhd
	ghdl -a --warn-all rx_unit.vhd

modules-e:
	ghdl -e --warn-all pattern
	ghdl -e --warn-all rx_data_mux
	ghdl -e --warn-all rx_timestamp_mux
	ghdl -e --warn-all rx_header
	ghdl -e --warn-all rx_registers
	ghdl -e --warn-all rx_chan
	ghdl -e --warn-all heartbeat
	ghdl -e --warn-all rollover
	ghdl -e --warn-all marker
	ghdl -e --warn-all rx_buffer
	ghdl -e --warn-all rx_unit

testbenches:
	ghdl -a --warn-all -fsynopsys ../integration/tb/tb_utils.vhd
	ghdl -a --warn-all -fsynopsys tb/rx_registers_tb.vhd
	ghdl -e --warn-all -fsynopsys rx_registers_tb
	ghdl -a --warn-all -fsynopsys tb/pattern_tb.vhd
	ghdl -e --warn-all -fsynopsys pattern_tb
	ghdl -a --warn-all -fsynopsys tb/rx_data_mux_tb.vhd
	ghdl -e --warn-all -fsynopsys rx_data_mux_tb
	ghdl -a --warn-all -fsynopsys tb/rx_timestamp_mux_tb.vhd
	ghdl -e --warn-all -fsynopsys rx_timestamp_mux_tb
	ghdl -a --warn-all -fsynopsys tb/rx_header_tb.vhd
	ghdl -e --warn-all -fsynopsys rx_header_tb
	ghdl -a --warn-all -fsynopsys tb/rx_chan_tb.vhd
	ghdl -e --warn-all -fsynopsys rx_chan_tb
	ghdl -a --warn-all -fsynopsys tb/heartbeat_tb.vhd
	ghdl -e --warn-all -fsynopsys heartbeat_tb
	ghdl -a --warn-all -fsynopsys tb/rollover_tb.vhd
	ghdl -e --warn-all -fsynopsys rollover_tb
	ghdl -a --warn-all -fsynopsys tb/marker_tb.vhd
	ghdl -e --warn-all -fsynopsys marker_tb
	ghdl -a --warn-all -fsynopsys tb/rx_buffer_tb.vhd
	ghdl -e --warn-all -fsynopsys rx_buffer_tb
	ghdl -a --warn-all -fsynopsys tb/rx_unit_tb.vhd
	ghdl -e --warn-all -fsynopsys rx_unit_tb

# stop time of each testbench
STOP_heartbeat_tb        = 30us
STOP_marker_tb           = 30us
STOP_rx_chan_tb          = 30us
STOP_rollover_tb         = 30us
STOP_rx_registers_tb     = 5us
STOP_rx_buffer_tb        = 1us
STOP_rx_header_tb        = 500ns
STOP_rx_timestamp_mux_tb = 100ns
STOP_rx_data_mux_tb      = 100ns
STOP_pattern_tb          = 14us
STOP_rx_unit_tb          = 30us

TESTBENCHES = heartbeat_tb marker_tb rx_chan_tb rollover_tb rx_registers_tb rx_buffer_tb rx_header_tb rx_timestamp_mux_tb rx_data_mux_tb pattern_tb

# a requested name with no stop time is not a testbench here:  stop before building anything
$(foreach t,$(patsubst run-%,%,$(filter run-%_tb,$(MAKECMDGOALS))),$(if $(STOP_$(t)),,\
  $(error unknown testbench $(t);  here:  $(sort $(patsubst STOP_%,%,$(filter STOP_%,$(.VARIABLES)))))))

# make run-<name>_tb:  one testbench, run exactly as run-testbenches runs it
run-%_tb: all
	@$(TBDOC) tb/$*_tb.vhd
	ghdl -r -fsynopsys $*_tb --stop-time=$(STOP_$*_tb)

run-testbenches: $(addprefix run-,$(TESTBENCHES))

run-unit-testbench: run-rx_unit_tb

run-dev: all
	ghdl -r -fsynopsys rx_chan_tb --stop-time=30us

# the testbench descriptions only:  no build, no simulation
descriptions:
	@for f in tb/*_tb.vhd; do $(TBDOC) $$f; done
