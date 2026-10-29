// Icon Workshop: turn any picture into an app icon.
// Choose a picture, pick a shape, zoom and drag it into place, add a background and border,
// check it at small sizes, then "Use this icon". "Put original back" undoes it.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Effects
import org.kde.kirigami as Kirigami

QQC2.Popup {
    id: ws
    property var studio
    property var app: ({ id: "", name: "", icon: "", file: "" })
    property url picture: ""
    property string shape: "rounded"        // square | rounded | round | free
    property real zoom: 1
    property real offX: 0
    property real offY: 0
    property string bg: "none"              // none | white | black | accent | custom
    property color bgCustom: "#1b2414"
    property int borderW: 0
    property color borderC: "#ffffff"
    property string message: ""
    signal iconChanged()

    readonly property real shapeRadius: shape === "round" ? 128 : (shape === "rounded" ? 58 : (shape === "square" ? 16 : 0))
    readonly property color bgColor: bg === "white" ? "#ffffff" : bg === "black" ? "#000000" : bg === "accent" ? studio.st.c.accent : bg === "custom" ? bgCustom : "transparent"

    function openFor(a) { app = a; picture = ""; zoom = 1; offX = 0; offY = 0; message = ""; open() }
    function safeId() { return app.id.replace(/\.desktop$/, "").replace(/[^A-Za-z0-9_.-]/g, "_") }

    modal: true
    width: Math.min(parent ? parent.width - 20 : 820, 820)
    height: Math.min(parent ? parent.height - 20 : 560, 560)
    padding: 0
    background: Rectangle { radius: 12; color: ws.studio.rack; border.color: ws.studio.led }

    FileDialog {
        id: chooser
        title: "Choose a picture for " + ws.app.name
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp *.bmp *.gif *.svg *.ico)"]
        onAccepted: { ws.picture = selectedFile; ws.zoom = 1; ws.offX = 0; ws.offY = 0 }
    }
    ColorDialog { id: bgPick; title: "Background color"; onAccepted: { ws.bgCustom = selectedColor; ws.bg = "custom" } }
    ColorDialog { id: borderPick; title: "Border color"; onAccepted: ws.borderC = selectedColor }

    contentItem: RowLayout {
        spacing: 0

        // ---------- canvas side ----------
        Rectangle {
            Layout.preferredWidth: 340
            Layout.fillHeight: true
            color: "#0f1210"
            radius: 12
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 18; spacing: 14
                Text { text: "Icon Workshop"; color: ws.studio.ink; font.family: ws.studio.uiFont; font.pixelSize: 18; font.bold: true }
                Text { text: "New icon for " + ws.app.name; color: ws.studio.dim; font.family: ws.studio.uiFont; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }

                // checkerboard behind the canvas so see-through parts are visible
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 256; height: 256
                    Grid {
                        anchors.fill: parent; columns: 16; clip: true
                        Repeater { model: 256; delegate: Rectangle { required property int index; width: 16; height: 16; color: (Math.floor(index / 16) + index) % 2 ? "#2a2f2b" : "#1d211e" } }
                    }

                    // ---- the icon itself (this is what gets saved) ----
                    Item {
                        id: canvas
                        anchors.fill: parent

                        Item {
                            id: content
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle { anchors.fill: parent; color: ws.bgColor }
                            Image {
                                id: pic
                                source: ws.picture
                                fillMode: Image.PreserveAspectFit
                                width: 256 * ws.zoom; height: 256 * ws.zoom
                                x: (256 - width) / 2 + ws.offX
                                y: (256 - height) / 2 + ws.offY
                                smooth: true; mipmap: true
                                sourceSize.width: 1024
                            }
                            Kirigami.Icon {
                                visible: ws.picture.toString() === ""
                                anchors.centerIn: parent; width: 160; height: 160
                                source: ws.app.icon.startsWith("/") ? "file://" + ws.app.icon : ws.app.icon
                                fallback: "application-x-executable"
                            }
                        }
                        Item {
                            id: mask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle { anchors.fill: parent; radius: ws.shapeRadius; color: "#ffffff" }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: content
                            maskEnabled: ws.shape !== "free"
                            maskSource: mask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: ws.borderW > 0 && ws.shape !== "free"
                            radius: ws.shapeRadius
                            color: "transparent"
                            border.width: ws.borderW
                            border.color: ws.borderC
                        }
                    }
                    // drag to move the picture
                    DragHandler {
                        target: null
                        property real sx: 0; property real sy: 0
                        onActiveChanged: if (active) { sx = ws.offX; sy = ws.offY }
                        onTranslationChanged: { ws.offX = sx + translation.x; ws.offY = sy + translation.y }
                    }
                    WheelHandler { onWheel: (ev) => ws.zoom = Math.max(0.2, Math.min(4, ws.zoom * (ev.angleDelta.y > 0 ? 1.08 : 0.93))) }
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: "Drag the picture to move it. Scroll to zoom."; color: ws.studio.dim; font.family: ws.studio.uiFont; font.pixelSize: 11 }

                // small-size check
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 18
                    Repeater {
                        model: [64, 32, 16]
                        delegate: ColumnLayout {
                            required property int modelData
                            spacing: 4
                            ShaderEffectSource { sourceItem: canvas; Layout.preferredWidth: modelData; Layout.preferredHeight: modelData; Layout.alignment: Qt.AlignHCenter; smooth: true; mipmap: true }
                            Text { text: modelData + " px"; color: ws.studio.dim; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ---------- controls side ----------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 18
            spacing: 12

            StudioButton { studio: ws.studio; text: ws.picture.toString() === "" ? "Choose a picture…" : "Choose a different picture…"; primary: ws.picture.toString() === ""; onClicked: chooser.open() }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: ws.studio.dim; font.family: ws.studio.uiFont; font.pixelSize: 11
                   text: "Any photo, drawing, logo or screenshot works: PNG, JPG, WebP, GIF, SVG or ICO." }

            Text { text: "Shape"; color: ws.studio.ink; font.family: ws.studio.uiFont; font.pixelSize: 13; font.bold: true }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [["square", "Square"], ["rounded", "Rounded"], ["round", "Round"], ["free", "As is"]]
                    delegate: StudioButton { required property var modelData; studio: ws.studio; text: modelData[1]; selected: ws.shape === modelData[0]; Layout.fillWidth: true; onClicked: ws.shape = modelData[0] }
                }
            }

            RowLayout {
                Text { text: "Zoom"; color: ws.studio.ink; font.family: ws.studio.uiFont; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 70 }
                QQC2.Slider { Layout.fillWidth: true; from: 0.2; to: 4; value: ws.zoom; onMoved: ws.zoom = value }
                StudioButton { studio: ws.studio; text: "Center"; onClicked: { ws.offX = 0; ws.offY = 0; ws.zoom = 1 } }
            }

            Text { text: "Background"; color: ws.studio.ink; font.family: ws.studio.uiFont; font.pixelSize: 13; font.bold: true }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [["none", "None"], ["white", "White"], ["black", "Black"], ["accent", "Accent"]]
                    delegate: StudioButton { required property var modelData; studio: ws.studio; text: modelData[1]; selected: ws.bg === modelData[0]; Layout.fillWidth: true; onClicked: ws.bg = modelData[0] }
                }
                StudioButton { studio: ws.studio; text: "Pick…"; selected: ws.bg === "custom"; onClicked: bgPick.open() }
            }

            RowLayout {
                Text { text: "Border"; color: ws.studio.ink; font.family: ws.studio.uiFont; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 70 }
                QQC2.Slider { Layout.fillWidth: true; from: 0; to: 24; stepSize: 1; value: ws.borderW; onMoved: ws.borderW = value }
                Rectangle { width: 30; height: 30; radius: 6; color: ws.borderC; border.color: "#ffffff44"
                    HoverHandler { cursorShape: Qt.PointingHandCursor } TapHandler { onTapped: borderPick.open() } }
            }

            Item { Layout.fillHeight: true }

            Text { visible: ws.message !== ""; text: ws.message; Layout.fillWidth: true; wrapMode: Text.WordWrap
                   color: ws.message.startsWith("✓") ? ws.studio.led : ws.studio.lamp; font.family: ws.studio.uiFont; font.pixelSize: 12 }

            RowLayout {
                spacing: 8
                StudioButton { studio: ws.studio; text: "Put original back"
                    onClicked: ws.studio.run(["appicon-reset", ws.app.id], out => { ws.message = "✓ Original icon is back"; ws.iconChanged() }) }
                Item { Layout.fillWidth: true }
                StudioButton { studio: ws.studio; text: "Close"; onClicked: ws.close() }
                StudioButton {
                    studio: ws.studio; text: "Use this icon"; primary: true
                    enabled: ws.picture.toString() !== "" && ws.studio.home !== ""
                    onClicked: canvas.grabToImage(result => {
                        const path = ws.studio.home + "/.local/share/icons/monster-custom/" + ws.safeId() + "-" + Date.now() + ".png"
                        if (!result.saveToFile(path)) { ws.message = "✗ Couldn't save the icon. Try again."; return }
                        ws.studio.run(["appicon", ws.app.file, path], out => {
                            ws.message = out.indexOf("OK") === 0 ? "✓ " + ws.app.name + " has its new icon. It shows in menus and the taskbar right away (restart the app if it's open)." : "✗ " + out
                            ws.iconChanged()
                        })
                    }, Qt.size(256, 256))
                }
            }
        }
    }
}
