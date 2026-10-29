// Letters: the best of KDE's Text & Fonts page, made simple.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

QQC2.ScrollView {
    id: page
    property var studio
    readonly property var st: studio.st
    readonly property var allFonts: studio.installedFonts
    readonly property var monoFonts: allFonts.filter(f => /mono|code|hack|courier|consol|terminus|jetbrains|fira code|cascadia|inconsolata|source code/i.test(f))
    property string search: ""
    contentWidth: availableWidth
    clip: true

    component Box: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 24
        radius: 8; color: page.studio.rack2; border.color: page.studio.line
        ColumnLayout { id: inner; anchors.fill: parent; anchors.margins: 12; spacing: 8 }
    }
    component Label2: Text { color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
    component Hint: Text { color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }

    ColumnLayout {
        width: page.availableWidth
        spacing: 12

        PageHeader { studio: page.studio; title: "Letters"; note: "Choose how text looks in every menu, window and the taskbar." }

        // sample
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sample.implicitHeight + 28
            radius: 8; color: page.st.c.view; border.color: page.studio.line
            ColumnLayout {
                id: sample
                anchors.fill: parent; anchors.margins: 14; spacing: 4
                Text { text: "The quick monster jumps over the lazy log"; color: page.st.c.text; font.family: page.st.font; font.pixelSize: page.st.size * 1.6; font.bold: page.st.bold; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                Text { text: "Menus and windows will use " + page.st.font + " at " + page.st.size + " pt."; color: page.st.c.muted; font.family: page.st.font; font.pixelSize: page.st.size * 1.33; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                Text { text: "monster@bazzite:~$ echo hello"; color: page.st.c.accent; font.family: page.st.mono; font.pixelSize: page.st.size * 1.33 }
                Text {
                    visible: !page.studio.hasFont(page.st.font)
                    text: page.st.font + " isn't installed on this PC yet, so Apply will use Noto Sans. Pick another font below to see the real thing."
                    color: page.st.c.warn; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }
            }
        }

        Box {
            Label2 { text: "Text font" }
            QQC2.TextField { Layout.fillWidth: true; placeholderText: "Search fonts…"; onTextChanged: page.search = text.toLowerCase() }
            ListView {
                id: fontList
                Layout.fillWidth: true; Layout.preferredHeight: 190
                clip: true
                model: page.allFonts.filter(f => !page.search || f.toLowerCase().indexOf(page.search) >= 0)
                currentIndex: model.indexOf(page.st.font)
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                delegate: Rectangle {
                    required property string modelData
                    width: fontList.width - 12; height: 32; radius: 6
                    color: page.st.font === modelData ? "#1f2a14" : (fh.hovered ? "#222824" : "transparent")
                    HoverHandler { id: fh }
                    TapHandler { onTapped: page.studio.set("font", modelData) }
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData; font.family: modelData; font.pixelSize: 15
                           color: page.st.font === modelData ? page.studio.led : page.studio.ink }
                }
            }
        }

        Box {
            RowLayout { Label2 { text: "Text size"; Layout.fillWidth: true } Text { text: page.st.size + " pt"; color: page.studio.led; font.family: "monospace"; font.pixelSize: 12 } }
            QQC2.Slider { Layout.fillWidth: true; from: 8; to: 16; stepSize: 1; value: page.st.size; onMoved: page.studio.set("size", value) }
            RowLayout {
                Label2 { text: "Bold window titles"; Layout.fillWidth: true }
                QQC2.Switch { checked: page.st.bold; onToggled: page.studio.set("bold", checked) }
            }
        }

        Box {
            Label2 { text: "Terminal font" }
            Hint { text: "Used in Konsole and anywhere code is shown." }
            QQC2.ComboBox {
                Layout.fillWidth: true
                model: page.monoFonts.length ? page.monoFonts : page.allFonts
                currentIndex: Math.max(0, model.indexOf(page.st.mono))
                onActivated: page.studio.set("mono", currentText)
            }
        }

        Box {
            Label2 { text: "Sharpness" }
            RowLayout {
                Text { text: "Smooth letter edges"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; Layout.fillWidth: true }
                QQC2.Switch { checked: page.st.smooth; onToggled: page.studio.set("smooth", checked) }
            }
            Text { text: "Crispness"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13 }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [["none", "Softest"], ["slight", "Soft (best)"], ["medium", "Sharp"], ["full", "Sharpest"]]
                    delegate: StudioButton { required property var modelData; studio: page.studio; text: modelData[1]; selected: page.st.hint === modelData[0]; Layout.fillWidth: true; onClicked: page.studio.set("hint", modelData[0]) }
                }
            }
        }

        Box {
            Label2 { text: "Make all text bigger" }
            Hint { text: "Scales text everywhere, like the zoom on a phone. Fully shows after you log out and back in." }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [100, 112, 125, 150]
                    delegate: StudioButton { required property int modelData; studio: page.studio; text: modelData + "%"; selected: page.st.scale === modelData; Layout.fillWidth: true; onClicked: page.studio.set("scale", modelData) }
                }
            }
        }
        Item { Layout.preferredHeight: 10 }
    }
}
