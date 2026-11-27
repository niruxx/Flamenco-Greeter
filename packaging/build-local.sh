#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
root=$PWD
out=$root/dist

case ${1-} in
    fedora|debian) ;;
    *) echo "Usage: sh packaging/build-local.sh fedora|debian" >&2; exit 2 ;;
esac

mkdir -p "$out"
build=$(mktemp -d "$out/.build.XXXXXX")
trap 'rm -rf "$build"' EXIT

case $1 in
    fedora)
        shift
        spec=$root/packaging/fedora/flamenco-greeter.spec
        version=$(sed -n 's/^Version:[[:space:]]*//p' "$spec")
        mkdir -p "$build/SOURCES"
        tar -czf "$build/SOURCES/flamenco-greeter-$version.tar.gz" \
            Makefile bin/flamenco-greeter data examples greeter
        rpmbuild -bb --define "_topdir $build" --define '_rpmformat 4' "$@" "$spec"
        mv "$build/RPMS/noarch/"*.rpm "$out/"
        ;;
    debian)
        stage=$build/flamenco-greeter
        make install DESTDIR="$stage" PREFIX=/usr
        install -Dm644 packaging/debian/control "$stage/DEBIAN/control"
        install -Dm755 packaging/debian/postinst "$stage/DEBIAN/postinst"
        dpkg-deb --root-owner-group --build "$stage" "$build"
        mv "$build/"*.deb "$out/"
        ;;
esac
