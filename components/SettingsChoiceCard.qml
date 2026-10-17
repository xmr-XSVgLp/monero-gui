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

import FontAwesome

import "../components" as MoneroComponents

// Settings pages: selectable option card (e.g. local / remote node). Selected = lit border,
// green tint, bar on the left and a filled marker in the top right corner.
Item {
    id: choice
    property string iconText: ""
    property string title: ""
    property string description: ""
    property bool selected: false
    readonly property bool hovered: choiceMouse.containsMouse
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(96, contentRow.implicitHeight + 32)

    MoneroComponents.CardPanel {
        anchors.fill: parent
        cut: 12
        hovered: choice.hovered && !choice.selected
        selected: choice.selected
    }

    Rectangle {
        visible: choice.selected
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 28
        radius: 1
        color: choice.accent
    }

    MouseArea {
        id: choiceMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: choice.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: choice.clicked()
    }

    RowLayout {
        id: contentRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 18
        anchors.rightMargin: 16
        spacing: 14

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 7
                accent: choice.border
                lineOpacity: choice.selected ? 0.8 : (choice.hovered ? 0.6 : 0.3)
                fillColor: choice.accent
                fillOpacity: choice.selected ? 0.2 : 0.05
                ticks: false
            }

            Text {
                anchors.centerIn: parent
                text: choice.iconText
                font.family: FontAwesome.fontFamilySolid
                font.styleName: "Solid"
                font.pixelSize: 17
                color: choice.selected || choice.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    text: choice.title
                    elide: Text.ElideRight
                    color: MoneroComponents.Style.defaultFontColor
                    font.family: MoneroComponents.Style.fontMedium.name
                    font.pixelSize: 16
                    themeTransition: false
                }

                // radio marker
                Item {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16

                    MoneroComponents.NeonFrame {
                        anchors.fill: parent
                        cut: 4
                        accent: choice.selected ? choice.accent : choice.border
                        lineOpacity: choice.selected ? 1.0 : 0.45
                        fillOpacity: 0
                        ticks: false
                    }

                    Rectangle {
                        visible: choice.selected
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        color: choice.accent
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: choice.description
                color: MoneroComponents.Style.dimmedFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                lineHeight: 1.1
            }
        }
    }
}
