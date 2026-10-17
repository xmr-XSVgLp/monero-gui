import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

// One subaddress in the Receive page list, styled like AccountRow on a single line:
// index badge, label, truncated address, history / edit / copy buttons.
Item {
    id: row
    property int addressIndex: 0
    property string label: ""
    property string address: ""          // already truncated for display
    property bool selected: false
    property bool editVisible: addressIndex !== 0
    property string historyTooltip: ""
    property string editTooltip: ""
    property string copyTooltip: ""
    signal clicked()
    signal historyClicked()
    signal editClicked()
    signal copyClicked()

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    readonly property bool hovered: rowMouse.containsMouse || historyButton.hovered
                                    || editButton.hovered || copyButton.hovered

    implicitHeight: 48

    MoneroComponents.CardPanel {
        anchors.fill: parent
        cut: 8
        hovered: row.hovered
        selected: row.selected
    }

    // active address: accent bar on the left
    Rectangle {
        visible: row.selected
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 18
        radius: 1
        color: row.accent
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 12

        // index badge
        Item {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 26

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 5
                accent: row.selected ? row.accent : row.border
                lineOpacity: row.selected ? 0.95 : 0.3
                fillColor: row.accent
                fillOpacity: row.selected ? 0.2 : 0.0
                ticks: false
            }

            MoneroComponents.TextPlain {
                anchors.centerIn: parent
                text: "#" + row.addressIndex
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: row.addressIndex > 99 ? 10 : 12
                color: row.selected ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            Layout.minimumWidth: 40
            text: row.label
            elide: Text.ElideRight
            font.family: MoneroComponents.Style.fontMedium.name
            font.pixelSize: 15
            color: row.selected || row.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
            themeTransition: false
        }

        MoneroComponents.TextPlain {
            text: row.address
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }

        RowLayout {
            Layout.leftMargin: 4
            spacing: 6

            MoneroComponents.ReceiveIconButton {
                id: historyButton
                icon: "search"
                tooltip: row.historyTooltip
                onClicked: row.historyClicked()
            }

            MoneroComponents.ReceiveIconButton {
                id: editButton
                icon: "edit"
                // keeps its slot on the primary address so the columns line up
                opacity: row.editVisible ? 1 : 0
                enabled: row.editVisible
                tooltip: row.editTooltip
                onClicked: row.editClicked()
            }

            MoneroComponents.ReceiveIconButton {
                id: copyButton
                icon: "copy"
                tooltip: row.copyTooltip
                onClicked: row.copyClicked()
            }
        }
    }
}
