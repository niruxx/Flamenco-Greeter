import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Widgets

// The login screen. Layout, motion and controls follow the shell's
// LockSurface (Modules/Lock/LockSurface.qml) so logging in and unlocking look
// like the same screen; the greeter adds a user picker and a session chooser.
Item {
    id: root

    property bool primary: true

    // 0 → 1 once the theme is ready, back to 0 while the session starts
    property real p: 0
    Behavior on p { Anim { duration: Theme.durXl; easing.bezierCurve: Theme.curves.emphasized } }

    // With "colors from wallpaper", give matugen a moment so the screen
    // doesn't flash the fallback palette first.
    property bool waited: false
    Timer { running: true; interval: 1500; onTriggered: root.waited = true }
    readonly property bool themeReady: Settings.ready && (Settings.data.appearance.palette !== "wallpaper" || ColorGen.available || waited)
    onThemeReadyChanged: if (themeReady) p = 1
    Component.onCompleted: if (themeReady) p = 1

    Connections {
        target: Greeter
        function onUnlockingChanged() {
            if (Greeter.unlocking)
                root.p = 0;
        }
    }

    property string menu: ""   // "" | "users" | "sessions"

    // ── widget editing: press and hold the background (or a widget) ──
    property bool editing: false
    // the clock, login card and buttons step back while widgets are edited
    readonly property real chrome: editing ? 0.15 : 1
    property real chromeAnim: chrome
    Behavior on chromeAnim { Anim {} }

    function startEditing() {
        if (!primary || GreeterWidgets.locked || Greeter.unlocking)
            return;
        menu = "";
        editing = true;
        root.forceActiveFocus();
    }

    function stopEditing() {
        if (!editing)
            return;
        editing = false;
        input.forceActiveFocus();
    }

    Keys.onEscapePressed: stopEditing()

    // ── wallpaper (cross-fades when a different user's theme comes in) ──
    readonly property string wallpaper: Paths.expand(Settings.data.wallpaper.current)
    property bool showB: false
    onWallpaperChanged: {
        if (showB)
            wallA.source = Paths.toUrl(wallpaper);
        else
            wallB.source = Paths.toUrl(wallpaper);
        showB = !showB;
    }

    Item {
        id: wallLayer
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.surfaceHigh }
                GradientStop { position: 1; color: Theme.bg }
            }
        }
        Image {
            id: wallA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: Paths.toUrl(root.wallpaper)
            opacity: root.showB ? 0 : 1
            Behavior on opacity { Anim { duration: Theme.durXl } }
        }
        Image {
            id: wallB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: root.showB ? 1 : 0
            Behavior on opacity { Anim { duration: Theme.durXl } }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: wallLayer
        blurEnabled: true
        blurMax: 64
        blur: 1
        brightness: -0.18
        saturation: -0.1
        scale: 1.06
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.25
    }

    // the background: a click closes a menu or finishes editing; holding it starts editing
    MouseArea {
        id: background
        anchors.fill: parent
        enabled: root.primary
        pressAndHoldInterval: 600
        onPressed: mouse => {
            if (root.editing || root.menu !== "" || GreeterWidgets.locked)
                return;
            holdRing.x = mouse.x - holdRing.width / 2;
            holdRing.y = mouse.y - holdRing.height / 2;
            holdGrow.restart();
        }
        onReleased: holdGrow.stop()
        onCanceled: holdGrow.stop()
        onPressAndHold: root.startEditing()
        onClicked: {
            if (root.menu !== "")
                root.menu = "";
            else if (root.editing)
                root.stopEditing();
        }
    }

    // grows under the pointer while holding, so it's clear something is about to happen
    Rectangle {
        id: holdRing
        width: 72
        height: 72
        radius: 36
        color: Theme.alpha(Theme.accent, 0.22)
        border.width: 2
        border.color: Theme.accent
        opacity: holdGrow.running ? 1 : 0
        scale: 0
        Behavior on opacity { Anim { duration: Theme.durShort } }
        NumberAnimation {
            id: holdGrow
            target: holdRing
            property: "scale"
            from: 0.2
            to: 1
            duration: background.pressAndHoldInterval
            easing.type: Easing.OutCubic
        }
    }

    LoginWidgetLayer {
        anchors.fill: parent
        visible: root.primary
        opacity: root.p
        editing: root.editing
        onHoldToEdit: root.startEditing()
    }

    // ── clock ──
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16 - (1 - root.p) * 80
        opacity: root.p * root.chromeAnim
        spacing: 0

        FText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hours + ":" + Time.minutes
            font.pixelSize: Theme.fsHuge * 1.4
            font.weight: Font.Black
            color: Theme.text
        }
        FText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.date
            font.pixelSize: Theme.fsXl
            color: Theme.text
            opacity: 0.85
        }
    }

    // ── login card ──
    ColumnLayout {
        id: auth
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.58 + (1 - root.p) * 120 - (Greeter.manualUser ? 34 : 0)
        opacity: root.p * root.chromeAnim
        enabled: !root.editing
        spacing: Theme.sp4
        Behavior on y { enabled: root.p === 1; Anim { easing.bezierCurve: Theme.curves.spring } }

        GreeterAvatar {
            id: face
            Layout.alignment: Qt.AlignHCenter
            size: 96
            source: Greeter.avatar
            name: Greeter.displayName
            border.width: 3
            border.color: Theme.alpha(Theme.text, 0.6)

            StateLayer {
                radius: face.radius
                onClicked: root.menu = root.menu === "users" ? "" : "users"
            }
        }

        // name, doubling as the user switcher
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: nameRow.implicitWidth + Theme.sp4 * 2
            implicitHeight: 36
            radius: 18
            color: "transparent"

            RowLayout {
                id: nameRow
                anchors.centerIn: parent
                spacing: Theme.sp1
                FText {
                    text: Greeter.displayName
                    font.pixelSize: Theme.fsXl
                    font.weight: Font.Bold
                }
                FIcon {
                    icon: root.menu === "users" ? "expand_less" : "expand_more"
                    color: Theme.textDim
                }
            }
            StateLayer {
                onClicked: root.menu = root.menu === "users" ? "" : "users"
            }
        }

        // "Other user…": type a username
        Rectangle {
            id: nameField
            visible: Greeter.manualUser
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 340
            Layout.preferredHeight: 54
            radius: 27
            color: Theme.alpha(Theme.surface, 0.75)
            border.width: 2
            border.color: nameInput.activeFocus ? Theme.accent : Theme.alpha(Theme.border, 0.6)
            Behavior on border.color { CAnim {} }

            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLg
                text: Greeter.manualName
                onTextEdited: Greeter.manualName = text
                onAccepted: {
                    input.forceActiveFocus();
                    Greeter.listen();
                }
                KeyNavigation.tab: input
                Keys.onEscapePressed: Greeter.selectUser(Math.max(0, Greeter.userIndex))
            }
            FText {
                anchors.centerIn: parent
                visible: nameInput.text === ""
                text: "Username"
                dim: true
            }
        }

        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 340
            Layout.preferredHeight: 54
            radius: 27
            color: Theme.alpha(Theme.surface, 0.75)
            border.width: 2
            border.color: Greeter.errorText ? Theme.error : input.activeFocus ? Theme.accent : Theme.alpha(Theme.border, 0.6)
            Behavior on border.color { CAnim {} }

            readonly property bool echo: Greeter.promptText !== "" && Greeter.promptEcho
            // the reader is listening and nothing's typed yet
            readonly property bool fingerprint: Greeter.scanning && Greeter.buffer === "" && !Greeter.authenticating
            // a password was entered mid-scan and goes in when the round ends
            readonly property bool waiting: Greeter.scanning && Greeter.authenticating

            // shake on failure
            transform: Translate { id: shake }
            SequentialAnimation {
                id: shakeAnim
                loops: 1
                NumberAnimation { target: shake; property: "x"; to: -16; duration: 50 }
                NumberAnimation { target: shake; property: "x"; to: 14; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: -10; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: 6; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 70 }
            }
            Connections {
                target: Greeter
                function onShakeCountChanged() { shakeAnim.restart(); }
                function onBufferChanged() {
                    if (input.text !== Greeter.buffer)
                        input.text = Greeter.buffer;
                }
                function onManualUserChanged() {
                    if (Greeter.manualUser)
                        nameInput.forceActiveFocus();
                    else
                        input.forceActiveFocus();
                }
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 48
                opacity: field.echo ? 1 : 0
                focus: root.primary
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLg
                echoMode: field.echo ? TextInput.Normal : TextInput.Password
                onTextEdited: {
                    Greeter.buffer = text;
                    if (Greeter.errorText && !Greeter.authenticating)
                        Greeter.errorText = "";
                }
                onAccepted: {
                    root.menu = "";
                    Greeter.submit();
                }
                KeyNavigation.backtab: nameInput
                Keys.onEscapePressed: {
                    if (root.menu !== "")
                        root.menu = "";
                    else
                        Greeter.reset();
                }
                Component.onCompleted: if (root.primary) forceActiveFocus()
            }

            // animated dots
            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: !field.echo && Greeter.buffer.length > 0
                Repeater {
                    model: Math.min(Greeter.buffer.length, 24)
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: Theme.text
                        scale: 0
                        Component.onCompleted: scale = 1
                        Behavior on scale { Anim { duration: Theme.durMed; easing.bezierCurve: Theme.curves.springFast } }
                    }
                }
            }

            FText {
                anchors.centerIn: parent
                width: parent.width - 96
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: Greeter.buffer.length === 0
                text: Greeter.authenticating ? "Checking…" : Greeter.errorText || Greeter.promptText || (Greeter.scanning ? "Scan your finger on the reader" : Greeter.ready ? "Enter password" : "Loading…")
                dim: !Greeter.errorText
                color: Greeter.errorText ? Theme.error : Theme.textDim
            }

            FIcon {
                id: spinner
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                icon: Greeter.authenticating ? "progress_activity" : field.fingerprint ? "fingerprint" : "arrow_forward"
                color: Theme.accent
                fill: field.fingerprint ? 1 : 0
                RotationAnimation on rotation {
                    running: Greeter.authenticating
                    from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    // don't leave the arrow tilted where the spinner stopped
                    onRunningChanged: if (!running) spinner.rotation = 0
                }
                // breathe while the reader waits for a finger
                SequentialAnimation on scale {
                    running: field.fingerprint
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) spinner.scale = 1
                    NumberAnimation { to: 1.18; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // under the field, so the card doesn't move when it comes and goes
            FText {
                anchors.top: parent.bottom
                anchors.topMargin: Theme.sp2
                anchors.horizontalCenter: parent.horizontalCenter
                text: field.waiting ? "Finishing the fingerprint scan…" : "or type your password"
                dim: true
                font.pixelSize: Theme.fsSm
                opacity: field.fingerprint || field.waiting ? 1 : 0
                Behavior on opacity { Anim { duration: Theme.durShort } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: input.forceActiveFocus()
            }
        }
    }

    GreeterMenu {
        visible: root.primary && opacity > 0
        open: root.menu === "users"
        avatars: true
        anchors.horizontalCenter: parent.horizontalCenter
        // drops down from under the avatar, over the name and password field
        y: auth.y + face.height + Theme.sp2
        transformOrigin: Item.Top
        model: Greeter.users.map((u, i) => ({
                    title: u.realName || u.name,
                    subtitle: u.realName && u.realName !== u.name ? u.name : "",
                    avatar: u.avatar,
                    current: !Greeter.manualUser && i === Greeter.userIndex
                })).concat([{ title: "Other user…", icon: "person_add", current: Greeter.manualUser }])
        onPicked: index => {
            root.menu = "";
            if (index < Greeter.users.length)
                Greeter.selectUser(index);
            else
                Greeter.selectManual();
            if (!Greeter.manualUser)
                input.forceActiveFocus();
        }
    }

    // ── session + power (where the lock screen keeps media + power) ──
    RowLayout {
        id: bottom
        visible: root.primary
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 40 - (1 - root.p) * 100
        opacity: root.p * (root.editing ? 0 : 1)
        enabled: !root.editing
        spacing: Theme.sp3
        Behavior on opacity { Anim { duration: Theme.durShort } }

        Rectangle {
            id: sessionChip
            visible: Greeter.sessions.length > 0
            implicitWidth: srow.implicitWidth + 32
            implicitHeight: 52
            radius: 26
            color: Theme.alpha(Theme.surface, 0.75)
            RowLayout {
                id: srow
                anchors.centerIn: parent
                spacing: 8
                FIcon { icon: "desktop_windows"; color: Theme.accent }
                FText {
                    text: Greeter.session?.name ?? ""
                    Layout.maximumWidth: 260
                    elide: Text.ElideRight
                }
                FIcon {
                    visible: Greeter.sessions.length > 1
                    icon: root.menu === "sessions" ? "expand_more" : "expand_less"
                    color: Theme.textDim
                }
            }
            StateLayer {
                disabled: Greeter.sessions.length < 2
                onClicked: root.menu = root.menu === "sessions" ? "" : "sessions"
            }
        }

        FIconButton { icon: "bedtime"; size: 52; flat: false; onClicked: GreeterPower.suspend() }
        FIconButton { icon: "restart_alt"; size: 52; flat: false; onClicked: GreeterPower.reboot() }
        FIconButton { icon: "power_settings_new"; size: 52; flat: false; iconColor: Theme.error; onClicked: GreeterPower.shutdown() }
    }

    GreeterMenu {
        visible: root.primary && opacity > 0
        open: root.menu === "sessions"
        x: Math.max(Theme.sp4, bottom.x + sessionChip.x + sessionChip.width / 2 - width / 2)
        y: bottom.y - height - Theme.sp3
        transformOrigin: Item.Bottom
        model: Greeter.sessions.map((s, i) => ({
                    title: s.name,
                    subtitle: s.comment,
                    icon: s.type === "x11" ? "tv" : "desktop_windows",
                    current: i === Greeter.sessionIndex
                }))
        onPicked: index => {
            root.menu = "";
            Greeter.selectSession(index);
            input.forceActiveFocus();
        }
    }

    // ── corners: host name + battery ──
    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 24
        spacing: 6
        visible: root.primary && Greeter.hostName !== ""
        opacity: root.p
        FIcon { icon: "computer" }
        FText { text: Greeter.hostName }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 6
        visible: GreeterPower.hasBattery
        opacity: root.p
        FIcon { icon: GreeterPower.icon; rotation: 90; fill: 1 }
        FText { text: GreeterPower.percent + "%" }
    }

    LoginWidgetSheet {
        visible: root.primary && opacity > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
        open: root.editing
        onDone: root.stopEditing()
    }

    // windowed only: `qs -p … ipc call greeter …` for screenshots and testing
    IpcHandler {
        target: "greeter"
        enabled: Greeter.windowed && root.primary
        function menu(name: string): void { root.menu = name; }
        function type(text: string): void { Greeter.buffer = text; }
        function submit(): void { Greeter.submit(); }
        function reset(): void { Greeter.reset(); }
        // with `preview --fingerprint`: touch the fake reader
        function finger(match: bool): void { Greeter.previewFinger(match); }
        function edit(on: bool): void { on ? root.startEditing() : root.stopEditing(); }
        function addWidget(type: string): void { GreeterWidgets.add(type); }
        // save what's on screen to a PNG; works off-screen too (tools/screenshots.sh)
        function grab(path: string): void { root.grabToImage(r => r.saveToFile(path)); }
    }

    // fade from / to black around the login
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 1 - root.p
    }
}
