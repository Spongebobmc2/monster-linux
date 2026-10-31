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

        // ---- your own saved themes ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            RowLayout {
                spacing: 10
                Text { text: "My Themes"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 17; font.bold: true }
                Text { text: page.studio.myThemes.length + (page.studio.myThemes.length === 1 ? " THEME" : " THEMES"); color: page.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1.5 }
                Item { Layout.fillWidth: true }
                StudioButton { studio: page.studio; text: "Save current as new"; onClicked: page.studio.openSave() }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: page.studio.myThemes.length ? "Your saved looks. Try one, apply it, rename it or delete it."
                                                  : "Nothing saved yet. Change anything you like, then press Save theme and give it a name. It shows up here."
                color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 12
            }
            Flow {
                Layout.fillWidth: true
                spacing: 12
                visible: page.studio.myThemes.length > 0
                Repeater {
                    model: page.studio.myThemes
                    delegate: ThemeCard { required property var modelData; studio: page.studio; item: modelData; mine: true }
                }
            }
        }

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
                        delegate: ThemeCard { required property var modelData; studio: page.studio; item: modelData }
                    }
                }
            }
        }
    }
}
