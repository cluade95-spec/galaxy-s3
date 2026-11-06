#!/bin/bash
# Offline tests of `fetch` (no root needed, no network): the real cmd_fetch runs with a fake `download` serving local files.
# Needs a tarball to serve: the real ubuntu-base tarball if present (XU_REAL_TARBALL=... or the Phase 7 scratch copy), else a stand-in file
# (then the 'accepts the genuine tarball' test is skipped; every refusal test still runs).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/lib.sh"; . "$HERE/mkroot.sh"
W=$(mktemp -d /var/tmp/xu-fetch.XXXXXX); trap 'rm -rf "$W"' EXIT
if TB=$(real_tarball); then HAVE_REAL=1; else HAVE_REAL=""; TB="$W/standin.tgz"; echo standin > "$TB"; echo "[INFO] real tarball not found: genuine-tarball test skipped"; fi
run() { MODE="$1" PARENT="$2" TB="$TB" bash "$HERE/fetch-driver.sh"; }
nothing_kept() { [ -z "$(ls -A "$1" 2>/dev/null | grep -v '^\.xenial-userland\.lock$')" ]; }

if [ -n "$HAVE_REAL" ]; then
  out=$(run ok "$W/p1" 2>&1); rc=$?
  [ $rc = 0 ] && echo "$out" | grep -q "is authentic" && ok "F1 genuine tarball + signed list accepted ($out)" || bad "F1 rc=$rc $out"
  [ -f "$W/p1/SHA256SUMS" ] && [ -f "$W/p1/SHA256SUMS.gpg" ] && [ -f "$W/p1/ubuntu-base-16.04.6-base-amd64.tar.gz" ] && ok "F2 the three files were kept" || bad "F2 files: $(ls -A $W/p1)"
  [ "$(stat -c %a "$W/p1/ubuntu-base-16.04.6-base-amd64.tar.gz")" = 444 ] && ok "F3 kept files are read-only (mode 444)" || bad "F3"
  [ -z "$(ls -A "$W/p1" | grep '^\.fetch')" ] && ok "F4 no temporary download directory left behind" || bad "F4"
fi
for m in badtar badsums badsig fail; do
  out=$(run $m "$W/p_$m" 2>&1); rc=$?
  [ $rc != 0 ] && nothing_kept "$W/p_$m" && ok "F5 $m: refused (rc=$rc) and NOTHING kept ($(echo "$out" | tail -1 | cut -c1-90))" || bad "F5 $m: rc=$rc kept: $(ls -A "$W/p_$m")"
done
out=$(MODE=ok PARENT=/mnt/c/xu-fetch-test TB="$TB" bash "$HERE/fetch-driver.sh" 2>&1); rc=$?
[ $rc != 0 ] && [ ! -e /mnt/c/xu-fetch-test ] && echo "$out" | grep -q "Windows drive" && ok "F6 a /mnt/c target is refused before anything is created" || bad "F6 rc=$rc $out"
for sig in TERM:143 HUP:129 QUIT:131 INT:130; do
  name=${sig%%:*}; want=${sig##*:}; P="$W/p_sig_$name"
  MODE=sleep PARENT="$P" TB="$TB" start_bg "$W/pid" "$W/log" bash "$HERE/fetch-driver.sh"
  wait_for "pgrep -f 'sleep 7321' >/dev/null" 5
  [ "$name" = INT ] && kill -INT -- "-$BGPID" || kill -"$name" "$BGPID"
  t0=$SECONDS; wait "$BGPID"; rc=$?
  gone=1; pgrep -f "sleep 7321" >/dev/null && gone=0
  [ $rc = $want ] && [ $gone = 1 ] && [ $((SECONDS - t0)) -le 5 ] && nothing_kept "$P" && ok "F7 $name during the download: exit $rc, curl-stand-in stopped, temp dir removed, nothing kept" || bad "F7 $name: rc=$rc (want $want) sleep-gone=$gone kept=$(ls -A "$P")"
  pkill -f "sleep 7321" 2>/dev/null; true
done
finish
