// More: bring back KDE's own appearance pages, and start over.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

QQC2.ScrollView {
    id: page
    property var studio
    property bool classicShown: false
    property string msg: ""
    contentWidth: availableWidth
    clip: true
    Component.onCompleted: studio.sh("kreadconfig6 --file kdeglobals --group 'KDE Control Module Restrictions' --key kcm_colors --default true",
                                     out => page.classicShown = out.trim() !== "false")

    component Box: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 24
        radius: 8; color: page.studio.rack2; border.color: page.studio.line
        ColumnLayout { id: inner; anchors.fill: parent; anchors.margins: 12; spacing: 8 }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 12

        PageHeader { studio: page.studio; title: "More"; note: "Extra options for people who like to tinker." }

        Box {
            RowLayout {
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "Show KDE's own appearance pages too"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
                    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 11
                           text: "Monster Themes Studio replaces Wallpaper, Colors & Themes, Text & Fonts and Animations in System Settings. Turn this on to see KDE's original pages again, for example the login screen or window borders." }
                }
                QQC2.Switch {
                    checked: page.classicShown
                    onToggled: page.studio.run(["classic", checked ? "show" : "hide"], out => { page.classicShown = checked; page.msg = out.replace(/^OK /, "✓ ") + ". Reopen System Settings to see it." })
                }
            }
            Text { visible: page.msg !== ""; text: page.msg; color: page.studio.led; font.family: page.studio.uiFont; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }

        Box {
            Text { text: "Start over"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 11
                   text: "Puts the stage back to the Monster Gloop theme. Nothing changes on your PC until you press Apply to my PC." }
            StudioButton { studio: page.studio; text: "Back to Monster Gloop"; onClicked: page.studio.loadTheme(page.studio.findTheme("Monster Gloop")) }
        }

        Box {
            Text { text: "Where things are saved"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: page.studio.dim; font.family: "monospace"; font.pixelSize: 11
                   text: "Colors: ~/.local/share/color-schemes/MonsterCustom.colors\nYour icons: ~/.local/share/icons/monster-custom/\nWallpapers: ~/.local/share/wallpapers/monster-studio/" }
        }
        Item { Layout.preferredHeight: 10 }
    }
}
