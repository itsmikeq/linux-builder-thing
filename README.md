# riscv-bootstrap

A reproducible bootstrap that starts from a minimal vendor RISC-V Linux (kernel + `sh`, no
development tools) and ends with a self-hosted native GCC toolchain, plus an upstream kernel
built on the device.

* Target: `riscv64-unknown-linux-musl`, RV64GC, LP64D, musl, static.
* Bootstrap compiler: static clang/lld 21.1.8, cross-built on a prep host.
* Final compiler: GCC 15.2.0 + binutils 2.45, built natively, then rebuilt by itself.

See `docs/DESIGN.md` (architecture), `docs/VERIFICATION.md` (source integrity),
`docs/KERNEL-COMPAT.md` (kernel/syscall assumptions) and `docs/STATUS.md` (what has and has
not been verified).

```
packages/<pkg>/package.sh   metadata (+ build functions) for every package, pinned + sha256
scripts/host/               PREP HOST ONLY (bash/Python): rbs.py, stage0/, qemu/, mkbundle.sh
scripts/target/             RISC-V ONLY (POSIX sh): bootstrap.sh, build-pkg.sh, lib.sh
tests/host/  tests/target/  tests/run-qemu-tests.sh
keys/fetch-keys.sh          fetches upstream signing keys (pinned trust anchors)
manifest.lock               resolved, locked dependency graph (JSON)
manifest.order              build order consumed by the target (plain text)
sources/ build/ output/ logs/ sysroot/   generated (git-ignored)
```

## Preparation host (x86_64 Linux with network)

Requirements: bash, python3, curl, gpgv, tar/xz/bzip2, cmake ≥ 3.20, ninja, a C/C++
compiler that can build LLVM (clang ≥ 15 or gcc ≥ 7), lld, make, flex, bison, bc,
e2fsprogs (`mke2fs`, `debugfs`), cpio, and `qemu-system-riscv64` + OpenSBI for tests.
About 25 GB disk.

```bash
keys/fetch-keys.sh                         # upstream signing keys (pinned sha256 + fingerprint)
```
```bash
python3 scripts/host/rbs.py fetch          # download + verify every pinned source (sha256)
```
```bash
python3 scripts/host/rbs.py analyze        # static build-system analysis
```
```bash
python3 scripts/host/rbs.py resolve        # -> manifest.lock / manifest.order (fails on errors)
```
```bash
JOBS=$(nproc) scripts/host/stage0/all.sh   # pinned host clang, then static riscv64 toolchain + busybox
```
```bash
scripts/host/mkbundle.sh                   # -> output/bundle/{busybox,rbs-bundle.tar,SHA256SUMS}
```

To bump a version: edit `pkg_version`, clear `pkg_sha256=`, then run
`python3 scripts/host/rbs.py pin <pkg>`. That verifies the upstream signature before
recording the hash. `rbs.py probe <pkg>` runs a traced configure to find tools the
metadata doesn't declare.

## On the RISC-V device (offline)

Copy `output/bundle/busybox` (keep the executable bit, e.g. `scp -p`) and
`output/bundle/rbs-bundle.tar` to a writable directory with about 8 GB free, then:

```bash
./busybox tar -xf rbs-bundle.tar
```
```bash
./busybox sh rbs/scripts/target/bootstrap.sh probe-kernel    # what does the vendor kernel support?
```
```bash
./busybox sh rbs/scripts/target/bootstrap.sh selftest        # clang compiles/links/runs C and C++
```
```bash
./busybox sh rbs/scripts/target/bootstrap.sh stage 1         # make, sed, awk, m4, coreutils, ...
```
```bash
./busybox sh rbs/scripts/target/bootstrap.sh stage 2         # binutils, gmp/mpfr/mpc, musl, GCC
```
```bash
./busybox sh rbs/scripts/target/bootstrap.sh stage 3         # GCC rebuilds itself (3-stage + compare)
```
```bash
./busybox sh rbs/scripts/target/bootstrap.sh stage 4         # upstream kernel + busybox, by GCC
```

Re-running a stage resumes: built packages are skipped. Other entry points:
`bootstrap.sh --only gmp stage 2`, `--rebuild gcc`, `--from binutils stage 2`, `-j N`,
`list`. Logs go to `rbs/logs/<pkg>.log`, provenance to `rbs/var/provenance/<pkg>`.

## Testing without hardware (QEMU)

```bash
scripts/host/qemu/build-test-kernel.sh && scripts/host/qemu/mkinitramfs.sh
```
```bash
tests/run-qemu-tests.sh smoke          # selftest + kernel probe in a simulated vendor OS, no network
```
```bash
tests/run-qemu-tests.sh stage1         # native stage 1 builds inside qemu-system-riscv64
```
```bash
RESUME=1 tests/run-qemu-tests.sh stage2
```

The QEMU guest's only userland is a stand-in "vendor" shell, and its `/bin/sh` is an
audit shim. If anything in the bootstrap falls back to vendor tools, the test fails.
