import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Hacker frame for a QR code: glowing corner brackets, a slow scan line and a
// Monero badge. Fill the QR container with it; it draws slightly outside.
Item {
    id: root
    property color accent: MoneroComponents.Style.orange
    property int gap: 9
    property int arm: 26
    property bool scanning: visible

    Canvas {
        id: brackets
        x: -root.gap
        y: -root.gap
        width: root.width + 2 * root.gap
        height: root.height + 2 * root.gap
        property var deps: [root.accent, width, height]
        onDepsChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), w = width, h = height, a = root.arm, o = 1.5;
            ctx.reset();
            ctx.strokeStyle = root.accent;
            ctx.lineWidth = 3;
            ctx.lineCap = "square";
            ctx.beginPath();
            ctx.moveTo(o, a); ctx.lineTo(o, o + 6); ctx.lineTo(o + 6, o); ctx.lineTo(a, o);
            ctx.moveTo(w - a, o); ctx.lineTo(w - o, o); ctx.lineTo(w - o, a);
            ctx.moveTo(w - o, h - a); ctx.lineTo(w - o, h - o - 6); ctx.lineTo(w - o - 6, h - o); ctx.lineTo(w - a, h - o);
            ctx.moveTo(a, h - o); ctx.lineTo(o, h - o); ctx.lineTo(o, h - a);
            ctx.stroke();
            // thin dashed rails between brackets
            ctx.lineWidth = 1;
            ctx.globalAlpha = 0.35;
            ctx.beginPath();
            for (var x = a + 8; x < w - a - 8; x += 8) { ctx.moveTo(x, o); ctx.lineTo(x + 3, o); ctx.moveTo(x, h - o); ctx.lineTo(x + 3, h - o); }
            for (var y = a + 8; y < h - a - 8; y += 8) { ctx.moveTo(o, y); ctx.lineTo(o, y + 3); ctx.moveTo(w - o, y); ctx.lineTo(w - o, y + 3); }
            ctx.stroke();
        }
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            blurMax: 20
            shadowEnabled: true
            shadowColor: root.accent
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: 0.8
            shadowOpacity: 0.9
        }
    }

    // scan line, kept faint so phones still read the code
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            id: scan
            width: parent.width
            height: 14
            visible: root.scanning
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.85; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) }
                GradientStop { position: 1.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55) }
            }
            SequentialAnimation on y {
                running: root.scanning
                loops: Animation.Infinite
                NumberAnimation { from: -scan.height; to: root.height; duration: 2600; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 900 }
            }
        }
    }

    // Monero badge sitting on the bottom edge, inside the quiet zone
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.bottom
        anchors.verticalCenterOffset: root.gap / 2
        width: 26
        height: 26
        radius: 13
        color: MoneroComponents.Style.blackTheme ? "#000" : "#FFF"
        border.color: root.accent
        border.width: 1.5
        Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)
            source: "qrc:///images/monero-vector.svg"
            mipmap: true
        }
    }
}
