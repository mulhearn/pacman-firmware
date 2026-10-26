#! /bin/bash
find ghdl vivado/src vivado/ip_repo -type f -name '*.vhd' | xargs -n1 sed --in-place 's/[[:space:]]\+$//'
find vivado/tcl -type f -name '*.tcl' | xargs -n1 sed --in-place 's/[[:space:]]\+$//'
find docs -type f -name '*.txt' | xargs -n1 sed --in-place 's/[[:space:]]\+$//'

# VHDL indentation as Emacs (vhdl-mode, .dir-locals.el) does it, tabs to spaces;  ghdl and its copies in
# vivado/src/hdl only (not the vendor files in vivado/ip_repo).
find ghdl vivado/src/hdl -type f -name '*.vhd' | xargs emacs -Q --batch -l utils/vhdl_indent.el 2>/dev/null
