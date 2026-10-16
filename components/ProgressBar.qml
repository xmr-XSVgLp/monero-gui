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
import moneroComponents.Wallet 1.0

import "../components" as MoneroComponents

Rectangle {
    id: item
    property int fillLevel: 0
    property string syncType // Wallet or Daemon
    property string syncText: qsTr("%1 blocks remaining: ").arg(syncType)
    visible: false
    color: "transparent"

    function updateProgress(currentBlock,targetBlock, blocksToSync, statusTxt){
        if(targetBlock > 0) {
            var remaining = (currentBlock < targetBlock) ? targetBlock - currentBlock : 0
            var progressLevel = (blocksToSync > 0 ) ? (100*(blocksToSync - remaining)/blocksToSync).toFixed(0) : 100
            fillLevel = progressLevel
            if(typeof statusTxt != "undefined" && statusTxt != "") {
                progressText.text = statusTxt;
                progressTextValue.text = "";
            } else {
                progressText.text = syncText;
                progressTextValue.text = remaining.toFixed(0);
            }
        }
    }

    Item {
        anchors.top: item.top
        anchors.topMargin: 10
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        anchors.fill: parent

        MoneroComponents.TextPlain {
            id: progressText
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: progressTextValue.left
            anchors.rightMargin: 6
            elide: Text.ElideRight
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 11
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.5
            color: MoneroComponents.Style.defaultFontColor
            text: qsTr("Synchronizing %1").arg(syncType) + translationManager.emptyString
            height: 18
            themeTransition: false
        }

        MoneroComponents.TextPlain {
            id: progressTextValue
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.right: parent.right
            font.family: MoneroComponents.Style.fontMonoBold.name
            font.pixelSize: 11
            color: MoneroComponents.Style.textAccent
            height: 18
            themeTransition: false
        }

        Item {
            id: bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: progressText.bottom
            anchors.topMargin: 3
            height: 12

            readonly property color accent: MoneroComponents.Style.orange
            readonly property int segW: 4
            readonly property int gap: 2
            readonly property int count: Math.max(1, Math.floor((segments.width + gap) / (segW + gap)))
            readonly property int lit: Math.round(count * Math.max(0, Math.min(100, fillLevel)) / 100)

            Text {
                id: lb
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "["
                color: MoneroComponents.Style.textAccent
                font.family: MoneroComponents.Style.fontMonoBold.name
                font.pixelSize: 13
            }

            Text {
                id: pct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: ("  " + fillLevel).slice(-3) + "%"
                color: MoneroComponents.Style.textAccent
                font.family: MoneroComponents.Style.fontMonoBold.name
                font.pixelSize: 11
            }

            Text {
                id: rb
                anchors.right: pct.left
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: "]"
                color: MoneroComponents.Style.textAccent
                font.family: MoneroComponents.Style.fontMonoBold.name
                font.pixelSize: 13
            }

            Item {
                id: segments
                anchors.left: lb.right
                anchors.leftMargin: 3
                anchors.right: rb.left
                anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                clip: true

                Row {
                    spacing: bar.gap
                    Repeater {
                        model: bar.count
                        Rectangle {
                            width: bar.segW
                            height: segments.height
                            color: bar.accent
                            opacity: index < bar.lit ? (index === bar.lit - 1 ? 1.0 : 0.85) : 0.13
                        }
                    }
                }

                // light sweep over the filled part
                Rectangle {
                    id: sweep
                    width: 22
                    height: parent.height
                    visible: bar.lit > 0 && bar.lit < bar.count && item.visible
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: MoneroComponents.Style.blackTheme ? "#CCFFFFFF" : "#99FFFFFF" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    NumberAnimation on x {
                        running: sweep.visible
                        loops: Animation.Infinite
                        from: -sweep.width
                        to: bar.lit * (bar.segW + bar.gap)
                        duration: 1400
                    }
                }
            }
        }
    }
}
