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

// Collapsible card in the style of the NYM VPN / advanced options panels:
// a header with chevron, title and a short summary on the right; the content shows when open.

import QtQuick
import QtQuick.Layouts
import FontAwesome

import "../components" as MoneroComponents

Item {
    id: card
    property bool checked: false
    property string title: ""
    property string icon: ""
    property color iconColor: MoneroComponents.Style.orange
    property string summary: ""
    // optional item shown instead of the summary text (e.g. icons)
    property Component summaryDelegate: null
    default property alias content: body.data

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    readonly property bool hovered: headerMouse.containsMouse

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 10
        accent: card.border
        lineOpacity: card.checked || card.hovered ? 0.6 : 0.25
        fillColor: card.dark ? "#0C130E" : "#DADFDB"
        fillOpacity: card.dark ? 0.92 : 0.9
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Canvas {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    rotation: card.checked ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    property color c: card.accent
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

                Text {
                    visible: card.icon !== ""
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 18
                    text: card.icon
                    font.family: FontAwesome.fontFamilySolid
                    font.styleName: "Solid"
                    font.pixelSize: 15
                    color: card.iconColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Accessible.ignored: true
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    text: card.title.toUpperCase()
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: card.checked || card.hovered
                           ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Loader {
                    active: card.summaryDelegate !== null
                    visible: active
                    sourceComponent: card.summaryDelegate
                }

                MoneroComponents.TextPlain {
                    visible: card.summaryDelegate === null
                    Layout.maximumWidth: card.width * 0.45
                    text: card.summary
                    elide: Text.ElideMiddle
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.checked = !card.checked
            }
        }

        Rectangle {
            visible: card.checked
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 1
            color: card.accent
            opacity: 0.3
        }

        ColumnLayout {
            id: body
            visible: card.checked
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.topMargin: 14
            spacing: 18
        }
    }
}
