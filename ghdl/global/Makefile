# the opening comment block of a testbench, without the leading "-- "
TBDOC = sed -n '/^--/!q; /^---\{1,\}$$/{p;d;}; s/^-- \{0,1\}//p'

all: modules-a modules-e testbenches

modules-a:
	ghdl -a --warn-all ../hardware/hw1v5/hardware_version.vhd
	ghdl -a --warn-all ../integration/firmware_version.vhd
	ghdl -a --warn-all ../integration/common.vhd
	ghdl -a --warn-all ../integration/register_map.vhd
	ghdl -a --warn-all ../integration/gen/version_info_pkg.vhd
	ghdl -a --warn-all global_registers.vhd
	ghdl -a --warn-all global_status.vhd
	ghdl -a --warn-all global_unit.vhd

modules-e:
	ghdl -e --warn-all global_registers
	ghdl -e --warn-all global_status
	ghdl -e --warn-all global_unit

testbenches:
	ghdl -a --warn-all -fsynopsys ../integration/tb/tb_utils.vhd
	ghdl -a --warn-all -fsynopsys tb/global_registers_tb.vhd
	ghdl -e --warn-all -fsynopsys global_registers_tb
	ghdl -a --warn-all -fsynopsys tb/global_status_tb.vhd
	ghdl -e --warn-all -fsynopsys global_status_tb
	ghdl -a --warn-all -fsynopsys tb/global_unit_tb.vhd
	ghdl -e --warn-all -fsynopsys global_unit_tb

# stop time of each testbench
STOP_global_registers_tb = 5us
STOP_global_status_tb    = 150ns
STOP_global_unit_tb      = 400ns

TESTBENCHES = global_registers_tb global_status_tb

# a requested name with no stop time is not a testbench here:  stop before building anything
$(foreach t,$(patsubst run-%,%,$(filter run-%_tb,$(MAKECMDGOALS))),$(if $(STOP_$(t)),,\
  $(error unknown testbench $(t);  here:  $(sort $(patsubst STOP_%,%,$(filter STOP_%,$(.VARIABLES)))))))

# make run-<name>_tb:  one testbench, run exactly as run-testbenches runs it
run-%_tb: all
	@$(TBDOC) tb/$*_tb.vhd
	ghdl -r -fsynopsys $*_tb --stop-time=$(STOP_$*_tb)

run-testbenches: $(addprefix run-,$(TESTBENCHES))

run-unit-testbench: run-global_unit_tb

# the testbench descriptions only:  no build, no simulation
descriptions:
	@for f in tb/*_tb.vhd; do $(TBDOC) $$f; done
