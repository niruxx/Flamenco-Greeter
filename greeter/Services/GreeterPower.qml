pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery + power actions for the login screen. The shell's Power service
// also manages sleep inhibitors and niri logout, which don't apply here.
Singleton {
    id: root

    readonly property bool preview: Quickshell.env("FLAMENCO_GREETER_PREVIEW") === "1"

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device?.isLaptopBattery ?? false
    readonly property real percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.FullyCharged
    readonly property string icon: {
        if (charging)
            return "battery_charging_full";
        if (percent >= 95)
            return "battery_full";
        const bars = Math.max(0, Math.min(6, Math.floor(percent / 15)));
        return "battery_" + bars + "_bar";
    }

    function run(action) {
        if (preview) {
            console.log("[Greeter] preview: would run systemctl", action);
            return;
        }
        Quickshell.execDetached(["systemctl", action]);
    }

    function suspend() { run("suspend"); }
    function reboot() { run("reboot"); }
    function shutdown() { run("poweroff"); }
}
