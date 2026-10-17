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
import QtQuick.Layouts
import QtQuick.Effects

import FontAwesome

import "../components" as MoneroComponents

// Cypherpunk button: chamfered neon frame, glow, monospace caps, scanline sweep on hover.
Item {
    id: button
    property bool fontAwesomeIcon: false
    property bool primary: true
    property string rightIcon: ""
    property string rightIconInactive: ""
    property color textColor: primary ? MoneroComponents.Style.textAccent : MoneroComponents.Style.buttonSecondaryTextColor;
    property bool small: false
    property alias text: label.text
    property alias fontBold: label.font.bold
    property int fontSize: {
        if(small) return 12.5;
        else return 14.5;
    }
    property alias label: label
    property alias tooltip: tooltip.text
    property alias tooltipLeft: tooltip.tooltipLeft
    property alias tooltipPopup: tooltip.tooltipPopup
    signal clicked()

    property color accent: MoneroComponents.Style.orange
    readonly property color ink: MoneroComponents.Style.blackTheme ? "#000000" : "#FFFFFF"
    readonly property bool hovered: button.enabled && (buttonArea.containsMouse || button.focus)
    readonly property bool lit: hovered || buttonArea.pressed
    readonly property int cut: small ? 7 : 9

    height: small ?  30 : 36
    width: buttonLayout.width + 32
    implicitHeight: height
    implicitWidth: width

    function doClick(){
        if (typeof appWindow !== "undefined" && appWindow.playFx) appWindow.playFx("click");
        releaseFocus();
        clicked();
    }

    Item {
        id: body
        anchors.fill: parent
        opacity: button.enabled ? 1 : 0.4
        scale: buttonArea.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 80 } }

        Canvas {
            id: frame
            anchors.fill: parent
            property color fillColor: button.lit
                ? button.accent
                : Qt.rgba(button.accent.r, button.accent.g, button.accent.b, button.primary ? 0.12 : 0.0)
            property color lineColor: button.primary || button.lit
                ? button.accent
                : Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.55)
            onFillColorChanged: requestPaint()
            onLineColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                var c = button.cut, w = width, h = height;
                ctx.reset();
                ctx.beginPath();
                ctx.moveTo(c + 0.5, 0.5);
                ctx.lineTo(w - 0.5, 0.5);
                ctx.lineTo(w - 0.5, h - c - 0.5);
                ctx.lineTo(w - c - 0.5, h - 0.5);
                ctx.lineTo(0.5, h - 0.5);
                ctx.lineTo(0.5, c + 0.5);
                ctx.closePath();
                ctx.fillStyle = fillColor;
                ctx.fill();
                ctx.lineWidth = 1;
                ctx.strokeStyle = lineColor;
                ctx.stroke();
                // corner ticks
                ctx.fillStyle = lineColor;
                ctx.fillRect(w - 6, 2.5, 3, 1);
                ctx.fillRect(3, h - 3.5, 3, 1);
            }

            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                blurMax: 24
                shadowEnabled: true
                shadowColor: button.accent
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                shadowBlur: button.lit ? 1.0 : 0.6
                shadowOpacity: button.lit ? 0.9 : (button.primary ? 0.35 : 0.0)
            }
        }

        // scanline sweeping across while hovered
        Item {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            visible: button.hovered
            Rectangle {
                id: scan
                width: 28
                height: parent.height
                opacity: 0.35
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: button.ink }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                NumberAnimation on x {
                    from: -scan.width
                    to: button.width
                    duration: 900
                    loops: Animation.Infinite
                    running: button.hovered
                }
            }
        }

        RowLayout {
            id: buttonLayout
            height: button.height
            spacing: 8
            anchors.centerIn: parent

            MoneroComponents.TextPlain {
                id: label
                font.family: MoneroComponents.Style.fontMonoBold.name
                font.bold: true
                font.pixelSize: button.fontSize
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2
                color: button.lit ? button.ink : button.textColor
                visible: text !== ""
                themeTransition: false
            }

            // blinking terminal cursor
            Item {
                Layout.alignment: Qt.AlignVCenter
                visible: label.visible
                implicitWidth: button.small ? 6 : 7
                implicitHeight: label.font.pixelSize
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    color: button.lit ? button.ink : button.textColor
                    visible: button.hovered
                    SequentialAnimation on opacity {
                        running: button.hovered
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 450 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 450 }
                    }
                }
            }

            Image {
                visible: !fontAwesomeIcon && button.rightIcon !== ""
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                width: button.small ? 16 : 20
                height: button.small ? 16 : 20
                source: {
                    if (fontAwesomeIcon) return "";
                    if(button.rightIconInactive !== "" && !button.enabled) {
                        return button.rightIconInactive;
                    }
                    return button.rightIcon;
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                color: button.lit ? button.ink : button.textColor
                font.family: FontAwesome.fontFamilySolid
                font.pixelSize: button.small ? 16 : 20
                font.styleName: "Solid"
                text: button.rightIcon
                visible: fontAwesomeIcon && button.rightIcon !== ""
            }
        }
    }

    MoneroComponents.Tooltip {
        id: tooltip
        anchors.fill: parent
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: doClick()
        onEntered: tooltip.text ? tooltip.tooltipPopup.open() : ""
        onExited: tooltip.text ? tooltip.tooltipPopup.close() : ""
        cursorShape: Qt.PointingHandCursor
    }

    Keys.enabled: button.visible
    Keys.onSpacePressed: doClick()
    Keys.onEnterPressed: doClick()
    Keys.onReturnPressed: doClick()
}
