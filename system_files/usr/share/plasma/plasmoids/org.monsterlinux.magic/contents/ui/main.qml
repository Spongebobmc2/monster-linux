// Monster Magic: opened as its own window with `plasmawindowed org.monsterlinux.magic`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Magic {
        Layout.preferredWidth: 1180
        Layout.preferredHeight: 760
        Layout.minimumWidth: 900
        Layout.minimumHeight: 600
    }
}
