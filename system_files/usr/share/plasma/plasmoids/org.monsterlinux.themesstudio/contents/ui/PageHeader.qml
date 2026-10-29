// Title + one-line explanation at the top of each Studio section.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    property var studio
    property string title: ""
    property string note: ""
    spacing: 4
    Layout.fillWidth: true
    RowLayout {
        spacing: 8
        Rectangle { width: 7; height: 7; radius: 4; color: studio.led }
        Text { text: title.toUpperCase(); color: studio.ink; font.family: studio.uiFont; font.pixelSize: 14; font.bold: true; font.letterSpacing: 2 }
    }
    Text {
        visible: note !== ""
        text: note
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: studio.dim
        font.family: studio.uiFont
        font.pixelSize: 12
    }
}
