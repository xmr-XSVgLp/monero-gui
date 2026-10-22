import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Animated Trezor Safe 7 (same drawing as open-wallet-from-file-trezor) with the wallet's
// Monero logo on its screen. Shown inside the "proceed to the device" windows.
Item {
    id: root
    property bool running: visible
    property color accent: MoneroComponents.Style.orange
    readonly property bool dark: MoneroComponents.Style.blackTheme
    implicitWidth: 150
    implicitHeight: 190

    // device outline: rounded top, straight sides, chamfered bottom
    function bodyPath(ctx, w, h, lw) {
        var x0 = lw, x1 = w - lw, y0 = lw, y1 = h - lw, r = w * 0.12;
        var ys = h * 0.70, xb0 = w * 0.2, xb1 = w * 0.8, rb = w * 0.06;
        ctx.beginPath();
        ctx.moveTo(x0 + r, y0);
        ctx.lineTo(x1 - r, y0); ctx.arcTo(x1, y0, x1, y0 + r, r);
        ctx.lineTo(x1, ys);
        ctx.lineTo(xb1 + rb, y1 - rb * 0.6); ctx.quadraticCurveTo(xb1, y1, xb1 - rb, y1);
        ctx.lineTo(xb0 + rb, y1); ctx.quadraticCurveTo(xb0, y1, xb0 - rb, y1 - rb * 0.6);
        ctx.lineTo(x0, ys);
        ctx.lineTo(x0, y0 + r); ctx.arcTo(x0, y0, x0 + r, y0, r);
        ctx.closePath();
    }

    Item {
        id: device
        width: 112
        height: 160
        anchors.centerIn: parent

        // pulse rings with the device shape
        Repeater {
            model: 2
            Canvas {
                id: ring
                anchors.fill: parent
                opacity: 0
                property var deps: [root.accent]
                onDepsChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = root.accent;
                    ctx.lineWidth = 2;
                    root.bodyPath(ctx, width, height, 2);
                    ctx.stroke();
                }
                SequentialAnimation {
                    running: root.running
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 900 }
                    ParallelAnimation {
                        NumberAnimation { target: ring; property: "scale"; from: 1.0; to: 1.35; duration: 1800; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ring; property: "opacity"; from: 0.6; to: 0.0; duration: 1800; easing.type: Easing.OutCubic }
                    }
                    PauseAnimation { duration: (1 - index) * 900 }
                }
            }
        }

        // body
        Canvas {
            id: body
            anchors.fill: parent
            property var deps: [root.accent, root.dark]
            onDepsChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d"), w = width, h = height, lw = 3;
                ctx.reset();
                root.bodyPath(ctx, w, h, lw);
                ctx.fillStyle = root.dark ? "#050A06" : "#F4FBF6";
                ctx.fill();
                ctx.strokeStyle = root.accent;
                ctx.lineWidth = lw;
                ctx.stroke();
                // padlock
                var cx = w / 2, py = h * 0.86, bw = w * 0.13, bh = w * 0.1;
                ctx.fillStyle = root.accent;
                ctx.fillRect(cx - bw / 2, py - bh / 2, bw, bh);
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(cx, py - bh / 2, bw * 0.32, Math.PI, 0);
                ctx.stroke();
            }
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                blurMax: 24
                shadowEnabled: true
                shadowColor: root.accent
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowBlur: glowPulse.value
                shadowOpacity: 0.9
            }
            QtObject {
                id: glowPulse
                property real value: 0.5
                SequentialAnimation on value {
                    running: root.running
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.9; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.4; duration: 1100; easing.type: Easing.InOutSine }
                }
            }
        }

        // screen
        Rectangle {
            id: screen
            x: parent.width * 0.12
            y: parent.height * 0.08
            width: parent.width * 0.76
            height: parent.height * 0.58
            radius: 6
            color: root.dark ? "#0A140C" : "#E6F4EA"
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
            border.width: 1.5
            clip: true

            // faint binary rain, like the screen in the icon
            Text {
                id: rain
                width: parent.width
                text: "0110100110\n1001011010\n0101101001\n1100101100\n0011010110\n1010011001\n0110100110\n1001011010\n0101101001\n1100101100"
                color: root.accent
                opacity: 0.13
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 9
                lineHeight: 1.1
                horizontalAlignment: Text.AlignHCenter
                NumberAnimation on y {
                    running: root.running
                    loops: Animation.Infinite
                    from: -rain.implicitHeight / 2
                    to: 0
                    duration: 4000
                }
            }

            // wallet logo, breathing
            Image {
                id: logo
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -4
                width: 52
                height: 52
                source: "qrc:///images/logos/xmr-ticker@2x.png"
                smooth: true
                mipmap: true
                SequentialAnimation on scale {
                    running: root.running
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.08; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                }
            }

            // "hold to confirm" bar under the logo
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                width: parent.width * 0.5
                height: 4
                radius: 2
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: root.accent
                    SequentialAnimation on width {
                        running: root.running
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: screen.width * 0.5; duration: 1600; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 500 }
                    }
                }
            }

            // scan line
            Rectangle {
                id: scan
                width: parent.width
                height: 14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35) }
                }
                NumberAnimation on y {
                    running: root.running
                    loops: Animation.Infinite
                    from: -scan.height
                    to: screen.height
                    duration: 2200
                }
            }
        }

        // gentle float
        SequentialAnimation on anchors.verticalCenterOffset {
            running: root.running
            loops: Animation.Infinite
            NumberAnimation { to: -4; duration: 1400; easing.type: Easing.InOutSine }
            NumberAnimation { to: 4; duration: 1400; easing.type: Easing.InOutSine }
        }
    }
}
