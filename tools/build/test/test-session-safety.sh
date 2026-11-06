#!/bin/bash
# Root test (private mount namespace, tiny chroot): teardown with a LIVE process, signal handling in enter and install, leftover processes,
# mount-failure cleanup, symlink attacks, odd paths, noexec, and the minimal /dev. Run:  sudo tools/build/test/test-session-safety.sh
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/lib.sh"; . "$HERE/mkroot.sh"; V2="${XU_SCRIPT:-$HERE/../xenial-userland.v2.sh}"
[ "$(id -u)" = 0 ] || { echo "needs root (chroot, mount)"; exit 2; }
if [ -z "${XU_IN_NS:-}" ]; then exec env XU_IN_NS=1 unshare -m --propagation private bash "$HERE/$(basename "$0")" "$@"; fi
W=$(mktemp -d /var/tmp/xu-sess.XXXXXX); P="$W/p"; R="$P/xenial-root"; SRC="$W/src"; U=12345; G=12345
cleanup() { pkill -f "sleep 73[0-9][0-9]" 2>/dev/null; sleep 0.3; umount -R "${R:?}/dev" "${R:?}/proc" "${R:?}/src" 2>/dev/null; rm -rf --one-file-system "${W:?}"; }
trap cleanup EXIT
VC=(env -u SUDO_UID -u SUDO_GID bash "$V2"); V() { "${VC[@]}" "$@"; }
mini_root "$P"; mkdir -p "$SRC"; chown $U:$G "$SRC"
ENTER=(enter "$P" --uid $U --gid $G "$SRC")
sess() { start_bg "$W/pid" "$W/log" "${VC[@]}" "${ENTER[@]}" "$@"; wait_for "[ \$(n_mounts) -ge 11 ] && pgrep -f 'sleep 73' >/dev/null" 8; }

echo "## T. teardown with a live process: refuse BEFORE any unmount"
sess /usr/bin/sleep 7301
m0=$(n_mounts); out=$(V teardown "$P" 2>&1); rc=$?
[ "$m0" -ge 11 ] && ok "T0 a session is live with $m0 mounts below the chroot" || bad "T0 mounts=$m0"
[ $rc = 4 ] && ok "T1 teardown refused with exit code 4" || bad "T1 rc=$rc"
[ "$(n_mounts)" = "$m0" ] && ok "T2 NOTHING was unmounted (mount count still $m0)" || bad "T2 mounts now $(n_mounts)"
echo "$out" | grep -q "running inside the chroot" && echo "$out" | grep -q "sleep" && echo "$out" | grep -q "pid" && ok "T3 message names the pid and program inside the chroot" || bad "T3 $out"
echo "$out" | grep -q "leave the shell (type exit" && echo "$out" | grep -q "Jack" && echo "$out" | grep -qi "run teardown again" && ok "T4 message explains how to end the session safely (exit the shell, stop daemons, retry)" || bad "T4 $out"
kill -0 "$BGPID" 2>/dev/null && [ "$(procs_in_root)" -ge 1 ] && ok "T5 the session and its process are still running" || bad "T5"
out=$(V "${ENTER[@]}" /usr/bin/id 2>&1); [ $? != 0 ] && echo "$out" | grep -q "another xenial-userland.sh instance is running" && ok "T5b a second enter while the first is live is refused by the lock (nothing mounted twice)" || bad "T5b $out"
[ "$(n_mounts)" = "$m0" ] && ok "T5c and the live session's mounts are untouched by it" || bad "T5c mounts $(n_mounts) vs $m0"
pkill -f "sleep 7301"; wait "$BGPID"
wait_for "[ \$(n_mounts) = 0 ]" 8 && ok "T6 when the session command ends, enter unmounts by itself" || bad "T6 mounts=$(n_mounts)"
V teardown "$P" >/dev/null 2>&1 && ok "T7 teardown now succeeds" || bad "T7"
# a host process whose current directory is inside the chroot (no mounts at all)
( cd "$R/tmp" && exec sleep 7302 ) & CW=$!; sleep 0.3
out=$(V teardown "$P" 2>&1); rc=$?
[ $rc = 4 ] && echo "$out" | grep -q "current directory is inside" && ok "T8 a host process sitting in a chroot directory also blocks teardown (exit 4, explained)" || bad "T8 rc=$rc $out"
kill $CW; wait $CW 2>/dev/null; V teardown "$P" >/dev/null 2>&1 && ok "T9 teardown succeeds after it leaves" || bad "T9"
out=$(V teardown "$W/does-not-exist" 2>&1); [ $? = 0 ] && echo "$out" | grep -q "nothing to tear down" && ok "T10 teardown on a missing userland: harmless" || bad "T10 $out"

