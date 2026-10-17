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

// Settings pages: key / value row inside a card. Label dimmed, value in mono, optional icon
// button on the right. The row is tinted on hover.
Item {
    id: row
    property string label: ""
    property string value: ""
    property bool mono: true
    property string actionIcon: ""
    property string actionTooltip: ""
    readonly property bool hovered: rowHover.containsMouse || actionButton.hovered
    readonly property color accent: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
    signal actionClicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(40, Math.max(labelText.implicitHeight, valueText.implicitHeight) + 18)

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 6
        lineOpacity: 0
        fillColor: row.accent
        fillOpacity: row.hovered ? 0.09 : 0.0
        ticks: false
        Behavior on fillOpacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 16

        MoneroComponents.TextPlain {
            id: labelText
            Layout.preferredWidth: 190
            Layout.maximumWidth: 190
            text: row.label
            wrapMode: Text.WordWrap
            color: MoneroComponents.Style.dimmedFontColor
            font.family: MoneroComponents.Style.fontRegular.name
            font.pixelSize: 13
            themeTransition: false
        }

        MoneroComponents.TextPlain {
            id: valueText
            Layout.fillWidth: true
            text: row.value
            wrapMode: Text.WrapAnywhere
            color: MoneroComponents.Style.defaultFontColor
            font.family: row.mono ? MoneroComponents.Style.fontMonoRegular.name : MoneroComponents.Style.fontRegular.name
            font.pixelSize: 13
            themeTransition: false
        }

        MoneroComponents.SettingsIconButton {
            id: actionButton
            visible: row.actionIcon !== ""
            icon: row.actionIcon
            tooltip: row.actionTooltip
            onClicked: row.actionClicked()
        }
    }
}
