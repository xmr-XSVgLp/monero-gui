import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Neon diagonal arrow for the transaction history: outgoing up-right (red),
// incoming down-left (green).
Item {
    id: root
    property bool out: false
    readonly property color tint: out
        ? (MoneroComponents.Style.blackTheme ? "#FF4D5E" : "#C62828")
        : MoneroComponents.Style.orange
    width: 20
    height: 20

    Canvas {
        id: c
        anchors.fill: parent
        property var deps: [root.out, root.tint, width, height]
        onDepsChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), w = width, h = height, m = 3;
            ctx.reset();
            ctx.strokeStyle = root.tint;
            ctx.lineWidth = 2;
            ctx.lineCap = "square";
            ctx.lineJoin = "miter";
            ctx.beginPath();
            if (root.out) {
                ctx.moveTo(m, h - m); ctx.lineTo(w - m, m);
                ctx.moveTo(w * 0.42, m); ctx.lineTo(w - m, m); ctx.lineTo(w - m, h * 0.58);
            } else {
                ctx.moveTo(w - m, m); ctx.lineTo(m, h - m);
                ctx.moveTo(m, h * 0.42); ctx.lineTo(m, h - m); ctx.lineTo(w * 0.58, h - m);
            }
            ctx.stroke();
        }
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            blurMax: 16
            shadowEnabled: true
            shadowColor: root.tint
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: 0.7
            shadowOpacity: 0.9
        }
    }
}
