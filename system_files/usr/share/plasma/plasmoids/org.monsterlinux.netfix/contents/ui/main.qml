// Monster Network Fix: green check = online, red X = offline. Click, then press Fix.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    property string net: "checking"      // online | no-dns | offline | checking
    property bool busy: false
    property var steps: []               // [{kind: "OK"|"FIX"|"FAIL", text: "..."}]
    property bool lastFixWorked: false

    readonly property bool online: net === "online"
    readonly property string checkCmd: "sh -c 'monster-netfix check 2>/dev/null || echo offline'"
    readonly property string fixCmd: "sh -c 'pkexec \"$(command -v monster-netfix)\"; " +
        // The VPN kill switch can block the internet while the VPN is down: reconnect it as you
        "if command -v nordvpn >/dev/null && nordvpn status 2>/dev/null | grep -qi disconnected; then " +
        "nordvpn connect >/dev/null 2>&1 && echo \"FIX Reconnected NordVPN\"; fi'"

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.icon: Qt.resolvedUrl(online ? "../icons/net-ok.svg" : "../icons/net-bad.svg")
    toolTipMainText: online ? "Internet: working" : (net === "checking" ? "Checking internet..." : "Internet: not working")
    toolTipSubText: online ? "Click to open Network Fix." : "Click, then press Fix to repair it automatically."

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (source === root.checkCmd) {
                root.net = out.split("\n")[0] || "offline"
            } else {
                const list = []
                out.split("\n").forEach(line => {
                    const m = line.match(/^(OK|FIX|FAIL) (.*)$/)
                    if (m) list.push({ kind: m[1], text: m[2] })
                })
                if (list.length === 0)
                    list.push({ kind: "FAIL", text: "The fix didn't run (" + ((data["stderr"] || "").trim() || "no permission?") + ")" })
                root.steps = list
                root.lastFixWorked = list.some(s => s.text === "You're back online" || s.text === "Internet is already working")
                root.busy = false
                exec.connectSource(root.checkCmd)
            }
            exec.disconnectSource(source)
        }
    }

    function refresh() { exec.connectSource(checkCmd) }
    function fix() {
        busy = true
        steps = []
        exec.connectSource(fixCmd)
    }

    Timer {
        interval: 8000
        running: !root.busy
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: parent.containsMouse
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 19
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { level: 3; text: "Monster Network Fix"; Layout.fillWidth: true }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Rectangle {
                width: Kirigami.Units.gridUnit * 0.7; height: width; radius: width / 2
                color: root.online ? "#a8e03a" : (root.net === "no-dns" ? "#e8b03d" : "#e5352a")
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.online ? "Internet is working."
                    : root.net === "no-dns" ? "Connected, but websites can't be found."
                    : root.net === "checking" ? "Checking..."
                    : "No internet."
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 7
            Layout.preferredHeight: Kirigami.Units.gridUnit * 7
            Kirigami.Icon {
                anchors.fill: parent
                source: Plasmoid.icon
                scale: pressArea.pressed ? 0.92 : (pressArea.containsMouse ? 1.04 : 1)
                opacity: root.busy ? 0.4 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: pressArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fix()
            }
            PlasmaComponents3.BusyIndicator { anchors.centerIn: parent; running: root.busy; visible: root.busy }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.bold: true
            text: root.busy ? "Fixing... this can take up to a minute"
                : (root.online ? "Press to run a network check-up" : "Press to fix my internet")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: root.steps.length > 0
            Repeater {
                model: root.steps
                delegate: RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Label {
                        text: modelData.kind === "FAIL" ? "✗" : "✓"
                        color: modelData.kind === "FAIL" ? "#e5352a" : (modelData.kind === "FIX" ? "#e8b03d" : "#a8e03a")
                        font.bold: true
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: modelData.text
                    }
                }
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            font: Kirigami.Theme.smallFont
            visible: root.steps.length === 0
            text: "Checks lockdown, the firewall, airplane mode, Wi-Fi, DNS and the network service, and reconnects everything that was connected before. It stops as soon as you're back online."
        }
    }
}
