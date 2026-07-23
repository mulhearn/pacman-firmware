all: modules-a modules-e testbenches

modules-a:
	echo "*** modules analysis ***"
	ghdl -a ../integration/common.vhd
	ghdl -a ../integration/register_map.vhd
	ghdl -a rising_edge_sync.vhd
	ghdl -a timestamp.vhd
	ghdl -a timer.vhd
	ghdl -a atc_timer.vhd
	ghdl -a counter.vhd
	ghdl -a atc_buffer.vhd
	ghdl -a atc_registers.vhd
	ghdl -a atc_mux.vhd
	ghdl -a atc_counter.vhd
	ghdl -a atc_unit.vhd


modules-e:
	echo "*** module elaboration ***"
	ghdl -e rising_edge_sync
	ghdl -e timer
	ghdl -e atc_timer
	ghdl -e timestamp
	ghdl -e counter
	ghdl -e atc_buffer
	ghdl -e atc_registers
	ghdl -e atc_mux
	ghdl -e atc_counter
	ghdl -e atc_unit

testbenches:
	echo "*** testbench analysis and elaboration ***"
	ghdl -a -fsynopsys tb/rising_edge_sync_tb.vhd
	ghdl -e -fsynopsys rising_edge_sync_tb
	ghdl -a -fsynopsys tb/atc_registers_tb.vhd
	ghdl -e -fsynopsys atc_registers_tb
	ghdl -a -fsynopsys tb/timer_tb.vhd
	ghdl -e -fsynopsys timer_tb
	ghdl -a -fsynopsys tb/atc_timer_tb.vhd
	ghdl -e -fsynopsys atc_timer_tb
	ghdl -a -fsynopsys tb/timestamp_tb.vhd
	ghdl -e -fsynopsys timestamp_tb
	ghdl -a -fsynopsys tb/counter_tb.vhd
	ghdl -e -fsynopsys counter_tb
	ghdl -a -fsynopsys tb/atc_counter_tb.vhd
	ghdl -e -fsynopsys atc_counter_tb
	ghdl -a -fsynopsys tb/atc_buffer_tb.vhd
	ghdl -e -fsynopsys atc_buffer_tb
	ghdl -a -fsynopsys tb/atc_mux_tb.vhd
	ghdl -e -fsynopsys atc_mux_tb
	ghdl -a -fsynopsys tb/atc_unit_tb.vhd
	ghdl -e -fsynopsys atc_unit_tb

run-testbenches: all
	ghdl -r -fsynopsys rising_edge_sync_tb --stop-time=2000ns
	ghdl -r -fsynopsys atc_registers_tb --stop-time=500ns
	ghdl -r -fsynopsys timer_tb --stop-time=300ns
	ghdl -r -fsynopsys counter_tb --stop-time=300ns
	ghdl -r -fsynopsys atc_buffer_tb --stop-time=300ns
	ghdl -r -fsynopsys atc_mux_tb --stop-time=1000ns
	ghdl -r -fsynopsys atc_counter_tb --stop-time=5us


run-unit-testbench: all
	ghdl -r -fsynopsys atc_unit_tb --stop-time=1000ns

run-dev: all
	ghdl -r -fsynopsys timestamp_tb --stop-time=200ns





