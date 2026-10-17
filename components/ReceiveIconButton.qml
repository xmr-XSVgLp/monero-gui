import QtQuick

import "../components" as MoneroComponents

// Small chamfered icon button used on the Receive page (address rows, address box).
// icon: "search" | "edit" | "copy"
Item {
    id: root
    property string icon: "copy"
    property string tooltip: ""
    property bool tooltipLeft: true
    readonly property bool hovered: area.containsMouse
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    signal clicked()

    implicitWidth: 28
    implicitHeight: 28

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 6
        accent: root.hovered ? root.accent : root.border
        lineOpacity: root.hovered ? 0.9 : 0.28
        fillColor: root.accent
        fillOpacity: root.hovered ? 0.18 : 0.0
        glow: root.hovered ? 0.4 : 0.0
        ticks: false
    }

    Canvas {
        id: glyph
        anchors.centerIn: parent
        width: 18
        height: 18
        scale: 0.85
        property color c: root.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
        property string kind: root.icon
        onCChanged: requestPaint()
        onKindChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = c;
            ctx.lineWidth = 1.6;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.beginPath();
            if (kind === "edit") {
                ctx.moveTo(3, 15); ctx.lineTo(3.8, 11.6); ctx.lineTo(12.6, 2.8);
                ctx.lineTo(15.2, 5.4); ctx.lineTo(6.4, 14.2); ctx.closePath();
                ctx.moveTo(10.8, 4.6); ctx.lineTo(13.4, 7.2);
                ctx.moveTo(9, 15.5); ctx.lineTo(15.5, 15.5);
            } else if (kind === "search") {
                ctx.arc(7.5, 7.5, 5, 0, 2 * Math.PI);
                ctx.moveTo(11.2, 11.2); ctx.lineTo(16, 16);
            } else {
                // two overlapping sheets
                ctx.rect(6, 6, 9.5, 10);
                ctx.moveTo(3, 12.5); ctx.lineTo(3, 3); ctx.lineTo(11.5, 3);
            }
            ctx.stroke();
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onEntered: if (root.tooltip) tip.tooltipPopup.open()
        onExited: tip.tooltipPopup.close()
    }

    MoneroComponents.Tooltip {
        id: tip
        anchors.fill: parent
        tooltipLeft: root.tooltipLeft
        text: root.tooltip
    }
}
