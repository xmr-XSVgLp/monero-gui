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


// Centered card used by the modal dialogs (password, labels, information...): neon frame,
// optional cypherpunk picture on the left, title, and the dialog's own content on the right.
// The dialog itself fills the window with a tint (main.qml blurs what is behind).

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

Item {
    id: card
    // tx, tag, key, info, warning, node; "" = no picture
    property string kind: "info"
    property string title: ""
    property int maxWidth: 760
    property int imageSize: 160
    default property alias content: body.data
    readonly property bool hasImage: kind !== ""
    readonly property int bodyWidth: width - 48 - (hasImage ? imageSize + 24 : 0)
    readonly property bool dark: MoneroComponents.Style.blackTheme

    function imageFor(k) {
        switch (k) {
        case "node": return "qrc:///images/node-encrypted.png";
        case "tx": return "qrc:///images/dlg-tx.png";
        case "tag": return "qrc:///images/dlg-tag.png";
        case "key": return "qrc:///images/dlg-key.png";
        case "warning": return "qrc:///images/dlg-warning.png";
        default: return "qrc:///images/dlg-info.png";
        }
    }

    width: Math.min(maxWidth, (parent ? parent.width : maxWidth) - 64)
    height: row.implicitHeight + 48
    anchors.centerIn: parent

    onVisibleChanged: if (visible) appear.restart()
    ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 160 }
        NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 14
        accent: card.kind === "warning" ? (card.dark ? "#FFC23D" : "#A86F00") : (card.dark ? "#E8ECE9" : "#2B3A30")
        lineOpacity: 0.6
        fillColor: card.dark ? "#0C130E" : "#DADFDB"
        fillOpacity: 0.98
        glow: 0.4
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 24

        Image {
            visible: card.hasImage
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: card.imageSize
            Layout.preferredHeight: card.imageSize
            source: card.hasImage ? card.imageFor(card.kind) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        ColumnLayout {
            Layout.preferredWidth: card.bodyWidth
            Layout.maximumWidth: card.bodyWidth
            Layout.alignment: Qt.AlignVCenter
            spacing: 14

            MoneroComponents.TextPlain {
                visible: card.title !== ""
                Layout.preferredWidth: card.bodyWidth
                text: card.title
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 16
                font.letterSpacing: 1.5
                font.capitalization: Font.AllUppercase
                wrapMode: Text.WordWrap
                color: card.kind === "warning" ? (card.dark ? "#FFD27A" : "#A86F00") : MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }

            ColumnLayout {
                id: body
                Layout.preferredWidth: card.bodyWidth
                Layout.maximumWidth: card.bodyWidth
                spacing: 12
            }
        }
    }
}
