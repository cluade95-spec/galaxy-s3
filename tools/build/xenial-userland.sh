#!/bin/bash
# Reproducible Ubuntu 16.04 (xenial) build userland in a plain directory + chroot. Changes NO host package; needs root only
# for chroot/mount. Everything lives under ROOT; `teardown` unmounts and (after you confirm) removes it.
#
#   xenial-userland.sh fetch    ROOT_PARENT            download ubuntu-base 16.04.6, verify its SHA-256 against Ubuntu's SHA256SUMS
#   xenial-userland.sh extract  ROOT_PARENT            unpack it to ROOT_PARENT/xenial-root (run as root)
#   xenial-userland.sh install  ROOT_PARENT            apt-get the Android 7 build packages inside the chroot (NOT TESTED in the sandbox, see doc)
#   xenial-userland.sh enter    ROOT_PARENT [SRC] [CMD...]   bind-mount proc, dev, and SRC at /src, run CMD (default: bash), unmount on exit
#   xenial-userland.sh teardown ROOT_PARENT            unmount everything; prints the one rm command, does not run it
#
# What was tested in the Phase 7/8 sandbox: fetch+verify, extract, python2.7 / OpenJDK 8 / make 4.1 inside, enter/unmount.
# Not tested: `install` (apt), because the sandbox proxy rejects some apt requests and blocks security.ubuntu.com.
set -euo pipefail
CMD="${1:?usage: $0 fetch|extract|install|enter|teardown ROOT_PARENT ...}"; PARENT="${2:?ROOT_PARENT}"; shift 2 || true
BASE=http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release
TAR=ubuntu-base-16.04.6-base-amd64.tar.gz
ROOT="$PARENT/xenial-root"
# Android 7.x build dependencies on Ubuntu 16.04 as listed in the AOSP "Initializing a Build Environment" page for that
# release, plus Python 2. Taken from memory of that page: CHECK against the LineageOS 14.1 documentation before relying on it.
PKGS="git-core gnupg flex bison gperf build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev libgl1-mesa-dev libxml2-utils xsltproc unzip openjdk-8-jdk python2.7 bc rsync ccache libssl-dev ca-certificates"
need_root() { [ "$(id -u)" = 0 ] || { echo "run as root (sudo): chroot and mount need it; nothing else on the host is changed"; exit 1; }; }
mounted() { grep -q " $ROOT/$1 " /proc/mounts; }
case "$CMD" in
  fetch)
    mkdir -p "$PARENT"; cd "$PARENT"
    [ -f "$TAR" ] || curl -fsS -O "$BASE/$TAR"
    curl -fsS -O "$BASE/SHA256SUMS"; curl -fsS -O "$BASE/SHA256SUMS.gpg" || true
    grep " \*\?$TAR\$" SHA256SUMS | sed 's/ \*/  /' | sha256sum -c -
    echo "SHA-256 matches the SHA256SUMS file. ALSO verify its signature before trusting it:  gpg --verify SHA256SUMS.gpg SHA256SUMS"
    echo "(import Ubuntu's CD image signing key through a channel you trust; this script does not do that for you)" ;;
  extract)
    need_root; [ -f "$PARENT/$TAR" ] || { echo "run fetch first"; exit 1; }
    [ ! -e "$ROOT" ] || { echo "$ROOT exists; refusing to overwrite"; exit 1; }
    mkdir -p "$ROOT"; tar -xpzf "$PARENT/$TAR" -C "$ROOT"; echo "unpacked to $ROOT" ;;
  install)
    need_root; cp /etc/resolv.conf "$ROOT/etc/resolv.conf"
    printf 'deb http://archive.ubuntu.com/ubuntu xenial main universe\ndeb http://archive.ubuntu.com/ubuntu xenial-updates main universe\ndeb http://security.ubuntu.com/ubuntu xenial-security main universe\n' > "$ROOT/etc/apt/sources.list"
    mount -t proc proc "$ROOT/proc"; trap 'umount "$ROOT/proc"' EXIT
    chroot "$ROOT" /bin/bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y --no-install-recommends $PKGS && ln -sf python2.7 /usr/bin/python"
    chroot "$ROOT" /bin/bash -c 'java -version 2>&1 | head -2; javac -version 2>&1; python --version 2>&1; make --version | head -1' ;;
  enter)
    need_root; SRC="${1:-}"; shift || true
    mount -t proc proc "$ROOT/proc"; mount --bind /dev "$ROOT/dev"
    if [ -n "$SRC" ]; then mkdir -p "$ROOT/src"; mount --bind "$SRC" "$ROOT/src"; fi
    trap 'umount "$ROOT/src" 2>/dev/null || true; umount "$ROOT/dev"; umount "$ROOT/proc"' EXIT
    chroot "$ROOT" /usr/bin/env -i HOME=/root TERM="${TERM:-xterm}" PATH=/usr/sbin:/usr/bin:/sbin:/bin "${@:-/bin/bash}" ;;
  teardown)
    need_root
    for m in src dev proc; do mounted "$m" && umount "$ROOT/$m" && echo "unmounted $m"; done
    grep " $ROOT" /proc/mounts && { echo "still mounted below $ROOT: do NOT remove it"; exit 1; } || true
    echo "no mounts remain below $ROOT. To delete the userland, run yourself:  rm -rf '$ROOT'" ;;
  *) echo "unknown command $CMD"; exit 1 ;;
esac
