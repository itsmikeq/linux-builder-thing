# Stage 4: upstream Linux kernel compiled NATIVELY by the self-hosted GCC.
# This produces an upstream kernel for QEMU 'virt' (defconfig). It does NOT
# replace the vendor kernel: vendor drivers / out-of-tree modifications are not
# available, and a device tree alone cannot supply missing drivers. Keep booting
# the vendor kernel on hardware until each peripheral is verified upstream.
pkg_name=linux-kernel
pkg_version=6.18.63
pkg_stage=4
pkg_toolchain=gcc
pkg_source_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${pkg_version}.tar.xz"
pkg_verify="gpg-sums:kernel-autosigner.asc:https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc"
pkg_sha256=81764a545072d160748beff4d9de2e7d95aa9f16e8261110288f067a2cc61d71
pkg_build_tools="make sh sed grep awk cc ld as ar nm objcopy objdump strip flex bison bc find xargs cmp diff tar gzip"
pkg_build_deps="gcc-final binutils-final flex bison"
pkg_optional_tools="perl python3 openssl pahole cpio rsync zstd lz4 lzop"
pkg_outputs="boot/Image boot/config"
pkg_in_tree=1
# KCONFIG: defconfig (QEMU virt). Override with KERNEL_CONFIG=/path/to/.config.
pkg_configure() {
  if [ -n "${KERNEL_CONFIG:-}" ]; then cp "$KERNEL_CONFIG" .config; make SHELL="$CONFIG_SHELL" ARCH=riscv olddefconfig
  else make SHELL="$CONFIG_SHELL" ARCH=riscv defconfig
    ./scripts/config -d MODULES -d DEBUG_INFO -e DEBUG_INFO_NONE -d MODULE_SIG -d IKHEADERS -d BPF_JIT
    make SHELL="$CONFIG_SHELL" ARCH=riscv olddefconfig
  fi
}
pkg_build() {
  make SHELL="$CONFIG_SHELL" ARCH=riscv HOSTCC=gcc CC=gcc LD=ld.bfd -j"$JOBS" \
    KBUILD_BUILD_TIMESTAMP="1970-01-01" KBUILD_BUILD_USER=rbs KBUILD_BUILD_HOST=rbs Image
}
pkg_install() { mkdir -p "$DESTDIR$PREFIX/boot"; cp arch/riscv/boot/Image "$DESTDIR$PREFIX/boot/Image"; cp .config "$DESTDIR$PREFIX/boot/config"; }
pkg_validate() { [ "$(od -An -c -j 56 -N 4 arch/riscv/boot/Image | tr -d ' ')" = "RSC\\005" ]; }
