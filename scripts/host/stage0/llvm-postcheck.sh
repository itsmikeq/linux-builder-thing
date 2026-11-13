#!/usr/bin/env bash
# PREP HOST: sanity-check the RISC-V toolchain *files* (no execution).
. "$(dirname "$0")/../common.sh"
rc=0
for f in clang lld llvm-ar llvm-nm llvm-objcopy llvm-strip; do
  p=$(readlink -f "$TC/bin/$f")
  d=$(file -b "$p")
  case $d in
    *"UCB RISC-V"*"statically linked"*) echo "ok   $f: $d" | cut -c1-110 ;;
    *) echo "FAIL $f: $d"; rc=1 ;;
  esac
  if readelf -l "$p" 2>/dev/null | grep -q INTERP; then echo "FAIL $f has PT_INTERP"; rc=1; fi
  if readelf -d "$p" 2>/dev/null | grep -q NEEDED; then echo "FAIL $f has DT_NEEDED"; rc=1; fi
done
exit $rc
