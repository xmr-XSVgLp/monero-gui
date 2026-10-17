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
import QtQuick.Controls
import QtQuick.Layouts

import "../components" as MoneroComponents
import "effects/" as MoneroEffects

// Information / confirmation dialog: a centered card over the tinted (and blurred) window.
Rectangle {
    id: root
    color: "transparent"
    visible: false
    property alias title: card.title
    property alias text: dialogContent.text
    property alias content: root.text
    property alias cancelVisible: cancelButton.visible
    property alias okVisible: okButton.visible
    property alias textArea: dialogContent
    property alias okText: okButton.text
    property alias cancelText: cancelButton.text
    property alias closeVisible: closeButton.visible
    // picture: tx, tag, key, info, warning, node; empty = chosen from the title (error/warning or info)
    property string kind: ""
    readonly property bool dark: MoneroComponents.Style.blackTheme

    // same signals as Dialog has
    signal accepted()
    signal rejected()
    signal closeCallback();

    function _autoKind() {
        if (kind !== "")
            return kind;
        var t = (card.title || "").toLowerCase();
        var warn = [qsTr("Error"), qsTr("Warning"), "error", "warning"];
        for (var i = 0; i < warn.length; i++)
            if (t.indexOf(String(warn[i]).toLowerCase()) >= 0)
                return "warning";
        return "info";
    }

    function open() {
        // always over the whole window, also when declared inside a page
        if (Overlay.overlay && root.parent !== Overlay.overlay && root.parent !== appWindow.contentItem)
            root.parent = Overlay.overlay;
        root.z = 11
        card.kind = _autoKind();
        flickable.contentY = 0;
        root.visible = true;
        appWindow.modalDialogs++;
        root.forceActiveFocus();
    }

    function close() {
        if (root.visible)
            appWindow.modalDialogs = Math.max(0, appWindow.modalDialogs - 1);
        root.visible = false;
        kind = "";
        // reset button text
        okButton.text = qsTr("OK")
        cancelButton.text = qsTr("Cancel")

        closeCallback();
    }

    width: parent ? parent.width : 520
    height: parent ? parent.height : 380

    Keys.onEscapePressed: {
        root.close()
        root.rejected()
    }

    MoneroComponents.ModalTint { }

    MoneroComponents.ModalCard {
        id: card
        imageSize: 150

        Flickable {
            id: flickable
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(dialogContent.paintedHeight + 4, root.height * 0.55)
            contentWidth: width
            contentHeight: dialogContent.paintedHeight + 4
            clip: true
            ScrollBar.vertical: MoneroComponents.NeonScrollBar {
                onActiveChanged: if (!active && !isMac) active = true
                palette.mid: "#8E8E93"
                palette.dark: "#B8B8BD"
            }
            boundsBehavior: isMac ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds

            TextEdit {
                id: dialogContent
                width: flickable.width - 14
                renderType: Text.QtRendering
                font.family: MoneroComponents.Style.fontRegular.name
                textFormat: TextEdit.AutoText
                readOnly: true
                font.pixelSize: 14
                selectByMouse: false
                wrapMode: TextEdit.Wrap
                color: MoneroComponents.Style.defaultFontColor

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        appWindow.showStatusMessage(qsTr("Double tap to copy"),3)
                    }
                    onDoubleClicked: {
                        parent.selectAll()
                        parent.copy()
                        parent.deselect()
                        console.log("copied to clipboard");
                        appWindow.showStatusMessage(qsTr("Content copied to clipboard"),3)
                    }
                }
            }
        }

        // Cancel (grey) / OK (green)
        RowLayout {
            id: buttons
            Layout.topMargin: 6
            Layout.fillWidth: true
            spacing: 14

            Item { Layout.fillWidth: true }

            MoneroComponents.StandardButton {
                id: cancelButton
                small: true
                accent: root.dark ? "#8C8C8C" : "#6B6B6B"
                textColor: root.dark ? "#D0D0D0" : "#4A4A4A"
                text: qsTr("Cancel") + translationManager.emptyString
                onClicked: {
                    root.close()
                    root.rejected()
                }
            }

            MoneroComponents.StandardButton {
                id: okButton
                small: true
                accent: root.dark ? "#5FD08F" : "#1E8E4E"
                text: qsTr("OK") + translationManager.emptyString
                KeyNavigation.tab: cancelButton
                onClicked: {
                    root.close()
                    root.accepted()
                }
            }
        }
    }

    // close icon, top right corner of the card
    Rectangle {
        id: closeButton
        x: card.x + card.width - width - 6
        y: card.y + 6
        width: 36
        height: 36
        color: "transparent"

        MoneroEffects.ImageMask {
            anchors.centerIn: parent
            width: 14
            height: 14
            image: MoneroComponents.Style.titleBarCloseSource
            color: MoneroComponents.Style.defaultFontColor
            opacity: 0.75
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                root.close()
                root.rejected()
            }
            cursorShape: Qt.PointingHandCursor
            onEntered: closeButton.color = root.dark ? "#262626" : "#D8DED9";
            onExited: closeButton.color = "transparent";
        }
    }
}
