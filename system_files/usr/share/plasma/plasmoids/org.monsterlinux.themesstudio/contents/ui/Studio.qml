// Monster Themes Studio: the main window.
// Left: section menu. Middle: the section's controls. Right: the lit stage with a live preview and Apply.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasma5support as P5Support
import "../code/themes.js" as T

Rectangle {
    id: studio
    color: room

    // ---------- studio look ----------
    readonly property color room: "#0d0f0e"
    readonly property color rack: "#151816"
    readonly property color rack2: "#1b1f1c"
    readonly property color line: "#262b28"
    readonly property color ink: "#e4e8e1"
    readonly property color dim: "#8b938d"
    readonly property color led: "#a8e03a"
    readonly property color lamp: "#ff4a3a"
    readonly property string uiFont: "Noto Sans"

    // ---------- the theme being designed ----------
    property var st: buildState(findTheme("Monster Gloop"), {})
    property string themeName: "Monster Gloop"
    property var undoStack: []
    property string home: ""
    property var results: []          // [{kind, text}] from the last Apply
    property bool applying: false
    property var installedFonts: Qt.fontFamilies()
    readonly property string pkg: decodeURIComponent(Qt.resolvedUrl("..").toString().replace("file://", "")).replace(/\/$/, "")
    readonly property string helper: pkg + "/code/apply.sh"

    readonly property var slots: [
        ["bg", "Window", "Main window background"], ["bg2", "Side panels", "Sidebars and lists"],
        ["view", "Content", "Where text and files sit"], ["panel", "Taskbar & title bars", ""],
        ["button", "Buttons", ""], ["text", "Text", ""], ["muted", "Faded text", "Hints and less important text"],
        ["link", "Links", ""], ["accent", "Accent", "Highlights, selection, the main button"],
        ["ok", "Good", "Success and all fine"], ["warn", "Warning", ""], ["err", "Problem", "Errors and close buttons"]
    ]
    readonly property var sections: [
        ["gallery", "Theme Gallery", "Ready-made looks to try"],
        ["colors", "Colors", "Every color on screen"],
        ["letters", "Letters", "Fonts, size and sharpness"],
        ["wallpaper", "Wallpaper", "Desktop and lock screen picture"],
        ["glass", "Glass & Shape", "See-through windows, taskbar, pointer"],
        ["icons", "Icons", "Icon shapes and your own icons"],
        ["motion", "Motion", "Animation speed and effects"],
        ["more", "More", "Classic KDE pages and reset"]
    ]
    property int page: 0

    // ---------- your own saved themes (~/.local/share/monster-themes) ----------
    property var myThemes: []
    function slug(n) { return ("" + n).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40) || "my-theme" }
    function refreshMine() {
        run(["mythemes", "list"], out => {
            const L = []
            out.split("\n").forEach(l => { try { const t = JSON.parse(l); if (t && t.n && t.state) L.push(t) } catch (e) {} })
            L.sort((a, b) => (b.at || 0) - (a.at || 0))
            myThemes = L
        })
    }
    function findMine(name) { for (const t of myThemes) if (t.n.toLowerCase() === ("" + name).toLowerCase()) return t; return null }
    function saveTheme(name, cb) {
        name = ("" + name).trim(); if (!name) return
        const t = { n: name, id: slug(name), at: Date.now(), state: JSON.parse(JSON.stringify(st)) }
        run(["mythemes", "save", t.id, JSON.stringify(t)], () => { themeName = name; refreshMine(); if (cb) cb() })
    }
    function renameTheme(t, name, cb) {
        name = ("" + name).trim(); if (!name || name === t.n) { if (cb) cb(); return }
        const n = { n: name, id: slug(name), at: t.at || Date.now(), state: t.state }
        run(["mythemes", "save", n.id, JSON.stringify(n)], () => {
            const done = () => { if (themeName === t.n) themeName = name; refreshMine(); if (cb) cb() }
            if (n.id !== t.id) run(["mythemes", "delete", t.id], done); else done()
        })
    }
    function deleteTheme(t) { run(["mythemes", "delete", t.id], () => refreshMine()) }
    function loadMine(t) { snapshot(); st = JSON.parse(JSON.stringify(t.state)); themeName = t.n }
    function thumbOf(t) {
        const w = t.state && (t.state.wallThumb || t.state.wallPath)
        return w ? (w.startsWith("file:") ? w : "file://" + w) : pkg + "/thumbs/monster-gloop.png"
    }

    // ---------- small color helpers ----------
    function hx(c) { return ("" + c).slice(0, 7) }
    function parse(h) { const n = parseInt(hx(h).slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255] }
    function rgb(h) { return parse(h).join(",") }
    function mix(a, b, t) { const A = parse(a), B = parse(b); return "#" + [0, 1, 2].map(i => Math.round(A[i] * (1 - t) + B[i] * t).toString(16).padStart(2, "0")).join("") }
    function lum(h) { const f = v => { v /= 255; return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4) }; const c = parse(h); return .2126 * f(c[0]) + .7152 * f(c[1]) + .0722 * f(c[2]) }
    function onAccent(h) { return lum(h) > .45 ? "#11180a" : "#ffffff" }
    function telaColor(h) {
        const c = parse(h).map(v => v / 255), mx = Math.max(...c), mn = Math.min(...c), d = mx - mn
        if (d < .12) return mx > .6 ? "grey" : "black"
        let hue = mx === c[0] ? ((c[1] - c[2]) / d) % 6 : mx === c[1] ? (c[2] - c[0]) / d + 2 : (c[0] - c[1]) / d + 4
        hue = (hue * 60 + 360) % 360
        if (hue < 15 || hue >= 340) return "red"; if (hue < 40) return "orange"; if (hue < 65) return "yellow"
        if (hue < 160) return "green"; if (hue < 250) return "blue"; if (hue < 300) return "purple"; return "pink"
    }
    function q(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'" }
    function hasFont(f) { return installedFonts.indexOf(f) >= 0 }
    function fontOr(f, fallback) { return hasFont(f) ? f : fallback }

    // ---------- theme state ----------
    function snapshot() { const u = undoStack.slice(); u.push(JSON.stringify({st: st, n: themeName})); if (u.length > 60) u.shift(); undoStack = u }
    function undo() { if (!undoStack.length) return; const u = undoStack.slice(); const s = JSON.parse(u.pop()); undoStack = u; st = s.st; themeName = s.n }
    function set(key, value) { snapshot(); const s = JSON.parse(JSON.stringify(st)); s[key] = value; st = s; themeName = "My theme" }
    function setColor(key, value) { snapshot(); const s = JSON.parse(JSON.stringify(st)); s.c[key] = hx(value).toLowerCase(); st = s; themeName = "My theme" }
    // same as setColor but without a new Undo step (used while dragging in the color spectrum)
    function setColorLive(key, value) { const s = JSON.parse(JSON.stringify(st)); s.c[key] = hx(value).toLowerCase(); st = s; themeName = "My theme" }
    function buildState(item, prev) {
        const t = JSON.parse(JSON.stringify(item.st))
        prev = prev || {}
        return {
            c: t.c, font: t.font, mono: t.mono, size: t.size, bold: t.bold,
            op: t.op, opIn: t.opIn, panel: t.opBar >= 95 ? "opaque" : "translucent",
            icons: t.icons || "square", iconTheme: "", cursor: prev.cursor || "",
            wallKind: "image", wallPath: pkg + "/wallpapers/" + item.wallpaper, wallThumb: pkg + "/thumbs/" + item.thumb,
            smooth: prev.smooth ?? true, hint: prev.hint || "slight", scale: prev.scale || 100,
            anim: prev.anim ?? 1, wobbly: prev.wobbly ?? false, lamp: prev.lamp ?? false, blur: prev.blur ?? true
        }
    }
    function loadTheme(item) { snapshot(); st = buildState(item, st); themeName = item.n }
    function findTheme(name) { for (const g of T.GROUPS) for (const it of g.items) if (it.n === name) return it; return null }

    // ---------- the .colors file KDE reads ----------
    function colorsFile() {
        const c = st.c, sel = onAccent(c.accent)
        const common = { DecorationFocus: c.accent, DecorationHover: c.muted, ForegroundActive: c.accent, ForegroundInactive: c.muted,
            ForegroundLink: c.link, ForegroundVisited: mix(c.link, c.muted, .5), ForegroundNegative: c.err, ForegroundNeutral: c.warn,
            ForegroundPositive: c.ok, ForegroundNormal: c.text }
        const secs = { Window: [c.bg, c.bg2], View: [c.view, c.bg2], Button: [c.button, c.bg2], Header: [c.panel, c.bg],
            Tooltip: [c.bg2, c.bg], Complementary: [c.panel, c.bg2], Selection: [c.accent, mix(c.accent, "#000000", .15)] }
        const out = []
        for (const s in secs) {
            const d = Object.assign({}, common, { BackgroundNormal: secs[s][0], BackgroundAlternate: secs[s][1] })
            if (s === "Selection") Object.assign(d, { ForegroundNormal: sel, ForegroundInactive: sel, ForegroundActive: sel, ForegroundLink: sel })
            out.push("[Colors:" + s + "]\n" + Object.keys(d).sort().map(k => k + "=" + rgb(d[k])).join("\n"))
        }
        out.push("[General]\nColorScheme=MonsterCustom\nName=Monster Custom (" + themeName + ")\nshadeSortColumn=true")
        out.push("[WM]\nactiveBackground=" + rgb(c.panel) + "\nactiveForeground=" + rgb(c.text) + "\ninactiveBackground=" + rgb(c.bg) + "\ninactiveForeground=" + rgb(c.muted))
        return out.join("\n\n")
    }

    // ---------- running the helper ----------
    property int runId: 0
    property var callbacks: ({})
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const cb = studio.callbacks[source]
            exec.disconnectSource(source)
            if (cb) { const c = Object.assign({}, studio.callbacks); delete c[source]; studio.callbacks = c; cb((data["stdout"] || "").trim(), data["exit code"]) }
        }
    }
    function run(args, cb) {
        runId++
        const cmd = "bash " + q(helper) + " " + args.map(q).join(" ") + " # " + runId
        const c = Object.assign({}, callbacks); c[cmd] = cb || function () {}; callbacks = c
        exec.connectSource(cmd)
    }
    function sh(cmd, cb) {
        runId++
        const full = cmd + " # " + runId
        const c = Object.assign({}, callbacks); c[full] = cb || function () {}; callbacks = c
        exec.connectSource(full)
    }
    function parseResults(out) {
        return out.split("\n").map(l => { const m = l.match(/^(OK|FAIL) (.*)$/); return m ? { kind: m[1], text: m[2] } : null }).filter(x => x)
    }

    function applyAll() {
        applying = true
        results = []
        const font = fontOr(st.font, "Noto Sans"), mono = fontOr(st.mono, hasFont("Hack") ? "Hack" : "Noto Sans Mono")
        const steps = [
            ["colors", colorsFile(), st.c.accent],
            ["fonts", font, st.size, st.bold ? 1 : 0, mono, st.smooth ? 1 : 0, st.hint, st.scale],
            ["glass", st.op, st.opIn, st.panel],
            [st.iconTheme ? "iconset" : "iconset", st.iconTheme || st.icons, telaColor(st.c.accent), lum(st.c.bg) < .4 ? 1 : 0],
            ["wallpaper", st.wallKind, st.wallPath || ""],
            ["motion", st.anim, st.wobbly ? 1 : 0, st.lamp ? 1 : 0, st.blur ? 1 : 0]
        ]
        if (st.cursor) steps.push(["cursor", st.cursor])
        let all = []
        const notes = []
        if (font !== st.font) notes.push({ kind: "OK", text: st.font + " isn't on this PC, so Noto Sans is used instead" })
        const next = i => {
            if (i >= steps.length) { results = notes.concat(all); applying = false; return }
            run(steps[i], out => { all = all.concat(parseResults(out)); results = notes.concat(all); next(i + 1) })
        }
        next(0)
    }

    Component.onCompleted: {
        sh("printf %s \"$HOME\"; mkdir -p \"$HOME/.local/share/icons/monster-custom\"", out => studio.home = out)
        refreshMine()
    }

    // ---------- Save theme box ----------
    function openSave() {
        nameField.text = (themeName === "My theme" || T.GROUPS.some(g => g.items.some(i => i.n === themeName))) ? "" : themeName
        saveBox.open(); nameField.forceActiveFocus(); nameField.selectAll()
    }
    QQC2.Popup {
        id: saveBox
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: 420; modal: true; focus: true; padding: 20
        background: Rectangle { radius: 12; color: studio.rack; border.color: studio.led }
        QQC2.Overlay.modal: Rectangle { color: "#a0000000" }
        contentItem: ColumnLayout {
            spacing: 12
            Text { text: "Save this theme"; color: studio.ink; font.family: studio.uiFont; font.pixelSize: 17; font.bold: true }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: studio.dim; font.family: studio.uiFont; font.pixelSize: 12
                text: "Give it a name. It goes into My Themes at the top of the Theme Gallery, so you can switch back to it any time." }
            QQC2.TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "For example: Night Gaming"
                maximumLength: 40
                color: studio.ink; font.family: studio.uiFont; font.pixelSize: 14
                background: Rectangle { radius: 8; color: studio.room; border.color: nameField.activeFocus ? studio.led : studio.line; implicitHeight: 40 }
                onAccepted: if (text.trim()) { studio.saveTheme(text); saveBox.close() }
            }
            Text {
                visible: nameField.text.trim() !== "" && studio.findMine(nameField.text) !== null
                text: "You already have a theme with this name. Saving replaces it."
                color: "#e8b03d"; font.family: studio.uiFont; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                StudioButton { studio: studio; text: "Cancel"; onClicked: saveBox.close() }
                StudioButton { studio: studio; text: studio.findMine(nameField.text) ? "Replace" : "Save"; primary: true; enabled: nameField.text.trim() !== ""
                    onClicked: { studio.saveTheme(nameField.text); saveBox.close() } }
            }
        }
    }

    // =================== layout ===================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ---- top bar ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 58
            radius: 10
            color: studio.rack
            border.color: studio.line
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 14
                Image { source: studio.pkg + "/code/gloop.svg"; sourceSize.width: 34; sourceSize.height: 34; Layout.preferredWidth: 34; Layout.preferredHeight: 34 }
                ColumnLayout {
                    spacing: 0
                    Text { text: "Monster Themes Studio"; color: studio.ink; font.family: studio.uiFont; font.pixelSize: 18; font.bold: true }
                    Text { text: "APPEARANCE & STYLE"; color: studio.dim; font.family: "monospace"; font.pixelSize: 10; font.letterSpacing: 2 }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: lampRow.implicitWidth + 18; implicitHeight: 26; radius: 6
                    color: "#1d0e0c"; border.color: "#4a1d18"
                    Row {
                        id: lampRow; anchors.centerIn: parent; spacing: 7
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: studio.lamp; anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: .35; duration: 1200 } NumberAnimation { to: 1; duration: 1200 } }
                        }
                        Text { text: "LIVE PREVIEW"; color: studio.lamp; font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 2 }
                    }
                }
                StudioButton { studio: studio; text: "Undo"; enabled: studio.undoStack.length > 0; onClicked: studio.undo() }
                StudioButton { studio: studio; text: "Save theme"; onClicked: studio.openSave() }
                StudioButton { studio: studio; text: studio.applying ? "Applying..." : "Apply to my PC"; primary: true; enabled: !studio.applying; onClicked: studio.applyAll() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ---- section menu ----
            Rectangle {
                Layout.preferredWidth: 210
                Layout.fillHeight: true
                radius: 10; color: studio.rack; border.color: studio.line
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 4
                    Repeater {
                        model: studio.sections
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 52; radius: 8
                            color: studio.page === index ? studio.rack2 : (hov.hovered ? "#181c19" : "transparent")
                            border.color: studio.page === index ? studio.led : "transparent"
                            HoverHandler { id: hov }
                            TapHandler { onTapped: studio.page = index }
                            ColumnLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 1
                                Item { Layout.fillHeight: true }
                                Text { text: modelData[1]; color: studio.page === index ? studio.led : studio.ink; font.family: studio.uiFont; font.pixelSize: 14; font.bold: true }
                                Text { text: modelData[2]; color: studio.dim; font.family: studio.uiFont; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: "Changes show on the stage right away. Press Apply to my PC to use them."
                        color: studio.dim; font.family: studio.uiFont; font.pixelSize: 11
                    }
                }
            }

            // ---- section content ----
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10; color: studio.rack; border.color: studio.line
                clip: true
                StackLayout {
                    anchors.fill: parent; anchors.margins: 16
                    currentIndex: studio.page
                    GalleryPage { studio: studio }
                    ColorsPage { studio: studio }
                    LettersPage { studio: studio }
                    WallpaperPage { studio: studio }
                    GlassPage { studio: studio }
                    IconsPage { studio: studio }
                    MotionPage { studio: studio }
                    MorePage { studio: studio }
                }
            }

            // ---- stage ----
            Rectangle {
                Layout.preferredWidth: 430
                Layout.fillHeight: true
                radius: 10; border.color: studio.line
                gradient: Gradient {
                    GradientStop { position: 0; color: "#232825" }
                    GradientStop { position: .55; color: "#121513" }
                    GradientStop { position: 1; color: "#0a0c0b" }
                }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Repeater { model: 3; delegate: Rectangle { width: 22; height: 6; radius: 2; color: "#3a3f3b" } }
                        Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: studio.themeName.toUpperCase(); color: studio.dim; font.family: "monospace"; font.pixelSize: 11; font.letterSpacing: 2; elide: Text.ElideRight }
                        Repeater { model: 3; delegate: Rectangle { width: 22; height: 6; radius: 2; color: "#3a3f3b" } }
                    }
                    Preview { studio: studio; Layout.fillWidth: true; Layout.preferredHeight: width * 10 / 16 }

                    // Apply results
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8; color: "#0f1210"; border.color: studio.line
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 6
                            Text {
                                text: studio.applying ? "Applying your theme..." : (studio.results.length ? "Done. Here's what changed:" : "Ready when you are")
                                color: studio.ink; font.family: studio.uiFont; font.pixelSize: 14; font.bold: true
                            }
                            Text {
                                visible: !studio.results.length && !studio.applying
                                Layout.fillWidth: true; wrapMode: Text.WordWrap
                                text: "Try themes from the gallery or change anything you like. When it looks right, press Apply to my PC. Some changes fully show after you log out and back in."
                                color: studio.dim; font.family: studio.uiFont; font.pixelSize: 12
                            }
                            QQC2.BusyIndicator { visible: studio.applying; running: studio.applying; Layout.alignment: Qt.AlignHCenter }
                            ListView {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true; spacing: 4
                                model: studio.results
                                delegate: RowLayout {
                                    required property var modelData
                                    width: ListView.view.width
                                    Text { text: modelData.kind === "OK" ? "✓" : "✗"; color: modelData.kind === "OK" ? studio.led : studio.lamp; font.bold: true; font.pixelSize: 13 }
                                    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: modelData.text; color: studio.ink; font.family: studio.uiFont; font.pixelSize: 12 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
