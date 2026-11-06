#!/bin/bash
# Phase 9 (Part D): build the REAL board configuration (pxa986_golden_rev02_defconfig) in a DISPOSABLE copy of the pinned tree with
# the whole SELinux back-port patch applied, plus the kernel modules. Compile-only: nothing is run (no phone, no emulator).
# Usage: make-pxa988-test-kernel.sh WORKDIR PRISTINE_CLONE ARM_EABI_PREFIX PERL_SHIM PLAIN|SHIP [PATCH_FILE...]
#   PLAIN = plain defconfig + SELinux options;  SHIP = also Samsung's five production options (SEC_RESTRICT_*, SAMSUNG_PRODUCT_SHIP)
# The pinned clone is only read. The patch is applied to the copy.
set -euo pipefail
W=$(mkdir -p "$1" && cd "$1" && pwd); PRISTINE=$(cd "$2" && pwd); CROSS="$3"; SHIM="$4"; VAR="$5"; shift 5
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../.." && pwd)
PATCHES=("$@"); [ ${#PATCHES[@]} -gt 0 ] || PATCHES=("$REPO/tools/selinux/patches/android-3.4-selinux-backport.patch")
KCOMMIT=44afe4cf6023bf39c18bad72185003a40915fad2
[ "$(git -C "$PRISTINE" rev-parse HEAD)" = "$KCOMMIT" ] || { echo "pristine clone is not at $KCOMMIT"; exit 1; }
SRC="$W/src-$VAR"; OUT="$W/out-$VAR"; rm -rf "$SRC" "$OUT"; mkdir -p "$OUT"
git clone -q --no-checkout "$PRISTINE" "$SRC"; git -C "$SRC" checkout -q "$KCOMMIT"
cd "$SRC"; make ARCH=arm CROSS_COMPILE="$CROSS" mrproper >/dev/null 2>&1      # in the COPY only (899 leftover files, as in Phase 2)
for p in "${PATCHES[@]}"; do git apply "$p"; echo "applied to the copy: $(basename "$p")"; done
make O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc pxa986_golden_rev02_defconfig
if [ "$VAR" = SHIP ]; then
  scripts/config --file "$OUT/.config" --enable CONFIG_SAMSUNG_PRODUCT_SHIP --enable CONFIG_SEC_RESTRICT_ROOTING --enable CONFIG_SEC_RESTRICT_SETUID \
     --enable CONFIG_SEC_RESTRICT_FORK --enable CONFIG_SEC_RESTRICT_ROOTING_LOG
fi
scripts/config --file "$OUT/.config" --enable CONFIG_SECURITY --enable CONFIG_SECURITY_NETWORK --enable CONFIG_AUDIT \
  --enable CONFIG_SECURITY_SELINUX --enable CONFIG_SECURITY_SELINUX_DEVELOP --enable CONFIG_EXT4_FS_SECURITY \
  --disable CONFIG_DEFAULT_SECURITY_DAC --enable CONFIG_DEFAULT_SECURITY_SELINUX
make O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc oldconfig < <(yes "") >/dev/null
export KBUILD_BUILD_USER=experimental KBUILD_BUILD_HOST=goldenvess3g-pxa
make -j"$(nproc)" O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc PERL="$SHIM" zImage > "$W/build-$VAR-zimage.log" 2>&1
make -j"$(nproc)" O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc PERL="$SHIM" modules > "$W/build-$VAR-modules.log" 2>&1
echo "== $VAR: zImage $(stat -c %s "$OUT/arch/arm/boot/zImage") bytes; modules: $(find "$OUT" -name '*.ko' | wc -l)"
echo "warnings in security/ and binder: $(grep -c -E '(security/|drivers/staging/android/binder).*warning' "$W/build-$VAR-zimage.log")"
"${CROSS}nm" "$OUT/vmlinux" | grep -E " T avc_has_extended_perms| T security_binder_transaction| T security_compute_xperms_decision" | head
grep -E "^CONFIG_(SECURITY|SECURITY_NETWORK|AUDIT|AUDITSYSCALL|SECURITY_SELINUX|SECURITY_SELINUX_DEVELOP|EXT4_FS_SECURITY|DEFAULT_SECURITY_SELINUX|SEC_RESTRICT_[A-Z_]*|SAMSUNG_PRODUCT_SHIP)=" "$OUT/.config"
grep -h vermagic= -r "$OUT" --include='*.mod.c' 2>/dev/null | sort | uniq -c | head -3