echo "## S. signals during enter (interactive session)"
for sig in TERM:143 HUP:129 QUIT:131; do
  name=${sig%%:*}; want=${sig##*:}
  sess /usr/bin/sleep 7303
  kill -"$name" "$BGPID"; t0=$SECONDS; wait "$BGPID"; rc=$?
  [ $rc = $want ] && [ "$(n_mounts)" = 0 ] && [ "$(procs_in_root)" = 0 ] && [ $((SECONDS-t0)) -le 12 ] && ok "S1 $name: exit $rc, session process stopped, ALL mounts removed, nothing left in the chroot" || bad "S1 $name: rc=$rc mounts=$(n_mounts) procs=$(procs_in_root)"
done
sess /usr/bin/sleep 7304
kill -INT -- "-$BGPID"; wait "$BGPID"; rc=$?
[ $rc = 130 ] && [ "$(n_mounts)" = 0 ] && [ "$(procs_in_root)" = 0 ] && ok "S2 Ctrl-C (INT to the whole process group, like a terminal): the program inside gets it, enter unmounts and exits 130" || bad "S2 rc=$rc mounts=$(n_mounts)"
sess /usr/bin/sleep 7305
kill -INT "$BGPID"; sleep 1.5
kill -0 "$BGPID" 2>/dev/null && [ "$(n_mounts)" -ge 8 ] && ok "S3 INT sent only to the script (not via a terminal) is ignored by an interactive session: it keeps running, mounts intact" || bad "S3"
kill -TERM "$BGPID"; wait "$BGPID"; [ "$(n_mounts)" = 0 ] && ok "S4 and a following TERM still cleans up completely" || bad "S4"
sess /usr/bin/bash -c 'trap "" TERM HUP; while true; do /usr/bin/sleep 0.2; done'
wait_for "[ \$(n_mounts) -ge 8 ]" 8
kill -TERM "$BGPID"; t0=$SECONDS; wait "$BGPID"; rc=$?
[ $rc = 143 ] && [ "$(n_mounts)" = 0 ] && [ "$(procs_in_root)" = 0 ] && ok "S5 a program that IGNORES TERM is killed after the grace period; mounts removed ($((SECONDS-t0))s)" || bad "S5 rc=$rc mounts=$(n_mounts) procs=$(procs_in_root)"

echo "## L. programs left running after the session shell exits"
out=$(V "${ENTER[@]}" /usr/bin/bash -c '/usr/bin/sleep 7306 >/dev/null 2>&1 & exit 0' 2>&1); rc=$?
m=$(n_mounts)
[ $rc = 3 ] && ok "L1 exit code 3: the session ended but a program is still running inside" || bad "L1 rc=$rc $out"
[ "$m" -ge 8 ] && ok "L2 mounts were KEPT (no partial unmount while the program runs): $m" || bad "L2 mounts=$m"
echo "$out" | grep -q "pid" && echo "$out" | grep -q "sleep" && ok "L3 the leftover program is reported by pid and name" || bad "L3 $out"
V teardown "$P" >/dev/null 2>&1; [ $? = 4 ] && [ "$(n_mounts)" = "$m" ] && ok "L4 teardown refuses while it runs, unmounting nothing" || bad "L4"
V "${ENTER[@]}" /usr/bin/id >/dev/null 2>&1 && bad "L5 a new session must not start over leftovers" || ok "L5 a new enter refuses while mounts/processes remain"
pkill -f "sleep 7306"; sleep 0.5; V teardown "$P" >/dev/null 2>&1 && [ "$(n_mounts)" = 0 ] && ok "L6 after the program is stopped, teardown unmounts everything" || bad "L6 mounts=$(n_mounts)"
out=$(V enter "$P" --uid $U --gid $G --kill-leftovers "$SRC" /usr/bin/bash -c '/usr/bin/sleep 7307 >/dev/null 2>&1 & exit 0' 2>&1); rc=$?
[ $rc = 0 ] && [ "$(n_mounts)" = 0 ] && ! pgrep -f "sleep 7307" >/dev/null && ok "L7 --kill-leftovers: the leftover is stopped, mounts removed, exit 0" || bad "L7 rc=$rc mounts=$(n_mounts) $out"
V "${ENTER[@]}" /usr/bin/bash -c 'exit 7' >/dev/null 2>&1; [ $? = 7 ] && [ "$(n_mounts)" = 0 ] && ok "L8 the command's own exit status (7) is passed through; mounts removed" || bad "L8"

echo "## M. failure while mounting"
mkdir "$W/wrap"; REALMOUNT=$(type -P mount)
printf '#!/bin/bash\nn=$(cat %s/cnt 2>/dev/null || echo 0); n=$((n+1)); echo $n > %s/cnt\nif [ "$n" = "$FAILAT" ]; then echo "mount: simulated failure" >&2; exit 32; fi\nexec %s "$@"\n' "$W/wrap" "$W/wrap" "$REALMOUNT" > "$W/wrap/mount"; chmod +x "$W/wrap/mount"
for at in 2 5 11; do
  rm -f "${W:?}/wrap/cnt"; out=$(PATH="$W/wrap:$PATH" FAILAT=$at V "${ENTER[@]}" /usr/bin/id 2>&1); rc=$?
  [ $rc != 0 ] && [ "$(n_mounts)" = 0 ] && ok "M1 mount call #$at fails: script stops (rc=$rc) and every mount made so far is removed" || bad "M1 #$at rc=$rc mounts=$(n_mounts) $out"
done

echo "## Y. symlink attacks against the userland tree"
mkdir "$W/decoy"; echo keep > "$W/decoy/file"; chown 4242:4242 "$W/decoy" "$W/decoy/file"; snapd() { (cd "$W/decoy" && find . -printf '%p %u:%g %m %s\n' | sort | md5sum); }
d0=$(snapd)
mv "$R/dev" "$R/dev.real"; ln -s "$W/decoy" "$R/dev"
V "${ENTER[@]}" /usr/bin/id >/dev/null 2>&1 && bad "Y1 symlinked dev/ must be refused" || ok "Y1 dev/ replaced by a symlink: enter refuses"
unlink "$R/dev"; mv "$R/dev.real" "$R/dev"
[ "$(snapd)" = "$d0" ] && [ "$(n_mounts)" = 0 ] && ok "Y2 the decoy directory was not touched, nothing mounted" || bad "Y2"
mv "$R/etc/passwd" "$R/etc/passwd.real"; echo "decoy-line" > "$W/decoy/pw"; ln -s "$W/decoy/pw" "$R/etc/passwd"
V "${ENTER[@]}" /usr/bin/id >/dev/null 2>&1 && bad "Y3 symlinked etc/passwd must be refused" || ok "Y3 etc/passwd is a symlink: enter refuses (ensure_builder_user)"
[ "$(cat "$W/decoy/pw")" = "decoy-line" ] && ok "Y4 the file it pointed to was not appended to" || bad "Y4 $(cat "$W/decoy/pw")"
unlink "$R/etc/passwd"; mv "$R/etc/passwd.real" "$R/etc/passwd"
rmdir "$R/home/builder" 2>/dev/null; ln -s "$W/decoy" "$R/home/builder"
V "${ENTER[@]}" /usr/bin/id >/dev/null 2>&1 && bad "Y5 symlinked home/builder must be refused" || ok "Y5 home/builder is a symlink: enter refuses"
[ "$(stat -c %u "$W/decoy")" = 4242 ] && ok "Y6 the decoy keeps its owner (the script did not chown through the link)" || bad "Y6 owner now $(stat -c %u "$W/decoy")"
unlink "$R/home/builder"
mv "$R" "$W/real-root"; ln -s "$W/real-root" "$R"
V "${ENTER[@]}" /usr/bin/id >/dev/null 2>&1 && bad "Y7 xenial-root as a symlink must be refused" || ok "Y7 xenial-root itself a symlink: refused"
unlink "$R"; mv "$W/real-root" "$R"
# install: symlinks at the files it writes as root
printf '#!/bin/bash\nexit 100\n' > "$R/usr/bin/apt-get"; chmod +x "$R/usr/bin/apt-get"
for f in etc/resolv.conf etc/apt/sources.list usr/sbin/policy-rc.d; do
  echo keep > "$W/decoy/t"; chown 4242:4242 "$W/decoy/t"; rm -f "${R:?}/$f"; ln -s "$W/decoy/t" "$R/$f"
  V install "$P" >/dev/null 2>&1
  [ "$(cat "$W/decoy/t")" = keep ] && [ ! -L "$R/$f" ] && [ -f "$R/$f" ] && ok "Y8 install replaced the symlink at /$f with a regular file and did not write through it" || bad "Y8 /$f decoy=[$(cat "$W/decoy/t")] link=$([ -L "$R/$f" ] && echo yes)"
  umount -R "${R:?}/dev" "${R:?}/proc" 2>/dev/null
done
[ "$(n_mounts)" = 0 ] && ok "Y9 no mounts left after the install attempts" || bad "Y9 mounts left: $(n_mounts)"

echo "## W. odd paths, noexec"
WP="$W/with space"; mini_root "$WP"; SS="$W/src dir"; mkdir "$SS"; chown $U:$G "$SS"; R2="$WP/xenial-root"
out=$(V enter "$WP" --uid $U --gid $G "$SS" /usr/bin/bash -c 'touch "/src/x y"; id -u' 2>&1); rc=$?
[ $rc = 0 ] && [ -e "$SS/x y" ] && ok "W1 spaces in ROOT_PARENT and SRC work (mounts escaped correctly)" || bad "W1 rc=$rc $out"
[ "$(grep -c 'with\\040space' /proc/mounts)" = 0 ] && ok "W2 no mounts left below the path with spaces" || bad "W2"
out=$(V enter "$P" --uid $U --gid $G "$W/src"$'\t'"x" /usr/bin/id 2>&1); [ $? != 0 ] && echo "$out" | grep -q "control character" && ok "W3 a tab in the path is refused" || bad "W3 $out"
out=$(V enter "$P" --uid $U --gid $G 'a\b' /usr/bin/id 2>&1); [ $? != 0 ] && echo "$out" | grep -q "backslash" && ok "W4 a backslash in the path is refused" || bad "W4 $out"
mkdir "$W/nx"; mount -t tmpfs -o noexec tmpfs "$W/nx"; mini_root "$W/nx"
out=$(V enter "$W/nx" --uid $U --gid $G /usr/bin/id 2>&1); [ $? != 0 ] && echo "$out" | grep -q noexec && ok "W5 a noexec filesystem for the userland is refused" || bad "W5 $out"
umount "$W/nx"

echo "## D. install: interruption must not continue, and must unmount"
printf '#!/bin/bash\n: > /tmp/apt-started\nexec sleep 7308\n' > "$R/usr/bin/apt-get"; chmod +x "$R/usr/bin/apt-get"
rm -f "${P:?}/xenial-userland-installed.list"
for sig in TERM:143 HUP:129 QUIT:131 INT:130; do
  name=${sig%%:*}; want=${sig##*:}
  start_bg "$W/pid" "$W/log" "${VC[@]}" install "$P"; wait_for "pgrep -f 'sleep 7308' >/dev/null" 8
  [ "$name" = INT ] && kill -INT -- "-$BGPID" || kill -"$name" "$BGPID"
  t0=$SECONDS; wait "$BGPID"; rc=$?
  [ $rc = $want ] && [ "$(n_mounts)" = 0 ] && [ "$(procs_in_root)" = 0 ] && [ ! -e "$P/xenial-userland-installed.list" ] && ok "D1 $name during apt: exit $rc (not 1), apt stopped, the NEXT install steps did not run, all mounts removed ($((SECONDS-t0))s)" || bad "D1 $name: rc=$rc (want $want) mounts=$(n_mounts) procs=$(procs_in_root)"
done
printf '#!/bin/bash\nexit 100\n' > "$R/usr/bin/apt-get"
out=$(V install "$P" 2>&1); rc=$?; [ $rc != 0 ] && [ "$(n_mounts)" = 0 ] && echo "$out" | grep -q "apt step failed" && ok "D2 apt failing (exit 100): install stops with a clear message and unmounts" || bad "D2 rc=$rc mounts=$(n_mounts) $out"

echo "## C. contrast with the ORIGINAL script (read-only use)"
ORIG="$HERE/../xenial-userland.sh"
( cd "$W" && bash "$ORIG" enter p "$SRC" /usr/bin/sleep 7309 >/dev/null 2>&1 ) & sleep 1.5
ot=$(cd "$W" && bash "$ORIG" teardown p 2>&1); live=$(n_mounts)
pkill -f "sleep 7309"; sleep 0.7; wait 2>/dev/null
echo "$ot" | grep -q "no mounts remain" && [ "$live" -ge 1 ] && ok "C1 ORIGINAL: with a relative ROOT_PARENT its teardown said 'no mounts remain' while $live mounts were live and printed an rm -rf" || echo "[INFO] C1 original output: $ot (live=$live)"
finish
