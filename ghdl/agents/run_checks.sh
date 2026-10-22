#!/bin/bash
# Run the checks (check/*_check.vhd, after "make import"):  one line per check, a summary, then the results per
# requirement (report.py, docs/requirements.txt);  exit status non-zero if any check failed.  Logs:  build/<check>.log.
#   ./run_checks.sh          all checks
#   ./run_checks.sh rx tx    checks whose name starts with rx or tx
cd "$(dirname "$0")"
B=build
pass=0; fail=0; logs=()
for f in check/*_check.vhd; do
    tb=$(basename "$f" .vhd)
    if [ $# -gt 0 ]; then
        match=0; for p in "$@"; do [[ $tb == $p* ]] && match=1; done
        [ $match = 1 ] || continue
    fi
    log=$B/$tb.log
    logs+=("$log")
    if ! ghdl -m --workdir=$B -fsynopsys "$tb" > "$log" 2>&1; then
        echo "FAIL $tb (build)  [$log]"; fail=$((fail + 1)); continue
    fi
    ghdl -r --workdir=$B -fsynopsys "$tb" --stop-time=100ms >> "$log" 2>&1
    status=$?
    result=$(grep -E '^(PASS|FAIL) ' "$log" | tail -1)
    if [ $status -eq 0 ] && [[ $result == PASS* ]]; then
        echo "$result"; pass=$((pass + 1))
    else
        [ -z "$result" ] && result="FAIL $tb (no result line, exit $status)"
        echo "$result  [$log]"; fail=$((fail + 1))
    fi
done
echo "---- $pass passed, $fail failed"
[ $# -gt 0 ] && echo "(results per requirement for the checks run only)"
python3 report.py "${logs[@]}"
[ $fail -eq 0 ]
