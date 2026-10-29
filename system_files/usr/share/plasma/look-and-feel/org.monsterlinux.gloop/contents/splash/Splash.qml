import QtQuick

Rectangle {
    id: root
    color: "#0e140a"
    property int stage

    onStageChanged: {
        if (stage == 2) { intro.running = true }
    }

    Image {
        anchors.fill: parent
        source: "file:///usr/share/wallpapers/MonsterGloop/contents/images/1920x1080.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.25
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: logo.width
        height: logo.height + label.height + bar.height + 60
        opacity: 0

        Image {
            id: logo
            width: 180; height: 180
            sourceSize.width: 360; sourceSize.height: 360
            anchors.horizontalCenter: parent.horizontalCenter
            source: blinkTimer.closed ? "images/gloop-blink.svg" : "images/gloop.svg"

            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: -12; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: -12; to: 0; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        Text {
            id: label
            anchors.top: logo.bottom
            anchors.topMargin: 28
            anchors.horizontalCenter: parent.horizontalCenter
            text: "MONSTER LINUX"
            color: "#dde6cf"
            font.pixelSize: 26
            font.letterSpacing: 6
            font.bold: true
        }

        Rectangle {
            id: bar
            anchors.top: label.bottom
            anchors.topMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            width: 220; height: 6; radius: 3
            color: "#1a2412"
            Rectangle {
                height: parent.height; radius: 3
                color: "#a8e03a"
                width: parent.width * Math.min(1, (root.stage + 1) / 6)
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    Timer {
        id: blinkTimer
        property bool closed: false
        interval: closed ? 140 : 2600
        running: true; repeat: true
        onTriggered: closed = !closed
    }

    OpacityAnimator {
        id: intro
        target: content
        from: 0; to: 1
        duration: 600
        easing.type: Easing.InOutQuad
    }

    Component.onCompleted: intro.running = true
}
