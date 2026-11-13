#!/usr/bin/env bash
# PREP HOST: install upstream Linux UAPI headers into the riscv64 sysroot.
. "$(dirname "$0")/../common.sh"
done_p linux-headers && { msg "linux-headers already done"; exit 0; }
src=$(srcdir linux-headers)
msg "linux headers_install ARCH=riscv"
rm -rf "$S0/linux-hdr"
# 'headers_install' requires rsync; 'headers' + cp avoids that undeclared tool.
make -C "$src" O="$S0/linux-hdr" ARCH=riscv HOSTCC=gcc headers >"$LOGDIR/linux-headers.log" 2>&1
find "$S0/linux-hdr/usr/include" -name '.*' -type f -delete
cp -a "$S0/linux-hdr/usr/include/." "$SYSROOT/usr/include/"
test -f "$SYSROOT/usr/include/linux/version.h"
stamp linux-headers
