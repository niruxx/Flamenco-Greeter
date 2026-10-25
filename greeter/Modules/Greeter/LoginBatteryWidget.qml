import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

// Battery level and whether it's charging.
LoginWidgetCard {
    id: root

    required property var widget
    property bool editing: false

    ColumnLayout {
        width: 200
        spacing: Theme.sp2

        RowLayout {
            spacing: Theme.sp2
            FIcon {
                icon: GreeterPower.hasBattery ? GreeterPower.icon : "battery_unknown"
                size: 32
                fill: 1
                rotation: 90
                color: GreeterPower.hasBattery && GreeterPower.percent <= 15 && !GreeterPower.charging ? Theme.error : Theme.accent
            }
            FText {
                text: GreeterPower.hasBattery ? GreeterPower.percent + "%" : "No battery"
                font.pixelSize: GreeterPower.hasBattery ? Theme.fsXxl : Theme.fsLg
                font.weight: Font.Bold
            }
        }

        Rectangle {
            visible: GreeterPower.hasBattery
            Layout.fillWidth: true
            implicitHeight: 8
            radius: 4
            color: Theme.alpha(Theme.surfaceHighest, 0.9)
            Rectangle {
                width: parent.width * GreeterPower.percent / 100
                height: parent.height
                radius: 4
                color: GreeterPower.percent <= 15 && !GreeterPower.charging ? Theme.error : Theme.accent
                Behavior on width { Anim {} }
            }
        }

        FText {
            visible: GreeterPower.hasBattery
            text: GreeterPower.charging ? "Charging" : "On battery"
            dim: true
        }
    }
}
