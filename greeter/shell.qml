//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1

import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Modules.Greeter

// Flamenco greeter: the shell's lock screen, for greetd.
//
// Commons/, Widgets/ and assets/ are Flamenco Shell's own (linked in at
// install time), so Theme, palettes, fonts and controls are the exact ones the
// desktop uses. Settings reads the synced copy of the user's settings.json
// from the greeter cache, so the login screen wears their theme.
ShellRoot {
    id: root

    // no hot reload on a real login screen; keep it while previewing
    Binding {
        target: Quickshell
        property: "watchFiles"
        value: Greeter.preview
    }

    Component.onCompleted: {
        ColorGen.available;
        Greeter.ready;
        // `flamenco-greeter doctor` and the launcher load the UI off-screen
        // to catch QML errors (e.g. after a Flamenco Shell update) before a
        // broken greeter leaves the login screen black.
        if (Quickshell.env("FLAMENCO_GREETER_CHECK") === "1")
            checkDone.start();
    }

    // Quickshell only hooks up Qt.quit() once loading has finished
    Timer {
        id: checkDone
        interval: 200
        onTriggered: {
            console.log("flamenco-greeter-check: loaded");
            Qt.quit();
        }
    }

    // by URL, so the off-screen check (which has no layer-shell backend) only
    // compiles it when it's used; the window below shares all its content
    Loader {
        active: !Greeter.windowed
        source: active ? "Modules/Greeter/GreeterSurface.qml" : ""
    }

    Loader {
        active: Greeter.windowed
        sourceComponent: GreeterWindow {}
    }
}
