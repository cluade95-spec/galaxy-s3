#!/bin/bash
# Guarded extraction of GT-I8200 (goldenvess3g) vendor files from UNPACKED, VERIFIED OFFICIAL firmware.
# Reads only the directory in $GOLDEN_FW_DIR. Never touches a phone. Writes only under ./proprietary/.
# STATUS: written but NEVER RUN against real firmware: no verified official firmware exists yet.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
FW=${GOLDEN_FW_DIR:-}
die() { echo "REFUSED: $*" >&2; exit 2; }

[ -n "$FW" ] && [ -d "$FW/system" ] || die "set GOLDEN_FW_DIR to an unpacked firmware directory that contains system/"
SYS=$FW/system
PROV=$FW/PROVENANCE.txt
[ -f "$PROV" ] || die "no PROVENANCE.txt. Firmware of unknown origin is not accepted (see README.md)."

get() { grep -E "^$1=" "$PROV" | head -1 | cut -d= -f2-; }
for k in source package_name package_size package_sha256 origin; do
  [ -n "$(get $k)" ] || die "PROVENANCE.txt lacks '$k='"
done
case "$(get origin)" in
  samsung-fus|samsung-opensource) ;;
  *) die "origin must be samsung-fus or samsung-opensource (got '$(get origin)'). A mirror is not an origin." ;;
esac
pn=$(get package_name)
echo "$pn" | grep -qiE 'I8200N|I8200Q|I8200L|I8190|I9300|T110|T210|T211' && die "package name '$pn' names a different model"
echo "$pn" | grep -qE 'I8200XXU[A-Z0-9]+' || die "package name '$pn' does not look like a GT-I8200 (I8200XXU...) package"

BP=$SYS/build.prop
[ -f "$BP" ] || die "system/build.prop missing"
prop() { grep -E "^$1=" "$BP" | head -1 | cut -d= -f2-; }
[ "$(prop ro.product.model)" = "GT-I8200" ]       || die "ro.product.model is '$(prop ro.product.model)', need exactly GT-I8200"
[ "$(prop ro.product.device)" = "goldenvess3g" ]  || die "ro.product.device is '$(prop ro.product.device)', need goldenvess3g"
fp=$(prop ro.build.fingerprint)
echo "$fp" | grep -q '/goldenvess3g' || die "fingerprint '$fp' is not a goldenvess3g build"
if [ -n "${EXPECT_PDA:-}" ]; then
  echo "$fp$(prop ro.build.version.incremental)" | grep -q "$EXPECT_PDA" || die "build is not $EXPECT_PDA"
fi

# Rooted or modified trees are not clean stock firmware.
for f in bin/.ext/.su xbin/su bin/su xbin/daemonsu etc/init.d/99SuperSUDaemon app/Superuser.apk app/SuperSU.apk; do
  [ -e "$SYS/$f" ] && die "root artifact present: system/$f (not clean stock firmware)"
done
if [ -f "$SYS/etc/install-recovery.sh" ] && grep -qiE 'daemonsu|/su ' "$SYS/etc/install-recovery.sh"; then
  die "system/etc/install-recovery.sh starts a root daemon"
fi

OUT=$HERE/proprietary
REPORT=$HERE/extraction-report.txt
mkdir -p "$OUT"
{
  echo "# extraction report"
  echo "source=$(get source)"; echo "package_name=$pn"; echo "package_size=$(get package_size)"
  echo "package_sha256=$(get package_sha256)"; echo "origin=$(get origin)"
  echo "build_fingerprint=$fp"
} > "$REPORT"

missing=0; copied=0
SYS_REAL=$(cd "$SYS" && pwd -P)
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  rel=${line%%#*}; rel=$(echo "$rel" | tr -d ' \t'); rel=${rel#system/}
  src=$SYS/$rel
  if [ ! -f "$src" ]; then echo "MISSING $rel" | tee -a "$REPORT" >&2; missing=$((missing+1)); continue; fi
  real=$(cd "$(dirname "$src")" && pwd -P)/$(basename "$src")
  case "$real" in "$SYS_REAL"/*) ;; *) die "path escapes the firmware tree: $rel" ;; esac
  mkdir -p "$OUT/$(dirname "$rel")"
  cp --preserve=mode "$src" "$OUT/$rel"
  echo "$(sha256sum "$OUT/$rel" | cut -d' ' -f1)  $(stat -c %s "$OUT/$rel")  $rel" >> "$REPORT"
  copied=$((copied+1))
done < "$HERE/proprietary-files.txt"

echo "copied $copied files, $missing missing. Report: $REPORT"
echo "Known gap: sensord is not in the manifest (absent from the only dump examined); check the official firmware for bin/sensord."
[ "$missing" -eq 0 ] || exit 1
