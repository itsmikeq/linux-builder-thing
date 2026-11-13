pkg_name=xz
pkg_version=5.6.4
pkg_stage=1
pkg_source_url="https://github.com/tukaani-project/xz/releases/download/v${pkg_version}/xz-${pkg_version}.tar.xz"
pkg_sig_url="${pkg_source_url}.sig"
# Lasse Collin's key is not obtainable from an allowed host here; pinned by
# SHA-256 on first fetch (TOFU). See docs/VERIFICATION.md.
pkg_verify="tofu"
pkg_sha256=829ccfe79d769748f7557e7a4429a64d06858e27e1e362e25d01ab7b931d9c95
pkg_build_tools="sh cc make sed grep awk ar ranlib install diff cmp xargs"
pkg_build_deps="llvm-bootstrap"
pkg_provides="xz unxz xzcat lzma"
pkg_outputs="bin/xz"
pkg_configure_opts="--disable-nls --disable-doc --disable-scripts --disable-shared"
pkg_validate() { [ "$(echo hi | "$DESTDIR$PREFIX/bin/xz" | "$DESTDIR$PREFIX/bin/xz" -d)" = hi ]; }
# AM_PROG_AS: only used for x86 CRC assembly; riscv uses C.
pkg_optional_tools="as"
