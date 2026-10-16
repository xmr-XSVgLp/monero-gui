import QtQuick
import QtQuick.Controls

import "../components" as MoneroComponents

// Thin neon scrollbar; drop-in replacement for ScrollBar.
ScrollBar {
    id: bar
    readonly property bool hot: bar.hovered || bar.pressed
    padding: 2
    implicitWidth: hot ? 8 : 6
    implicitHeight: hot ? 8 : 6

    contentItem: Rectangle {
        implicitWidth: bar.hot ? 4 : 2
        implicitHeight: bar.hot ? 4 : 2
        color: MoneroComponents.Style.orange
        opacity: bar.policy === ScrollBar.AlwaysOn || (bar.active && bar.size < 1.0) ? (bar.hot ? 1.0 : 0.7) : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }

        // glowing head/tail ticks
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: parent.width + 4; height: 1; color: parent.color; visible: bar.orientation === Qt.Vertical }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 1; width: parent.width + 4; height: 1; color: parent.color; visible: bar.orientation === Qt.Vertical }
    }

    background: Rectangle {
        implicitWidth: 1
        implicitHeight: 1
        color: MoneroComponents.Style.orange
        opacity: bar.contentItem.opacity > 0 ? 0.12 : 0.0
        width: bar.orientation === Qt.Vertical ? 1 : bar.width
        height: bar.orientation === Qt.Vertical ? bar.height : 1
        x: bar.orientation === Qt.Vertical ? bar.width / 2 : 0
        y: bar.orientation === Qt.Vertical ? 0 : bar.height / 2
    }
}
