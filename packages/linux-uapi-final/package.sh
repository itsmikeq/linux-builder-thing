# Upstream Linux UAPI headers, installed NATIVELY into the stage-3 GCC sysroot.
# (Upstream headers; the vendor kernel source is unavailable. UAPI is backward
# compatible, but newer syscalls may be absent at runtime: see probe-kernel.)
pkg_name=linux-uapi-final
pkg_version=6.18.63
pkg_stage=3
pkg_toolchain=gcc   # stage 3+: built by GCC only; resolver forbids clang/LLVM providers
pkg_source_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${pkg_version}.tar.xz"
pkg_verify="gpg-sums:kernel-autosigner.asc:https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc"
pkg_sha256=81764a545072d160748beff4d9de2e7d95aa9f16e8261110288f067a2cc61d71
pkg_build_tools="make sh sed cc find cp"
pkg_build_deps="gcc make"
pkg_outputs="sysroot/usr/include/linux/version.h sysroot/usr/include/asm/unistd.h"
pkg_in_tree=1
pkg_configure() { :; }
pkg_build() { make SHELL="$CONFIG_SHELL" ARCH=riscv HOSTCC="$CC" headers; }
pkg_install() {
  find usr/include -name '.*' -type f -exec rm -f {} +
  mkdir -p "$DESTDIR$SYSROOT/usr"; cp -a usr/include "$DESTDIR$SYSROOT/usr/"
}
