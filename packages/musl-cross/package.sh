# musl libc for the bootstrap sysroot, cross-compiled on the prep host with clang.
pkg_name=musl-cross
pkg_version=1.2.5
pkg_stage=0
pkg_source_url="https://musl.libc.org/releases/musl-${pkg_version}.tar.gz"
pkg_sig_url="${pkg_source_url}.asc"
pkg_verify="gpg-detached:musl.pub"
pkg_sha256=a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4
pkg_build_tools="make sh sed cc ar ranlib"
pkg_build_deps="musl-headers linux-headers compiler-rt-builtins"
pkg_outputs="sysroot/usr/lib/libc.a sysroot/usr/lib/crt1.o"
pkg_host_script="scripts/host/stage0/musl.sh"
