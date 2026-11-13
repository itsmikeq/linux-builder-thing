# Design

## Where things run

| Stage | Runs on | Built by | Installs to | Purpose |
|---|---|---|---|---|
| 0a | prep host (x86_64) | distro clang | `build/stage0/host-llvm` | pinned native clang/lld 21.1.8 (host compiler for cross builds) |
| 0  | prep host | pinned host clang | `output/toolchain`, `output/bootstrap` | static riscv64 clang/lld/LLVM tools, musl sysroot, libc++, busybox |
| 1  | **RISC-V** | bootstrap clang | `$RBS/tools` | make, m4, sed, gawk, grep, diff, find, coreutils, patch, tar, gzip, xz, bison, flex, bash |
| 2  | **RISC-V** | bootstrap clang | `$RBS/gcc-boot` (+`sysroot/`) | Linux UAPI, musl, binutils, GMP, MPFR, MPC, GCC (C, C++) |
| 3  | **RISC-V** | stage-2 GCC | `$RBS/native` (+`sysroot/`) | binutils, musl, GCC via 3-stage `make bootstrap` + compare |
| 4  | **RISC-V** | stage-3 GCC | `$RBS/native` | upstream kernel (QEMU virt), busybox for a rootfs |

The preparation host never builds a target-stage (≥1) package. Its own work (Stage 0) is
in `scripts/host/` (bash/Python). Target work is in `scripts/target/` (POSIX `sh`, run by
the bundled busybox).

## Stage 0: how the static bootstrap toolchain is made

1. **Pinned host compiler (0a).** libc++ 21 needs clang ≥ 19, so the distro clang (18)
   only builds a native clang/lld 21.1.8 from the verified tarball. Everything after uses
   that, which also makes the result independent of the host distro's LLVM.
2. **Linux UAPI headers** (`make headers`, *not* `headers_install`, which needs rsync)
   into `output/toolchain/sysroot/usr/include`.
3. **musl headers only.** That breaks the real cycle *compiler-rt needs libc headers ↔
   musl needs compiler-rt as LIBCC*. It's modelled as the separate package `musl-headers`.
4. **compiler-rt builtins + crtbegin/crtend** for `riscv64-unknown-linux-musl` (standalone
   CMake, `COMPILER_RT_DEFAULT_TARGET_ONLY`). It's installed both in a private resource dir
   for the host clang (`build/stage0/xresource`, so the host install is never touched) and
   in the final `toolchain/lib/clang/21/lib/riscv64-unknown-linux-musl/`.
5. **musl 1.2.5** static `libc.a`, with `LIBCC=` our builtins.
6. **libunwind, libc++abi, libc++** (static; the ABI library is merged into `libc++.a`).
7. **Cross LLVM**: clang + lld + llvm-{ar,nm,objcopy,objdump,strip,readelf,size,strings,
   addr2line,symbolizer,cxxfilt}. `LLVM_BUILD_STATIC=ON`, `LLVM_ENABLE_PIC=OFF`, linked with
   `-static -fuse-ld=lld --rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++`. It only
   builds the RISCV target, with no zlib/zstd/libxml2/terminfo. The host-built tablegens are
   reused through `LLVM_NATIVE_TOOL_DIR`. Defaults: lld, compiler-rt, libunwind, libc++,
   triple `riscv64-unknown-linux-musl`.
8. **Driver config** `toolchain/bin/riscv64-unknown-linux-musl.cfg`:
   `--sysroot=<CFGDIR>/../sysroot -march=rv64gc -mabi=lp64d -static`. `<CFGDIR>` makes the
   toolchain relocatable, so the bundle can be unpacked anywhere.
9. **busybox 1.37.0**, static. It's the bootstrap `sh`, the core utilities, and the
   `tar`/`xz`/`gzip`/`bzip2` used to unpack the sources.

## Why everything is static

