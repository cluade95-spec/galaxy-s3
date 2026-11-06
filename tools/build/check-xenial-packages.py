#!/usr/bin/env python3
"""Check the package names in xenial-userland.v2.sh against Ubuntu 16.04 package indexes.
  check-xenial-packages.py live  OUT.tsv    download the xenial/-updates/-security main+universe amd64 indexes over HTTPS (about 17 MB,
                                            no root, nothing installed) and write the resolved versions to OUT.tsv
  check-xenial-packages.py check IN.tsv     offline: every name the script installs must be a real package in IN.tsv (no virtual names)
The script's package sets are read with `xenial-userland.v2.sh list-packages`."""
import gzip, io, re, subprocess, sys, urllib.request, os
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "xenial-userland.v2.sh")
# names from the documents that are NOT installed (renamed, absent or conditional): their Xenial status is recorded for the audit
EXTRA_NAMES = {"lib32readline-dev", "lib32readline-gplv2-dev", "lib32z-dev", "git-core", "erofs-utils", "git-lfs", "python3-protobuf", "lz4", "xxd",
               "yasm", "maven", "libwxgtk2.8-dev", "openjdk-7-jdk", "python-is-python2", "libxml2-16", "libtinfo5", "lib32ncurses5-dev"}
def script_pkgs():
    return subprocess.check_output(["bash", SCRIPT, "list-packages", "all"], text=True).split()
def live(out):
    idx = {}; prov = {}
    for suite in ("xenial", "xenial-updates", "xenial-security"):
        for comp in ("main", "universe"):
            u = f"https://archive.ubuntu.com/ubuntu/dists/{suite}/{comp}/binary-amd64/Packages.gz"
            data = gzip.decompress(urllib.request.urlopen(u, timeout=120).read()).decode("utf-8", "replace")
            for blk in data.split("\n\n"):
                m = re.search(r"^Package: (.+)$", blk, re.M)
                if not m: continue
                v = re.search(r"^Version: (.+)$", blk, re.M).group(1)
                a = re.search(r"^Architecture: (.+)$", blk, re.M).group(1)
                idx[m.group(1)] = (v, f"{suite}/{comp}", a)
                p = re.search(r"^Provides: (.+)$", blk, re.M)
                if p:
                    for x in p.group(1).split(","): prov.setdefault(x.strip().split(" ")[0], set()).add(m.group(1))
    with open(out, "w") as f:
        f.write("package\tversion\tindex\tarch\tnote\n")
        for n in sorted(set(script_pkgs()) | EXTRA_NAMES):
            if n in idx: f.write(f"{n}\t{idx[n][0]}\t{idx[n][1]}\t{idx[n][2]}\treal\n")
            elif n in prov: f.write(f"{n}\t-\t-\t-\tvirtual (provided by {','.join(sorted(prov[n]))})\n")
            else: f.write(f"{n}\t-\t-\t-\tMISSING\n")
def check(inp):
    rows = [l.rstrip("\n").split("\t") for l in open(inp)][1:]
    d = {r[0]: r for r in rows}; bad = 0
    for n in script_pkgs():
        r = d.get(n)
        if not r: print("NOT IN TSV:", n); bad += 1
        elif r[4] != "real": print("NOT A REAL PACKAGE:", n, r[4]); bad += 1
    print("checked", len(script_pkgs()), "names;", "FAIL" if bad else "all real xenial amd64 packages"); return bad
if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "live": live(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "check": sys.exit(1 if check(sys.argv[2]) else 0)
    else: print(__doc__); sys.exit(2)
