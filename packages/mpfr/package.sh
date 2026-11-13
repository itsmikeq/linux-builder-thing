pkg_name=mpfr
pkg_version=4.2.2
pkg_stage=2
pkg_source_url="https://ftp.gnu.org/gnu/mpfr/mpfr-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap gmp"
pkg_runtime_deps=""
pkg_provides=""
pkg_provides_files="lib/libmpfr.a include/mpfr.h"
pkg_outputs="lib/libmpfr.a"
pkg_configure_opts="--disable-shared --enable-static --with-gmp=$PREFIX"
