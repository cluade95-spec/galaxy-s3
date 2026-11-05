#!/bin/bash
# First experimental LineageOS 14.1 build driver for goldenvess3g. COMPUTER ONLY: never touches a phone, never flashes.
# Stops at the first failed gate. Does not install anything system-wide. Does not disable SELinux, verity or any
# other security feature, and does not substitute unverified vendor files.
#
# Usage: build-lineage.sh <tree dir> <log dir>
#   <tree dir>  empty/new directory for the ~whole Android source tree (needs far more space than a laptop-class sandbox)
#   <log dir>   where complete logs and the exact-revision manifest are written
set -uo pipefail
TREE="${1:?usage: $0 TREE LOGDIR}"; LOGS="${2:?usage: $0 TREE LOGDIR}"; mkdir -p "$LOGS"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"; DEV="$HERE/android/device/samsung/goldenvess3g"; VEN="$HERE/android/vendor/samsung/goldenvess3g"
exec > >(tee -a "$LOGS/build-driver.log") 2>&1
echo "== start $(date -u +%FT%TZ)  repo-head=$(git -C "$HERE" rev-parse HEAD)"
echo "== gate 0: preflight"; "$HERE/tools/build/preflight.sh" "${MIN_FREE_GB:-100}" | tee "$LOGS/preflight.log" || { echo "STOP: preflight failed; nothing was synced or built."; exit 2; }
echo "== gate 1: sync (LineageOS cm-14.1 manifest)"
mkdir -p "$TREE" && cd "$TREE" || exit 3
repo init -u https://github.com/LineageOS/android.git -b cm-14.1 --depth=1 || { echo "STOP: repo init failed"; exit 3; }
mkdir -p .repo/local_manifests && cp "$DEV/local_manifest.xml" .repo/local_manifests/goldenvess3g.xml
repo sync -c -j"$(nproc)" --no-tags --no-clone-bundle 2>&1 | tee "$LOGS/repo-sync.log"; [ "${PIPESTATUS[0]}" = 0 ] || { echo "STOP: repo sync failed"; exit 3; }
repo manifest -r -o "$LOGS/exact-revisions.xml" && echo "exact revisions saved to $LOGS/exact-revisions.xml"
echo "== gate 2: install device and vendor trees (vendor tree must come from extract-files.sh on verified official firmware)"
mkdir -p device/samsung/goldenvess3g vendor/samsung/goldenvess3g
cp -a "$DEV/." device/samsung/goldenvess3g/ && cp -a "$VEN/." vendor/samsung/goldenvess3g/
[ -f vendor/samsung/goldenvess3g/extraction-report.txt ] || { echo "STOP: no extraction-report.txt: vendor files are not from verified firmware"; exit 4; }
echo "== gate 3: build"
set +u; source build/envsetup.sh; breakfast goldenvess3g userdebug 2>&1 | tee "$LOGS/breakfast.log"
mka bacon 2>&1 | tee "$LOGS/build.log"; rc=${PIPESTATUS[0]}; echo "== build exit code $rc"; exit $rc
