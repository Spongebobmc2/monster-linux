// Motion: the best of KDE's Animations page. Speed plus a few fun effects, with a test run.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

QQC2.ScrollView {
    id: page
    property var studio
    readonly property var st: studio.st
    contentWidth: availableWidth
    clip: true

    component Box: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 24
        radius: 8; color: page.studio.rack2; border.color: page.studio.line
        ColumnLayout { id: inner; anchors.fill: parent; anchors.margins: 12; spacing: 8 }
    }
    component Toggle: RowLayout {
        property string title; property string hint; property bool checked; signal toggled(bool on)
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Text { text: title; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
            Text { text: hint; color: page.studio.dim; font.family: page.studio.uiFont; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
        QQC2.Switch { checked: parent.checked; onToggled: parent.toggled(checked) }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 12

        PageHeader { studio: page.studio; title: "Motion"; note: "How fast windows and menus open and close, plus a few fun effects." }

        Box {
            Text { text: "Animation speed"; color: page.studio.ink; font.family: page.studio.uiFont; font.pixelSize: 13; font.bold: true }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [[0, "Instant"], [0.5, "Fast"], [1, "Normal"], [2, "Slow"], [4, "Very slow"]]
                    delegate: StudioButton { required property var modelData; studio: page.studio; text: modelData[1]; selected: page.st.anim === modelData[0]; Layout.fillWidth: true; onClicked: page.studio.set("anim", modelData[0]) }
                }
            }
            // test run: a little window that opens at the chosen speed
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 120; radius: 8; color: page.st.c.bg2; clip: true
                Rectangle {
                    id: demo
                    width: 150; height: 86; radius: 8; y: 17
                    x: 14
                    color: page.st.c.bg; border.color: page.st.c.accent
                    Rectangle { width: parent.width; height: 18; radius: 8; color: page.st.c.panel }
                    Text { anchors.centerIn: parent; text: "Hello!"; color: page.st.c.text; font.family: page.st.font; font.pixelSize: 14 }
                    transformOrigin: Item.Center
                }
                SequentialAnimation {
                    id: run
                    ParallelAnimation {
                        NumberAnimation { target: demo; property: "scale"; from: 0.2; to: 1; duration: Math.max(1, 300 * page.st.anim); easing.type: Easing.OutBack }
                        NumberAnimation { target: demo; property: "opacity"; from: 0; to: 1; duration: Math.max(1, 250 * page.st.anim) }
                        NumberAnimation { target: demo; property: "x"; from: 14; to: 160; duration: Math.max(1, 500 * page.st.anim); easing.type: Easing.InOutQuad }
                    }
                    PauseAnimation { duration: 500 }
                    NumberAnimation { target: demo; property: "x"; to: 14; duration: Math.max(1, 400 * page.st.anim); easing.type: Easing.InOutQuad }
                }
                StudioButton { studio: page.studio; text: "Test it"; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10; onClicked: run.restart() }
            }
        }

        Box {
            Toggle { title: "Wobbly windows"; hint: "Windows wobble like jelly when you drag them."; checked: page.st.wobbly; onToggled: on => page.studio.set("wobbly", on) }
            Toggle { title: "Magic lamp"; hint: "Windows slide into the taskbar like a genie when you minimize them."; checked: page.st.lamp; onToggled: on => page.studio.set("lamp", on) }
            Toggle { title: "Blur behind see-through things"; hint: "The taskbar, menus and terminal blur what's behind them. Turn off on older PCs."; checked: page.st.blur; onToggled: on => page.studio.set("blur", on) }
        }
        Item { Layout.preferredHeight: 10 }
    }
}
