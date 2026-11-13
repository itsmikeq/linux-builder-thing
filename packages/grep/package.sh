pkg_name=grep
pkg_version=3.11
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/grep/grep-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=1db2aedde89d0dea42b16d9528f894c8d15dae4e190b59aecc78f5a951276eab
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="grep egrep fgrep"
pkg_outputs="bin/grep"
pkg_configure_opts="--disable-nls --disable-perl-regexp"
pkg_validate() { echo hello | "$DESTDIR$PREFIX/bin/grep" -q 'h.l*o'; }
