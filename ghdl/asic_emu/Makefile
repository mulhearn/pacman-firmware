all: modules-a modules-e testbenches

modules-a:
	ghdl -a --warn-all ../integration/common.vhd
	ghdl -a --warn-all uart_tx.vhd
	ghdl -a --warn-all uart_rx.vhd
	ghdl -a --warn-all digital_core.vhd
	ghdl -a asic_emu_unit.vhd
modules-e:
	ghdl -e --warn-all uart_tx
	ghdl -e --warn-all uart_rx
	ghdl -e --warn-all digital_core
	ghdl -e asic_emu_unit
testbenches:
	ghdl -a -fsynopsys tb/uart_tx_tb.vhd
	ghdl -e -fsynopsys uart_tx_tb
	ghdl -a -fsynopsys tb/uart_rx_tb.vhd
	ghdl -e -fsynopsys uart_rx_tb
	ghdl -a -fsynopsys tb/digital_core_tb.vhd
	ghdl -e -fsynopsys digital_core_tb
	ghdl -a -fsynopsys tb/asic_emu_unit_tb.vhd
	ghdl -e -fsynopsys asic_emu_unit_tb

run-testbenches: all
	ghdl -r --warn-all -fsynopsys uart_tx_tb --stop-time=750ns
	ghdl -r --warn-all -fsynopsys uart_rx_tb --stop-time=750ns
	ghdl -r --warn-all -fsynopsys asic_emu_unit_tb --stop-time=1500ns

run-unit-testbench: all
	ghdl -r --warn-all -fsynopsys uart_tx_tb --stop-time=750ns
