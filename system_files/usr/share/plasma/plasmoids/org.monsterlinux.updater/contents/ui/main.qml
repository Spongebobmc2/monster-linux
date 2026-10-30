// Monster Updater: opened as its own window with `plasmawindowed org.monsterlinux.updater`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Updater {
        Layout.preferredWidth: 560
        Layout.preferredHeight: 600
        Layout.minimumWidth: 460
        Layout.minimumHeight: 520
    }
}
