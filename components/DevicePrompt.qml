import QtQuick
import QtQuick.Effects

import "../components" as MoneroComponents

// Full-window prompt shown while the Trezor waits for the user to confirm on the device.
Rectangle {
    id: root
    property string title: "CONFIRMA EN TU TREZOR"
    property string subtitle: "Revisa los datos en la pantalla del dispositivo y confírmalos allí."
    readonly property color accent: MoneroComponents.Style.orange
    readonly property bool dark: MoneroComponents.Style.blackTheme

    color: dark ? "#D9000000" : "#D9F2FFF4"
    visible: false
    opacity: visible ? 1 : 0

    function show(forTransaction) {
        title = forTransaction ? "CONFIRMA LA TRANSACCIÓN EN TU TREZOR" : "CONFIRMA EN TU TREZOR";
        subtitle = forTransaction
            ? "Comprueba dirección e importe en la pantalla del Safe 7 y mantén pulsado para firmar."
            : "Revisa los datos en la pantalla del dispositivo y confírmalos allí.";
        visible = true;
        if (typeof appWindow !== "undefined" && appWindow.playFx) appWindow.playFx("alert");
    }

    function hide() {
        visible = false;
    }

    // swallow clicks so nothing behind is pressed by accident
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = true
    }

    Column {
        anchors.centerIn: parent
        spacing: 26

        Item {
            id: stage
            width: 260
            height: 250
            anchors.horizontalCenter: parent.horizontalCenter

            // pulse rings
            Repeater {
                model: 3
                Rectangle {
                    id: ring
                    anchors.centerIn: device
                    width: device.width
                    height: device.height
                    radius: 22
                    color: "transparent"
                    border.color: root.accent
                    border.width: 2
                    opacity: 0
                    SequentialAnimation {
                        running: root.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 600 }
                        ParallelAnimation {
                            NumberAnimation { target: ring; property: "scale"; from: 1.0; to: 1.6; duration: 1800; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0.0; duration: 1800; easing.type: Easing.OutCubic }
                        }
                        PauseAnimation { duration: (2 - index) * 600 }
                    }
                }
            }

            // Trezor Safe 7 silhouette
            Item {
                id: device
                anchors.centerIn: parent
                width: 104
                height: 172

                Rectangle {
                    id: body
                    anchors.fill: parent
                    radius: 22
                    color: root.dark ? "#050805" : "#FFFFFF"
                    border.color: root.accent
                    border.width: 2
                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: true
                        blurMax: 32
                        shadowEnabled: true
                        shadowColor: root.accent
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        shadowBlur: 1.0
                        shadowOpacity: 0.8
                    }
                }

                Rectangle {
                    id: screen
                    x: 9; y: 9
                    width: parent.width - 18
                    height: parent.height - 40
                    radius: 13
                    color: root.dark ? "#0B1A0E" : "#D0D8D2"
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                    border.width: 1
                    clip: true

                    // hold-to-confirm ring
                    Canvas {
                        id: hold
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -8
                        width: 54
                        height: 54
                        property real p: 0
                        onPChanged: requestPaint()
                        NumberAnimation on p {
                            running: root.visible
                            loops: Animation.Infinite
                            from: 0; to: 1; duration: 1600
                            easing.type: Easing.InOutQuad
                        }
                        onPaint: {
                            var ctx = getContext("2d"), r = width / 2 - 3;
                            ctx.reset();
                            ctx.lineWidth = 3;
                            ctx.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2);
                            ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke();
                            ctx.strokeStyle = root.accent;
                            ctx.beginPath(); ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * p); ctx.stroke();
                            // check mark
                            ctx.lineWidth = 3;
                            ctx.lineCap = "square";
                            ctx.beginPath();
                            ctx.moveTo(width * 0.32, height * 0.52);
                            ctx.lineTo(width * 0.45, height * 0.65);
                            ctx.lineTo(width * 0.70, height * 0.38);
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        text: "HOLD"
                        color: MoneroComponents.Style.textAccent
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }

                    // screen scanline
                    Rectangle {
                        id: sl
                        width: parent.width
                        height: 2
                        color: root.accent
                        opacity: 0.25
                        NumberAnimation on y {
                            running: root.visible
                            loops: Animation.Infinite
                            from: 0; to: screen.height; duration: 1300
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    text: "TREZOR"
                    color: MoneroComponents.Style.textAccent
                    opacity: 0.8
                    font.family: MoneroComponents.Style.fontMonoBold.name
                    font.pixelSize: 9
                    font.letterSpacing: 2.5
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - 60, 560)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.title + (blink.on ? "_" : " ")
            color: MoneroComponents.Style.textAccent
            font.family: MoneroComponents.Style.fontMonoBold.name
            font.pixelSize: 22
            font.letterSpacing: 1.5
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - 60, 460)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.subtitle
            color: MoneroComponents.Style.defaultFontColor
            opacity: 0.8
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 13
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "[ ocultar ]"
            color: MoneroComponents.Style.textAccent
            opacity: hideArea.containsMouse ? 1 : 0.5
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 12
            MouseArea {
                id: hideArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.hide()
            }
        }
    }

    Timer {
        id: blink
        property bool on: true
        interval: 450
        repeat: true
        running: root.visible
        onTriggered: on = !on
    }
}
