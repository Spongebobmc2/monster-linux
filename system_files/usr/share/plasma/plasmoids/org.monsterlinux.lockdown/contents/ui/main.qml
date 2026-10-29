// Monster Lockdown tray button
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    property bool locked: false
    property bool online: true
    property bool busy: false
    property string lastError: ""

    readonly property string helper: "$(command -v monster-lockdown)"
    readonly property string statusCmd:
        "sh -c 'monster-lockdown status 2>/dev/null || echo unlocked; " +
        "nmcli -t -f STATE general 2>/dev/null || echo unknown'"

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.icon: Qt.resolvedUrl(locked ? "../icons/button-locked.svg" : "../icons/button.svg")
    toolTipMainText: locked ? "Monster Lockdown: LOCKED" : "Monster Lockdown"
    toolTipSubText: locked
        ? "Network, Bluetooth and file sharing are cut off. Click to unlock."
        : (online ? "Everything is connected. Click for the red button."
                  : "No internet right now. Click for the red button.")

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (source === root.statusCmd) {
                const lines = out.split("\n")
                root.locked = lines[0] === "locked"
                root.online = (lines[1] || "").indexOf("connected") === 0
            } else {
                root.busy = false
                root.lastError = data["exit code"] === 0 ? "" :
                    "That didn't work (code " + data["exit code"] + "). " + (data["stderr"] || "").trim()
                exec.connectSource(root.statusCmd)
            }
            exec.disconnectSource(source)
        }
    }

    function refresh() { exec.connectSource(statusCmd) }
    function setLock(on) {
        busy = true
        lastError = ""
        exec.connectSource("sh -c 'pkexec \"" + helper + "\" " + (on ? "on" : "off") + "'")
    }

    Timer {
        interval: 4000
        running: true
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
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 3
            text: "Monster Lockdown"
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Rectangle {
                width: Kirigami.Units.gridUnit * 0.7
                height: width
                radius: width / 2
                color: root.locked ? "#e5352a" : (root.online ? "#a8e03a" : "#e8b03d")
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.locked ? "LOCKED DOWN. Nothing can get in or out."
                    : (root.online ? "Open. You're connected." : "Open, but there's no internet right now.")
            }
        }

        // The big red button
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            Layout.preferredHeight: Kirigami.Units.gridUnit * 8
            Kirigami.Icon {
                id: bigButton
                anchors.fill: parent
                source: Plasmoid.icon
                scale: pressArea.pressed ? 0.92 : (pressArea.containsMouse ? 1.04 : 1)
                opacity: root.busy ? 0.5 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: pressArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setLock(!root.locked)
            }
            PlasmaComponents3.BusyIndicator {
                anchors.centerIn: parent
                running: root.busy
                visible: root.busy
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.bold: true
            text: root.busy ? "Working..." : (root.locked ? "Press to unlock and reconnect" : "Press to lock everything down")
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            font: Kirigami.Theme.smallFont
            text: root.locked
                ? "Unlocking turns the firewall back to normal and reconnects Wi-Fi/Ethernet, Bluetooth and sharing if they were on before."
                : "Locking blocks all network traffic, turns off Wi-Fi/Ethernet (your VPN disconnects too), Bluetooth, file sharing and remote login."
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: root.lastError !== ""
            color: "#e5352a"
            text: root.lastError
        }
    }
}
