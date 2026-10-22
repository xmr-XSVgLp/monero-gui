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

import "." as MoneroComponents

// Settings > Node: the remote node list in the card style. One card row per node (selected node
// lit, with a bar on the left), edit / remove buttons on the right, "add" row at the end.
// Same model and actions as RemoteNodeList (remoteNodesModel, remoteNodeDialog).
ColumnLayout {
    id: remoteNodeList
    spacing: 8
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"

    Repeater {
        model: remoteNodesModel

        Item {
            id: nodeRow
            readonly property bool selected: index === remoteNodesModel.selected
            readonly property bool hovered: nodeMouse.containsMouse || editButton.hovered || removeButton.hovered
            readonly property var trusted: remoteNodesModel.get(index) ? remoteNodesModel.get(index).trusted : false
            // Tor on / I2P required / I2P off for an .i2p node: cannot be used now (main.qml remoteNodeAllowed)
            readonly property string blockedText: (persistentSettings.torEnabled, persistentSettings.netWallet, persistentSettings.i2pEnabled,
                                                   persistentSettings.netTx, appWindow.remoteNodeBlockedText(address))
            readonly property bool blockedByTor: blockedText !== ""
            Layout.fillWidth: true
            implicitHeight: 44
            opacity: blockedByTor ? 0.4 : 1

            MoneroComponents.CardPanel {
                anchors.fill: parent
                cut: 8
                hovered: nodeRow.hovered && !nodeRow.selected
                selected: nodeRow.selected
            }

            Rectangle {
                visible: nodeRow.selected
                anchors.left: parent.left
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height - 16
                radius: 1
                color: remoteNodeList.accent
            }

            MouseArea {
                id: nodeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: remoteNodesModel.applyRemoteNode(index)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 10

                // selected marker
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    color: nodeRow.selected ? remoteNodeList.accent : "transparent"
                    border.width: 1
                    border.color: nodeRow.selected ? remoteNodeList.accent : MoneroComponents.Style.dimmedFontColor
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    text: address + (nodeRow.blockedByTor ? "  ·  " + nodeRow.blockedText : "")
                    elide: Text.ElideMiddle
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 14
                    color: nodeRow.selected || nodeRow.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
                    themeTransition: false
                }

                MoneroComponents.Label {
                    id: trustedDaemonCheckMark
                    Layout.topMargin: 0
                    visible: nodeRow.trusted
                    fontSize: 13
                    fontFamily: FontAwesome.fontFamilySolid
                    styleName: "Solid"
                    fontColor: nodeRow.selected ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    text: FontAwesome.shieldAlt
                    tooltip: qsTr("Trusted daemon") + translationManager.emptyString
                    themeTransition: false
                }

                MoneroComponents.SettingsIconButton {
                    id: editButton
                    icon: FontAwesome.edit
                    tooltip: qsTr("Edit remote node") + translationManager.emptyString
                    onClicked: remoteNodeDialog.edit(remoteNodesModel.get(index), function (remoteNode) {
                        remoteNodesModel.set(index, remoteNode)
                        if (index === remoteNodesModel.selected) {
                            remoteNodesModel.applyRemoteNode(index)
                        }
                    })
                }

                MoneroComponents.SettingsIconButton {
                    id: removeButton
                    visible: remoteNodesModel.count > 1
                    icon: FontAwesome.times
                    tooltip: qsTr("Remove remote node") + translationManager.emptyString
                    onClicked: remoteNodesModel.removeSelectNextIfNeeded(index)
                }
            }
        }
    }

    // add a node
    Item {
        id: addRow
        readonly property bool hovered: addMouse.containsMouse
        Layout.fillWidth: true
        implicitHeight: 44

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 8
            accent: remoteNodeList.border
            lineOpacity: addRow.hovered ? 0.6 : 0.2
            fillColor: remoteNodeList.accent
            fillOpacity: addRow.hovered ? 0.08 : 0.0
            ticks: false
            Behavior on lineOpacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: remoteNodeDialog.add(remoteNodesModel.append)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
                text: FontAwesome.plus
                font.family: FontAwesome.fontFamilySolid
                font.styleName: "Solid"
                font.pixelSize: 11
                color: remoteNodeList.accent
            }

            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                text: qsTr("Add remote node") + translationManager.emptyString
                font.family: MoneroComponents.Style.fontMedium.name
                font.pixelSize: 14
                color: addRow.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
                themeTransition: false
            }
        }
    }
}
