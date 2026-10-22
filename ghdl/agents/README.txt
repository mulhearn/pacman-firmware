ghdl/agents:  augie's validation and waveform generation for the PACMAN firmware
=============================================================================

Written and maintained by augie (AI agent); not reviewed line by line.  The human-read code is elsewhere in
ghdl/:  the RTL in ghdl/<unit>/ and the viewing testbenches in ghdl/<unit>/tb/ (illustration only).

  make check         every check/*_check.vhd:  one PASS/FAIL line each, a summary, non-zero exit on failure;
                     then the results per requirement (docs/requirements.txt):  one line per level-2 requirement,
                     NONE for a requirement without checks
  make check T=rx    only the checks whose name starts with rx
  make waveforms     the timing diagrams as PDFs, headless (waveforms/; copy to pacman_docs by hand):  the
                     TRM's, and the firmware description's (pacman_docs/agents/firmware.tex)
  make clean

Requirements
  docs/requirements.txt (at the top of pacman-firmware;  human-reviewed):  what each unit promises (level 1) and
  testable statements (level 2, each marked sim or sim+hw:  also checked on the board by pacman_fwcheck).  The
  checks here are level 3:  a check counts toward the requirement named by the last req("RX-1.2") before it;
  report.py merges the tallies of the logs.

Layout
  check/       unit checks, black box at each unit's ports (registers over the regbus, UART/AXI stream in and
               out):  self-checking, silent unless something fails
  waveforms/   diagram testbenches (tb/), VCD -> PDF scripts (matplotlib pinned to the TRM's):  one per TRM
               figure;  for the firmware description, one testbench and one script per unit, drawn by wave.py
  lib/         tb_pkg.vhd:  check, check_equal, finish, formatting
  build/       everything compiled here (ignored); all RTL from ghdl/ (hw1v5), order worked out by GHDL

No .vhd directly in this directory:  utils/sync_ghdl.sh copies ghdl/*/*.vhd into the Vivado sources.
