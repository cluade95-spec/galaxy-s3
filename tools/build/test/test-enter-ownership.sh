#!/bin/bash
# Root test of `enter`: ownership of files in the bind-mounted source tree, privilege drop, refusals.
# Uses a TINY chroot built from the host's own bash/coreutils (no Ubuntu image). Runs inside a private mount namespace (unshare -m).
# Run:  sudo tools/build/test/test-enter-ownership.sh
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/lib.sh"; . "$HERE/mkroot.sh"; V2="$HERE/../xenial-userland.v2.sh"
[ "$(id -u)" = 0 ] || { echo "needs root (chroot, mount)"; exit 2; }
if [ -z "${XU_IN_NS:-}" ]; then exec env XU_IN_NS=1 unshare -m --propagation private bash "$HERE/$(basename "$0")" "$@"; fi
W=$(mktemp -d /var/tmp/xu-test.XXXXXX); P="$W/root"; R="$P/xenial-root"; SRC="$W/src"; U=12345; G=12345
trap 'umount -R "$R/dev" "$R/proc" "$R/src" 2>/dev/null; rm -rf --one-file-system "$W"' EXIT
V() { env -u SUDO_UID -u SUDO_GID bash "$V2" "$@"; }
mini_root "$P"; mkdir -p "$SRC"
chown $U:$G "$SRC"; echo old > "$SRC/mine"; chown $U:$G "$SRC/mine"; echo old > "$SRC/other"; chown 4242:4242 "$SRC/other"; chmod 666 "$SRC/other"
mkdir "$SRC/dir"; chown $U:$G "$SRC/dir"; echo r > "$SRC/rootfile"; chown 0:0 "$SRC/rootfile"; chmod 644 "$SRC/rootfile"
before=$(cd "$SRC" && stat -c '%n %u:%g %a' mine other dir rootfile)

echo "## O. ownership and privilege"
out=$(V enter "$P" --uid $U --gid $G "$SRC" /usr/bin/bash -c 'id -u; id -g; id -G; touch /src/newfile; mkdir /src/newdir; touch /src/newdir/x; echo more >> /src/other; echo more >> /src/mine; touch /home/builder/h' 2>&1); rc=$?
[ $rc = 0 ] && ok "O1 enter ran the command (exit 0)" || bad "O1 exit $rc: $out"
echo "$out" | sed -n 1p | grep -qx $U && echo "$out" | sed -n 2p | grep -qx $G && echo "$out" | sed -n 3p | grep -qx $G && ok "O2 inside the chroot: uid=$U gid=$G, no supplementary groups (not root)" || bad "O2 identity: $(echo $out | head -c 120)"
(cd "$SRC" && [ "$(stat -c %u:%g newfile)" = $U:$G ] && [ "$(stat -c %u:%g newdir)" = $U:$G ] && [ "$(stat -c %u:%g newdir/x)" = $U:$G ]) && ok "O3 new files and directories are owned by the normal user, not root" || bad "O3 $(cd $SRC; stat -c '%n %u:%g' newfile newdir newdir/x)"
after=$(cd "$SRC" && stat -c '%n %u:%g %a' mine other dir rootfile); [ "$before" = "$after" ] && ok "O4 ownership and mode of EXISTING files unchanged (incl. another uid's and a root-owned file)" || bad "O4 changed: $before -> $after"
[ "$(stat -c %u "$R/home/builder")" = $U ] && ok "O5 chroot home /home/builder belongs to the user" || bad "O5"
grep -q "^builder:x:$U:$G:" "$R/etc/passwd" && ok "O6 passwd entry added only inside the chroot (host /etc/passwd untouched: $(grep -c ":$U:" /etc/passwd) hits)" || bad "O6"
[ "$(n_mounts)" = 0 ] && ok "O7 no mounts left after normal exit" || bad "O7 mounts remain: $(n_mounts)"
V enter "$P" --uid $U --gid $G "$SRC" /usr/bin/bash -c 'touch /src/rootfile' >/dev/null 2>&1 && bad "O8 a normal user must not modify a root-owned 644 file" || ok "O8 root-owned files stay protected from the user (write refused)"
mo=$(V enter "$P" --uid $U --gid $G "$SRC" /usr/bin/bash -c 'while read -r a b c d e; do [ "$b" = /src ] && echo "$d"; done < /proc/mounts' 2>&1); echo "$mo" | grep -q nosuid && echo "$mo" | grep -q nodev && ok "O9 /src is mounted nosuid,nodev" || bad "O9 $mo"
SUDO_UID=$U SUDO_GID=$G bash "$V2" enter "$P" "$SRC" /usr/bin/id -u 2>&1 | grep -qx $U && ok "O10 default user is taken from SUDO_UID/SUDO_GID" || bad "O10"
out=$(V enter "$P" --root "$SRC" /usr/bin/bash -c 'touch /src/asroot' 2>&1); [ "$(stat -c %u "$SRC/asroot" 2>/dev/null)" = 0 ] && echo "$out" | grep -q WARNING && ok "O11 CONTRAST: --root creates root-owned files (the old behaviour) and warns" || bad "O11 $out"
rm -f "$SRC/asroot"

echo "## R. refusals (each must fail closed and leave no mount)"
refuse() { local n="$1"; shift; if V "$@" >/dev/null 2>&1; then bad "$n (should refuse)"; else ok "$n"; fi; }
refuse "R1 uid 0 without --root"                            enter "$P" --uid 0 --gid 0 "$SRC" /usr/bin/id
refuse "R2 no SUDO_UID and no --uid"                        enter "$P" "$SRC" /usr/bin/id
refuse "R3 non-numeric uid"                                 enter "$P" --uid abc --gid 1 "$SRC" /usr/bin/id
refuse "R4 SRC is /"                                        enter "$P" --uid $U --gid $G / /usr/bin/id
refuse "R5 SRC inside the userland directory"               enter "$P" --uid $U --gid $G "$P" /usr/bin/id
mkdir "$W/rootowned"; chown 0:0 "$W/rootowned"; refuse "R6 SRC owned by someone else (script never chowns)" enter "$P" --uid $U --gid $G "$W/rootowned" /usr/bin/id
echo 'taken:x:777:777::/:/bin/false' >> "$R/etc/passwd"; refuse "R7 uid already used by another chroot account" enter "$P" --uid 777 --gid 778 "$SRC" /usr/bin/id
mkdir "$W/f"; chown 778:778 "$W/f"; echo 'x:x:777:' >> "$R/etc/group"; refuse "R8 gid already used by another chroot group" enter "$P" --uid 778 --gid 777 "$W/f" /usr/bin/id
refuse "R9 SRC is not a directory"                          enter "$P" --uid $U --gid $G "$SRC/mine" /usr/bin/id
( . "$V2"; set +e; ( refuse_windows_fs /mnt/c/lineage ) >/dev/null 2>&1 && bad "R10 /mnt/c path must be refused" || ok "R10 /mnt/c/... (Windows drive) refused" )
( . "$V2"; set +e; ( refuse_windows_fs /mnt/d ) >/dev/null 2>&1 && bad "R11 /mnt/d" || ok "R11 /mnt/d refused" )
[ "$(n_mounts)" = 0 ] && ok "R12 no mounts left after the refusals" || bad "R12 mounts remain"
finish
