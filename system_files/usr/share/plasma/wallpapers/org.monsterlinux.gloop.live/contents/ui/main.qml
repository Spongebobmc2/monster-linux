// Monster Gloop Live: Gloop's eye glances around and blinks now and then.
import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    // Geometry of the painted scene (designed at 1920x1080, scaled to cover the screen)
    readonly property real sceneW: 1920
    readonly property real sceneH: 1080
    readonly property real s: Math.max(width / sceneW, height / sceneH)
    readonly property real ox: (width - sceneW * s) / 2
    readonly property real oy: (height - sceneH * s) / 2
    readonly property real eyeX: 1300
    readonly property real eyeY: 565

    // Where the eye can look (offset of the iris from the eye's center, in scene pixels)
    readonly property var looks: [
        [14, 13], [0, 0], [-32, 6], [32, -2], [-24, -22], [24, 22],
        [-36, 16], [10, -30], [-30, 4], [14, 13]
    ]
    property real lookX: 14
    property real lookY: 13

    Rectangle { anchors.fill: parent; color: "#0e140a" }

    Image {
        id: scene
        anchors.fill: parent
        source: Qt.resolvedUrl("../images/base.jpg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    // The moving iris and pupil
    Image {
        id: iris
        width: 140 * root.s
        height: 140 * root.s
        sourceSize.width: 280
        sourceSize.height: 280
        source: Qt.resolvedUrl("../images/iris.svg")
        smooth: true
        x: root.ox + (root.eyeX + root.lookX - 70) * root.s
        y: root.oy + (root.eyeY + root.lookY - 70) * root.s
    }

    // Slow, sneaky glances: the eye creeps over and settles gently
    Behavior on lookX { NumberAnimation { duration: 2800; easing.type: Easing.InOutSine } }
    Behavior on lookY { NumberAnimation { duration: 2800; easing.type: Easing.InOutSine } }

    // The eyelid: slides down from the top of the eye, then back up
    Item {
        id: lidClip
        x: root.ox + (root.eyeX - 104) * root.s
        y: root.oy + (root.eyeY - 104) * root.s
        width: 208 * root.s
        height: 0
        clip: true
        Image {
            width: 208 * root.s
            height: 208 * root.s
            sourceSize.width: 416
            sourceSize.height: 416
            source: Qt.resolvedUrl("../images/lid.svg")
            smooth: true
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.9
            height: Math.max(2, 5 * root.s)
            radius: height / 2
            color: "#0a1404"
            visible: lidClip.height > 4 && winkArc.opacity < 0.5
        }
    }

    // Wink: the eye closes into a happy curve and a sparkle pops out
    Image {
        id: winkArc
        x: lidClip.x; y: lidClip.y
        width: 208 * root.s; height: 208 * root.s
        sourceSize.width: 416; sourceSize.height: 416
        source: Qt.resolvedUrl("../images/wink.svg")
        opacity: 0
    }
    Image {
        id: sparkle
        width: 80 * root.s; height: 80 * root.s
        sourceSize.width: 160; sourceSize.height: 160
        x: root.ox + (root.eyeX + 118 - 40) * root.s
        y: root.oy + (root.eyeY - 96 - 40) * root.s
        source: Qt.resolvedUrl("../images/sparkle.svg")
        scale: 0
        rotation: 0
    }

    SequentialAnimation {
        id: wink
        NumberAnimation { target: lidClip; property: "height"; to: 208 * root.s; duration: 110; easing.type: Easing.InQuad }
        PropertyAction { target: winkArc; property: "opacity"; value: 1 }
        ParallelAnimation {
            NumberAnimation { target: sparkle; property: "scale"; from: 0; to: 1; duration: 260; easing.type: Easing.OutBack }
            NumberAnimation { target: sparkle; property: "rotation"; from: -30; to: 20; duration: 700 }
        }
        PauseAnimation { duration: 380 }
        NumberAnimation { target: sparkle; property: "scale"; to: 0; duration: 200; easing.type: Easing.InQuad }
        PropertyAction { target: winkArc; property: "opacity"; value: 0 }
        NumberAnimation { target: lidClip; property: "height"; to: 0; duration: 170; easing.type: Easing.OutQuad }
    }

    Timer {
        id: winkTimer
        interval: 12000
        running: true
        repeat: true
        onTriggered: {
            if (!blink.running && !wink.running) wink.start()
            interval = 20000 + Math.random() * 40000
        }
    }

    SequentialAnimation {
        id: blink
        NumberAnimation { target: lidClip; property: "height"; to: 208 * root.s; duration: 90; easing.type: Easing.InQuad }
        PauseAnimation { duration: 60 }
        NumberAnimation { target: lidClip; property: "height"; to: 0; duration: 130; easing.type: Easing.OutQuad }
    }

    Timer {
        id: lookTimer
        interval: 6000
        running: true
        repeat: true
        onTriggered: {
            var next = root.looks[Math.floor(Math.random() * root.looks.length)]
            root.lookX = next[0]
            root.lookY = next[1]
            interval = 5500 + Math.random() * 8000
            
        }
    }

    Timer {
        id: blinkTimer
        interval: 4200
        running: true
        repeat: true
        onTriggered: {
            if (!blink.running && !wink.running) {
                blink.loops = Math.random() < 0.2 ? 2 : 1
                blink.start()
            }
            interval = 3000 + Math.random() * 5000
        }
    }
}
