// Monster Magic: opened as its own window with `plasmawindowed org.monsterlinux.magic`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Magic {
        Layout.preferredWidth: 1060
        Layout.preferredHeight: 700
        Layout.minimumWidth: 920
        Layout.minimumHeight: 620
    }
}
