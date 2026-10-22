# the opening comment block of a testbench, without the leading "-- "
TBDOC = sed -n '/^--/!q; /^---\{1,\}$$/{p;d;}; s/^-- \{0,1\}//p'

all: modules-a modules-e testbenches

modules-a:
	ghdl -a --warn-all ../integration/common.vhd
	ghdl -a --warn-all ../integration/register_map.vhd
	ghdl -a --warn-all ../axi/axis_read.vhd
	ghdl -a --warn-all tx_chan.vhd
	ghdl -a --warn-all tx_registers.vhd
	ghdl -a --warn-all tx_buffer.vhd
	ghdl -a --warn-all tx_data_mux.vhd
	ghdl -a --warn-all tx_unit.vhd

modules-e:
	ghdl -e --warn-all axis_read
	ghdl -e --warn-all tx_chan
	ghdl -e --warn-all tx_registers
	ghdl -e --warn-all tx_buffer
	ghdl -e --warn-all tx_data_mux
	ghdl -e --warn-all tx_unit

testbenches:
	ghdl -a --warn-all -fsynopsys ../integration/tb/tb_utils.vhd
	ghdl -a --warn-all -fsynopsys tb/tx_chan_tb.vhd
	ghdl -e --warn-all -fsynopsys tx_chan_tb
	ghdl -a --warn-all -fsynopsys tb/tx_registers_tb.vhd
	ghdl -e --warn-all -fsynopsys tx_registers_tb
	ghdl -a --warn-all -fsynopsys tb/tx_buffer_tb.vhd
	ghdl -e --warn-all -fsynopsys tx_buffer_tb
	ghdl -a --warn-all -fsynopsys tb/tx_data_mux_tb.vhd
	ghdl -e --warn-all -fsynopsys tx_data_mux_tb
	ghdl -a --warn-all -fsynopsys tb/tx_unit_tb.vhd
	ghdl -e --warn-all -fsynopsys tx_unit_tb

# stop time of each testbench
STOP_tx_chan_tb      = 5us
STOP_tx_registers_tb = 2us
STOP_tx_buffer_tb    = 700ns
STOP_tx_data_mux_tb  = 100ns
STOP_tx_unit_tb      = 20us

TESTBENCHES = tx_chan_tb tx_registers_tb tx_buffer_tb tx_data_mux_tb

# a requested name with no stop time is not a testbench here:  stop before building anything
$(foreach t,$(patsubst run-%,%,$(filter run-%_tb,$(MAKECMDGOALS))),$(if $(STOP_$(t)),,\
  $(error unknown testbench $(t);  here:  $(sort $(patsubst STOP_%,%,$(filter STOP_%,$(.VARIABLES)))))))

# make run-<name>_tb:  one testbench, run exactly as run-testbenches runs it
run-%_tb: all
	@$(TBDOC) tb/$*_tb.vhd
	ghdl -r -fsynopsys $*_tb --stop-time=$(STOP_$*_tb)

run-testbenches: $(addprefix run-,$(TESTBENCHES))

run-unit-testbench: run-tx_unit_tb

run-dev: all
	@$(TBDOC) tb/tx_chan_tb.vhd
	ghdl -r -fsynopsys tx_chan_tb --stop-time=5us

# the testbench descriptions only:  no build, no simulation
descriptions:
	@for f in tb/*_tb.vhd; do $(TBDOC) $$f; done
