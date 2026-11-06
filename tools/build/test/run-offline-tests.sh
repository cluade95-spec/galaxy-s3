#!/bin/bash
# Tests that need NO root, NO network and NO image download. (test-fetch.sh uses the real tarball only if it is already on disk.)
HERE=$(cd "$(dirname "$0")" && pwd); rc=0
for t in test-verify test-packages test-java-tls test-fetch; do echo "=== $t"; bash "$HERE/$t.sh" || rc=1; done
echo; echo "Root tests (need sudo; each re-executes itself in a private mount namespace, so nothing leaks into your real mounts): sudo $HERE/run-root-tests.sh"
exit $rc
