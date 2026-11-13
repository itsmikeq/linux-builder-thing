#!/usr/bin/env bash
# PREP HOST: musl for riscv64. "headers" mode installs only headers (cycle break
# for compiler-rt); default mode builds static libc.a using our compiler-rt builtins.
. "$(dirname "$0")/../common.sh"
mode=${1:-full}
setup_xres
src=$(srcdir musl-cross)
if [ "$mode" = headers ]; then
  done_p musl-headers && exit 0
  msg "musl install-headers"
  make -C "$src" ARCH=riscv64 prefix=/usr DESTDIR="$SYSROOT" install-headers >"$LOGDIR/musl-headers.log" 2>&1
  stamp musl-headers; exit 0
fi
done_p musl-cross && { msg "musl already done"; exit 0; }
B=$S0/musl-build; rm -rf "$B"; mkdir -p "$B"; cd "$B"
BUILTINS=$XRES/lib/$TARGET/libclang_rt.builtins.a
[ -f "$BUILTINS" ] || die "compiler-rt builtins missing ($BUILTINS); run compiler-rt.sh"
msg "musl configure/build"
{
  CC="$HOST_CC $XCFLAGS" AR=$HOST_AR RANLIB=$HOST_RANLIB LIBCC="$BUILTINS" \
  CFLAGS="-O2 -ffile-prefix-map=$src=/usr/src/musl" \
    "$src/configure" --prefix=/usr --target=riscv64-linux-musl --disable-shared &&
  make -j"$JOBS" &&
  make DESTDIR="$SYSROOT" install
} >"$LOGDIR/musl.log" 2>&1 || die "musl failed; see $LOGDIR/musl.log"
test -f "$SYSROOT/usr/lib/libc.a"
stamp musl-cross
