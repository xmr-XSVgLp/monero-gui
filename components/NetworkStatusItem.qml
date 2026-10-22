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

import moneroComponents.Wallet 1.0
import "../components" as MoneroComponents

Rectangle {
    id: item
    color: "transparent"
    property var connected: Wallet.ConnectionStatus_Disconnected

    function getConnectionStatusString(status) {
        switch (appWindow.daemonStartStopInProgress)
        {
            case 1:
                return qsTr("Starting the node");
            case 2:
                return qsTr("Stopping the node");
            default:
                break;
        }
        switch (status) {
            case Wallet.ConnectionStatus_Connected:
                if (!appWindow.daemonSynced)
                    return qsTr("Synchronizing");
                if (persistentSettings.useRemoteNode && persistentSettings.allowRemoteNodeMining && appWindow.isMining)
                    return qsTr("Remote node") + " + " + qsTr("Mining");
                if (persistentSettings.useRemoteNode)
                    return qsTr("Remote node");
                return appWindow.isMining ? qsTr("Connected") + " + " + qsTr("Mining"): qsTr("Connected");
            case Wallet.ConnectionStatus_WrongVersion:
                return qsTr("Wrong version");
            case Wallet.ConnectionStatus_Disconnected:
                if (appWindow.walletMode <= 1) {
                    return qsTr("Searching node") + translationManager.emptyString;
                }
                return qsTr("Disconnected");
            case Wallet.ConnectionStatus_Connecting:
                return qsTr("Connecting");
            default:
                return qsTr("Invalid connection status");
        }
    }

    RowLayout {
        Layout.preferredHeight: 40

        Item {
            id: iconItem
            width: 40
            height: 40
            opacity: {
                if(!appWindow.isMining || item.connected == Wallet.ConnectionStatus_Connected){
                    return 1
                } else {
                    MoneroComponents.Style.blackTheme ? 0.5 : 0.3
                }
            }

            // node beacon: hex frame with a core that pulses when connected,
            // a rotating dashed frame while connecting/syncing and a crossed-out core when offline
            Item {
                id: beacon
                visible: !appWindow.isMining
                width: 28
                height: 28
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 6

                readonly property color accent: MoneroComponents.Style.orange
                readonly property color offColor: MoneroComponents.Style.dimmedFontColor
                // 0 = offline, 1 = busy (starting/connecting/syncing), 2 = online
                readonly property int status: {
                    if (appWindow.daemonStartStopInProgress > 0) return 1;
                    if (item.connected == Wallet.ConnectionStatus_Connecting) return 1;
                    if (item.connected == Wallet.ConnectionStatus_Connected) return appWindow.daemonSynced ? 2 : 1;
                    return 0;
                }
                // blue = connected, yellow = connecting/syncing, red = disconnected
                readonly property bool dark: MoneroComponents.Style.blackTheme
                readonly property color tint: status === 2 ? (dark ? "#2F9BFF" : "#1565C0")
                                            : status === 1 ? (dark ? "#FFD400" : "#B08900")
                                            : (dark ? "#FF3B3B" : "#C62828")

                Repeater {
                    model: 2
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: width / 2
                        color: "transparent"
                        border.color: beacon.tint
                        border.width: 1.5
                        visible: beacon.status === 2
                        opacity: 0
                        SequentialAnimation on opacity {
                            running: beacon.status === 2 && beacon.visible
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 900 }
                            NumberAnimation { from: 0.8; to: 0; duration: 1800 }
                        }
                        SequentialAnimation on scale {
                            running: beacon.status === 2 && beacon.visible
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 900 }
                            NumberAnimation { from: 1; to: 3.4; duration: 1800; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Canvas {
                    id: hex
                    anchors.fill: parent
                    property color c: beacon.tint
                    property int st: beacon.status
                    onCChanged: requestPaint()
                    onStChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        var cx = width / 2, cy = height / 2, r = width / 2 - 2;
                        ctx.reset();
                        ctx.lineWidth = 1.5;
                        ctx.strokeStyle = c;
                        ctx.beginPath();
                        for (var k = 0; k < 6; k++) {
                            var a = Math.PI / 3 * k - Math.PI / 2;
                            var x = cx + r * Math.cos(a), y = cy + r * Math.sin(a);
                            if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.closePath();
                        if (st === 1) ctx.setLineDash([3, 3]);
                        ctx.stroke();
                        ctx.setLineDash([]);
                        // core
                        ctx.beginPath();
                        ctx.arc(cx, cy, 4, 0, 2 * Math.PI);
                        if (st === 0) {
                            ctx.lineWidth = 1.5;
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(cx - 6, cy + 6);
                            ctx.lineTo(cx + 6, cy - 6);
                            ctx.stroke();
                        } else {
                            ctx.fillStyle = c;
                            ctx.fill();
                        }
                    }
                    RotationAnimator on rotation {
                        running: beacon.status === 1 && beacon.visible
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 2400
                    }
                    rotation: 0
                    Connections {
                        target: beacon
                        function onStatusChanged() { if (beacon.status !== 1) hex.rotation = 0 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: appWindow.walletMode >= 2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        middlePanel.settingsView.settingsStateViewState = "Node";
                        appWindow.showPageRequest("Settings");
                    }
                }
            }

            Image {
                visible: appWindow.isMining
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.right: parent.right
                anchors.rightMargin: 0
                source: "qrc:///images/icons/miningxmr.png"
                MouseArea {
                    anchors.fill: parent
                    visible: appWindow.walletMode >= 2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appWindow.showPageRequest("Mining")
                }
            }
        }

        Item {
            height: 40
            width: 260

            MoneroComponents.TextPlain {
                id: statusText
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 0
                font.family: MoneroComponents.Style.fontMedium.name
                font.bold: true
                font.pixelSize: 13
                color: MoneroComponents.Style.blackTheme ? MoneroComponents.Style.dimmedFontColor : MoneroComponents.Style.defaultFontColor
                opacity: MoneroComponents.Style.blackTheme ? 0.65 : 0.75
                text: qsTr("Network status") + translationManager.emptyString
                themeTransition: false
            }

            MoneroComponents.TextPlain {
                id: statusTextVal
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 14
                font.family: MoneroComponents.Style.fontMedium.name
                font.pixelSize: 20
                color: MoneroComponents.Style.defaultFontColor
                text: getConnectionStatusString(item.connected) + translationManager.emptyString
                opacity: MoneroComponents.Style.blackTheme ? 1.0 : 0.7
                themeTransition: false

                MouseArea {
                    anchors.fill: parent
                    visible: appWindow.walletMode >= 2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if(!appWindow.isMining) {
                            middlePanel.settingsView.settingsStateViewState = "Node";
                            appWindow.showPageRequest("Settings");
                        } else {
                            appWindow.showPageRequest("Mining")
                        }
                    }
                }
            }

            MoneroComponents.TextPlain {
                anchors.left: statusTextVal.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: refreshMouseArea.containsMouse ?  MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                font.family: FontAwesome.fontFamilySolid
                font.pixelSize: 24
                font.styleName: "Solid"
                opacity: 0.85
                text: FontAwesome.random
                themeTransition: false
                tooltip: qsTr("Switch to another public remote node") + translationManager.emptyString;
                visible: (
                    !appWindow.disconnected &&
                    !persistentSettings.useRemoteNode &&
                    (persistentSettings.bootstrapNodeAddress == "auto" || persistentSettings.walletMode < 2)
                )

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    visible: true
                    onEntered: parent.tooltipPopup.open()
                    onExited: parent.tooltipPopup.close()
                    onClicked: {
                        const callback = function(result) {
                            refreshMouseArea.visible = true;
                            if (result) {
                                appWindow.showStatusMessage(qsTr("Successfully switched to another public node"), 3);
                                appWindow.currentWallet.refreshHeightAsync();
                            } else {
                                appWindow.showStatusMessage(qsTr("Failed to switch public node"), 3);
                            }
                        };

                        daemonManager.sendCommandAsync(
                            ["set_bootstrap_daemon", "auto"],
                            appWindow.currentWallet.nettype,
                            persistentSettings.blockchainDataDir,
                            callback);

                        refreshMouseArea.visible = false;
                        appWindow.showStatusMessage(qsTr("Switching to another public node"), 3);
                    }
                }
            }
        }
    }
}
