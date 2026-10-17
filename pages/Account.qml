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
import QtQuick.Dialogs

import FontAwesome

import "../components" as MoneroComponents
import "../components/effects/" as MoneroEffects

import moneroComponents.Clipboard 1.0
import moneroComponents.Wallet 1.0
import moneroComponents.WalletManager 1.0
import moneroComponents.TransactionHistory 1.0
import moneroComponents.TransactionHistoryModel 1.0
import "../js/TxUtils.js" as TxUtils

Rectangle {
    id: pageAccount
    color: "transparent"
    property var model
    property alias accountHeight: mainLayout.height
    property alias balanceAllText: balanceRow.balanceText
    property alias unlockedBalanceAllText: balanceRow.unlockedText
    property bool selectAndSend: false
    property int currentAccountIndex

    // fiat value of an "<amount> XMR" string, same conversion as the Send page
    function fiatOf(xmrText) {
        if (!persistentSettings.fiatPriceEnabled || persistentSettings.hideBalance || appWindow.fiatPrice <= 0)
            return "?.??";
        var amount = parseFloat(xmrText);
        return isNaN(amount) ? "?.??" : appWindow.fiatApiConvertToFiat(amount);
    }

    function renameSubaddressAccountLabel(_index){
        inputDialog.labelText = qsTr("Set the label of the selected account:") + translationManager.emptyString;
        inputDialog.onAcceptedCallback = function() {
            appWindow.currentWallet.setSubaddressLabel(_index, 0, inputDialog.inputText)
            appWindow.currentWallet.subaddressAccount.refresh()
        }
        inputDialog.onRejectedCallback = null;
        inputDialog.open(appWindow.currentWallet.getSubaddressLabel(_index, 0))
    }

    Clipboard { id: clipboard }

    /* main layout */
    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right

        spacing: 20

        MoneroComponents.BalanceCard {
            id: balanceRow
            visible: !selectAndSend
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            titleText: qsTr("Balance All") + translationManager.emptyString
            unlockedLabel: qsTr("Total unlocked balance: ") + translationManager.emptyString
            fiatEnabled: persistentSettings.fiatPriceEnabled
            fiatSymbol: persistentSettings.fiatPriceEnabled ? appWindow.fiatApiCurrencySymbol() : ""
            fiatTotal: pageAccount.fiatOf(balanceText)
            // clicking the chip switches the app currency between USD and the last other one
            chipToggleable: fiatEnabled
            onChipClicked: appWindow.fiatApiToggleUsd()
            fiatUnlocked: pageAccount.fiatOf(unlockedText)
            priceText: appWindow.fiatPrice > 0 ? appWindow.fiatPrice.toFixed(2) : "?.??"
            priceBtcText: persistentSettings.fiatPriceEnabled && appWindow.priceBtc > 0 ? appWindow.priceBtc.toFixed(8) : ""
            btcTotal: {
                if (!persistentSettings.fiatPriceEnabled || persistentSettings.hideBalance || !(appWindow.priceBtc > 0))
                    return "";
                var amount = parseFloat(balanceText);
                return isNaN(amount) ? "" : (amount * appWindow.priceBtc).toFixed(8);
            }
            change7d: appWindow.fiatChange7d
            change24h: appWindow.fiatChange24h
            change24hLabel: qsTr("24h change") + translationManager.emptyString
            priceLabel: qsTr("Price") + translationManager.emptyString
            changeLabel: qsTr("7-day change") + translationManager.emptyString
            onCopyRequested: (amount) => {
                console.log("Copied to clipboard");
                clipboard.setText(amount);
                appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
            }
        }

        ColumnLayout {
            id: addressRow
            spacing: 0

            RowLayout {
                spacing: 0

                MoneroComponents.LabelSubheader {
                    Layout.fillWidth: true
                    fontSize: 24
                    textFormat: Text.RichText
                    text: qsTr("Accounts") + translationManager.emptyString
                }

                MoneroComponents.StandardButton {
                    id: createNewAccountButton
                    visible: !selectAndSend
                    small: true
                    text: qsTr("Create new account") + translationManager.emptyString
                    fontSize: 13
                    onClicked: {
                        inputDialog.labelText = qsTr("Set the label of the new account:") + translationManager.emptyString
                        inputDialog.onAcceptedCallback = function() {
                            appWindow.currentWallet.subaddressAccount.addRow(inputDialog.inputText)
                            appWindow.currentWallet.switchSubaddressAccount(appWindow.currentWallet.numSubaddressAccounts() - 1)
                            appWindow.onWalletUpdate();
                        }
                        inputDialog.onRejectedCallback = null;
                        inputDialog.open()
                    }

                    Rectangle {
                        anchors.top: createNewAccountButton.bottom
                        anchors.topMargin: 8
                        anchors.left: createNewAccountButton.left
                        anchors.right: createNewAccountButton.right
                        height: 2
                        color: MoneroComponents.Style.appWindowBorderColor

                        MoneroEffects.ColorTransition {
                            targetObj: parent
                            blackColor: MoneroComponents.Style._b_appWindowBorderColor
                            whiteColor: MoneroComponents.Style._w_appWindowBorderColor
                        }
                    }
                }
            }

            ColumnLayout {
                id: subaddressAccountListRow
                property int subaddressAccountListItemHeight: 44
                property int subaddressAccountListSpacing: 6
                Layout.topMargin: 14
                Layout.fillWidth: true
                Layout.minimumWidth: 240
                Layout.preferredHeight: (subaddressAccountListItemHeight + subaddressAccountListSpacing) * subaddressAccountListView.count
                visible: subaddressAccountListView.count >= 1

                ListView {
                    id: subaddressAccountListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: ListView.StopAtBounds
                    interactive: false
                    currentIndex: currentAccountIndex

                    spacing: subaddressAccountListRow.subaddressAccountListSpacing
                    delegate: MoneroComponents.AccountRow {
                        width: subaddressAccountListView.width
                        height: subaddressAccountListRow.subaddressAccountListItemHeight
                        accountIndex: index
                        label: model.label
                        address: TxUtils.addressTruncatePretty(model.address, mainLayout.width < 740 ? 1 : (mainLayout.width < 900 ? 2 : 3))
                        balance: model.balance + " XMR"
                        fiat: persistentSettings.fiatPriceEnabled
                              ? "≈ " + pageAccount.fiatOf(model.balance) + " " + appWindow.fiatApiCurrencySymbol()
                              : ""
                        selected: index === currentAccountIndex
                        editTooltip: qsTr("Edit account label") + translationManager.emptyString

                        onClicked: {
                            appWindow.currentWallet.switchSubaddressAccount(index);
                            if (selectAndSend)
                                appWindow.showPageRequest("Transfer");
                        }
                        onEditClicked: pageAccount.renameSubaddressAccountLabel(index)
                    }

                    onCurrentIndexChanged: {
                        appWindow.onWalletUpdate();
                    }
                }
            }

            Rectangle {
                color: MoneroComponents.Style.appWindowBorderColor
                Layout.fillWidth: true
                height: 1

                MoneroEffects.ColorTransition {
                    targetObj: parent
                    blackColor: MoneroComponents.Style._b_appWindowBorderColor
                    whiteColor: MoneroComponents.Style._w_appWindowBorderColor
                }
            }
        }
    }

    function onPageCompleted() {
        console.log("account");
        if (appWindow.currentWallet !== undefined) {
            appWindow.currentWallet.subaddressAccount.refresh();
            subaddressAccountListView.model = appWindow.currentWallet.subaddressAccountModel;
            appWindow.currentWallet.subaddress.refresh(appWindow.currentWallet.currentSubaddressAccount)

            balanceRow.balanceText = walletManager.displayAmount(appWindow.currentWallet.balanceAll()) + " XMR"
            balanceRow.unlockedText = walletManager.displayAmount(appWindow.currentWallet.unlockedBalanceAll()) + " XMR"
        }
    }

    function onPageClosed() {
        selectAndSend = false;
    }
}
