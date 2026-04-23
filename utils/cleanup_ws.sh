#! /bin/bash
find ghdl vivado/src vivado/ip_repo -type f -name '*.vhd' | xargs -n1 sed --in-place 's/[[:space:]]\+$//'
find vivado/tcl -type f -name '*.tcl' | xargs -n1 sed --in-place 's/[[:space:]]\+$//'
find docs -type f -name '*.txt' | xargs -n1 sed --in-place 's/[[:space:]]\+$//'
