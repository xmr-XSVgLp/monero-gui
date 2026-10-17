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

// Collapsible "NYM VPN" panel (same style as the advanced options panel of the wizard home).
// The account words go to the NymVPN daemon (nym-vpnc account set); the app itself never stores them.
// When connected, the app's SOCKS5 proxy setting points at the NymVPN mixnet proxy.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

Item {
    id: nymPanel
    property bool checked: false
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
    // box: same red as the Disconnect button; label: a softer red that is easier to read
    readonly property color requiredColor: dark ? "#FF4D4D" : "#C62828"
    readonly property color requiredTextColor: dark ? "#E08A8A" : "#B04848"
    readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
    readonly property bool hovered: headerMouse.containsMouse
    readonly property string state_: appWindow.nymVpnState
    readonly property bool active: state_ === "ready" || state_ === "connected"

    readonly property color stateColor: state_ === "connected" || state_ === "ready" ? (dark ? "#5FD08F" : "#1E8E4E")
                                      : state_ === "working" ? (dark ? "#FFC23D" : "#A86F00")
                                      : state_ === "error" || state_ === "missing" ? (dark ? "#FF5C5C" : "#C62828")
                                      : MoneroComponents.Style.dimmedFontColor
    readonly property string stateText: {
        switch (state_) {
        case "connected": return qsTr("Connected · mixnet") + translationManager.emptyString;
        case "ready": return qsTr("Active · mixnet") + translationManager.emptyString;
        case "working": return qsTr("Connecting…") + translationManager.emptyString;
        case "error": return qsTr("Error") + translationManager.emptyString;
        case "missing": return qsTr("Not installed") + translationManager.emptyString;
        default: return qsTr("Off") + translationManager.emptyString;
        }
    }

    implicitHeight: column.implicitHeight

    readonly property bool needsInstall: appWindow.nymVpncVersion !== "" && !appWindow.nymVpncOk

    Component.onCompleted: {
        appWindow.nymVpnCheckInstall();
        appWindow.nymVpnLoadDirectory();
    }
    // check again every time it is opened (it may have been installed meanwhile)
    onCheckedChanged: if (checked) {
        if (!active) appWindow.nymVpnCheckInstall();
        appWindow.nymVpnLoadDirectory();
    }

    MoneroComponents.NeonFrame {
        anchors.fill: parent
        cut: 10
        accent: nymPanel.border
        lineOpacity: nymPanel.checked ? 0.6 : (nymPanel.hovered ? 0.6 : 0.25)
        fillColor: nymPanel.dark ? "#0C130E" : "#EEF4EF"
        fillOpacity: nymPanel.dark ? 0.92 : 0.9
        ticks: false
        Behavior on lineOpacity { NumberAnimation { duration: 150 } }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // header row: chevron, title, state
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
                    rotation: nymPanel.checked ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    property color c: nymPanel.accent
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

                MoneroComponents.TextPlain {
                    text: "NYM VPN"
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: nymPanel.checked || nymPanel.hovered
                           ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: nymPanel.stateColor
                    SequentialAnimation on opacity {
                        running: nymPanel.state_ === "working"
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.opacity = 1
                        NumberAnimation { to: 0.2; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }

                MoneroComponents.TextPlain {
                    text: nymPanel.stateText
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: nymPanel.active ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: nymPanel.checked = !nymPanel.checked
            }
        }

        Rectangle {
            visible: nymPanel.checked
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 1
            color: nymPanel.accent
            opacity: 0.3
        }

        ColumnLayout {
            visible: nymPanel.checked
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.topMargin: 14
            spacing: 12

            // first line: Nym required and the connection buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // "Nym required": saved; blocks every connection outside NymVPN and connects at startup
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 8
                    spacing: 10

                    MoneroComponents.CheckBox {
                        id: nymRequiredBox
                        accent: nymPanel.requiredColor
                        checked: persistentSettings.nymVpnRequired
                        toggleOnClick: false
                        onClicked: persistentSettings.nymVpnRequired = !persistentSettings.nymVpnRequired
                        text: ""
                    }

                    // own label: CheckBox's label colour is reset by the theme transition
                    MoneroComponents.TextPlain {
                        text: qsTr("Nym required") + translationManager.emptyString
                        tooltipIconVisible: true
                        tooltip: qsTr("When checked, every connection of the app goes only through NymVPN: remote node, local node, prices, swaps and updates. If Nym is not connected, nothing goes out directly: those connections wait until Nym is up. The option is saved, and NymVPN connects automatically every time the app starts.") + translationManager.emptyString
                        font.pixelSize: 14
                        font.bold: true
                        color: nymPanel.requiredTextColor
                        themeTransition: false

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: persistentSettings.nymVpnRequired = !persistentSettings.nymVpnRequired
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: !nymPanel.active && !nymPanel.needsInstall
                    enabled: nymPanel.state_ !== "working"
                    text: qsTr("Connect") + translationManager.emptyString
                    onClicked: {
                        appWindow.nymVpnConnect(wordsInput.text);
                        wordsInput.text = "";
                    }
                }

                // blue: reconnect with traffic blocked meanwhile
                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: persistentSettings.nymVpnEnabled && (nymPanel.active || nymPanel.state_ === "error" || appWindow.nymVpnRestarting)
                    enabled: nymPanel.state_ !== "working"
                    accent: nymPanel.dark ? "#3D8BFF" : "#1F5FD1"
                    textColor: nymPanel.dark ? "#CFE0FF" : "#1F5FD1"
                    text: qsTr("Restart") + translationManager.emptyString
                    onClicked: appWindow.nymVpnRestart()
                }

                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: nymPanel.active || (persistentSettings.nymVpnEnabled && nymPanel.state_ === "error")
                    enabled: nymPanel.state_ !== "working"
                    accent: nymPanel.dark ? "#FF4D4D" : "#C62828"
                    textColor: nymPanel.dark ? "#FFD6D6" : "#C62828"
                    text: qsTr("Disconnect") + translationManager.emptyString
                    onClicked: appWindow.nymVpnDisconnect()
                }
            }

            // second line: one text, one help
            MoneroComponents.Label {
                Layout.topMargin: 0
                Layout.rightMargin: 24
                text: qsTr("Traffic and privacy · random exit") + translationManager.emptyString
                fontSize: 13
                tooltipIconVisible: true
                tooltip: [
                    qsTr("All of this app's traffic (remote or local node, prices, swaps and updates) goes through the Nym mixnet, using the SOCKS5 proxy of NymVPN. The rest of your Mac is not affected."),
                    qsTr("NymVPN picks the exit node at random. The app asks for a new route every time it starts and when you press Restart, so the public IP changes."),
                    qsTr("The local node (monerod) is started with the Nym proxy too, so its peer connections also go through the mixnet; syncing is slower. If it was already running before Nym connected, stop and start it again."),
                    qsTr("It needs NymVPN installed with its command line client (nym-vpnc) and an account with credit.")
                ].join("<br><br>") + translationManager.emptyString
                       + (nymPanel.active && appWindow.nymVpnMessage !== ""
                          ? "<br><br>" + appWindow.nymVpnMessage : "")
            }

            // nym-vpnc missing or too old: how to install it
            Rectangle {
                visible: nymPanel.needsInstall
                Layout.fillWidth: true
                implicitHeight: installCol.implicitHeight + 28
                color: nymPanel.dark ? "#14FFC23D" : "#14A86F00"
                border.width: 1
                border.color: nymPanel.dark ? "#66FFC23D" : "#66A86F00"

                ColumnLayout {
                    id: installCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 10

                    MoneroComponents.Label {
                        Layout.topMargin: 0
                        Layout.rightMargin: 24
                        text: qsTr("Installation help") + translationManager.emptyString
                        fontSize: 13
                        tooltipIconVisible: true
                        tooltip: (appWindow.nymVpncVersion === "none"
                                  ? qsTr("The NymVPN command line client (nym-vpnc %1) is not installed.").arg(appWindow.nymVpncRequired)
                                  : qsTr("Your nym-vpnc is version %1; version %2 or newer is needed.").arg(appWindow.nymVpncVersion).arg(appWindow.nymVpncRequired))
                                 + "<br><br>" + [
                                     qsTr("Open the NymVPN %1 download page with the button below.").arg(appWindow.nymVpncRequired),
                                     qsTr("In the macOS section, download nym-vpnc-%1.pkg (and NymVPN-%1.pkg too if you don't have the NymVPN app).").arg(appWindow.nymVpncRequired),
                                     qsTr("Open the downloaded .pkg and follow the installer (it asks for your Mac password)."),
                                     qsTr("Come back here and press \"Check again\".")
                                 ].join("<br><br>") + translationManager.emptyString
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        MoneroComponents.StandardButton {
                            small: true
                            text: qsTr("Open download page") + translationManager.emptyString
                            onClicked: Qt.openUrlExternally("https://github.com/nymtech/nym-vpn-client/releases/tag/nym-vpn-v" + appWindow.nymVpncRequired)
                        }
                        MoneroComponents.StandardButton {
                            small: true
                            text: qsTr("Check again") + translationManager.emptyString
                            onClicked: appWindow.nymVpnCheckInstall()
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            MoneroComponents.LineEditMulti {
                id: wordsInput
                visible: !nymPanel.active && !nymPanel.needsInstall
                Layout.fillWidth: true
                labelText: qsTr("Recovery phrase of your NymVPN account") + translationManager.emptyString
                labelFontSize: 14
                placeholderText: qsTr("Leave empty to use the account already set in NymVPN") + translationManager.emptyString
                placeholderFontSize: 14
                fontSize: 14
                wrapMode: Text.WordWrap
                pasteButton: true
            }

            MoneroComponents.TextPlain {
                visible: wordsInput.visible && wordsInput.text.trim() !== ""
                text: qsTr("%1 words").arg(wordsInput.text.trim().split(/\s+/).length) + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            // what happened last
            MoneroComponents.TextPlain {
                visible: appWindow.nymVpnMessage !== "" && !nymPanel.active && nymPanel.state_ !== "missing"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: appWindow.nymVpnMessage
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                color: nymPanel.state_ === "error" ? nymPanel.stateColor : MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }

            // route: entry node -> exit node -> public IP
            Rectangle {
                visible: nymPanel.active
                Layout.fillWidth: true
                implicitHeight: routeGrid.implicitHeight + 24
                color: nymPanel.dark ? "#08FFFFFF" : "#08000000"
                border.width: 1
                border.color: Qt.rgba(nymPanel.border.r, nymPanel.border.g, nymPanel.border.b, 0.15)

                GridLayout {
                    id: routeGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    columns: 3
                    columnSpacing: 14
                    rowSpacing: 8

                    Repeater {
                        model: [
                            { label: qsTr("Entry node") + translationManager.emptyString,
                              value: appWindow.nymVpnDescribeGateway(appWindow.nymVpnEntryId), id: appWindow.nymVpnEntryId },
                            { label: qsTr("Exit node") + translationManager.emptyString,
                              value: appWindow.nymVpnDescribeGateway(appWindow.nymVpnExitId), id: appWindow.nymVpnExitId },
                            { label: qsTr("New IP") + translationManager.emptyString,
                              value: appWindow.nymVpnIp, id: appWindow.nymVpnIpPlace }
                        ]
                        delegate: RowLayout {
                            Layout.columnSpan: 3
                            Layout.fillWidth: true
                            spacing: 14
                            MoneroComponents.TextPlain {
                                Layout.preferredWidth: 110
                                Layout.alignment: Qt.AlignTop
                                text: modelData.label
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 0.8
                                font.capitalization: Font.AllUppercase
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: modelData.value !== "" ? modelData.value : (index === 2 && appWindow.nymVpnInfoLoading ? "…" : "—")
                                    font.family: MoneroComponents.Style.fontMonoMedium.name
                                    font.pixelSize: 14
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }
                                MoneroComponents.TextPlain {
                                    // always takes its line so the panel keeps its height while refreshing
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                    text: modelData.id !== "" && modelData.id !== modelData.value ? modelData.id : " "
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 11
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                            }
                        }
                    }
                }

                MoneroComponents.StandardButton {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    small: true
                    // always clickable: a new lookup replaces one that is still running
                    text: (appWindow.nymVpnInfoLoading ? "… " : "") + qsTr("Refresh") + translationManager.emptyString
                    onClicked: appWindow.nymVpnLoadInfo()
                }
            }

            MoneroComponents.Label {
                visible: nymPanel.active && appWindow.nymVpnRouteNote !== ""
                Layout.topMargin: 0
                Layout.rightMargin: 24
                text: qsTr("Route details") + translationManager.emptyString
                fontSize: 12
                tooltipIconVisible: true
                tooltip: appWindow.nymVpnRouteNote
            }
        }
    }
}
