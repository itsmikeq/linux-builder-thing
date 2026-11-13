#!/usr/bin/env bash
# PREP HOST (stage 0a): pinned *native* x86_64 clang/lld 21.1.8 built from the
# verified llvm-project tarball with the host distribution compiler. All later
# cross builds use this compiler, so the RISC-V toolchain does not depend on the
# host distro's LLVM version. Its tablegen binaries are reused by llvm.sh.
. "$(dirname "$0")/../common.sh"
done_p host-llvm && { msg "host-llvm already done"; exit 0; }
src=$(srcdir llvm-bootstrap)
B=$S0/host-llvm-build
msg "host clang/lld $LLVM_VER (native, targets X86;RISCV)"
{
cmake -G Ninja -S "$src/llvm" -B "$B" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=${BOOT_HOST_CC:-clang-18} -DCMAKE_CXX_COMPILER=${BOOT_HOST_CXX:-clang++-18} \
  -DLLVM_USE_LINKER=lld -DCMAKE_INSTALL_PREFIX="$S0/host-llvm" \
  -DLLVM_TARGETS_TO_BUILD="X86;RISCV" -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_TESTS=OFF -DCLANG_ENABLE_ARCMT=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
  -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_PARALLEL_LINK_JOBS=2 \
  -DLLVM_INSTALL_BINUTILS_SYMLINKS=OFF -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON &&
ninja -C "$B" -j"$JOBS" install &&
# tablegens for cross builds
ninja -C "$B" -j"$JOBS" llvm-tblgen clang-tblgen llvm-min-tblgen
} >"$LOGDIR/host-llvm.log" 2>&1 || die "host llvm failed; see $LOGDIR/host-llvm.log"
"$S0/host-llvm/bin/clang" --version | head -1
stamp host-llvm
