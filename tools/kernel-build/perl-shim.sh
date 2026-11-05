#!/bin/sh
# Build-environment shim, NOT a source change.
# Kernel 3.4.5's kernel/timeconst.pl contains `if (!defined(@val))`, which Perl >= 5.22
# rejects ("Can't use 'defined(@array)'"). The upstream fix is `if (!@val)` (identical meaning).
# Kbuild runs `$(PERL) kernel/timeconst.pl <HZ>`; passing PERL=<this script> lets us apply the
# one-line upstream fix to a temporary copy at run time. The source tree is never modified.
# Every other perl invocation passes straight through.
# Usage: make PERL=/path/to/perl-shim.sh ...
script="$1"
case "$script" in
  */timeconst.pl)
    tmp="${TMPDIR:-/tmp}/timeconst.shim.$$.pl"
    sed 's/!defined(@val)/!@val/' "$script" > "$tmp" || exit 1
    # Record exactly what was changed (to stderr, so it lands in the build log).
    diff "$script" "$tmp" >&2
    shift
    perl "$tmp" "$@"
    rc=$?
    rm -f "$tmp"
    exit $rc
    ;;
  *) exec perl "$@" ;;
esac
