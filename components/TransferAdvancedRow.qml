import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

// One row of the Send page "Advanced options" panel, in the card style.
// Same API as AdvancedOptionsItem: title, tooltip, button1..button3.
Item {
    id: row

    property alias title: title.text
    property alias tooltip: title.tooltip
    property alias button1: button1
    property alias button2: button2
    property alias button3: button3

    Layout.fillWidth: true
    implicitHeight: Math.max(52, content.implicitHeight + 20)

    HoverHandler { id: rowHover }

    MoneroComponents.CardPanel {
        anchors.fill: parent
        cut: 8
        selected: rowHover.hovered
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 12

        MoneroComponents.Label {
            id: title
            Layout.topMargin: 0
            Layout.alignment: Qt.AlignVCenter
            fontSize: 14
            fontFamily: MoneroComponents.Style.fontMedium.name
            tooltipIconVisible: true
        }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 24
        }

        MoneroComponents.StandardButton {
            id: button1
            small: true
            primary: false
            visible: button1.text
        }

        MoneroComponents.StandardButton {
            id: button2
            small: true
            primary: false
            visible: button2.text
        }

        MoneroComponents.StandardButton {
            id: button3
            small: true
            primary: false
            visible: button3.text
        }
    }
}
