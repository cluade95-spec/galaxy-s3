#!/bin/bash
# EXPERIMENT (Phase 8): build three kernels for QEMU's ARM Versatile Express (vexpress-a9) from SEPARATE COPIES of the
# pinned GT-I8200 kernel tree, to test SELinux policy version 30, ioctl extended permissions and the binder hooks.
#   k0 = pinned source unchanged, SELinux switched on     (expected: cannot load a version 30 policy)
#   k1 = + Google android-3.4 SELinux/LSM code           (Phase 7 back-port, NO binder hooks)
#   k2 = k1 + the five binder LSM hook calls              (tools/selinux/patches/binder-lsm-hooks.patch)
# The pinned clone is only read. These kernels are for an emulator, never for a phone (vexpress, not PXA988).
# Usage: make-qemu-kernels.sh WORKDIR PRISTINE_CLONE ARM_EABI_PREFIX PERL_SHIM
set -euo pipefail
W=$(mkdir -p "$1" && cd "$1" && pwd); PRISTINE=$(cd "$2" && pwd); CROSS="$3"; SHIM="$4"
HERE=$(cd "$(dirname "$0")" && pwd)
KCOMMIT=44afe4cf6023bf39c18bad72185003a40915fad2
ACOMMIT=40bb591cb6abaf540bf9a988e3fac0ca86368865
MCOMPAT=3f3f88f18a15ac8efd8bf438b61af1511c8097bf
[ "$(git -C "$PRISTINE" rev-parse HEAD)" = "$KCOMMIT" ] || { echo "pristine clone is not at $KCOMMIT"; exit 1; }
FILES="security/selinux include/linux/security.h include/linux/lsm_audit.h security/security.c security/capability.c security/commoncap.c security/lsm_audit.c security/Kconfig"
export KBUILD_BUILD_USER=experimental KBUILD_BUILD_HOST=goldenvess3g-qemu

config_and_build() {  # $1=srcdir $2=outdir
  local SRC=$1 OUT=$2; mkdir -p "$OUT"
  ( cd "$SRC"
    make O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc vexpress_defconfig
    scripts/config --file "$OUT/.config" \
      --enable CONFIG_SECURITY --enable CONFIG_SECURITY_NETWORK --enable CONFIG_AUDIT \
      --enable CONFIG_SECURITY_SELINUX --enable CONFIG_SECURITY_SELINUX_DEVELOP \
      --disable CONFIG_DEFAULT_SECURITY_DAC --enable CONFIG_DEFAULT_SECURITY_SELINUX \
      --enable CONFIG_STAGING --enable CONFIG_ANDROID --enable CONFIG_ANDROID_BINDER_IPC \
      --enable CONFIG_DEVTMPFS --enable CONFIG_TMPFS --enable CONFIG_PROC_FS --enable CONFIG_SYSFS \
      --disable CONFIG_MODULES --disable CONFIG_SMP --disable CONFIG_VIBRATOR_ANDROID
    make O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc oldconfig < <(yes "") >/dev/null
    make -j"$(nproc)" O="$OUT" ARCH=arm CROSS_COMPILE="$CROSS" HOSTCC=gcc PERL="$SHIM" zImage
  )
}
prep_copy() {  # $1=dir
  rm -rf "$1"; git clone -q --no-checkout "$PRISTINE" "$1"; git -C "$1" checkout -q "$KCOMMIT"
  ( cd "$1"; make ARCH=arm CROSS_COMPILE="$CROSS" mrproper >/dev/null 2>&1   # in the COPY only
    # Samsung's generic kernel files (printk.c, timer.c, ...) include <mach/sec_debug.h>, which exists only for the
    # PXA988 platform. Copy the same header (verbatim, all its content is behind CONFIG_SEC_* switches that are off)
    # into the vexpress include directory of the COPY so the tree builds for the emulator board.
    cp arch/arm/mach-mmp/include/mach/sec_debug.h arch/arm/mach-vexpress/include/mach/sec_debug.h
    # Two Samsung symbols are also referenced from generic code (input.c, mmc/core/core.c) and defined only for PXA988.
    # Empty stand-ins, again in the COPY only, so the emulator kernel links. They do nothing on the emulated board.
    printf '#include <linux/device.h>\nvoid sec_debug_check_crash_key(unsigned int code, int value) { }\nstruct class *sec_class;\n' > arch/arm/mach-vexpress/gv_qemu_stubs.c
    echo 'obj-y += gv_qemu_stubs.o' >> arch/arm/mach-vexpress/Makefile )
}

# ---- Google android-3.4 reference files (read-only fetch) ----
rm -rf "$W/acom" "$W/a34"; mkdir -p "$W/acom" "$W/a34"
git -C "$W/acom" init -q .
git -C "$W/acom" fetch -q --depth 1 --filter=blob:none https://android.googlesource.com/kernel/common "$ACOMMIT"
git -C "$W/acom" archive "$ACOMMIT" $FILES | tar -x -C "$W/a34"
git -C "$W/acom" fetch -q --depth 2 --filter=blob:none https://android.googlesource.com/kernel/common "$MCOMPAT"
git -C "$W/acom" format-patch -1 --stdout "$MCOMPAT" > "$W/mcompat.patch"

# ---- k0: baseline ----
echo "== k0 baseline"; prep_copy "$W/k0"; config_and_build "$W/k0" "$W/out-k0" > "$W/build-k0.log" 2>&1
cp "$W/out-k0/arch/arm/boot/zImage" "$W/zImage-k0"

# ---- k1: back-port without binder hooks; k2: with them ----
echo "== k1 back-port"; prep_copy "$W/k1"
( cd "$W/k1"
  for f in $FILES; do mkdir -p "$(dirname "$f")"; if [ -d "$W/a34/$f" ]; then cp -a "$W/a34/$f/." "$f/"; else cp "$W/a34/$f" "$f"; fi; done
  git checkout -q -- security/selinux/nlmsgtab.c
  git apply -R "$W/mcompat.patch"
  find security include/linux -type f -exec touch {} + )
config_and_build "$W/k1" "$W/out-k1" > "$W/build-k1.log" 2>&1
cp "$W/out-k1/arch/arm/boot/zImage" "$W/zImage-k1"
echo "== k2 back-port + binder hooks"
( cd "$W/k1"; sed -n '/^--- a/,$p' "$HERE/../patches/binder-lsm-hooks.patch" | git apply; touch drivers/staging/android/binder.c )
config_and_build "$W/k1" "$W/out-k1" > "$W/build-k2.log" 2>&1
cp "$W/out-k1/arch/arm/boot/zImage" "$W/zImage-k2"
( cd "$W/k1"; git diff --shortstat -- security include/linux drivers/staging/android ':!include/linux/version.h' ) | tee "$W/diffstat-k2.txt"
sha256sum "$W"/zImage-k? | tee "$W/zimages.sha256"
