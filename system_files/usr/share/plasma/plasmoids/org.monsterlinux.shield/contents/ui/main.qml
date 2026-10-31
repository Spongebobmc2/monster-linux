// Monster Shield: opened as its own window with `plasmawindowed org.monsterlinux.shield`.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Shield {
        Layout.preferredWidth: 980
        Layout.preferredHeight: 700
        Layout.minimumWidth: 820
        Layout.minimumHeight: 620
    }
}
