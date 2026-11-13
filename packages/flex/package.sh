pkg_name=flex
pkg_version=2.6.4
pkg_stage=1
pkg_source_url="https://github.com/westes/flex/releases/download/v${pkg_version}/flex-${pkg_version}.tar.gz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="tofu"
pkg_sha256=e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995
# Bootstrap cycle flex->flex is broken by the pre-generated src/scan.c in the release tarball.
pkg_cycle_break="flex"
pkg_build_tools="sh cc make sed grep awk m4 ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps="m4"
pkg_provides="flex lex"
pkg_outputs="bin/flex"
pkg_optional_tools="bison help2man makeinfo lex yacc"
pkg_configure_opts="--disable-nls --disable-shared"
pkg_install() { make SHELL="$CONFIG_SHELL" DESTDIR="$DESTDIR" install; ln -sf flex "$DESTDIR$PREFIX/bin/lex"; }
pkg_validate() { "$DESTDIR$PREFIX/bin/flex" --version | grep -q 'flex 2.6.4'; }
