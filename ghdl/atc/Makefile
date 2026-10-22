# the opening comment block of a testbench, without the leading "-- "
TBDOC = sed -n '/^--/!q; /^---\{1,\}$$/{p;d;}; s/^-- \{0,1\}//p'

all: modules-a modules-e testbenches

modules-a:
	ghdl -a --warn-all ../integration/common.vhd
	ghdl -a --warn-all ../integration/register_map.vhd
	ghdl -a --warn-all rising_edge_sync.vhd
	ghdl -a --warn-all timestamp.vhd
	ghdl -a --warn-all timer.vhd
	ghdl -a --warn-all atc_timer.vhd
	ghdl -a --warn-all counter.vhd
	ghdl -a --warn-all atc_buffer.vhd
	ghdl -a --warn-all atc_registers.vhd
	ghdl -a --warn-all atc_mux.vhd
	ghdl -a --warn-all atc_counter.vhd
	ghdl -a --warn-all atc_unit.vhd

modules-e:
	ghdl -e --warn-all rising_edge_sync
	ghdl -e --warn-all timer
	ghdl -e --warn-all atc_timer
	ghdl -e --warn-all timestamp
	ghdl -e --warn-all counter
	ghdl -e --warn-all atc_buffer
	ghdl -e --warn-all atc_registers
	ghdl -e --warn-all atc_mux
	ghdl -e --warn-all atc_counter
	ghdl -e --warn-all atc_unit

testbenches:
	ghdl -a --warn-all -fsynopsys ../integration/tb/tb_utils.vhd
	ghdl -a --warn-all -fsynopsys tb/rising_edge_sync_tb.vhd
	ghdl -e --warn-all -fsynopsys rising_edge_sync_tb
	ghdl -a --warn-all -fsynopsys tb/atc_registers_tb.vhd
	ghdl -e --warn-all -fsynopsys atc_registers_tb
	ghdl -a --warn-all -fsynopsys tb/timer_tb.vhd
	ghdl -e --warn-all -fsynopsys timer_tb
	ghdl -a --warn-all -fsynopsys tb/atc_timer_tb.vhd
	ghdl -e --warn-all -fsynopsys atc_timer_tb
	ghdl -a --warn-all -fsynopsys tb/timestamp_tb.vhd
	ghdl -e --warn-all -fsynopsys timestamp_tb
	ghdl -a --warn-all -fsynopsys tb/counter_tb.vhd
	ghdl -e --warn-all -fsynopsys counter_tb
	ghdl -a --warn-all -fsynopsys tb/atc_counter_tb.vhd
	ghdl -e --warn-all -fsynopsys atc_counter_tb
	ghdl -a --warn-all -fsynopsys tb/atc_buffer_tb.vhd
	ghdl -e --warn-all -fsynopsys atc_buffer_tb
	ghdl -a --warn-all -fsynopsys tb/atc_mux_tb.vhd
	ghdl -e --warn-all -fsynopsys atc_mux_tb
	ghdl -a --warn-all -fsynopsys tb/atc_unit_tb.vhd
	ghdl -e --warn-all -fsynopsys atc_unit_tb

# stop time of each testbench
STOP_rising_edge_sync_tb = 2us
STOP_atc_registers_tb    = 10us
STOP_timer_tb            = 300ns
STOP_counter_tb          = 300ns
STOP_atc_buffer_tb       = 300ns
STOP_atc_mux_tb          = 1us
STOP_atc_counter_tb      = 300ns
STOP_timestamp_tb        = 200ns
STOP_atc_timer_tb        = 300ns
STOP_atc_unit_tb         = 1us

TESTBENCHES = rising_edge_sync_tb atc_registers_tb timer_tb counter_tb atc_buffer_tb atc_mux_tb atc_counter_tb timestamp_tb atc_timer_tb

# a requested name with no stop time is not a testbench here:  stop before building anything
$(foreach t,$(patsubst run-%,%,$(filter run-%_tb,$(MAKECMDGOALS))),$(if $(STOP_$(t)),,\
  $(error unknown testbench $(t);  here:  $(sort $(patsubst STOP_%,%,$(filter STOP_%,$(.VARIABLES)))))))

# make run-<name>_tb:  one testbench, run exactly as run-testbenches runs it
run-%_tb: all
	@$(TBDOC) tb/$*_tb.vhd
	ghdl -r -fsynopsys $*_tb --stop-time=$(STOP_$*_tb)

run-testbenches: $(addprefix run-,$(TESTBENCHES))

run-unit-testbench: run-atc_unit_tb

run-dev: all
	@$(TBDOC) tb/timestamp_tb.vhd
	ghdl -r -fsynopsys timestamp_tb --stop-time=200ns

# the testbench descriptions only:  no build, no simulation
descriptions:
	@for f in tb/*_tb.vhd; do $(TBDOC) $$f; done
