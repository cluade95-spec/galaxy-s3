#!/bin/bash
# Assemble policy.conf exactly as system/sepolicy/Android.mk (LineageOS cm-14.1) does, on the host, and optionally
# compile it with a host-built checkpolicy at given policy versions. Nothing is installed; everything stays in OUTDIR.
# Usage: build-policy-conf.sh <system/sepolicy dir> <vendor/cm/sepolicy dir> <checkpolicy binary> <OUTDIR> [versions...]
# Variables follow the project's BoardConfig: userdebug, target_needs_platform_text_relocations=true.
# NO policy rule is removed or edited. Errors are reported as they are.
set -u
SP="$1"; CM="$2"; CP="$3"; OUT="$4"; shift 4; VERS="${*:-30}"
mkdir -p "$OUT"
types="security_classes initial_sids access_vectors global_macros neverallow_macros mls_macros mls policy_capabilities te_macros attributes ioctl_defines ioctl_macros *.te roles users initial_sid_contexts fs_use genfs_contexts port_contexts"
files=()
for t in $types; do for d in "$SP" "$CM"; do
  for f in $(cd "$d" 2>/dev/null && ls -1 $t 2>/dev/null | LC_ALL=C sort); do files+=("$d/$f"); done
done; done
echo "policy inputs: ${#files[@]} files ($(printf '%s\n' "${files[@]}" | grep -c "^$CM") from vendor/cm)"
m4 -D mls_num_sens=1 -D mls_num_cats=1024 -D target_build_variant=userdebug -D target_has_legacy_camera_hal1= \
   -D target_needs_platform_text_relocations=true -D shipping_build= -s "${files[@]}" > "$OUT/policy.conf" || { echo "m4 failed"; exit 1; }
sed '/dontaudit/d' "$OUT/policy.conf" > "$OUT/policy.conf.dontaudit"
echo "policy.conf: $(wc -l < "$OUT/policy.conf") lines; allowxperm rules: $(grep -c '^ *allowxperm' "$OUT/policy.conf"); neverallowxperm: $(grep -c '^ *neverallowxperm' "$OUT/policy.conf")"
for v in $VERS; do
  echo "=== checkpolicy -M -c $v"
  "$CP" -M -c "$v" -o "$OUT/sepolicy.$v" "$OUT/policy.conf" > "$OUT/check-$v.log" 2>&1; rc=$?
  echo "exit=$rc errors=$(grep -c -i 'error' "$OUT/check-$v.log")"; head -12 "$OUT/check-$v.log"
done
