#!/bin/bash
# Offline test (no root, no network) of relax_java_tls on mock java.security files written like OpenJDK 8u292's.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/lib.sh"; set +e; . "$HERE/../xenial-userland.v2.sh"; set +e
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mk() { cat > "$1" <<'X'
# mock java.security (8u292 layout)
security.provider.1=sun.security.provider.Sun
jdk.certpath.disabledAlgorithms=MD2, MD5, SHA1 jdkCA & usage TLSServer, \
    RSA keySize < 1024, DSA keySize < 1024, EC keySize < 224
jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1, RC4, DES, MD5withRSA, \
    DH keySize < 1024, EC keySize < 224, 3DES_EDE_CBC, anon, NULL, \
    include jdk.disabled.namedCurves
jdk.tls.legacyAlgorithms=NULL, anon, RC4, DES, 3DES_EDE_CBC
X
}
F="$T/a/java.security"; mkdir "$T/a"; mk "$F"; chmod 640 "$F"
check "J1 tokens before: TLSv1 and TLSv1.1 are listed" bash -c ". '$HERE/../xenial-userland.v2.sh'; java_tls_disabled_tokens '$F' | grep -qx TLSv1"
relax_java_tls "$F" >/dev/null 2>&1; rc=$?
[ $rc = 0 ] && ok "J2 relax_java_tls succeeds" || bad "J2 rc=$rc"
tok=$(java_tls_disabled_tokens "$F" | tr '\n' '|')
[ "$tok" = "SSLv3|RC4|DES|MD5withRSA|DH keySize < 1024|EC keySize < 224|3DES_EDE_CBC|anon|NULL|include jdk.disabled.namedCurves|" ] && ok "J3 exactly TLSv1 and TLSv1.1 removed; every other disabled algorithm kept ($tok)" || bad "J3 tokens: $tok"
[ "$(grep -c TLSv1 "$F")" = 0 ] && grep -q 'usage TLSServer' "$F" && ok "J4 unrelated lines untouched (certpath TLSServer text, legacyAlgorithms)" || bad "J4"
grep -q '^jdk.tls.legacyAlgorithms=NULL, anon, RC4, DES, 3DES_EDE_CBC$' "$F" && ok "J5 legacyAlgorithms line identical" || bad "J5"
[ -f "$F.orig-xenial-userland" ] && grep -q 'TLSv1, TLSv1.1' "$F.orig-xenial-userland" && ok "J6 original kept as .orig-xenial-userland" || bad "J6"
[ "$(stat -c %a "$F")" = 640 ] && ok "J7 file mode preserved" || bad "J7 mode $(stat -c %a "$F")"
relax_java_tls "$F" >/dev/null 2>&1 && ok "J8 idempotent (second run succeeds)" || bad "J8"
grep -q 'TLSv1, TLSv1.1' "$F.orig-xenial-userland" && ok "J9 backup not overwritten by the second run" || bad "J9"
mkdir "$T/b"; G="$T/b/java.security"; printf 'jdk.tls.disabledAlgorithms=SSLv3, RC4, \\\n    TLSv1, TLSv1.1, \\\n    anon\n' > "$G"
relax_java_tls "$G" >/dev/null 2>&1 && [ "$(java_tls_disabled_tokens "$G" | tr '\n' '|')" = "SSLv3|RC4|anon|" ] && ok "J10 tokens on a continuation line are removed too" || bad "J10 $(java_tls_disabled_tokens "$G" | tr '\n' '|')"
mkdir "$T/c"; H="$T/c/java.security"; printf 'jdk.tls.disabledAlgorithms=SSLv3, RC4, TLSv1.1\n' > "$H"
relax_java_tls "$H" >/dev/null 2>&1 && bad "J11 a token with no trailing comma must make the function FAIL CLOSED" || ok "J11 unrecognised layout (token last, no comma) fails closed instead of claiming success"
mkdir "$T/d"; printf 'security.provider.1=x\n' > "$T/d/java.security"
relax_java_tls "$T/d/java.security" >/dev/null 2>&1 && bad "J12" || ok "J12 file without the property is refused"
ln -s "$F" "$T/link.security"; relax_java_tls "$T/link.security" >/dev/null 2>&1 && bad "J13 symlink must be refused" || ok "J13 a symlink is refused (never followed)"
relax_java_tls "$T/missing" >/dev/null 2>&1 && bad "J14" || ok "J14 missing file refused"
finish
