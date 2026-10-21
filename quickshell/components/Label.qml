import QtQuick
import "../"

// Default text style for the whole shell: one sans family, tabular digits.
Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textMd
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
}
