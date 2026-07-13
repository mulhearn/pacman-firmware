all: modules-a modules-e testbenches

modules-a:
	echo "*** modules analysis ***"
	ghdl -a ../integration/common.vhd
	ghdl -a regbus_fanout.vhd
	ghdl -a regbus_cdc.vhd
	ghdl -a regbus_hub.vhd
	ghdl -a registers_scratch.vhd
modules-e:
	echo "*** module elaboration ***"
	ghdl -e regbus_fanout
	ghdl -e regbus_cdc
	ghdl -e regbus_hub
	ghdl -e registers_scratch
testbenches:
	echo "*** testbench analysis and elaboration ***"
	ghdl -a -fsynopsys tb/registers_scratch_tb.vhd
	ghdl -e -fsynopsys registers_scratch_tb
	ghdl -a -fsynopsys tb/regbus_fanout_tb.vhd
	ghdl -e -fsynopsys regbus_fanout_tb
	ghdl -a -fsynopsys tb/regbus_cdc_tb.vhd
	ghdl -e -fsynopsys regbus_cdc_tb
	ghdl -a -fsynopsys tb/regbus_hub_tb.vhd
	ghdl -e -fsynopsys regbus_hub_tb


run-testbenches:
	ghdl -r -fsynopsys registers_scratch_tb --stop-time=350ns
	ghdl -r -fsynopsys regbus_fanout_tb --stop-time=350ns
	ghdl -r -fsynopsys regbus_cdc_tb --stop-time=350ns
	ghdl -r -fsynopsys regbus_hub_tb --stop-time=350ns
