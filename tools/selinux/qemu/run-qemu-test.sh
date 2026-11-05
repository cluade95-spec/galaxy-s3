#!/bin/bash
# Boot one kernel image in QEMU's vexpress-a9 with one initramfs and capture the serial console.
# Usage: run-qemu-test.sh <qemu-system-arm> <zImage> <initramfs.cpio> <extra kernel args> <log> [timeout s]
# QEMU is run from an unpacked Ubuntu package (no installation): set LD_LIBRARY_PATH for it before calling.
QEMU="$1"; Z="$2"; RD="$3"; ARGS="$4"; LOG="$5"; T="${6:-180}"
timeout "$T" "$QEMU" -M vexpress-a9 -m 256 -nographic -no-reboot -net none \
   -kernel "$Z" -initrd "$RD" -append "console=ttyAMA0 rdinit=/init loglevel=7 $ARGS" > "$LOG" 2>&1
echo "qemu exit=$?" >> "$LOG"
