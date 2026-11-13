#!/usr/bin/env bash
# PREP HOST TEST: static properties of the bundle (no execution).
#  - every ELF file is RISC-V; every ELF executable is static (no PT_INTERP / DT_NEEDED)
#  - no host (x86-64) binaries leaked into the bundle
#  - all sources listed in manifest.order are present with correct sha256
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BD=$ROOT/output/bundle
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
tar -xf "$BD/rbs-bundle.tar" -C "$T"
fail=0 n=0
while IFS= read -r -d '' f; do
  head -c4 "$f" | grep -q $'\x7fELF' || continue
  n=$((n+1))
  m=$(readelf -h "$f" 2>/dev/null | awk -F: '/Machine/{gsub(/^ +/,"",$2);print $2}')
  [ "$m" = "RISC-V" ] || { echo "FAIL non-RISC-V ELF: ${f#$T/} ($m)"; fail=1; continue; }
  t=$(readelf -h "$f" | awk -F: '/Type/{print $2}')
  case $t in *EXEC*|*DYN*)
    readelf -l "$f" | grep -q INTERP && { echo "FAIL dynamic (PT_INTERP): ${f#$T/}"; fail=1; }
    readelf -d "$f" 2>/dev/null | grep -q NEEDED && { echo "FAIL DT_NEEDED: ${f#$T/}"; fail=1; } ;;
  esac
done < <(find "$T" -type f -print0)
echo "checked $n ELF files"
grep -v '^#' "$T/rbs/manifest.order" | while read -r st name ver file sum; do
  echo "$sum  $T/rbs/sources/$file" | sha256sum -c --quiet - || { echo "FAIL source $file"; exit 1; }
done || fail=1
[ -x "$T/rbs/bootstrap/bin/busybox" ] || { echo "FAIL busybox not executable"; fail=1; }
[ $fail = 0 ] && echo "check-bundle: PASS" || { echo "check-bundle: FAIL"; exit 1; }
