#!/bin/bash
# Test driver: runs the real cmd_fetch with `download` replaced by a local fake. MODE: ok badtar badsums badsig sleep fail ; env: PARENT TB (tarball to serve)
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../xenial-userland.v2.sh"
FX="$HERE/fixtures"
download() {   # download URL DEST   (run in a background subshell by run_child)
  local name=${1##*/} dest=$2
  case "$MODE" in sleep) exec sleep 7321;; fail) exit 1;; esac
  case "$name" in
    SHA256SUMS)     cp "$FX/SHA256SUMS" "$dest"; [ "$MODE" != badsums ] || printf '0000 other\n' >> "$dest";;
    SHA256SUMS.gpg) cp "$FX/SHA256SUMS.gpg" "$dest"; [ "$MODE" != badsig ] || printf 'garbage' > "$dest";;
    *)              cp "$TB" "$dest"; [ "$MODE" != badtar ] || printf 'x' >> "$dest";;
  esac
}
cmd_fetch "$PARENT"
