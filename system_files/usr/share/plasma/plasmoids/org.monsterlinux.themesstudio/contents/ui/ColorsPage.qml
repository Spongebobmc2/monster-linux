// Colors: the 12 colors KDE uses everywhere. Click a swatch to pick, or type a hex code.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

QQC2.ScrollView {
    id: page
    property var studio
    property string editing: ""
    contentWidth: availableWidth
    clip: true

    ColorDialog {
        id: picker
        title: "Pick a color"
        onAccepted: if (page.editing) page.studio.setColor(page.editing, selectedColor.toString())
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 14

        PageHeader { studio: page.studio; title: "Colors"; note: "Click a square to pick a new color. The stage on the right changes as you go." }

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
                            color: page.studio.rack2; border.color: page.studio.line
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 7
                                    color: page.studio.st.c[row.modelData]
                                    border.color: "#ffffff33"
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: { page.editing = row.modelData; picker.selectedColor = page.studio.st.c[row.modelData]; picker.open() } }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { text: row.info[1]; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
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
                    TapHandler { onTapped: page.studio.setColor("accent", modelData) }
                }
            }
        }
        Item { Layout.preferredHeight: 10 }
    }
}
