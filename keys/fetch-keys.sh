#!/usr/bin/env bash
# PREP HOST: fetch the upstream signing keys (trust anchors) used by `rbs.py pin`.
# Each file is pinned by SHA-256 (as first fetched over HTTPS from the upstream project,
# i.e. trust-on-first-use) and its primary-key fingerprint is checked. A changed key is
# never silently accepted: re-validate it independently, then update the pin here.
set -euo pipefail
cd "$(dirname "$0")"
fetch() { # file url sha256 fingerprint
  if [ ! -f "$1" ] || ! echo "$3  $1" | sha256sum -c --quiet - 2>/dev/null; then
    curl -fsSL -o "$1.part" "$2"
    if ! echo "$3  $1.part" | sha256sum -c --quiet -; then
      echo "key file $1 changed upstream ($2): re-validate before trusting" >&2
      rm -f "$1.part"; exit 1
    fi
    mv "$1.part" "$1"
  fi
  gpg --show-keys --with-colons "$1" 2>/dev/null | grep -q "^fpr:::::::::$4:" \
    || { echo "fingerprint $4 not found in $1" >&2; exit 1; }
  echo "ok $1 ($4)"
}
fetch gnu-keyring.gpg       https://ftp.gnu.org/gnu/gnu-keyring.gpg \
  8013de59880f7a59f53b6bd207f4d2a408d67b84a82fa9cba1dbbf443428e2db 7C0135FB088AAF6C66C650B9BB5869F064EA74AB
fetch release-keys.asc      https://releases.llvm.org/release-keys.asc \
  f38bd19b7f2d22cafa755841e6ce9375b9a2e6d41f7b974e4953d6b084839001 FFB3368980F3E6BB5737145A316C56D064CACBA5
fetch musl.pub              https://musl.libc.org/musl.pub \
  bf6baaa63c2c4958636850a24bb9d2d514c8b6a1b3ab9c08f3b75910fb6f57be 836489290BB6B70F99FFDA0556BCDB593020450F
fetch kernel-autosigner.asc https://git.kernel.org/pub/scm/docs/kernel/pgpkeys.git/plain/keys/632D3A06589DA6B1.asc \
  e9f6f7b99c1383ecd72de4ea9e8175e388e8c5872b97e8b7655b25fb831e4609 B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1
fetch busybox-vda.gpg       https://busybox.net/~vda/vda_pubkey.gpg \
  41d0554e1abb52e962d52ed360181ca9def8876f512553dc660edd0a4a3cb160 C9E9416F76E610DBD09D040F47B70C55ACC9965B
