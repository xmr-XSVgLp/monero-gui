import QtQuick

import "../components" as MoneroComponents

// Chamfered background for the Receive page payment request inputs.
Item {
    id: root
    property bool focused: false
    property bool warning: false         // red frame (e.g. an address that was already used)
    readonly property color warningColor: dark ? "#FF3C3C" : "#C41E1E"
    property bool info: false            // blue frame (the primary address)
    readonly property color infoColor: dark ? "#3B9EFF" : "#1565C0"
    readonly property bool marked: warning || info
    readonly property color markColor: warning ? warningColor : infoColor
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"

    implicitHeight: 36

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 6
        accent: root.marked ? root.markColor : root.focused ? root.accent : root.border
        lineOpacity: root.marked || root.focused ? 0.9 : 0.28
        fillColor: root.marked ? root.markColor : root.dark ? "#000000" : "#FFFFFF"
        fillOpacity: root.marked ? 0.12 : root.dark ? 0.35 : 0.7
        glow: root.marked ? 0.3 : 0.0
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }
}
