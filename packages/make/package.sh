pkg_name=make
pkg_version=4.4.1
pkg_stage=1
pkg_source_url="https://ftp.gnu.org/gnu/make/make-${pkg_version}.tar.gz"
pkg_sig_url="${pkg_source_url}.sig"
pkg_verify="gpg-detached:gnu-keyring.gpg"
pkg_sha256=dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3
pkg_build_tools="sh cc sed grep ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_runtime_deps=""
pkg_provides="make gmake"
# Bootstrap cycle: make is needed to build make. Broken by upstream build.sh.
pkg_cycle_break="make"
pkg_outputs="bin/make"
pkg_configure_opts="--disable-nls --without-guile --disable-load"
pkg_build() { sh ./build.sh; }
pkg_install() { mkdir -p "$DESTDIR$PREFIX/bin"; cp make "$DESTDIR$PREFIX/bin/make"; ln -sf make "$DESTDIR$PREFIX/bin/gmake"; }
pkg_validate() { "$DESTDIR$PREFIX/bin/make" --version | head -1 | grep -q 'GNU Make 4.4.1'; }
# Not needed: generated files ship in the release tarball / used only by tests or optional features.
pkg_optional_tools="pkg-config"
