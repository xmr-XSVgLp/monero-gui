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

// Settings pages: one action as a card row (icon, title + description, shortcut, chevron).
// The whole row is clickable and lights up on hover.
Item {
    id: settingsListItem
    property alias iconText: iconLabel.text
    property alias symbol: symbolText.text
    property alias description: area.text
    property alias title: header.text
    property bool isLast: false
    readonly property bool hovered: rowMouse.containsMouse && enabled
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(60, textColumn.implicitHeight + 24)
    opacity: enabled ? 1 : 0.4

    MoneroComponents.CardPanel {
        anchors.fill: parent
        cut: 9
        hovered: settingsListItem.hovered
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: settingsListItem.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (settingsListItem.enabled) settingsListItem.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 16
        spacing: 14

        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 6
                accent: settingsListItem.border
                lineOpacity: settingsListItem.hovered ? 0.7 : 0.3
                fillColor: settingsListItem.accent
                fillOpacity: settingsListItem.hovered ? 0.18 : 0.05
                ticks: false
            }

            Text {
                id: iconLabel
                anchors.centerIn: parent
                font.family: FontAwesome.fontFamilySolid
                font.styleName: "Solid"
                font.pixelSize: 15
                color: settingsListItem.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
            }
        }

        ColumnLayout {
            id: textColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            MoneroComponents.TextPlain {
                id: header
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontMedium.name
                font.pixelSize: 15
                themeTransition: false
            }

            Text {
                id: area
                Layout.fillWidth: true
                visible: text !== ""
                color: MoneroComponents.Style.dimmedFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                lineHeight: 1.1
            }
        }

        // keyboard shortcut, shown while Ctrl is held
        MoneroComponents.TextPlain {
            id: symbolText
            visible: appWindow.ctrlPressed && text !== ""
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 12
            color: MoneroComponents.Style.defaultFontColor
            themeTransition: false
        }

        Canvas {
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            Layout.rightMargin: settingsListItem.hovered ? 0 : 3
            Behavior on Layout.rightMargin { NumberAnimation { duration: 150 } }
            property color c: settingsListItem.accent
            onCChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = c;
                ctx.lineWidth = 1.8;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(3.5, 1.5); ctx.lineTo(8.5, 6); ctx.lineTo(3.5, 10.5);
                ctx.stroke();
            }
        }
    }
}
