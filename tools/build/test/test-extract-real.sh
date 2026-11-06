#!/bin/bash
# Root test (private mount namespace): `extract`, then `enter`/`teardown` on the REAL ubuntu-base 16.04.6 userland. Needs the real tarball
# (XU_REAL_TARBALL=/path, or the Phase 7 scratch copy). No download, no apt: only what the base image itself contains.
# Run:  sudo tools/build/test/test-extract-real.sh
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/lib.sh"; . "$HERE/mkroot.sh"; V2="${XU_SCRIPT:-$HERE/../xenial-userland.v2.sh}"
[ "$(id -u)" = 0 ] || { echo "needs root (chroot, mount)"; exit 2; }
if [ -z "${XU_IN_NS:-}" ]; then exec env XU_IN_NS=1 unshare -m --propagation private bash "$HERE/$(basename "$0")" "$@"; fi
TB=$(real_tarball) || { echo "[SKIP] real tarball not available (set XU_REAL_TARBALL)"; exit 0; }
W=$(mktemp -d /var/tmp/xu-real.XXXXXX); P="$W/p"; R="$P/xenial-root"; SRC="$W/src"; U=12345; G=12345
trap 'umount -R "$R/dev" "$R/proc" "$R/src" 2>/dev/null; rm -rf --one-file-system "$W"' EXIT
V() { env -u SUDO_UID -u SUDO_GID bash "$V2" "$@"; }
mkdir -p "$P" "$SRC"; chown $U:$G "$SRC"
cp "$TB" "$HERE/fixtures/SHA256SUMS" "$HERE/fixtures/SHA256SUMS.gpg" "$P/"

echo "## E. extract"
out=$(V extract "$P" 2>&1); rc=$?
[ $rc = 0 ] && [ -x "$R/bin/bash" ] && ok "E1 extract of the real tarball succeeded" || bad "E1 rc=$rc $out"
[ -z "$(find "$R" -xdev \( -type b -o -type c \) 2>/dev/null)" ] && ok "E2 NO device nodes were created on disk (the tarball has 79; all skipped)" || bad "E2 $(find "$R" -xdev \( -type b -o -type c \) | head -3)"
[ -d "$R/dev" ] && [ -z "$(ls -A "$R/dev")" ] && ok "E3 dev/ exists and is empty" || bad "E3"
[ "$(stat -c %u:%a "$R")" = "0:755" ] && [ "$(stat -c %a "$R/tmp")" = 1777 ] && ok "E4 root dir owned by root, tmp is 1777" || bad "E4 $(stat -c %u:%a "$R") $(stat -c %a "$R/tmp")"
grep -q 'Ubuntu 16.04' "$R/etc/os-release" && ok "E5 it is Ubuntu 16.04 ($(grep PRETTY "$R/etc/os-release"))" || bad "E5"
( . "$V2"; set +e; ROOT="$R"; check_root_tree ) >/dev/null 2>&1 && ok "E6 check_root_tree accepts the real extracted tree (all directories it requires are real directories)" || bad "E6 check_root_tree rejects the real tree"
V extract "$P" >/dev/null 2>&1 && bad "E7 second extract must refuse to overwrite" || ok "E7 a second extract refuses to overwrite"

