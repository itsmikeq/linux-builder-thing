#!/usr/bin/env bash
# PREP HOST (test infrastructure): initramfs that SIMULATES THE MINIMAL VENDOR OS.
# Contents: a stand-in "vendor" shell only. No make/tar/curl/python/compilers.
# /bin/sh is an AUDIT shim: every use is logged to /work/.vendor-sh-audit, so the
# tests can prove the bootstrap never falls back to the vendor shell (e.g. via
# '#!/bin/sh' shebangs or make's default SHELL). /usr/bin/env does not exist.
. "$(dirname "$0")/../common.sh"
OUT=$RBS_ROOT/output/qemu; mkdir -p "$OUT"
BBX=$RBS_ROOT/output/bootstrap/bin/busybox
[ -f "$BBX" ] || die "build busybox first"
R=$S0/initramfs; rm -rf "$R"; mkdir -p "$R"/{vendor,bin,proc,sys,dev,work,tmp}
cp "$BBX" "$R/vendor/busybox"           # stand-in for the vendor's own userland
cat > "$R/bin/sh" <<'SH'
#!/vendor/busybox sh
# Record the parent program: distinguishes build-system leaks (make, scripts run by
# path) from libc system()/popen(), which POSIX hardwires to /bin/sh.
p=$(/vendor/busybox readlink /proc/$PPID/exe 2>/dev/null)
echo "vendor /bin/sh used: parent=${p:-?} :: $*" >> /work/.vendor-sh-audit
exec /vendor/busybox sh "$@"
SH
chmod 755 "$R/bin/sh"
cat > "$R/init" <<'SH'
#!/vendor/busybox sh
B=/vendor/busybox
$B mount -t proc proc /proc
$B mount -t sysfs sys /sys
$B mount -t devtmpfs dev /dev
$B mount -t tmpfs tmp /tmp
$B mount -t ext4 /dev/vda /work || { echo "RBS: cannot mount work disk"; $B poweroff -f; }
echo "RBS: vendor-sim booted: $($B uname -srm)"
# The vendor-shell audit is cumulative for the life of the work disk, so a run that is
# resumed after a crash/restart still yields one complete audit (fresh disk = fresh audit).
cd /work
# Operator session: the vendor PATH is emptied; only explicit ./paths work.
# Output is streamed to the console (live progress) and kept in /work/run.log.
( ( PATH=/nonexistent; export PATH; /vendor/busybox sh /work/run.sh ); echo "$?" > /work/run.rc ) 2>&1 | $B tee /work/run.log
echo "RBS-EXIT=$($B cat /work/run.rc)"
$B sync; cd /; $B umount /work; $B poweroff -f
SH
chmod 755 "$R/init"
( cd "$R" && find . | LC_ALL=C sort | cpio -o -H newc --quiet --reproducible ) | gzip -9n > "$OUT/initramfs.cpio.gz"
ls -l "$OUT/initramfs.cpio.gz"
