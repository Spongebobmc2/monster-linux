// Color spectrum tool: drag in the big square for shade (left/right = soft to strong,
// up/down = bright to dark) and along the rainbow bar for the color itself.
// Changes show on the stage live; one drag = one Undo step.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

Rectangle {
    id: sp
    property var studio
    property string slotKey: ""          // which of the 12 colors is being edited
    property string slotName: ""
    property bool showDone: true
    signal moreOptions()
    signal done()

    // current color as hue / saturation / value (0..1)
    property real h: 0
    property real s: 0
    property real v: 0
    property string startColor: "#000000"   // color when this slot was opened (for "Put back")
    property var recent: []                 // colors picked this session

    readonly property color current: Qt.hsva(h, s, v, 1)
    readonly property string hex: studio.hx(current.toString()).toUpperCase()

    radius: 10
    color: studio.rack
    border.color: studio.led
    implicitHeight: body.implicitHeight + 24

    function loadFrom(c) {
        const col = Qt.lighter(c, 1.0)
        h = col.hsvHue < 0 ? h : col.hsvHue      // greys have no hue: keep the last one
        s = col.hsvSaturation
        v = col.hsvValue
    }
    function open(key, name) {
        slotKey = key; slotName = name
        startColor = studio.st.c[key]
        loadFrom(startColor)
    }
    // first change of a drag makes an Undo step, the rest are live
    property bool dragging: false
    function push(final) {
        if (!slotKey) return
        if (!dragging) { studio.setColor(slotKey, hex); dragging = true }
        else studio.setColorLive(slotKey, hex)
        if (final) {
            dragging = false
            const r = recent.filter(x => x !== hex); r.unshift(hex); recent = r.slice(0, 10)
        }
    }
    function setHex(t) {
        let x = t.trim(); if (!x.startsWith("#")) x = "#" + x
        if (!/^#[0-9a-fA-F]{6}$/.test(x)) return false
        loadFrom(x); dragging = false; push(true); return true
    }

    // keep in step when the color changes somewhere else (hex box, quick accent, Undo, theme change)
    Connections {
        target: sp.studio
        function onStChanged() {
            if (!sp.dragging && sp.slotKey && sp.studio.hx(sp.studio.st.c[sp.slotKey]).toUpperCase() !== sp.hex)
                sp.loadFrom(sp.studio.st.c[sp.slotKey])
        }
    }

    // contrast check: text-type colors against the window background, others against text
    readonly property bool isWord: ["text", "muted", "link"].indexOf(slotKey) >= 0
    readonly property string against: isWord ? studio.st.c.bg : studio.st.c.text
    readonly property real ratio: {
        const a = studio.lum(hex), b = studio.lum(against)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text { text: "COLOR SPECTRUM · " + sp.slotName.toUpperCase(); color: sp.studio.led; font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 2; Layout.fillWidth: true; elide: Text.ElideRight }
            StudioButton { studio: sp.studio; visible: sp.showDone; text: "Done"; primary: true; implicitHeight: 30; onClicked: sp.done() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // ---- shade square ----
            Item {
                id: square
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                Layout.minimumWidth: 200
                Rectangle {
                    anchors.fill: parent; radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#ffffff" }
                        GradientStop { position: 1; color: Qt.hsva(sp.h, 1, 1, 1) }
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: 8
                    border.color: sp.studio.line
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: 1; color: "#ff000000" }
                    }
                }
                // ring that shows the chosen spot
                Rectangle {
                    width: 18; height: 18; radius: 9
                    x: sp.s * square.width - 9
                    y: (1 - sp.v) * square.height - 9
                    color: sp.current
                    border.width: 3
                    border.color: sp.v > 0.55 && sp.s < 0.5 ? "#11180a" : "#ffffff"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    function pick(mx, my, final) {
                        sp.s = Math.max(0, Math.min(1, mx / width))
                        sp.v = Math.max(0, Math.min(1, 1 - my / height))
                        sp.push(final)
                    }
                    onPressed: (m) => pick(m.x, m.y, false)
                    onPositionChanged: (m) => { if (pressed) pick(m.x, m.y, false) }
                    onReleased: (m) => pick(m.x, m.y, true)
                }
                Accessible.role: Accessible.Slider
                Accessible.name: "Shade: strength and brightness"
            }

            // ---- before / after + numbers ----
            ColumnLayout {
                Layout.preferredWidth: 150
                spacing: 8
                Text { text: "BEFORE → NOW"; color: sp.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1 }
                RowLayout {
                    spacing: 0
                    Rectangle {
                        Layout.preferredWidth: 70; Layout.preferredHeight: 48; color: sp.startColor
                        radius: 6
                        Text { anchors.centerIn: parent; text: "Put back"; color: sp.studio.onAccent(sp.startColor); font.pixelSize: 10; font.family: sp.studio.uiFont }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: sp.setHex(sp.startColor) }
                    }
                    Rectangle { Layout.preferredWidth: 70; Layout.preferredHeight: 48; color: sp.current; radius: 6 }
                }
                QQC2.TextField {
                    id: hexField
                    Layout.fillWidth: true
                    text: sp.hex
                    font.family: "monospace"
                    maximumLength: 7
                    onEditingFinished: if (!sp.setHex(text)) text = sp.hex
                }
                Text {
                    text: "R " + Math.round(sp.current.r * 255) + "  G " + Math.round(sp.current.g * 255) + "  B " + Math.round(sp.current.b * 255)
                    color: sp.studio.dim; font.family: "monospace"; font.pixelSize: 11
                }
                // readability check
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 40; radius: 6
                    color: sp.isWord ? sp.studio.st.c.bg : sp.current
                    border.color: sp.studio.line
                    Text {
                        anchors.centerIn: parent
                        text: "Aa  Sample"
                        color: sp.isWord ? sp.current : sp.studio.st.c.text
                        font.family: sp.studio.uiFont; font.pixelSize: 14; font.bold: true
                    }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    font.family: sp.studio.uiFont; font.pixelSize: 11
                    color: sp.ratio >= 4.5 ? "#5fc8a0" : (sp.ratio >= 3 ? "#e8b03d" : "#d9574a")
                    text: (sp.ratio >= 4.5 ? "✓ Easy to read" : (sp.ratio >= 3 ? "! OK for big text" : "✗ Hard to read")) + " (" + sp.ratio.toFixed(1) + ":1)"
                }
            }
        }

        // ---- rainbow bar ----
        Item {
            id: hueBar
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Rectangle {
                anchors.fill: parent; radius: 11
                border.color: sp.studio.line
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.000; color: "#ff0000" }
                    GradientStop { position: 0.167; color: "#ffff00" }
                    GradientStop { position: 0.333; color: "#00ff00" }
                    GradientStop { position: 0.500; color: "#00ffff" }
                    GradientStop { position: 0.667; color: "#0000ff" }
                    GradientStop { position: 0.833; color: "#ff00ff" }
                    GradientStop { position: 1.000; color: "#ff0000" }
                }
            }
            Rectangle {
                width: 14; height: 28; radius: 4
                y: -3
                x: sp.h * hueBar.width - 7
                color: Qt.hsva(sp.h, 1, 1, 1)
                border.width: 3; border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                function pick(mx, final) { sp.h = Math.max(0, Math.min(0.999, mx / width)); sp.push(final) }
                onPressed: (m) => pick(m.x, false)
                onPositionChanged: (m) => { if (pressed) pick(m.x, false) }
                onReleased: (m) => pick(m.x, true)
            }
            Accessible.role: Accessible.Slider
            Accessible.name: "Color (rainbow)"
        }

        // ---- quick tweaks ----
        Flow {
            Layout.fillWidth: true
            spacing: 6
            StudioButton { studio: sp.studio; text: "Lighter"; implicitHeight: 30; onClicked: { sp.v = Math.min(1, sp.v + 0.08); sp.dragging = false; sp.push(true) } }
            StudioButton { studio: sp.studio; text: "Darker"; implicitHeight: 30; onClicked: { sp.v = Math.max(0, sp.v - 0.08); sp.dragging = false; sp.push(true) } }
            StudioButton { studio: sp.studio; text: "Softer"; implicitHeight: 30; onClicked: { sp.s = Math.max(0, sp.s - 0.1); sp.dragging = false; sp.push(true) } }
            StudioButton { studio: sp.studio; text: "Stronger"; implicitHeight: 30; onClicked: { sp.s = Math.min(1, sp.s + 0.1); sp.dragging = false; sp.push(true) } }
            StudioButton { studio: sp.studio; text: "Opposite color"; implicitHeight: 30; onClicked: { sp.h = (sp.h + 0.5) % 1; sp.dragging = false; sp.push(true) } }
            StudioButton { studio: sp.studio; text: "More options…"; implicitHeight: 30; onClicked: sp.moreOptions() }
        }

        // ---- recently picked ----
        RowLayout {
            visible: sp.recent.length > 0
            spacing: 6
            Text { text: "RECENT"; color: sp.studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 1 }
            Repeater {
                model: sp.recent
                delegate: Rectangle {
                    required property string modelData
                    width: 24; height: 24; radius: 12; color: modelData
                    border.color: "#ffffff33"
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sp.setHex(modelData) }
                }
            }
        }
    }
}
