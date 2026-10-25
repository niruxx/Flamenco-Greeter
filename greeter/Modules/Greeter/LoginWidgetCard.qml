import QtQuick
import qs.Commons

// The surface every login-screen widget sits on: the same translucent,
// rounded panel as the password field, so widgets read as part of the screen.
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: Theme.sp4

    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: inner.childrenRect.height + padding * 2
    radius: Theme.rLg
    color: Theme.alpha(Theme.surface, 0.72)
    border.width: 1
    border.color: Theme.alpha(Theme.border, 0.5)

    Item {
        id: inner
        x: root.padding
        y: root.padding
        width: childrenRect.width
        height: childrenRect.height
    }
}
