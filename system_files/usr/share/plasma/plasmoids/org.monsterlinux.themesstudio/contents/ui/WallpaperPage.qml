// Wallpaper: the moving Gloop, every theme's scene, the PC's own wallpapers, or any picture.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import "../code/themes.js" as T

QQC2.ScrollView {
    id: page
    property var studio
    readonly property var st: studio.st
    property var installed: []
    contentWidth: availableWidth
    clip: true

    function pick(path) { const s = JSON.parse(JSON.stringify(st)); studio.snapshot(); s.wallKind = "image"; s.wallPath = path; studio.st = s }
    function live() { const s = JSON.parse(JSON.stringify(st)); studio.snapshot(); s.wallKind = "live"; studio.st = s }

    Component.onCompleted: studio.run(["list", "wallpapers"], out => page.installed = out.split("\n").filter(x => x))

    FileDialog {
        id: own
        title: "Choose a picture"
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp *.bmp *.gif *.svg)"]
        onAccepted: page.pick(decodeURIComponent(selectedFile.toString().replace("file://", "")))
    }

    component Tile: Rectangle {
        id: tile
        property string src: ""
        property string label: ""
        property bool on: false
        signal picked()
        width: 168; height: 122; radius: 8
        color: page.studio.rack2
        border.color: on ? page.studio.led : page.studio.line
        border.width: on ? 2 : 1
        clip: true
        Image { x: 1; y: 1; width: parent.width - 2; height: 94; source: tile.src; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 336 }
        Text { x: 8; y: 100; width: parent.width - 16; text: tile.label; color: tile.on ? page.studio.led : page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 12; elide: Text.ElideRight }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tile.picked() }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 14

        PageHeader { studio: page.studio; title: "Wallpaper"; note: "Your desktop picture. The lock screen uses the same one." }

        RowLayout {
            spacing: 8
            StudioButton { studio: page.studio; text: "Choose my own picture…"; primary: true; onClicked: own.open() }
            Text { text: page.st.wallKind === "live" ? "Now: Gloop with the moving eye" : "Now: " + (page.st.wallPath || "").split("/").pop()
                   color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 12; elide: Text.ElideMiddle; Layout.fillWidth: true }
        }

        Text { text: "MOVING"; color: page.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2 }
        Flow {
            Layout.fillWidth: true; spacing: 10
            Tile { src: page.studio.pkg + "/wallpapers/monster-gloop.png"; label: "Gloop (eye moves and winks)"; on: page.st.wallKind === "live"; onPicked: page.live() }
        }

        Text { text: "THEME SCENES"; color: page.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2 }
        Flow {
            Layout.fillWidth: true; spacing: 10
            Repeater {
                model: [].concat(...T.GROUPS.map(g => g.items))
                delegate: Tile {
                    required property var modelData
                    readonly property string path: page.studio.pkg + "/wallpapers/" + modelData.wallpaper
                    src: "file://" + path; label: modelData.n
                    on: page.st.wallKind === "image" && page.st.wallPath === path
                    onPicked: page.pick(path)
                }
            }
        }

        Text { visible: page.installed.length > 0; text: "ON THIS PC"; color: page.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2 }
        Flow {
            Layout.fillWidth: true; spacing: 10
            Repeater {
                model: page.installed
                delegate: Tile {
                    required property string modelData
                    src: "file://" + modelData
                    label: modelData.indexOf("/contents/images/") > 0 ? modelData.split("/contents/")[0].split("/").pop() : modelData.split("/").pop()
                    on: page.st.wallKind === "image" && page.st.wallPath === modelData
                    onPicked: page.pick(modelData)
                }
            }
        }
        Item { Layout.preferredHeight: 10 }
    }
}
