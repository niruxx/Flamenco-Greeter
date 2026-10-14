import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Small pop-up list for choosing a user or a session.
// model: [{ title, subtitle, icon, avatar, current }]
Rectangle {
    id: root

    property bool open: false
    property var model: []
    property bool avatars: false
    signal picked(int index)

    implicitWidth: 320
    implicitHeight: col.implicitHeight + Theme.sp2 * 2
    radius: Theme.rLg
    color: Theme.surface
    border.width: 1
    border.color: Theme.alpha(Theme.border, 0.6)

    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    Behavior on opacity { Anim { duration: Theme.durShort } }
    Behavior on scale { Anim { easing.bezierCurve: Theme.curves.spring } }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.sp2
        spacing: 2

        Repeater {
            model: root.model

            Rectangle {
                id: row
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.rMd
                color: modelData.current ? Theme.alpha(Theme.accent, 0.16) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp3
                    anchors.rightMargin: Theme.sp3
                    spacing: Theme.sp3

                    Avatar {
                        visible: root.avatars && !row.modelData.icon
                        size: 34
                        source: row.modelData.avatar ?? ""
                        name: row.modelData.title
                    }
                    FIcon {
                        visible: !!row.modelData.icon
                        icon: row.modelData.icon ?? ""
                        Layout.preferredWidth: root.avatars ? 34 : implicitWidth
                        color: row.modelData.current ? Theme.accent : Theme.text
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        FText {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            elide: Text.ElideRight
                            font.weight: row.modelData.current ? Font.Bold : Font.Normal
                        }
                        FText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.modelData.subtitle ?? ""
                            dim: true
                            font.pixelSize: Theme.fsSm
                            elide: Text.ElideRight
                        }
                    }
                    FIcon {
                        visible: !!row.modelData.current
                        icon: "check"
                        color: Theme.accent
                    }
                }

                StateLayer {
                    onClicked: root.picked(row.index)
                }
            }
        }
    }
}
