import QtQuick

import "../components" as MoneroComponents

// Background panel in the card style (Account page / wizard cards). Put content on top of it.
// hovered: brighter border, green tint and glow. selected: like hovered, without the glow.
Item {
    id: root
    property bool hovered: false
    property bool selected: false
    property int cut: 12
    property real idleLine: 0.28
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    readonly property bool lit: hovered || selected

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: root.cut
        accent: root.border
        lineOpacity: root.lit ? 0.85 : root.idleLine
        fillColor: root.dark ? "#0C130E" : "#DADFDB"
        fillOpacity: root.dark ? 0.92 : 0.9
        glow: root.hovered ? 0.3 : 0.0
        ticks: root.lit
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: root.cut
        lineOpacity: 0
        fillColor: root.accent
        fillOpacity: root.lit ? 0.10 : 0.0
        ticks: false
        Behavior on fillOpacity { NumberAnimation { duration: 150 } }
    }
}
