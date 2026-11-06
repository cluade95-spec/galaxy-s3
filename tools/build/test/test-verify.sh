#!/bin/bash
# Offline tests of the authenticity chain in xenial-userland.v2.sh. No root, no network, no Ubuntu image download.
# Uses (a) the real SHA256SUMS + SHA256SUMS.gpg for ubuntu-base 16.04.6 (public, 1.5 KB, in fixtures/) and the host's ubuntu-keyring,
# and (b) throw-away keys generated in a temporary GNUPGHOME.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/lib.sh"
set +e; . "$HERE/../xenial-userland.v2.sh"; set +e   # source the library (main does not run when sourced)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
FX="$HERE/fixtures"; KR=$KEYRING_FILE; FPR=$UBUNTU_CDIMAGE_KEY_FPR

echo "## A. real Ubuntu files"
expect_ok   "A1 real signature verifies with the pinned CD-image key"            verify_signed_sums "$KR" "$FPR" "$FX/SHA256SUMS" "$FX/SHA256SUMS.gpg"
expect_ok   "A2 signed list has the tarball exactly once with the pinned hash"    sums_line_ok "$FX/SHA256SUMS" "$TAR" "$TAR_SHA256"
expect_fail "A3 wrong pinned hash is rejected"                                   sums_line_ok "$FX/SHA256SUMS" "$TAR" "0000000000000000000000000000000000000000000000000000000000000000"
expect_fail "A4 unknown file name is rejected"                                   sums_line_ok "$FX/SHA256SUMS" "no-such.tar.gz" "$TAR_SHA256"
sed 's/9c160b52/9c160b53/' "$FX/SHA256SUMS" > "$T/S1"
expect_fail "A5 SHA256SUMS altered after signing -> signature fails"             verify_signed_sums "$KR" "$FPR" "$T/S1" "$FX/SHA256SUMS.gpg"
printf '%s' "$(cat "$FX/SHA256SUMS.gpg")" | head -c 300 > "$T/G1"
expect_fail "A6 truncated signature fails"                                       verify_signed_sums "$KR" "$FPR" "$FX/SHA256SUMS" "$T/G1"
expect_fail "A7 missing signature file fails closed"                             verify_signed_sums "$KR" "$FPR" "$FX/SHA256SUMS" "$T/none.gpg"
expect_fail "A8 empty signature file fails closed"                               verify_signed_sums "$KR" "$FPR" "$FX/SHA256SUMS" /dev/null
expect_fail "A9 a DIFFERENT genuine Ubuntu key (2018 archive key) is not accepted for this signature" verify_signed_sums "$KR" F6ECB3762474EDA9D21B7022871920D1991BC93C "$FX/SHA256SUMS" "$FX/SHA256SUMS.gpg"
expect_fail "A10 pinned fingerprint absent from keyring fails"                   verify_signed_sums "$KR" 0123456789ABCDEF0123456789ABCDEF01234567 "$FX/SHA256SUMS" "$FX/SHA256SUMS.gpg"
expect_fail "A11 empty keyring fails"                                            verify_signed_sums /dev/null "$FPR" "$FX/SHA256SUMS" "$FX/SHA256SUMS.gpg"
expect_fail "A12 short fingerprint (key id) is refused"                          verify_signed_sums "$KR" D94AA3F0EFE21092 "$FX/SHA256SUMS" "$FX/SHA256SUMS.gpg"
expect_fail "A13 lower-case fingerprint is refused (exact match only)"           verify_signed_sums "$KR" "$(echo $FPR | tr A-F a-f)" "$FX/SHA256SUMS" "$FX/SHA256SUMS.gpg"
expect_ok   "A14 host keyring is the one ubuntu-keyring installed (provenance)"  check_keyring_provenance "$KR"
echo "x" > "$T/fake.gpg"; expect_fail "A15 a file not owned by ubuntu-keyring is refused (provenance)" check_keyring_provenance "$T/fake.gpg"
( PATH=/nonexistent; verify_signed_sums "$KR" "$FPR" "$FX/SHA256SUMS" "$FX/SHA256SUMS.gpg" ) >/dev/null 2>&1 && bad "A16 no gpg binary -> must fail" || ok "A16 no gpg binary fails closed"

