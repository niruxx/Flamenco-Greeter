import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

// A short message on the login screen ("Welcome", contact details…),
// written in place while editing.
LoginWidgetCard {
    id: root

    required property var widget
    property bool editing: false
    readonly property string text: widget?.config?.text ?? ""
    // follow the saved text (it arrives just after creation), but never under the cursor
    onTextChanged: if (!edit.activeFocus && edit.text !== text) edit.text = text

    Item {
        width: 260
        height: Math.max(48, edit.implicitHeight)

        FIcon {
            id: pin
            icon: "sticky_note_2"
            color: Theme.accent
            fill: 1
        }
        TextEdit {
            id: edit
            anchors.left: pin.right
            anchors.leftMargin: Theme.sp2
            anchors.right: parent.right
            readOnly: !root.editing
            enabled: root.editing          // otherwise holding the note starts editing, like any widget
            wrapMode: TextEdit.Wrap
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsLg
            Component.onCompleted: text = root.text   // not a binding: that would move the cursor on every save
            onEditingFinished: GreeterWidgets.configure(root.widget.id, "text", text)
            // save as you go too, so leaving edit mode never drops what was typed
            onTextChanged: if (root.editing && activeFocus) saveTimer.restart()
        }
        FText {
            anchors.left: edit.left
            visible: edit.text === ""
            text: root.editing ? "Write a note…" : "Empty note"
            dim: true
            font.pixelSize: Theme.fsLg
        }
        Timer {
            id: saveTimer
            interval: 600
            onTriggered: GreeterWidgets.configure(root.widget.id, "text", edit.text)
        }
    }
}
