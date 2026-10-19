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

// The bundled Nym SDK helper owns this wallet's mixnet session.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

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
    readonly property string statusMessage: oshelper.nymClient.message || appWindow.nymVpnMessage
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

    onActiveChanged: if (active) nymWords.clear()
    onState_Changed: if (state_ === "off" || (state_ === "error" && nymWords.text === ""))
        nymWords.text = oshelper.nymClient.accountSettings().mnemonic || ""

    implicitHeight: column.implicitHeight

    readonly property bool needsInstall: !appWindow.nymClientAvailable

    Component.onCompleted: {
        if (!active) nymWords.text = oshelper.nymClient.accountSettings().mnemonic || "";
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
        fillColor: nymPanel.dark ? "#0C130E" : "#DADFDB"
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
                z: 1
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
                    text: "NYM MIXNET"
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: nymPanel.checked || nymPanel.hovered
                           ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    visible: nymPanel.active
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    text: qsTr("ID Dispositivo: ") + oshelper.nymClient.device
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: deviceMouse.containsMouse ? nymPanel.accent : MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                    Controls.ToolTip.visible: deviceMouse.containsMouse
                    Controls.ToolTip.text: oshelper.nymClient.device
                    MouseArea {
                        id: deviceMouse
                        objectName: "nymDeviceLink"
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appWindow.nymVpnOpenAccount()
                    }
                }
                Item { visible: !nymPanel.active; Layout.fillWidth: true }

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
                        id: nymRequiredLabel
                        // the "?" icon is drawn outside the text: keep room for it and keep it above the next items
                        Layout.rightMargin: 20
                        z: 2
                        text: qsTr("Nym required") + translationManager.emptyString
                        tooltipIconVisible: true
                        tooltip: qsTr("When checked, the app waits for its independent Nym client before connecting. A local node must be started with this proxy. The option is saved and Nym connects at startup.") + translationManager.emptyString
                        font.pixelSize: 14
                        font.bold: true
                        color: nymPanel.requiredTextColor
                        themeTransition: false

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: nymRequiredLabel.tooltipPopup.open()
                            onExited: nymRequiredLabel.tooltipPopup.close()
                            onClicked: persistentSettings.nymVpnRequired = !persistentSettings.nymVpnRequired
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: !nymPanel.active && nymPanel.state_ !== "working" && !nymPanel.needsInstall
                    enabled: nymPanel.state_ !== "working"
                    text: qsTr("Connect") + translationManager.emptyString
                    onClicked: {
                        appWindow.nymVpnConnect(nymWords.text);
                    }
                }

                // blue: reconnect with traffic blocked meanwhile
                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: nymPanel.active
                    enabled: nymPanel.state_ !== "working"
                    accent: nymPanel.dark ? "#3D8BFF" : "#1F5FD1"
                    textColor: nymPanel.dark ? "#CFE0FF" : "#1F5FD1"
                    text: qsTr("Reconnect") + translationManager.emptyString
                    onClicked: appWindow.nymVpnRestart()
                }

                MoneroComponents.StandardButton {
                    Layout.alignment: Qt.AlignVCenter
                    small: true
                    visible: nymPanel.active || nymPanel.state_ === "working"
                    enabled: true
                    accent: nymPanel.dark ? "#FF4D4D" : "#C62828"
                    textColor: nymPanel.dark ? "#FFD6D6" : "#C62828"
                    text: (nymPanel.state_ === "working" ? qsTr("Cancel") : qsTr("Disconnect")) + translationManager.emptyString
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
                    qsTr("The wallet uses its own Nym mixnet client. Connecting, reconnecting and disconnecting here do not control the official NymVPN app."),
                    qsTr("Reconnect closes this session and selects a random exit different from the previous node. Different nodes can share a public IP. If no alternative is found, traffic stays blocked."),
                    qsTr("The local node (monerod) is started with the Nym proxy too, so its peer connections also go through the mixnet; syncing is slower. If it was already running before Nym connected, stop and start it again."),
                    qsTr("Se requiere una cuenta NymVPN activa y sus 24 palabras. La wallet registra su propio dispositivo. Al conectar, las palabras se guardan automáticamente en Monero/xmr-wallet-plus/nym.conf, fuera del programa empaquetado.")
                ].join("<br><br>") + translationManager.emptyString
                       + (nymPanel.active && appWindow.nymVpnMessage !== ""
                          ? "<br><br>" + appWindow.nymVpnMessage : "")
            }

            MoneroComponents.TextPlain {
                visible: nymPanel.needsInstall
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("The bundled Nym client is missing. Rebuild the app with compilar-macos.sh.") + translationManager.emptyString
                color: nymPanel.stateColor
            }

            Controls.TextArea {
                id: nymWords
                FontMetrics { id: seedMetrics; font: nymWords.font }
                objectName: "nymSeedInput"
                clip: true
                Layout.fillWidth: true
                Layout.preferredHeight: 2 * seedMetrics.height + topPadding + bottomPadding
                // only to enter the phrase: hidden while (re)connecting and once an account is saved
                // (Connect still sends the saved phrase); shown again after an error to change it
                visible: !nymPanel.active && nymPanel.state_ !== "working"
                         && (!oshelper.nymClient.accountSaved || nymPanel.state_ === "error")
                enabled: nymPanel.state_ !== "working"
                placeholderText: qsTr("Las 24 palabras de tu cuenta NymVPN")
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 14
                color: MoneroComponents.Style.defaultFontColor
                placeholderTextColor: MoneroComponents.Style.dimmedFontColor
                selectionColor: MoneroComponents.Style.textSelectionColor
                padding: 12
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                background: MoneroComponents.NeonFrame {
                    cut: 6
                    ticks: false
                    accent: nymWords.activeFocus ? nymPanel.accent : nymPanel.border
                    lineOpacity: nymWords.activeFocus ? 0.9 : 0.35
                    fillColor: nymPanel.dark ? "#050806" : "#FFFFFF"
                    fillOpacity: 0.9
                }
            }

            // what happened last
            MoneroComponents.TextPlain {
                visible: nymPanel.statusMessage !== "" && !nymPanel.active && nymPanel.state_ !== "missing"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: nymPanel.statusMessage
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
