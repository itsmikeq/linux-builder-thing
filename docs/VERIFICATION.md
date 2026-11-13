# Source integrity

`scripts/host/rbs.py pin` downloads each source, verifies it against upstream signatures,
and only then records its SHA-256 in `packages/<pkg>/package.sh`. From then on,
`rbs.py fetch`, the bundle generator and the target's `build-pkg.sh` all enforce that
SHA-256. A mismatch never re-pins.

| Source | Method | Trust anchor (`keys/`) |
|---|---|---|
| GNU packages (make, m4, sed, gawk, grep, diffutils, findutils, coreutils, patch, tar, gzip, bison, bash, binutils, gmp, mpfr, mpc, gcc) | detached `.sig`, gpgv | `gnu-keyring.gpg` from ftp.gnu.org |
| llvm-project 21.1.8 | detached `.sig` | `release-keys.asc` from releases.llvm.org |
| musl 1.2.5 | detached `.asc` | `musl.pub` from musl.libc.org |
| Linux 6.18.63 | `sha256sums.asc` clear-signed by the kernel.org autosigner | `kernel-autosigner.asc` (key 632D3A06589DA6B1, from git.kernel.org pgpkeys) |
| busybox 1.37.0 | detached `.sig` | `busybox-vda.gpg` (Denys Vlasenko) from busybox.net |
| xz 5.6.4, flex 2.6.4 | **TOFU**: SHA-256 pinned at first download from GitHub releases | none: the signing keys weren't reachable from this environment's allowed hosts |

`keys/fetch-keys.sh` fetches the keys from the upstream projects over HTTPS and checks a
pinned SHA-256 and fingerprint for each. The pins record what was first fetched. That's
trust-on-first-use for the keys; compare fingerprints against an independent source
before relying on them. Per-package verification results are in
`build/verification.json` and copied into `manifest.lock`.

Known issue: musl 1.2.5 is affected by CVE-2025-26519 (iconv EUC-KR). The bootstrap tools
don't use that iconv path. Apply the upstream fix (or move to a later musl) before
using this libc for anything exposed to untrusted input.
