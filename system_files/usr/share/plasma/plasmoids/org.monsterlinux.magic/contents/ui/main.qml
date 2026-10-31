// Monster Magic: opened as its own window with `plasmawindowed org.monsterlinux.magic`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Magic {
        Layout.preferredWidth: 1240
        Layout.preferredHeight: 800
        Layout.minimumWidth: 1000
        Layout.minimumHeight: 660
    }
}
