# mini_root PARENT : a tiny chroot at PARENT/xenial-root built from the host's own bash and coreutils (no Ubuntu image). Sourced by the root tests.
mini_root() {
  local P="$1" R="$1/xenial-root" b p l
  mkdir -p "$R"/{bin,usr/bin,usr/sbin,usr/share/keyrings,lib,lib64,etc/apt,proc,dev,tmp,home,var/log}
  for b in bash env id touch mkdir stat cat ls sleep rm head wc kill ln true false sh echo; do
    p=$(type -P "$b") || continue
    cp -L "$p" "$R/usr/bin/$b"
    ldd "$p" 2>/dev/null | grep -o '/[^ ]*' | while read -r l; do [ -e "$l" ] && { mkdir -p "$R$(dirname "$l")"; cp -L "$l" "$R$l"; }; done
  done
  ln -sf ../usr/bin/bash "$R/bin/bash"; ln -sf ../usr/bin/sh "$R/bin/sh"; chmod 1777 "$R/tmp"
  printf 'root:x:0:0:root:/root:/bin/bash\n' > "$R/etc/passwd"; printf 'root:x:0:\n' > "$R/etc/group"
  cp /usr/share/keyrings/ubuntu-archive-keyring.gpg "$R/usr/share/keyrings/"
}
n_mounts() { awk -v r="$R" 'index($2,r)==1' /proc/mounts | wc -l; }
procs_in_root() { local p n=0; for p in /proc/[0-9]*; do [ "$(readlink "$p/root" 2>/dev/null)" = "$R" ] && n=$((n+1)); done; echo $n; }
wait_for() { local i; for ((i = 0; i < $2 * 10; i++)); do eval "$1" && return 0; sleep 0.1; done; return 1; }
# start_bg PIDFILE LOGFILE CMD... : run CMD in its own session (so a group signal behaves like a terminal Ctrl-C); the pid is the command's pid
# (env --default-signal: a background job of a script starts with SIGINT/SIGQUIT ignored; a real terminal session does not)
start_bg() { local pf="$1" lf="$2"; shift 2; env --default-signal=INT,QUIT setsid bash -c 'echo $$ > "$1"; shift; exec "$@"' _ "$pf" "$@" > "$lf" 2>&1 & BGPID=$!; wait_for "[ -s '$pf' ]" 5; }
