#!/usr/bin/env bash
# PREP HOST: cross-compile a STATICALLY LINKED riscv64 clang/clang++/lld + LLVM
# binutils replacements, linked against musl + libc++ + libunwind + compiler-rt.
# Output: output/toolchain (relocatable: bin/, lib/clang/21/, sysroot/).
# Installed with the real prefix (prefix "/" makes GNUInstallDirs use /usr/bin) and
# no RPATH handling (static executables have no RPATH to rewrite).
. "$(dirname "$0")/../common.sh"
done_p llvm-bootstrap && { msg "llvm already done"; exit 0; }
[ -x "$HL/clang" ] || die "pinned host clang missing; run host-llvm.sh first"
setup_xres
src=$(srcdir llvm-bootstrap)
B=$S0/llvm-rv64-build
NT=$S0/host-llvm-build/bin
COMPONENTS="clang;clang-resource-headers;lld;llvm-ar;llvm-ranlib;llvm-nm;llvm-objcopy;llvm-objdump;llvm-strip;llvm-readelf;llvm-readobj;llvm-size;llvm-strings;llvm-addr2line;llvm-symbolizer;llvm-cxxfilt"
msg "cross LLVM $LLVM_VER for $TARGET (static)"
XF="$ARCHFLAGS -resource-dir=$XRES -ffile-prefix-map=$src=/usr/src/llvm-project"
{
cmake -G Ninja -S "$src/llvm" -B "$B" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_C_COMPILER=$HOST_CC -DCMAKE_CXX_COMPILER=$HOST_CXX -DCMAKE_ASM_COMPILER=$HOST_CC \
  -DCMAKE_AR=$HOST_AR -DCMAKE_RANLIB=$HOST_RANLIB -DCMAKE_NM=$HOST_NM \
  -DCMAKE_C_COMPILER_TARGET=$TARGET -DCMAKE_CXX_COMPILER_TARGET=$TARGET -DCMAKE_ASM_COMPILER_TARGET=$TARGET \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_C_FLAGS="$XF" -DCMAKE_CXX_FLAGS="$XF -stdlib=libc++" \
  -DCMAKE_EXE_LINKER_FLAGS="-static -fuse-ld=lld --rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCMAKE_INSTALL_PREFIX="$TC" -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON \
  -DLLVM_HOST_TRIPLE=$TARGET -DLLVM_DEFAULT_TARGET_TRIPLE=$TARGET \
  -DLLVM_TARGETS_TO_BUILD=RISCV -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_NATIVE_TOOL_DIR="$NT" -DLLVM_TABLEGEN="$NT/llvm-tblgen" -DCLANG_TABLEGEN="$NT/clang-tblgen" \
  -DLLVM_ENABLE_LIBCXX=ON -DLLVM_STATIC_LINK_CXX_STDLIB=ON -DLLVM_BUILD_STATIC=ON -DLLVM_ENABLE_PIC=OFF \
  -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_ENABLE_BACKTRACES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_INCLUDE_UTILS=OFF -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF \
  -DCLANG_ENABLE_ARCMT=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF -DCLANG_PLUGIN_SUPPORT=OFF \
  -DCLANG_DEFAULT_LINKER=lld -DCLANG_DEFAULT_RTLIB=compiler-rt -DCLANG_DEFAULT_UNWINDLIB=libunwind \
  -DCLANG_DEFAULT_CXX_STDLIB=libc++ -DCLANG_DEFAULT_OBJCOPY=llvm-objcopy \
  -DLLVM_INSTALL_BINUTILS_SYMLINKS=ON -DLLVM_DISTRIBUTION_COMPONENTS="$COMPONENTS" \
  -DLLVM_PARALLEL_LINK_JOBS=2 -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON &&
ninja -C "$B" -j"$JOBS" distribution &&
ninja -C "$B" install-distribution
} >"$LOGDIR/llvm.log" 2>&1 || die "cross llvm failed; see $LOGDIR/llvm.log"

# Driver configuration: relocatable (paths relative to the binary via <CFGDIR>).
# -static: the vendor OS has no musl dynamic loader, and we must not need root to
# install one at /lib, so everything built by the bootstrap compiler is static.
cat > "$TC/bin/$TARGET.cfg" <<CFG
--sysroot=<CFGDIR>/../sysroot
-march=rv64gc
-mabi=lp64d
-static
-Wno-unused-command-line-argument
CFG
cd "$TC/bin"
for l in cc:clang c++:clang++ cpp:clang-cpp ld:ld.lld; do ln -sf "${l#*:}" "${l%%:*}"; done
[ -e clang-cpp ] || ln -sf clang clang-cpp
bash "$RBS_ROOT/scripts/host/stage0/llvm-postcheck.sh"
stamp llvm-bootstrap
