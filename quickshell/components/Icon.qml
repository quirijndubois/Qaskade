import QtQuick
import "../"

// A monochrome glyph from Theme.icons, e.g. Icon { name: "bluetooth" }.
Text {
    property string name: ""
    property int size: 16

    text: Theme.icons[name] || ""
    color: Theme.text
    font.family: Theme.iconFamily
    font.pixelSize: size
    width: size
    height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
