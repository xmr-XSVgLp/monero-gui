import QtQuick

import "../components" as MoneroComponents

// Short "TX BROADCAST" animation played right after a transaction is sent.
// play(callback) runs the animation and then calls callback().
Rectangle {
    id: root
    readonly property color accent: MoneroComponents.Style.orange
    property var done: null
    property int step: 0
    property string hexLine: ""

    color: MoneroComponents.Style.blackTheme ? "#CC000000" : "#CCF2FFF4"
    visible: false

    function randomHex(n) {
        var s = "";
        for (var i = 0; i < n; ++i) s += "0123456789abcdef".charAt(Math.floor(Math.random() * 16));
        return s;
    }

    function play(callback) {
        done = callback;
        step = 0;
        hexLine = randomHex(48);
        opacity = 1;
        visible = true;
        glitch.trigger();
        seq.restart();
        if (typeof appWindow !== "undefined" && appWindow.playFx) appWindow.playFx("send");
    }

    function finish() {
        seq.stop();
        visible = false;
        var cb = done;
        done = null;
        if (cb) cb();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.finish()
    }

    Item {
        id: panel
        anchors.centerIn: parent
        width: Math.min(root.width - 40, 460)
        height: 150

        Rectangle {
            anchors.fill: parent
            color: MoneroComponents.Style.blackTheme ? "#000" : "#FFF"
            opacity: 0.85
        }

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 14
            lineWidth: 1.5
            glow: 0.7
        }

        Column {
            anchors.centerIn: parent
            spacing: 12

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                Text {
                    text: "TX BROADCAST"
                    color: MoneroComponents.Style.textAccent
                    font.family: MoneroComponents.Style.fontMonoBold.name
                    font.pixelSize: 26
                    font.letterSpacing: 2
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: 3
                        Text {
                            text: "▸"
                            color: root.accent
                            font.pixelSize: 26
                            opacity: (root.step % 4) > index ? 1.0 : 0.15
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hexLine
                color: MoneroComponents.Style.textAccent
                opacity: 0.55
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 10
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.step < 8 ? "> propagando a la red p2p ..." : "> enviado ✓"
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 13
            }
        }
    }

    MoneroComponents.GlitchFx {
        id: glitch
        anchors.fill: parent
        target: panel
        duration: 360
    }

    SequentialAnimation {
        id: seq
        loops: 1
        SequentialAnimation {
            loops: 10
            ScriptAction { script: { root.step += 1; root.hexLine = root.randomHex(48); } }
            PauseAnimation { duration: 120 }
        }
        ScriptAction { script: glitch.trigger() }
        PauseAnimation { duration: 260 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 200 }
        ScriptAction { script: root.finish() }
    }
}
