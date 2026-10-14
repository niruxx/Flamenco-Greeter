pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.Commons

// Login state + the greetd conversation. The UI binds to this the same way the
// shell's lock screen binds to its Lock scope (buffer, submit, errorText, …).
Singleton {
    id: root

    readonly property bool preview: Quickshell.env("FLAMENCO_GREETER_PREVIEW") === "1"
    readonly property string cacheDir: Quickshell.env("FLAMENCO_GREETER_CACHE") || "/var/cache/flamenco-greeter"
    readonly property string bin: Quickshell.env("FLAMENCO_GREETER_BIN") || "flamenco-greeter"

    // ── users + sessions (from `flamenco-greeter users|sessions --json`) ──
    property var users: []
    property var sessions: []
    property int userIndex: -1
    property int sessionIndex: 0
    property bool usersLoaded: false
    property bool sessionsLoaded: false
    readonly property bool ready: usersLoaded && sessionsLoaded

    // "Other user…": type a name instead of picking one
    property bool manualUser: false
    property string manualName: ""

    readonly property var user: manualUser ? null : users[userIndex] ?? null
    readonly property string username: manualUser ? manualName.trim() : user?.name ?? ""
    readonly property string displayName: manualUser ? (manualName.trim() || "Other user") : user?.realName || username
    readonly property string avatar: user?.avatar ?? ""
    readonly property var session: sessions[sessionIndex] ?? null

    // ── auth (same names as the shell's Lock scope) ──
    property string buffer: ""
    property bool authenticating: false
    property bool unlocking: false
    property string errorText: ""
    property string promptText: ""       // a PAM prompt other than the password (OTP, token…)
    property bool promptEcho: false
    property int shakeCount: 0
    property bool awaitingResponse: false
    property bool passwordSent: false    // the typed password answered this session's first hidden prompt

    readonly property string hostName: hostnameFile.text().trim()

    function selectUser(i) {
        cancel();
        manualUser = false;
        userIndex = i;
    }

    function selectManual() {
        cancel();
        manualUser = true;
        manualName = "";
    }

    function selectSession(i) {
        sessionIndex = i;
    }

    function cancel() {
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        authenticating = false;
        awaitingResponse = false;
        promptText = "";
        buffer = "";
        errorText = "";
    }

    function submit() {
        if (authenticating || unlocking || username === "")
            return;
        if (!session) {
            fail("No desktop sessions installed");
            return;
        }
        errorText = "";
        authenticating = true;
        if (preview) {
            previewTimer.restart();
            return;
        }
        if (awaitingResponse)
            respond();
        else if (Greetd.state === GreetdState.Inactive) {
            passwordSent = false;
            Greetd.createSession(username);
        }
    }

    function respond() {
        awaitingResponse = false;
        Greetd.respond(buffer);
        buffer = "";
    }

    function fail(message) {
        authenticating = false;
        awaitingResponse = false;
        promptText = "";
        errorText = message;
        buffer = "";
        shakeCount++;
    }

    function succeed() {
        authenticating = false;
        unlocking = true;
        GreeterMemory.remember(username, session?.id ?? "");
        launchTimer.start();
    }

    Connections {
        target: Greetd
        enabled: !root.preview

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired) {
                // informational / error text from PAM (fingerprint prompts, lockout notices…)
                if (error)
                    root.errorText = message;
                Greetd.respond("");
                return;
            }
            root.awaitingResponse = true;
            // the password typed before the session existed answers the first hidden prompt;
            // anything after that (OTP, token PIN…) is shown and answered from the field
            if (!root.passwordSent && !echoResponse && root.buffer !== "") {
                root.passwordSent = true;
                root.promptText = "";
                root.respond();
            } else {
                root.promptText = message;
                root.promptEcho = echoResponse;
                root.authenticating = false;
            }
        }

        function onAuthFailure(message) {
            root.fail(/locked|too many|maximum/i.test(message) ? message : "Wrong password");
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
        }

        function onReadyToLaunch() {
            root.succeed();
        }

        function onError(error) {
            root.fail("Login service error");
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
        }
    }

    // Let the exit animation play before handing the seat to the session.
    Timer {
        id: launchTimer
        interval: Theme.durXl + 50
        onTriggered: {
            const s = root.session;
            if (root.preview) {
                console.log("[Greeter] preview: would start", JSON.stringify(s.command), "as", root.username);
                Qt.quit();
                return;
            }
            Greetd.launch(s.command, s.env);
        }
    }

    // Preview: any password works except "wrong", so both paths can be seen.
    Timer {
        id: previewTimer
        interval: 700
        onTriggered: root.buffer === "wrong" ? root.fail("Wrong password") : root.succeed()
    }

    // ── loading ──
    Process {
        running: true
        command: [root.bin, "users", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.users = JSON.parse(text);
                } catch (e) {
                    console.warn("[Greeter] could not read users:", e);
                }
                root.usersLoaded = true;
            }
        }
    }

    Process {
        running: true
        command: [root.bin, "sessions", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sessions = JSON.parse(text);
                } catch (e) {
                    console.warn("[Greeter] could not read sessions:", e);
                }
                root.sessionsLoaded = true;
            }
        }
    }

    // Pick the remembered user/session once everything is in.
    onReadyChanged: {
        if (!ready)
            return;
        const ui = users.findIndex(u => u.name === GreeterMemory.lastUser);
        if (users.length === 0)
            manualUser = true;
        else
            userIndex = ui >= 0 ? ui : 0;
        const si = sessions.findIndex(s => s.id === GreeterMemory.lastSession);
        const niri = sessions.findIndex(s => /niri/i.test(s.id));
        sessionIndex = si >= 0 ? si : niri >= 0 ? niri : 0;
    }

    // ── per-user theme ──
    // Each synced user has users/<name>/settings.json; switching users pours
    // it into the shell's Settings so Theme cross-fades to their palette and
    // wallpaper, exactly as a palette change does on the desktop.
    FileView {
        id: themeFile
        path: root.user?.synced ? root.cacheDir + "/users/" + root.user.name + "/settings.json" : ""
        printErrors: false
        onLoaded: root.applyTheme(text())
    }

    function applyTheme(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return;
        }
        for (const section of ["general", "appearance", "wallpaper", "keyboard", "apps"]) {
            const target = Settings.data[section];
            const src = data[section];
            if (!target || !src)
                continue;
            for (const k in src)
                if (k in target && target[k] !== src[k])
                    target[k] = src[k];
        }
    }

    FileView {
        id: hostnameFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
    }
}
