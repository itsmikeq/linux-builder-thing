#!/usr/bin/env bash
# PREP HOST: static busybox for riscv64 (bootstrap shell + utilities + tar/xz/gzip).
. "$(dirname "$0")/../common.sh"
done_p busybox && { msg "busybox already done"; exit 0; }
setup_xres
src=$(srcdir busybox)
B=$S0/busybox-build; rm -rf "$B"; mkdir -p "$B"
CROSS=(CC="$HOST_CC $XCFLAGS $XLDFLAGS -Wno-unused-command-line-argument" LD=ld.lld AR=$HOST_AR NM=$HOST_NM STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump
       HOSTCC=gcc ARCH=riscv KBUILD_BUILD_TIMESTAMP="1970-01-01" KBUILD_BUILD_USER=rbs KBUILD_BUILD_HOST=rbs)
msg "busybox config"
{
make -C "$src" O="$B" "${CROSS[@]}" defconfig &&
cd "$B" &&
# Static, no PIE. 'tc' is disabled: it fails against Linux >= 6.8 UAPI (CBQ removed).
# BB_GLOBAL_CONST='': busybox declares ptr_to_globals 'const' and assigns it via a cast;
# clang 21 reuses the stale (NULL) value, e.g. awk segfaults writing to address 0x4.
# libbb.h documents this define as the switch for such toolchains.
sed -i -e 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' \
       -e 's/^CONFIG_TC=y/# CONFIG_TC is not set/' \
       -e 's/^CONFIG_FEATURE_TC_INGRESS=y/# CONFIG_FEATURE_TC_INGRESS is not set/' \
       -e 's/^CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' \
       -e 's/^CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' \
       -e 's/^CONFIG_PIE=y/# CONFIG_PIE is not set/' \
       -e "s/^CONFIG_EXTRA_CFLAGS=.*/CONFIG_EXTRA_CFLAGS=\"-DBB_GLOBAL_CONST=''\"/" .config &&
( set +o pipefail; yes "" | make "${CROSS[@]}" oldconfig >/dev/null ) &&   # yes(1) dies of SIGPIPE
msg "busybox build" &&
make "${CROSS[@]}" -j"$JOBS"
} >"$LOGDIR/busybox.log" 2>&1 || die "busybox failed; see $LOGDIR/busybox.log"
mkdir -p "$RBS_ROOT/output/bootstrap/bin"
cp "$B/busybox" "$RBS_ROOT/output/bootstrap/bin/busybox"
cp "$B/.config" "$RBS_ROOT/output/bootstrap/busybox.config"
file "$RBS_ROOT/output/bootstrap/bin/busybox"
stamp busybox
