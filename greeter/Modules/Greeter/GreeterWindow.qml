import QtQuick
import Quickshell

// `flamenco-greeter preview`: the greeter in an ordinary window, with a fake
// login (any password but "wrong" succeeds) so it can be tried from a session.
FloatingWindow {
    title: "Flamenco Greeter (preview)"
    implicitWidth: 1280
    implicitHeight: 800
    color: "black"

    GreeterContent {
        anchors.fill: parent
        primary: true
        // the first screen's wallpaper (per-screen wallpapers, like the real login screen)
        screenName: Quickshell.screens[0]?.name ?? ""
    }
}
