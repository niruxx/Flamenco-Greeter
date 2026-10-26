import QtQuick
import Quickshell
import Quickshell.Wayland

// One full-screen layer per output. The first output takes the keyboard and
// shows the login card; the others show the wallpaper and clock.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property bool primary: modelData === Quickshell.screens[0]

        screen: modelData
        anchors { left: true; right: true; top: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "flamenco-greeter"
        WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "black"

        GreeterContent {
            anchors.fill: parent
            primary: win.primary
            screenName: win.modelData?.name ?? ""
        }
    }
}
