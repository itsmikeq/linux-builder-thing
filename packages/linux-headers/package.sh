# Linux UAPI headers for userspace (installed into the musl sysroot).
# These are *upstream* headers; the vendor kernel source is unavailable.
# UAPI is backward compatible; programs must still runtime-check syscalls.
pkg_name=linux-headers
pkg_version=6.18.63
pkg_stage=0
pkg_source_url="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${pkg_version}.tar.xz"
pkg_verify="gpg-sums:kernel-autosigner.asc:https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc"
pkg_sha256=81764a545072d160748beff4d9de2e7d95aa9f16e8261110288f067a2cc61d71
pkg_build_tools="make sh sed cc find cp"
pkg_build_deps=""
pkg_runtime_deps=""
pkg_provides_files="usr/include/linux/version.h usr/include/asm/unistd.h"
pkg_outputs="sysroot/usr/include/linux/version.h"
pkg_host_script="scripts/host/stage0/linux-headers.sh"
