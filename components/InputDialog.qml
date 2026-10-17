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
import QtQuick.Controls
import QtQuick.Layouts

import "../components" as MoneroComponents

// Text input dialog (labels of transactions, addresses and accounts, page jump, restore height):
// a centered card over the blurred window.
Item {
    id: root
    visible: false
    property alias labelText: label.text
    property alias inputText: input.text
    // picture: tag (labels, default), info, tx...
    property string kind: "tag"
    readonly property bool dark: MoneroComponents.Style.blackTheme

    // same signals as Dialog has
    signal accepted()
    signal rejected()

    function open(prepopulate) {
        leftPanel.enabled = false
        middlePanel.enabled = false
        titleBar.state = "essentials"
        root.visible = true;
        input.focus = true;
        input.text = prepopulate ? prepopulate : "";
        input.selectAll();
    }

    function close() {
        leftPanel.enabled = true
        middlePanel.enabled = true
        titleBar.state = "default"
        root.visible = false;
        kind = "tag";
    }

    MoneroComponents.ModalTint { }

    MoneroComponents.ModalCard {
        id: card
        kind: root.kind
        maxWidth: 680
        imageSize: 140

        Label {
            id: label
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 16
            font.family: MoneroComponents.Style.fontRegular.name
            color: MoneroComponents.Style.defaultFontColor
        }

        MoneroComponents.Input {
            id : input
            focus: true
            Layout.topMargin: 2
            Layout.fillWidth: true
            horizontalAlignment: TextInput.AlignLeft
            verticalAlignment: TextInput.AlignVCenter
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 20
            KeyNavigation.tab: okButton
            bottomPadding: 10
            leftPadding: 12
            topPadding: 10
            color: MoneroComponents.Style.defaultFontColor
            selectionColor: MoneroComponents.Style.textSelectionColor
            selectedTextColor: MoneroComponents.Style.textSelectedColor

            background: MoneroComponents.NeonFrame {
                cut: 6
                ticks: false
                accent: input.activeFocus ? (root.dark ? "#5FD08F" : "#1E8E4E") : (root.dark ? "#E8ECE9" : "#2B3A30")
                lineOpacity: input.activeFocus ? 0.9 : 0.4
                fillColor: root.dark ? "#050806" : "#FFFFFF"
                fillOpacity: 0.9
            }

            Keys.enabled: root.visible
            function acceptInput() {
                root.close()
                root.accepted()
            }

            Keys.onEnterPressed: acceptInput()
            Keys.onReturnPressed: {
                acceptInput()
            }
            Keys.onEscapePressed: {
                root.close()
                root.rejected()
            }
        }

        // Cancel (grey) / OK (green)
        RowLayout {
            id: buttons
            spacing: 14
            Layout.topMargin: 8
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            MoneroComponents.StandardButton {
                id: cancelButton
                small: true
                accent: root.dark ? "#8C8C8C" : "#6B6B6B"
                textColor: root.dark ? "#D0D0D0" : "#4A4A4A"
                text: qsTr("Cancel") + translationManager.emptyString
                KeyNavigation.tab: input
                onClicked: {
                    root.close()
                    root.rejected()
                }
            }
            MoneroComponents.StandardButton {
                id: okButton
                small: true
                accent: root.dark ? "#5FD08F" : "#1E8E4E"
                text: qsTr("Ok") + translationManager.emptyString
                KeyNavigation.tab: cancelButton
                onClicked: {
                    root.close()
                    root.accepted()
                }
            }
        }
    }
}
