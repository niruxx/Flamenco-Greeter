#!/usr/bin/env bash
# Capture the README screenshots from `flamenco-greeter preview`.
#
#   tools/screenshots.sh [output-dir]      (default: docs/screenshots)
#
# Run from a desktop session after `make dev`. Uses spectacle (KDE) or niri's
# own window screenshot; rsvg-convert renders the palette wallpapers that
# tools/readme-assets.py draws, so your own wallpaper never ends up in a shot.
# Your settings aren't touched: preview works on a throwaway copy.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$here/..
out=${1:-$root/docs/screenshots}
settle=${SETTLE:-1.4}    # seconds for animations to finish before a capture
boot=${BOOT:-4}          # seconds for a preview window to appear
work=${XDG_CACHE_HOME:-$HOME/.cache}/flamenco-greeter-readme
greeter=$root/greeter
bin=$root/bin/flamenco-greeter

command -v rsvg-convert >/dev/null || { echo "screenshots: rsvg-convert is not installed (pacman -S librsvg)" >&2; exit 1; }
[ -e "$greeter/Commons" ] || { echo "screenshots: run 'make dev' first" >&2; exit 1; }
if command -v spectacle >/dev/null && [ "${XDG_CURRENT_DESKTOP:-}" = KDE ]; then
    grab() { spectacle -b -n -a -e -S -o "$1"; }
elif [ -n "${NIRI_SOCKET:-}" ]; then
    grab() { niri msg action screenshot-window --path "$1" >/dev/null; }
elif command -v spectacle >/dev/null; then
    grab() { spectacle -b -n -a -e -S -o "$1"; }
else
    echo "screenshots: needs spectacle (KDE) or a niri session" >&2
    exit 1
fi

mkdir -p "$out" "$work/walls"
python3 "$here/readme-assets.py" wallpapers "$work/walls" >/dev/null
wall() {   # wall PALETTE MODE → a rendered PNG
    local png=$work/walls/$1-$2.png
    [ -f "$png" ] || rsvg-convert -w 1920 "$work/walls/$1-$2.svg" -o "$png"
    echo "$png"
}

ipc() { qs -p "$greeter" ipc call greeter "$@" >/dev/null; }

pid=""
stop() {
    [ -n "$pid" ] || return 0
    qs kill -p "$greeter" >/dev/null 2>&1 || true
    wait "$pid" 2>/dev/null || true
    pid=""
}
trap stop EXIT

# start NAME PALETTE MODE [preview flags…]
start() {
    stop
    "$bin" preview --palette "$2" --mode "$3" --wallpaper "$(wall "$2" "$3")" "${@:4}" >/dev/null 2>&1 &
    pid=$!
    sleep "$boot"
}

shot() {   # shot NAME [settle-seconds]
    sleep "${2:-$settle}"
    grab "$out/$1.png"
    echo "  $out/$1.png"
}

echo "Capturing to $out"

start login flamenco dark;                  shot login-dark
ipc menu users;                             shot user-picker
ipc menu sessions;                          shot session-picker
ipc menu "";  ipc type wrong; ipc submit;   shot wrong-password 1

start login flamenco light;                 shot login-light

start fp flamenco dark --fingerprint;       shot fingerprint
ipc finger false;                           shot fingerprint-miss 0.3
sleep 2.5;    ipc type hunter2;             shot fingerprint-typing

for p in catppuccin rosepine nord gruvbox dracula kanagawa tokyonight everforest; do
    start "$p" "$p" dark;                   shot "palette-$p"
done

stop
echo "Done."
