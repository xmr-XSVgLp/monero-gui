import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Small neon Trezor Safe 7: wide top with the screen, narrower base with the padlock.
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
            var ctx = getContext("2d"), w = width, h = height, lw = Math.max(1.4, h / 14);
            ctx.reset();
            ctx.strokeStyle = root.accent;
            ctx.fillStyle = root.accent;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            function rrect(x, y, rw, rh, r) {
                ctx.beginPath();
                ctx.moveTo(x + r, y); ctx.lineTo(x + rw - r, y);
                ctx.arcTo(x + rw, y, x + rw, y + r, r); ctx.lineTo(x + rw, y + rh - r);
                ctx.arcTo(x + rw, y + rh, x + rw - r, y + rh, r); ctx.lineTo(x + r, y + rh);
                ctx.arcTo(x, y + rh, x, y + rh - r, r); ctx.lineTo(x, y + r);
                ctx.arcTo(x, y, x + r, y, r); ctx.closePath();
            }

            // body: wide top with straight sides, then a diagonal down to a narrower flat base (Safe 7 shape)
            var bh = h - lw, bw = bh * 0.7, bx = (w - bw) / 2, by = lw / 2;
            var r = bw * 0.16, nb = bw * 0.2, t0 = by + bh * 0.70, rb = r * 0.5;
            ctx.lineWidth = lw;
            ctx.beginPath();
            ctx.moveTo(bx + r, by); ctx.lineTo(bx + bw - r, by);
            ctx.arcTo(bx + bw, by, bx + bw, by + r, r);
            ctx.lineTo(bx + bw, t0);
            ctx.lineTo(bx + bw - nb + rb * 0.4, by + bh - rb);
            ctx.quadraticCurveTo(bx + bw - nb, by + bh, bx + bw - nb - rb, by + bh);
            ctx.lineTo(bx + nb + rb, by + bh);
            ctx.quadraticCurveTo(bx + nb, by + bh, bx + nb - rb * 0.4, by + bh - rb);
            ctx.lineTo(bx, t0);
            ctx.lineTo(bx, by + r);
            ctx.arcTo(bx, by, bx + r, by, r);
            ctx.closePath();
            ctx.stroke();
            // screen on the wide part
            var m = lw * 1.4;
            ctx.lineWidth = lw * 0.6;
            ctx.globalAlpha = 0.7;
            rrect(bx + m, by + m, bw - 2 * m, t0 - by - m, bw * 0.08);
            ctx.stroke();
            ctx.globalAlpha = 1;
            // padlock on the base
            var cx = w / 2, cy = by + bh * 0.88, pw = bw * 0.22, ph = pw * 0.7;
            ctx.fillRect(cx - pw / 2, cy - ph / 2, pw, ph);
            ctx.lineWidth = lw * 0.6;
            ctx.beginPath();
            ctx.arc(cx, cy - ph / 2, pw * 0.32, Math.PI, 0);
            ctx.stroke();
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
