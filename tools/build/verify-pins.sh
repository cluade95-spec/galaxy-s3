#!/bin/bash
# Verify that every revision pinned in local_manifest.xml exists upstream, and print its tree/commit identity.
# Read-only: fetches single commits into a throwaway repository under the given scratch directory.
# Usage: verify-pins.sh <local_manifest.xml> <scratch dir>
set -u
MAN="$1"; WORK="$2"; mkdir -p "$WORK"
python3 - "$MAN" <<'PY' > "$WORK/pins.tsv"
import sys,xml.etree.ElementTree as ET
r=ET.parse(sys.argv[1]).getroot()
rem={x.get('name'):x.get('fetch') for x in r.findall('remote')}
for p in r.findall('project'):
    print('\t'.join([p.get('path'),rem[p.get('remote')].rstrip('/')+'/'+p.get('name'),p.get('revision')]))
PY
rc=0
while IFS=$'\t' read -r path url rev; do
  d="$WORK/$(echo "$path" | tr / _)"; rm -rf "$d"; git init -q "$d"
  if git -C "$d" fetch -q --depth 1 "$url" "$rev" 2>"$d.err"; then
    echo "OK    $path  $rev  tree=$(git -C "$d" rev-parse FETCH_HEAD^{tree})  date=$(git -C "$d" log -1 --format=%cs FETCH_HEAD)  $url"
  else
    echo "FAIL  $path  $rev  $url  ($(head -c 200 "$d.err" | tr '\n' ' '))"; rc=1
  fi
done < "$WORK/pins.tsv"
exit $rc
