// Cypherpunk status toast: shown at the bottom centre of the window.
// API kept compatible with the old statusMessage Rectangle: set `text`, toggle `visible`.
import QtQuick 2.9

import "." as MoneroComponents

Item {
    id: toast

    property alias text: label.text
    property int bottomMargin: 24
    readonly property real restY: (parent ? parent.height : 0) - height - bottomMargin
    property int duration: 3000
    readonly property color accent: MoneroComponents.Style.blackTheme ? "#FF7A1A" : "#E86A0C"
    readonly property color accentDark: MoneroComponents.Style.blackTheme ? "#E25800" : "#C85400"
    readonly property int cut: 10

    z: 99
    visible: false
    width: Math.min(row.implicitWidth + 2 * cut + 28, parent ? parent.width - 40 : 600)
    height: 42
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    y: restY

    function flash() {
        enter.restart();
        drain.restart();
        sweep.restart();
    }

    onVisibleChanged: if (visible) flash()

    // soft orange glow
    Canvas {
        id: glow
        anchors.fill: chamfer
        anchors.margins: -8
        opacity: 0.45
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.shadowColor = toast.accent;
            ctx.shadowBlur = 14;
            ctx.fillStyle = toast.accent;
            var c = toast.cut, w = width - 16, h = height - 16;
            ctx.translate(8, 8);
            ctx.beginPath();
            ctx.moveTo(c, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - c);
            ctx.lineTo(w - c, h); ctx.lineTo(0, h); ctx.lineTo(0, c);
            ctx.closePath(); ctx.fill();
        }
        Connections {
            target: MoneroComponents.Style
            function onBlackThemeChanged() { glow.requestPaint(); chamfer.requestPaint(); }
        }
    }

    // chamfered orange body
    Canvas {
        id: chamfer
        width: parent.width
        height: parent.height
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var c = toast.cut, w = width, h = height;
            ctx.beginPath();
            ctx.moveTo(c, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - c);
            ctx.lineTo(w - c, h); ctx.lineTo(0, h); ctx.lineTo(0, c);
            ctx.closePath();
            var g = ctx.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0, toast.accent);
            g.addColorStop(1, toast.accentDark);
            ctx.fillStyle = g;
            ctx.fill();
            // inner bevel line
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.35);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(c + 1, 1.5); ctx.lineTo(w - 1.5, 1.5);
            ctx.stroke();
            // corner ticks
            ctx.fillStyle = "#140A03";
            ctx.fillRect(w - 16, 5, 10, 2);
        }

        // scanline sweep
        Item {
            anchors.fill: parent
            clip: true
            Rectangle {
                id: beam
                width: 40
                height: parent.height
                x: -width
                opacity: 0.35
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: "white" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            NumberAnimation {
                id: sweep
                target: beam; property: "x"
                from: -beam.width; to: chamfer.width
                duration: 700; easing.type: Easing.OutCubic
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: ">_"
                color: "#140A03"
                font.family: MoneroComponents.Style.fontMonoBold.name
                font.pixelSize: 15
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: toast.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 450 }
                    NumberAnimation { to: 1.0; duration: 450 }
                }
            }

            Text {
                id: label
                color: "#140A03"
                font.family: MoneroComponents.Style.fontMonoBold.name
                font.pixelSize: 14
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // time-left bar
        Rectangle {
            id: timeBar
            anchors.left: parent.left
            anchors.leftMargin: toast.cut
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            height: 2
            color: "#140A03"
            opacity: 0.55
            width: chamfer.width - 2 * toast.cut
            NumberAnimation on width {
                id: drain
                running: false
                from: chamfer.width - 2 * toast.cut; to: 0
                duration: toast.duration
            }
        }
    }

    ParallelAnimation {
        id: enter
        NumberAnimation { target: toast; property: "y"; from: toast.restY + toast.height + toast.bottomMargin; to: toast.restY; duration: 260; easing.type: Easing.OutBack }
        NumberAnimation { target: toast; property: "opacity"; from: 0; to: 1; duration: 200 }
    }
}
