#!/bin/sh
# Build the package from this checkout into "History Builds/flamenco-greeter-<version>-<rel>/".
# Runtime dependencies (flamenco-shell, greetd…) aren't needed to build, so they aren't checked.
set -e
cd "$(dirname "$0")"
. ./PKGBUILD
out="../../History Builds/$pkgname-$pkgver-$pkgrel"
makepkg -f --cleanbuild --nodeps
mkdir -p "$out"
mv -f "$pkgname-$pkgver-$pkgrel"-*.pkg.tar.zst "$out/"
rm -rf src pkg
ls -la "$out"
