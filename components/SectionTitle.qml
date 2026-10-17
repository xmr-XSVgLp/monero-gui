import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

// Section heading in the card style: small accent square + mono caps label (+ optional right text).
RowLayout {
    id: root
    property string text: ""
    property string rightText: ""
    readonly property color accent: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
    spacing: 10

    Rectangle {
        Layout.preferredWidth: 6
        Layout.preferredHeight: 6
        color: root.accent
    }

    MoneroComponents.TextPlain {
        text: root.text.toUpperCase()
        font.family: MoneroComponents.Style.fontMonoMedium.name
        font.pixelSize: 13
        font.letterSpacing: 2
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
    }

    Item { Layout.fillWidth: true }

    MoneroComponents.TextPlain {
        visible: root.rightText !== ""
        text: root.rightText
        font.family: MoneroComponents.Style.fontMonoRegular.name
        font.pixelSize: 12
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
    }
}
