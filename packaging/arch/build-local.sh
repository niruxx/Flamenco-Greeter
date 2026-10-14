#!/bin/sh
# Build the package from this checkout and drop it in ../../dist.
set -e
cd "$(dirname "$0")"
makepkg -f --cleanbuild
mkdir -p ../../dist
mv -f flamenco-greeter-*.pkg.tar.zst ../../dist/
rm -rf src pkg
ls ../../dist
