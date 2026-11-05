#!/bin/bash
# Read-only preflight for a first LineageOS 14.1 build of goldenvess3g. Prints PASS/FAIL per gate; exit 1 if any gate fails.
# Usage: preflight.sh [min_free_gb]   (default 100: a deliberately low planning figure; the measured sample in
#        docs/phase-6-first-build-attempt.md shows even a shallow source tree is larger than this machine's free space)
MINGB="${1:-100}"; HERE="$(cd "$(dirname "$0")/../.." && pwd)"; DEV="$HERE/android/device/samsung/goldenvess3g"
VEN="$HERE/android/vendor/samsung/goldenvess3g"; fail=0
gate(){ if [ "$2" = ok ]; then printf 'PASS  %-34s %s\n' "$1" "$3"; else printf 'FAIL  %-34s %s\n' "$1" "$3"; fail=1; fi; }
echo "host: $(uname -sr), $(nproc) CPUs, $(free -g | awk '/Mem:/{print $2}') GiB RAM"
free_gb=$(df -BG --output=avail "$HERE" | tail -1 | tr -dc 0-9)
[ "$free_gb" -ge "$MINGB" ] && gate disk ok "${free_gb} GiB free" || gate disk bad "${free_gb} GiB free, need at least ${MINGB} GiB for source plus output (planning figure)"
jv=$(javac -version 2>&1 | grep -o 'javac [0-9.]*' | head -1)
case "$jv" in "javac 1.8"*|"javac 8"*) gate "JDK 8 (Android 7 needs OpenJDK 8)" ok "$jv";; *) gate "JDK 8 (Android 7 needs OpenJDK 8)" bad "found: ${jv:-none}";; esac
command -v python2 >/dev/null && gate "python2 (build/releasetools are py2)" ok "$(python2 --version 2>&1)" || gate "python2 (build/releasetools are py2)" bad "not installed"
command -v repo >/dev/null && gate "repo tool" ok "$(command -v repo)" || gate "repo tool" bad "not installed (downloadable; not installed system-wide without approval)"
"$HERE/tools/build/verify-pins.sh" "$DEV/local_manifest.xml" "${TMPDIR:-/tmp}/g-pins-$$" >/dev/null 2>&1 && gate "pinned revisions exist upstream" ok "4 of 4" || gate "pinned revisions exist upstream" bad "see verify-pins.sh output"
n=$(ls "$VEN/proprietary" 2>/dev/null | wc -l)
[ "$n" -gt 0 ] && [ -f "$VEN/extraction-report.txt" ] && gate "vendor tree from verified firmware" ok "$n entries" || gate "vendor tree from verified firmware" bad "no extracted files and no extraction-report.txt (no verified official firmware)"
kd="${GOLDENVESS3G_KERNEL_DIR:-}"
if [ -n "$kd" ] && [ -f "$kd/zImage" ] && ls "$kd"/modules/*.ko >/dev/null 2>&1; then gate "out-of-band kernel (zImage + modules)" ok "$kd"; else gate "out-of-band kernel (zImage + modules)" bad "GOLDENVESS3G_KERNEL_DIR unset or incomplete (build with tools/kernel-build/build-golden-kernel.sh)"; fi
if [ -n "$kd" ] && grep -q '^CONFIG_SECURITY_SELINUX=y$' "$kd/.config" 2>/dev/null; then gate "kernel has SELinux" ok "CONFIG_SECURITY_SELINUX=y"; else gate "kernel has SELinux" bad "Phase 2 kernel has CONFIG_SECURITY off; Android 7 init needs SELinux (and policy v30 vs kernel v26 is open)"; fi
miss=""; for v in BOARD_KERNEL_BASE BOARD_KERNEL_PAGESIZE BOARD_BOOTIMAGE_PARTITION_SIZE BOARD_SYSTEMIMAGE_PARTITION_SIZE BOARD_USERDATAIMAGE_PARTITION_SIZE BOARD_FLASH_BLOCK_SIZE; do
  grep -Eq "^[[:space:]]*$v[[:space:]]*:?=" "$DEV/BoardConfig.mk" || miss="$miss $v"; done
[ -z "$miss" ] && gate "BoardConfig values defined" ok "all present" || gate "BoardConfig values defined" bad "undefined (TODO, no verified source):$miss"
exit $fail