echo "## E. tampered and interrupted extraction"
P2="$W/p2"; mkdir -p "$P2"; cp "$P/SHA256SUMS" "$P/SHA256SUMS.gpg" "$P2/"; cp "$TB" "$P2/ubuntu-base-16.04.6-base-amd64.tar.gz"; printf x >> "$P2/ubuntu-base-16.04.6-base-amd64.tar.gz"
V extract "$P2" >/dev/null 2>&1 && bad "E8 tarball changed after fetch must be refused" || ok "E8 a tarball altered after fetch is refused at extract (re-verification)"
[ ! -e "$P2/xenial-root" ] && ok "E9 and nothing was extracted" || bad "E9"
P3="$W/p3"; mkdir -p "$P3" "$W/bin"; cp "$P/SHA256SUMS" "$P/SHA256SUMS.gpg" "$TB" "$P3/"
printf '#!/bin/bash\ncase " $* " in *" -xpzf "*|*-xpzf*) exec sleep 7331;; esac\nexec /usr/bin/tar "$@"\n' > "$W/bin/tar"; chmod +x "$W/bin/tar"
for sig in TERM:143 INT:130; do
  name=${sig%%:*}; want=${sig##*:}; rm -rf "$P3/xenial-root"
  PATH="$W/bin:$PATH" start_bg "$W/pid" "$W/log" env -u SUDO_UID bash "$V2" extract "$P3"
  wait_for "pgrep -f 'sleep 7331' >/dev/null" 15
  [ "$name" = INT ] && kill -INT -- "-$BGPID" || kill -"$name" "$BGPID"
  wait "$BGPID"; rc=$?
  [ $rc = $want ] && [ ! -e "$P3/xenial-root" ] && ! pgrep -f "sleep 7331" >/dev/null && ok "E10 $name during extraction: exit $rc, partial tree removed, extractor stopped" || bad "E10 $name rc=$rc tree=$(ls "$P3")"
  pkill -f "sleep 7331" 2>/dev/null; true
done

echo "## E. concurrent extraction"
rm -rf "$P3/xenial-root"
PATH="$W/bin:$PATH" start_bg "$W/pid" "$W/log" env -u SUDO_UID bash "$V2" extract "$P3"; FIRST=$BGPID
wait_for "pgrep -f 'sleep 7331' >/dev/null && [ -d '$P3/xenial-root' ]" 15
out=$(PATH="$W/bin:$PATH" env -u SUDO_UID bash "$V2" extract "$P3" 2>&1); rc=$?
[ $rc != 0 ] && echo "$out" | grep -q "another xenial-userland.sh instance is running" && ok "E11 a second extract while the first runs is refused by the lock (before it looks at the tree)" || bad "E11 rc=$rc $out"
[ -d "$P3/xenial-root" ] && kill -0 "$FIRST" 2>/dev/null && pgrep -f "sleep 7331" >/dev/null && ok "E12 the first extraction's tree and process are untouched by the refused attempt" || bad "E12"
kill -TERM "$FIRST"; wait "$FIRST"; rc=$?
[ $rc = 143 ] && [ ! -e "$P3/xenial-root" ] && ok "E13 the first one, when interrupted, removes only its own partial tree" || bad "E13 rc=$rc tree=$(ls "$P3")"
pkill -f "[s]leep 7331" 2>/dev/null
# a completed extraction must not be removed by a later extract that is refused
V extract "$P3" >/dev/null 2>&1; [ -x "$P3/xenial-root/bin/bash" ] && ok "E14 extract after the interrupted one works" || bad "E14"
V extract "$P3" >/dev/null 2>&1; [ -x "$P3/xenial-root/bin/bash" ] && ok "E15 a further extract is refused and the finished tree is left intact" || bad "E15 finished tree damaged"

echo "## X. enter and teardown on the real userland (no apt)"
before=$(cd "$SRC" && stat -c '%u:%g' .)
out=$(V enter "$P" --uid $U --gid $G "$SRC" /bin/bash -c 'grep PRETTY_NAME /etc/os-release; id -u; id -G; touch /src/created-in-real-xenial; mkdir -p /src/d/e; echo hi > /dev/null; head -c 8 /dev/urandom | wc -c; cat <(echo procsub-ok); ls /dev | tr "\n" " "; echo; test -e /dev/vda && echo HOST-DISK-VISIBLE || echo no-host-disk; ls /proc/self >/dev/null && echo proc-ok; echo "$HOME $USER"; touch $HOME/h && echo home-writable' 2>&1); rc=$?
[ $rc = 0 ] && ok "X1 enter ran bash inside the real Ubuntu 16.04 userland as uid $U" || bad "X1 rc=$rc $out"
echo "$out" | sed -n 1p | grep -q 'Ubuntu 16.04' && ok "X2 the shell reported Ubuntu 16.04 ($(echo "$out" | sed -n 1p))" || bad "X2 $out"
echo "$out" | sed -n 2p | grep -qx $U && echo "$out" | sed -n 3p | grep -qx $G && ok "X3 identity inside: uid $U, only group $G" || bad "X3"
[ "$(stat -c %u:%g "$SRC/created-in-real-xenial")" = $U:$G ] && [ "$(stat -c %u:%g "$SRC/d/e")" = $U:$G ] && ok "X4 files created in /src belong to the normal user" || bad "X4"
[ "$(cd "$SRC" && stat -c '%u:%g' .)" = "$before" ] && ok "X5 the source directory itself kept its owner" || bad "X5"
echo "$out" | grep -qx 8 && echo "$out" | grep -q procsub-ok && echo "$out" | grep -q proc-ok && echo "$out" | grep -q home-writable && ok "X6 /dev/null, /dev/urandom, process substitution (/dev/fd), /proc and \$HOME work" || bad "X6 $out"
devls=$(echo "$out" | sed -n 6p | tr -s ' ' | sed 's/ $//')
[ "$devls" = "fd full null ptmx pts random shm stderr stdin stdout tty urandom zero" ] && ok "X7 /dev contains only the minimal set: $devls" || bad "X7 /dev = [$devls]"
echo "$out" | grep -q no-host-disk && ok "X8 host disk devices are NOT visible inside the chroot" || bad "X8"
[ "$(n_mounts)" = 0 ] && ok "X9 no mounts left" || bad "X9 mounts: $(n_mounts)"
echo "$out" | grep -q 'builder' ; grep -q '^builder:x:12345:12345' "$R/etc/passwd" && [ "$(grep -c '^builder:' "$R/etc/passwd")" = 1 ] && ok "X10 builder entry added once to the REAL userland's passwd (re-running adds nothing)" || bad "X10"
V enter "$P" --uid $U --gid $G "$SRC" /bin/true >/dev/null 2>&1; [ "$(grep -c '^builder:' "$R/etc/passwd")" = 1 ] && ok "X11 second enter did not duplicate the account" || bad "X11"
V teardown "$P" 2>&1 | grep -q -- "--one-file-system" && ok "X12 teardown on the real tree: clean, prints rm --one-file-system" || bad "X12"
finish
