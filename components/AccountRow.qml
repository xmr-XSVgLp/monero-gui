import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents
import "../js/Utils.js" as Utils

// One account in the Account page list, styled like the balance card, on a single line:
// index badge, label, address, balance, fiat value, edit button.
Item {
    id: row
    property int accountIndex: 0
    property string badge: ""            // shown instead of "#index" (Wallet+ mined addresses account)
    property string customColor: ""      // instead of the colour of the index
    property string label: ""
    property string address: ""          // already truncated for display
    property string balance: ""          // "<amount> XMR"
    property string fiat: ""             // "≈ 12.34 EUR", empty to hide
    property bool selected: false
    property string editTooltip: ""
    signal clicked()
    signal editClicked()

    readonly property bool dark: MoneroComponents.Style.blackTheme
    // colour of this account's card (card-matrix-*<index % 8>.png): matrix, circuit, synth, hive,
    // glitch, radar, stream, topo
    readonly property var cardColorsDark:  ["#00FF42", "#00E8FF", "#FF2CD9", "#FFB200", "#9F4EFF", "#FF3C3C", "#307DFF", "#FFDA00"]
    readonly property var cardColorsLight: ["#00A82D", "#008C9E", "#B0108F", "#B87800", "#6A22C8", "#C41E1E", "#1F55C0", "#9E8600"]
    readonly property color cardColor: customColor !== "" ? customColor : (dark ? cardColorsDark : cardColorsLight)[accountIndex % 8]
    // only the active account shows its colour; the others keep the neutral soft white
    readonly property color border: selected ? cardColor : (dark ? "#E8ECE9" : "#2B3A30")
    readonly property color accent: border
    readonly property bool hovered: rowMouse.containsMouse || editMouse.containsMouse

    implicitHeight: 44

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 8
        accent: row.border
        lineOpacity: row.selected ? 0.95 : (row.hovered ? 0.45 : 0.18)
        fillColor: row.dark ? "#0B0F0C" : "#D8DDD9"
        fillOpacity: row.dark ? 0.92 : 0.9
        glow: row.selected ? 0.35 : 0.0
        ticks: row.selected
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }

    // tint of the account colour, stronger when selected
    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 8
        lineOpacity: 0
        fillColor: row.border
        fillOpacity: row.selected ? 0.10 : 0.0
        ticks: false
    }

    // selected: bar on the left, same colour as the row border
    Rectangle {
        visible: row.selected
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 16
        radius: 1
        color: row.border
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
        anchors.rightMargin: 8
        spacing: 12

        // index badge
        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 26

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 5
                accent: row.border
                lineOpacity: row.selected ? 0.95 : 0.35
                fillColor: row.border
                fillOpacity: row.selected ? 0.18 : 0.03
                ticks: false
            }

            MoneroComponents.TextPlain {
                anchors.centerIn: parent
                text: row.badge !== "" ? row.badge : "#" + row.accountIndex
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: row.badge !== "" ? 14 : (row.accountIndex > 99 ? 10 : 12)
                color: row.selected ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
        }

        // label
        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            Layout.minimumWidth: 50
            text: row.label
            elide: Text.ElideRight
            font.family: MoneroComponents.Style.fontMedium.name
            font.pixelSize: 15
            color: row.selected || row.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
            themeTransition: false
        }

        // address
        MoneroComponents.TextPlain {
            text: row.address
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }

        // balance + fiat
        MoneroComponents.TextPlain {
            Layout.leftMargin: 8
            Layout.minimumWidth: 230   // keeps balances aligned in a column
            horizontalAlignment: Text.AlignRight
            text: Utils.prettyAmountRich(row.balance, Math.round(font.pixelSize * 0.65))
            textFormat: Text.RichText
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 15
            color: MoneroComponents.Style.defaultFontColor
            themeTransition: false
        }

        MoneroComponents.TextPlain {
            visible: row.fiat !== ""
            Layout.minimumWidth: 110
            horizontalAlignment: Text.AlignRight
            text: Utils.prettyAmountRich(row.fiat, Math.round(font.pixelSize * 0.65))
            textFormat: Text.RichText
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }

        // edit label button: chamfered square with a drawn pencil
        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.leftMargin: 2

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 6
                accent: row.border
                lineOpacity: editMouse.containsMouse ? 0.95 : (row.selected ? 0.5 : 0.3)
                fillColor: row.accent
                fillOpacity: editMouse.containsMouse ? 0.25 : 0.0
                glow: editMouse.containsMouse ? 0.5 : 0.0
                ticks: false
            }

            Canvas {
                id: pencil
                anchors.centerIn: parent
                width: 18
                height: 18
                scale: 0.85
                property color c: editMouse.containsMouse ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                onCChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = c;
                    ctx.lineWidth = 1.6;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    // pencil body
                    ctx.beginPath();
                    ctx.moveTo(3, 15); ctx.lineTo(3.8, 11.6); ctx.lineTo(12.6, 2.8);
                    ctx.lineTo(15.2, 5.4); ctx.lineTo(6.4, 14.2); ctx.closePath();
                    ctx.stroke();
                    // ferrule
                    ctx.beginPath();
                    ctx.moveTo(10.8, 4.6); ctx.lineTo(13.4, 7.2);
                    ctx.stroke();
                    // baseline
                    ctx.beginPath();
                    ctx.moveTo(9, 15.5); ctx.lineTo(15.5, 15.5);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.editClicked()
                onEntered: if (row.editTooltip) editTip.tooltipPopup.open()
                onExited: editTip.tooltipPopup.close()
            }

            MoneroComponents.Tooltip {
                id: editTip
                anchors.fill: parent
                tooltipLeft: true
                text: row.editTooltip
            }
        }
    }
}
