pkg_name=bash
pkg_version=5.2.37
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/bash/bash-${pkg_version}.tar.gz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=9599b22ecd1d5787ad7d3b7bf0c59f312b3396d1e281175dd1f8a4014da621ff
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="bash"
pkg_outputs="bin/bash"
pkg_configure_opts="--without-bash-malloc --disable-nls --enable-static-link --without-curses"
pkg_optional_tools="bison yacc"
pkg_validate() { [ "$("$DESTDIR$PREFIX/bin/bash" -c 'a=(x y); echo ${a[1]}')" = y ]; }
