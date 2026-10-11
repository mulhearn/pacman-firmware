#! /bin/bash
#
# check_sync.sh: report differences between vivado/src/hdl and ghdl directory tree.
#

cd "$(dirname "$0")/.."
declare -A src
for f in ghdl/*/*.vhd; do src["vivado/src/hdl/$(basename "$f")"]=$f; done
while IFS= read -r f; do src["vivado/src/hdl/${f#ghdl/hardware/}"]=$f; done < <(find ghdl/hardware -type f | sort)
for f in ghdl/asic_emu/stub/*.vhd; do src["vivado/src/hdl/$(basename "$f")"]=$f; done

differ=()
for dst in "${!src[@]}"; do
    cmp -s "${src[$dst]}" "$dst" || differ+=("${dst#vivado/src/hdl/}")
done
IFS=$'\n' differ=($(sort <<< "${differ[*]}")); unset IFS

{
if [ ${#differ[@]} -eq 0 ]; then
    echo "SYNC CHECK: OK, vivado/src/hdl matches ghdl/ (${#src[@]} files)"
else
    echo "SYNC CHECK: WARNING, vivado/src/hdl differs from ghdl/ in ${#differ[@]} of ${#src[@]} files" \
         "(this build is not what ghdl/ simulates; utils/sync_ghdl.sh syncs):"
    printf '    %s\n' "${differ[@]}"
fi
} | tee reports/sync_check.txt
exit 0
