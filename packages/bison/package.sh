pkg_name=bison
pkg_version=3.8.2
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/bison/bison-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2
pkg_build_tools="sh cc make sed grep awk m4 ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_provides="bison yacc"
pkg_outputs="bin/bison"
pkg_runtime_deps="m4"
pkg_configure_opts="--disable-nls"
pkg_optional_tools="perl makeinfo help2man flex lex yacc"
pkg_validate() { "$DESTDIR$PREFIX/bin/bison" --version | grep -q 'GNU Bison'; }
