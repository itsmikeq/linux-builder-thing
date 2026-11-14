# Status

What has been **run and verified**, and what has **not**, as of the last QEMU run.
Everything below was run in QEMU `virt` (TCG, `-cpu` restricted to RV64GC, no network)
booting a stand-in "vendor" OS (upstream 6.18.63 kernel + an initramfs whose only userland
is a shell). Nothing has run on real vendor hardware yet.

## Verified

| Area | Evidence |
|---|---|
| Source pinning | 27 sources: 25 verified by upstream GPG signatures (GNU keyring, LLVM release keys, musl, kernel.org autosigner, busybox), 2 TOFU (xz, flex). SHA-256 enforced on host and target. |
| Dependency resolution | `rbs.py resolve`: 35 packages, 0 cycles, 0 unresolved, 0 warnings, 0 errors. Static analysis + configure probes cross-checked against metadata. |
| Stage 0 (prep host) | Pinned clang/lld 21.1.8 built from source; static riscv64 clang, clang++, lld, llvm-{ar,nm,objcopy,objdump,readelf,strip,...}, musl 1.2.5, libc++/libc++abi/libunwind, compiler-rt, busybox 1.37.0. `tests/host/check-bundle.sh`: all 20 ELF files RISC-V and static (no PT_INTERP/DT_NEEDED). |
| Offline bundle | `output/bundle/{busybox,rbs-bundle.tar}` (≈753 MB, deterministic tar). Unpacked in the guest with only the transferred `./busybox`. |
| Selftest in guest | `uname -m` = riscv64; clang compiles, links and runs C (pthreads, libm) and C++ (libc++, exceptions via libunwind); llvm-ar + lld link; integrated assembler; outputs static RISC-V. |
| Kernel probe in guest | All required syscalls present (openat, clone, execve, wait4, pipe2, getdents64, mmap, futex, riscv_flush_icache); HWCAP = imafdc. |
| **Stage 1 native builds** | All 15 packages built natively in the guest by the bootstrap clang: make 4.4.1 (via `build.sh`, no prior make), bash 5.2.37, coreutils 9.5, diffutils 3.10, findutils 4.10.0, gawk 5.3.2, grep 3.11, gzip 1.13, m4 1.4.19, bison 3.8.2, flex 2.6.4, patch 2.7.6, sed 4.9, tar 1.35, xz 5.6.4. Each passed its `pkg_validate` and the static-RISC-V output check; provenance recorded per package. |
| Hermeticity (Stage 1) | No vendor tools on PATH (`env -i`, PATH inside the bundle). Vendor-shell audit: **no build-system use of `/bin/sh`**; the only uses were 6 libc `system()` calls from gnulib configure test programs (allowed, see `DESIGN.md`). |
| Resume/durability | A container restart mid-run was survived: finished packages kept their stamps (`sync` after each stamp, `cache=writeback`), and the run resumed with `RESUME=1`. |

Fixes found by running natively (all committed): clang 21 miscompiles busybox's
const `ptr_to_globals` (`BB_GLOBAL_CONST=''`); libc++abi `__cxa_thread_atexit_impl`
false positive from non-linking CMake checks; make's configure needs
`--disable-dependency-tracking`; bash termcap needs `<unistd.h>` for clang ≥ 16; gawk
configure post-processes a Makefile it never generated; busybox `patch` has no `-d`;
shebangs, make's default shell and autoconf's conftest `SHELL = /bin/sh` pointed at the
vendor shell; LLVM embedded the git repo URL/hash in `clang --version`.

## Not yet verified

* **Stage 2** (linux-uapi, musl, binutils, gmp, mpfr, mpc, GCC built by clang): metadata
  and build functions written, **never run**.
* **Stage 3** (GCC 3-stage self-bootstrap + compare, binutils/musl rebuilt by GCC):
  **never run**. The resolver enforces that no stage-3 package takes a clang/LLVM tool.
* **Stage 4** (upstream kernel built natively by GCC, busybox rootfs): **never run**;
  the QEMU kernel used so far was cross-built on the prep host as a stand-in.
* Bit-for-bit reproducibility of the bundle across hosts: inputs are pinned and the tar
  is deterministic, but two independent Stage 0 builds have not been compared.
* Real vendor hardware and vendor kernel: untested. See `KERNEL-COMPAT.md`.

## Continue from here

On the prep host (from a checkout with `sources/` and `output/` built):

```bash
bash tests/run-qemu-tests.sh smoke
```
```bash
bash tests/run-qemu-tests.sh stage1
```
```bash
RESUME=1 bash tests/run-qemu-tests.sh stage2
```
```bash
bash tests/ensure-stage-running.sh stage2      # resume after an interruption
```

Timings under TCG emulation on 4 host cores: Stage 0 ≈ 2.5 h (dominated by the two LLVM
builds); Stage 1 ≈ 2 h. Stage 2 (GCC) is expected to take several hours.
