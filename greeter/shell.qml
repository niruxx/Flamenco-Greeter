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
    }

    Loader {
        active: !Greeter.windowed
        sourceComponent: GreeterSurface {}
    }

    Loader {
        active: Greeter.windowed
        sourceComponent: PreviewWindow {}
    }
}
