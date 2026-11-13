pkg_name=mpc
pkg_version=1.3.1
pkg_stage=2
pkg_source_url="https://ftp.gnu.org/gnu/mpc/mpc-${pkg_version}.tar.gz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap gmp mpfr"
pkg_runtime_deps=""
pkg_provides=""
pkg_provides_files="lib/libmpc.a include/mpc.h"
pkg_outputs="lib/libmpc.a"
pkg_configure_opts="--disable-shared --enable-static --with-gmp=$PREFIX --with-mpfr=$PREFIX"
