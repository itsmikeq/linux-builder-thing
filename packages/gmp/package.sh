pkg_name=gmp
pkg_version=6.3.0
pkg_stage=2
pkg_source_url="https://ftp.gnu.org/gnu/gmp/gmp-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
pkg_build_tools="sh cc make sed grep awk m4 ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides=""
pkg_provides_files="lib/libgmp.a include/gmp.h"
pkg_outputs="lib/libgmp.a include/gmp.h"
pkg_configure_opts="--disable-shared --enable-static --enable-cxx=no"
pkg_check_cmd="make check"
# Not needed: generated files ship in the release tarball / used only by tests or optional features.
pkg_optional_tools="lex yacc"
