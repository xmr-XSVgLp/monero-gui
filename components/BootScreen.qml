import QtQuick

import "../components" as MoneroComponents

// Terminal boot sequence shown once when the app opens. Click or press a key to skip.
Rectangle {
    id: boot
    property bool active: true
    property int lineIndex: 0
    property int charIndex: 0
    signal finished()

    readonly property color accent: MoneroComponents.Style.orange
    readonly property var lines: [
        "MONERO // SAFE7 EDITION",
        "> init secure memory ............ OK",
        "> load ringct + bulletproofs .... OK",
        "> trezor thp transport .......... OK",
        "> p2p node bridge ............... OK",
        "> decrypt interface layer ....... OK",
        "",
        "ACCESS GRANTED"
    ]
    property string typed: ""

    color: MoneroComponents.Style.blackTheme ? "#000000" : "#F2FFF4"
    visible: false
    focus: visible

    function start() {
        if (!active) { finish(); return; }
        typed = ""; lineIndex = 0; charIndex = 0;
        opacity = 1;
        visible = true;
        forceActiveFocus();
        typer.start();
        if (typeof appWindow !== "undefined" && appWindow.playFx) appWindow.playFx("boot");
    }

    function finish() {
        typer.stop();
        pauseLine.stop();
        hold.stop();
        if (!visible) boot.finished();
        else if (!outro.running) outro.start();
    }

    Keys.onPressed: (event) => { finish(); event.accepted = true; }

    MoneroComponents.MatrixRain {
        anchors.fill: parent
        opacity: MoneroComponents.Style.blackTheme ? 0.22 : 0.15
        running: boot.visible
    }

    Rectangle {
        id: termBox
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 520)
        height: term.implicitHeight + 48
        color: MoneroComponents.Style.blackTheme ? "#E6000000" : "#E6F2FFF4"

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 12
            lineWidth: 1.5
            glow: 0.6
        }

        Text {
            id: term
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            color: MoneroComponents.Style.textAccent
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 15
            lineHeight: 1.35
            wrapMode: Text.NoWrap
            textFormat: Text.PlainText
            text: boot.typed + (cursor.on ? "█" : " ")
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        text: "[ click / any key ]"
        color: MoneroComponents.Style.textAccent
        opacity: 0.45
        font.family: MoneroComponents.Style.fontMonoRegular.name
        font.pixelSize: 11
    }

    Timer {
        id: cursor
        property bool on: true
        interval: 400
        repeat: true
        running: boot.visible
        onTriggered: on = !on
    }

    Timer {
        id: typer
        interval: 14
        repeat: true
        onTriggered: {
            if (boot.lineIndex >= boot.lines.length) {
                stop();
                hold.start();
                return;
            }
            var line = boot.lines[boot.lineIndex];
            if (boot.charIndex < line.length) {
                // type fast through the dotted leaders
                var step = line.charAt(boot.charIndex) === "." ? 4 : 2;
                boot.typed += line.substr(boot.charIndex, step);
                boot.charIndex += step;
            } else {
                boot.typed += "\n";
                boot.lineIndex += 1;
                boot.charIndex = 0;
                stop();
                pauseLine.interval = boot.lineIndex === 1 ? 300 : 110;
                pauseLine.start();
            }
        }
    }

    // small pause after each line so it feels like work is being done
    Timer {
        id: pauseLine
        interval: 90
        onTriggered: typer.start()
    }

    Timer {
        id: hold
        interval: 450
        onTriggered: boot.finish()
    }

    SequentialAnimation {
        id: outro
        ScriptAction { script: glitch.trigger() }
        PauseAnimation { duration: 220 }
        NumberAnimation { target: boot; property: "opacity"; to: 0; duration: 280 }
        ScriptAction { script: { boot.visible = false; boot.finished(); } }
    }

    MoneroComponents.GlitchFx {
        id: glitch
        anchors.fill: parent
        target: termBox
        duration: 400
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: boot.finish()
    }
}
