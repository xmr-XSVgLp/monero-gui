import QtQuick

import "../components" as MoneroComponents

// Chamfered background for the Receive page payment request inputs.
Item {
    id: root
    property bool focused: false
    property bool warning: false         // red frame (e.g. an address that was already used)
    readonly property color warningColor: dark ? "#FF3C3C" : "#C41E1E"
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"

    implicitHeight: 36

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 6
        accent: root.warning ? root.warningColor : root.focused ? root.accent : root.border
        lineOpacity: root.warning || root.focused ? 0.9 : 0.28
        fillColor: root.warning ? root.warningColor : root.dark ? "#000000" : "#FFFFFF"
        fillOpacity: root.warning ? 0.12 : root.dark ? 0.35 : 0.7
        glow: root.warning ? 0.3 : 0.0
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }
}
