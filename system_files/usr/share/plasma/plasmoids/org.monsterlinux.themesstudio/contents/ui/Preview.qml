// The live stage: a small Monster Linux desktop drawn with the theme being designed.
// Drawn at 480x300 and scaled to fit, so everything keeps its proportions.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: pv
    property var studio
    readonly property var st: studio.st
    readonly property var c: st.c
    readonly property real k: width / 480
    readonly property real r: st.icons === "round" ? 0.5 : (st.icons === "rounded" ? 0.3 : 0.16)
    readonly property real winR: st.icons === "square" ? 3 : 7

    Rectangle {
        id: frame
        width: 480; height: 300
        scale: pv.k
        transformOrigin: Item.TopLeft
        radius: 8
        color: "#050605"
        clip: true

        // wallpaper
        Image {
            anchors.fill: parent
            source: pv.st.wallKind === "live" ? pv.studio.pkg + "/wallpapers/monster-gloop.png" : (pv.st.wallPath ? "file://" + pv.st.wallPath : "")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 960
        }
        Rectangle {
            visible: pv.st.wallKind === "live"
            x: 10; y: 10; radius: 4; color: "#000000aa"; width: liveTxt.implicitWidth + 12; height: 20
            Text { id: liveTxt; anchors.centerIn: parent; text: "Moving eye"; color: "#e6ff6b"; font.pixelSize: 10 }
        }

        // terminal window (behind)
        Rectangle {
            x: 22; y: 22; width: 220; height: 130; radius: pv.winR
            color: pv.c.view; opacity: pv.st.opIn / 100; clip: true
            border.color: "#00000055"
            Rectangle { width: parent.width; height: 20; color: pv.c.panel
                Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: "Terminal"; color: pv.c.text; font.family: pv.st.font; font.pixelSize: 10; font.bold: pv.st.bold }
                Row { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Repeater { model: 3; delegate: Rectangle { required property int index; width: 7; height: 7; radius: 4; color: index === 2 ? pv.c.err : pv.c.muted } } }
            }
            Column {
                x: 8; y: 28; spacing: 2
                Text { text: "monster@bazzite:~$ fastfetch"; color: pv.c.accent; font.family: pv.st.mono; font.pixelSize: 9 }
                Text { text: "  Theme   " + pv.studio.themeName; color: pv.c.text; font.family: pv.st.mono; font.pixelSize: 9 }
                Text { text: "  Fonts   " + pv.st.font; color: pv.c.muted; font.family: pv.st.mono; font.pixelSize: 9 }
                Text { text: "  ✓ network ok"; color: pv.c.ok; font.family: pv.st.mono; font.pixelSize: 9 }
            }
        }

        // files window (front)
        Rectangle {
            x: 96; y: 52; width: 290; height: 186; radius: pv.winR
            color: pv.c.bg; opacity: pv.st.op / 100; clip: true
            border.color: "#00000066"
            Rectangle { id: tb; width: parent.width; height: 22; color: pv.c.panel
                Text { x: 9; anchors.verticalCenter: parent.verticalCenter; text: "Files: Home"; color: pv.c.text; font.family: pv.st.font; font.pixelSize: pv.st.size + 1; font.bold: pv.st.bold }
                Row { anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Repeater { model: 3; delegate: Rectangle { required property int index; width: 8; height: 8; radius: 4; color: index === 2 ? pv.c.err : pv.c.muted } } }
            }
            Rectangle {
                y: tb.height; width: 82; height: parent.height - tb.height; color: pv.c.bg2
                Column {
                    x: 6; y: 8; spacing: 3; width: parent.width - 12
                    Repeater {
                        model: ["Recent", "Home", "Games", "Pictures", "Downloads"]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width; height: 18; radius: 4
                            color: index === 1 ? pv.c.accent : "transparent"
                            Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: modelData; font.family: pv.st.font; font.pixelSize: pv.st.size
                                   color: index === 1 ? pv.studio.onAccent(pv.c.accent) : pv.c.text; font.bold: index === 1 }
                        }
                    }
                }
            }
            Rectangle {
                x: 82; y: tb.height; width: parent.width - 82; height: parent.height - tb.height; color: pv.c.view
                Column {
                    x: 12; y: 10; spacing: 7; width: parent.width - 24
                    Text { text: "Welcome to Monster Linux"; color: pv.c.text; font.family: pv.st.font; font.pixelSize: pv.st.size + 4; font.bold: pv.st.bold; width: parent.width; elide: Text.ElideRight }
                    Text { text: "This is how your apps will look."; color: pv.c.muted; font.family: pv.st.font; font.pixelSize: pv.st.size; width: parent.width; wrapMode: Text.WordWrap }
                    Text { text: "Links look like this"; color: pv.c.link; font.family: pv.st.font; font.pixelSize: pv.st.size; font.underline: true }
                    Row {
                        spacing: 6
                        Rectangle { width: 70; height: 22; radius: 4; color: pv.c.bg; border.color: pv.c.muted
                            Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: "Search…"; color: pv.c.muted; font.family: pv.st.font; font.pixelSize: pv.st.size - 1 } }
                        Rectangle { width: 50; height: 22; radius: 4; color: pv.c.accent
                            Text { anchors.centerIn: parent; text: "Open"; color: pv.studio.onAccent(pv.c.accent); font.family: pv.st.font; font.pixelSize: pv.st.size; font.bold: true } }
                        Rectangle { width: 54; height: 22; radius: 4; color: pv.c.button
                            Text { anchors.centerIn: parent; text: "Cancel"; color: pv.c.text; font.family: pv.st.font; font.pixelSize: pv.st.size } }
                    }
                    Rectangle { width: parent.width; height: 6; radius: 3; color: pv.c.bg2
                        Rectangle { width: parent.width * 0.62; height: parent.height; radius: 3; color: pv.c.accent } }
                    Row {
                        spacing: 5
                        Repeater {
                            model: [["Updated", "ok"], ["Low space", "warn"], ["Offline", "err"]]
                            delegate: Rectangle {
                                required property var modelData
                                width: chip.implicitWidth + 12; height: 17; radius: 9; color: "transparent"; border.color: pv.c[modelData[1]]
                                Text { id: chip; anchors.centerIn: parent; text: modelData[0]; color: pv.c[modelData[1]]; font.family: pv.st.font; font.pixelSize: 9; font.bold: true }
                            }
                        }
                    }
                }
            }
        }

        // taskbar
        Rectangle {
            x: 8; y: parent.height - 32; width: parent.width - 16; height: 26; radius: pv.winR + 2
            color: pv.c.panel; opacity: pv.st.panel === "opaque" ? 1 : 0.86
            Row {
                x: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Image { source: pv.studio.pkg + "/code/gloop.svg"; sourceSize.width: 20; sourceSize.height: 20; width: 20; height: 20 }
                Repeater {
                    model: [["#7fb6ff", "system-file-manager"], ["#ff9a4a", "internet-web-browser"], ["#3a4a66", "steam"], ["#2b2f35", "utilities-terminal"], ["#9aa3ad", "preferences-system"]]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 18; height: 18; radius: width * pv.r; color: modelData[0]
                        Kirigami.Icon { anchors.centerIn: parent; width: 12; height: 12; source: modelData[1]; color: "#ffffff"; isMask: true }
                        Rectangle { visible: index < 2; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 1; width: 8; height: 2; radius: 1; color: pv.c.accent }
                    }
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: "7:46 PM"; color: pv.c.text; font.family: pv.st.font; font.pixelSize: 10
            }
        }
    }
}
