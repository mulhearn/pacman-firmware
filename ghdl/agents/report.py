#!/usr/bin/env python3
"""report.py LOG...:  the checks' results per requirement (docs/requirements.txt), from the "REQ <id> <checks> <failures>"
lines of the check logs.  One line per level-2 requirement, under its level-1 heading;  flags requirements with no
checks, IDs not in requirements.txt, and checks made before any req().  Exit status non-zero on any failure or flag."""
import re
import sys
import textwrap
from pathlib import Path

HERE = Path(__file__).resolve().parent
WIDTH = 116


def requirements():
    """[(id, level, where, text)] in file order;  a level-2 text may continue on indented lines"""
    out = []
    for line in (HERE / "../../docs/requirements.txt").read_text().splitlines():
        m = re.match(r"^([A-Z]+(?:-\d+(?:\.\d+)?)?)\s+(sim\+hw|sim)?\s*(.*)$", line)
        if m and ((m.group(1).isalpha() and len(m.group(1)) <= 4) or "-" in m.group(1)) and m.group(3):
            rid, where, text = m.groups()
            level = 0 if rid.isalpha() else (1 if "." not in rid else 2)
            out.append([rid, level, where or "", text.strip()])
        elif out and line.startswith(" " * 17) and line.strip():
            out[-1][3] += " " + line.strip()
    return out


def tallies(logs):
    t = {}
    for log in logs:
        for line in Path(log).read_text(errors="replace").splitlines():
            m = re.match(r"^REQ (\S+)\s+(\d+) (\d+)$", line)
            if m:
                c, f = t.get(m.group(1), (0, 0))
                t[m.group(1)] = (c + int(m.group(2)), f + int(m.group(3)))
    return t


def main(logs):
    reqs = requirements()
    t = tallies(logs)
    known = {r[0] for r in reqs}
    bad = 0
    for rid, level, where, text in reqs:
        if level == 0:
            print("\n%s  %s" % (rid, text))
        elif level == 1:
            print(textwrap.fill(text, WIDTH, initial_indent="  %-8s " % rid, subsequent_indent=" " * 11))
        else:
            c, f = t.get(rid, (0, 0))
            state = "FAIL" if f else ("PASS" if c else "NONE")
            bad += state != "PASS"
            head = "    %s %-8s %5d  %-6s  " % (state, rid, c, where)
            print(textwrap.fill(text, WIDTH, initial_indent=head, subsequent_indent=" " * len(head)))
    extra = sorted(set(t) - known)
    if extra:
        print()
        for rid in extra:
            c, f = t[rid]
            print("    %s %-8s %5d  %s" % ("FAIL" if f else "????", rid,  c,
                                          "checks made before any req()" if rid == "(none)" else "not in requirements.txt"))
            bad += 1
    n2 = sum(1 for r in reqs if r[1] == 2)
    covered = sum(1 for r in reqs if r[1] == 2 and t.get(r[0], (0, 0))[0])
    print("\n---- %d requirements, %d with checks, %d checks in all, %d to look at" %
          (n2, covered, sum(c for c, f in t.values()), bad))
    return bad == 0


if __name__ == "__main__":
    sys.exit(0 if main(sys.argv[1:]) else 1)
