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
    property bool used: false            // already received a transaction: do not hand it out again
    property string usedText: ""
    property bool primary: false         // primary address (starts with 4): shown blue, not copied from here
    property string primaryText: ""
    signal clicked()
    signal historyClicked()
    signal editClicked()
    signal copyClicked()

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    // same red as the red account cards (AccountRow)
    readonly property color usedColor: dark ? "#FF3C3C" : "#C41E1E"
    readonly property color primaryColor: dark ? "#3B9EFF" : "#1565C0"
    readonly property bool marked: used || primary
    readonly property color markColor: used ? usedColor : primaryColor
    readonly property color frameColor: marked ? markColor : accent
    readonly property bool hovered: rowMouse.containsMouse || historyButton.hovered
                                    || editButton.hovered || copyButton.hovered

    implicitHeight: 48

    MoneroComponents.CardPanel {
        anchors.fill: parent
        visible: !row.marked
        cut: 8
        hovered: row.hovered
        selected: row.selected
    }

    // used address (red) or primary address (blue): coloured frame, tint and glow, like a coloured account card
    MoneroComponents.NeonFrame {
        anchors.fill: parent
        visible: row.marked
        cut: 8
        accent: row.markColor
        lineOpacity: row.selected ? 0.95 : (row.hovered ? 0.8 : 0.6)
        fillColor: row.dark ? "#0B0F0C" : "#D8DDD9"
        fillOpacity: row.dark ? 0.92 : 0.9
        glow: row.selected ? 0.35 : 0.15
        ticks: row.selected
    }
    MoneroComponents.NeonFrame {
        anchors.fill: parent
        visible: row.marked
        cut: 8
        lineOpacity: 0
        fillColor: row.markColor
        fillOpacity: row.selected ? 0.14 : 0.08
        ticks: false
    }

    // active address: accent bar on the left
    Rectangle {
        visible: row.selected || row.marked
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 18
        radius: 1
        color: row.frameColor
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
                accent: row.selected || row.marked ? row.frameColor : row.border
                lineOpacity: row.selected || row.marked ? 0.95 : 0.3
                fillColor: row.frameColor
                fillOpacity: row.selected || row.marked ? 0.2 : 0.0
                ticks: false
            }

            MoneroComponents.TextPlain {
                anchors.centerIn: parent
                text: "#" + row.addressIndex
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: row.addressIndex > 99 ? 10 : 12
                color: row.selected || row.marked ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
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
            visible: row.marked
            text: row.used ? row.usedText : row.primaryText
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 11
            color: row.markColor
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
                enabled: !row.marked
                opacity: row.marked ? 0.3 : 1
                tooltip: row.copyTooltip
                onClicked: row.copyClicked()
            }
        }
    }
}
