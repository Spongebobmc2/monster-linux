// Monster Magic window ("Slime Pop" look).
// Left: the 10 buttons, each with its last result. Right: findings (green / amber / red),
// a Fix it button on every amber or red finding, Fix all, recommended steps, and details.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.plasma.plasma5support as P5Support

Rectangle {
    id: magic
    color: "#fbfdf6"

    readonly property color ink: "#1b2610"
    readonly property color dim: "#5f6d52"
    readonly property color lime: "#8cc22a"
    readonly property color deep: "#3f7a0e"
    readonly property color soft: "#e3f3c4"
    readonly property color edge: "#e1eecb"
    readonly property color good: "#2f8a4a"
    readonly property color warn: "#c27d0e"
    readonly property color bad: "#c4452f"
    readonly property string head: "Unbounded"
    readonly property string body: "Sora"
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../code/magic.sh").toString().replace("file://", ""))

    // [key, title, promise, icon path (64 grid)]
    readonly property var buttons: [
        ["safe",      "Am I Safe?",              "Firewall, updates, Secure Boot, virus check",       "M32 8 L52 16 V30 C52 44 43 52 32 56 C21 52 12 44 12 30 V16 Z M23 32 L30 39 L42 25"],
        ["drive",     "Drive Check",             "SSD health, TRIM and firmware",                    "M10 18 H54 V46 H10 Z M10 36 H54 M44 41 H48"],
        ["plug",      "Plug and Play Check",     "Sound, Bluetooth, USB, printers, controllers",     "M24 8 V20 M40 8 V20 M18 20 H46 V30 C46 38 40 44 32 44 C24 44 18 38 18 30 Z M32 44 V56"],
        ["game",      "Make This Game Work",     "Driver, Vulkan, Proton-GE, power mode",            "M18 22 H46 C54 22 58 30 56 40 C55 46 49 48 45 43 L41 38 H23 L19 43 C15 48 9 46 8 40 C6 30 10 22 18 22 Z M20 30 V38 M16 34 H24 M42 32 H43 M46 36 H47"],
        ["fast",      "Start Fast",              "Find what slows start-up and fix it",              "M32 54 A22 22 0 1 1 32 10 A22 22 0 0 1 54 32 M32 32 L44 22 M32 32 m-3 0 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0"],
        ["space",     "Free Up Space Safely",    "Clears only things that come back",                "M16 18 H48 M26 18 V12 H38 V18 M20 18 L23 54 H41 L44 18 M28 26 V46 M36 26 V46"],
        ["looking",   "Fix What I'm Looking At", "Click a stuck app: restart, repair or reset",      "M10 32 C16 20 24 14 32 14 C40 14 48 20 54 32 C48 44 40 50 32 50 C24 50 16 44 10 32 Z M32 32 m-7 0 a7 7 0 1 0 14 0 a7 7 0 1 0 -14 0"],
        ["yesterday", "It Worked Yesterday",     "See what changed and go back",                     "M14 32 A18 18 0 1 0 20 18 M12 10 V20 H22 M32 22 V33 L40 38"],
        ["openfile",  "Open This File",          "Gets the right app for any file",                  "M18 8 H38 L48 18 V56 H18 Z M38 8 V18 H48 M25 32 H41 M25 40 H41 M25 48 H35"],
        ["windows",   "Bring My Windows Stuff",  "Copies Windows files into the right folders",      "M10 14 L30 11 V31 H10 Z M34 10 L54 7 V31 H34 Z M10 35 H30 V53 L10 50 Z M34 35 H54 V57 L34 54 Z"]
    ]

    property string current: ""
    property string currentTitle: ""
    property string arg: ""
    property bool busy: false
    property bool showFirst: false
    property bool planShown: false
    property var plan: []
    property var findings: []     // [{k: OK|WARN|FAIL|TIP, t, fix: {id,label,what}|null, done: ""}]
    property var steps: []
    property string proof: ""
    property bool showDetails: false
    property var last: ({})       // key -> "green" | "amber" | "red"
    property string fixing: ""

    readonly property int nFail: findings.filter(f => f.k === "FAIL" && !f.done).length
    readonly property int nWarn: findings.filter(f => f.k === "WARN" && !f.done).length
    readonly property var fixable: findings.filter(f => f.fix && !f.done && f.k !== "OK")
    // fixes that open something or need the user's own steps are left out of "Fix all"
    readonly property var manualFixes: ["secureboot", "printers", "open-downloads", "yesterday-go", "update", "virus", "steam", "drive-firmware", "protonplus", "empty-trash", "reset-app", "restart-app", "repair-app"]
    readonly property var autoFixable: fixable.filter(f => manualFixes.indexOf(f.fix.id) < 0)
    readonly property string tone: nFail ? "red" : nWarn ? "amber" : (proof ? "green" : "")

    // ---- helper runner ----
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
        const c = Object.assign({}, callbacks); c[cmd] = cb || function () {}; callbacks = c
        exec.connectSource(cmd)
    }
    function parse(out) {
        const F = [], S = [], P = []; let pr = ""
        out.split("\n").forEach(l => {
            const m = l.match(/^(STEP|OK|WARN|FAIL|TIP|FIX|PROOF|PLAN) ?(.*)$/)
            if (!m) return
            const k = m[1], t = m[2]
            if (k === "PROOF") pr = t
            else if (k === "PLAN") P.push(t)
            else if (k === "STEP") S.push(t)
            else if (k === "FIX") {
                const p = t.split("|"), fx = { id: p[0], label: p[1] || "Fix it", what: p[2] || "" }
                for (let i = F.length - 1; i >= 0; i--) if (F[i].k === "WARN" || F[i].k === "FAIL" || F[i].k === "TIP") { if (!F[i].fix) F[i].fix = fx; break }
            } else F.push({ k: k, t: t, fix: null, done: "" })
        })
        return { findings: F, steps: S, plan: P, proof: pr }
    }
    function remember() {
        const t = tone || "green", l = Object.assign({}, last); l[current] = t; last = l
        run(["last-set", current, t])
    }
    Component.onCompleted: run(["last-get"], o => { try { last = JSON.parse(o) } catch (e) {} })

    // ---- flow ----
    function choose(b) {
        current = b[0]; currentTitle = b[1]; findings = []; steps = []; proof = ""; plan = []; planShown = false; arg = ""; showDetails = false
        if (current === "windows") { folderPick.open(); return }
        if (current === "openfile") { filePick.open(); return }
        start()
    }
    function start() {
        if (showFirst) { busy = true; run(["plan", current], out => { busy = false; plan = parse(out).plan; planShown = true }) }
        else go()
    }
    function go() {
        planShown = false; busy = true; findings = []; steps = []; proof = ""
        const a = [current]; if (arg) a.push(arg)
        run(a, out => { busy = false; const r = parse(out); findings = r.findings; steps = r.steps; proof = r.proof; remember() })
    }
    function applyFix(f, then) {
        fixing = f.fix.id
        run(["fix", f.fix.id], out => {
            fixing = ""
            const r = parse(out)
            const ok = r.findings.length && r.findings.every(x => x.k === "OK" || x.k === "TIP")
            const msg = r.findings.map(x => x.t).join(" · ")
            // the drive and space fixes re-run a whole check: show its fresh results instead
            if (f.fix.id === "space" || f.fix.id === "drive") { findings = r.findings; steps = r.steps; proof = r.proof; remember(); if (then) then(); return }
            const L = findings.map(x => x === f ? Object.assign({}, x, { done: ok ? "✓ " + msg : "", k: ok ? x.k : "FAIL", t: ok ? x.t : x.t + " — " + msg }) : x)
            findings = L; remember(); if (then) then()
        })
    }
    function fixAll() {
        const todo = autoFixable
        const next = i => { if (i >= todo.length) return; const f = findings.find(x => x.fix && x.fix.id === todo[i].fix.id && !x.done); if (f) applyFix(f, () => next(i + 1)); else next(i + 1) }
        next(0)
    }
    function toneColor(t) { return t === "red" ? bad : t === "amber" ? warn : t === "green" ? good : edge }

    FolderDialog { id: folderPick; title: "Pick the Windows user folder (Windows drive → Users → your name)"
        onAccepted: { magic.arg = decodeURIComponent(selectedFolder.toString().replace("file://", "")); magic.start() } }
    FileDialog { id: filePick; title: "Pick the file you want to open"
        onAccepted: { magic.arg = decodeURIComponent(selectedFile.toString().replace("file://", "")); magic.start() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- lime header ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 96; color: magic.lime
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24; spacing: 14
                Image { source: "../images/magic.png"; Layout.preferredWidth: 58; Layout.preferredHeight: 58; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "Monster Magic"; font.family: magic.head; font.weight: Font.ExtraBold; font.pixelSize: 22; color: "#14200a" }
                    Text { text: "One button. Real fixes. Proof every time."; font.family: magic.body; font.pixelSize: 12.5; color: "#24360f" }
                }
                Toggle { on: magic.showFirst; onToggled: magic.showFirst = !magic.showFirst }
                Text { text: "Show me the plan first"; font.family: magic.body; font.pixelSize: 12.5; font.bold: true; color: "#14200a" }
            }
        }
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 14; clip: true
            Row { Repeater { model: Math.ceil(magic.width / 34) + 1
                Item { width: 34; height: 14
                    Rectangle { x: 1; y: -9; width: 18; height: 18; radius: 9; color: magic.lime }
                    Rectangle { x: 21.5; y: -5.5; width: 11; height: 11; radius: 5.5; color: magic.lime } } } }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.bottomMargin: 16; Layout.topMargin: 4
            spacing: 16

            // ---- the 10 buttons ----
            GridLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(magic.width * 0.46)
                Layout.maximumWidth: Math.round(magic.width * 0.46)
                columns: 2; rowSpacing: 10; columnSpacing: 10
                Repeater {
                    model: magic.buttons
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool on: magic.current === modelData[0]
                        readonly property string res: magic.last[modelData[0]] || ""
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 70
                        radius: 16
                        color: on ? "#eef8dc" : (ma.containsMouse ? "#f7fbef" : "white")
                        border.width: on ? 2.5 : 1; border.color: on ? magic.deep : magic.edge
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 12
                                color: card.on ? magic.deep : magic.soft
                                Canvas {
                                    anchors.fill: parent; anchors.margins: 8
                                    property bool c: card.on
                                    onCChanged: requestPaint()
                                    onPaint: { const g = getContext("2d"); g.reset(); g.scale(width / 64, height / 64)
                                        g.lineWidth = 4.6; g.lineCap = "round"; g.lineJoin = "round"; g.strokeStyle = card.on ? "#ffffff" : "#3f7a0e"
                                        g.path = card.modelData[3]; g.stroke() }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: card.modelData[1]; font.family: magic.body; font.pixelSize: 14; font.bold: true; color: magic.ink; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: card.modelData[2]; font.family: magic.body; font.pixelSize: 11; color: magic.dim; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                            }
                            Rectangle {
                                visible: card.res !== ""
                                Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6
                                color: magic.toneColor(card.res)
                            }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: !magic.busy && magic.fixing === ""; cursorShape: Qt.PointingHandCursor; onClicked: magic.choose(card.modelData) }
                    }
                }
            }

            // ---- results ----
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 20; color: "white"; border.color: magic.edge
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 12

                    // title + status banner
                    Text { text: magic.current === "" ? "Pick a button" : magic.currentTitle; font.family: magic.head; font.weight: Font.ExtraBold; font.pixelSize: 19; color: magic.ink; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text {
                        visible: magic.current === ""
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                        text: "Every button checks one thing, shows green, amber or red, and gives you a Fix it button for anything that isn't green. Changes that need your password ask first."
                        font.family: magic.body; font.pixelSize: 13; color: magic.dim
                    }
                    Rectangle {
                        visible: magic.proof !== "" && !magic.busy
                        Layout.fillWidth: true; radius: 14; implicitHeight: banner.implicitHeight + 24
                        color: magic.tone === "red" ? "#fdeee9" : magic.tone === "amber" ? "#fff6e3" : "#eef8dc"
                        border.color: magic.toneColor(magic.tone); border.width: 1.5
                        RowLayout {
                            id: banner
                            anchors.fill: parent; anchors.margins: 12; spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17; color: magic.toneColor(magic.tone)
                                Text { anchors.centerIn: parent; text: magic.tone === "green" ? "✓" : "!"; color: "white"; font.bold: true; font.pixelSize: 17 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text {
                                    text: magic.tone === "red" ? magic.nFail + " to fix" + (magic.nWarn ? " · " + magic.nWarn + " to look at" : "")
                                        : magic.tone === "amber" ? magic.nWarn + (magic.nWarn === 1 ? " thing" : " things") + " worth fixing" : "All good"
                                    font.family: magic.body; font.pixelSize: 15; font.bold: true; color: magic.ink
                                }
                                Text { text: magic.proof; font.family: magic.body; font.pixelSize: 12; color: magic.dim; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            }
                            Pill { visible: magic.autoFixable.length > 1; label: "Fix all (" + magic.autoFixable.length + ")"; primary: true; enabled: magic.fixing === ""; onClicked: magic.fixAll() }
                        }
                    }

                    // plan
                    ColumnLayout {
                        visible: magic.planShown
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "Here's what I'll do"; font.family: magic.body; font.pixelSize: 14; font.bold: true; color: magic.ink }
                        Repeater { model: magic.plan
                            delegate: Text { required property string modelData; required property int index
                                text: (index + 1) + ".  " + modelData; font.family: magic.body; font.pixelSize: 13; color: magic.ink; wrapMode: Text.Wrap; Layout.fillWidth: true } }
                        RowLayout { spacing: 8
                            Pill { label: "Do it"; primary: true; onClicked: magic.go() }
                            Pill { label: "Cancel"; onClicked: { magic.planShown = false; magic.current = "" } } }
                    }

                    RowLayout {
                        visible: magic.busy
                        spacing: 12
                        QQC2.BusyIndicator { running: magic.busy; implicitWidth: 34; implicitHeight: 34 }
                        Text { text: magic.current === "looking" ? "Click the window that's misbehaving…" : "Checking… (a password box may pop up)"; font.family: magic.body; font.pixelSize: 13; color: magic.dim }
                    }

                    // findings
                    QQC2.ScrollView {
                        id: sv
                        Layout.fillWidth: true; Layout.fillHeight: true
                        visible: magic.findings.length > 0 && !magic.busy
                        clip: true; contentWidth: availableWidth
                        ColumnLayout {
                            width: sv.availableWidth; spacing: 6
                            Repeater {
                                model: magic.findings
                                delegate: Rectangle {
                                    id: row
                                    required property var modelData
                                    readonly property var f: modelData
                                    readonly property string kk: f.done ? "OK" : f.k
                                    Layout.fillWidth: true
                                    implicitHeight: rl.implicitHeight + 18
                                    radius: 12
                                    color: kk === "FAIL" ? "#fdeee9" : kk === "WARN" ? "#fff6e3" : kk === "TIP" ? "#f4f8ff" : "#f7fbef"
                                    RowLayout {
                                        id: rl
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                        Rectangle {
                                            Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10
                                            color: row.kk === "FAIL" ? magic.bad : row.kk === "WARN" ? magic.warn : row.kk === "TIP" ? "#3a73c9" : magic.good
                                            Text { anchors.centerIn: parent; color: "white"; font.bold: true; font.pixelSize: 11
                                                text: row.kk === "OK" ? "✓" : row.kk === "TIP" ? "i" : "!" }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 1
                                            Text { text: (row.f.k === "TIP" ? "Recommended: " : "") + row.f.t; font.family: magic.body; font.pixelSize: 12.5; color: magic.ink; wrapMode: Text.Wrap; Layout.fillWidth: true; font.bold: row.kk === "FAIL" }
                                            Text { visible: row.f.done !== ""; text: row.f.done; font.family: magic.body; font.pixelSize: 11.5; color: magic.good; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                            Text { visible: !!row.f.fix && !row.f.done; text: row.f.fix ? row.f.fix.what : ""; font.family: magic.body; font.pixelSize: 11; color: magic.dim; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                        }
                                        Pill {
                                            visible: !!row.f.fix && !row.f.done
                                            label: magic.fixing !== "" && row.f.fix && magic.fixing === row.f.fix.id ? "Fixing…" : (row.f.fix ? row.f.fix.label : "")
                                            primary: row.f.k !== "TIP"; small: true
                                            enabled: magic.fixing === ""
                                            onClicked: magic.applyFix(row.f)
                                        }
                                    }
                                }
                            }
                            // details
                            Text {
                                visible: magic.steps.length > 0
                                text: (magic.showDetails ? "▾ Hide details" : "▸ Show details") + " (" + magic.steps.length + ")"
                                font.family: magic.body; font.pixelSize: 12; color: magic.deep; Layout.topMargin: 6
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: magic.showDetails = !magic.showDetails }
                            }
                            Repeater { model: magic.showDetails ? magic.steps : []
                                delegate: Text { required property string modelData; text: modelData; font.family: "JetBrains Mono"; font.pixelSize: 11; color: magic.dim; wrapMode: Text.Wrap; Layout.fillWidth: true } }
                        }
                    }
                    Item { Layout.fillHeight: true; visible: magic.findings.length === 0 || magic.busy }
                }
            }
        }
    }

    // ---------- small parts (inline components can't see the window's colors, so they're written out) ----------
    component Pill: Rectangle {
        id: pill
        property string label
        property bool primary: false
        property bool small: false
        signal clicked()
        radius: height / 2
        implicitHeight: small ? 32 : 40; implicitWidth: pt.implicitWidth + (small ? 26 : 36)
        opacity: enabled ? 1 : .45
        color: primary ? (ma2.pressed ? "#2f5c0a" : ma2.containsMouse ? "#356a0c" : "#3f7a0e") : (ma2.containsMouse ? "#e3f3c4" : "white")
        border.width: primary ? 0 : 1; border.color: "#cfe3a8"
        Text { id: pt; anchors.centerIn: parent; text: pill.label; font.family: "Sora"; font.pixelSize: pill.small ? 12 : 13; font.bold: true; color: pill.primary ? "white" : "#1b2610" }
        MouseArea { id: ma2; anchors.fill: parent; hoverEnabled: true; enabled: pill.enabled; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        signal toggled()
        implicitWidth: 52; implicitHeight: 28; radius: 14
        color: on ? "#3f7a0e" : Qt.rgba(1, 1, 1, .55)
        Rectangle { width: 22; height: 22; radius: 11; y: 3; x: tg.on ? tg.width - width - 3 : 3; color: "white"
            Behavior on x { NumberAnimation { duration: 150 } } }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }
}
