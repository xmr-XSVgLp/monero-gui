import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Small neon safe: door, combination dial and handle.
Item {
    id: root
    property color accent: MoneroComponents.Style.orange
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
            // body (chamfered corners)
            var x0 = lw, y0 = lw, x1 = w - lw, y1 = h * 0.86, k = w * 0.14;
            ctx.beginPath();
            ctx.moveTo(x0 + k, y0); ctx.lineTo(x1 - k, y0); ctx.lineTo(x1, y0 + k);
            ctx.lineTo(x1, y1 - k); ctx.lineTo(x1 - k, y1); ctx.lineTo(x0 + k, y1);
            ctx.lineTo(x0, y1 - k); ctx.lineTo(x0, y0 + k); ctx.closePath();
            ctx.stroke();
            // feet
            ctx.fillRect(w * 0.18, y1, w * 0.14, h - y1);
            ctx.fillRect(w * 0.68, y1, w * 0.14, h - y1);
            // dial
            var cx = w * 0.44, cy = (y0 + y1) / 2, r = w * 0.2;
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke();
            ctx.lineWidth = lw * 0.8;
            for (var i = 0; i < 4; ++i) {
                var a = i * Math.PI / 2 + Math.PI / 4;
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(a) * r * 0.35, cy + Math.sin(a) * r * 0.35);
                ctx.lineTo(cx + Math.cos(a) * r * 0.85, cy + Math.sin(a) * r * 0.85);
                ctx.stroke();
            }
            // handle
            ctx.lineWidth = lw;
            ctx.beginPath(); ctx.moveTo(w * 0.8, cy - h * 0.14); ctx.lineTo(w * 0.8, cy + h * 0.14); ctx.stroke();
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
