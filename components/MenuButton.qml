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

import "../components" as MoneroComponents
import "effects/" as MoneroEffects

Rectangle {
    id: button
    property alias text: label.text
    property bool checked: false
    property alias symbol: symbolText.text
    property int numSelectedChildren: 0
    property var under: null
    signal clicked()

    // Monero orange instead of the theme accent (Trading data / Swaps)
    property bool moneroOrange: false
    // blue for the Trading section (Trading data / Swaps / Notes)
    property bool blueAccent: false
    readonly property color accent: blueAccent ? "#3B9EFF" : moneroOrange ? "#FF6600" : MoneroComponents.Style.orange
    readonly property bool hovered: buttonArea.containsMouse

    function doClick() {
        // Android workaround
        releaseFocus();
        clicked();
    }

    function getOffset() {
        var offset = 0
        var item = button
        while (item.under) {
            offset += 20
            item = item.under
        }
        return offset
    }

    color: "transparent"
    property bool present: !under || under.checked || checked || under.numSelectedChildren > 0
    height: present ? ((appWindow.height >= 800) ? 44  : 38 ) : 0

    // Subtle cypherpunk highlight: neon wash, thin chamfered outline, faint scanline on hover
    Item {
        id: highlight
        visible: GraphicsInfo.api !== GraphicsInfo.Software && (button.checked || button.hovered)
        anchors.fill: parent
        anchors.leftMargin: 12 + button.getOffset()
        anchors.rightMargin: 8
        anchors.topMargin: 3
        anchors.bottomMargin: 3

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(button.accent.r, button.accent.g, button.accent.b, button.checked ? 0.16 : 0.08) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Canvas {
            id: outline
            anchors.fill: parent
            visible: button.checked
            property color lineColor: Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.35)
            onLineColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                var c = 7, w = width, h = height;
                ctx.reset();
                ctx.beginPath();
                ctx.moveTo(c + 0.5, 0.5);
                ctx.lineTo(w - 0.5, 0.5);
                ctx.lineTo(w - 0.5, h - c - 0.5);
                ctx.lineTo(w - c - 0.5, h - 0.5);
                ctx.lineTo(0.5, h - 0.5);
                ctx.lineTo(0.5, c + 0.5);
                ctx.closePath();
                ctx.lineWidth = 1;
                ctx.strokeStyle = lineColor;
                ctx.stroke();
            }
        }

        Item {
            anchors.fill: parent
            clip: true
            visible: button.hovered && !button.checked
            Rectangle {
                id: scan
                width: 40
                height: parent.height
                opacity: 0.12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: button.accent }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                NumberAnimation on x {
                    from: -scan.width
                    to: highlight.width
                    duration: 1400
                    loops: Animation.Infinite
                    running: button.hovered && !button.checked
                }
            }
        }
    }

    // fallback hover effect for the software renderer
    Rectangle {
        visible: GraphicsInfo.api === GraphicsInfo.Software && (button.checked || buttonArea.containsMouse)
        anchors.fill: parent
        color: MoneroComponents.Style.menuButtonFallbackBackgroundColor
        opacity: button.checked ? 1 : 0.3
    }

    // active indicator: neon bar just left of the highlight frame
    Rectangle {
        visible: button.checked
        x: 4 + button.getOffset() - 2
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: parent.height - 6
        color: Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.25)
        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: parent.height
            color: button.accent
        }
    }

    // button decorations that are subject to leftMargin offsets
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 20
        height: parent.height
        width: 2
        color: "transparent"

        // button text
        MoneroComponents.TextPlain {
            id: label
            color: button.blueAccent ? (MoneroComponents.Style.blackTheme ? (button.checked ? "#B8DCFF" : "#6CB8FF") : "#1565C0")
                 : button.moneroOrange ? (MoneroComponents.Style.blackTheme ? (button.checked ? "#FFB27A" : "#FF8A3D") : "#D95700")
                 : button.checked ? MoneroComponents.Style.textAccent : MoneroComponents.Style.menuButtonTextColor
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.letterSpacing: 0.5
            // the theme fade would paint the coloured labels grey
            themeTransition: !button.blueAccent && !button.moneroOrange
            themeTransitionBlackColor: MoneroComponents.Style._b_menuButtonTextColor
            themeTransitionWhiteColor: MoneroComponents.Style._w_menuButtonTextColor
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.right
            anchors.leftMargin: button.getOffset() + 8
            font.bold: true
            font.pixelSize: 14
        }
    }

    // menu button right arrow
    MoneroEffects.ImageMask {
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: parent.getOffset()
        anchors.right: parent.right
        anchors.rightMargin: 20
        height: 14
        width: 8
        image: MoneroComponents.Style.menuButtonImageRightSource
        color: button.checked ? MoneroComponents.Style.menuButtonImageRightColorActive : MoneroComponents.Style.menuButtonImageRightColor
        opacity: button.checked ? 0.8 : 0.25
    }

    MoneroComponents.TextPlain {
        id: symbolText
        anchors.right: parent.right
        anchors.rightMargin: 44
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 12
        font.bold: true
        color: MoneroComponents.Style.menuButtonTextColor
        visible: appWindow.ctrlPressed
        themeTransition: false
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if(parent.checked)
                return
            button.doClick()
            parent.checked = true
        }
    }

    transform: Scale {
        yScale: button.present ? 1 : 0

        Behavior on yScale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    Behavior on height {
        SequentialAnimation {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    Behavior on checked {
        // we get the value of checked before the change
        ScriptAction { script: if (under) under.numSelectedChildren += checked > 0 ? -1 : 1 }
    }
}
