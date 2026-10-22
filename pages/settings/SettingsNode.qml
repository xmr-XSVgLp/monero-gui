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
import QtQuick.Controls

import FontAwesome

import "../../js/Utils.js" as Utils
import "../../components" as MoneroComponents
import "../../components/effects" as MoneroEffects

Rectangle{
    color: "transparent"
    Layout.fillWidth: true
    property alias nodeHeight: root.height

    // local / remote node toggle: icon + name, selected = lit frame and green tint; the description in a tooltip
    component NodeTypeButton: Item {
        id: typeButton
        property string kind: "local"
        property string label: ""
        property string tip: ""
        property bool selected: false
        readonly property bool hovered: typeArea.containsMouse
        readonly property color accent: MoneroComponents.Style.blackTheme ? "#3DDC84" : "#2E7D4A"
        signal clicked()
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: typeRow.implicitWidth + 30
        implicitHeight: 52

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 9
            accent: typeButton.selected ? typeButton.accent : (MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30")
            lineOpacity: typeButton.selected ? 0.9 : (typeButton.hovered ? 0.6 : 0.3)
            fillColor: typeButton.accent
            fillOpacity: typeButton.selected ? 0.14 : (typeButton.hovered ? 0.05 : 0.0)
            glow: typeButton.selected ? 0.25 : 0.0
            ticks: false
        }
        Row {
            id: typeRow
            anchors.centerIn: parent
            spacing: 10
            MoneroComponents.NodeTypeIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                kind: typeButton.kind
                accent: typeButton.accent
                lit: typeButton.selected || typeButton.hovered
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: typeButton.label
                color: typeButton.selected || typeButton.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                font.family: MoneroComponents.Style.fontMedium.name
                font.pixelSize: 15
            }
        }
        MoneroComponents.Tooltip {
            id: typeTip
            anchors.fill: parent
            text: typeButton.tip
        }
        MouseArea {
            id: typeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: typeButton.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
            onEntered: typeTip.tooltipPopup.open()
            onExited: typeTip.tooltipPopup.close()
            onClicked: { typeTip.tooltipPopup.close(); typeButton.clicked(); }
        }
    }


    /* main layout */
    ColumnLayout {
        id: root
        anchors.margins: 20
        anchors.topMargin: 0

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right

        spacing: 12

        //! Manage pricing
        readonly property bool fiatRatesConsentNeeded: persistentSettings.fiatPriceCurrency !== "xmrusd" && !persistentSettings.fiatRatesConsentGiven

        // ---- Network configuration (shared with the welcome page)
        MoneroComponents.NetworkConfigCard {
            Layout.fillWidth: true
        }


        // node choice and settings: only in advanced mode (the simple modes pick the node themselves)
        ColumnLayout {
            Layout.fillWidth: true
            visible: appWindow.walletMode >= 2
            spacing: 12

            // one folding card: start/stop on the left, local / remote choice on the right (details in tooltips),
            // then the remote node list (remote) or the peers, monerod command and connection test
            MoneroComponents.CollapsibleCard {
                icon: FontAwesome.server
                title: qsTr("Node") + translationManager.emptyString
                summary: persistentSettings.useRemoteNode
                         ? qsTr("Remote node") + " · " + remoteNodesModel.currentRemoteNode().address + translationManager.emptyString
                         : qsTr("Local node") + " · " + (appWindow.daemonRunning ? qsTr("running") : qsTr("stopped")) + translationManager.emptyString
                checked: persistentSettings.nodeCardOpen
                onCheckedChanged: persistentSettings.nodeCardOpen = checked

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 16
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // red while it can stop the daemon, yellow and locked while starting or stopping
                        MoneroComponents.StandardButton {
                            readonly property int busy: appWindow.daemonStartStopInProgress
                            readonly property color busyColor: MoneroComponents.Style.blackTheme ? "#FFD60A" : "#B8860B"
                            visible: !persistentSettings.useRemoteNode
                            Layout.alignment: Qt.AlignVCenter
                            small: true
                            enabled: busy === 0
                            disabledOpacity: 1
                            accent: busy !== 0 ? busyColor : appWindow.daemonRunning ? (MoneroComponents.Style.blackTheme ? "#FF4D4D" : "#C62828") : MoneroComponents.Style.orange
                            textColor: busy !== 0 ? busyColor : appWindow.daemonRunning ? (MoneroComponents.Style.blackTheme ? "#FFD6D6" : "#C62828") : MoneroComponents.Style.textAccent
                            text: (busy === 1 ? qsTr("Starting…") : busy === 2 ? qsTr("Stopping…") : appWindow.daemonRunning ? qsTr("Stop daemon") : qsTr("Start daemon")) + translationManager.emptyString
                            onClicked: {
                                if (busy !== 0)
                                    return;
                                if (appWindow.daemonRunning) {
                                    appWindow.stopDaemon(function() {});
                                } else {
                                    persistentSettings.daemonFlags = daemonFlags.text;
                                    appWindow.startDaemon(persistentSettings.daemonFlags);
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        NodeTypeButton {
                            id: localNodeChoice
                            visible: !isAndroid
                            kind: "local"
                            label: qsTr("Local node") + translationManager.emptyString
                            tip: qsTr("The blockchain is downloaded to your computer. Provides higher security and requires more local storage.") + translationManager.emptyString
                            selected: !persistentSettings.useRemoteNode
                            onClicked: {
                                if (persistentSettings.useRemoteNode) {
                                    persistentSettings.useRemoteNode = false;
                                    appWindow.disconnectRemoteNode();
                                }
                            }
                        }

                        NodeTypeButton {
                            id: remoteNodeChoice
                            kind: "remote"
                            label: qsTr("Remote node") + translationManager.emptyString
                            tip: qsTr("Uses a third-party server to connect to the Monero network. Less secure, but easier on your computer.") + translationManager.emptyString
                            selected: persistentSettings.useRemoteNode
                            onClicked: {
                                if (!persistentSettings.useRemoteNode) {
                                    appWindow.connectRemoteNode();
                                }
                            }
                        }
                    }

                    // remote node choice right under the Local / Remote buttons: the same manager as Security > Nodes
                    MoneroComponents.RemoteNodeManager {
                        Layout.fillWidth: true
                        visible: persistentSettings.useRemoteNode
                        showNotes: false
                    }

                    // external IPs of the local node (same list as Security > Connections)
                    MoneroComponents.NodePeers {
                        visible: !persistentSettings.useRemoteNode && appWindow.daemonRunning
                        Layout.fillWidth: true
                        showTitle: true
                    }

                    // full monerod command line (read from ps while it runs, else the last one started here)
                    ColumnLayout {
                        id: daemonCommand
                        property string text: ""
                        property bool preview: false     // monerod is not running: the command the next start will use
                        visible: text !== ""
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 6
                        // remote node mode: only a monerod that is really running (left running, or started by hand)
                        function refresh() {
                            // remote mode: the wallet talks to the remote node itself, no monerod command
                            if (persistentSettings.useRemoteNode) { preview = false; text = ""; return; }
                            var c = daemonManager.command(true);
                            preview = c === "";   // also in remote mode: what a local start would run
                            // the start itself adds --bootstrap-daemon-address (DaemonManager::start)
                            var boot = appWindow.daemonBootstrapAddress();
                            text = preview ? "monerod " + appWindow.daemonFlagsFor(appWindow.daemonBaseFlags())
                                             + (boot !== "" ? " --bootstrap-daemon-address " + boot : "") : c;
                        }
                        Component.onCompleted: refresh()
                        Connections {
                            target: appWindow
                            function onDaemonRunningChanged() { daemonCommand.refresh(); }
                            function onDaemonCommandStaleChanged() { daemonCommand.refresh(); }
                        }
                        // the Network configuration or the peers changed: show it at once
                        Connections {
                            target: persistentSettings
                            function onNetSyncChanged() { daemonCommand.refresh(); }
                            function onNetTxChanged() { daemonCommand.refresh(); }
                            function onAnonPeersChanged() { daemonCommand.refresh(); }
                            function onExclusiveNodesChanged() { daemonCommand.refresh(); }
                            function onExtraPeersChanged() { daemonCommand.refresh(); }
                            function onDaemonFlagsChanged() { daemonCommand.refresh(); }
                            function onUseRemoteNodeChanged() { daemonCommand.refresh(); }
                            function onBootstrapNodeAddressChanged() { daemonCommand.refresh(); }
                        }
                        Timer {
                            interval: 3000
                            repeat: true
                            running: true
                            triggeredOnStart: true
                            onTriggered: daemonCommand.refresh()
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true
                                text: (!daemonCommand.preview ? qsTr("monerod command")
                                       : persistentSettings.useRemoteNode ? qsTr("monerod command (if you start the local node)")
                                       : qsTr("monerod command (next start)")) + translationManager.emptyString
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 0.8
                                font.capitalization: Font.AllUppercase
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                            MoneroComponents.StandardButton {
                                small: true
                                text: qsTr("Copy") + translationManager.emptyString
                                onClicked: {
                                    clipboard.setText(daemonCommand.text);
                                    appWindow.showStatusMessage(qsTr("Copied to clipboard") + translationManager.emptyString, 3);
                                }
                            }
                        }

                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            visible: appWindow.daemonCommandStale && !daemonCommand.preview
                            wrapMode: Text.WordWrap
                            text: qsTr("The Network configuration changed: monerod restarts by itself with the new flags.") + translationManager.emptyString
                            font.pixelSize: 12
                            color: MoneroComponents.Style.blackTheme ? "#FFC23D" : "#A86F00"
                            themeTransition: false
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: commandText.implicitHeight + 20
                            color: MoneroComponents.Style.blackTheme ? "#08FFFFFF" : "#08000000"
                            border.width: 1
                            border.color: MoneroComponents.Style.blackTheme ? "#26E8ECE9" : "#262B3A30"
                            TextEdit {
                                id: commandText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 10
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAnywhere
                                // one flag per line, easier to read
                                text: daemonCommand.text.replace(/ (--)/g, "\n  $1")
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 12
                                color: MoneroComponents.Style.defaultFontColor
                                selectionColor: MoneroComponents.Style.textSelectionColor
                            }
                        }
                    }

                }
            }

        }

        // ---- connection checks: one per anonymous network, with what each one is used for ----
        MoneroComponents.CollapsibleCard {
            Layout.topMargin: 4
            icon: FontAwesome.checkCircle
                title: qsTr("Connection check") + translationManager.emptyString
            summary: appWindow.connTestingNet !== "" ? qsTr("checking %1…").arg(appWindow.netDisplayName(appWindow.connTestingNet)) + translationManager.emptyString
                                                     : qsTr("Nym · Tor · I2P") + translationManager.emptyString
            checked: persistentSettings.connCardOpen
            onCheckedChanged: persistentSettings.connCardOpen = checked

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 16
                spacing: 18

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Runs only when requested, one network at a time, and shares bandwidth with synchronization. Through Nym or I2P it can take a few minutes.") + translationManager.emptyString
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                MoneroComponents.ConnectionCheck { Layout.fillWidth: true; net: "nym" }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"; opacity: 0.15 }
                MoneroComponents.ConnectionCheck { Layout.fillWidth: true; net: "tor" }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"; opacity: 0.15 }
                MoneroComponents.ConnectionCheck { Layout.fillWidth: true; net: "i2p" }
            }
        }

        // same NYM VPN panel as the welcome page
        MoneroComponents.NymVpnPanel {
            Layout.fillWidth: true
            Layout.topMargin: 4
        }

        // bundled Tor, below Nym
        MoneroComponents.TorPanel {
            Layout.fillWidth: true
            Layout.topMargin: 14
        }

        // bundled I2P, below Tor (works together with Tor or Nym)
        MoneroComponents.I2pPanel {
            Layout.fillWidth: true
            Layout.topMargin: 14
        }

        // ---- price conversion (moved here from Interface), folded ----
        // the same checkbox turns on the fiat balance and the swap prices of the Swaps page
        MoneroComponents.CollapsibleCard {
            id: priceCard
            z: 2   // the open dropdowns must draw over the Network card below
            Layout.topMargin: 14
            icon: FontAwesome.globe
                title: qsTr("External connections") + translationManager.emptyString
            summary: persistentSettings.fiatPriceEnabled
                     ? appWindow.priceSourceName(persistentSettings.fiatPriceProvider) + " · " + persistentSettings.fiatPriceCurrency.replace(/^xmr/, "").toUpperCase() + " · " + qsTr("Swaps") + translationManager.emptyString
                     : qsTr("Off") + translationManager.emptyString

            MoneroComponents.ExternalPriceSettings { }
        }

        // ---- network (moved here from Interface), folded ----
        // while NymVPN is on or "Nym required" is checked the proxy belongs to Nym: shown, not editable
        // the free SOCKS5 proxy is gone: the Network configuration (top) always uses Tor or Nym
        MoneroComponents.CollapsibleCard {
            id: networkCard
            visible: false
            readonly property bool torLocked: persistentSettings.torEnabled || persistentSettings.torRequired
            readonly property bool nymLocked: torLocked || persistentSettings.nymVpnEnabled || persistentSettings.nymVpnRequired
            Layout.topMargin: 14
            Layout.bottomMargin: 20
            icon: FontAwesome.networkWired
                title: qsTr("Network") + translationManager.emptyString
            summary: (torLocked ? "Tor · " + oshelper.torClient.address
                      : nymLocked ? qsTr("NymVPN") + " · " + persistentSettings.nymVpnSocksAddress
                      : proxyCheckbox.checked ? "Socks5 · " + (socksProxyFlagSet ? socksProxyFlag : persistentSettings.proxyAddress)
                      : qsTr("No proxy")) + translationManager.emptyString

            MoneroComponents.TextPlain {
                visible: networkCard.nymLocked
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: (networkCard.torLocked ? qsTr("Locked while Tor is connected or \"Tor required\" is checked: the app uses its Tor proxy.")
                      : qsTr("Locked while NymVPN is connected or \"Nym required\" is checked: the app uses the Nym proxy.")) + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.CheckBox {
                id: proxyCheckbox
                enabled: !socksProxyFlagSet && !networkCard.nymLocked
                checked: networkCard.nymLocked ? true : (socksProxyFlagSet ? socksProxyFlag : persistentSettings.proxyEnabled)
                onClicked: {
                    persistentSettings.proxyEnabled = !persistentSettings.proxyEnabled;
                }
                text: qsTr("Socks5 proxy (%1%2)")
                    .arg(appWindow.walletMode >= 2 ? qsTr("remote node connections, ") : "")
                    .arg(qsTr("updates downloading, fetching price sources")) + translationManager.emptyString
            }

            Item {
                Layout.fillWidth: true
                Layout.leftMargin: 35
                Layout.minimumWidth: 100
                implicitHeight: proxyEdit.implicitHeight
                visible: proxyCheckbox.checked

                MoneroComponents.RemoteNodeEdit {
                    id: proxyEdit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    enabled: !socksProxyFlagSet
                    opacity: networkCard.nymLocked ? 0.6 : 1
                    placeholderFontSize: 15

                    daemonAddrLabelText: qsTr("IP address") + translationManager.emptyString
                    daemonPortLabelText: qsTr("Port") + translationManager.emptyString

                    initialAddress: networkCard.torLocked ? oshelper.torClient.address
                                    : networkCard.nymLocked ? persistentSettings.nymVpnSocksAddress
                                    : socksProxyFlagSet ? socksProxyFlag : persistentSettings.proxyAddress
                    onEditingFinished: {
                        if (!networkCard.nymLocked)
                            persistentSettings.proxyAddress = proxyEdit.getAddress();
                    }
                }

                // locked by Nym: the address stays readable but takes no clicks or typing
                MouseArea {
                    anchors.fill: parent
                    visible: networkCard.nymLocked
                    acceptedButtons: Qt.AllButtons
                    cursorShape: Qt.ForbiddenCursor
                }
            }
        }

        // blockchain location, startup flags, bootstrap node: folded so they don't take the whole page
        MoneroComponents.CollapsibleCard {
            visible: appWindow.walletMode >= 2 && !persistentSettings.useRemoteNode
            Layout.topMargin: 4
            icon: FontAwesome.slidersH
                title: qsTr("Local node options") + translationManager.emptyString
            summary: persistentSettings.blockchainDataDir !== "" ? persistentSettings.blockchainDataDir : qsTr("(default)") + translationManager.emptyString

            RowLayout {
                Layout.fillWidth: true

                MoneroComponents.LineEditMulti {
                    id: blockchainFolder
                    Layout.preferredWidth: 200
                    Layout.fillWidth: true
                    fontSize: 15
                    labelFontSize: 14
                    property string style: "<style type='text/css'>a {cursor:pointer;text-decoration: underline; color: %1}</style>".arg(MoneroComponents.Style.defaultFontColor)
                    labelText: qsTr("Blockchain location") + style + " <a href='#'> (%1)</a>".arg(qsTr("Change")) + translationManager.emptyString
                    labelButtonText: qsTr("Reset") + translationManager.emptyString
                    labelButtonVisible: text
                    placeholderText: qsTr("(default)") + translationManager.emptyString
                    placeholderFontSize: 15
                    readOnly: true
                    text: persistentSettings.blockchainDataDir
                    addressValidation: false
                    onInputLabelLinkActivated: {
                        //mouse.accepted = false
                        if(persistentSettings.blockchainDataDir !== ""){
                            blockchainFileDialog.currentFolder = "file://" + persistentSettings.blockchainDataDir;
                        }
                        blockchainFileDialog.open();
                        blockchainFolder.focus = true;
                    }
                    onLabelButtonClicked: persistentSettings.blockchainDataDir = ""
                }
            }

            MoneroComponents.LineEditMulti {
                id: daemonFlags
                Layout.fillWidth: true
                labelFontSize: 14
                fontSize: 15
                wrapMode: Text.WrapAnywhere
                labelText: qsTr("Daemon startup flags") + translationManager.emptyString
                placeholderText: qsTr("(optional)") + translationManager.emptyString
                placeholderFontSize: 15
                text: persistentSettings.daemonFlags
                addressValidation: false
                error: text.match(/(^|\s)--(data-dir|bootstrap-daemon-address|non-interactive)/)
                onEditingFinished: {
                    if (!daemonFlags.error) {
                        persistentSettings.daemonFlags = daemonFlags.text;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !persistentSettings.useRemoteNode

                ColumnLayout {
                    Layout.fillWidth: true

                    MoneroComponents.RemoteNodeEdit {
                        id: bootstrapNodeEdit
                        Layout.minimumWidth: 100

                        daemonAddrLabelText: qsTr("Bootstrap Address") + translationManager.emptyString
                        daemonPortLabelText: qsTr("Bootstrap Port") + translationManager.emptyString
                        initialAddress: persistentSettings.bootstrapNodeAddress
                        onEditingFinished: {
                            if (daemonAddrText == "auto") {
                                persistentSettings.bootstrapNodeAddress = daemonAddrText;
                            } else {
                                persistentSettings.bootstrapNodeAddress = daemonAddrText ? bootstrapNodeEdit.getAddress() : "";
                            }
                            console.log("setting bootstrap node to " + persistentSettings.bootstrapNodeAddress)
                        }
                    }
                }
            }
        }
    }

}
