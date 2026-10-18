import QtQuick

import "../components" as MoneroComponents

// Start screen shown once when the app opens: Monero coin, name, progress bar and version.
// Click or press a key to skip.
Rectangle {
    id: boot
    property bool active: true
    property string versionNumber: ""
    property string versionTag: ""
    signal finished()

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color moneroOrange: "#F26822"
    readonly property color textColor: dark ? "#ECECEC" : "#1E2421"
    readonly property color dimColor: dark ? "#8C8C8C" : "#6A716D"

    color: dark ? "#07090A" : "#D3D8D4"
    visible: false
    focus: visible

    function start() {
        if (!active) { finish(); return; }
        opacity = 1;
        visible = true;
        forceActiveFocus();
        progress.value = 0;
        intro.start();
        if (typeof appWindow !== "undefined" && appWindow.playFx) appWindow.playFx("boot");
    }

    function finish() {
        intro.stop();
        if (!visible) boot.finished();
        else if (!outro.running) outro.start();
    }

    Keys.onPressed: (event) => { finish(); event.accepted = true; }

    // soft light behind the coin
    Canvas {
        anchors.fill: parent
        property bool dark: boot.dark
        onDarkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var cx = width / 2, cy = height * 0.42, r = Math.max(width, height) * 0.6;
            var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
            g.addColorStop(0, dark ? "#1A1C1D" : "#FFFFFF");
            g.addColorStop(1, dark ? "#07090A" : "#C7CDC8");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
    }

    Column {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        spacing: 0
        opacity: 0
        scale: 0.96

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 170
            height: 170

            Image {
                id: coin
                anchors.centerIn: parent
                width: 170
                height: 170
                source: "qrc:///images/boot-coin.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true

                // slow breathing of the ring glow
                SequentialAnimation on scale {
                    running: boot.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.025; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.025; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                }
            }
        }

        Item { width: 1; height: 26 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "XMR WALLET+"
            color: boot.textColor
            font.family: MoneroComponents.Style.fontLight.name
            font.pixelSize: 34
            font.letterSpacing: 12
            // letterSpacing adds space after the last letter too: shift to keep it centred
            leftPadding: 12
        }

        Item { width: 1; height: 8 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Secure Monero wallet") + translationManager.emptyString
            color: boot.dimColor
            font.family: MoneroComponents.Style.fontRegular.name
            font.pixelSize: 13
            font.letterSpacing: 1
        }

        Item { width: 1; height: 40 }

        // progress bar
        Item {
            id: progress
            property real value: 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: 240
            height: 2

            Rectangle {
                anchors.fill: parent
                radius: 1
                color: boot.textColor
                opacity: 0.12
            }

            Rectangle {
                width: parent.width * progress.value
                height: parent.height
                radius: 1
                color: boot.moneroOrange
            }
        }

        Item { width: 1; height: 14 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (progress.value < 1 ? qsTr("Starting…") : qsTr("Ready")) + translationManager.emptyString
            color: boot.dimColor
            font.family: MoneroComponents.Style.fontRegular.name
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }

    // version at the bottom
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        opacity: content.opacity

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: boot.versionNumber !== ""
            text: qsTr("Version %1").arg(boot.versionNumber) + translationManager.emptyString
            color: boot.dimColor
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 12
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: boot.versionTag !== ""
            text: boot.versionTag
            color: boot.dimColor
            opacity: 0.6
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 10
        }
    }

    SequentialAnimation {
        id: intro
        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
            NumberAnimation { target: content; property: "scale"; from: 0.96; to: 1; duration: 600; easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: progress; property: "value"; from: 0; to: 1; duration: 1500; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 350 }
        ScriptAction { script: boot.finish() }
    }

    SequentialAnimation {
        id: outro
        NumberAnimation { target: boot; property: "opacity"; to: 0; duration: 380; easing.type: Easing.InOutQuad }
        ScriptAction { script: { boot.visible = false; boot.finished(); } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: boot.finish()
    }
}
