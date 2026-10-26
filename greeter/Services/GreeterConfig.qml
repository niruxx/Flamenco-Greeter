pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The login screen's settings from Flamenco Shell: Settings → Lock & Login →
// Apply writes <cache>/config.json (plus wallpaper.* and avatars/*), as
// described in flamenco-shell's docs/greeter.md. Missing file or key: our
// defaults. Re-read whenever it changes, so Apply shows up straight away.
Singleton {
    id: root

    readonly property string cacheDir: Quickshell.env("FLAMENCO_GREETER_CACHE") || "/var/cache/flamenco-greeter"
    property var data: ({})
    readonly property bool present: data.version !== undefined

    function file(rel) {
        return rel ? cacheDir + "/" + rel : "";
    }

    // ── wallpaper ──
    readonly property var wp: data.wallpaper ?? {}
    readonly property string wallpaperMode: wp.mode ?? ""            // "" (not set) | image | color
    readonly property string wallpaper: wp.mode === "image" ? file(wp.file) : ""
    // a live wallpaper's video (sent next to its still by newer shells)
    readonly property string live: wp.mode === "image" ? file(wp.live ?? "") : ""
    // "desktop": it's the desktop's wallpaper, so a user's own synced one may replace it;
    // anything else (or an older shell that doesn't say): chosen for the login screen
    readonly property bool fromDesktop: wp.source === "desktop"
    readonly property string fillMode: wp.fillMode ?? "crop"
    readonly property real blur: wp.blur ?? 1
    readonly property real dim: wp.dim ?? 0.25
    readonly property string color: wp.color ?? ""
    readonly property real liveSpeed: wp.liveSpeed ?? 1

    // ── look ──
    readonly property var appearance: data.appearance ?? {}
    readonly property var colors: appearance.colors ?? {}
    readonly property bool dark: appearance.dark ?? true
    readonly property string fontFamily: appearance.fontFamily ?? ""
    readonly property string monoFamily: appearance.monoFamily ?? ""
    readonly property real fontScale: appearance.fontScale ?? 1
    readonly property real roundness: appearance.roundness ?? 1

    // ── behaviour ──
    readonly property var clock: data.clock ?? null
    readonly property bool sessionPicker: data.sessions?.picker ?? true
    readonly property string defaultSession: data.sessions?.default ?? ""     // e.g. "niri.desktop"
    readonly property var hiddenSessions: data.sessions?.hidden ?? []
    readonly property bool userList: data.users?.list ?? true
    readonly property bool rememberLast: data.users?.rememberLast ?? true
    readonly property string defaultUser: data.users?.default ?? ""
    readonly property bool powerButtons: data.power?.buttons ?? true
    // without a config.json nobody has said no, so the reader is used when PAM has it
    readonly property bool fingerprint: present ? (data.auth?.fingerprint ?? false) : true

    function avatar(user) {
        const rel = (data.users?.avatars ?? {})[user];
        return rel ? file(rel) : "";
    }

    FileView {
        id: fileView
        path: root.cacheDir + "/config.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn("[Greeter] config.json doesn't parse, using defaults:", e);
                root.data = {};
            }
        }
        onLoadFailed: root.data = {}
    }
}
