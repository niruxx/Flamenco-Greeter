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
    // in a window instead of full-screen layers: previews, and testing against greetd from a desktop
    readonly property bool windowed: preview || Quickshell.env("FLAMENCO_GREETER_WINDOWED") === "1"
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
    property bool passwordSent: false    // something typed has answered a prompt in this session

    // ── fingerprint ──
    // A reader plus pam_fprintd in greetd's PAM stack (`flamenco-greeter fingerprint --json`).
    // When both are there, a PAM session opens as soon as a user is picked:
    // pam_fprintd checks that user's enrolled prints (as root) and starts the
    // reader, or falls straight through to the password prompt, which is then
    // held until Enter.
    readonly property bool previewFingerprint: Quickshell.env("FLAMENCO_GREETER_PREVIEW_FINGERPRINT") === "1"
    property bool fingerprintAvailable: preview && previewFingerprint
    property bool scanning: false        // the reader is waiting for a finger
    property bool sawFingerprint: false  // this PAM session went through the reader
    property int fingerprintMisses: 0    // listening stops after too many, until the user is picked again
    readonly property int maxMisses: 6

    // ── talking to greetd ──
    // greetd answers one request at a time, and only once the PAM step behind
    // it is done. While pam_fprintd waits for a finger it's mid-step, so
    // anything sent then (a cancel, a new session) queues behind the scan and
    // its reply arrives late. Quickshell's cancelSession() also reports
    // Inactive straight away, before greetd has acknowledged, so a session
    // started right after can mistake that acknowledgement for its own
    // "success". So: never cancel mid-step (wait for greetd to answer), and
    // leave a moment between a cancel and the next session.
    property bool inFlight: false        // greetd owes us a reply
    property bool cancelWanted: false    // drop the session as soon as greetd answers
    property string mode: ""             // what the current PAM session is for: "fingerprint" | "password"
    property string pendingMode: ""      // the session to start once greetd is idle

    readonly property string hostName: hostnameFile.text().trim()

    function selectUser(i) {
        cancel();
        manualUser = false;
        userIndex = i;
        fingerprintMisses = 0;
        Qt.callLater(listen);
    }

    function selectManual() {
        cancel();
        manualUser = true;
        manualName = "";
        fingerprintMisses = 0;
    }

    function selectSession(i) {
        sessionIndex = i;
    }

    // Esc / switching users: drop the current attempt, then listen again.
    function reset() {
        cancel();
        Qt.callLater(listen);
    }

    function cancel() {
        pendingMode = "";
        stopSession();
        mode = "";
        scanning = false;
        sawFingerprint = false;
        authenticating = false;
        awaitingResponse = false;
        promptText = "";
        buffer = "";
        errorText = "";
    }

    function stopSession() {
        if (preview || Greetd.state === GreetdState.Inactive)
            return;
        if (inFlight) {
            cancelWanted = true;     // greetd is busy inside PAM; cancel once it answers
            return;
        }
        cancelWanted = false;
        Greetd.cancelSession();      // → Inactive → onStateChanged starts any pending session
    }

    // Start listening on the reader for the selected user.
    function listen() {
        if (!fingerprintAvailable || !ready || unlocking || authenticating || username === "")
            return;
        if (fingerprintMisses >= maxMisses)
            return;
        restart("fingerprint");
    }

    function restart(nextMode) {
        pendingMode = nextMode;
        if (preview || (Greetd.state === GreetdState.Inactive && !inFlight)) {
            if (!beginTimer.running)
                Qt.callLater(begin);
        } else {
            stopSession();
        }
    }

    function begin() {
        const m = pendingMode;
        if (!m || username === "" || unlocking)
            return;
        if (!preview && (Greetd.state !== GreetdState.Inactive || inFlight))
            return;                  // still winding down; onStateChanged tries again
        pendingMode = "";
        mode = m;
        passwordSent = false;
        sawFingerprint = false;
        scanning = false;
        awaitingResponse = false;
        promptText = "";
        if (preview) {
            previewBegin(m);
        } else {
            inFlight = true;
            Greetd.createSession(username);
        }
    }

    function submit() {
        if (authenticating || unlocking || username === "")
            return;
        if (!session) {
            fail("No desktop sessions installed");
            return;
        }
        // Enter on an empty field shouldn't stop a fingerprint scan
        if (buffer === "" && scanning)
            return;
        errorText = "";
        authenticating = true;
        relistenTimer.stop();
        if (awaitingResponse)
            respond();
        else if (preview && scanning)
            previewRoundTimer.restart();
        else if (preview || Greetd.state === GreetdState.Inactive || cancelWanted)
            restart("password");
        // otherwise a fingerprint scan is mid-round: the password answers the
        // prompt it hands over to, and a finger still works in the meantime
    }

    function respond() {
        awaitingResponse = false;
        passwordSent = true;
        if (preview) {
            previewTimer.restart();
        } else {
            inFlight = true;
            Greetd.respond(buffer);
        }
    }

    function fail(message) {
        authenticating = false;
        awaitingResponse = false;
        scanning = false;
        promptText = "";
        errorText = message;
        buffer = "";
        shakeCount++;
        relistenTimer.restart();
        errorTimer.restart();
    }

    // A finger that didn't match: say so, but keep what's typed and keep listening.
    function fingerprintMiss() {
        if (authenticating)
            return;                  // a password is already on its way
        fingerprintMisses++;
        if (fingerprintMisses >= maxMisses)
            scanning = false;        // stop offering the reader until the user is picked again
        errorText = fingerprintMisses >= maxMisses ? "Too many tries, enter your password" : "Fingerprint not recognized";
        shakeCount++;
        errorTimer.restart();
    }

    function succeed() {
        relistenTimer.stop();
        authenticating = false;
        scanning = false;
        errorText = "";
        unlocking = true;
        GreeterMemory.remember(username, session?.id ?? "");
        launchTimer.start();
    }

    Connections {
        target: Greetd
        enabled: !root.preview

        function onStateChanged() {
            if (Greetd.state !== GreetdState.Inactive)
                return;
            root.scanning = false;
            if (root.pendingMode)
                beginTimer.restart();
        }

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (root.cancelWanted) {
                // what's left of an attempt being dropped
                if (responseRequired) {
                    root.inFlight = false;
                    root.stopSession();
                }
                return;
            }
            if (!responseRequired) {
                // Quickshell acknowledges these itself, and greetd stays mid-step.
                // Before anything typed is asked for, they come from the reader:
                // "place your finger…" (info) or a failed match (error). PAM's
                // wording is translated and varies, so we use our own.
                if (root.fingerprintAvailable && !root.passwordSent) {
                    root.sawFingerprint = true;
                    if (error)
                        root.fingerprintMiss();
                    else
                        root.scanning = true;
                } else if (error) {
                    root.errorText = message;
                }
                return;
            }

            root.inFlight = false;
            root.scanning = false;
            root.awaitingResponse = true;
            if (!root.passwordSent && !echoResponse) {
                // the first hidden prompt is the password
                root.promptText = "";
                if (root.authenticating && root.buffer !== "") {
                    root.respond();
                } else {
                    root.authenticating = false;
                    // the reader gave up (timed out, or a miss): listen again,
                    // unless the user has started typing their password
                    if (root.sawFingerprint)
                        relistenTimer.restart();
                }
            } else {
                // anything after that (OTP, token PIN…) is shown and answered from the field
                root.promptText = message;
                root.promptEcho = echoResponse;
                root.authenticating = false;
                root.buffer = "";
            }
        }

        function onAuthFailure(message) {
            root.inFlight = false;
            if (root.cancelWanted) {
                root.cancelWanted = false;
                return;              // the attempt was being dropped anyway
            }
            root.fail(/locked|too many|maximum/i.test(message) ? message : root.passwordSent ? "Wrong password" : "Couldn't sign in");
        }

        function onReadyToLaunch() {
            root.inFlight = false;
            if (root.cancelWanted) {
                root.stopSession();  // e.g. a finger for the user that was just switched away from
                return;
            }
            root.succeed();
        }

        function onError(error) {
            root.inFlight = false;
            if (root.cancelWanted) {
                root.cancelWanted = false;
                return;
            }
            root.fail("Login service error");
        }
    }

    // Gap between a cancel and the next session, so greetd's acknowledgement
    // of the cancel isn't read as the new session's result.
    Timer {
        id: beginTimer
        interval: 500
        onTriggered: root.begin()
    }

    // Start a new round on the reader shortly after one ends without a match.
    Timer {
        id: relistenTimer
        interval: 1200
        onTriggered: {
            if (root.buffer === "" && !root.authenticating && !root.unlocking)
                root.listen();
        }
    }

    // once the reader is listening again, go back to "Scan your finger…"
    Timer {
        id: errorTimer
        interval: 2500
        onTriggered: {
            if (root.scanning && root.buffer === "" && root.fingerprintMisses < root.maxMisses)
                root.errorText = "";
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

    // ── preview ──
    // No greetd: any password but "wrong" works, and `--fingerprint` fakes a
    // reader that `ipc call greeter finger true|false` touches.
    function previewBegin(m) {
        if (m === "fingerprint") {
            sawFingerprint = true;
            scanning = true;
        } else {
            awaitingResponse = true;
            respond();
        }
    }

    function previewFinger(match) {
        if (!scanning)
            return;
        if (match) {
            previewRoundTimer.stop();
            succeed();
        } else {
            fingerprintMiss();
        }
    }

    // a password entered mid-scan waits for the round to end, as with pam_fprintd
    Timer {
        id: previewRoundTimer
        interval: 2000
        onTriggered: {
            root.scanning = false;
            root.awaitingResponse = true;
            root.respond();
        }
    }

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

    Process {
        running: !root.preview
        command: [root.bin, "fingerprint", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const fp = JSON.parse(text);
                    root.fingerprintAvailable = fp.pam && fp.readers > 0;
                } catch (e) {
                    console.warn("[Greeter] could not read fingerprint state:", e);
                }
                Qt.callLater(root.listen);
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
        Qt.callLater(listen);
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
