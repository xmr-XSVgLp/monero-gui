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
import QtQuick.Effects
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import moneroComponents.NetworkType 1.0
import moneroComponents.WalletKeysFilesModel 1.0

import "../js/Wizard.js" as Wizard
import "../components"
import "../components" as MoneroComponents
import "../components/effects/" as MoneroEffects

Rectangle {
    id: wizardOpenWallet1

    color: "transparent"
    property alias pageHeight: pageRoot.height
    property alias pageRoot: pageRoot
    property alias recentWallets: recentList
    property string viewName: "wizardOpenWallet1"
    property int walletCount: walletKeysFilesModel.rowCount()
    // wallets in the "XMR" folder of USB / SD volumes, checked every few seconds while this page is shown
    property var usbWallets: []

    function refreshUsbWallets() {
        var list = oshelper.removableWallets();
        if (JSON.stringify(list) !== JSON.stringify(usbWallets))
            usbWallets = list;
    }

    Timer {
        interval: 3000
        repeat: true
        running: wizardOpenWallet1.visible && wizardStateView.state === "wizardOpenWallet1"
        triggeredOnStart: true
        onTriggered: wizardOpenWallet1.refreshUsbWallets()
    }

    WalletKeysFilesModel {
        id: walletKeysFilesModel
    }

    ColumnLayout {
        id: pageRoot
        Layout.alignment: Qt.AlignHCenter;
        width: parent.width - 100
        Layout.fillWidth: true
        anchors.horizontalCenter: parent.horizontalCenter;
        KeyNavigation.tab: openWalletFromFileHeader

        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: wizardController.wizardSubViewTopMargin
            Layout.maximumWidth: wizardController.wizardSubViewWidth
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            WizardHeader {
                id: openWalletFromFileHeader
                title: qsTr("Open a wallet from file") + translationManager.emptyString
                subtitle: qsTr("Import an existing .keys wallet file from your computer.") + translationManager.emptyString
                Accessible.role: Accessible.StaticText
                Accessible.name: title + ". " + subtitle
                Keys.onUpPressed: wizardNav.btnNext.forceActiveFocus();
                Keys.onBacktabPressed: wizardNav.btnNext.forceActiveFocus();
                Keys.onDownPressed: recentList.itemAt(0).forceActiveFocus();
                Keys.onTabPressed: recentList.itemAt(0).forceActiveFocus();
            }

            // ---- wallets on USB / SD volumes ----
            RowLayout {
                visible: wizardOpenWallet1.usbWallets.length > 0
                Layout.topMargin: 14
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 6; height: 6
                    color: MoneroComponents.Style.blackTheme ? "#6CB8FF" : "#1565C0"
                }

                MoneroComponents.TextPlain {
                    text: qsTr("USB / SD wallets").toUpperCase() + translationManager.emptyString
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    text: wizardOpenWallet1.usbWallets.length
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    opacity: 0.7
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.TextPlain {
                    text: qsTr("Close the wallet before unplugging the drive") + translationManager.emptyString
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            Flow {
                id: usbFlow
                visible: wizardOpenWallet1.usbWallets.length > 0
                spacing: 10
                Layout.topMargin: 4
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight

                Repeater {
                    model: wizardOpenWallet1.usbWallets

                    delegate: Item {
                        id: usbItem
                        height: flow.itemHeight
                        width: Math.floor((usbFlow.width - (flow.columns - 1) * usbFlow.spacing) / flow.columns)
                        readonly property bool dark: MoneroComponents.Style.blackTheme
                        readonly property color blue: dark ? "#6CB8FF" : "#1565C0"
                        readonly property bool hovered: usbMouseArea.containsMouse || usbItem.focus
                        activeFocusOnTab: true
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.fileName + ". " + modelData.volume
                        Keys.onEnterPressed: wizardController.openWalletFile(modelData.path)
                        Keys.onReturnPressed: wizardController.openWalletFile(modelData.path)

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            accent: usbItem.blue
                            lineOpacity: usbItem.focus ? 1.0 : (usbItem.hovered ? 0.9 : 0.45)
                            fillColor: usbItem.dark ? "#0C130E" : "#DADFDB"
                            fillOpacity: usbItem.dark ? 0.92 : 0.9
                            glow: usbItem.hovered ? 0.3 : 0.0
                            ticks: usbItem.hovered
                            Behavior on lineOpacity { NumberAnimation { duration: 150 } }
                        }

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            lineOpacity: 0
                            fillColor: usbItem.blue
                            fillOpacity: usbItem.hovered ? 0.12 : 0.05
                            ticks: false
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    source: /trezor|tzr/.test(modelData.fileName.toLowerCase()) ? "qrc:///images/open-wallet-from-file-trezor.png"
                                          : modelData.networktype === 1 ? "qrc:///images/open-wallet-from-file-testnet.png"
                                          : modelData.networktype === 2 ? "qrc:///images/open-wallet-from-file-stagenet.png"
                                          : "qrc:///images/open-wallet-safe.png"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: modelData.fileName
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMedium.name
                                    font.pixelSize: 15
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }

                                // drive name and last change
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: modelData.volume + " · " + Qt.formatDate(new Date(modelData.modified * 1000), "dd/MM/yyyy")
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 11
                                    color: usbItem.blue
                                    themeTransition: false
                                }
                            }
                        }

                        MouseArea {
                            id: usbMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wizardController.openWalletFile(modelData.path)
                        }
                    }
                }
            }

            RowLayout {
                visible: wizardOpenWallet1.walletCount > 0
                Layout.topMargin: 14
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 6; height: 6
                    color: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
                }

                MoneroComponents.TextPlain {
                    text: qsTr("Recently opened").toUpperCase() + translationManager.emptyString
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    text: wizardOpenWallet1.walletCount
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    opacity: 0.7
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }
            }

            Flow {
                id: flow
                visible: wizardOpenWallet1.walletCount > 0
                spacing: 10
                clip: true

                property int _height: 0
                property int itemHeight: 64
                property int maxRows: 5
                property int columns: wizardController.layoutScale <= 1 ? 2 : 3

                Layout.topMargin: 4
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: _height

                function calcHeight(){
                    var rows = Math.min(Math.ceil(wizardOpenWallet1.walletCount / flow.columns), flow.maxRows);
                    return rows * flow.itemHeight + Math.max(0, rows - 1) * flow.spacing + 4;
                }

                Repeater {
                    id: recentList
                    clip: true
                    model: walletKeysFilesModel.proxyModel
                    Layout.fillWidth: true
                    Layout.minimumWidth: flow.itemHeight
                    Layout.preferredHeight: parent.height

                    function moveUp(itemIndex) {
                        if (itemIndex == 0) {
                            openWalletFromFileHeader.forceActiveFocus();
                        } else {
                            recentList.itemAt(itemIndex - 1).forceActiveFocus();
                        }
                    }

                    function moveDown(itemIndex) {
                        if (itemIndex + 1 == recentList.count) {
                            wizardNav.btnPrev.forceActiveFocus();
                        } else {
                            recentList.itemAt(itemIndex + 1).forceActiveFocus();
                        }
                    }

                    function openSelectedWalletFile(path) {
                        wizardController.openWalletFile(path);
                    }

                    delegate: Item {
                        // inherited roles from walletKeysFilesModel:
                        // index, fileName, modified, accessed, path, networktype, address
                        id: item
                        height: flow.itemHeight
                        width: Math.floor((flow.width - (flow.columns - 1) * flow.spacing) / flow.columns)
                        property string walletFileName: fileName
                        property string networkType: {
                            if(networktype === 0 && appWindow.walletMode >= 2) return qsTr("Mainnet");
                            else if(networktype === 1) return qsTr("Testnet");
                            else if(networktype === 2) return qsTr("Stagenet");
                            return "";
                        }
                        readonly property bool dark: MoneroComponents.Style.blackTheme
                        readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
                        readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
                        readonly property bool hovered: itemMouseArea.containsMouse || item.focus

                        Accessible.role: Accessible.ListItem
                        Accessible.name: {
                            if (networktype === 0) var networkTypeText = qsTr("Mainnet wallet") + translationManager.emptyString;
                            if (networktype === 1) var networkTypeText = qsTr("Testnet wallet") + translationManager.emptyString;
                            if (networktype === 2) var networkTypeText = qsTr("Stagenet wallet") + translationManager.emptyString;

                            return fileName + ". " + networkTypeText;
                        }
                        Keys.onUpPressed: recentList.moveUp(index);
                        Keys.onBacktabPressed: recentList.moveUp(index);
                        Keys.onDownPressed: recentList.moveDown(index);
                        Keys.onTabPressed: recentList.moveDown(index);
                        Keys.onEnterPressed: recentList.openSelectedWalletFile(path);
                        Keys.onReturnPressed: recentList.openSelectedWalletFile(path);

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            accent: item.border
                            lineOpacity: item.focus ? 1.0 : (item.hovered ? 0.85 : 0.22)
                            fillColor: item.dark ? "#0C130E" : "#DADFDB"
                            fillOpacity: item.dark ? 0.92 : 0.9
                            glow: item.hovered ? 0.3 : 0.0
                            ticks: item.hovered
                            Behavior on lineOpacity { NumberAnimation { duration: 150 } }
                        }

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            lineOpacity: 0
                            fillColor: item.accent
                            fillOpacity: item.hovered ? 0.10 : 0.0
                            ticks: false
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42

                                Image {
                                    id: icon
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    source: {
                                        if (networktype === 0 && fileName.toLowerCase().includes("viewonly")) return "qrc:///images/open-wallet-from-file-view-only.png";
                                        else if (networktype === 0 && /trezor|tzr|trial/.test(fileName.toLowerCase())) return "qrc:///images/open-wallet-from-file-trezor.png";
                                        else if (networktype === 0 && fileName.toLowerCase().includes("ledger")) return "qrc:///images/restore-wallet-from-hardware.png";
                                        else if (networktype === 0) return "qrc:///images/open-wallet-safe.png";
                                        else if (networktype === 1) return "qrc:///images/open-wallet-from-file-testnet.png";
                                        else if (networktype === 2) return "qrc:///images/open-wallet-from-file-stagenet.png";
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: fileName
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMedium.name
                                    font.pixelSize: 15
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }

                                // short address, or the last time the file changed
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: address && address.length > 12
                                          ? address.substring(0, 6) + "…" + address.substring(address.length - 6)
                                          : Qt.formatDate(new Date(modified * 1000), "dd/MM/yyyy")
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 11
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                            }

                            // network badge (testnet/stagenet, or mainnet in advanced mode)
                            Item {
                                visible: item.networkType !== ""
                                implicitWidth: netText.implicitWidth + 12
                                implicitHeight: netText.implicitHeight + 6

                                MoneroComponents.NeonFrame {
                                    anchors.fill: parent
                                    cut: 4
                                    accent: networktype === 0 ? item.border : (networktype === 1 ? "#FFB200" : "#00E8FF")
                                    lineOpacity: 0.5
                                    fillColor: accent
                                    fillOpacity: 0.08
                                    ticks: false
                                }

                                MoneroComponents.TextPlain {
                                    id: netText
                                    anchors.centerIn: parent
                                    text: item.networkType.toUpperCase()
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: recentList.openSelectedWalletFile(path);
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            WizardNav {
                id: wizardNav
                Layout.topMargin: 0
                progressEnabled: false
                btnPrev.text: appWindow.width <= 506 ? "<" : qsTr("Back to menu") + translationManager.emptyString
                btnNext.text: appWindow.width <= 760 ? qsTr("Browse") : qsTr("Browse filesystem") + translationManager.emptyString
                btnNext.width: appWindow.width <= 506 ? 80 : appWindow.width <= 760 ? 120 : 330
                btnNext.visible: true
                btnPrevKeyNavigationBackTab: recentList.itemAt(recentList.count - 1)
                btnNextKeyNavigationTab: openWalletFromFileHeader

                onPrevClicked: {
                    wizardStateView.state = "wizardHome";
                }
                onNextClicked: {
                    wizardController.openWallet();
                }
            }
        }
    }

    function onPageCompleted(previousView){
        if(previousView.viewName == "wizardHome"){
            walletKeysFilesModel.refresh(appWindow.accountsDir);
            wizardOpenWallet1.walletCount = walletKeysFilesModel.rowCount();
            flow._height = flow.calcHeight();
        }
    }
}
