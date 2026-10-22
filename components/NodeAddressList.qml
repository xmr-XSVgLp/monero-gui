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


// One editable list of "host:port" addresses for a monerod / wallet flag
// (Network configuration > Node addresses): title with the flag, help text, the list with
// "Remove" links and a field + "Add" button. The owner keeps the list (model) and does the work
// in addRequested / removeRequested; addRequested returns "" or the reason it was refused.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

ColumnLayout {
    id: list
    property string title: ""
    property string flag: ""
    property string help: ""
    property string warning: ""
    property var model: []
    property var isActive: function(address) { return true; }
    property var addRequested: function(address) { return ""; }
    property var removeRequested: function(address) {}

    readonly property bool dark: MoneroComponents.Style.blackTheme
    property string error: ""

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MoneroComponents.TextPlain {
            text: list.title
            font.pixelSize: 14
            font.bold: true
            color: MoneroComponents.Style.defaultFontColor
            themeTransition: false
        }
        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            text: list.flag
            font.family: MoneroComponents.Style.fontMonoRegular.name
            font.pixelSize: 12
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }
    }
    MoneroComponents.TextPlain {
        Layout.fillWidth: true
        visible: list.help !== ""
        wrapMode: Text.WordWrap
        text: list.help
        font.pixelSize: 12
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
    }
    MoneroComponents.TextPlain {
        Layout.fillWidth: true
        visible: list.warning !== ""
        wrapMode: Text.WordWrap
        text: list.warning
        font.pixelSize: 12
        color: list.dark ? "#FFC23D" : "#A86F00"
        themeTransition: false
    }

    Repeater {
        model: list.model
        delegate: RowLayout {
            Layout.fillWidth: true
            spacing: 12
            readonly property bool active: list.isActive(modelData)
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                elide: Text.ElideMiddle
                text: modelData
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                color: MoneroComponents.Style.defaultFontColor
                opacity: active ? 1 : 0.45
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                visible: !active
                text: qsTr("not used: its network is not in Send transactions") + translationManager.emptyString
                font.pixelSize: 11
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.rightMargin: 10
                text: qsTr("Remove") + translationManager.emptyString
                font.pixelSize: 12
                font.bold: true
                font.underline: removeMouse.containsMouse
                color: removeMouse.containsMouse ? (list.dark ? "#FF5C5C" : "#C62828") : MoneroComponents.Style.dimmedFontColor
                themeTransition: false
                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.removeRequested(modelData)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MoneroComponents.LineEdit {
            id: addressInput
            Layout.fillWidth: true
            inputPaddingTop: 0
            inputPaddingBottom: 0
            fontSize: 13
            placeholderFontSize: 13
            fontBold: false
            placeholderText: "host:port"
            onAccepted: list.add()
            onTextChanged: list.error = ""
        }
        MoneroComponents.StandardButton {
            small: true
            text: qsTr("Add") + translationManager.emptyString
            enabled: addressInput.text.trim() !== ""
            onClicked: list.add()
        }
    }
    MoneroComponents.TextPlain {
        Layout.fillWidth: true
        visible: list.error !== ""
        wrapMode: Text.WordWrap
        text: list.error
        font.pixelSize: 12
        color: list.dark ? "#FF5C5C" : "#C62828"
        themeTransition: false
    }

    function add() {
        var e = list.addRequested(addressInput.text);
        list.error = e || "";
        if (!e) addressInput.text = "";
    }
}
