# Timing diagrams, headless:  the TRM's (pacman_docs/trm/timing_diagrams) and the firmware description's
# (pacman_docs/agents/figs).  Each diagram testbench (tb/) writes a VCD, each script plots its PDFs.  Run
# from ghdl/agents ("make waveforms": builds first).  Copying the PDFs into pacman_docs stays manual.
#
# The first run makes a Python venv here (.venv; needs network once).  matplotlib is pinned to the version
# the TRM PDFs were made with (3.10.3), so the figures match them.  Another Python:  make PYTHON=python3

B      := ../build
PYTHON ?= .venv/bin/python
FIGS   := single_read.pdf single_write.pdf rx_buffer.pdf tx_buffer.pdf
# the firmware description (pacman_docs/agents/firmware.tex):  wave.py, one script and one testbench per unit
DOCS   := global.pdf tx_stream.pdf tx_frames.pdf rx_chan_start.pdf rx_chan_frames.pdf rx_stream.pdf \
          atc_timer.pdf atc_poke.pdf atc_lemo.pdf

all: $(FIGS) $(DOCS)

.venv/bin/python:
	python3 -m venv .venv
	.venv/bin/pip install --quiet vcdvcd matplotlib==3.10.3 numpy

%_diagram_tb.vcd: tb/%_diagram_tb.vhd $(B)/work-obj93.cf
	ghdl -m --workdir=$(B) -fsynopsys $*_diagram_tb > $*_diagram_tb.log
	ghdl -r --workdir=$(B) -fsynopsys $*_diagram_tb --stop-time=$(STOP_$*) --vcd=$@ >> $*_diagram_tb.log
STOP_regbus    := 220ns
STOP_rx_buffer := 1us
STOP_tx_buffer := 700ns
STOP_global    := 200ns
STOP_tx        := 16us
STOP_rx_chan   := 22us
STOP_rx_stream := 600ns
STOP_atc       := 2200ns

single_read.pdf single_write.pdf: %.pdf: %.py timing_diagram.py regbus_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<
rx_buffer.pdf: rx_buffer.py timing_diagram.py rx_buffer_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<
tx_buffer.pdf: tx_buffer.py timing_diagram.py tx_buffer_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<

global.pdf: global.py wave.py global_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<
tx_stream.pdf tx_frames.pdf &: tx.py wave.py tx_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<
rx_chan_start.pdf rx_chan_frames.pdf &: rx_chan.py wave.py rx_chan_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<
rx_stream.pdf: rx_stream.py wave.py rx_stream_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<
atc_timer.pdf atc_poke.pdf atc_lemo.pdf &: atc.py wave.py atc_diagram_tb.vcd $(PYTHON)
	$(PYTHON) $<

clean:
	rm -f *.vcd *.pdf *.log

.PHONY: all clean
