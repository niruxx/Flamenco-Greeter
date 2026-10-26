import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services
import qs.Widgets

// What's behind the login card on one screen: a color, a picture, or a live
// wallpaper (video or GIF) playing over its still, then blurred and dimmed.
// Which one comes from Greeter.backdrop(): Flamenco Shell's Lock & Login
// settings, or the selected user's synced desktop wallpaper.
Item {
    id: root

    property string screenName: ""
    readonly property var b: Greeter.backdrop(screenName)
    readonly property int fill: b.fill === "fit" ? Image.PreserveAspectFit : b.fill === "stretch" ? Image.Stretch : Image.PreserveAspectCrop
    readonly property bool liveVideo: b.live !== "" && Greeter.isVideo(b.live)

    // the still cross-fades when it changes (another user's theme, Apply in the shell)
    readonly property string still: b.still
    property bool showB: false
    onStillChanged: {
        if (showB)
            wallA.source = Paths.toUrl(still);
        else
            wallB.source = Paths.toUrl(still);
        showB = !showB;
    }

    Item {
        id: content
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            visible: root.b.color === ""
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.surfaceHigh }
                GradientStop { position: 1; color: Theme.bg }
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: root.b.color !== ""
            color: root.b.color || Theme.bg
        }
        Image {
            id: wallA
            anchors.fill: parent
            fillMode: root.fill
            asynchronous: true
            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            source: Paths.toUrl(root.still)
            opacity: root.showB ? 0 : 1
            Behavior on opacity { Anim { duration: Theme.durXl } }
        }
        Image {
            id: wallB
            anchors.fill: parent
            fillMode: root.fill
            asynchronous: true
            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            opacity: root.showB ? 1 : 0
            Behavior on opacity { Anim { duration: Theme.durXl } }
        }

        // live: the video fades in over its still once it's actually playing
        Loader {
            id: video
            anchors.fill: parent
            active: root.liveVideo
            source: active ? "GreeterLiveVideo.qml" : ""
            opacity: item?.started ? 1 : 0
            Behavior on opacity { Anim { duration: Theme.durLong } }
            onLoaded: {
                item.url = Qt.binding(() => Paths.toUrl(root.b.live));
                item.speed = Qt.binding(() => root.b.speed);
                item.fillMode = Qt.binding(() => root.fill);
            }
        }
        Loader {
            anchors.fill: parent
            active: root.b.live !== "" && !root.liveVideo
            sourceComponent: AnimatedImage {
                source: Paths.toUrl(root.b.live)
                fillMode: root.fill
                speed: root.b.speed
                playing: true
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: content
        blurEnabled: root.b.blur > 0
        blurMax: 64
        blur: root.b.blur
        brightness: -0.18 * root.b.blur
        saturation: -0.1 * root.b.blur
        // a little larger while blurred, so the blur's soft edge stays off screen
        scale: 1 + 0.06 * root.b.blur
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: root.b.dim
    }
}
