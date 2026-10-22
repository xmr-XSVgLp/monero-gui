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
import "../components" as MoneroComponents

Rectangle {
    id: root
    visible: false
    z: 11
    radius: 14
    color: MoneroComponents.Style.blackTheme ? "#121917" : "#E7EBE8"
    border.color: MoneroComponents.Style.blackTheme ? "#35413B" : "#BAC5BE"
    implicitWidth: 460
    implicitHeight: contentHeight + 56
    Accessible.role: Accessible.Dialog
    Accessible.name: messageText

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


    function show() { root.visible = true; }
    function close() { root.visible = false; }

    MouseArea { anchors.fill: parent }

    ColumnLayout {
        id: rootLayout
        anchors.centerIn: parent
        width: Math.max(0, root.width - 56)
        spacing: 18

        RowLayout {
            visible: !root.deviceMode
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Image {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                source: "qrc:///images/logos/walletplus-logo.png"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            MoneroComponents.TextPlain {
                text: "XMR Wallet+"
                font.pixelSize: 17
                font.bold: true
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
        }

        MoneroComponents.TrezorDeviceAnim {
            visible: root.deviceMode
            running: false
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            MoneroComponents.TextPlain {
                id: messageTitle
                Layout.fillWidth: true
                text: qsTr("Please wait...") + translationManager.emptyString
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
                textFormat: Text.PlainText
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.deviceMode && root.deviceLabel !== "" ? root.deviceLabel : root.walletLabel
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
                textFormat: Text.PlainText
            }
        }

        // Activity indicator only; opening a wallet has no measurable percentage.
        Rectangle {
            Layout.fillWidth: true
            height: 3
            radius: 1.5
            color: MoneroComponents.Style.blackTheme ? "#2C3831" : "#CCD5CF"
            clip: true
            Rectangle {
                id: activity
                width: parent.width * 0.3
                height: parent.height
                radius: 1.5
                color: MoneroComponents.Style.orange
                SequentialAnimation on x {
                    running: root.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: -activity.width; to: activity.parent.width; duration: 1500; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 250 }
                }
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            visible: root.deviceMode && root.subText !== ""
            text: root.subText
            textFormat: Text.PlainText
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }
        Rectangle {
            visible: root.deviceMode && root.addressText !== ""
            Layout.fillWidth: true
            implicitHeight: addressGroups.implicitHeight + 24
            radius: 8
            color: MoneroComponents.Style.blackTheme ? "#1B2520" : "#D8E0DA"
            Text {
                id: addressGroups
                anchors.centerIn: parent
                width: parent.width - 24
                textFormat: Text.RichText
                text: root.groupedAddress(root.addressText)
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Text.AlignHCenter
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 16
                lineHeight: 1.3
            }
        }
        MoneroComponents.StandardButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.deviceMode
            enabled: !root.cancelling
            small: true
            primary: false
            text: (root.cancelling ? qsTr("Cancelling...") : qsTr("Cancel")) + translationManager.emptyString
            onClicked: root.cancelRequested()
        }
    }
}
