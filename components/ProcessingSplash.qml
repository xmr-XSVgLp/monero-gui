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
    color: MoneroComponents.Style.blackTheme ? "black" : "white"
    visible: false
    radius: 10
    border.color: MoneroComponents.Style.orange
    border.width: 2
    z: 11
    property alias messageText: messageTitle.text
    property bool deviceMode: false     // waiting for a confirmation on the Trezor
    property string subText: ""
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
            Layout.preferredHeight: 80

            Image {
                id: imgLogo
                width: 60
                height: 60
                sourceSize: Qt.size(width, height)
                anchors.centerIn: parent
                source: "qrc:///images/monero-vector.svg"
                mipmap: true
            }

            BusyIndicator {
                running: root.visible && !root.deviceMode
                anchors.centerIn: imgLogo
                contentItem: Image {
                    visible: parent.running
                    source: "qrc:///images/busy-indicator.png"
                    RotationAnimator on rotation {
                        running: root.visible && !root.deviceMode
                        loops: Animation.Infinite
                        duration: 1000
                        from: 0
                        to: 360
                    }
                }
            }
        }


        MoneroComponents.TextPlain {
            id: messageTitle
            text: qsTr("Please wait...") + translationManager.emptyString
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Layout.fillWidth: true
            themeTransition: false
            color: MoneroComponents.Style.defaultFontColor
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
    }
}
