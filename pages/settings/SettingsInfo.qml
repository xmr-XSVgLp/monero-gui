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
import QtQuick.Dialogs

import FontAwesome

import "../../js/Wizard.js" as Wizard
import "../../js/Utils.js" as Utils
import "../../version.js" as Version
import "../../components" as MoneroComponents


Rectangle {
    id: infoPage
    color: "transparent"
    Layout.fillWidth: true
    property alias infoHeight: infoLayout.height
    readonly property string rendererName: ({
        [GraphicsInfo.OpenGL]: "OpenGL",
        [GraphicsInfo.Vulkan]: "Vulkan",
        [GraphicsInfo.Metal]: "Metal",
        [GraphicsInfo.Direct3D11]: "Direct3D 11",
        [GraphicsInfo.Direct3D12]: "Direct3D 12",
        [GraphicsInfo.OpenVG]: "OpenVG",
        [GraphicsInfo.Software]: "Software",
        [GraphicsInfo.Null]: "Null"
    })[GraphicsInfo.api] ?? "Unknown"
    property string walletModeString: {
        var modeStr;
        if(appWindow.walletMode === 0){
          modeStr = qsTr("Simple mode") + translationManager.emptyString;
        } else if(appWindow.walletMode === 1){
          modeStr = qsTr("Simple mode") + " (bootstrap)" + translationManager.emptyString;
        } else if(appWindow.walletMode === 2){
          modeStr = "%1 (%2)".arg(qsTr("Advanced mode")).arg(persistentSettings.useRemoteNode ? qsTr("Remote node") : qsTr("Local node")) + translationManager.emptyString;
        }
        return modeStr + (portableSettings.portable ? ", %1".arg(qsTr("portable")) : "");
    }

    component InfoCard: Rectangle {
        property string heading
        default property alias content: cardContents.data
        Layout.fillWidth: true
        implicitHeight: cardContents.implicitHeight + 32
        radius: 12
        color: MoneroComponents.Style.blackTheme ? "#111917" : "#E5E9E5"
        border.color: MoneroComponents.Style.blackTheme ? "#2B3933" : "#BDC8C0"
        ColumnLayout {
            id: cardContents
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 6
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                text: heading
                font.pixelSize: 16
                font.bold: true
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
                wrapMode: Text.WordWrap
            }
        }
    }
    component InfoRow: RowLayout {
        id: detailRow
        property string label
        property string value
        property bool mono: true
        property string actionIcon: ""
        property string actionTooltip: ""
        signal actionClicked()
        Layout.fillWidth: true
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        spacing: 14
        GridLayout {
            Layout.fillWidth: true
            columns: detailRow.width < 480 ? 1 : 2
            columnSpacing: 18
            rowSpacing: 4
            MoneroComponents.TextPlain {
                Layout.preferredWidth: parent.columns === 2 ? 190 : -1
                Layout.fillWidth: parent.columns === 1
                text: label
                color: MoneroComponents.Style.dimmedFontColor
                font.pixelSize: 12
                themeTransition: false
                wrapMode: Text.WordWrap
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                text: value
                color: MoneroComponents.Style.defaultFontColor
                font.family: mono ? MoneroComponents.Style.fontMonoRegular.name : MoneroComponents.Style.fontRegular.name
                font.pixelSize: 13
                themeTransition: false
                wrapMode: Text.WrapAnywhere
            }
        }
        MoneroComponents.SettingsIconButton {
            visible: actionIcon !== ""
            icon: actionIcon
            tooltip: actionTooltip
            onClicked: actionClicked()
        }
    }

    ColumnLayout {
        id: infoLayout
        width: Math.min(920, Math.max(0, infoPage.width - 40))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 18

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: heroContents.implicitHeight + 48
            radius: 16
            color: "#111715"
            border.color: "#57402A"
            clip: true
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                height: 3
                radius: 2
                color: "#C58142"
            }
            GridLayout {
                id: heroContents
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                columns: infoLayout.width < 540 ? 1 : 2
                columnSpacing: 28
                rowSpacing: 20
                Image {
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 160
                    Layout.alignment: Qt.AlignHCenter
                    source: "qrc:///images/logos/walletplus-logo.png"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        text: "XMR Wallet+"
                        font.pixelSize: infoLayout.width < 540 ? 30 : 36
                        font.bold: true
                        color: "#F0EAE2"
                        themeTransition: false
                        wrapMode: Text.WordWrap
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        text: qsTr("Your Monero. Your control.") + translationManager.emptyString
                        font.pixelSize: 16
                        color: "#D4B28D"
                        themeTransition: false
                        wrapMode: Text.WordWrap
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        text: qsTr("An independent wallet built on Monero GUI.") + translationManager.emptyString
                        font.pixelSize: 13
                        color: "#A7B3AC"
                        themeTransition: false
                        wrapMode: Text.WordWrap
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        text: "v" + Version.WALLETPLUS_VERSION
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 13
                        color: "#D4B28D"
                        themeTransition: false
                    }
                }
            }
        }

        InfoCard {
            heading: qsTr("Software and build") + translationManager.emptyString

            InfoRow {
                label: qsTr("XMR Wallet+ version") + translationManager.emptyString
                value: Version.WALLETPLUS_VERSION
            }

            InfoRow {
                label: qsTr("GUI version: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: Version.GUI_VERSION + " (Qt " + qtRuntimeVersion + ")" + translationManager.emptyString
            }

            InfoRow {
                id: guiMoneroVersion
                label: qsTr("Embedded Monero version: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: moneroVersion
            }

        }

        InfoCard {
            heading: qsTr("Wallet and environment") + translationManager.emptyString
            InfoRow {
                id: walletLocation
                property string walletPath: (isIOS ?  appWindow.accountsDir : "") + persistentSettings.wallet_path
                label: qsTr("Wallet path: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: walletPath
                actionIcon: FontAwesome.folderOpen
                actionTooltip: qsTr("Open folder") + translationManager.emptyString
                onActionClicked: oshelper.openContainingFolder(walletPath)
            }

            InfoRow {
                id: restoreHeight
                visible: typeof currentWallet != "undefined" && currentWallet !== null
                label: qsTr("Wallet restore height: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: currentWallet ? currentWallet.walletCreationHeight : ""
                actionIcon: FontAwesome.edit
                actionTooltip: qsTr("Change") + translationManager.emptyString
                onActionClicked: restoreHeightText.changeRestoreHeight()

                // kept as an object so the restore height logic keeps its id
                QtObject {
                    id: restoreHeightText
                    function changeRestoreHeight() {
                        inputDialog.labelText = qsTr("Set a new restore height.\nYou can enter a block height or a date (YYYY-MM-DD):") + translationManager.emptyString;
                        inputDialog.onAcceptedCallback = function() {
                            var _restoreHeight;
                            if (inputDialog.inputText) {
                                _restoreHeight = Utils.parseDateStringOrRestoreHeightAsInteger(inputDialog.inputText.trim());
                            }
                            if (!isNaN(_restoreHeight)) {
                                if(_restoreHeight >= 0) {
                                    currentWallet.walletCreationHeight = _restoreHeight
                                    // Restore height is saved in .keys file. Set password to trigger rewrite.
                                    currentWallet.setPassword(appWindow.walletPassword)

                                    // Show confirmation dialog
                                    confirmationDialog.title = qsTr("Rescan wallet cache") + translationManager.emptyString;
                                    confirmationDialog.text  = qsTr("Are you sure you want to rebuild the wallet cache?\n"
                                                                    + "The following information will be deleted\n"
                                                                    + "- Recipient addresses\n"
                                                                    + "- Tx keys\n"
                                                                    + "- Tx descriptions\n\n"
                                                                    + "The old wallet cache file will be renamed and can be restored later.\n"
                                                                    );
                                    confirmationDialog.onAcceptedCallback = function() {
                                        appWindow.closeWallet(function() {
                                            walletManager.clearWalletCache(persistentSettings.wallet_path);
                                            walletManager.openWalletAsync(persistentSettings.wallet_path, appWindow.walletPassword,
                                                                            persistentSettings.nettype, persistentSettings.kdfRounds);
                                        });
                                    }

                                    confirmationDialog.onRejectedCallback = null;
                                    confirmationDialog.open()
                                    return;
                                }
                            }

                            appWindow.showStatusMessage(qsTr("Invalid restore height specified. Must be a number or a date formatted YYYY-MM-DD"),3);
                        }
                        inputDialog.onRejectedCallback = null;
                        inputDialog.kind = "info";
                        inputDialog.open(currentWallet ? currentWallet.walletCreationHeight.toFixed(0) : "0")
                    }
                }
            }

            InfoRow {
                label: qsTr("Wallet log path: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: logger.logFilePath
                actionIcon: FontAwesome.folderOpen
                actionTooltip: qsTr("Open folder") + translationManager.emptyString
                onActionClicked: oshelper.openContainingFolder(logger.logFilePath)
            }

            InfoRow {
                label: qsTr("Wallet mode: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: walletModeString
                mono: false
            }

            InfoRow {
                label: qsTr("Graphics mode: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: rendererName
            }

            InfoRow {
                visible: isTails
                label: qsTr("Tails: ").replace(/:\s*$/, "") + translationManager.emptyString
                value: tailsUsePersistence ? qsTr("persistent") + translationManager.emptyString : qsTr("persistence disabled") + translationManager.emptyString;
                mono: false
            }
        }

        Item {
            id: actions
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 24
            readonly property bool stacked: width < 2 * Math.max(donateMonero.width, donateWalletPlus.width) + copyInfo.width + 32
            implicitHeight: stacked ? donateMonero.height + copyInfo.height + donateWalletPlus.height + 24 : 48

            MoneroComponents.StandardButton {
                id: copyInfo
                x: (actions.width - width) / 2
                y: actions.stacked ? donateMonero.height + 12 : (actions.height - height) / 2
                small: true
                text: qsTr("Copy to clipboard") + translationManager.emptyString
                onClicked: {
                    var data = "";
                    data += "XMR Wallet+ version: " + Version.WALLETPLUS_VERSION;
                    data += "\nGUI version: " + Version.GUI_VERSION + " (Qt " + qtRuntimeVersion + ")";
                    data += "\nEmbedded Monero version: " + moneroVersion;
                    data += "\nWallet path: " + walletLocation.walletPath;

                    data += "\nWallet restore height: ";
                    if(currentWallet)
                        data += currentWallet.walletCreationHeight;

                    data += "\nWallet log path: " + logger.logFilePath;
                    data += "\nWallet mode: " + walletModeString;
                    data += "\nGraphics mode: " + rendererName;
                    if (isTails)
                        data += "\nTails: " + (tailsUsePersistence ? "persistent" : "persistence disabled");

                    console.log("Copied to clipboard");
                    clipboard.setText(data);
                    appWindow.showStatusMessage(qsTr("Copied to clipboard"), 3);
                }
            }

            MoneroComponents.StandardButton {
                id: donateMonero
                x: actions.stacked ? (actions.width - width) / 2 : 0
                y: 0
                height: 48
                fontSize: 14
                accent: MoneroComponents.Style.orange
                textColor: MoneroComponents.Style.textAccent
                fontAwesomeIcon: true
                rightIcon: FontAwesome.heart
                text: qsTr("Donate to Monero") + translationManager.emptyString
                onClicked: {
                    middlePanel.sendTo("888tNkZrPN6JsEgekjMnABU4TBzc2Dt29EPAvkRxbANsAnjyPbb3iQ1YBRk1UXcdRsiKc9dhwMVgN5S9cQUiyoogDavup3H", "", qsTr("Donation to Monero Core Team") + translationManager.emptyString);
                }
            }

            MoneroComponents.StandardButton {
                id: donateWalletPlus
                x: actions.stacked ? (actions.width - width) / 2 : actions.width - width
                y: actions.stacked ? copyInfo.y + copyInfo.height + 12 : 0
                height: 48
                fontSize: 14
                accent: MoneroComponents.Style.orange
                textColor: MoneroComponents.Style.textAccent
                fontAwesomeIcon: true
                rightIcon: FontAwesome.heart
                text: qsTr("Donate to XMR Wallet+") + translationManager.emptyString
                onClicked: {
                    middlePanel.sendTo("87777TxqmTc3zNbxyPC9KtEZYtATJXFMuCWzzRQUVNpshQChDa8vcC8HVquywZaJ3UbQZwHGfq9SmAFscsnrs1FM3vWP93f", "", qsTr("Donation to XMR Wallet+") + translationManager.emptyString);
                }
            }
        }
    }
}
