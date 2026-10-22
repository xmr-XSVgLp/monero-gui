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
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Controls
import moneroComponents.NetworkType 1.0

import "../components" as MoneroComponents

Rectangle {
    id: wizardHome
    color: "transparent"
    property alias pageHeight: pageRoot.height
    property alias createWalletButton: createWalletButton
    property alias openWalletButton: openWalletButton
    property alias restoreWalletButton: restoreWalletButton
    property alias changeWalletModeButton: changeWalletModeButton
    property string viewName: "wizardHome"

    ColumnLayout {
        id: pageRoot
        Layout.alignment: Qt.AlignHCenter;
        width: parent.width - 100
        Layout.fillWidth: true
        anchors.horizontalCenter: parent.horizontalCenter;

        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: wizardController.wizardSubViewTopMargin
            Layout.maximumWidth: wizardController.wizardSubViewWidth
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                WizardHeader {
                    Layout.bottomMargin: 7
                    Layout.fillWidth: true
                    title: qsTr("Welcome to Monero") + translationManager.emptyString
                    subtitle: ""
                }

                MoneroComponents.LanguageButton {
                    Layout.bottomMargin: 8
                }
            }

            WizardMenuItem {
                id: createWalletButton
                Layout.topMargin: 8
                headerText: {
                    var nettype = persistentSettings.nettype;
                    return qsTr("Create a new wallet") + (nettype === 2 ? " (" + qsTr("stagenet") + ")"
                                                                        : nettype === 1 ? " (" + qsTr("testnet") + ")"
                                                                                        : "") + translationManager.emptyString
                }
                bodyText: qsTr("Choose this option if this is your first time using Monero.") + translationManager.emptyString
                imageIcon: "qrc:///images/wallet-icons/create-wallet.png"

                onMenuClicked: {
                    wizardController.restart();
                    wizardController.createWallet();
                    wizardStateView.state = "wizardCreateWallet1"
                    wizardStateView.wizardCreateWallet1View.pageRoot.forceActiveFocus();
                }
            }

            WizardMenuItem {
                headerText: {
                    var nettype = persistentSettings.nettype;
                    return qsTr("Create a new wallet from hardware") + (nettype === 2 ? " (" + qsTr("stagenet") + ")"
                                                                        : nettype === 1 ? " (" + qsTr("testnet") + ")"
                                                                                        : "") + translationManager.emptyString
                }
                bodyText: qsTr("Connect your hardware wallet to create a new Monero wallet.") + translationManager.emptyString
                imageIcon: "qrc:///images/wallet-icons/restore-wallet-from-hardware.png"

                onMenuClicked: {
                    wizardController.restart();
                    wizardStateView.state = "wizardCreateDevice1"
                }
            }

            WizardMenuItem {
                id: openWalletButton
                headerText: qsTr("Open a wallet from file") + translationManager.emptyString
                bodyText: qsTr("Import an existing .keys wallet file from your computer.") + translationManager.emptyString
                imageIcon: "qrc:///images/wallet-icons/open-wallet-from-file.png"

                onMenuClicked: {
                    wizardStateView.state = "wizardOpenWallet1"
                    wizardStateView.wizardOpenWallet1View.pageRoot.forceActiveFocus();
                }
            }

            WizardMenuItem {
                id: restoreWalletButton
                headerText: qsTr("Restore wallet from keys or mnemonic seed") + translationManager.emptyString
                bodyText: qsTr("Enter your private keys or 25-word mnemonic seed to restore your wallet.") + translationManager.emptyString
                imageIcon: "qrc:///images/wallet-icons/restore-wallet.png"

                onMenuClicked: {
                    wizardController.restart();
                    wizardStateView.state = "wizardRestoreWallet1"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 20

                MoneroComponents.StandardButton {
                    id: changeWalletModeButton
                    small: true
                    text: qsTr("Change wallet mode") + translationManager.emptyString

                    onClicked: {
                        wizardController.wizardStackView.backTransition = true;
                        wizardController.wizardState = 'wizardModeSelection';
                    }                    
                }
            }

            ListModel {
                id: networkTypeModel
                ListElement {column1: "Mainnet"; column2: ""; nettype: "mainnet"}
                ListElement {column1: "Testnet"; column2: ""; nettype: "testnet"}
                ListElement {column1: "Stagenet"; column2: ""; nettype: "stagenet"}
            }

            // advanced options: collapsible panel in the card style
            Item {
                id: showAdvancedCheckbox
                property bool checked: false
                readonly property bool dark: MoneroComponents.Style.blackTheme
                readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
                readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
                readonly property bool hovered: advHeaderMouse.containsMouse
                visible: appWindow.walletMode >= 2
                Layout.topMargin: 24
                Layout.fillWidth: true
                implicitHeight: advColumn.implicitHeight

                MoneroComponents.NeonFrame {
                    anchors.fill: parent
                    cut: 10
                    accent: showAdvancedCheckbox.border
                    lineOpacity: showAdvancedCheckbox.checked ? 0.6 : (showAdvancedCheckbox.hovered ? 0.6 : 0.25)
                    fillColor: showAdvancedCheckbox.dark ? "#0C130E" : "#DADFDB"
                    fillOpacity: showAdvancedCheckbox.dark ? 0.92 : 0.9
                    ticks: false
                    Behavior on lineOpacity { NumberAnimation { duration: 150 } }
                }

                ColumnLayout {
                    id: advColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    // header row: chevron, title, current settings
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
                                rotation: showAdvancedCheckbox.checked ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                property color c: showAdvancedCheckbox.accent
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
                                text: qsTr("Advanced options").toUpperCase() + translationManager.emptyString
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 13
                                font.letterSpacing: 2
                                color: showAdvancedCheckbox.checked || showAdvancedCheckbox.hovered
                                       ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            Item { Layout.fillWidth: true }

                            // what is set now, so it shows even when closed
                            MoneroComponents.TextPlain {
                                text: networkTypeModel.get(Math.max(0, Math.min(2, persistentSettings.nettype))).column1
                                      + "  ·  KDF " + (persistentSettings.kdfRounds ? persistentSettings.kdfRounds : 1)
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 12
                                color: persistentSettings.nettype !== 0 || persistentSettings.kdfRounds > 1
                                       ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                        }

                        MouseArea {
                            id: advHeaderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showAdvancedCheckbox.checked = !showAdvancedCheckbox.checked
                        }
                    }

                    Rectangle {
                        visible: showAdvancedCheckbox.checked
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.preferredHeight: 1
                        color: showAdvancedCheckbox.accent
                        opacity: 0.3
                    }

                    RowLayout {
                        visible: showAdvancedCheckbox.checked
                        Layout.fillWidth: true
                        Layout.margins: 16
                        Layout.topMargin: 14
                        spacing: 24

                        MoneroComponents.StandardDropdown {
                            id: networkTypeDropdown
                            currentIndex: persistentSettings.nettype
                            dataModel: networkTypeModel
                            Layout.preferredWidth: 220
                            Layout.maximumWidth: 220
                            labelText: qsTr("Network") + ":" + translationManager.emptyString
                            labelFontSize: 14

                            onChanged: {
                                var item = dataModel.get(currentIndex).nettype.toLowerCase();
                                if(item === "mainnet") {
                                    persistentSettings.nettype = NetworkType.MAINNET
                                } else if(item === "stagenet"){
                                    persistentSettings.nettype = NetworkType.STAGENET
                                } else if(item === "testnet"){
                                    persistentSettings.nettype = NetworkType.TESTNET
                                }
                                appWindow.disconnectRemoteNode()
                                networkTypeDropdown.currentIndex = Qt.binding(function() { return persistentSettings.nettype });
                                persistentSettings.wallet_path = ""
                            }
                        }

                        MoneroComponents.LineEdit {
                            id: kdfRoundsText
                            Layout.preferredWidth: 220
                            Layout.maximumWidth: 220

                            property bool kdfWarningShown: false

                            labelText: qsTr("Number of KDF rounds:") + translationManager.emptyString
                            labelFontSize: 14
                            fontSize: 16
                            placeholderFontSize: 16
                            placeholderText: "0"
                            validator: IntValidator { bottom: 1 }
                            text: persistentSettings.kdfRounds ? persistentSettings.kdfRounds : "1"
                            onTextChanged: {
                                var wasDefault = persistentSettings.kdfRounds === 1;
                                var newValue = parseInt(kdfRoundsText.text) >= 1 ? parseInt(kdfRoundsText.text) : 1;
                                persistentSettings.kdfRounds = newValue;

                                if (newValue === 1) {
                                    kdfRoundsText.kdfWarningShown = false;
                                } else if (wasDefault && !kdfRoundsText.kdfWarningShown) {
                                    kdfRoundsText.kdfWarningShown = true;
                                    confirmationDialog.title = qsTr("Warning") + translationManager.emptyString;
                                    confirmationDialog.text = qsTr("You have selected a non-standard number of KDF rounds.\n\nThis value is set globally and is not stored in the wallet file. It must be remembered and re-entered every time this wallet is opened; otherwise, the wallet will not open due to the password being incorrect.\n\nHigher values make opening and saving the wallet significantly slower.") + translationManager.emptyString;
                                    confirmationDialog.onAcceptedCallback = null;
                                    confirmationDialog.onRejectedCallback = function() {
                                        kdfRoundsText.text = "1";
                                    }
                                    confirmationDialog.cancelText = qsTr("Reset to 1") + translationManager.emptyString;
                                    confirmationDialog.okText = qsTr("Keep") + translationManager.emptyString;
                                    confirmationDialog.open();
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // which anonymous network each connection uses (same card as Settings → Node / Network)
            MoneroComponents.NetworkConfigCard {
                Layout.topMargin: 12
                Layout.fillWidth: true
            }

            // NymVPN: route the app through the Nym mixnet
            MoneroComponents.NymVpnPanel {
                id: nymVpnPanel
                Layout.topMargin: 14
                Layout.fillWidth: true
            }

            // bundled Tor and I2P, below Nym (same panels as Settings → Node / Network)
            MoneroComponents.TorPanel {
                Layout.topMargin: 14
                Layout.fillWidth: true
            }
            MoneroComponents.I2pPanel {
                Layout.topMargin: 14
                Layout.fillWidth: true
            }

            // connection check, one per network
            MoneroComponents.CollapsibleCard {
                Layout.topMargin: 14
                Layout.fillWidth: true
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
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200;
            easing.type: Easing.InCubic;
        }
    }

    function onPageCompleted(){
        wizardController.walletOptionsIsRecoveringFromDevice = false;
        if (networkTypeDropdown.currentIndex != 0) {
            showAdvancedCheckbox.checked = true;
        }
    }
}
