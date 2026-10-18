import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Small neon USB stick: connector with its two contacts on top, body with a light below.
Item {
    id: root
    property color accent: MoneroComponents.Style.blackTheme ? "#A66BFF" : "#6B2FD6"
    property bool glow: true
    implicitWidth: 22
    implicitHeight: 22

    Canvas {
        id: c
        anchors.fill: parent
        property var deps: [root.accent, width, height]
        onDepsChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), w = width, h = height, lw = Math.max(1.5, w / 13);
            ctx.reset();
            ctx.strokeStyle = root.accent;
            ctx.fillStyle = root.accent;
            ctx.lineWidth = lw;
            // connector
            var cx0 = w * 0.32, cx1 = w * 0.68, cy0 = lw, cy1 = h * 0.36;
            ctx.strokeRect(cx0, cy0, cx1 - cx0, cy1 - cy0);
            ctx.fillRect(w * 0.39, h * 0.13, w * 0.08, h * 0.1);
            ctx.fillRect(w * 0.53, h * 0.13, w * 0.08, h * 0.1);
            // body (rounded bottom corners)
            var x0 = w * 0.2, x1 = w * 0.8, y0 = cy1, y1 = h - lw, r = w * 0.14;
            ctx.beginPath();
            ctx.moveTo(x0, y0); ctx.lineTo(x1, y0);
            ctx.lineTo(x1, y1 - r); ctx.arcTo(x1, y1, x1 - r, y1, r);
            ctx.lineTo(x0 + r, y1); ctx.arcTo(x0, y1, x0, y1 - r, r);
            ctx.closePath();
            ctx.stroke();
            // activity light
            ctx.beginPath(); ctx.arc(w * 0.5, (y0 + y1) / 2 + h * 0.04, w * 0.07, 0, 2 * Math.PI); ctx.fill();
        }
        layer.enabled: root.glow && GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            blurMax: 16
            shadowEnabled: true
            shadowColor: root.accent
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: 0.6
            shadowOpacity: 0.85
        }
    }
}
