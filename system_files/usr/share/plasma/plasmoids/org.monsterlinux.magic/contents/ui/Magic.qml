// Monster Magic window ("Slime Pop" look).
// Left: brand, PC health score with "Check everything", and the 10 checks grouped.
// Right: the chosen check: Run, summary numbers, "Needs attention" with a fix button on every
// amber/red finding (+ Fix all), recommended steps, "All good", and details.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Effects
import org.kde.plasma.plasma5support as P5Support

Rectangle {
    id: magic
    color: "#f3f7ea"

    readonly property color ink: "#17210f"
    readonly property color dim: "#5d6b50"
    readonly property color deep: "#3f7a0e"
    readonly property color soft: "#eef5e0"
    readonly property color edge: "#e3ecd3"
    readonly property color good: "#2f8a4a"
    readonly property color warn: "#d68a12"
    readonly property color bad: "#c4452f"
    readonly property string head: "Unbounded"
    readonly property string body: "Sora"
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../code/magic.sh").toString().replace("file://", ""))

    // [key, title, what it checks, icon path (64 grid), group]
    readonly property var buttons: [
        ["safe",      "Am I Safe?",              "Firewall, updates, Secure Boot, SELinux, open network doors and virus check.", "M32 8 L52 16 V30 C52 44 43 52 32 56 C21 52 12 44 12 30 V16 Z M23 32 L30 39 L42 25", "Protect"],
        ["drive",     "Drive Check",             "Drive health, wear and temperature, TRIM, and firmware updates.", "M10 18 H54 V46 H10 Z M10 36 H54 M44 41 H48", "Protect"],
        ["plug",      "Plug and Play Check",     "Sound, microphone, Bluetooth, USB, cameras, controllers and printers.", "M24 8 V20 M40 8 V20 M18 20 H46 V30 C46 38 40 44 32 44 C24 44 18 38 18 30 Z M32 44 V56", "Fix problems"],
        ["game",      "Make This Game Work",     "Graphics driver, Vulkan, Steam, Proton-GE, GameMode, power mode and space.", "M18 22 H46 C54 22 58 30 56 40 C55 46 49 48 45 43 L41 38 H23 L19 43 C15 48 9 46 8 40 C6 30 10 22 18 22 Z M20 30 V38 M16 34 H24", "Fix problems"],
        ["looking",   "Fix What I'm Looking At", "Click a stuck or misbehaving window, then restart, repair or reset it.", "M10 32 C16 20 24 14 32 14 C40 14 48 20 54 32 C48 44 40 50 32 50 C24 50 16 44 10 32 Z M25 32 a7 7 0 1 0 14 0 a7 7 0 1 0 -14 0", "Fix problems"],
        ["yesterday", "It Worked Yesterday",     "See what changed in the system and go back to the last good one.", "M14 32 A18 18 0 1 0 20 18 M12 10 V20 H22 M32 22 V33 L40 38", "Fix problems"],
        ["fast",      "Start Fast",              "Measure start-up time and remove what slows it down.", "M32 54 A22 22 0 1 1 32 10 A22 22 0 0 1 54 32 M32 32 L44 22", "Speed & space"],
        ["space",     "Free Up Space Safely",    "Clear only things that come back by themselves, and find big folders.", "M16 18 H48 M26 18 V12 H38 V18 M20 18 L23 54 H41 L44 18 M28 26 V46 M36 26 V46", "Speed & space"],
        ["openfile",  "Open This File",          "Get the right free app for any file and open it.", "M18 8 H38 L48 18 V56 H18 Z M38 8 V18 H48 M25 32 H41 M25 40 H41", "Move in"],
        ["windows",   "Bring My Windows Stuff",  "Copy Desktop, Documents, Pictures, Music, Videos and Downloads from Windows.", "M10 14 L30 11 V31 H10 Z M34 10 L54 7 V31 H34 Z M10 35 H30 V53 L10 50 Z M34 35 H54 V57 L34 54 Z", "Move in"]
    ]
    // the checks "Check everything" runs (the others need you to pick something)
    readonly property var checkKeys: ["safe", "drive", "plug", "game", "yesterday", "fast"]
    readonly property string allIcon: "M32 6 L36 26 L56 32 L36 38 L32 58 L28 38 L8 32 L28 26 Z"

    property var sel: buttons[0]                 // selected button row, or the "all" pseudo row
    property string arg: ""
    property bool busy: false
    property string busyText: ""
    property bool showFirst: false
    property bool planShown: false
    property var plan: []
    property var findings: []                    // [{k, t, fix, done, src}]
    property var steps: []
    property string proof: ""
    property bool ran: false
    property bool showDetails: false
    property var last: ({})                      // key -> "tone|label"
    property string fixing: ""

    readonly property var attention: findings.filter(f => (f.k === "WARN" || f.k === "FAIL" || f.k === "TIP") && !f.done)
    readonly property var allGood: findings.filter(f => f.k === "OK" || f.done)
    readonly property int nFail: findings.filter(f => f.k === "FAIL" && !f.done).length
    readonly property int nWarn: findings.filter(f => f.k === "WARN" && !f.done).length
    readonly property var manualFixes: ["secureboot", "printers", "open-downloads", "yesterday-go", "update", "virus", "steam", "drive-firmware", "protonplus", "empty-trash", "reset-app", "restart-app", "repair-app", "space", "drive"]
    readonly property var autoFixable: findings.filter(f => f.fix && !f.done && f.k !== "OK" && f.k !== "TIP" && manualFixes.indexOf(f.fix.id) < 0)
    readonly property int greenCount: buttons.filter(b => (last[b[0]] || "").startsWith("green")).length
    readonly property int amberCount: buttons.filter(b => (last[b[0]] || "").startsWith("amber") || (last[b[0]] || "").startsWith("red")).length

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
    function parse(out, src) {
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
                for (let i = F.length - 1; i >= 0; i--) if (F[i].k !== "OK") { if (!F[i].fix) F[i].fix = fx; break }
            } else F.push({ k: k, t: t, fix: null, done: "", src: src || "" })
        })
        return { findings: F, steps: S, plan: P, proof: pr }
    }
    function toneOf(F) { return F.some(f => f.k === "FAIL" && !f.done) ? "red" : F.some(f => f.k === "WARN" && !f.done) ? "amber" : "green" }
    function labelOf(F, tone) {
        const n = F.filter(f => (f.k === "WARN" || f.k === "FAIL") && !f.done).length
        return tone === "green" ? "All good" : n + " to fix"
    }
    function remember(key, F) {
        const t = toneOf(F), v = t + "|" + labelOf(F, t)
        const l = Object.assign({}, last); l[key] = v; last = l
        run(["last-set", key, v])
    }
    function chipOf(key) { const v = last[key] || ""; return v ? { tone: v.split("|")[0], text: v.split("|")[1] || "" } : null }
    Component.onCompleted: run(["last-get"], o => { try { last = JSON.parse(o) } catch (e) {} })

    // ---- flow ----
    function select(b) {
        if (busy || fixing) return
        sel = b; findings = []; steps = []; proof = ""; plan = []; planShown = false; arg = ""; ran = false; showDetails = false
    }
    function runSelected() {
        const k = sel[0]
        if (k === "all") { runAll(); return }
        if (k === "windows") { folderPick.open(); return }
        if (k === "openfile") { filePick.open(); return }
        start()
    }
    function start() {
        if (showFirst && !planShown) { busy = true; busyText = "Getting the plan…"; run(["plan", sel[0]], out => { busy = false; plan = parse(out).plan; planShown = true }) }
        else go()
    }
    function go() {
        planShown = false; busy = true; findings = []; steps = []; proof = ""
        busyText = sel[0] === "looking" ? "Click the window that's misbehaving…" : "Checking… (a password box may pop up)"
        const a = [sel[0]]; if (arg) a.push(arg)
        run(a, out => { busy = false; ran = true; const r = parse(out); findings = r.findings; steps = r.steps; proof = r.proof; remember(sel[0], r.findings) })
    }
    function runAll() {
        sel = ["all", "Check everything", "Runs every check on your PC, scores it and lists everything worth fixing in one place.", allIcon, ""]
        busy = true; findings = []; steps = []; proof = ""; ran = false; planShown = false
        let F = [], S = []
        const next = i => {
            if (i >= checkKeys.length) {
                busy = false; ran = true; findings = F; steps = S
                proof = checkKeys.filter(k => (last[k] || "").startsWith("green")).length + " of " + checkKeys.length + " checks are green"
                return
            }
            const b = buttons.find(x => x[0] === checkKeys[i])
            busyText = "Checking " + b[1] + "… (" + (i + 1) + " of " + checkKeys.length + ")"
            run([b[0]], out => {
                const r = parse(out, b[1])
                remember(b[0], r.findings)
                F = F.concat(r.findings); S = S.concat(r.steps.map(s => b[1] + ": " + s)); findings = F
                next(i + 1)
            })
        }
        next(0)
    }
    function applyFix(f, then) {
        fixing = f.fix.id
        run(["fix", f.fix.id], out => {
            fixing = ""
            const r = parse(out, f.src)
            if (f.fix.id === "space" || f.fix.id === "drive") {   // these re-run a whole check
                findings = f.src ? findings.filter(x => x.src !== f.src).concat(r.findings) : r.findings
                steps = r.steps; if (!f.src) proof = r.proof
                remember(f.fix.id, r.findings); if (then) then(); return
            }
            const ok = r.findings.length > 0 && r.findings.every(x => x.k === "OK" || x.k === "TIP")
            const msg = r.findings.map(x => x.t).join(" · ")
            findings = findings.map(x => x === f ? Object.assign({}, x, ok ? { done: msg } : { k: "FAIL", t: x.t + ". " + msg }) : x)
            if (sel[0] !== "all") remember(sel[0], findings)
            if (then) then()
        })
    }
    function fixAll() {
        const ids = autoFixable.map(f => f.fix.id)
        const next = i => {
            if (i >= ids.length) return
            const f = findings.find(x => x.fix && x.fix.id === ids[i] && !x.done)
            if (f) applyFix(f, () => next(i + 1)); else next(i + 1)
        }
        next(0)
    }

    FolderDialog { id: folderPick; title: "Pick the Windows user folder (Windows drive → Users → your name)"
        onAccepted: { magic.arg = decodeURIComponent(selectedFolder.toString().replace("file://", "")); magic.start() } }
    FileDialog { id: filePick; title: "Pick the file you want to open"
        onAccepted: { magic.arg = decodeURIComponent(selectedFile.toString().replace("file://", "")); magic.start() } }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ======================= SIDEBAR =======================
        Rectangle {
            Layout.preferredWidth: 318; Layout.fillHeight: true
            color: "white"
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: magic.edge }
            ColumnLayout {
                anchors.fill: parent; spacing: 0
                // brand + score
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: brandCol.implicitHeight + 40
                    gradient: Gradient { orientation: Gradient.Vertical
                        GradientStop { position: 0; color: "#a6d83c" } GradientStop { position: 1; color: "#82b822" } }
                    ColumnLayout {
                        id: brandCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 20; spacing: 14
                        RowLayout {
                            spacing: 12
                            Image { source: "../images/magic.png"; Layout.preferredWidth: 52; Layout.preferredHeight: 52; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                            ColumnLayout { spacing: 1
                                Text { text: "Monster Magic"; font.family: magic.head; font.weight: Font.ExtraBold; font.pixelSize: 20; color: "#13200a" }
                                Text { text: "One button. Real fixes. Proof."; font.family: magic.body; font.pixelSize: 11.5; color: "#25380f" } }
                        }
                        Rectangle {
                            Layout.fillWidth: true; radius: 14; color: Qt.rgba(1, 1, 1, .55); implicitHeight: scoreCol.implicitHeight + 24
                            ColumnLayout {
                                id: scoreCol
                                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 12; spacing: 10
                                RowLayout {
                                    spacing: 12
                                    Item {
                                        Layout.preferredWidth: 48; Layout.preferredHeight: 48
                                        Canvas {
                                            anchors.fill: parent
                                            property int g: magic.greenCount
                                            onGChanged: requestPaint()
                                            onPaint: { const c = getContext("2d"); c.reset(); c.lineWidth = 6; c.lineCap = "round"
                                                c.strokeStyle = "rgba(47,109,10,0.18)"; c.beginPath(); c.arc(24, 24, 20, 0, 2 * Math.PI); c.stroke()
                                                if (g > 0) { c.strokeStyle = "#2f6d0a"; c.beginPath(); c.arc(24, 24, 20, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * g / 10); c.stroke() } }
                                        }
                                        Text { anchors.centerIn: parent; text: magic.greenCount; font.family: magic.head; font.weight: Font.ExtraBold; font.pixelSize: 15; color: "#13200a" }
                                    }
                                    ColumnLayout { spacing: 1; Layout.fillWidth: true
                                        Text { text: magic.greenCount + " of 10 green"; font.family: magic.body; font.pixelSize: 13.5; font.bold: true; color: "#13200a" }
                                        Text { text: magic.amberCount ? magic.amberCount + (magic.amberCount === 1 ? " check has" : " checks have") + " things to fix" : "Press Check everything for a full checkup"
                                            font.family: magic.body; font.pixelSize: 11; color: "#2f4515"; wrapMode: Text.Wrap; Layout.fillWidth: true } }
                                }
                                Pill { Layout.fillWidth: true; label: magic.busy && magic.sel[0] === "all" ? "Checking…" : "✦  Check everything"; primary: true; enabled: !magic.busy && magic.fixing === ""; onClicked: magic.runAll() }
                            }
                        }
                    }
                }
                Item {   // drip
                    Layout.fillWidth: true; Layout.preferredHeight: 13; clip: true
                    Row { Repeater { model: 11
                        Item { width: 34; height: 13
                            Rectangle { x: 1; y: -9; width: 18; height: 18; radius: 9; color: "#82b822" }
                            Rectangle { x: 21.5; y: -5.5; width: 11; height: 11; radius: 5.5; color: "#82b822" } } } }
                }
                // nav
                QQC2.ScrollView {
                    id: navScroll
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: navScroll.availableWidth; spacing: 2
                        Item { implicitHeight: 6 }
                        Repeater {
                            model: magic.buttons
                            delegate: ColumnLayout {
                                id: nrow
                                required property var modelData
                                required property int index
                                readonly property bool on: magic.sel[0] === modelData[0]
                                readonly property var chip: magic.chipOf(modelData[0])
                                Layout.fillWidth: true; spacing: 2
                                Text {
                                    visible: nrow.index === 0 || magic.buttons[nrow.index - 1][4] !== nrow.modelData[4]
                                    text: nrow.modelData[4].toUpperCase(); font.family: magic.body; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.6; color: "#7c8a6c"
                                    Layout.leftMargin: 22; Layout.topMargin: 10; Layout.bottomMargin: 4
                                }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                                    implicitHeight: 46; radius: 12
                                    color: nrow.on ? "#eef7dc" : (nma.containsMouse ? "#f7fbef" : "transparent")
                                    border.width: nrow.on ? 1.5 : 0; border.color: magic.deep
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 10; spacing: 10
                                        Icon { path: nrow.modelData[3]; on: nrow.on; size: 32 }
                                        Text { Layout.fillWidth: true; text: nrow.modelData[1]; font.family: magic.body; font.pixelSize: 13; font.weight: Font.DemiBold; color: magic.ink; elide: Text.ElideRight }
                                        Chip { tone: nrow.chip ? nrow.chip.tone : ""; label: nrow.chip ? nrow.chip.text : "Not run" }
                                    }
                                    MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: magic.select(nrow.modelData) }
                                }
                            }
                        }
                        Item { implicitHeight: 12 }
                    }
                }
            }
        }

        // ======================= MAIN =======================
        QQC2.ScrollView {
            id: mainScroll
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: mainScroll.availableWidth
                spacing: 16

                Item { implicitHeight: 6 }

                // hero
                Card {
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24
                    implicitHeight: heroRow.implicitHeight + 40
                    RowLayout {
                        id: heroRow
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 20; spacing: 18
                        Rectangle {
                            Layout.preferredWidth: 64; Layout.preferredHeight: 64; radius: 18
                            gradient: Gradient { GradientStop { position: 0; color: "#4f9212" } GradientStop { position: 1; color: "#2f6208" } }
                            Canvas {
                                anchors.fill: parent; anchors.margins: 14
                                property string p: magic.sel[3]
                                onPChanged: requestPaint()
                                onPaint: { const g = getContext("2d"); g.reset(); g.scale(width / 64, height / 64); g.lineWidth = 4.5; g.lineCap = "round"; g.lineJoin = "round"; g.strokeStyle = "#ffffff"; g.path = p; g.stroke() }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 5
                            Text { text: magic.sel[1]; font.family: magic.head; font.weight: Font.ExtraBold; font.pixelSize: 22; color: magic.ink; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: magic.sel[2]; font.family: magic.body; font.pixelSize: 13; color: magic.dim; wrapMode: Text.Wrap; Layout.fillWidth: true }
                            RowLayout {
                                visible: magic.sel[0] !== "all"
                                spacing: 8; Layout.topMargin: 2
                                Rectangle {
                                    width: 18; height: 18; radius: 5; color: magic.showFirst ? magic.deep : "white"; border.color: "#cfe3a8"; border.width: magic.showFirst ? 0 : 1.5
                                    Text { anchors.centerIn: parent; visible: magic.showFirst; text: "✓"; color: "white"; font.bold: true; font.pixelSize: 11 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: magic.showFirst = !magic.showFirst }
                                }
                                Text { text: "Show me the plan first"; font.family: magic.body; font.pixelSize: 12; color: magic.dim }
                            }
                        }
                        Pill {
                            label: magic.busy ? "Working…" : magic.ran ? "Run again" : (magic.sel[0] === "windows" ? "Pick the folder" : magic.sel[0] === "openfile" ? "Pick the file" : magic.sel[0] === "looking" ? "Pick the window" : "Run check")
                            primary: !magic.ran; enabled: !magic.busy && magic.fixing === ""
                            onClicked: magic.runSelected()
                        }
                    }
                }

                // plan
                Card {
                    visible: magic.planShown
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; implicitHeight: planCol.implicitHeight + 36
                    ColumnLayout {
                        id: planCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 18; spacing: 8
                        Text { text: "Here's what I'll do"; font.family: magic.body; font.pixelSize: 15; font.bold: true; color: magic.ink }
                        Repeater { model: magic.plan
                            delegate: Text { required property string modelData; required property int index
                                text: (index + 1) + ".  " + modelData; font.family: magic.body; font.pixelSize: 13; color: magic.ink; wrapMode: Text.Wrap; Layout.fillWidth: true } }
                        RowLayout { spacing: 8; Layout.topMargin: 4
                            Pill { label: "Do it"; primary: true; onClicked: magic.go() }
                            Pill { label: "Cancel"; onClicked: magic.planShown = false } }
                    }
                }

                // working
                Card {
                    visible: magic.busy
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; implicitHeight: 76
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 20; spacing: 14
                        QQC2.BusyIndicator { running: magic.busy; implicitWidth: 36; implicitHeight: 36 }
                        Text { text: magic.busyText; font.family: magic.body; font.pixelSize: 13.5; color: magic.ink; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    }
                }

                // summary numbers
                RowLayout {
                    visible: magic.ran && !magic.busy && magic.findings.length > 0
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; spacing: 12
                    Stat { number: magic.nWarn; label: "things worth\nfixing"; tone: magic.warn }
                    Stat { number: magic.allGood.length; label: "checks\npassed"; tone: magic.good }
                    Stat { number: magic.nFail; label: "urgent\nproblems"; tone: magic.bad }
                }
                Text {
                    visible: magic.ran && !magic.busy && magic.proof !== ""
                    Layout.leftMargin: 28; text: magic.proof; font.family: magic.body; font.pixelSize: 12.5; color: magic.dim
                }

                // needs attention
                Card {
                    visible: magic.ran && !magic.busy && magic.attention.length > 0
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; implicitHeight: attCol.implicitHeight + 32
                    ColumnLayout {
                        id: attCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 18; spacing: 0
                        RowLayout {
                            Layout.fillWidth: true; Layout.bottomMargin: 8
                            Text { Layout.fillWidth: true; text: "Needs attention"; font.family: magic.body; font.pixelSize: 15; font.bold: true; color: magic.ink }
                            Pill { visible: magic.autoFixable.length > 1; label: "Fix all (" + magic.autoFixable.length + ")"; primary: true; enabled: magic.fixing === ""; onClicked: magic.fixAll() }
                        }
                        Repeater {
                            model: magic.attention
                            delegate: ColumnLayout {
                                id: ar
                                required property var modelData
                                required property int index
                                readonly property var f: modelData
                                Layout.fillWidth: true; spacing: 0
                                Rectangle { visible: ar.index > 0; Layout.fillWidth: true; implicitHeight: 1; color: "#f0f4e8" }
                                RowLayout {
                                    Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12; spacing: 12
                                    Rectangle {
                                        Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13; Layout.alignment: Qt.AlignTop
                                        color: ar.f.k === "FAIL" ? magic.bad : ar.f.k === "TIP" ? "#3a73c9" : magic.warn
                                        Text { anchors.centerIn: parent; text: ar.f.k === "TIP" ? "i" : "!"; color: "white"; font.bold: true; font.pixelSize: 13 }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { visible: ar.f.src !== ""; text: ar.f.src.toUpperCase(); font.family: magic.body; font.pixelSize: 9.5; font.bold: true; font.letterSpacing: 1.2; color: "#7c8a6c" }
                                        Text { text: (ar.f.k === "TIP" ? "Recommended: " : "") + ar.f.t; font.family: magic.body; font.pixelSize: 13.5; font.bold: ar.f.k !== "TIP"; color: magic.ink; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                        Text { visible: !!ar.f.fix; text: ar.f.fix ? ar.f.fix.what : ""; font.family: magic.body; font.pixelSize: 11.5; color: magic.dim; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                    }
                                    Pill {
                                        visible: !!ar.f.fix
                                        label: ar.f.fix && magic.fixing === ar.f.fix.id ? "Fixing…" : (ar.f.fix ? ar.f.fix.label : "")
                                        primary: ar.f.k === "FAIL" || (!!ar.f.fix && magic.manualFixes.indexOf(ar.f.fix.id) < 0)
                                        enabled: magic.fixing === ""
                                        onClicked: magic.applyFix(ar.f)
                                    }
                                }
                            }
                        }
                    }
                }

                // all good
                Card {
                    visible: magic.ran && !magic.busy && magic.allGood.length > 0
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; implicitHeight: goodCol.implicitHeight + 32
                    ColumnLayout {
                        id: goodCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 18; spacing: 10
                        Text { text: magic.attention.length ? "All good" : "Everything is good ✓"; font.family: magic.body; font.pixelSize: 15; font.bold: true; color: magic.ink }
                        GridLayout {
                            Layout.fillWidth: true; columns: 2; columnSpacing: 18; rowSpacing: 8
                            Repeater {
                                model: magic.allGood
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 10
                                    Rectangle { Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10; color: magic.good; Layout.alignment: Qt.AlignTop
                                        Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.bold: true; font.pixelSize: 10 } }
                                    Text { Layout.fillWidth: true; text: modelData.done ? modelData.t + " → fixed" : modelData.t; font.family: magic.body; font.pixelSize: 12.5; color: magic.ink; wrapMode: Text.Wrap }
                                }
                            }
                        }
                    }
                }

                // details
                Text {
                    visible: magic.ran && !magic.busy && magic.steps.length > 0
                    Layout.leftMargin: 28
                    text: (magic.showDetails ? "▾ Hide details" : "▸ Show details") + " (" + magic.steps.length + ")"
                    font.family: magic.body; font.pixelSize: 12; color: magic.deep
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: magic.showDetails = !magic.showDetails }
                }
                Repeater { model: magic.showDetails ? magic.steps : []
                    delegate: Text { required property string modelData; Layout.leftMargin: 28; Layout.rightMargin: 24; Layout.fillWidth: true
                        text: modelData; font.family: "JetBrains Mono"; font.pixelSize: 11; color: magic.dim; wrapMode: Text.Wrap } }

                // first visit
                Card {
                    visible: !magic.ran && !magic.busy && !magic.planShown
                    Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; implicitHeight: introCol.implicitHeight + 36
                    ColumnLayout {
                        id: introCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 18; spacing: 10
                        Text { text: "How it works"; font.family: magic.body; font.pixelSize: 15; font.bold: true; color: magic.ink }
                        Repeater {
                            model: [["1", "Press Run check. Monster Magic looks first and changes nothing yet."],
                                    ["2", "Green means fine. Amber or red comes with a button that fixes it."],
                                    ["3", "Press a fix, or Fix all. Anything that needs your password asks first."]]
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 12; Layout.fillWidth: true
                                Rectangle { Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13; color: magic.soft
                                    Text { anchors.centerIn: parent; text: modelData[0]; font.family: magic.head; font.weight: Font.ExtraBold; font.pixelSize: 12; color: magic.deep } }
                                Text { Layout.fillWidth: true; text: modelData[1]; font.family: magic.body; font.pixelSize: 13; color: magic.ink; wrapMode: Text.Wrap }
                            }
                        }
                    }
                }
                Item { implicitHeight: 20 }
            }
        }
    }

    // ---------- parts (inline components can't see the window's ids, so colors are written out) ----------
    component Card: Rectangle {
        radius: 20; color: "white"
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#40300a"; shadowOpacity: 0.10; shadowBlur: 0.7; shadowVerticalOffset: 5 }
    }
    component Stat: Rectangle {
        id: st
        property int number: 0
        property string label
        property color tone
        Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 70; radius: 18; color: "white"; border.color: "#e3ecd3"
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 12
            Text { text: st.number; font.family: "Unbounded"; font.weight: Font.ExtraBold; font.pixelSize: 28; color: st.number ? st.tone : "#b8c2ab" }
            Text { text: st.label; font.family: "Sora"; font.pixelSize: 12; color: "#5d6b50"; Layout.fillWidth: true }
        }
    }
    component Chip: Rectangle {
        id: ch
        property string tone: ""
        property string label: ""
        radius: 10; implicitHeight: 20; implicitWidth: ct.implicitWidth + 16
        color: tone === "red" ? "#fde3dd" : tone === "amber" ? "#fff1d6" : tone === "green" ? "#e5f4e9" : "#f3f6ee"
        Text { id: ct; anchors.centerIn: parent; text: ch.label; font.family: "Sora"; font.pixelSize: 10.5; font.bold: true
            color: ch.tone === "red" ? "#b23a26" : ch.tone === "amber" ? "#a8690a" : ch.tone === "green" ? "#2f8a4a" : "#9aa58e" }
    }
    component Icon: Rectangle {
        id: ic
        property string path
        property bool on: false
        property int size: 32
        implicitWidth: size; implicitHeight: size; radius: size * 0.3
        color: on ? "#3f7a0e" : "#eef5e0"
        Canvas {
            anchors.fill: parent; anchors.margins: ic.size * 0.2
            property bool c: ic.on
            onCChanged: requestPaint()
            onPaint: { const g = getContext("2d"); g.reset(); g.scale(width / 64, height / 64); g.lineWidth = 5; g.lineCap = "round"; g.lineJoin = "round"; g.strokeStyle = ic.on ? "#ffffff" : "#3f7a0e"; g.path = ic.path; g.stroke() }
        }
    }
    component Pill: Rectangle {
        id: pill
        property string label
        property bool primary: false
        signal clicked()
        radius: height / 2
        implicitHeight: 40; implicitWidth: pt.implicitWidth + 38
        opacity: enabled ? 1 : .45
        color: primary ? (ma2.pressed ? "#2f5c0a" : ma2.containsMouse ? "#356a0c" : "#3f7a0e") : (ma2.containsMouse ? "#eef7dc" : "white")
        border.width: primary ? 0 : 1.5; border.color: "#cfe3a8"
        Text { id: pt; anchors.centerIn: parent; text: pill.label; font.family: "Sora"; font.pixelSize: 13; font.bold: true; color: pill.primary ? "white" : "#1b2610" }
        MouseArea { id: ma2; anchors.fill: parent; hoverEnabled: true; enabled: pill.enabled; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }
}
