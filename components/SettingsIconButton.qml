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

import FontAwesome

import "../components" as MoneroComponents

// Settings pages: small chamfered icon button (FontAwesome solid glyph) with an optional tooltip.
Item {
    id: btn
    property string icon: ""
    property string tooltip: ""
    readonly property bool hovered: btnMouse.containsMouse
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    signal clicked()

    implicitWidth: 28
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 6
        accent: btn.border
        lineOpacity: btn.hovered ? 0.9 : 0.3
        fillColor: btn.accent
        fillOpacity: btn.hovered ? 0.22 : 0.0
        glow: btn.hovered ? 0.4 : 0.0
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 120 } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.icon
        font.family: FontAwesome.fontFamilySolid
        font.styleName: "Solid"
        font.pixelSize: 12
        color: btn.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
    }

    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
        onEntered: if (btn.tooltip) tip.tooltipPopup.open()
        onExited: tip.tooltipPopup.close()
    }

    MoneroComponents.Tooltip {
        id: tip
        anchors.fill: parent
        tooltipLeft: true
        text: btn.tooltip
    }
}
