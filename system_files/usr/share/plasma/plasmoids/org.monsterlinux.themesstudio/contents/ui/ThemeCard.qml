// One theme in the gallery. mine = one of your own saved themes (adds Rename and Delete).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

Rectangle {
    id: card
    property var studio
    property var item
    property bool mine: false
    property bool askDelete: false
    property bool renaming: false
    readonly property bool current: studio.themeName === item.n
    width: 228; height: mine ? 300 : 262; radius: 10
    color: studio.rack2
    border.color: current ? studio.led : studio.line
    border.width: current ? 2 : 1
    clip: true
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 1; spacing: 0
        Image {
            Layout.fillWidth: true; Layout.preferredHeight: 142
            source: card.mine ? card.studio.thumbOf(card.item) : card.studio.pkg + "/thumbs/" + card.item.thumb
            fillMode: Image.PreserveAspectCrop; asynchronous: true
            sourceSize.width: 456
            // little color strip so saved themes show their colors
            Row {
                visible: card.mine
                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 8; spacing: 4
                Repeater {
                    model: card.mine ? ["bg", "panel", "button", "text", "accent"] : []
                    Rectangle { width: 16; height: 16; radius: 8; color: card.item.state.c[modelData]; border.color: "#000000"; border.width: 1 }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 10; spacing: 4
            RowLayout {
                Layout.fillWidth: true
                visible: !card.renaming
                Text { Layout.fillWidth: true; text: card.item.n; color: card.studio.ink; font.family: card.studio.uiFont; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                Text { text: card.mine ? "MINE" : card.item.tag.toUpperCase(); color: card.mine ? card.studio.led : card.studio.dim; font.family: "monospace"; font.pixelSize: 9 }
            }
            QQC2.TextField {
                id: rn
                visible: card.renaming
                Layout.fillWidth: true; maximumLength: 40
                color: card.studio.ink; font.family: card.studio.uiFont; font.pixelSize: 13
                background: Rectangle { radius: 6; color: card.studio.room; border.color: card.studio.led; implicitHeight: 30 }
                onAccepted: card.studio.renameTheme(card.item, text, () => card.renaming = false)
                Keys.onEscapePressed: card.renaming = false
            }
            Text {
                Layout.fillWidth: true; Layout.fillHeight: true
                text: card.mine ? "Saved " + new Date(card.item.at || 0).toLocaleDateString(Qt.locale(), Locale.ShortFormat) : card.item.d
                color: card.studio.dim; font.family: card.studio.uiFont; font.pixelSize: 11; wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 2
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                StudioButton { studio: card.studio; text: card.current ? "On stage" : "Try it"; selected: card.current; Layout.fillWidth: true
                    onClicked: card.mine ? card.studio.loadMine(card.item) : card.studio.loadTheme(card.item) }
                StudioButton { studio: card.studio; text: "Apply"; primary: true; Layout.fillWidth: true; enabled: !card.studio.applying
                    onClicked: { card.mine ? card.studio.loadMine(card.item) : card.studio.loadTheme(card.item); card.studio.applyAll() } }
            }
            RowLayout {
                visible: card.mine
                Layout.fillWidth: true; spacing: 6
                StudioButton { studio: card.studio; Layout.fillWidth: true
                    text: card.renaming ? "Save name" : "Rename"
                    onClicked: {
                        if (card.renaming) card.studio.renameTheme(card.item, rn.text, () => card.renaming = false)
                        else { rn.text = card.item.n; card.renaming = true; rn.forceActiveFocus(); rn.selectAll() }
                    } }
                StudioButton { studio: card.studio; Layout.fillWidth: true
                    text: card.askDelete ? "Yes, delete" : "Delete"
                    onClicked: { if (card.askDelete) card.studio.deleteTheme(card.item); else { card.askDelete = true; undoAsk.restart() } } }
            }
        }
    }
    Timer { id: undoAsk; interval: 3500; onTriggered: card.askDelete = false }
}
