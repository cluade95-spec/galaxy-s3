#!/bin/bash
# Phase 8: build the test policies and initramfs images and run the whole QEMU test matrix, writing one console log per run.
# Usage: run-matrix.sh WORKDIR_WITH_KERNELS QEMU_SYSTEM_ARM SEPOLICY_DIR VENDOR_CM_SEPOLICY_DIR CHECKPOLICY ARM_EABI_PREFIX OUTDIR
#   WORKDIR_WITH_KERNELS  directory containing zImage-k0, zImage-k1, zImage-k2 (from make-qemu-kernels.sh)
#   SEPOLICY_DIR          LineageOS cm-14.1 system/sepolicy checkout (read only)
#   QEMU_SYSTEM_ARM       qemu-system-arm binary; run with LD_LIBRARY_PATH / QEMU_DATA_DIR set if it is an unpacked package
# Nothing is installed; QEMU needs no root. The libGAL proposal is applied only to a scratch COPY of system/sepolicy.
set -euo pipefail
export TEXTREL_FLAG=false     # the broad text-relocation board flag is NOT applied in any policy built here
K="$1"; QEMU="$2"; SP="$3"; CM="$4"; CP="$5"; CROSS="$6"; OUT="$7"
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../.." && pwd); T="$OUT/work"; mkdir -p "$T" "$OUT"
PROP="$REPO/android/device/samsung/goldenvess3g/sepolicy/proposals"
# 1. policies: (a) the unmodified Android policy, (b) + test scaffold, (c) patched-copy + libgal proposal + execmod scaffold
"$REPO/tools/selinux/build-policy-conf.sh" "$SP" "$CM" "$CP" "$T/pure" 30 > "$OUT/policy-pure.log" 2>&1
EXTRA_DIRS="$HERE" "$REPO/tools/selinux/build-policy-conf.sh" "$SP" "$CM" "$CP" "$T/test" 30 > "$OUT/policy-test.log" 2>&1
rm -rf "$T/sp-patched"; cp -r "$SP" "$T/sp-patched"; rm -rf "$T/sp-patched/.git"
( cd "$T/sp-patched" && git init -q . >/dev/null 2>&1; sed -n '/^--- a/,$p' "$PROP/domain-te-libgal-type.patch" | patch -s -p1 )
EXTRA_DIRS="$PROP $HERE $HERE/execmod" TEXTREL_FLAG=false "$REPO/tools/selinux/build-policy-conf.sh" "$T/sp-patched" "$CM" "$CP" "$T/em" 30 > "$OUT/policy-execmod.log" 2>&1
for d in test em; do "$CP" -M -c 30 -o "$T/$d/sepolicy.dontaudit.30" "$T/$d/policy.conf.dontaudit" > /dev/null 2>&1; done   # dontaudit removed: every denial can be logged
# 2. harness and initramfs images
"${CROSS}gcc" -std=gnu99 -Wall -Wextra -nostdlib -static -ffreestanding -fno-builtin -march=armv7-a -marm -O2 -fno-stack-protector -Wl,-e,_start -o "$T/gv-init" "$HERE/init.c" -lgcc
python3 "$HERE/build-initramfs.py" "$T/gv-init" "$T/pure/sepolicy.30" "$T/rd-pure.cpio" > /dev/null
python3 "$HERE/build-initramfs.py" "$T/gv-init" "$T/test/sepolicy.dontaudit.30" "$T/rd-test.cpio" > /dev/null
python3 "$HERE/build-initramfs.py" "$T/gv-init" "$T/em/sepolicy.dontaudit.30" "$T/rd-em.cpio" > /dev/null
sha256sum "$T/pure/sepolicy.30" "$T/test/sepolicy.dontaudit.30" "$T/em/sepolicy.dontaudit.30" "$K"/zImage-k? > "$OUT/sha256.txt"
# 3. runs
run() { "$HERE/run-qemu-test.sh" "$QEMU" "$K/zImage-$1" "$T/rd-$2.cpio" "$3" "$OUT/$4.log" "${5:-200}"; }
run k0 pure "gvmode=load"                                   01-k0-unmodified-kernel-load-android-policy
run k1 pure "gvmode=load"                                   02-k1-backport-load-android-policy
run k2 pure "gvmode=load"                                   03-k2-backport-binder-load-android-policy
run k1 test "gvmode=tests gvexp=nohooks"                    04-k1-no-binder-hooks-tests
run k2 test "gvmode=tests gvexp=hooks"                      05-k2-binder-hooks-tests
run k1 test "gvmode=tests gvexp=hooks"                      06-control-k1-judged-against-hooks
run k2 test "gvmode=tests gvexp=hooks gvenforce=0"          07-control-k2-permissive
run k2 em   "gvmode=execmod"                                08-k2-execmod-libgal-type
run k2 em   "gvmode=execmod gvenforce=0"                    09-control-k2-execmod-permissive
for f in "$OUT"/0?-*.log; do echo "== $(basename "$f")"; grep -a -E "policydb version|LOADED|FAILED|policyvers \(after|enforce \(after|SUMMARY|\[FAIL\]|qemu exit" "$f" | cut -c1-170; done
