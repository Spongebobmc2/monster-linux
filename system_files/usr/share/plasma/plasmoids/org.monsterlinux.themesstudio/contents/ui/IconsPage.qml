// Icons: pick the icon shape for the whole system, then click any app on the model desktop
// to give it your own icon made from any picture (Icon Workshop).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page
    property var studio
    readonly property var st: studio.st
    property var apps: []          // [{id, name, icon, file}]
    property var iconThemes: []
    property string filter: ""
    property bool loading: true

    function loadApps() {
        loading = true
        studio.run(["apps"], out => {
            page.apps = out.split("\n").filter(x => x).map(l => { const p = l.split("|"); return { id: p[0], name: p[1], icon: p[2], file: p[3] } })
            page.loading = false
        })
    }
    Component.onCompleted: {
        loadApps()
        studio.run(["list", "iconthemes"], out => page.iconThemes = out.split("\n").filter(x => x && !/cursor|hicolor|default|locolor/i.test(x)))
    }
    function iconSource(a) { return a.icon.startsWith("/") ? "file://" + a.icon : a.icon }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PageHeader { studio: page.studio; title: "Icons"; note: "Choose the shape of every icon, or click an app below to give it your very own icon." }

        // ---- icon set ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: setCol.implicitHeight + 24
            radius: 8; color: page.studio.rack2; border.color: page.studio.line
            ColumnLayout {
                id: setCol
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Text { text: "Icon shape for all apps"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [["square", "Square (KDE normal)"], ["rounded", "Rounded"], ["round", "Round"]]
                        delegate: StudioButton {
                            required property var modelData
                            studio: page.studio; text: modelData[1]; Layout.fillWidth: true
                            selected: !page.st.iconTheme && page.st.icons === modelData[0]
                            onClicked: { const s = JSON.parse(JSON.stringify(page.st)); page.studio.snapshot(); s.icons = modelData[0]; s.iconTheme = ""; page.studio.st = s }
                        }
                    }
                }
                RowLayout {
                    Text { text: "Or use an icon set on this PC:"; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 12 }
                    QQC2.ComboBox {
                        Layout.fillWidth: true
                        model: ["(use the shape above)"].concat(page.iconThemes)
                        currentIndex: Math.max(0, model.indexOf(page.st.iconTheme))
                        onActivated: page.studio.set("iconTheme", currentIndex === 0 ? "" : currentText)
                    }
                }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 11
                       text: "Rounded and Round download a free matching icon set (Tela) in your accent color the first time you apply." }
            }
        }

        // ---- model desktop of the user's apps ----
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Your apps"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
            QQC2.TextField { Layout.preferredWidth: 220; placeholderText: "Find an app…"; onTextChanged: page.filter = text.toLowerCase() }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: page.st.c.bg
            border.color: page.studio.line
            clip: true
            Image { anchors.fill: parent; source: page.st.wallKind === "live" ? page.studio.pkg + "/wallpapers/monster-gloop.png" : "file://" + page.st.wallPath
                    fillMode: Image.PreserveAspectCrop; opacity: 0.35; asynchronous: true; sourceSize.width: 900 }
            QQC2.BusyIndicator { anchors.centerIn: parent; running: page.loading; visible: page.loading }
            GridView {
                id: grid
                anchors.fill: parent; anchors.margins: 10
                cellWidth: 104; cellHeight: 104
                clip: true
                model: page.apps.filter(a => !page.filter || a.name.toLowerCase().indexOf(page.filter) >= 0)
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                delegate: Item {
                    id: cell
                    required property var modelData
                    width: grid.cellWidth; height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4; radius: 10
                        color: ah.hovered ? "#ffffff14" : "transparent"
                        border.color: ah.hovered ? page.studio.led : "transparent"
                    }
                    HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: workshop.openFor(cell.modelData) }
                    Kirigami.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 12
                        width: 48; height: 48
                        source: page.iconSource(cell.modelData)
                        fallback: "application-x-executable"
                    }
                    Text {
                        x: 4; y: 66; width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name; color: page.st.c.text
                        font.family: page.st.font; font.pixelSize: 11
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                }
            }
        }
    }

    IconWorkshop {
        id: workshop
        studio: page.studio
        anchors.centerIn: parent
        onIconChanged: page.loadApps()
    }
}
