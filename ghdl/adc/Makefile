# the opening comment block of a testbench, without the leading "-- "
TBDOC = sed -n '/^--/!q; /^---\{1,\}$$/{p;d;}; s/^-- \{0,1\}//p'

all: modules-a modules-e testbenches

modules-a:
	ghdl -a --warn-all ../integration/common.vhd
	ghdl -a --warn-all ../integration/register_map.vhd
	ghdl -a --warn-all adc_emul.vhd
	ghdl -a --warn-all adc_mux.vhd
	ghdl -a --warn-all adc_cmp.vhd
	ghdl -a --warn-all ../bram/bram_buffer.vhd
	ghdl -a --warn-all adc_registers.vhd
	ghdl -a --warn-all adc_unit.vhd

modules-e:
	ghdl -e --warn-all adc_emul
	ghdl -e --warn-all adc_mux
	ghdl -e --warn-all adc_cmp
	ghdl -e --warn-all adc_registers
	ghdl -e --warn-all adc_unit

testbenches:
	ghdl -a --warn-all -fsynopsys ../integration/tb/tb_utils.vhd
	ghdl -a --warn-all -fsynopsys tb/adc_emul_tb.vhd
	ghdl -e --warn-all -fsynopsys adc_emul_tb
	ghdl -a --warn-all -fsynopsys tb/adc_mux_tb.vhd
	ghdl -e --warn-all -fsynopsys adc_mux_tb
	ghdl -a --warn-all -fsynopsys tb/adc_cmp_tb.vhd
	ghdl -e --warn-all -fsynopsys adc_cmp_tb
	ghdl -a --warn-all -fsynopsys tb/adc_registers_tb.vhd
	ghdl -e --warn-all -fsynopsys adc_registers_tb
	ghdl -a --warn-all -fsynopsys tb/adc_unit_tb.vhd
	ghdl -e --warn-all -fsynopsys adc_unit_tb

# stop time of each testbench
STOP_adc_emul_tb      = 400ns
STOP_adc_mux_tb       = 100ns
STOP_adc_cmp_tb       = 250ns
STOP_adc_registers_tb = 1us
STOP_adc_unit_tb      = 1us

TESTBENCHES = adc_emul_tb adc_mux_tb adc_cmp_tb adc_registers_tb

# a requested name with no stop time is not a testbench here:  stop before building anything
$(foreach t,$(patsubst run-%,%,$(filter run-%_tb,$(MAKECMDGOALS))),$(if $(STOP_$(t)),,\
  $(error unknown testbench $(t);  here:  $(sort $(patsubst STOP_%,%,$(filter STOP_%,$(.VARIABLES)))))))

# make run-<name>_tb:  one testbench, run exactly as run-testbenches runs it
run-%_tb: all
	@$(TBDOC) tb/$*_tb.vhd
	ghdl -r -fsynopsys $*_tb --stop-time=$(STOP_$*_tb)

run-testbenches: $(addprefix run-,$(TESTBENCHES))

run-unit-testbench: run-adc_unit_tb

# the testbench descriptions only:  no build, no simulation
descriptions:
	@for f in tb/*_tb.vhd; do $(TBDOC) $$f; done
