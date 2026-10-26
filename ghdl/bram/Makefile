# the opening comment block of a testbench, without the leading "-- "
TBDOC = sed -n '/^--/!q; /^---\{1,\}$$/{p;d;}; s/^-- \{0,1\}//p'

all: modules-a modules-e testbenches

modules-a:
	ghdl -a --warn-all ../integration/common.vhd
	ghdl -a --warn-all bram_buffer.vhd

modules-e:
	ghdl -e --warn-all bram_buffer

testbenches:
	ghdl -a --warn-all -fsynopsys ../integration/tb/tb_utils.vhd
	ghdl -a --warn-all -fsynopsys tb/bram_buffer_tb.vhd
	ghdl -e --warn-all -fsynopsys bram_buffer_tb

# stop time of each testbench
STOP_bram_buffer_tb = 400ns

TESTBENCHES = bram_buffer_tb

# a requested name with no stop time is not a testbench here:  stop before building anything
$(foreach t,$(patsubst run-%,%,$(filter run-%_tb,$(MAKECMDGOALS))),$(if $(STOP_$(t)),,\
  $(error unknown testbench $(t);  here:  $(sort $(patsubst STOP_%,%,$(filter STOP_%,$(.VARIABLES)))))))

# make run-<name>_tb:  one testbench, run exactly as run-testbenches runs it
run-%_tb: all
	@$(TBDOC) tb/$*_tb.vhd
	ghdl -r -fsynopsys $*_tb --stop-time=$(STOP_$*_tb)

run-testbenches: $(addprefix run-,$(TESTBENCHES))

run-unit-testbench: run-bram_buffer_tb

# the testbench descriptions only:  no build, no simulation
descriptions:
	@for f in tb/*_tb.vhd; do $(TBDOC) $$f; done
