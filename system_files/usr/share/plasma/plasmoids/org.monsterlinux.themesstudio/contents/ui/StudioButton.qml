// A Studio-styled button. primary = lime "do it" button; selected = lit segment in a choice row.
import QtQuick

Rectangle {
    id: btn
    property var studio
    property string text: ""
    property bool primary: false
    property bool selected: false
    signal clicked()

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 36
    radius: 8
    opacity: enabled ? 1 : 0.4
    color: primary ? studio.led : (selected ? "#1f2a14" : (hover.hovered && enabled ? "#222824" : studio.rack2))
    border.color: primary ? studio.led : (selected ? studio.led : studio.line)
    scale: tap.pressed && enabled ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? "#11180a" : (btn.selected ? btn.studio.led : btn.studio.ink)
        font.family: btn.studio.uiFont
        font.pixelSize: 13
        font.bold: true
    }
    HoverHandler { id: hover; cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { id: tap; enabled: btn.enabled; onTapped: btn.clicked() }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) clicked()
}
