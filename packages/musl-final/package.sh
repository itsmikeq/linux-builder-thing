# musl libc built NATIVELY into the stage-3 GCC sysroot ($PREFIX/sysroot/usr).
# Static only: executables must not need /lib/ld-musl-riscv64.so.1 on the vendor OS.
pkg_name=musl-final
pkg_version=1.2.5
pkg_stage=3
pkg_toolchain=gcc   # stage 3+: built by GCC only; resolver forbids clang/LLVM providers
pkg_source_url="https://musl.libc.org/releases/musl-${pkg_version}.tar.gz"
pkg_sig_url="${pkg_source_url}.asc"
pkg_verify="gpg-detached:musl.pub"
pkg_sha256=a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4
pkg_build_tools="make sh sed cc ar ranlib"
pkg_build_deps="gcc linux-uapi-final binutils-final"
pkg_outputs="sysroot/usr/lib/libc.a sysroot/usr/lib/crt1.o sysroot/usr/include/stdio.h"
pkg_configure() {
  "$CONFIG_SHELL" "$SRC/configure" --prefix=/usr --target=riscv64-linux-musl --disable-shared 
}
pkg_install() { make SHELL="$CONFIG_SHELL" DESTDIR="$DESTDIR$SYSROOT" install; }
