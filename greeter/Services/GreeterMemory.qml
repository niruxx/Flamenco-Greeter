pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Last user and session, kept in <cache>/state/memory.json. The launcher also
// reads lastUser to pick whose theme the greeter starts with.
Singleton {
    id: root

    readonly property bool rememberUser: Quickshell.env("FLAMENCO_GREETER_REMEMBER_USER") !== "0"
    readonly property bool rememberSession: Quickshell.env("FLAMENCO_GREETER_REMEMBER_SESSION") !== "0"

    readonly property string lastUser: rememberUser ? adapter.lastUser : ""
    readonly property string lastSession: rememberSession ? adapter.lastSession : ""

    function remember(user, session) {
        adapter.lastUser = rememberUser ? user : "";
        adapter.lastSession = rememberSession ? session : "";
        file.writeAdapter();
    }

    FileView {
        id: file
        path: (Quickshell.env("FLAMENCO_GREETER_CACHE") || "/var/cache/flamenco-greeter") + "/state/memory.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false

        JsonAdapter {
            id: adapter
            property string lastUser: ""
            property string lastSession: ""
        }
    }
}
