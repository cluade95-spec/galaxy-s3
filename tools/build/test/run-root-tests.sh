#!/bin/bash
# Root tests (chroot + mount, in a private mount namespace). Uses a tiny chroot built from the host's bash/coreutils; test-extract-real.sh additionally
# needs the real ubuntu-base tarball (XU_REAL_TARBALL=/path/to/ubuntu-base-16.04.6-base-amd64.tar.gz) and is skipped without it.
HERE=$(cd "$(dirname "$0")" && pwd); rc=0
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 2; }
for t in test-enter-ownership test-session-safety test-extract-real; do echo "=== $t"; bash "$HERE/$t.sh" || rc=1; done
exit $rc
