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
    enabled: appWindow.scheduledRunningId === ""
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

    property bool trimming: false
    function trimEmptyAccounts() {
        // mined addresses do not need their account: they are watched one by one
        var keep = 1;
        confirmationDialog.title = qsTr("Remove empty accounts") + translationManager.emptyString;
        confirmationDialog.text = qsTr("Removes the accounts at the end of the list that never received or sent anything, with their names. Accounts are numbered, so an empty one between used accounts stays. Your funds and history do not change.") + translationManager.emptyString
            + "\n\n" + qsTr("Mined addresses are not affected: they stay in the mined addresses account.") + translationManager.emptyString;
        confirmationDialog.okText = qsTr("Remove") + translationManager.emptyString;
        confirmationDialog.cancelText = qsTr("Cancel") + translationManager.emptyString;
        confirmationDialog.onAcceptedCallback = function() {
            var w = appWindow.currentWallet;
            if (!w || trimming) return;
            trimming = true;
            w.trimUnusedAccountsAsync(keep, function(removed, left, error) {
                trimming = false;
                if (w.currentSubaddressAccount >= left)
                    w.switchSubaddressAccount(0);
                // their scanning keys went with the removed accounts: watch them again
                appWindow.rewatchMinedAddresses(w);
                w.subaddressAccount.getAll();
                w.subaddress.refresh(w.currentSubaddressAccount);
                w.startRefresh();
                if (error) {
                    appWindow.showStatusMessage(qsTr("Could not remove the accounts: %1").arg(error) + translationManager.emptyString, 8);
                    return;
                }
                appWindow.onWalletUpdate();
                appWindow.showStatusMessage(removed > 0 ? qsTr("%1 empty accounts removed, %2 left").arg(removed).arg(left) + translationManager.emptyString
                                                        : qsTr("No empty accounts at the end of the list") + translationManager.emptyString, 5);
            });
        };
        confirmationDialog.onRejectedCallback = null;
        confirmationDialog.open();
    }

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

                MoneroComponents.CheckBox {
                    id: hideEmptyCheckBox
                    Layout.preferredWidth: hideEmptyCheckBox.width
                    Layout.rightMargin: 16
                    text: qsTr("Hide empty accounts") + translationManager.emptyString
                    fontSize: 13
                    checked: persistentSettings.hideEmptyAccounts
                    onClicked: persistentSettings.hideEmptyAccounts = !persistentSettings.hideEmptyAccounts
                }

                // Wallet+: the empty accounts at the end of the list go away for good (core fork
                // trim_unused_subaddress_accounts); accounts that ever received or sent stay
                MoneroComponents.StandardButton {
                    id: trimAccountsButton
                    visible: !selectAndSend && appWindow.currentWallet && subaddressAccountListView.count > 1
                    Layout.rightMargin: 12
                    small: true
                    primary: false
                    enabled: !pageAccount.trimming
                    text: (pageAccount.trimming ? qsTr("Removing…") : qsTr("Remove empty accounts")) + translationManager.emptyString
                    fontSize: 13
                    onClicked: pageAccount.trimEmptyAccounts()
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
                // empty accounts hidden: the first and the selected one always stay
                property int balanceTick: 0
                function isHidden(i) {
                    return persistentSettings.hideEmptyAccounts && i !== 0 && i !== currentAccountIndex
                           && appWindow.currentWallet && appWindow.currentWallet.balance(i) === 0;
                }
                readonly property int shownCount: {
                    balanceTick;
                    var n = 0;
                    for (var i = 0; i < subaddressAccountListView.count; ++i)
                        if (!isHidden(i)) n++;
                    return n;
                }
                // a non-interactive full-height list builds every row at once and freezes the window (many
                // accounts after saving a far mined address), so long lists scroll inside a fixed height and
                // only the visible rows exist
                // the list takes the window height left below the header (minus the mined row) and scrolls
                // inside it when the accounts do not fit
                readonly property int rowHeight: subaddressAccountListItemHeight + subaddressAccountListSpacing
                readonly property int fitRows: Math.max(5, Math.floor((middlePanel.flickable.height - 80 - addressRow.y - y
                                                                       - (minedAccountRow.visible ? 50 : 0) - 1) / rowHeight))
                readonly property bool longList: shownCount > fitRows
                Layout.preferredHeight: rowHeight * (longList ? fitRows : shownCount)
                visible: subaddressAccountListView.count >= 1

                Connections {
                    target: appWindow.currentWallet
                    ignoreUnknownSignals: true
                    function onUpdated() { subaddressAccountListRow.balanceTick++; }
                }

                ListView {
                    id: subaddressAccountListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: ListView.StopAtBounds
                    interactive: subaddressAccountListRow.longList
                    reuseItems: true
                    ScrollBar.vertical: ScrollBar { policy: subaddressAccountListRow.longList ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
                    currentIndex: currentAccountIndex

                    // the spacing lives in each delegate, so a hidden row leaves no gap
                    spacing: 0
                    delegate: Item {
                      readonly property bool hiddenRow: (subaddressAccountListRow.balanceTick, subaddressAccountListRow.isHidden(index))
                      width: subaddressAccountListView.width
                      height: hiddenRow ? 0 : subaddressAccountListRow.subaddressAccountListItemHeight + subaddressAccountListRow.subaddressAccountListSpacing
                      visible: !hiddenRow
                      MoneroComponents.AccountRow {
                        width: subaddressAccountListView.width
                        height: subaddressAccountListRow.subaddressAccountListItemHeight
                        accountIndex: index
                        label: model.label
                        address: TxUtils.addressTruncatePretty(model.address, mainLayout.width < 740 ? 1 : (mainLayout.width < 900 ? 2 : 3))
                        // without its mined addresses (they show in the mined addresses account)
                        readonly property string ownBalance: (subaddressAccountListRow.balanceTick, appWindow.minedAddressesTick, appWindow.currentWallet ? walletManager.displayAmount(appWindow.currentWallet.balance(index)) : model.balance)
                        balance: (persistentSettings.hideBalance ? model.balance : ownBalance) + " XMR"
                        fiat: persistentSettings.fiatPriceEnabled
                              ? "≈ " + pageAccount.fiatOf(ownBalance) + " " + appWindow.fiatApiCurrencySymbol()
                              : ""
                        selected: index === currentAccountIndex && !appWindow.minedAccountActive
                        editTooltip: qsTr("Edit account label") + translationManager.emptyString

                        onClicked: {
                            appWindow.selectMinedAccount(false);
                            appWindow.currentWallet.switchSubaddressAccount(index);
                            if (selectAndSend)
                                appWindow.showPageRequest("Transfer");
                        }
                        onEditClicked: pageAccount.renameSubaddressAccountLabel(index)
                      }
                    }

                    onCurrentIndexChanged: {
                        appWindow.onWalletUpdate();
                    }
                }
            }

            // Wallet+ "mined addresses account": addresses watched one by one (pages/CustomAddresses.qml),
            // selected like any other account; the edit button opens its page
            MoneroComponents.AccountRow {
                id: minedAccountRow
                readonly property int count: (appWindow.minedAddressesTick, appWindow.currentWallet ? appWindow.minedAddresses().length : 0)
                // balance of the mined addresses (+ change at address 0 of their missing accounts)
                readonly property string total: {
                    subaddressAccountListRow.balanceTick;
                    var w = appWindow.currentWallet;
                    if (!w || count === 0) return "";
                    var list = appWindow.minedAddresses(), nAcc = w.numSubaddressAccounts(), seen = {}, t = 0;
                    for (var i = 0; i < list.length; ++i) {
                        var k = list[i].account + ":" + list[i].index;
                        if (!seen[k]) { seen[k] = true; t += w.addressBalance(list[i].account, list[i].index, false); }
                    }
                    return walletManager.displayAmount(t);
                }
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.preferredHeight: 44
                visible: count > 0 && !selectAndSend
                accountIndex: 0
                badge: "⛏"
                customColor: MoneroComponents.Style.blackTheme ? "#3B9EFF" : "#1F62C9"
                label: qsTr("Mined addresses") + translationManager.emptyString
                address: qsTr("%1 addresses").arg(count) + translationManager.emptyString
                balance: (persistentSettings.hideBalance ? "?.??" : total) + " XMR"
                fiat: persistentSettings.fiatPriceEnabled && total !== ""
                      ? "≈ " + pageAccount.fiatOf(total) + " " + appWindow.fiatApiCurrencySymbol()
                      : ""
                selected: appWindow.minedAccountActive
                editTooltip: qsTr("Open the mined addresses page") + translationManager.emptyString
                onClicked: appWindow.selectMinedAccount(true)
                onEditClicked: appWindow.showPageRequest("CustomAddresses")
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

            subaddressAccountListRow.balanceTick++;
            balanceRow.balanceText = walletManager.displayAmount(appWindow.currentWallet.balanceAll()) + " XMR"
            balanceRow.unlockedText = walletManager.displayAmount(appWindow.currentWallet.unlockedBalanceAll()) + " XMR"
        }
    }

    function onPageClosed() {
        selectAndSend = false;
    }
}
