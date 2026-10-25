import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

// Shown while editing: every widget that can be added, and Done.
Rectangle {
    id: root

    property bool open: false
    signal done

    implicitWidth: col.implicitWidth + Theme.sp5 * 2
    implicitHeight: col.implicitHeight + Theme.sp4 * 2
    radius: Theme.rXl
    color: Theme.surface
    border.width: 1
    border.color: Theme.alpha(Theme.border, 0.6)

    visible: opacity > 0
    opacity: open ? 1 : 0
    transform: Translate { y: root.open ? 0 : 40; Behavior on y { Anim { easing.bezierCurve: Theme.curves.emphasizedDecel } } }
    Behavior on opacity { Anim { duration: Theme.durShort } }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: Theme.sp3

        RowLayout {
            Layout.preferredWidth: tiles.implicitWidth
            spacing: Theme.sp3
            ColumnLayout {
                spacing: 0
                FText {
                    text: "Widgets"
                    font.pixelSize: Theme.fsXl
                    font.weight: Font.Bold
                }
                FText {
                    text: "Drag to move · ✕ to remove · Esc when done"
                    dim: true
                    font.pixelSize: Theme.fsSm
                }
            }
            Item { Layout.fillWidth: true }
            FButton {
                text: "Done"
                icon: "check"
                onClicked: root.done()
            }
        }

        RowLayout {
            id: tiles
            spacing: Theme.sp2

            Repeater {
                model: GreeterWidgets.catalog

                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool available: !(modelData.single && GreeterWidgets.has(modelData.type))
                                                      && (modelData.type !== "battery" || GreeterPower.hasBattery)

                    implicitWidth: 96
                    implicitHeight: 88
                    radius: Theme.rMd
                    color: Theme.alpha(Theme.surfaceHigh, available ? 1 : 0.5)
                    opacity: available ? 1 : 0.45

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.sp1
                        FIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: tile.modelData.icon
                            size: 28
                            fill: 1
                            color: Theme.accent
                        }
                        FText {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.name
                            font.pixelSize: Theme.fsSm
                        }
                    }

                    StateLayer {
                        disabled: !tile.available
                        onClicked: GreeterWidgets.add(tile.modelData.type)
                    }
                }
            }
        }
    }
}
