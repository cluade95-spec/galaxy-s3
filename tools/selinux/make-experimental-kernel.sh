#!/bin/bash
# EXPERIMENT (Phase 7): build a SEPARATE COPY of the pinned GT-I8200 kernel with Google's android-3.4 SELinux/LSM code
# copied over, so SELinux policy version 30 + ioctl extended permissions can be compiled in. The pinned source clone is
# never touched. Output stays in WORKDIR. Compile-only: no kernel was ever run (no phone, no emulator).
# Usage: make-experimental-kernel.sh WORKDIR PRISTINE_CLONE ARM_EABI_PREFIX PERL_SHIM
#   PRISTINE_CLONE  a git clone at 44afe4cf6023bf39c18bad72185003a40915fad2 (from tools/kernel-build/build-golden-kernel.sh)
#   ARM_EABI_PREFIX e.g. /path/to/arm-eabi-4.6/bin/arm-eabi-   (the pinned toolchain)
#   PERL_SHIM       perl-shim.sh from the Phase 2 build (host perl 5.38 breaks kernel/timeconst.pl)
set -euo pipefail
W=$(mkdir -p "$1" && cd "$1" && pwd); PRISTINE=$(cd "$2" && pwd); CROSS="$3"; SHIM="$4"
ACOMMIT=40bb591cb6abaf540bf9a988e3fac0ca86368865     # android.googlesource.com/kernel/common refs/heads/deprecated/android-3.4 (2026-11-05)
KCOMMIT=44afe4cf6023bf39c18bad72185003a40915fad2
[ "$(git -C "$PRISTINE" rev-parse HEAD)" = "$KCOMMIT" ] || { echo "pristine clone is not at $KCOMMIT"; exit 1; }
# files taken verbatim from Google's android-3.4 (everything else, incl. binder.c, nlmsgtab.c, audit.h, binfmts.h, stays as is)
FILES="security/selinux include/linux/security.h include/linux/lsm_audit.h security/security.c security/capability.c security/commoncap.c security/lsm_audit.c security/Kconfig"
rm -rf "$W/acom" "$W/a34" "$W/kexp" && mkdir -p "$W/acom" "$W/a34"
git -C "$W/acom" init -q . && git -C "$W/acom" fetch -q --depth 1 --filter=blob:none https://android.googlesource.com/kernel/common "$ACOMMIT"
git -C "$W/acom" archive "$ACOMMIT" $FILES | tar -x -C "$W/a34"
# android-3.4 also carries "selinux: Android kernel compatibility with M userspace" (Android-only, "NOT intended for
# new Android devices"): it converts Android-M-format policies, which a new device with Android 7 userspace never has.
# It is reverse-applied below so the experiment contains only what Android 7 needs.
MCOMPAT=3f3f88f18a15ac8efd8bf438b61af1511c8097bf
git -C "$W/acom" fetch -q --depth 2 --filter=blob:none https://android.googlesource.com/kernel/common "$MCOMPAT"
git -C "$W/acom" format-patch -1 --stdout "$MCOMPAT" > "$W/mcompat.patch"
git clone -q --no-checkout "$PRISTINE" "$W/kexp" && git -C "$W/kexp" checkout -q "$KCOMMIT"
cd "$W/kexp"
for f in $FILES; do mkdir -p "$(dirname "$f")"; if [ -d "$W/a34/$f" ]; then cp -a "$W/a34/$f/." "$f/"; else cp "$W/a34/$f" "$f"; fi; done
git apply -R --check "$W/mcompat.patch" && git apply -R "$W/mcompat.patch" && echo "reverse-applied 3f3f88f (M-userspace compatibility)"
git checkout -q -- security/selinux/nlmsgtab.c      # android-3.4's version needs an unrelated Android macro
find security include/linux -newer "$W/acom/.git/HEAD" -type f -exec touch {} +   # git archive stamps old dates; force header regeneration
make ARCH=arm CROSS_COMPILE="$CROSS" mrproper >/dev/null 2>&1   # in the COPY only (899 leftover files, as in Phase 2)
OUT="$W/out"; mkdir -p "$OUT"
make O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc pxa986_golden_rev02_defconfig
scripts/config --file "$OUT/.config" --enable CONFIG_SECURITY --enable CONFIG_SECURITY_NETWORK --enable CONFIG_AUDIT \
  --enable CONFIG_SECURITY_SELINUX --enable CONFIG_SECURITY_SELINUX_DEVELOP --enable CONFIG_EXT4_FS_SECURITY \
  --disable CONFIG_DEFAULT_SECURITY_DAC --enable CONFIG_DEFAULT_SECURITY_SELINUX
make O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc oldconfig < <(yes "") >/dev/null
export KBUILD_BUILD_USER=experimental KBUILD_BUILD_HOST=goldenvess3g-exp
make -j"$(nproc)" O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc PERL="$SHIM" zImage 2>&1 | tee "$W/build.log" | tail -3
sha256sum "$OUT/arch/arm/boot/zImage"
"${CROSS}nm" "$OUT/vmlinux" | grep -E " T avc_has_extended_perms| t avtab_.*xperm" | head -3
