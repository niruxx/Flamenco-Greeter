import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

// The login screen's widgets. Normally they just sit there (holding one
// starts editing); while editing they can be dragged and removed.
Item {
    id: root

    property bool editing: false
    signal holdToEdit

    readonly property int margin: 24
    function clampX(x, w) { return Math.max(margin, Math.min(width - w - margin, x)); }
    function clampY(y, h) { return Math.max(margin, Math.min(height - h - margin, y)); }

    readonly property var components: ({
            clock: clockC,
            calendar: calendarC,
            weather: weatherC,
            battery: batteryC,
            system: systemC,
            note: noteC
        })

    // by count, not by the list itself: saving a widget (a keystroke in a
    // note) then updates it in place instead of rebuilding every widget
    Repeater {
        model: GreeterWidgets.widgets.length

        Item {
            id: slot

            required property int index
            readonly property var widget: GreeterWidgets.widgets[index] ?? null

            width: body.item?.implicitWidth ?? 0
            height: body.item?.implicitHeight ?? 0
            // centre at the saved fraction, kept on screen with room for the ✕ button
            readonly property real wantX: (widget?.x ?? 0.5) * root.width - width / 2
            readonly property real wantY: (widget?.y ?? 0.5) * root.height - height / 2
            x: root.clampX(wantX, width)
            y: root.clampY(wantY, height)

            scale: drag.pressed ? 1.04 : 1
            Behavior on scale { Anim { duration: Theme.durShort } }

            Loader {
                id: body
                sourceComponent: slot.widget ? root.components[slot.widget.type] ?? null : null
                onLoaded: {
                    item.widget = Qt.binding(() => slot.widget);
                    item.editing = Qt.binding(() => root.editing);
                }
            }

            // edit outline
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: Theme.rLg + 4
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                opacity: root.editing ? (drag.containsMouse || drag.pressed ? 1 : 0.6) : 0
                Behavior on opacity { Anim { duration: Theme.durShort } }
            }

            // drag to move while editing; hold to start editing otherwise.
            // Below the widget's own controls (city field, note text), which stay usable.
            MouseArea {
                id: drag
                anchors.fill: parent
                z: -1
                hoverEnabled: root.editing
                cursorShape: root.editing ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                pressAndHoldInterval: 600
                drag.target: root.editing ? slot : null
                drag.threshold: 4
                drag.minimumX: root.margin
                drag.minimumY: root.margin
                drag.maximumX: root.width - slot.width - root.margin
                drag.maximumY: root.height - slot.height - root.margin
                onPressAndHold: if (!root.editing) root.holdToEdit()
                onReleased: {
                    if (root.editing && slot.widget) {
                        GreeterWidgets.move(slot.widget.id, (slot.x + slot.width / 2) / root.width, (slot.y + slot.height / 2) / root.height);
                        // dragging replaced the bindings; follow the saved spot again
                        slot.x = Qt.binding(() => root.clampX(slot.wantX, slot.width));
                        slot.y = Qt.binding(() => root.clampY(slot.wantY, slot.height));
                    }
                }
            }

            FIconButton {
                visible: root.editing
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: -14
                icon: "close"
                size: 30
                flat: false
                color: Theme.error
                iconColor: Theme.onAccent
                onClicked: GreeterWidgets.remove(slot.widget.id)
            }
        }
    }

    Component { id: clockC; LoginClockWidget { widget: null } }
    Component { id: calendarC; LoginCalendarWidget { widget: null } }
    Component { id: weatherC; LoginWeatherWidget { widget: null } }
    Component { id: batteryC; LoginBatteryWidget { widget: null } }
    Component { id: systemC; LoginSystemWidget { widget: null } }
    Component { id: noteC; LoginNoteWidget { widget: null } }
}
