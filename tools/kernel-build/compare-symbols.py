#!/usr/bin/env python3
"""Compare two kernel symbol tables produced by `kallsyms-finder` (PyPI: vmlinux-to-elf).

Usage: python3 -I compare-symbols.py REFERENCE.syms CANDIDATE.syms
Each input line is "<hex address> <type> <name>".  Sizes are estimated the same way for
both files (distance to the next symbol at a higher address), so the comparison is like for like.
Read-only: it never executes any kernel image.
"""
import collections, sys

def load(path):
    rows = []
    for line in open(path):
        p = line.split()
        if len(p) >= 3:
            rows.append((int(p[0], 16), p[1], p[2]))
    return rows

def sizes(rows):
    rows = sorted(rows)
    out = {}
    for i, (addr, _t, name) in enumerate(rows[:-1]):
        j = i + 1
        while j < len(rows) and rows[j][0] == addr:
            j += 1
        if j < len(rows):
            out.setdefault(name, []).append(rows[j][0] - addr)
    return out

ref, cand = load(sys.argv[1]), load(sys.argv[2])
n_ref = collections.Counter(n for _a, _t, n in ref)
n_cand = collections.Counter(n for _a, _t, n in cand)
common = set(n_ref) & set(n_cand)
print(f"symbols: reference {len(ref)}, candidate {len(cand)}; distinct names {len(n_ref)} / {len(n_cand)}; common {len(common)}")
print("only in reference:", sorted(set(n_ref) - set(n_cand)))
print("only in candidate:", sorted(set(n_cand) - set(n_ref)))
s_ref, s_cand = sizes(ref), sizes(cand)
equal, different = 0, []
for name in common:
    if len(s_ref.get(name, [])) == 1 and len(s_cand.get(name, [])) == 1:
        if s_ref[name][0] == s_cand[name][0]:
            equal += 1
        else:
            different.append((name, s_ref[name][0], s_cand[name][0]))
total = equal + len(different)
print(f"comparable single-instance symbols: {total}; equal size: {equal} ({100 * equal / total:.3f}%); different: {len(different)}")
for item in sorted(different, key=lambda x: -abs(x[1] - x[2])):
    print("  size differs:", item)
a_ref = {n: a for a, _t, n in ref if n_ref[n] == 1}
a_cand = {n: a for a, _t, n in cand if n_cand[n] == 1}
both = [n for n in a_ref if n in a_cand]
same = sum(1 for n in both if a_ref[n] == a_cand[n])
print(f"unique-name symbols at identical address: {same} of {len(both)} ({100 * same / len(both):.2f}%)")
