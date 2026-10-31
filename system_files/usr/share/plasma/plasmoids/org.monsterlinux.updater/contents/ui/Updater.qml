// Monster Updater window — "Slime Pop" look.
// Starts Bazzite's own updater (the same one "ujust update" uses) and shows each step.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasma5support as P5Support

Rectangle {
    id: up
    color: "#fbfdf6"

    readonly property color ink: "#1b2610"
    readonly property color dim: "#5f6d52"
    readonly property color lime: "#8cc22a"
    readonly property color deep: "#3f7a0e"
    readonly property color soft: "#e3f3c4"
    readonly property color edge: "#e1eecb"
    readonly property color bad: "#c4452f"
    readonly property string head: "Unbounded"
    readonly property string body: "Sora"

    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../code/updater.sh").toString().replace("file://", ""))

    // the four parts Bazzite's updater goes through, in its own order
    readonly property var steps: [
        ["system",    "System",            "Monster Linux itself, drivers and firmware"],
        ["brew",      "Command-line tools", "Tools installed with Homebrew"],
        ["flatpak",   "Apps",              "Everything from the app store"],
        ["distrobox", "Containers",        "Extra Linux boxes, if you made any"]
    ]

    property string phase: "idle"        // idle | running | done | failed | missing
    property var st: ({ overall: 0, modules: {}, title: "", desc: "", msg: "" })
    property bool staged: false
    property string version: ""

    // ---- running the helper ----
    property int runId: 0
    property var callbacks: ({})
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const cb = up.callbacks[source]
            exec.disconnectSource(source)
            if (cb) { const c = Object.assign({}, up.callbacks); delete c[source]; up.callbacks = c; cb((data["stdout"] || "").trim()) }
        }
    }
    function q(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'" }
    function run(args, cb) {
        runId++
        const cmd = "bash " + q(helper) + " " + args.map(q).join(" ") + " # " + runId
        const c = Object.assign({}, callbacks); c[cmd] = cb || function () {}; callbacks = c
        exec.connectSource(cmd)
    }

    function poll() {
        run(["status"], out => {
            let s
            try { s = JSON.parse(out) } catch (e) { return }
            st = s
            if (s.done !== null && s.done !== undefined) {
                pollTimer.stop()
                phase = (s.done === 0 && s.fails === 0) ? "done" : "failed"
                run(["staged"], o => staged = (o === "YES"))
            } else if (s.running) {
                phase = "running"
                if (!pollTimer.running) pollTimer.start()
            }
        })
    }
    function startUpdate() {
        st = { overall: 0, modules: {}, title: "", desc: "", msg: "" }
        phase = "running"
        run(["start"], out => {
            if (out === "MISSING") { phase = "missing"; return }
            pollTimer.start()
        })
    }
    Timer { id: pollTimer; interval: 1000; repeat: true; onTriggered: up.poll() }
    Component.onCompleted: { run(["version"], o => version = o); poll() }

    function stepState(key) {
        const m = st.modules || {}
        if (m[key]) return m[key]            // starting | running | ok | fail
        if (phase === "done" || phase === "failed") return "skip"
        return "wait"
    }
    function headline() {
        if (phase === "running") return st.title ? "Updating " + friendly(st.title) : "Checking for updates…"
        if (phase === "done") return staged ? "Ready. Restart to finish." : "Everything is up to date"
        if (phase === "failed") return "Some updates did not finish"
        if (phase === "missing") return "The updater is not installed"
        return "Keep your PC fresh and safe"
    }
    function friendly(t) {
        const k = ("" + t).toLowerCase()
        for (let i = 0; i < steps.length; i++) if (steps[i][0] === k) return steps[i][1].toLowerCase()
        return t
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- lime header ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            color: up.lime
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 14
                Image { source: "../images/gloop.png"; Layout.preferredWidth: 54; Layout.preferredHeight: 56; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "Monster Updater"; font.family: up.head; font.weight: Font.ExtraBold; font.pixelSize: 21; color: "#14200a" }
                    Text { text: "System, drivers, apps. One button."; font.family: up.body; font.pixelSize: 13; color: "#24360f" }
                }
                Rectangle {
                    visible: up.version !== ""
                    radius: height / 2; color: Qt.rgba(1, 1, 1, .45)
                    implicitWidth: verT.implicitWidth + 20; implicitHeight: 24
                    Text { id: verT; anchors.centerIn: parent; text: "MONSTER LINUX " + up.version; font.family: up.body; font.pixelSize: 11; font.bold: true; color: "#14200a" }
                }
            }
        }
        // ---- drip edge ----
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 14
            clip: true
            Row {
                Repeater {
                    model: Math.ceil(up.width / 34) + 1
                    Item {
                        width: 34; height: 14
                        Rectangle { x: 1; y: -9; width: 18; height: 18; radius: 9; color: up.lime }
                        Rectangle { x: 21.5; y: -5.5; width: 11; height: 11; radius: 5.5; color: up.lime }
                    }
                }
            }
        }

        // ---- progress card ----
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.leftMargin: 22; Layout.rightMargin: 22; Layout.topMargin: 8; Layout.bottomMargin: 18
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: card.implicitHeight + 32
                radius: 18; color: "white"; border.color: up.edge
                ColumnLayout {
                    id: card
                    anchors.fill: parent; anchors.margins: 16
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: up.headline(); font.family: up.body; font.pixelSize: 16; font.weight: Font.DemiBold; color: up.phase === "failed" ? up.bad : up.ink; wrapMode: Text.Wrap; Layout.fillWidth: true }
                            Text {
                                text: up.phase === "running" ? (up.st.desc || "This can take a few minutes") :
                                      up.phase === "failed" ? (up.st.msg || "Check your internet, then try again") :
                                      up.phase === "done" ? (up.staged ? "The new system is ready and starts after a restart." : "Nothing else to do.") :
                                      up.phase === "missing" ? "Run \"ujust update\" in Konsole instead." :
                                      "Updates run in the background. You can keep using your PC."
                                font.family: up.body; font.pixelSize: 12; color: up.dim; wrapMode: Text.Wrap; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2
                            }
                        }
                        Text {
                            visible: up.phase === "running" || up.phase === "done"
                            text: Math.round(up.st.overall || 0) + "%"
                            font.family: up.head; font.weight: Font.ExtraBold; font.pixelSize: 36; color: up.deep
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: up.soft
                        Rectangle {
                            height: parent.height; radius: 4; color: up.phase === "failed" ? up.bad : up.deep
                            width: parent.width * Math.max(0, Math.min(1, (up.st.overall || 0) / 100))
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            // ---- the steps ----
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: stepCol.implicitHeight
                radius: 18; color: "white"; border.color: up.edge
                clip: true
                Column {
                    id: stepCol
                    width: parent.width
                    Repeater {
                        model: up.steps
                        Item {
                            width: stepCol.width; height: 58
                            readonly property string s: up.stepState(modelData[0])
                            Rectangle { visible: index > 0; width: parent.width - 32; x: 16; height: 1; color: up.edge }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                                // status dot
                                Item {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                    Rectangle {
                                        anchors.fill: parent; radius: 13
                                        color: s === "ok" ? up.deep : s === "fail" ? up.bad : (s === "running" || s === "starting") ? up.soft : "transparent"
                                        border.width: (s === "wait" || s === "skip") ? 2 : 0; border.color: up.edge
                                        Text { anchors.centerIn: parent; visible: s === "ok" || s === "fail"; text: s === "ok" ? "✓" : "!"; color: "white"; font.bold: true; font.pixelSize: 14 }
                                    }
                                    Canvas {
                                        anchors.fill: parent; visible: s === "running" || s === "starting"
                                        onPaint: { const c = getContext("2d"); c.reset(); c.lineWidth = 3; c.lineCap = "round"; c.strokeStyle = up.deep; c.beginPath(); c.arc(13, 13, 10, 0, Math.PI * 1.3); c.stroke() }
                                        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: visible }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text { text: modelData[1]; font.family: up.body; font.pixelSize: 14; font.weight: Font.DemiBold; color: s === "skip" ? up.dim : up.ink }
                                    Text { text: modelData[2]; font.family: up.body; font.pixelSize: 12; color: up.dim; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                Rectangle {
                                    radius: 10; implicitHeight: 22; implicitWidth: chip.implicitWidth + 16
                                    color: s === "fail" ? "#fbe3de" : up.soft
                                    visible: s !== "wait"
                                    Text {
                                        id: chip; anchors.centerIn: parent
                                        text: s === "ok" ? "Done" : s === "fail" ? "Failed" : s === "skip" ? "Not needed" : "Working"
                                        font.family: up.body; font.pixelSize: 11; font.bold: true; color: s === "fail" ? up.bad : up.deep
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // ---- buttons ----
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: up.phase === "running" ? "You can close this window. Updating keeps going." : ""
                    font.family: up.body; font.pixelSize: 12; color: up.dim; wrapMode: Text.Wrap
                }
                Pill { label: "Restart to finish"; primary: true; visible: up.phase === "done" && up.staged; onClicked: up.run(["restart"]) }
                Pill { label: up.phase === "failed" ? "Try again" : "Update now"; primary: true; visible: up.phase === "idle" || up.phase === "failed"; onClicked: up.startUpdate() }
                Pill { label: up.phase === "running" ? "Hide" : "Close"; onClicked: Qt.quit() }
            }
        }
    }

    component Pill: Rectangle {
        id: pill
        property string label
        property bool primary: false
        signal clicked()
        radius: height / 2
        implicitHeight: 40; implicitWidth: pt.implicitWidth + 36
        // (inline components cannot see the window's colors, so they are written out here)
        color: primary ? (ma.pressed ? "#2f5c0a" : ma.containsMouse ? "#356a0c" : "#3f7a0e") : (ma.containsMouse ? "#e3f3c4" : "white")
        border.width: primary ? 0 : 1; border.color: "#e1eecb"
        Text { id: pt; anchors.centerIn: parent; text: pill.label; font.family: "Sora"; font.pixelSize: 13; font.bold: true; color: pill.primary ? "white" : "#1b2610" }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }
}
