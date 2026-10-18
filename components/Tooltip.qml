// Copyright (c) 2021-2024, The Monero Project
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
import QtQuick.Controls
import QtQuick.Layouts

import FontAwesome

import "." as MoneroComponents

Rectangle {
    property alias text: tooltip.text
    property alias tooltipPopup: popup
    property bool tooltipIconVisible: false
    property bool tooltipLeft: false
    property bool tooltipBottom: tooltipIconVisible ? false : true

    color: "transparent"
    height: tooltipIconVisible ? icon.height : parent.height
    width: tooltipIconVisible ? icon.width : parent.width
    visible: text != ""

    Text {
        id: icon
        visible: tooltipIconVisible
        color: MoneroComponents.Style.defaultFontColor
        font.family: FontAwesome.fontFamily
        font.pixelSize: 10
        font.styleName: "Regular"
        leftPadding: 5
        rightPadding: 5
        text: FontAwesome.questionCircle
        opacity: mouseArea.containsMouse ? 0.7 : 1

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.WhatsThisCursor
            onEntered: popup.open()
            onExited: popup.close()
        }
    }

    ToolTip {
        id: popup
        width: tooltip.width + leftPadding + rightPadding
        height: tooltip.height + topPadding + bottomPadding

        background: MoneroComponents.NeonFrame {
            cut: 7
            fillColor: MoneroComponents.Style.blackTheme ? "#000A02" : "#DEE3DF"
            fillOpacity: 0.96
            lineOpacity: 0.9
            glow: 0.45
        }
        closePolicy: Popup.NoAutoClose
        padding: 10
        x: tooltipLeft
            ? (tooltipIconVisible ? icon.x - icon.width : parent.x - tooltip.width - 20 + parent.width/2)
            : (tooltipIconVisible ? icon.x + icon.width : parent.x + parent.width/2)
        y: tooltipBottom
            ? (tooltipIconVisible ? icon.y + height : parent.y + parent.height + 2)
            : (tooltipIconVisible ? icon.y - height : parent.y - tooltip.height - 20)
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 120 }
        }
        onAboutToShow: typeIn.restart()

        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
        }
        delay: 200

        RowLayout {
            Layout.maximumWidth: 370

            Item {
                id: typeClip
                // typewriter reveal: the text is uncovered left to right, line by line feel
                property real reveal: 1
                implicitWidth: tooltip.implicitWidth
                implicitHeight: tooltip.implicitHeight
                Layout.preferredWidth: tooltip.width
                Layout.preferredHeight: tooltip.height
                clip: true

                Text {
                    id: tooltip
                    width: Math.min(implicitWidth, 370)
                    color: MoneroComponents.Style.defaultFontColor
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    textFormat: Text.RichText
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    // cover that slides away to the right
                    color: MoneroComponents.Style.blackTheme ? "#000A02" : "#DEE3DF"
                    x: tooltip.width * typeClip.reveal
                    width: tooltip.width + 12
                    height: parent.height
                    visible: typeClip.reveal < 1
                    Rectangle {
                        width: 7
                        height: Math.min(parent.height, 14)
                        color: MoneroComponents.Style.orange
                    }
                }

                NumberAnimation {
                    id: typeIn
                    target: typeClip
                    property: "reveal"
                    from: 0
                    to: 1
                    duration: Math.min(450, 120 + tooltip.text.length * 4)
                }
            }
        }
    }
}
