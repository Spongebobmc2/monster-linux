// Theme Gallery: all the ready-made looks, grouped. Try = put it on the stage. Apply = use it now.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import "../code/themes.js" as T

QQC2.ScrollView {
    id: page
    property var studio
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: page.availableWidth
        spacing: 22

        PageHeader { studio: page.studio; title: "Theme Gallery"; note: "Pick a look to try it on the stage. You can change anything about it in the other sections before you apply it." }

        Repeater {
            model: T.GROUPS
            delegate: ColumnLayout {
                id: grp
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                RowLayout {
                    spacing: 10
                    Text { text: grp.modelData.title; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 17; font.bold: true }
                    Text { text: grp.modelData.items.length + (grp.modelData.items.length > 1 ? " THEMES" : " THEME"); color: page.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1.5 }
                }
                Text { text: grp.modelData.note; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 12 }
                Flow {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: grp.modelData.items
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool current: page.studio.themeName === modelData.n
                            width: 228; height: 262; radius: 10
                            color: page.studio.rack2
                            border.color: current ? page.studio.led : page.studio.line
                            border.width: current ? 2 : 1
                            clip: true
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 1; spacing: 0
                                Image {
                                    Layout.fillWidth: true; Layout.preferredHeight: 142
                                    source: page.studio.pkg + "/thumbs/" + card.modelData.thumb
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                    sourceSize.width: 456
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 10; spacing: 4
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { Layout.fillWidth: true; text: card.modelData.n; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                                        Text { text: card.modelData.tag.toUpperCase(); color: page.studio.dim; font.family: "monospace"; font.pixelSize: 9 }
                                    }
                                    Text { Layout.fillWidth: true; Layout.fillHeight: true; text: card.modelData.d; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 11; wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 2 }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        StudioButton { studio: page.studio; text: card.current ? "On stage" : "Try it"; selected: card.current; Layout.fillWidth: true; onClicked: page.studio.loadTheme(card.modelData) }
                                        StudioButton { studio: page.studio; text: "Apply"; primary: true; Layout.fillWidth: true; enabled: !page.studio.applying
                                            onClicked: { page.studio.loadTheme(card.modelData); page.studio.applyAll() } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
