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
import QtQuick.Effects
import QtQuick.Layouts

import "../components" as MoneroComponents

// Wizard menu entry drawn as a card, like the Account page: chamfered panel, icon,
// title + description and a chevron. Hover lights the border; the whole card is clickable.
Item {
    id: rowlayout
    Layout.fillWidth: true
    Layout.bottomMargin: 10
    property alias imageIcon: icon.source
    property bool checkbox: false
    property alias checked: checkboxItem.checked
    property alias headerText: header.text
    property alias bodyText: body.text
    signal menuClicked();

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    readonly property bool hovered: mouse.containsMouse || rowlayout.activeFocus

    implicitHeight: Math.max(84, content.implicitHeight + 28)

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 12
        accent: rowlayout.border
        lineOpacity: rowlayout.hovered ? 0.85 : 0.28
        fillColor: rowlayout.dark ? "#0C130E" : "#EEF4EF"
        fillOpacity: rowlayout.dark ? 0.92 : 0.9
        glow: rowlayout.hovered ? 0.3 : 0.0
        ticks: rowlayout.hovered
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }

    // green tint on hover
    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 12
        lineOpacity: 0
        fillColor: rowlayout.accent
        fillOpacity: rowlayout.hovered ? 0.10 : 0.0
        ticks: false
        Behavior on fillOpacity { NumberAnimation { duration: 150 } }
    }

    // hover: bar on the left
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 24
        radius: 1
        color: rowlayout.accent
        opacity: rowlayout.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 18
        spacing: 16

        Item {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56

            MoneroComponents.CheckBox {
                id: checkboxItem
                anchors.centerIn: parent
                toggleOnClick: false
                visible: rowlayout.checkbox
            }

            Image {
                id: icon
                visible: !rowlayout.checkbox && (GraphicsInfo.api === GraphicsInfo.Software || MoneroComponents.Style.blackTheme)
                anchors.centerIn: parent
                width: 56
                height: 56
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                source: ""
                scale: rowlayout.hovered ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            MultiEffect {
                visible: !rowlayout.checkbox && (GraphicsInfo.api !== GraphicsInfo.Software && !MoneroComponents.Style.blackTheme)
                anchors.fill: icon
                source: icon
                scale: icon.scale
                shadowEnabled: true
                shadowHorizontalOffset: 3
                shadowVerticalOffset: 3
                shadowBlur: 0.625
                blurMax: 16
                shadowColor: "#1E000000"
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 4

            MoneroComponents.TextPlain {
                id: header
                Layout.fillWidth: true
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontMedium.name
                font.pixelSize: wizardController.layoutScale == 4 ? 15 : wizardController.layoutScale == 3 ? 18 : 19
                wrapMode: Text.WordWrap
                themeTransition: false
            }

            MoneroComponents.TextPlain {
                id: body
                Layout.fillWidth: true
                visible: text !== ""
                color: MoneroComponents.Style.dimmedFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: wizardController.layoutScale <= 2 ? 15 : 13
                wrapMode: Text.WordWrap
                themeTransition: false
            }
        }

        // chevron
        Canvas {
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            Layout.leftMargin: 4
            property color c: rowlayout.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
            onCChanged: requestPaint()
            transform: Translate { x: rowlayout.hovered ? 3 : 0; Behavior on x { NumberAnimation { duration: 150 } } }
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = c;
                ctx.lineWidth = 1.8;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(4, 2); ctx.lineTo(10, 7); ctx.lineTo(4, 12);
                ctx.stroke();
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // only a real click: the page must not be scrolling and the item must not have moved
        // under the cursor between press and release (e.g. a panel below changed height)
        property real pressSceneY: 0
        property bool pressOk: false
        function pageMoving() {
            return typeof wizardFlickable !== "undefined" && wizardFlickable && wizardFlickable.moving;
        }
        onPressed: {
            pressSceneY = rowlayout.mapToItem(null, 0, 0).y;
            pressOk = !pageMoving();
        }
        onCanceled: pressOk = false
        onClicked: {
            var moved = Math.abs(rowlayout.mapToItem(null, 0, 0).y - pressSceneY) > 2;
            if (pressOk && !moved && !pageMoving())
                rowlayout.menuClicked();
            pressOk = false;
        }
    }
}