echo "## B. synthetic keys (key substitution, impostor, expired key)"
export GNUPGHOME="$T/gh"; mkdir -m700 "$GNUPGHOME"
gk() { gpg --batch --quiet --passphrase '' --quick-generate-key "$1" ed25519 sign "${2:-0}" 2>/dev/null; gpg --batch --with-colons --fingerprint "$1" 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}'; }
FA=$(gk "good <good@test>"); FB=$(gk "impostor <imp@test>")
echo "payload" > "$T/p"
gpg --batch --yes --quiet --local-user "$FA" --output "$T/p.good.sig"  --detach-sign "$T/p"
gpg --batch --yes --quiet --local-user "$FB" --output "$T/p.imp.sig"   --detach-sign "$T/p"
gpg --batch --quiet --export "$FA" "$FB" > "$T/both.gpg"
unset GNUPGHOME
[ -n "$FA" ] && [ -n "$FB" ] && ok "B0 generated two test keys" || bad "B0 key generation failed"
expect_ok   "B1 genuine signature by pinned test key verifies (keyring also holds the impostor key)" verify_signed_sums "$T/both.gpg" "$FA" "$T/p" "$T/p.good.sig"
expect_fail "B2 impostor signature rejected although its key is in the same keyring"                 verify_signed_sums "$T/both.gpg" "$FA" "$T/p" "$T/p.imp.sig"
echo "tampered" > "$T/p2"; expect_fail "B3 payload changed after signing"                         verify_signed_sums "$T/both.gpg" "$FA" "$T/p2" "$T/p.good.sig"
export GNUPGHOME="$T/gh2"; mkdir -m700 "$GNUPGHOME"
gpg --batch --quiet --passphrase '' --faked-system-time 20200101T000000 --quick-generate-key "old <old@test>" ed25519 sign 1d 2>/dev/null
FE=$(gpg --batch --with-colons --fingerprint old 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}')
gpg --batch --yes --quiet --faked-system-time 20200101T120000 --local-user "$FE" --output "$T/p.exp.sig" --detach-sign "$T/p" 2>/dev/null
gpg --batch --quiet --export "$FE" > "$T/exp.gpg"; unset GNUPGHOME
expect_fail "B4 signature by a key that has expired is rejected"                                      verify_signed_sums "$T/exp.gpg" "$FE" "$T/p" "$T/p.exp.sig"

echo "## C. tarball content checks (crafted tarballs)"
mkdir -p "$T/t1/dev" "$T/t1/etc"; echo a > "$T/t1/etc/a"; tar -C "$T/t1" -czf "$T/ok.tgz" .
expect_ok   "C1 ordinary tarball accepted"                                                           tar_listing_safe "$T/ok.tgz"
tar -C "$T" --transform 's,^t1/etc/a,/etc/evil,' -czf "$T/abs.tgz" t1/etc/a 2>/dev/null
expect_fail "C2 absolute path rejected"                                                              tar_listing_safe "$T/abs.tgz"
tar -C "$T/t1" --transform 's,^etc/a,../escape,' -czf "$T/dd.tgz" etc/a 2>/dev/null
expect_fail "C3 '..' path rejected"                                                                  tar_listing_safe "$T/dd.tgz"
echo junk > "$T/junk.tgz"; expect_fail "C4 non-tar rejected"                                         tar_listing_safe "$T/junk.tgz"
RT="$(ls -d /tmp/claude-0/*/*/scratchpad/ub16/ubuntu-base-16.04.6-base-amd64.tar.gz 2>/dev/null | head -1)"
[ -f "$RT" ] && expect_ok "C5 the real ubuntu-base tarball already on this machine passes (79 device nodes, all under dev/)" tar_listing_safe "$RT" || echo "[SKIP] C5 real tarball not present"
finish
