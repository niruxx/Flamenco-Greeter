import QtQuick
import qs.Commons
import qs.Services

// Analog clock with Material hands; the second hand sweeps in the accent color.
LoginWidgetCard {
    id: root

    required property var widget
    property bool editing: false
    readonly property int size: 168
    readonly property date now: Time.now

    Item {
        width: root.size
        height: root.size

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.alpha(Theme.surfaceHigh, 0.6)
        }

        // hour ticks
        Repeater {
            model: 12
            Rectangle {
                required property int index
                x: root.size / 2 - width / 2
                y: 8
                width: index % 3 === 0 ? 4 : 2
                height: index % 3 === 0 ? 12 : 7
                radius: width / 2
                color: index % 3 === 0 ? Theme.text : Theme.textDim
                transform: Rotation { origin.x: width / 2; origin.y: root.size / 2 - 8; angle: index * 30 }
            }
        }

        component Hand: Rectangle {
            property real turn      // degrees clockwise from 12
            property real length
            x: root.size / 2 - width / 2
            y: root.size / 2 - length
            height: length + 10
            radius: width / 2
            antialiasing: true
            transform: Rotation { origin.x: width / 2; origin.y: length; angle: turn }
        }

        Hand {
            width: 6
            length: root.size * 0.26
            color: Theme.text
            turn: (root.now.getHours() % 12 + root.now.getMinutes() / 60) * 30
        }
        Hand {
            width: 4
            length: root.size * 0.37
            color: Theme.text
            turn: (root.now.getMinutes() + root.now.getSeconds() / 60) * 6
        }
        Hand {
            width: 2
            length: root.size * 0.40
            color: Theme.accent
            turn: root.now.getSeconds() * 6
        }
        Rectangle {
            anchors.centerIn: parent
            width: 12; height: 12; radius: 6
            color: Theme.accent
        }
    }
}
