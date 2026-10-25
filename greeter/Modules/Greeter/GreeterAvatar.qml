import QtQuick
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

// Round profile picture, falling back to the first letter of the name
// (same look as the shell's lock screen avatar).
ClippingRectangle {
    id: root

    property string source: ""
    property string name: ""
    property int size: 96

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: Theme.accent

    FText {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: (root.name || "?").charAt(0).toUpperCase()
        font.pixelSize: Math.round(root.size * 0.44)
        font.weight: Font.Bold
        color: Theme.onAccent
    }

    Image {
        id: img
        anchors.fill: parent
        source: Paths.toUrl(root.source)
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        asynchronous: true
    }
}
