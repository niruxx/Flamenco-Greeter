import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Widgets

// Which machine this is: host name, OS, kernel and uptime.
LoginWidgetCard {
    id: root

    required property var widget
    property bool editing: false

    readonly property string os: (osRelease.text().match(/^PRETTY_NAME="?([^"\n]*)"?/m) ?? [])[1] ?? "Linux"
    readonly property string kernel: kernelFile.text().trim()
    property real uptime: 0
    readonly property string uptimeText: {
        const m = Math.floor(uptime / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        return d > 0 ? d + "d " + (h % 24) + "h" : h > 0 ? h + "h " + (m % 60) + "m" : m + "m";
    }

    FileView { id: osRelease; path: "/etc/os-release"; blockLoading: true; printErrors: false }
    FileView { id: kernelFile; path: "/proc/sys/kernel/osrelease"; blockLoading: true; printErrors: false }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        printErrors: false
        onLoaded: root.uptime = parseFloat(text())
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    component Row_: RowLayout {
        property string icon
        property string label
        property string value
        spacing: Theme.sp2
        FIcon { icon: parent.icon; color: Theme.accent; size: 18 }
        FText { text: parent.label; dim: true; Layout.preferredWidth: 64 }
        FText { text: parent.value; Layout.maximumWidth: 170; elide: Text.ElideRight }
    }

    ColumnLayout {
        spacing: Theme.sp2
        FText {
            text: Greeter.hostName || "This computer"
            font.pixelSize: Theme.fsLg
            font.weight: Font.Bold
        }
        Row_ { icon: "deployed_code"; label: "System"; value: root.os }
        Row_ { icon: "memory"; label: "Kernel"; value: root.kernel }
        Row_ { icon: "timer"; label: "Up"; value: root.uptimeText }
    }
}
