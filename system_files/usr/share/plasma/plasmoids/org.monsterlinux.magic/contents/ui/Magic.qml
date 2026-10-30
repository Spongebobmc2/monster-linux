// Monster Magic window: left = the 10 buttons, right = what the button is doing and its proof.
// Every button: (optional) show the plan first → run → OK/FAIL lines → big PROOF box.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.plasma.plasma5support as P5Support

Rectangle {
    id: magic
    color: "#0e140a"

    // Gloop colors
    readonly property color panel: "#141c0e"
    readonly property color card: "#1a2412"
    readonly property color line: "#2a3a1c"
    readonly property color ink: "#dde6cf"
    readonly property color dim: "#8a9878"
    readonly property color lime: "#a8e03a"
    readonly property color good: "#5fc8a0"
    readonly property color warn: "#e8b03d"
    readonly property color bad: "#d9574a"
    readonly property string font: "Noto Sans"

    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../code/magic.sh").toString().replace("file://", ""))

    // [key, number, title, promise, ready?]
    readonly property var buttons: [
        ["windows",   1, "Bring My Windows Stuff", "Copies your Windows files into the right folders", true],
        ["game",      2, "Make This Game Work", "Tries the known-good setups until your game starts", false],
        ["yesterday", 3, "It Worked Yesterday", "Shows what changed and takes you back to the last good system", true],
        ["looking",   4, "Fix What I'm Looking At", "Click a broken window and it fixes that app", false],
        ["openfile",  5, "Open This File", "Gets the right app for any file and opens it", true],
        ["plug",      6, "Plug and Play Check", "Tests everything you plugged in", true],
        ["fast",      7, "Start Fast", "Makes your PC start quicker and shows the time saved", true],
        ["space",     8, "Free Up Space Safely", "Clears only things that come back by themselves", true],
        ["safe",      9, "Am I Safe?", "Checks your protection and fixes what it can", true],
        ["drive",    11, "Drive Check", "Checks SSD health, runs TRIM and looks for firmware updates", true]
    ]

    property bool showFirst: true          // #10 Show Me Once
    property string current: ""
    property string currentTitle: ""
    property string arg: ""
    property bool busy: false
    property var plan: []
    property var lines: []                 // [{k, t}]
    property string proof: ""
    property bool planShown: false

    // ---- running magic.sh ----
    property int runId: 0
    property var callbacks: ({})
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const cb = magic.callbacks[source]
            exec.disconnectSource(source)
            if (cb) { const c = Object.assign({}, magic.callbacks); delete c[source]; magic.callbacks = c; cb((data["stdout"] || "").trim()) }
        }
    }
    function q(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'" }
    function run(args, cb) {
        runId++
        const cmd = "bash " + q(helper) + " " + args.map(q).join(" ") + " # " + runId
        const c = Object.assign({}, callbacks); c[cmd] = cb; callbacks = c
        exec.connectSource(cmd)
    }
    function parse(out) {
        const L = [], P = []; let pr = ""
        out.split("\n").forEach(l => {
            const m = l.match(/^(STEP|OK|FAIL|PROOF|PLAN) (.*)$/)
            if (!m) return
            if (m[1] === "PROOF") pr = m[2]
            else if (m[1] === "PLAN") P.push(m[2])
            else L.push({ k: m[1], t: m[2] })
        })
        return { lines: L, plan: P, proof: pr }
    }

    // ---- button flow ----
    function choose(b) {
        current = b[0]; currentTitle = b[2]; lines = []; proof = ""; plan = []; planShown = false; arg = ""
        if (!b[4]) return
        if (current === "windows") { folderPick.open(); return }
        if (current === "openfile") { filePick.open(); return }
        start()
    }
    function start() {
        if (showFirst) {
            busy = true
            run(["plan", current], out => { busy = false; plan = parse(out).plan; planShown = true })
        } else go()
    }
    function go(which) {
        planShown = false; busy = true; lines = []; proof = ""
        const args = [which || current]; if (arg) args.push(arg)
        run(args, out => { busy = false; const r = parse(out); lines = r.lines; proof = r.proof })
    }

    FolderDialog {
        id: folderPick
        title: "Pick the Windows user folder (Windows drive → Users → your name)"
        onAccepted: { magic.arg = decodeURIComponent(selectedFolder.toString().replace("file://", "")); magic.start() }
    }
    FileDialog {
        id: filePick
        title: "Pick the file you want to open"
        onAccepted: { magic.arg = decodeURIComponent(selectedFile.toString().replace("file://", "")); magic.start() }
    }

    // ---------------- layout ----------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle { width: 12; height: 12; radius: 6; color: magic.lime }
            ColumnLayout {
                spacing: 0
                Text { text: "MONSTER MAGIC"; color: magic.ink; font.family: magic.font; font.pixelSize: 22; font.bold: true; font.letterSpacing: 3 }
                Text { text: "One button, one promise. Every button proves it worked."; color: magic.dim; font.family: magic.font; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            // #10 Show Me Once
            Rectangle {
                implicitWidth: smRow.implicitWidth + 24; implicitHeight: 38; radius: 19
                color: magic.showFirst ? "#1f2a14" : magic.card
                border.color: magic.showFirst ? magic.lime : magic.line
                RowLayout {
                    id: smRow; anchors.centerIn: parent; spacing: 8
                    Rectangle { width: 30; height: 16; radius: 8; color: magic.showFirst ? magic.lime : magic.line
                        Rectangle { width: 12; height: 12; radius: 6; y: 2; x: magic.showFirst ? 16 : 2; color: "#0e140a" } }
                    Text { text: "10 · Show Me Once"; color: magic.showFirst ? magic.lime : magic.ink; font.family: magic.font; font.pixelSize: 13; font.bold: true }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: magic.showFirst = !magic.showFirst }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // ---- the buttons ----
            GridLayout {
                Layout.fillHeight: true
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(magic.width * 0.5)
                Layout.maximumWidth: Math.round(magic.width * 0.5)
                columns: 2; rowSpacing: 10; columnSpacing: 10
                Repeater {
                    model: magic.buttons
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool ready: modelData[4]
                        readonly property bool on: magic.current === modelData[0]
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumHeight: 74
                        radius: 12
                        color: on ? "#1f2a14" : (hov.containsMouse && ready ? "#202c16" : magic.card)
                        border.color: on ? magic.lime : magic.line
                        border.width: on ? 2 : 1
                        opacity: ready ? 1 : 0.5
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 12
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: card.on ? magic.lime : "#0e140a"; border.color: magic.lime
                                Text { anchors.centerIn: parent; text: card.modelData[1]; color: card.on ? "#11180a" : magic.lime; font.family: magic.font; font.pixelSize: 15; font.bold: true }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: card.modelData[2]; color: magic.ink; font.family: magic.font; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: card.ready ? card.modelData[3] : "Coming soon: " + card.modelData[3]; color: magic.dim; font.family: magic.font; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                            }
                        }
                        MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true; enabled: !magic.busy; cursorShape: card.ready ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: magic.choose(card.modelData) }
                    }
                }
            }

            // ---- what's happening + proof ----
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 320
                radius: 14; color: magic.panel; border.color: magic.line
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 10

                    Text {
                        text: magic.current === "" ? "Pick a button" : magic.currentTitle
                        color: magic.ink; font.family: magic.font; font.pixelSize: 18; font.bold: true
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        visible: magic.current === ""
                        text: "Each button does one job, tests it, and shows you the proof.\nSystem changes ask for your password and can be undone from the boot menu."
                        color: magic.dim; font.family: magic.font; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }
                    Text {
                        visible: magic.current === "game" || magic.current === "looking"
                        text: "This button is being built. It needs Tinker, the Monster Linux AI helper, to work out the fix for your exact case."
                        color: magic.warn; font.family: magic.font; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    // plan (Show Me Once)
                    ColumnLayout {
                        visible: magic.planShown
                        Layout.fillWidth: true; spacing: 6
                        Text { text: "HERE'S WHAT I'LL DO"; color: magic.lime; font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 2 }
                        Repeater {
                            model: magic.plan
                            delegate: Text {
                                required property string modelData
                                required property int index
                                text: (index + 1) + ".  " + modelData
                                color: magic.ink; font.family: magic.font; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                            }
                        }
                        RowLayout {
                            spacing: 8; Layout.topMargin: 6
                            Rectangle {
                                implicitWidth: 120; implicitHeight: 40; radius: 10; color: magic.lime
                                Text { anchors.centerIn: parent; text: "Do it"; color: "#11180a"; font.family: magic.font; font.pixelSize: 15; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: magic.go() }
                            }
                            Rectangle {
                                implicitWidth: 100; implicitHeight: 40; radius: 10; color: magic.card; border.color: magic.line
                                Text { anchors.centerIn: parent; text: "Cancel"; color: magic.ink; font.family: magic.font; font.pixelSize: 14 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { magic.planShown = false; magic.current = "" } }
                            }
                        }
                    }

                    // working
                    RowLayout {
                        visible: magic.busy
                        spacing: 10
                        QQC2.BusyIndicator { running: magic.busy; implicitWidth: 32; implicitHeight: 32 }
                        Text { text: "Working… (a password box may pop up)"; color: magic.dim; font.family: magic.font; font.pixelSize: 13 }
                    }

                    // result lines
                    QQC2.ScrollView {
                        id: resultsView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        visible: magic.lines.length > 0
                        clip: true
                        contentWidth: availableWidth
                        ColumnLayout {
                            width: resultsView.availableWidth; spacing: 4
                            Repeater {
                                model: magic.lines
                                delegate: Text {
                                    required property var modelData
                                    text: (modelData.k === "OK" ? "✓  " : modelData.k === "FAIL" ? "✗  " : "•  ") + modelData.t
                                    color: modelData.k === "OK" ? magic.good : modelData.k === "FAIL" ? magic.bad : magic.dim
                                    font.family: modelData.t.startsWith("  ") ? "monospace" : magic.font; font.pixelSize: 13
                                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true; visible: magic.lines.length === 0 }

                    // the proof
                    Rectangle {
                        visible: magic.proof !== ""
                        Layout.fillWidth: true
                        implicitHeight: proofText.implicitHeight + 28
                        radius: 12
                        readonly property color tone: magic.proof.startsWith("RED") ? magic.bad : magic.proof.startsWith("AMBER") ? magic.warn : magic.lime
                        color: Qt.rgba(tone.r, tone.g, tone.b, 0.12); border.color: tone; border.width: 2
                        Text {
                            id: proofText
                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 14
                            text: "PROOF  ·  " + magic.proof
                            color: parent.tone; font.family: magic.font; font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap
                        }
                    }

                    // extra action for "Drive Check": install firmware updates it found
                    Rectangle {
                        visible: magic.current === "drive" && magic.proof.indexOf("update(s) available") >= 0 && !magic.busy
                        implicitWidth: 240; implicitHeight: 42; radius: 10; color: magic.lime
                        Text { anchors.centerIn: parent; text: "Install firmware updates"; color: "#11180a"; font.family: magic.font; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: magic.go("drive-firmware") }
                    }

                    // extra action for "It Worked Yesterday"
                    Rectangle {
                        visible: magic.current === "yesterday" && magic.proof !== "" && !magic.busy && magic.proof.indexOf("Restart") < 0
                        implicitWidth: 260; implicitHeight: 42; radius: 10; color: magic.lime
                        Text { anchors.centerIn: parent; text: "Go back to the previous system"; color: "#11180a"; font.family: magic.font; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: magic.go("yesterday-go") }
                    }
                }
            }
        }
    }
}
