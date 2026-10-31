// Monster Shield window, "Slime Pop" look. Left: firewall. Right: virus check.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.plasma.plasma5support as P5Support

Rectangle {
    id: sh
    color: "#fbfdf6"

    readonly property color ink: "#1b2610"
    readonly property color dim: "#5f6d52"
    readonly property color lime: "#8cc22a"
    readonly property color deep: "#3f7a0e"
    readonly property color soft: "#e3f3c4"
    readonly property color edge: "#e1eecb"
    readonly property color bad: "#c4452f"
    readonly property color warn: "#b7791f"
    readonly property string head: "Unbounded"
    readonly property string body: "Sora"
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../code/shield.sh").toString().replace("file://", ""))

    property var s: ({ fw: "", zone: "", clam: "", db: 0, daily: "no", last: null, quarantined: 0 })
    property var scan: ({ running: false, total: 0, scanned: 0, found: [], done: null })
    property bool fwBusy: false
    property bool dbBusy: false
    property string note: ""

    readonly property bool fwOn: s.fw === "on"
    readonly property string place: s.zone === "monster-home" ? "home" : s.zone === "monster-public" ? "public" : ""
    readonly property bool dbOk: s.db > 0 && (Date.now() / 1000 - s.db) < 8 * 86400
    readonly property bool scannedRecently: (s.lastscan || 0) > 0 && (Date.now() / 1000 - s.lastscan) < 7 * 86400
    readonly property bool allGood: fwOn && place !== "" && s.clam === "yes" && dbOk && scannedRecently && !(scan.found && scan.found.length)

    // ---- helper runner ----
    property int runId: 0
    property var callbacks: ({})
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const cb = sh.callbacks[source]
            exec.disconnectSource(source)
            if (cb) { const c = Object.assign({}, sh.callbacks); delete c[source]; sh.callbacks = c; cb((data["stdout"] || "").trim()) }
        }
    }
    function q(x) { return "'" + ("" + x).replace(/'/g, "'\\''") + "'" }
    function run(args, cb) {
        runId++
        const cmd = "bash " + q(helper) + " " + args.map(q).join(" ") + " # " + runId
        const c = Object.assign({}, callbacks); c[cmd] = cb || function () {}; callbacks = c
        exec.connectSource(cmd)
    }
    function lastLine(out) { const l = out.split("\n").filter(x => /^(OK|FAIL) /.test(x)); return l.length ? l[l.length - 1].replace(/^(OK|FAIL) /, "") : "" }
    function refresh() { run(["status"], o => { try { s = JSON.parse(o) } catch (e) {} }) }
    function pollScan() {
        run(["scan-status"], o => {
            let x; try { x = JSON.parse(o) } catch (e) { return }
            scan = x
            if (!x.running) { scanTimer.stop(); refresh() }
        })
    }
    function startScan(kind) {
        if (s.clam !== "yes") { note = "The virus check isn't installed yet. Update Monster Linux to get it."; return }
        if (!dbOk) { note = "Getting the latest virus list first…"; updateDb(() => startScan(kind)); return }
        note = ""
        scan = { running: true, total: 0, scanned: 0, found: [], done: null }
        run(["scan", kind], o => { if (o === "MISSING") note = "The virus check isn't installed yet."; scanTimer.start() })
    }
    function updateDb(then) {
        dbBusy = true
        run(["update-db"], o => { dbBusy = false; note = lastLine(o); refresh(); if (then && o.indexOf("OK") === 0) Qt.callLater(then) })
    }
    function setPlace(p) { fwBusy = true; run(["fw-zone", p], o => { fwBusy = false; note = lastLine(o); refresh() }) }
    function setFw(on) { fwBusy = true; run([on ? "fw-on" : "fw-off"], o => { fwBusy = false; note = lastLine(o); refresh() }) }
    function ago(t) {
        if (!t) return "never"
        const d = Math.floor(Date.now() / 1000 - t)
        if (d < 3600) return Math.max(1, Math.round(d / 60)) + " min ago"
        if (d < 86400) return Math.round(d / 3600) + " h ago"
        return Math.round(d / 86400) + " days ago"
    }
    Timer { id: scanTimer; interval: 1000; repeat: true; onTriggered: sh.pollScan() }
    Component.onCompleted: { refresh(); run(["ensure"], () => refresh()); pollScan() }

    FolderDialog { id: pickFolder; title: "Pick a folder to check"; onAccepted: sh.startScan(decodeURIComponent(selectedFolder.toString().replace("file://", ""))) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- lime header ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 100; color: sh.lime
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24; spacing: 14
                Image { source: "../images/gloop.png"; Layout.preferredWidth: 56; Layout.preferredHeight: 58; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "Monster Shield"; font.family: sh.head; font.weight: Font.ExtraBold; font.pixelSize: 22; color: "#14200a" }
                    Text { text: "Firewall and virus check. One click each."; font.family: sh.body; font.pixelSize: 13; color: "#24360f" }
                }
                Rectangle {
                    radius: height / 2; implicitHeight: 34; implicitWidth: stT.implicitWidth + 44
                    color: sh.allGood ? "#ffffff" : "#fff4e0"
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Rectangle { width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter; color: sh.allGood ? sh.deep : sh.warn }
                        Text { id: stT; text: sh.allGood ? "You're protected" : "Needs a click"; font.family: sh.body; font.pixelSize: 13; font.bold: true; color: sh.allGood ? sh.deep : sh.warn }
                    }
                }
            }
        }
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 14; clip: true
            Row { Repeater { model: Math.ceil(sh.width / 34) + 1
                Item { width: 34; height: 14
                    Rectangle { x: 1; y: -9; width: 18; height: 18; radius: 9; color: sh.lime }
                    Rectangle { x: 21.5; y: -5.5; width: 11; height: 11; radius: 5.5; color: sh.lime } } } }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.leftMargin: 22; Layout.rightMargin: 22; Layout.topMargin: 6; Layout.bottomMargin: 10
            spacing: 18

            // =========== FIREWALL ===========
            Card {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: "Firewall"; font.family: sh.head; font.weight: Font.ExtraBold; font.pixelSize: 18; color: sh.ink }
                            Text { text: sh.fwOn ? "On. Strangers on the network can't get in." : "Off. Turn it on to block strangers."; font.family: sh.body; font.pixelSize: 12; color: sh.fwOn ? sh.dim : sh.bad; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                        Toggle { on: sh.fwOn; busy: sh.fwBusy; onToggled: sh.setFw(!sh.fwOn) }
                    }
                    Text { text: "Where are you?"; font.family: sh.body; font.pixelSize: 13; font.bold: true; color: sh.ink }
                    PlaceTile {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        title: "Home"; tag: "Best for home"
                        icon: "M12 30 L32 13 L52 30 M18 26 V51 H46 V26 M28 51 V38 H36 V51"
                        text: "Your phone, printer, other PCs and Steam streaming can find this PC. Nothing else can get in."
                        chosen: sh.fwOn && sh.place === "home"; enabled: !sh.fwBusy
                        onPicked: sh.setPlace("home")
                    }
                    PlaceTile {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        title: "Public"; tag: "Best protection"
                        icon: "M32 10 L50 17 V31 C50 43 42 50 32 54 C22 50 14 43 14 31 V17 Z M24 32 L30 38 L41 26"
                        text: "Cafés, hotels, airports, school. Nothing on the network can connect to this PC. Internet still works."
                        chosen: sh.fwOn && sh.place === "public"; enabled: !sh.fwBusy
                        onPicked: sh.setPlace("public")
                    }
                    Text {
                        visible: sh.fwOn && sh.place === ""
                        text: "Pick Home or Public so Monster Shield knows how careful to be."
                        font.family: sh.body; font.pixelSize: 12; color: sh.warn; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                }
            }

            // =========== VIRUS CHECK ===========
            Card {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                    ColumnLayout {
                        spacing: 2
                        Text { text: "Virus check"; font.family: sh.head; font.weight: Font.ExtraBold; font.pixelSize: 18; color: sh.ink }
                        Text {
                            text: sh.s.clam !== "yes" ? "Not installed yet. It comes with the next update." :
                                  "Virus list: " + (sh.s.db ? "updated " + sh.ago(sh.s.db) : "not downloaded yet") + "   ·   Last check: " + (sh.s.lastscan ? sh.ago(sh.s.lastscan) : "never")
                            font.family: sh.body; font.pixelSize: 12; color: (sh.s.clam === "yes" && sh.dbOk) ? sh.dim : sh.warn; wrapMode: Text.Wrap; Layout.fillWidth: true
                        }
                    }

                    // big result / progress panel
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 14
                        color: (sh.scan.found && sh.scan.found.length) ? "#fdeee9" : "#f4fae8"
                        border.color: (sh.scan.found && sh.scan.found.length) ? "#f1c4b8" : sh.edge
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 8
                            Text {
                                Layout.fillWidth: true; wrapMode: Text.Wrap
                                font.family: sh.body; font.pixelSize: 16; font.weight: Font.DemiBold
                                color: (sh.scan.found && sh.scan.found.length) ? sh.bad : sh.ink
                                text: sh.scan.running ? "Checking your files…" :
                                      (sh.scan.found && sh.scan.found.length) ? sh.scan.found.length + (sh.scan.found.length === 1 ? " bad file found" : " bad files found") :
                                      sh.scan.done !== null && sh.scan.done !== undefined ? "No viruses found ✓" : "Press Quick check to start"
                            }
                            Text {
                                visible: sh.scan.running || (sh.scan.done !== null && sh.scan.done !== undefined)
                                text: (sh.scan.running ? "Checked " : "") + sh.scan.scanned.toLocaleString(Qt.locale(), "f", 0) + (sh.scan.scanned === 1 ? " file" : " files") + (sh.scan.running ? " so far…" : " checked")
                                font.family: sh.body; font.pixelSize: 12; color: sh.dim
                            }
                            Rectangle {
                                visible: sh.scan.running
                                Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: sh.soft
                                Rectangle { height: parent.height; radius: 4; color: sh.deep
                                    width: parent.width * (sh.scan.total ? Math.min(0.97, sh.scan.scanned / Math.max(sh.scan.total, sh.scan.scanned + 1)) : .05)
                                    Behavior on width { NumberAnimation { duration: 500 } } }
                            }
                            ListView {
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                                model: sh.scan.found || []
                                delegate: ColumnLayout {
                                    required property var modelData
                                    width: ListView.view.width; spacing: 0
                                    Text { text: modelData.file.split("/").pop(); font.family: sh.body; font.pixelSize: 13; font.bold: true; color: sh.ink; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                    Text { text: modelData.virus + "  ·  " + modelData.file; font.family: sh.body; font.pixelSize: 11; color: sh.dim; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                }
                            }
                            RowLayout {
                                visible: !sh.scan.running && sh.scan.found && sh.scan.found.length > 0
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Lock them away so they can't run. You can look at them later."; font.family: sh.body; font.pixelSize: 12; color: sh.dim }
                                Pill { label: "Lock them away"; danger: true; onClicked: sh.run(["quarantine"], o => { sh.note = "Bad files locked away"; sh.pollScan(); sh.refresh() }) }
                            }
                            Item { visible: !(sh.scan.found && sh.scan.found.length); Layout.fillHeight: true }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Pill { label: "Quick check"; primary: true; Layout.fillWidth: true; enabled: !sh.scan.running && !sh.dbBusy; onClicked: sh.startScan("quick") }
                        Pill { label: "Full check"; Layout.fillWidth: true; enabled: !sh.scan.running && !sh.dbBusy; onClicked: sh.startScan("full") }
                        Pill { label: "Pick a folder…"; Layout.fillWidth: true; enabled: !sh.scan.running && !sh.dbBusy; onClicked: pickFolder.open() }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Toggle { on: sh.s.daily === "yes"; onToggled: sh.run([sh.s.daily === "yes" ? "daily-off" : "daily-on"], o => { sh.note = sh.lastLine(o); sh.refresh() }) }
                        Text { Layout.fillWidth: true; text: "Check Downloads every day"; font.family: sh.body; font.pixelSize: 13; color: sh.ink }
                        Text {
                            text: sh.dbBusy ? "Updating…" : "Update virus list"
                            font.family: sh.body; font.pixelSize: 12; font.underline: true; color: sh.deep
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !sh.dbBusy; onClicked: sh.updateDb() }
                        }
                        Text {
                            visible: sh.s.quarantined > 0
                            text: "Locked away (" + sh.s.quarantined + ")"
                            font.family: sh.body; font.pixelSize: 12; font.underline: true; color: sh.deep
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sh.run(["open-quarantine"]) }
                        }
                    }
                }
            }
        }

        // ---- status line ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 34; color: "#f1f8e2"
            Rectangle { width: parent.width; height: 1; color: sh.edge }
            Text {
                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 24
                text: sh.note || (sh.fwBusy ? "Changing the firewall…" : "No password needed for scans or Home/Public. Turning the firewall off asks for it.")
                font.family: sh.body; font.pixelSize: 12; color: sh.dim
            }
        }
    }

    // ---------- small parts (colors written out: inline components can't see the window's) ----------
    component Card: Rectangle { radius: 20; color: "white"; border.color: "#e1eecb" }

    component Pill: Rectangle {
        id: pill
        property string label
        property bool primary: false
        property bool danger: false
        signal clicked()
        radius: height / 2
        implicitHeight: 42; implicitWidth: pt.implicitWidth + 36
        opacity: enabled ? 1 : .45
        color: danger ? (ma.containsMouse ? "#a83a27" : "#c4452f") : primary ? (ma.pressed ? "#2f5c0a" : ma.containsMouse ? "#356a0c" : "#3f7a0e") : (ma.containsMouse ? "#e3f3c4" : "white")
        border.width: (primary || danger) ? 0 : 1; border.color: "#cfe3a8"
        Text { id: pt; anchors.centerIn: parent; text: pill.label; font.family: "Sora"; font.pixelSize: 13; font.bold: true; color: (pill.primary || pill.danger) ? "white" : "#1b2610" }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: pill.enabled; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }

    component Toggle: Rectangle {
        id: tg
        property bool on: false
        property bool busy: false
        signal toggled()
        implicitWidth: 64; implicitHeight: 34; radius: 17
        color: on ? "#3f7a0e" : "#c9d3bd"
        opacity: busy ? .5 : 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 28; height: 28; radius: 14; y: 3; x: tg.on ? tg.width - width - 3 : 3; color: "white"
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; enabled: !tg.busy; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }

    component PlaceTile: Rectangle {
        id: pt2
        property string title
        property string tag
        property string text
        property string icon
        property bool chosen: false
        signal picked()
        radius: 16
        color: chosen ? "#eef8dc" : (m2.containsMouse ? "#f7fbef" : "white")
        border.width: chosen ? 2.5 : 1
        border.color: chosen ? "#3f7a0e" : "#e1eecb"
        opacity: enabled ? 1 : .6
        RowLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 14
            Rectangle {
                Layout.preferredWidth: 52; Layout.preferredHeight: 52; radius: 14
                color: pt2.chosen ? "#3f7a0e" : "#e3f3c4"
                Canvas {
                    anchors.fill: parent; anchors.margins: 8
                    property bool c: pt2.chosen
                    onCChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d"); g.reset(); g.scale(width / 64, height / 64)
                        g.lineWidth = 4.5; g.lineCap = "round"; g.lineJoin = "round"; g.strokeStyle = pt2.chosen ? "#ffffff" : "#3f7a0e"
                        g.path = pt2.icon; g.stroke()
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 3
                RowLayout {
                    spacing: 8
                    Text { text: pt2.title; font.family: "Unbounded"; font.weight: Font.ExtraBold; font.pixelSize: 16; color: "#1b2610" }
                    Rectangle {
                        radius: 9; implicitHeight: 20; implicitWidth: tagT.implicitWidth + 14; color: "#e3f3c4"
                        Text { id: tagT; anchors.centerIn: parent; text: pt2.tag; font.family: "Sora"; font.pixelSize: 11; font.bold: true; color: "#3f7a0e" }
                    }
                }
                Text { Layout.fillWidth: true; text: pt2.text; wrapMode: Text.Wrap; font.family: "Sora"; font.pixelSize: 12; color: "#5f6d52" }
            }
            Rectangle {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                color: pt2.chosen ? "#3f7a0e" : "transparent"; border.width: pt2.chosen ? 0 : 2; border.color: "#cfe3a8"
                Text { anchors.centerIn: parent; visible: pt2.chosen; text: "✓"; color: "white"; font.bold: true; font.pixelSize: 13 }
            }
        }
        MouseArea { id: m2; anchors.fill: parent; hoverEnabled: true; enabled: pt2.enabled; cursorShape: Qt.PointingHandCursor; onClicked: pt2.picked() }
    }
}
