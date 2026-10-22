# ghdl/agents:  augie's validation and waveform generation for the PACMAN firmware (README.txt).
#
#   make check        run every check/*_check.vhd:  one PASS/FAIL line each, a summary, non-zero exit on failure;
#                     then one line per requirement (docs/requirements.txt, report.py)
#   make check T=rx   only the checks whose name starts with rx
#   make waveforms    the TRM timing diagrams as PDFs, no window (waveforms/)
#   make clean
#
# Everything builds in build/ from the RTL as it is in ghdl/ (all units, hw1v5); GHDL works out the order.

B    := build
RTL  := $(wildcard ../*/*.vhd ../hardware/hw1v5/*.vhd ../asic_emu/stub/*.vhd ../integration/gen/*.vhd)
TB   := lib/tb_pkg.vhd $(wildcard check/*.vhd waveforms/tb/*.vhd)

check: import
	./run_checks.sh $(T)

waveforms: import
	$(MAKE) -C waveforms

import:
	@mkdir -p $(B)
	@rm -f $(B)/work-obj93.cf
	ghdl -i --workdir=$(B) -fsynopsys $(RTL) $(TB)

clean:
	rm -rf $(B)
	$(MAKE) -C waveforms clean

.PHONY: check waveforms import clean
