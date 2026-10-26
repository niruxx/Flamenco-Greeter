import QtQuick
import QtMultimedia

// A live (video) wallpaper, looping and muted. Its own file, loaded by URL
// (like Flamenco Shell's LiveVideo), so without Qt Multimedia only this fails
// and the login screen keeps showing the video's still.
Item {
    id: root

    property string url
    property real speed: 1
    property int fillMode: Image.PreserveAspectCrop
    // the first frame is up, so it can fade in over the still
    property bool started: false

    // the url arrives after creation (the Loader binds it), so start playing then
    onUrlChanged: if (url) player.play()

    MediaPlayer {
        id: player
        source: root.url
        loops: MediaPlayer.Infinite
        playbackRate: Math.max(0.25, Math.min(2, root.speed))
        videoOutput: out
        onPositionChanged: if (position > 0) root.started = true
        onErrorOccurred: (error, errorString) => console.warn("[Greeter] live wallpaper:", errorString, root.url)
        Component.onCompleted: if (root.url) play()
    }
    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: root.fillMode === Image.Stretch ? VideoOutput.Stretch : root.fillMode === Image.PreserveAspectFit ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
    }
}
