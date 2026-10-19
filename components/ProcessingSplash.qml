// Copyright (c) 2014-2024, The Monero Project
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import "../components" as MoneroComponents

Rectangle {
    id: root
    // cyberpunk HUD: chamfered neon frame, scanlines, corner brackets, rotating rings around the
    // logo, chromatic-aberration title and an indeterminate segmented bar
    color: "transparent"
    visible: false
    z: 11

    readonly property color neon: MoneroComponents.Style.c("#00FF41")
    readonly property color cyan: "#00E5FF"
    readonly property color magenta: "#FF2BD6"
    property int tick: 0          // drives the hex stream and the bar
    property real glitch: 0       // 0..1, short bursts on the title
    property string hexLine: ""

    function randomHex(n) {
        var c = "0123456789ABCDEF", out = "";
        for (var i = 0; i < n; i++) out += c[Math.floor(Math.random() * 16)];
        return out;
    }

    Timer {
        interval: 90
        repeat: true
        running: root.visible
        onTriggered: {
            root.tick++;
            if (root.tick % 2 === 0)
                root.hexLine = "0x" + root.randomHex(8) + "  " + root.randomHex(4) + ":" + root.randomHex(4) + "  "
                               + root.randomHex(2) + " " + root.randomHex(2) + " " + root.randomHex(2) + " " + root.randomHex(2);
            root.glitch = Math.random() < 0.07 ? 0.6 + Math.random() * 0.4 : Math.max(0, root.glitch - 0.35);
        }
    }

    // ---- HUD background ----
    // chamfered fill (a plain Rectangle would show square corners outside the frame)
    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 18
        lineOpacity: 0
        fillColor: "#020604"
        fillOpacity: 0.96
        ticks: false
    }
    // scanlines
    Canvas {
        id: scanlines
        anchors.fill: parent
        anchors.margins: 4
        opacity: 0.18
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = MoneroComponents.Style.c("#00FF41");
            for (var y = 0; y < height; y += 3)
                ctx.fillRect(0, y, width, 1);
        }
    }
    // sweeping scan band
    Rectangle {
        id: scanBand
        x: 4
        width: parent.width - 8
        height: 60
        opacity: 0.5
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.9; color: MoneroComponents.Style.c("#2200FF41") }
            GradientStop { position: 1.0; color: MoneroComponents.Style.c("#6600FF41") }
        }
        NumberAnimation on y {
            running: root.visible
            loops: Animation.Infinite
            from: -60
            to: root.height
            duration: 2600
        }
    }
    clip: true

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 18
        accent: root.neon
        lineWidth: 1.5
        lineOpacity: 0.95
        glow: 0.7
        ticks: true
    }

    // corner brackets in cyan
    Repeater {
        model: 4
        Item {
            readonly property bool isRight: index % 2 === 1
            readonly property bool isBottom: index >= 2
            width: 22
            height: 22
            x: isRight ? root.width - width - 12 : 12
            y: isBottom ? root.height - height - 12 : 12
            visible: !((index === 0) || (index === 3))   // chamfered corners already carry the frame
            Rectangle { width: parent.width; height: 2; color: root.cyan; y: parent.isBottom ? parent.height - 2 : 0 }
            Rectangle { width: 2; height: parent.height; color: root.cyan; x: parent.isRight ? parent.width - 2 : 0 }
        }
    }

    // header strip
    Text {
        x: 30
        y: 16
        text: "XMR//WALLET+  ·  " + (root.walletLabel !== "" ? root.walletLabel : "SYS.PROC")
        width: Math.min(implicitWidth, root.width / 2 - 50)
        elide: Text.ElideRight
        color: root.neon
        opacity: 0.8
        font.family: MoneroComponents.Style.fontMonoMedium.name
        font.pixelSize: 11
        font.letterSpacing: 2
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 44
        y: 16
        spacing: 6
        Rectangle {
            width: 7
            height: 7
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: root.magenta
            opacity: root.tick % 10 < 5 ? 1 : 0.25
        }
        Text {
            text: root.deviceMode && root.deviceLabel !== "" ? "TREZOR " + root.deviceLabel : "PID " + (4096 + root.tick % 997)
            width: Math.min(implicitWidth, root.width / 2 - 80)
            elide: Text.ElideRight
            color: root.magenta
            opacity: 0.85
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }
    // footer: hex stream
    Text {
        visible: !root.deviceMode
        x: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        text: "> " + root.hexLine
        color: root.cyan
        opacity: 0.55
        font.family: MoneroComponents.Style.fontMonoRegular.name
        font.pixelSize: 11
    }
    Text {
        visible: !root.deviceMode
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        text: "RINGCT · CLSAG · " + (root.tick % 4 === 0 ? "█" : "▌")
        color: root.neon
        opacity: 0.55
        font.family: MoneroComponents.Style.fontMonoRegular.name
        font.pixelSize: 11
        font.letterSpacing: 1
    }
    property alias messageText: messageTitle.text
    property bool deviceMode: false     // waiting for a confirmation on the Trezor
    property string subText: ""
    property string walletLabel: ""     // wallet being opened / used
    property string deviceLabel: ""     // name of its Trezor
    property bool cancelling: false     // Cancel pressed, waiting for the operation to stop
    signal cancelRequested()
    property string addressText: ""     // address being shown on the Trezor, in groups of 4 to compare
    readonly property int contentHeight: rootLayout.implicitHeight

    function groupedAddress(a) {
        var parts = a.match(/.{1,4}/g) || [];
        var dark = MoneroComponents.Style.blackTheme;
        for (var i = 0; i < parts.length; ++i)
            parts[i] = "<span style='color:" + (i % 2 ? (dark ? "#9FB8A6" : "#4A6B55") : (dark ? "#FFFFFF" : "#0B1F0F")) + "'>" + parts[i] + "</span>";
        return parts.join("&nbsp; ");
    }

    width: 100
    height: 50

    function show() {
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    ColumnLayout {
        id: rootLayout

        anchors.centerIn: parent

        anchors.leftMargin: 30
        anchors.rightMargin: 30

        spacing: 21

        MoneroComponents.TrezorDeviceAnim {
            visible: root.deviceMode
            running: root.visible && root.deviceMode
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
        }

        Item {
            visible: !root.deviceMode
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Layout.preferredWidth: 120
            Layout.preferredHeight: 120

            // outer ring: green dashes, clockwise
            Canvas {
                id: ringOuter
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var c = width / 2, r = c - 3;
                    ctx.lineWidth = 2;
                    ctx.strokeStyle = MoneroComponents.Style.c("#00FF41");
                    for (var i = 0; i < 24; i++) {
                        if (i % 6 === 5) continue;
                        var a = i / 24 * Math.PI * 2;
                        ctx.beginPath();
                        ctx.arc(c, c, r, a, a + Math.PI * 2 / 24 * 0.6);
                        ctx.stroke();
                    }
                    ctx.lineWidth = 1;
                    ctx.globalAlpha = 0.4;
                    ctx.beginPath();
                    ctx.arc(c, c, r - 7, 0, Math.PI * 2);
                    ctx.stroke();
                }
                RotationAnimator on rotation {
                    running: root.visible && !root.deviceMode
                    loops: Animation.Infinite
                    duration: 6000
                    from: 0
                    to: 360
                }
            }
            // inner ring: cyan arcs, counter-clockwise, faster
            Canvas {
                anchors.centerIn: parent
                width: 92
                height: 92
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var c = width / 2, r = c - 2;
                    ctx.lineWidth = 3;
                    ctx.strokeStyle = "#00E5FF";
                    ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 0.55); ctx.stroke();
                    ctx.beginPath(); ctx.arc(c, c, r, Math.PI, Math.PI * 1.55); ctx.stroke();
                    ctx.strokeStyle = "#FF2BD6";
                    ctx.lineWidth = 2;
                    ctx.beginPath(); ctx.arc(c, c, r, Math.PI * 0.7, Math.PI * 0.82); ctx.stroke();
                }
                RotationAnimator on rotation {
                    running: root.visible && !root.deviceMode
                    loops: Animation.Infinite
                    duration: 1600
                    from: 360
                    to: 0
                }
            }
            Image {
                id: imgLogo
                width: 58
                height: 58
                sourceSize: Qt.size(width * 2, height * 2)
                anchors.centerIn: parent
                source: "qrc:///images/monero-vector.svg"
                mipmap: true
                // pulse
                SequentialAnimation on scale {
                    running: root.visible && !root.deviceMode
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.06; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }


        // title with chromatic aberration (magenta / cyan copies jump during a glitch burst)
        Item {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.preferredHeight: messageTitle.implicitHeight
            Text {
                anchors.fill: messageTitle
                text: messageTitle.text.toUpperCase()
                font: messageTitle.font
                horizontalAlignment: Text.AlignHCenter
                anchors.leftMargin: -(2 + root.glitch * 6)
                anchors.rightMargin: 2 + root.glitch * 6
                color: root.magenta
                opacity: 0.55 + root.glitch * 0.45
            }
            Text {
                anchors.fill: messageTitle
                anchors.leftMargin: 2 + root.glitch * 6
                anchors.rightMargin: -(2 + root.glitch * 6)
                text: messageTitle.text.toUpperCase()
                font: messageTitle.font
                horizontalAlignment: Text.AlignHCenter
                color: root.cyan
                opacity: 0.55 + root.glitch * 0.45
            }
            MoneroComponents.TextPlain {
                id: messageTitle
                width: parent.width
                text: qsTr("Please wait...") + translationManager.emptyString
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 22
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
                horizontalAlignment: Text.AlignHCenter
                themeTransition: false
                color: "#FFFFFF"
            }
        }

        // indeterminate segmented bar
        Row {
            visible: !root.deviceMode
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -6
            spacing: 3
            Repeater {
                model: 28
                Rectangle {
                    readonly property int head: root.tick % 40
                    readonly property int dist: head - index
                    width: 8
                    height: 6
                    color: dist >= 0 && dist < 6 ? (dist === 0 ? "#FFFFFF" : root.neon) : MoneroComponents.Style.c("#1A00FF41")
                    opacity: dist >= 0 && dist < 6 ? 1 - dist * 0.14 : 1
                    border.width: 1
                    border.color: MoneroComponents.Style.c("#3300FF41")
                }
            }
        }

        MoneroComponents.TextPlain {
            visible: root.deviceMode && root.subText !== ""
            text: root.subText
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(implicitWidth, root.width - 60)
            Layout.topMargin: -10
            themeTransition: false
            color: MoneroComponents.Style.dimmedFontColor
        }

        // the address to compare with the one on the Trezor screen
        Rectangle {
            visible: root.deviceMode && root.addressText !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.width - 60
            Layout.preferredHeight: addressGroups.implicitHeight + 24
            radius: 6
            color: MoneroComponents.Style.blackTheme ? "#0A140C" : "#EEF6F0"
            border.color: Qt.rgba(MoneroComponents.Style.orange.r, MoneroComponents.Style.orange.g, MoneroComponents.Style.orange.b, 0.5)
            border.width: 1

            Text {
                id: addressGroups
                anchors.centerIn: parent
                width: parent.width - 28
                textFormat: Text.RichText
                text: root.groupedAddress(root.addressText)
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Text.AlignHCenter
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 18
                lineHeight: 1.3
            }
        }

        // gives up the wait if the Trezor does not respond
        Rectangle {
            visible: root.deviceMode
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -4
            Layout.preferredWidth: cancelText.implicitWidth + 48
            Layout.preferredHeight: 34
            color: cancelArea.containsMouse && !root.cancelling ? Qt.rgba(1, 0.17, 0.84, 0.15) : "transparent"
            border.width: 1
            border.color: root.cancelling ? "#555555" : (cancelArea.containsMouse ? root.magenta : root.neon)
            opacity: root.cancelling ? 0.6 : 1

            Text {
                id: cancelText
                anchors.centerIn: parent
                text: (root.cancelling ? qsTr("Cancelling...") : qsTr("Cancel")) + translationManager.emptyString
                color: "#FFFFFF"
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 12
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
            }
            MouseArea {
                id: cancelArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.cancelling
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cancelRequested()
            }
        }
    }
}
