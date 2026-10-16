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
import "." as MoneroComponents

// Cypherpunk tab bar: chamfered neon frame, active tab lit with an underline glow.
Item {
    id: navbar
    default property list<MoneroComponents.NavbarItem> items
    property alias currentIndex: repeater.currentIndex
    property alias previousIndex: repeater.previousIndex

    readonly property color accent: MoneroComponents.Style.orange
    readonly property color ink: MoneroComponents.Style.blackTheme ? "#000000" : "#FFFFFF"
    property int textMargin: appWindow.width < 890 ? 28 : 52

    height: 34
    width: row.width
    implicitHeight: height
    implicitWidth: width

    Canvas {
        id: frame
        anchors.fill: parent
        property color lineColor: Qt.rgba(navbar.accent.r, navbar.accent.g, navbar.accent.b, 0.6)
        onLineColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            var c = 9, w = width, h = height;
            ctx.reset();
            ctx.beginPath();
            ctx.moveTo(c + 0.5, 0.5);
            ctx.lineTo(w - 0.5, 0.5);
            ctx.lineTo(w - 0.5, h - c - 0.5);
            ctx.lineTo(w - c - 0.5, h - 0.5);
            ctx.lineTo(0.5, h - 0.5);
            ctx.lineTo(0.5, c + 0.5);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(navbar.accent.r, navbar.accent.g, navbar.accent.b, 0.05);
            ctx.fill();
            ctx.lineWidth = 1;
            ctx.strokeStyle = lineColor;
            ctx.stroke();
            ctx.fillStyle = lineColor;
            ctx.fillRect(w - 6, 2.5, 3, 1);
            ctx.fillRect(3, h - 3.5, 3, 1);
        }
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: navbar.accent
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowBlur: 0.5
            shadowOpacity: 0.3
        }
    }

    Row {
        id: row
        height: parent.height

        Repeater {
            id: repeater
            model: items.length
            property int currentIndex: 0
            property int previousIndex: 0

            Item {
                id: tab
                property bool active: items[index].active
                visible: items[index].visible
                height: row.height
                width: visible ? Math.max(72, label.implicitWidth + navbar.textMargin) : 0

                // separator
                Rectangle {
                    visible: index > 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: parent.height - 14
                    color: Qt.rgba(navbar.accent.r, navbar.accent.g, navbar.accent.b, 0.3)
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    visible: tab.active || tabArea.containsMouse
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(navbar.accent.r, navbar.accent.g, navbar.accent.b, tab.active ? 0.22 : 0.1) }
                    }
                }

                Rectangle {
                    visible: tab.active
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 16
                    height: 2
                    color: navbar.accent
                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: true
                        shadowEnabled: true
                        shadowColor: navbar.accent
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        shadowBlur: 0.6
                        shadowOpacity: 0.9
                    }
                }

                MoneroComponents.TextPlain {
                    id: label
                    anchors.centerIn: parent
                    font.family: MoneroComponents.Style.fontMonoBold.name
                    font.pixelSize: 13
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2
                    text: items[index].text
                    color: tab.active || tabArea.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        repeater.previousIndex = repeater.currentIndex;
                        repeater.currentIndex = index;
                        items[index].selected()
                    }
                }
            }
        }
    }
}
