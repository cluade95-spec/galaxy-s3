#!/bin/bash
# Offline checks of the package lists (no root, no network): against the AUTHORITATIVE LineageOS list, the decisions table, and recorded Xenial data.
# Regenerate the Xenial data (network, no root):  python3 tools/build/check-xenial-packages.py live docs/data/xenial-package-availability.tsv
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/lib.sh"; B="$HERE/.."; D="$HERE/../../../docs/data"
S="$B/xenial-userland.v2.sh"; AVAIL="$D/xenial-package-availability.tsv"; DEC="$D/package-decisions.tsv"
FX="$HERE/fixtures/lineage-before-init-504b1dbb.txt"
sets() { bash "$S" list-packages "$1" | tr ' ' '\n' | sort; }
col() { awk -F'\t' -v c="$1" -v v="$2" -v o="$3" 'NR>1 && $c==v {print $o}' "$DEC" | sort -u; }
auth=$(sed -n '/^# MAIN LIST/{n;p}' "$FX" | tr ' ' '\n' | grep -v '^$' | sort)
expect_ok "P1 every package the script installs is a real Xenial amd64 package (recorded index data)" python3 "$B/check-xenial-packages.py" check "$AVAIL"
dups=$(bash "$S" list-packages all | tr ' ' '\n' | sort | uniq -d); [ -z "$dups" ] && ok "P2 no package listed twice across the sets" || bad "P2 duplicates: $dups"
miss=""; for n in $auth; do awk -F'\t' -v n="$n" 'NR>1 && $1==n{f=1} END{exit !f}' "$DEC" || miss="$miss $n"; done
[ -z "$miss" ] && ok "P3 every package of the authoritative main list ($(echo "$auth" | wc -l) names) has a decision row" || bad "P3 no decision for:$miss"
for n in $auth; do d=$(awk -F'\t' -v n="$n" '$1==n{print $4}' "$DEC"); case "$d" in install|install-renamed|unavailable-omitted|omitted-by-doc) ;; *) bad "P4 $n has decision '$d'";; esac; done; ok "P4 every authoritative package has an allowed decision (install, install-renamed, unavailable-omitted, omitted-by-doc)"
# the decisions table and the script must agree exactly
inst=$( { col 4 install 3; col 4 install-renamed 3; } | sort -u )
e=$(sets essential); [ "$e" = "$inst" ] && ok "P5 script 'essential' set == packages with decision install/install-renamed ($(echo "$e" | wc -l))" || bad "P5 differ: $(diff <(echo "$e") <(echo "$inst") | tr '\n' ' ')"
o=$(sets optional); od=$(col 4 optional 3); [ "$o" = "$od" ] && ok "P6 script 'optional' set == decision 'optional'" || bad "P6 differ"
# every decision that is not 'install' must name a reason; unavailable ones must really be absent from Xenial
nor=$(awk -F'\t' 'NR>1 && length($5)<10{print $1}' "$DEC"); [ -z "$nor" ] && ok "P7 every row has a reason" || bad "P7 no reason: $nor"
for n in $(col 4 unavailable-omitted 1); do awk -F'\t' -v n="$n" '$1==n && $5=="MISSING"{f=1} END{exit !f}' "$AVAIL" && ok "P8 '$n' is recorded as MISSING in Xenial" || bad "P8 '$n' is not recorded as missing"; done
for n in lib32readline-dev lib32readline-gplv2-dev libwxgtk2.8-dev lz4 xxd erofs-utils git-lfs python3-protobuf python-is-python2 yasm maven git-core lib32z-dev; do
  echo " $(bash "$S" list-packages all | tr '\n' ' ') " | grep -q " $n " && bad "P9 $n must not be installed by name" || ok "P9 $n is not installed by that name"; done
for n in openjdk-8-jdk python2.7 make lib32readline6-dev gcc-multilib g++-multilib libc6-dev-i386 lib32z1-dev lib32ncurses5-dev libncurses5 libncurses5-dev zip unzip git ccache liblz4-tool vim-common libwxgtk3.0-dev; do
  echo " $(sets essential | tr '\n' ' ') " | grep -q " $n " && ok "P10 essential set has $n" || bad "P10 essential set lacks $n"; done
grep -q 'INSTALL_OPTIONAL' "$S" && ok "P11 optional packages need INSTALL_OPTIONAL=1" || bad "P11"
grep -v '^ *#' "$S" | grep -Eq ':i386|add-architecture' && bad "P12 script references i386 multiarch" || ok "P12 no :i386 / add-architecture (lib32* are amd64 packages on Xenial)"
finish
