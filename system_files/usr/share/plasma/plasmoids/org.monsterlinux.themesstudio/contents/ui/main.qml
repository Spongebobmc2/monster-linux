// Monster Themes Studio: opened as its own window with `plasmawindowed org.monsterlinux.themesstudio`
// (the System Settings entry and the app menu entry both do this).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    fullRepresentation: Studio {
        Layout.preferredWidth: 1260
        Layout.preferredHeight: 800
        Layout.minimumWidth: 980
        Layout.minimumHeight: 640
    }
}
