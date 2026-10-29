// Glass & Shape: see-through windows, the taskbar, and the mouse pointer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

QQC2.ScrollView {
    id: page
    property var studio
    readonly property var st: studio.st
    property var cursors: []
    contentWidth: availableWidth
    clip: true
    Component.onCompleted: studio.run(["list", "cursors"], out => page.cursors = out.split("\n").filter(x => x))

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

        PageHeader { studio: page.studio; title: "Glass & Shape"; note: "Make windows a little see-through so your wallpaper shows. Games always stay solid." }

        Box {
            RowLayout { Label2 { text: "Window you're using"; Layout.fillWidth: true } Text { text: page.st.op + "%"; color: page.studio.led; font.family: "monospace"; font.pixelSize: 12 } }
            QQC2.Slider { Layout.fillWidth: true; from: 60; to: 100; stepSize: 1; value: page.st.op; onMoved: page.studio.set("op", value) }
            Hint { text: "100% is fully solid. Lower is more see-through." }
        }
        Box {
            RowLayout { Label2 { text: "Windows behind it"; Layout.fillWidth: true } Text { text: page.st.opIn + "%"; color: page.studio.led; font.family: "monospace"; font.pixelSize: 12 } }
            QQC2.Slider { Layout.fillWidth: true; from: 50; to: 100; stepSize: 1; value: page.st.opIn; onMoved: page.studio.set("opIn", value) }
        }
        Box {
            Label2 { text: "Taskbar" }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [["opaque", "Solid"], ["translucent", "See-through"], ["adaptive", "Automatic"]]
                    delegate: StudioButton { required property var modelData; studio: page.studio; text: modelData[1]; selected: page.st.panel === modelData[0]; Layout.fillWidth: true; onClicked: page.studio.set("panel", modelData[0]) }
                }
            }
            Hint { text: "Automatic is see-through, and turns solid when a window is maximized." }
        }
        Box {
            Label2 { text: "Mouse pointer" }
            QQC2.ComboBox {
                Layout.fillWidth: true
                model: ["Keep my current pointer"].concat(page.cursors)
                currentIndex: Math.max(0, model.indexOf(page.st.cursor))
                onActivated: page.studio.set("cursor", currentIndex === 0 ? "" : currentText)
            }
        }
        Item { Layout.preferredHeight: 10 }
    }
}
