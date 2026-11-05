#!/bin/bash
# Host-only logic test of ril_interposer.c with a FAKE vendor RIL written for this test (no Samsung code).
# Usage: run-test.sh <dir containing telephony/ril.h> <scratch dir>
# Proves only: ids above the vendor limit are never forwarded and never answered with success.
set -e
INC="$1"; OUT="$2"; HERE="$(cd "$(dirname "$0")" && pwd)"; SRC="$HERE/../../android/device/samsung/goldenvess3g/ril/ril_interposer.c"
mkdir -p "$OUT"
cc -shared -fPIC -DRIL_SHLIB -I"$INC" -o "$OUT/libfakevendor.so" "$HERE/fake_vendor.c"
cc -shared -fPIC -DRIL_SHLIB -I"$INC" -DVENDOR_RIL_PATH="\"$OUT/libfakevendor.so\"" -o "$OUT/libinterposer.so" "$SRC" -ldl
cc -DRIL_SHLIB -I"$INC" -o "$OUT/test" "$HERE/test_main.c" -ldl
"$OUT/test" "$OUT/libinterposer.so" "$OUT/libfakevendor.so"
