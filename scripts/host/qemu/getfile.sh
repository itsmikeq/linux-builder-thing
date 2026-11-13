#!/usr/bin/env bash
# PREP HOST: copy a file or directory out of an ext4 work image (no root, no mount).
#   getfile.sh <img> <path-in-image> <dest>
set -euo pipefail
img=$1 path=$2 dest=$3
mkdir -p "$dest"
debugfs -R "rdump $path $dest" "$img" >/dev/null 2>&1 || { echo "cannot extract $path" >&2; exit 1; }