The vendor OS has no musl dynamic loader, and installing `/lib/ld-musl-riscv64.so.1` needs
root and changes the vendor system. So every bootstrap binary is static: the clang config
and GCC's `--with-specs=%{!shared:%{!static-pie:-static}}` make static linking the default,
and `LDFLAGS=-static` is set in the build environment. Shared libraries can come back in
Stage 4, once we own the root filesystem.

## Hermeticity (no vendor tools)

`bootstrap.sh` re-execs itself with `env -i` and
`PATH=<stage prefixes>:<toolchain>/bin:<bundle>/bootstrap/bin`. No vendor directory is on
PATH. Configure scripts run as `$CONFIG_SHELL configure`, and make gets
`SHELL=$CONFIG_SHELL`. After extraction, `#!/bin/sh` (and `#!/usr/bin/env sh`) shebangs
and autoconf's hardcoded `SHELL = /bin/sh` conftest makefile are rewritten to the bundled
shell, with mtimes preserved so nothing is regenerated. GNU make is built with the bundled
shell as its default. `TMPDIR` and `HOME` point inside the bundle.

The QEMU test's `/bin/sh` is an audit shim that records each use and its parent program.
Any build-system use (scripts run by path, make recipes, hardcoded `SHELL=/bin/sh`) fails
the test. The one allowed use is libc `system()`/`popen()` from configure test programs:
POSIX and musl hardwire `/bin/sh` there, and the vendor OS providing a POSIX `sh` is a
stated baseline assumption. Those calls are counted and reported separately.

## Stamps, resume, rebuild

Every package builds in `build/<pkg>` from a fresh extraction, installs into
`staging/<pkg>` (DESTDIR), is validated (`pkg_validate` + expected outputs + "static
RISC-V" check), and is then merged into its stage prefix. The installed file list goes to
`var/files/<pkg>.files`, provenance to `var/provenance/<pkg>`, and a stamp
`var/stamps/<pkg>.done` (= `version sha256`) is written. Re-running a stage skips stamped
packages. `--only/--rebuild/--from` force rebuilds, and a rebuild first removes the files
the previous build installed.

## Resource limits (embedded hardware)

* `JOBS` defaults to `min(nproc, MemAvailable/1GiB)`.
* GCC: `--disable-lto --disable-libstdcxx-pch --disable-libsanitizer`, C/C++ only.
  Expect ≥ 2 GiB RAM + swap for `-j1` cc1plus builds, and about 6 GiB free disk for stage 3.
* Build trees are deleted after success (`KEEP_BUILD=1` keeps them).
* The bundle is an uncompressed tar of already-compressed sources. Unpacking it needs no
  decompressor and very little memory.

## Dependency resolution (prep host, `scripts/host/rbs.py`)

The metadata (`packages/*/package.sh`) is authoritative. It's checked against:
* **static analysis** (`rbs.py analyze`): `AC_PROG_*`/`AC_CHECK_PROG`/`AC_CHECK_LIB`/
  `PKG_CHECK_MODULES` in `configure.ac`, `find_package`/`find_program` in CMake, known tools in
  Makefile recipes, and script shebangs;
* **controlled probes** (`rbs.py probe PKG`): runs the package's real `configure` with
  every PATH executable replaced by a logging shim, and records what was *executed*.

`rbs.py resolve` turns tool requirements into provider packages (the lowest stage wins,
which is the minimal bootstrap). It refuses clang providers for `pkg_toolchain=gcc` packages,
detects cycles (Tarjan SCC) unless they're broken via `pkg_cycle_break` (make's
`build.sh`, flex's shipped `scan.c`) or a split package (`musl-headers`), flags
stage-order violations, and writes `manifest.lock` (JSON, including unresolved items and
warnings) and `manifest.order` (plain text for the target's `sh`). Findings that metadata
doesn't explain are reported, not guessed: e.g. analysis showed `rsync` hidden in
`headers_install`, and that `sed`'s configure runs `perl` (only used by its tests, so it's
declared optional).
