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
import moneroComponents.Wallet 1.0
import moneroComponents.NetworkType 1.0
import moneroComponents.Clipboard 1.0

import "components" as MoneroComponents
import "js/Utils.js" as Utils
import "components/effects/" as MoneroEffects

Rectangle {
    id: panel

    property int currentAccountIndex
    property alias currentAccountLabel: accountLabel.text
    property string balanceString: "?.??"
    property string balanceUnlockedString: "?.??"
    property string balanceFiatString: "?.??"
    property string minutesToUnlock: ""
    property bool isSyncing: false
    property alias networkStatus : networkStatus
    property alias progressBar : progressBar
    property alias daemonProgressBar : daemonProgressBar

    property int titleBarHeight: 50
    property string copyValue: ""
    Clipboard { id: clipboard }

    signal historyClicked()
    signal transferClicked()
    signal receiveClicked()
    signal advancedClicked()
    signal settingsClicked()
    signal addressBookClicked()
    signal accountClicked()
    signal swapsClicked()
    signal tradingClicked()
    signal notesClicked()
    signal walletPlusClicked()
    signal securityClicked()
    signal trezorClicked()

    function selectItem(pos) {
        menuColumn.previousButton.checked = false
        if(pos === "History") menuColumn.previousButton = historyButton
        else if(pos === "Transfer") menuColumn.previousButton = transferButton
        else if(pos === "Receive")  menuColumn.previousButton = receiveButton
        else if(pos === "AddressBook") menuColumn.previousButton = addressBookButton
        else if(pos === "Settings") menuColumn.previousButton = settingsButton
        else if(pos === "Advanced") menuColumn.previousButton = advancedButton
        else if(pos === "Account") menuColumn.previousButton = accountButton
        else if(pos === "Swaps") menuColumn.previousButton = swapsButton
        else if(pos === "Trading") menuColumn.previousButton = tradingButton
        else if(pos === "Notes") menuColumn.previousButton = notesButton
        else if(pos === "WalletPlus") menuColumn.previousButton = walletPlusButton
        else if(pos === "Security") menuColumn.previousButton = securityButton
        else if(pos === "Trezor") menuColumn.previousButton = trezorButton
        menuColumn.previousButton.checked = true
    }

    width: 300
    color: "transparent"
    anchors.bottom: parent.bottom
    anchors.top: parent.top

    MoneroEffects.GradientBackground {
        anchors.fill: parent
        fallBackColor: MoneroComponents.Style.middlePanelBackgroundColor
        initialStartColor: MoneroComponents.Style.leftPanelBackgroundGradientStart
        initialStopColor: MoneroComponents.Style.leftPanelBackgroundGradientStop
        blackColorStart: MoneroComponents.Style._b_leftPanelBackgroundGradientStart
        blackColorStop: MoneroComponents.Style._b_leftPanelBackgroundGradientStop
        whiteColorStart: MoneroComponents.Style._w_leftPanelBackgroundGradientStart
        whiteColorStop: MoneroComponents.Style._w_leftPanelBackgroundGradientStop
        posStart: 0.6
        start: Qt.point(0, 0)
        end: Qt.point(height, width)
    }

    // card with monero logo
    Column {
        visible: true
        z: 2
        id: column1
        height: 175
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: (persistentSettings.customDecorations)? 50 : 0

        Item {
            width: parent.width
            height: parent.height

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.leftMargin: 20
                height: 490
                width: 260

                Image {
                    id: card
                    visible: GraphicsInfo.api === GraphicsInfo.Software || MoneroComponents.Style.blackTheme
                    width: 260
                    height: 135
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:///images/card-matrix-" + (MoneroComponents.Style.blackTheme ? "dark" : "light") + (currentAccountIndex % 8) + ".png"
                }

                MultiEffect {
                    visible: GraphicsInfo.api !== GraphicsInfo.Software && !MoneroComponents.Style.blackTheme
                    anchors.fill: card
                    source: card
                    shadowEnabled: true
                    shadowHorizontalOffset: 3
                    shadowVerticalOffset: 3
                    shadowBlur: 0.625
                    blurMax: 16
                    shadowColor: "#3B000000"
                }

                MoneroComponents.TextPlain {
                    id: testnetLabel
                    visible: persistentSettings.nettype != NetworkType.MAINNET
                    text: (persistentSettings.nettype == NetworkType.TESTNET ? qsTr("Testnet") : qsTr("Stagenet")) + translationManager.emptyString
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 192
                    font.bold: true
                    font.pixelSize: 12
                    color: "#f33434"
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    id: viewOnlyLabel
                    visible: viewOnly
                    text: qsTr("View Only") + translationManager.emptyString
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.right: testnetLabel.visible ? testnetLabel.left : parent.right
                    anchors.rightMargin: 8
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ff9323"
                    themeTransition: false
                }
            }

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.leftMargin: 20
                height: 490
                width: 50

                MoneroComponents.Label {
                    fontSize: 12
                    id: accountIndex
                    text: qsTr("Account") + translationManager.emptyString + " #" + currentAccountIndex
                    color: MoneroComponents.Style.blackTheme ? "white" : "black"
                    anchors.left: parent.left
                    anchors.leftMargin: 60
                    anchors.top: parent.top
                    anchors.topMargin: 23
                    themeTransition: false

                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appWindow.showPageRequest("Account")
                    }
                }

                MoneroComponents.Label {
                    fontSize: 16
                    id: accountLabel
                    textWidth: 170
                    color: MoneroComponents.Style.blackTheme ? "white" : "black"
                    anchors.left: parent.left
                    anchors.leftMargin: 60
                    anchors.top: parent.top
                    anchors.topMargin: 36
                    themeTransition: false
                    elide: Text.ElideRight

                    MouseArea {
                        hoverEnabled: true
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appWindow.showPageRequest("Account")
                    }
                }

                MoneroComponents.Label {
                    fontSize: 16
                    visible: isSyncing
                    text: qsTr("Syncing...") + translationManager.emptyString
                    color: MoneroComponents.Style.blackTheme ? "white" : "black"
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.bottom: currencyLabel.top
                    anchors.bottomMargin: 15
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    id: currencyLabel
                    font.pixelSize: 16
                    text: {
                        if (persistentSettings.fiatPriceEnabled && persistentSettings.fiatPriceToggle) {
                            return appWindow.fiatApiCurrencySymbol();
                        } else {
                            return "XMR"
                        }
                    }
                    color: MoneroComponents.Style.blackTheme ? "white" : "black"
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.top: parent.top
                    anchors.topMargin: 100
                    themeTransition: false

                    MouseArea {
                        hoverEnabled: true
                        anchors.fill: parent
                        visible: persistentSettings.fiatPriceEnabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: persistentSettings.fiatPriceToggle = !persistentSettings.fiatPriceToggle
                    }
                }

                MoneroComponents.TextPlain {
                    id: balancePart1
                    text: balancePart1Fx.output
                    MoneroComponents.DecryptFx { id: balancePart1Fx; source: Utils.prettyAmount(balancePart1.realText) }
                    themeTransition: false
                    anchors.left: parent.left
                    anchors.leftMargin: 58
                    anchors.baseline: currencyLabel.baseline
                    color: MoneroComponents.Style.blackTheme ? "white" : "black"
                    Binding on color {
                        when: balancePart1MouseArea.containsMouse || balancePart2MouseArea.containsMouse
                        value: MoneroComponents.Style.textAccent
                    }
                    property string realText: {
                        if (persistentSettings.fiatPriceEnabled && persistentSettings.fiatPriceToggle) {
                            return balanceFiatString.split('.')[0] + "."
                        } else {
                            return balanceString.split('.')[0] + "."
                        }
                    }
                    font.pixelSize: {
                        var defaultSize = 29;
                        var digits = (balancePart1.realText.length - 1)
                        if (digits > 2 && !(persistentSettings.fiatPriceEnabled && persistentSettings.fiatPriceToggle)) {
                            return defaultSize - 1.1 * digits
                        } else {
                            return defaultSize
                        }
                    }
                    MouseArea {
                        id: balancePart1MouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                                console.log("Copied to clipboard");
                                clipboard.setText(balancePart1.realText + balancePart2.realText);
                                appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
                        }
                    }
                }
                MoneroComponents.TextPlain {
                    id: balancePart2
                    text: balancePart2Fx.output
                    MoneroComponents.DecryptFx { id: balancePart2Fx; source: String(balancePart2.realText).slice(0, 3) }
                    themeTransition: false
                    anchors.left: balancePart1.right
                    anchors.leftMargin: 2
                    anchors.baseline: currencyLabel.baseline
                    color: balancePart1.color
                    property string realText: {
                        if (persistentSettings.fiatPriceEnabled && persistentSettings.fiatPriceToggle) {
                            return balanceFiatString.split('.')[1]
                        } else {
                            return balanceString.split('.')[1]
                        }
                    }
                    font.pixelSize: 16
                    MouseArea {
                        id: balancePart2MouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => balancePart1MouseArea.clicked(mouse)
                    }
                }
                MoneroComponents.TextPlain {
                    id: balancePart3
                    text: balancePart3Fx.output
                    MoneroComponents.DecryptFx { id: balancePart3Fx; source: String(balancePart2.realText).slice(3) }
                    themeTransition: false
                    anchors.left: balancePart2.right
                    anchors.baseline: currencyLabel.baseline
                    color: balancePart1.color
                    font.pixelSize: 11
                    MouseArea {
                        hoverEnabled: true
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => balancePart1MouseArea.clicked(mouse)
                    }
                }

                Item { //separator
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                }
            }
        }
    }

    Rectangle {
        id: menuRect
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: column1.bottom
        color: "transparent"

        Flickable {
            id:flicker
            contentHeight: menuColumn.height
            anchors.top: parent.top
            anchors.bottom: separator.top
            width: parent.width
            boundsBehavior: isMac ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds
            clip: true

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            clip: true
            property var previousButton: transferButton

            // top border
            MoneroComponents.MenuButtonDivider {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Account tab ---------------
            MoneroComponents.MenuButton {
                id: accountButton
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Account") + translationManager.emptyString
                symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "T" + translationManager.emptyString

                onClicked: {
                    parent.previousButton.checked = false
                    parent.previousButton = accountButton
                    panel.accountClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: accountButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Transfer tab ---------------
            MoneroComponents.MenuButton {
                id: transferButton
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Send") + translationManager.emptyString
                symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "S" + translationManager.emptyString
                onClicked: {
                    parent.previousButton.checked = false
                    parent.previousButton = transferButton
                    panel.transferClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: transferButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- AddressBook tab ---------------

            MoneroComponents.MenuButton {
                id: addressBookButton
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Address book") + translationManager.emptyString
                symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "B" + translationManager.emptyString
                under: transferButton
                onClicked: {
                    parent.previousButton.checked = false
                    parent.previousButton = addressBookButton
                    panel.addressBookClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: addressBookButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Receive tab ---------------
            MoneroComponents.MenuButton {
                id: receiveButton
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Receive") + translationManager.emptyString
                symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "R" + translationManager.emptyString
                onClicked: {
                    parent.previousButton.checked = false
                    parent.previousButton = receiveButton
                    panel.receiveClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: receiveButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- History tab ---------------

            MoneroComponents.MenuButton {
                id: historyButton
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Transactions") + translationManager.emptyString
                symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "H" + translationManager.emptyString
                onClicked: {
                    parent.previousButton.checked = false
                    parent.previousButton = historyButton
                    panel.historyClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: historyButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Advanced tab ---------------
            MoneroComponents.MenuButton {
                id: advancedButton
                visible: appWindow.walletMode >= 2
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Advanced") + translationManager.emptyString
                symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "D" + translationManager.emptyString
                onClicked: {
                    parent.previousButton.checked = false
                    parent.previousButton = advancedButton
                    panel.advancedClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: advancedButton.present && appWindow.walletMode >= 2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Settings tab ---------------
            MoneroComponents.MenuButton {
                id: settingsButton
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Settings") + translationManager.emptyString
                symbol: (isMac ? "⌃" : qsTr("Ctrl+")) + "E" + translationManager.emptyString
                onClicked: {
                    parent.previousButton.checked = false
                    parent.previousButton = settingsButton
                    panel.settingsClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: settingsButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Wallet+ section (Trading data, Swaps, Notes) ---------------
            // set apart from the wallet pages by a gap and a blue line
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 22

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: "#3B9EFF"
                    opacity: 0.55
                }
            }

            MoneroComponents.MenuButton {
                id: walletPlusButton
                anchors.left: parent.left
                anchors.right: parent.right
                blueAccent: true
                text: "Wallet+"
                onClicked: {
                    menuColumn.previousButton.checked = false
                    menuColumn.previousButton = walletPlusButton
                    panel.walletPlusClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: tradingButton.visible && tradingButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Trading data (subsection of Wallet+) ---------------
            MoneroComponents.MenuButton {
                id: tradingButton
                anchors.left: parent.left
                anchors.right: parent.right
                // price charts and swaps need the price connections; Notes stays available
                visible: persistentSettings.fiatPriceEnabled
                blueAccent: true
                under: walletPlusButton
                text: qsTr("Markets") + translationManager.emptyString
                onClicked: {
                    menuColumn.previousButton.checked = false
                    menuColumn.previousButton = tradingButton
                    panel.tradingClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: swapsButton.visible && swapsButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Swaps (subsection of Wallet+) ---------------
            MoneroComponents.MenuButton {
                id: swapsButton
                anchors.left: parent.left
                anchors.right: parent.right
                blueAccent: true
                text: qsTr("Swaps") + translationManager.emptyString
                visible: persistentSettings.fiatPriceEnabled
                under: walletPlusButton
                onClicked: {
                    menuColumn.previousButton.checked = false
                    menuColumn.previousButton = swapsButton
                    panel.swapsClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: notesButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Notes (subsection of Wallet+, encrypted) ---------------
            MoneroComponents.MenuButton {
                id: notesButton
                anchors.left: parent.left
                anchors.right: parent.right
                blueAccent: true
                text: qsTr("Notes") + translationManager.emptyString
                under: walletPlusButton
                onClicked: {
                    menuColumn.previousButton.checked = false
                    menuColumn.previousButton = notesButton
                    panel.notesClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: securityButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Security (subsection of Wallet+) ---------------
            MoneroComponents.MenuButton {
                id: securityButton
                anchors.left: parent.left
                anchors.right: parent.right
                blueAccent: true
                text: qsTr("Security") + translationManager.emptyString
                under: walletPlusButton
                onClicked: {
                    menuColumn.previousButton.checked = false
                    menuColumn.previousButton = securityButton
                    panel.securityClicked()
                }
            }

            MoneroComponents.MenuButtonDivider {
                visible: trezorButton.present
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
            }

            // ------------- Trezor (subsection of Wallet+, device customization) ---------------
            MoneroComponents.MenuButton {
                id: trezorButton
                anchors.left: parent.left
                anchors.right: parent.right
                blueAccent: true
                text: "Trezor"
                under: walletPlusButton
                onClicked: {
                    menuColumn.previousButton.checked = false
                    menuColumn.previousButton = trezorButton
                    panel.trezorClicked()
                }
            }
        } // Column

        } // Flickable

        Rectangle {
            id: separator
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            anchors.bottom: progressBar.visible ? progressBar.top : networkStatus.top
            height: 10
            color: "transparent"
        }

        MoneroComponents.ProgressBar {
            id: progressBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: daemonProgressBar.top
            height: 48
            syncType: qsTr("Wallet") + translationManager.emptyString
            visible: !appWindow.disconnected
        }

        MoneroComponents.ProgressBar {
            id: daemonProgressBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: networkStatus.top
            syncType: qsTr("Daemon") + translationManager.emptyString
            visible: !appWindow.disconnected
            height: 62
        }
        
        MoneroComponents.NetworkStatusItem {
            id: networkStatus
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            connected: Wallet.ConnectionStatus_Disconnected
            height: 48
        }
    }
}
