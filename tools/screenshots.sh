#!/usr/bin/env bash
# Capture the README screenshots from `flamenco-greeter preview`.
#
#   tools/screenshots.sh [output-dir]      (default: docs/screenshots)
#
# Run from any desktop session after `make dev`. The greeter saves its own
# window through IPC (`ipc call greeter grab`), so no screenshot tool is needed and any
# compositor works. rsvg-convert renders the palette wallpapers drawn by
# tools/readme-assets.py, so your own wallpaper never ends up in a shot, and
# preview works on a throwaway copy of your settings.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$here/..
out=$(realpath -m "${1:-$root/docs/screenshots}")
settle=${SETTLE:-1.4}    # seconds for animations to finish before a capture
boot=${BOOT:-6}          # seconds for a preview window to appear
work=${XDG_CACHE_HOME:-$HOME/.cache}/flamenco-greeter-readme
bin=$root/bin/flamenco-greeter

command -v rsvg-convert >/dev/null || { echo "screenshots: rsvg-convert is not installed (pacman -S librsvg)" >&2; exit 1; }
[ -e "$root/greeter/Commons" ] || { echo "screenshots: run 'make dev' first" >&2; exit 1; }

mkdir -p "$out" "$work/walls"
python3 "$here/readme-assets.py" wallpapers "$work/walls" >/dev/null
wall() {   # wall PALETTE MODE → a rendered PNG
    local png=$work/walls/$1-$2.png
    [ -f "$png" ] || rsvg-convert -w 1920 "$work/walls/$1-$2.svg" -o "$png"
    echo "$png"
}

id=""
ipc() { qs ipc -i "$id" call greeter "$@" >/dev/null; }

stop() {
    [ -n "$id" ] || return 0
    qs kill -i "$id" >/dev/null 2>&1 || true
    id=""
    sleep 0.5
}
trap stop EXIT

# start PALETTE MODE [preview flags…]   (no widgets unless asked for)
start() {
    stop
    local log=$work/preview.log
    "$bin" preview --palette "$1" --mode "$2" --wallpaper "$(wall "$1" "$2")" "${@:3}" > "$log" 2>&1 &
    sleep "$boot"
    id=$(grep -o "by-id/[a-z0-9]*" "$log" | head -1 | cut -d/ -f2)
    [ -n "$id" ] || { echo "screenshots: the preview didn't start; see $log" >&2; exit 1; }
}

empty=$work/no-widgets.json
echo '{"widgets": [], "locked": false}' > "$empty"

shot() {   # shot NAME [settle-seconds]
    sleep "${2:-$settle}"
    ipc grab "$out/$1.png"
    sleep 0.8
    echo "  $out/$1.png"
}

echo "Capturing to $out"

start flamenco dark --widgets "$empty";       shot login-dark
ipc menu users;                               shot user-picker
ipc menu sessions;                            shot session-picker
ipc menu "";  ipc type wrong; ipc submit;     shot wrong-password 1

start flamenco light --widgets "$empty";      shot login-light

start flamenco dark --fingerprint --widgets "$empty";   shot fingerprint
ipc finger false;                             shot fingerprint-miss 0.3
sleep 2.5;    ipc type hunter2;               shot fingerprint-typing

start flamenco dark --widgets "$here/demo-widgets.json";  shot widgets
ipc edit true;                                shot widgets-edit

for p in catppuccin rosepine nord gruvbox dracula kanagawa tokyonight everforest; do
    start "$p" dark --widgets "$empty";       shot "palette-$p"
done

stop
echo "Done."
