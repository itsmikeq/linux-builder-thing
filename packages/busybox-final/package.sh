# Stage 4: busybox rebuilt natively by the self-hosted GCC for the minimal rootfs.
pkg_name=busybox-final
pkg_version=1.37.0
pkg_stage=4
pkg_toolchain=gcc
pkg_source_url="https://busybox.net/downloads/busybox-${pkg_version}.tar.bz2"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:busybox-vda.gpg"
pkg_sha256=3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4
pkg_build_tools="make sh sed grep awk cc ld ar strip"
pkg_build_deps="gcc-final binutils-final musl-final linux-uapi-final"
pkg_outputs="rootfs/bin/busybox"
pkg_in_tree=1
pkg_configure() {
  cp "$RBS/bootstrap/busybox.config" .config
  sed -i 's/^CONFIG_EXTRA_LDFLAGS=.*/CONFIG_EXTRA_LDFLAGS=""/' .config
  yes "" | make SHELL="$CONFIG_SHELL" oldconfig >/dev/null
}
pkg_build() { make SHELL="$CONFIG_SHELL" CC=gcc HOSTCC=gcc -j"$JOBS" KBUILD_BUILD_TIMESTAMP="1970-01-01"; }
pkg_install() {
  mkdir -p "$DESTDIR$PREFIX/rootfs/bin"; cp busybox "$DESTDIR$PREFIX/rootfs/bin/busybox"
}
pkg_validate() { [ "$(./busybox echo ok)" = ok ]; }
