// Colors: the 12 colors KDE uses everywhere. Click a swatch to open the color spectrum, or type a hex code.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

QQC2.ScrollView {
    id: page
    property var studio
    property string editing: "accent"
    contentWidth: availableWidth
    clip: true

    ColorDialog {
        id: picker
        title: "Pick a color"
        onAccepted: if (page.editing) { page.studio.setColor(page.editing, selectedColor.toString()); spectrum.loadFrom(selectedColor.toString()) }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 14

        PageHeader { studio: page.studio; title: "Colors"; note: "Click a square, then drag in the color spectrum below to change it. The stage on the right changes as you go." }

        Repeater {
            model: [["Surfaces", ["bg", "bg2", "view", "panel", "button"]], ["Words", ["text", "muted", "link"]], ["Highlights", ["accent", "ok", "warn", "err"]]]
            delegate: ColumnLayout {
                id: grp
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Text { text: grp.modelData[0].toUpperCase(); color: page.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2 }
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.availableWidth > 620 ? 2 : 1
                    columnSpacing: 8; rowSpacing: 8
                    Repeater {
                        model: grp.modelData[1]
                        delegate: Rectangle {
                            id: row
                            required property string modelData
                            readonly property var info: page.studio.slots.find(s => s[0] === modelData)
                            Layout.fillWidth: true
                            implicitHeight: 54; radius: 8
                            color: page.editing === row.modelData ? "#1f2a14" : page.studio.rack2
                            border.color: page.editing === row.modelData ? page.studio.led : page.studio.line
                            function choose() { page.editing = row.modelData; spectrum.open(row.modelData, row.info[1]); page.contentItem.contentY = Math.max(0, spectrum.y - 40) }
                            // the whole row is clickable (the hex box on the right still takes typing)
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.choose() }
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 7
                                    color: page.studio.st.c[row.modelData]
                                    border.width: page.editing === row.modelData ? 3 : 1
                                    border.color: page.editing === row.modelData ? page.studio.led : "#ffffff33"
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.choose() }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { text: row.info[1]; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignLeft; elide: Text.ElideRight }
                                    Text { visible: row.info[2] !== ""; text: row.info[2]; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                QQC2.TextField {
                                    Layout.preferredWidth: 86
                                    text: page.studio.st.c[row.modelData].toUpperCase()
                                    font.family: "monospace"
                                    maximumLength: 7
                                    onEditingFinished: {
                                        let v = text.trim(); if (!v.startsWith("#")) v = "#" + v
                                        if (/^#[0-9a-fA-F]{6}$/.test(v)) page.studio.setColor(row.modelData, v)
                                        else text = page.studio.st.c[row.modelData].toUpperCase()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // quick accent picks
        Text { text: "QUICK ACCENT"; color: page.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2 }
        Flow {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: ["#a8e03a", "#e8a23d", "#ff8fb8", "#36c8e0", "#4cc2ff", "#a24bff", "#ff5a4a", "#ffd23f", "#6aa84f", "#ffffff"]
                delegate: Rectangle {
                    required property string modelData
                    width: 34; height: 34; radius: 17; color: modelData
                    border.width: page.studio.st.c.accent === modelData ? 3 : 1
                    border.color: page.studio.st.c.accent === modelData ? page.studio.ink : "#ffffff33"
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { page.studio.setColor("accent", modelData); if (page.editing === "accent") spectrum.loadFrom(modelData) } }
                }
            }
        }
        // color spectrum: always here, edits whichever square is selected (Accent to start)
        SpectrumPicker {
            id: spectrum
            studio: page.studio
            Layout.fillWidth: true
            Layout.topMargin: 6
            showDone: false
            onMoreOptions: { picker.selectedColor = page.studio.st.c[page.editing]; picker.open() }
            Component.onCompleted: open("accent", "Accent")
        }
        Item { Layout.preferredHeight: 10 }
    }
}
