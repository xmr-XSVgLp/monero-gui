import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Chamfered neon frame shared by inputs, checkboxes, tooltips and dialogs.
Item {
    id: root
    property color accent: MoneroComponents.Style.orange
    property int cut: 8
    property real lineWidth: 1
    property real lineOpacity: 1.0
    property real fillOpacity: 0.0
    property color fillColor: accent
    property real glow: 0.0            // 0 = no glow, 1 = full
    property bool ticks: true          // little corner marks
    property bool cutTopLeft: true
    property bool cutBottomRight: true

    Canvas {
        id: canvas
        anchors.fill: parent
        property var deps: [root.accent, root.cut, root.lineWidth, root.lineOpacity,
                            root.fillOpacity, root.fillColor, root.ticks, width, height]
        onDepsChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            var c = root.cut, w = width, h = height, o = root.lineWidth / 2;
            ctx.reset();
            ctx.beginPath();
            ctx.moveTo(root.cutTopLeft ? c + o : o, o);
            ctx.lineTo(w - o, o);
            ctx.lineTo(w - o, root.cutBottomRight ? h - c - o : h - o);
            if (root.cutBottomRight) ctx.lineTo(w - c - o, h - o);
            ctx.lineTo(o, h - o);
            ctx.lineTo(o, root.cutTopLeft ? c + o : o);
            ctx.closePath();
            if (root.fillOpacity > 0) {
                ctx.fillStyle = Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.fillOpacity);
                ctx.fill();
            }
            if (root.lineOpacity > 0 && root.lineWidth > 0) {
                ctx.lineWidth = root.lineWidth;
                ctx.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.lineOpacity);
                ctx.stroke();
                if (root.ticks && w > 30 && h > 16) {
                    ctx.fillStyle = ctx.strokeStyle;
                    ctx.fillRect(w - 7, 2.5, 4, 1);
                    ctx.fillRect(3, h - 3.5, 4, 1);
                }
            }
        }

        layer.enabled: root.glow > 0 && GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            blurMax: 24
            shadowEnabled: true
            shadowColor: root.accent
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: 0.4 + 0.6 * root.glow
            shadowOpacity: root.glow
        }
    }
}
