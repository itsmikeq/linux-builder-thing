# Kernel / syscall assumptions

We don't have the vendor kernel source or hardware, so **nothing below is assumed to be
true of the vendor kernel**. `bootstrap.sh probe-kernel` measures it on the device
(`logs/kernel-probe.txt`) before any build.

Hard requirements (the probe fails if any are missing):
* riscv64 Linux with RV64GC userspace: `AT_HWCAP` must contain `imafdc`. The bootstrap code is
  compiled `-march=rv64gc -mabi=lp64d` and uses no V/B/Zb* extensions.
* syscalls: openat, clone, execve, wait4, pipe2, getdents64, mmap, futex,
  `riscv_flush_icache` (used by `__clear_cache`).
* `/proc` mounted (nproc, meminfo, cpuinfo) and `/dev/null`, plus a writable filesystem with
  room for the bundle (~1 GB) and builds (~6 GB), supporting symlinks and the exec bit.
* ELF static executables (`CONFIG_BINFMT_ELF`) and `#!` scripts (`CONFIG_BINFMT_SCRIPT`).

Optional and measured (musl or the tools fall back): getrandom, statx, copy_file_range,
renameat2, faccessat2, memfd_create, close_range, openat2, pidfd_open, riscv_hwprobe.

musl 1.2.5 itself supports riscv64 kernels from the port's introduction (Linux 4.15). In
practice the oldest kernel we'd expect to work is 4.15. This is **unverified**: QEMU tests
use a 6.18 kernel.

Upstream headers (6.18) are used for userspace. UAPI is backward compatible, but a header
that *declares* a syscall doesn't mean the vendor kernel implements it.
