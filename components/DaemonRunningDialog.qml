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


// "Local node is running" when closing the app: a small card over a dimmed window
// (instead of the full-window StandardDialog), with the encrypted node picture.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

Item {
    id: dlg
    anchors.fill: parent
    visible: false
    z: 9000

    property var onStopCallback
    property var onKeepCallback
    readonly property bool dark: MoneroComponents.Style.blackTheme

    function open(stopCallback, keepCallback) {
        onStopCallback = stopCallback;
        onKeepCallback = keepCallback;
        visible = true;
        appear.restart();
        dlg.forceActiveFocus();
    }

    function close() { visible = false; }

    function finish(callback) {
        close();
        if (callback)
            callback();
    }

    // Esc: don't close the app
    Keys.onEscapePressed: close()

    // the window behind is blurred by main.qml (like the loading splash); this only tints it
    // and swallows clicks outside the card
    Rectangle {
        anchors.fill: parent
        color: dlg.dark ? "#59000000" : "#40000000"
        MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: function(w) { w.accepted = true } }
    }

    Item {
        id: card
        width: Math.min(800, dlg.width - 48)
        height: cardRow.implicitHeight + 48
        anchors.centerIn: parent
        opacity: 0
        scale: 0.96

        ParallelAnimation {
            id: appear
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 14
            accent: dlg.dark ? "#E8ECE9" : "#2B3A30"
            lineOpacity: 0.6
            fillColor: dlg.dark ? "#0C130E" : "#DADFDB"
            fillOpacity: 0.98
            glow: 0.4
        }

        RowLayout {
            id: cardRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 22

            Image {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 180
                Layout.preferredHeight: 180
                source: "qrc:///images/node-encrypted.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            ColumnLayout {
                id: textCol
                // explicit width so the texts wrap inside the card instead of running past it
                Layout.preferredWidth: card.width - 48 - 180 - 22
                Layout.maximumWidth: card.width - 48 - 180 - 22
                Layout.alignment: Qt.AlignVCenter
                spacing: 12

                MoneroComponents.TextPlain {
                    Layout.preferredWidth: textCol.Layout.preferredWidth
                    text: qsTr("Local node is running") + translationManager.emptyString
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 16
                    font.letterSpacing: 1.5
                    font.capitalization: Font.AllUppercase
                    wrapMode: Text.WordWrap
                    color: MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    Layout.preferredWidth: textCol.Layout.preferredWidth
                    text: qsTr("Do you want to stop local node or keep it running in the background?") + translationManager.emptyString
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    color: MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    Layout.preferredWidth: textCol.Layout.preferredWidth
                    text: qsTr("Kept running, it stays in sync and the wallet opens faster next time.")
                          + (persistentSettings.nymVpnEnabled ? " " + qsTr("NymVPN stays connected too, so the node keeps syncing through Nym.") : "")
                          + translationManager.emptyString
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                RowLayout {
                    Layout.topMargin: 8
                    Layout.fillWidth: true
                    spacing: 14

                    MoneroComponents.StandardButton {
                        small: true
                        accent: dlg.dark ? "#FF4D4D" : "#C62828"
                        textColor: dlg.dark ? "#FFD6D6" : "#C62828"
                        text: qsTr("Force stop") + translationManager.emptyString
                        onClicked: dlg.finish(dlg.onStopCallback)
                    }

                    MoneroComponents.StandardButton {
                        small: true
                        accent: dlg.dark ? "#5FD08F" : "#1E8E4E"
                        text: qsTr("Keep it running") + translationManager.emptyString
                        onClicked: dlg.finish(dlg.onKeepCallback)
                    }

                    Item { Layout.fillWidth: true }

                    // grey: back to the app without closing it
                    MoneroComponents.StandardButton {
                        small: true
                        accent: dlg.dark ? "#8C8C8C" : "#6B6B6B"
                        textColor: dlg.dark ? "#D0D0D0" : "#4A4A4A"
                        text: qsTr("Cancel") + translationManager.emptyString
                        onClicked: dlg.close()
                    }
                }
            }
        }
    }
}
