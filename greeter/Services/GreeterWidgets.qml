pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Widgets placed on the login screen (press and hold the background to edit).
// Kept in <cache>/state/widgets.json, shared by everyone who uses this login
// screen. Positions are fractions of the screen, so a layout survives a
// resolution change. `flamenco-greeter widgets lock` turns editing off.
Singleton {
    id: root

    readonly property string cacheDir: Quickshell.env("FLAMENCO_GREETER_CACHE") || "/var/cache/flamenco-greeter"
    readonly property var widgets: adapter.widgets
    readonly property bool locked: adapter.locked

    // single: only one on screen at a time (they show the same thing)
    readonly property var catalog: [
        { type: "clock", name: "Clock", icon: "schedule", single: true },
        { type: "calendar", name: "Calendar", icon: "calendar_month", single: true },
        { type: "weather", name: "Weather", icon: "partly_cloudy_day", single: true },
        { type: "battery", name: "Battery", icon: "battery_full", single: true },
        { type: "system", name: "System", icon: "computer", single: true },
        { type: "note", name: "Note", icon: "sticky_note_2", single: false }
    ]

    function info(type) {
        return catalog.find(c => c.type === type) ?? null;
    }

    function has(type) {
        return widgets.some(w => w.type === type);
    }

    // spots tried in order for a new widget: the sides, clear of the clock and login card
    readonly property var slots: [[0.16, 0.32], [0.84, 0.32], [0.16, 0.68], [0.84, 0.68], [0.16, 0.5], [0.84, 0.5], [0.5, 0.86]]

    function add(type, config) {
        const free = slots.find(s => !widgets.some(w => Math.hypot(w.x - s[0], w.y - s[1]) < 0.12)) ?? [0.5, 0.5];
        const w = {
            id: Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36),
            type: type,
            x: free[0],
            y: free[1],
            config: config ?? {}
        };
        adapter.widgets = widgets.concat([w]);
        save();
        return w.id;
    }

    function remove(id) {
        adapter.widgets = widgets.filter(w => w.id !== id);
        save();
    }

    function move(id, x, y) {
        update(id, w => Object.assign({}, w, { x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y)) }));
    }

    function configure(id, key, value) {
        update(id, w => Object.assign({}, w, { config: Object.assign({}, w.config, { [key]: value }) }));
    }

    function update(id, fn) {
        adapter.widgets = widgets.map(w => w.id === id ? fn(w) : w);
        save();
    }

    function save() {
        file.writeAdapter();
    }

    FileView {
        id: file
        path: root.cacheDir + "/state/widgets.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false

        JsonAdapter {
            id: adapter
            property var widgets: []
            property bool locked: false
        }
    }
}
