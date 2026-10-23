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

import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import FontAwesome

import moneroComponents.Clipboard 1.0
import moneroComponents.PendingTransaction 1.0
import moneroComponents.Wallet 1.0
import moneroComponents.NetworkType 1.0
import "../components"
import "../components" as MoneroComponents
import "." 1.0
import "../js/TxUtils.js" as TxUtils
import "../js/Utils.js" as Utils


Rectangle {
    id: root
    signal paymentClicked(var recipients, string paymentId, int mixinCount, int priority, string description)
    signal sweepUnmixableClicked()

    color: "transparent"
    property alias transferHeight1: pageRoot.height
    property alias transferHeight2: advancedLayout.height
    property int mixin: 15  // (ring size 16)
    property string warningContent: ""
    property string sendButtonWarning: {
        // Currently opened wallet is not view-only
        if (appWindow.viewOnly) {
            return qsTr("Wallet is view-only and sends are only possible by using offline transaction signing. " +
                        "Unless key images are imported, the balance reflects only incoming but not outgoing transactions.") + translationManager.emptyString;
        }

        // There are sufficient unlocked funds available
        if (recipientModel.getAmountTotal() > appWindow.getUnlockedBalance()) {
            return qsTr("Amount is more than unlocked balance.") + translationManager.emptyString;
        }

        if (!recipientModel.hasEmptyAddress()) {
            // Address is valid
            if (recipientModel.hasInvalidAddress()) {
                return qsTr("Address is invalid.") + translationManager.emptyString;
            }

            // Amount is nonzero
            if (recipientModel.hasEmptyAmount()) {
                return qsTr("Enter an amount.") + translationManager.emptyString;
            }
        }

        return "";
    }
    property string startLinkText: "<style type='text/css'>a {text-decoration: none; color: #FF6C3C; font-size: 14px;}</style><a href='#'>(%1)</a>".arg(qsTr("Start daemon")) + translationManager.emptyString
    property bool warningLongPidDescription: descriptionLine.text.match(/^[0-9a-f]{64}$/i)
    property bool paymentIdBlocked: paymentIdCheckbox.checked || warningLongPidDescription
    property bool hasTransferWarnings: warningContent !== "" || paymentIdBlocked
    property bool hasValidTransferInfo: !recipientModel.hasEmptyAddress()
                                     && !recipientModel.hasEmptyAmount()
                                     && !recipientModel.hasInvalidAddress()
                                     && recipientModel.getAmountTotal() <= appWindow.getUnlockedBalance()
    property bool canSendTransaction: !sendButtonWarningBox.visible
                                   && !hasTransferWarnings
                                   && hasValidTransferInfo
    property bool canCreateOfflineTx: appWindow.viewOnly
                                   && appWindow.daemonSynced
                                   && !hasTransferWarnings
                                   && hasValidTransferInfo

    Clipboard { id: clipboard }

    // "Now" / "Date and time" buttons of the schedule card
    component ScheduleOption: Rectangle {
        id: scheduleOption
        property string label: ""
        property bool selected: false
        signal picked()
        readonly property color accent: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
        implicitWidth: Math.max(80, optionText.implicitWidth + 28)
        implicitHeight: 30
        radius: 3
        color: selected ? Qt.rgba(accent.r, accent.g, accent.b, 0.22) : (optionMouse.containsMouse ? (MoneroComponents.Style.blackTheme ? "#14FFFFFF" : "#14000000") : "transparent")
        border.width: 1
        border.color: selected ? accent : Qt.rgba(MoneroComponents.Style.defaultFontColor.r, MoneroComponents.Style.defaultFontColor.g, MoneroComponents.Style.defaultFontColor.b, 0.25)
        MoneroComponents.TextPlain {
            id: optionText
            anchors.centerIn: parent
            text: scheduleOption.label
            font.family: MoneroComponents.Style.fontMonoMedium.name
            font.pixelSize: 13
            font.bold: scheduleOption.selected
            color: MoneroComponents.Style.defaultFontColor
            themeTransition: false
        }
        MouseArea {
            id: optionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!scheduleOption.selected) scheduleOption.picked()
        }
    }

    function oa_message(text) {
      oaPopup.title = qsTr("OpenAlias error") + translationManager.emptyString
      oaPopup.text = text
      oaPopup.onCloseCallback = null
      oaPopup.open()
    }

    function oa_confirm(openAlias, resolvedAddress, onAccepted) {
      confirmationDialog.title = qsTr("OpenAlias warning") + translationManager.emptyString
      confirmationDialog.text = qsTr("Address found, but the DNSSEC signatures could not be verified, so this address may be spoofed.") + "\n\n" +
                                qsTr("OpenAlias: ") + openAlias + "\n\n" +
                                qsTr("Resolved address: ") + resolvedAddress + "\n\n" +
                                qsTr("Only use this address if you trust this OpenAlias result.") + translationManager.emptyString
      confirmationDialog.cancelText = qsTr("Cancel") + translationManager.emptyString
      confirmationDialog.okText = qsTr("Use address") + translationManager.emptyString
      confirmationDialog.onAcceptedCallback = onAccepted
      confirmationDialog.onRejectedCallback = null
      confirmationDialog.open()
    }

    // Wallet+: "addr,addr,..." or "addr:amount,addr:amount,..." (a group copied from Receive) -> one row per address
    function parseMultipleRecipients(text) {
        var parts = text.split(/[\s,;]+/).filter(function(p) { return p !== ""; });
        if (parts.length < 2 || parts.length > recipientModel.maxRecipients)
            return null;
        var list = [];
        for (var k = 0; k < parts.length; ++k) {
            var m = parts[k].match(/^([0-9A-Za-z]+)(?::([0-9]*\.?[0-9]+))?$/);
            if (!m || !walletManager.addressValid(m[1], appWindow.persistentSettings.nettype))
                return null;
            list.push({ address: m[1], amount: m[2] !== undefined ? m[2] : "" });
        }
        return list;
    }
    function fillMultipleRecipients(list) {
        recipientModel.clear();
        for (var k = 0; k < list.length; ++k)
            recipientModel.append(list[k]);
        appWindow.showStatusMessage(qsTr("%1 recipients filled in").arg(list.length) + translationManager.emptyString, 4);
    }

    function fillPaymentDetails(address, payment_id, amount, tx_description, recipient_name) {
        if (recipientModel.count > 0) {
            const last = recipientModel.count - 1;
            if (recipientModel.get(recipientModel.count - 1).address == "") {
                recipientModel.remove(last);
            }
        }

        recipientModel.newRecipient(address, Utils.removeTrailingZeros(amount || ""));
        setPaymentId(payment_id || "");
        setDescription((recipient_name ? recipient_name + (tx_description ? " (" + tx_description + ")" : "") : (tx_description || "")));
    }

    function updateFromQrCode(address, payment_id, amount, tx_description, recipient_name) {
        console.log("updateFromQrCode")
        fillPaymentDetails(address, payment_id, amount, tx_description, recipient_name);
        cameraUi.qrcode_decoded.disconnect(updateFromQrCode)
    }

    function setDescription(value) {
        descriptionLine.text = value;
        descriptionCheckbox.checked = descriptionLine.text != "";
    }

    function setPaymentId(value) {
        paymentIdLine.text = value;
        paymentIdCheckbox.checked = paymentIdLine.text != "";
    }

    function clearFields() {
        recipientModel.clear();
        fillPaymentDetails("", "", "", "", "");
        priorityDropdown.currentIndex = 0
        scheduleCard.reset()
    }

    // Information dialog
    StandardDialog {
        // dynamically change onclose handler
        property var onCloseCallback
        id: oaPopup
        cancelVisible: false
        onAccepted:  {
            if (onCloseCallback) {
                onCloseCallback()
            }
        }
    }

    readonly property color cardAccent: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
    readonly property color cardBorder: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"

    ColumnLayout {
      id: pageRoot
      anchors.margins: 20
      anchors.topMargin: 40

      anchors.left: parent.left
      anchors.top: parent.top
      anchors.right: parent.right

      spacing: 16

      // sending from a mined address (Mine addresses page): only its funds are used
      Rectangle {
          Layout.fillWidth: true
          visible: !!appWindow.minedSpend || appWindow.minedAccountActive
          implicitHeight: minedSpendRow.implicitHeight + 24
          radius: 3
          color: "#143B9EFF"
          border.width: 1
          border.color: "#3B9EFF"

          RowLayout {
              id: minedSpendRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 12
              MoneroComponents.TextPlain {
                  text: "⛏"
                  font.pixelSize: 16
                  color: "#3B9EFF"
                  themeTransition: false
              }
              MoneroComponents.TextPlain {
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                  font.pixelSize: 13
                  color: MoneroComponents.Style.defaultFontColor
                  themeTransition: false
                  readonly property var m: appWindow.minedSpend
                  text: m ? qsTr("Sending from mined address %1:%2 (%3). Only its funds are used: %4 XMR spendable. The change goes to the primary account (address 0:1) and the transaction is tagged \"(mined address change)\".").arg(m.account).arg(m.index).arg(m.label || "").arg(leftPanel.balanceUnlockedString) + translationManager.emptyString
                        : qsTr("Sending from the mined addresses account. A send can only come from one address: the mined address with the most spendable funds is used (%1 XMR). The change goes to the primary account (address 0:1). To choose one, use Send next to it on the Mine addresses page.").arg(leftPanel.balanceUnlockedString) + translationManager.emptyString
              }
              MoneroComponents.StandardButton {
                  small: true
                  primary: false
                  visible: !!appWindow.minedSpend
                  text: qsTr("Use the account") + translationManager.emptyString
                  onClicked: appWindow.stopMinedSpend()
              }
          }
      }

      RowLayout {
          visible: root.warningContent !== ""

          MoneroComponents.WarningBox {
              text: warningContent
              onLinkActivated: {
                  appWindow.startDaemon(appWindow.persistentSettings.daemonFlags);
              }
          }
      }

      RowLayout {
          visible: leftPanel.minutesToUnlock !== ""

          MoneroComponents.WarningBox {
              text: qsTr("Spendable funds: %1 XMR. Please wait ~%2 minutes for your whole balance to become spendable.").arg(leftPanel.balanceUnlockedString).arg(leftPanel.minutesToUnlock)
          }
      }

        ListModel {
            id: recipientModel

            readonly property int maxRecipients: 50

            ListElement {
                address: ""
                amount: ""
            }

            function newRecipient(address, amount) {
                if (recipientModel.count < maxRecipients) {
                    recipientModel.append({address: address, amount: amount});
                    return true;
                }
                return false;
            }

            function getRecipients() {
                var recipients = [];
                for (var index = 0; index < recipientModel.count; ++index) {
                    const recipient = recipientModel.get(index);
                    recipients.push({
                        address: recipient.address,
                        amount: recipient.amount,
                    });
                }
                return recipients;
            }

            function getAmountTotal() {
                var sum = [];
                for (var index = 0; index < recipientModel.count; ++index) {
                    const amount = recipientModel.get(index).amount;
                    if (amount == "(all)") {
                        return appWindow.getUnlockedBalance();
                    }
                    sum.push(amount || "0");
                }
                return walletManager.amountsSumFromStrings(sum);
            }

            function hasEmptyAmount() {
                for (var index = 0; index < recipientModel.count; ++index) {
                    if (recipientModel.get(index).amount === "") {
                        return true;
                    }
                }
                return false;
            }

            function hasEmptyAddress() {
                for (var index = 0; index < recipientModel.count; ++index) {
                    if (recipientModel.get(index).address === "") {
                        return true;
                    }
                }
                return false;
            }

            function hasInvalidAddress() {
                for (var index = 0; index < recipientModel.count; ++index) {
                    if (!TxUtils.checkAddress(recipientModel.get(index).address, appWindow.persistentSettings.nettype)) {
                        return true;
                    }
                }
                return false;
            }
        }

        // Recipients card: address + amount rows, tools, total and fiat value
        Item {
            Layout.fillWidth: true
            implicitHeight: recipientLayout.implicitHeight + 32

            HoverHandler { id: recipientCardHover }

            MoneroComponents.CardPanel {
                anchors.fill: parent
                selected: recipientCardHover.hovered
            }

            ColumnLayout {
                id: recipientLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 0

                readonly property int colSpacing: 16
                readonly property int rowSpacing: 8
                readonly property int secondRowWidth: 150
                readonly property int thirdRowWidth: 48

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12
                    spacing: 0

                    RowLayout {
                        id: addressLabel
                        spacing: 8
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            color: root.cardAccent
                        }

                        MoneroComponents.TextPlain {
                            Layout.leftMargin: 2
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 13
                            font.letterSpacing: 2
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                            text: qsTr("Address").toUpperCase() + translationManager.emptyString
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        MoneroComponents.TransferIconButton {
                            text: FontAwesome.desktop
                            tooltip: qsTr("Grab QR code from screen") + translationManager.emptyString
                            onClicked: {
                                clearFields();
                                const codes = oshelper.grabQrCodesFromScreen();
                                for (var index = 0; index < codes.length; ++index) {
                                    const parsed = walletManager.parse_uri_to_object(codes[index]);
                                    if (!parsed.error) {
                                        fillPaymentDetails(parsed.address, parsed.payment_id, parsed.amount, parsed.tx_description, parsed.recipient_name);
                                        break;
                                    } else if (walletManager.addressValid(codes[index], appWindow.persistentSettings.nettype)) {
                                        fillPaymentDetails(codes[index]);
                                        break;
                                    }
                                }
                            }
                        }

                        MoneroComponents.TransferIconButton {
                            text: FontAwesome.qrcode
                            fontPixelSize: 15
                            visible: appWindow.qrScannerEnabled
                            tooltip: qsTr("Scan QR code") + translationManager.emptyString
                            onClicked: {
                                cameraUi.state = "Capture"
                                cameraUi.qrcode_decoded.connect(updateFromQrCode)
                            }
                        }

                        MoneroComponents.TransferIconButton {
                            fontFamily: FontAwesome.fontFamily
                            fontStyleName: ""
                            text: FontAwesome.addressBook
                            fontPixelSize: 15
                            tooltip: qsTr("Import from address book") + translationManager.emptyString
                            onClicked: {
                                middlePanel.addressBookView.selectAndSend = true;
                                appWindow.showPageRequest("AddressBook");
                            }
                        }
                    }

                    RowLayout {
                        id: amountLabel
                        spacing: 8
                        Layout.leftMargin: recipientLayout.colSpacing
                        Layout.preferredWidth: recipientLayout.secondRowWidth + recipientLayout.thirdRowWidth
                        Layout.maximumWidth: recipientLayout.secondRowWidth + recipientLayout.thirdRowWidth

                        MoneroComponents.TextPlain {
                            Layout.leftMargin: recipientLayout.colSpacing / 2
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 13
                            font.letterSpacing: 2
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                            text: qsTr("Amount").toUpperCase() + translationManager.emptyString
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        MoneroComponents.TransferIconButton {
                            text: FontAwesome.infinity
                            visible: recipientModel.count == 1
                            tooltip: qsTr("Send all unlocked balance of this account") + translationManager.emptyString
                            tooltipLeft: true
                            // recipient delegate: children[1] = row, row.children[2] = amount field
                            onClicked: recipientRepeater.itemAt(0).children[1].children[2].text = "(all)";
                        }
                    }
                }

                Repeater {
                    id: recipientRepeater
                    model: recipientModel

                    // Keep the child order: children[0] = frame, children[1] = row with
                    // [0] address, [1] divider, [2] amount, [3] remove, [4] XMR (used by index below)
                    Item {
                        id: recipientItem
                        Layout.fillWidth: true
                        Layout.topMargin: index > 0 ? recipientLayout.rowSpacing : 0
                        implicitHeight: Math.max(46, recipientRow.implicitHeight + 8)

                        readonly property bool hasFocusInside: {
                            var item = Window.activeFocusItem;
                            while (item) {
                                if (item === recipientRow) {
                                    return true;
                                }
                                item = item.parent;
                            }
                            return false;
                        }
                        readonly property bool hasError: (recipientRow.children[0].error && recipientRow.children[0].text != "")
                                                         || recipientRow.children[2].error

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 8
                            accent: recipientItem.hasError ? MoneroComponents.Style.errorColor : root.cardBorder
                            lineOpacity: recipientItem.hasError || recipientItem.hasFocusInside ? 0.85 : (recipientRowHover.hovered ? 0.6 : 0.3)
                            fillColor: recipientItem.hasError ? MoneroComponents.Style.errorColor : root.cardAccent
                            fillOpacity: recipientItem.hasFocusInside ? 0.10 : (MoneroComponents.Style.blackTheme ? 0.04 : 0.06)
                            ticks: false
                            Behavior on lineOpacity { NumberAnimation { duration: 150 } }

                            HoverHandler { id: recipientRowHover }
                        }

                        RowLayout {
                            id: recipientRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            MoneroComponents.LineEditMulti {
                                KeyNavigation.backtab: index > 0 ? recipientRepeater.itemAt(index - 1).children[1].children[2] : sendButton
                                KeyNavigation.tab: parent.children[2]
                                Layout.alignment: Qt.AlignVCenter
                                Layout.leftMargin: 4
                                Layout.fillWidth: true
                                addressValidation: true
                                borderDisabled: true
                                fontColor: error && text != "" ? MoneroComponents.Style.errorColor : MoneroComponents.Style.defaultFontColor
                                fontFamily: MoneroComponents.Style.fontMonoRegular.name
                                fontSize: 14
                                inputPaddingBottom: 4
                                inputPaddingTop: 4
                                inputPaddingRight: 0
                                placeholderFontFamily: MoneroComponents.Style.fontMonoRegular.name
                                placeholderFontSize: 14
                                spacing: 0
                                wrapMode: Text.WrapAnywhere
                                placeholderText: {
                                    if(persistentSettings.nettype == NetworkType.MAINNET){
                                        return "4.. / 8.. / monero:.. / OpenAlias";
                                    } else if (persistentSettings.nettype == NetworkType.STAGENET){
                                        return "5.. / 7.. / monero:..";
                                    } else if(persistentSettings.nettype == NetworkType.TESTNET){
                                        return "9.. / B.. / monero:..";
                                    }
                                }
                                onTextChanged: {
                                    const several = root.parseMultipleRecipients(text);
                                    if (several) {
                                        Qt.callLater(root.fillMultipleRecipients, several);
                                        return;
                                    }
                                    const parsed = walletManager.parse_uri_to_object(text);
                                    if (!parsed.error) {
                                        fillPaymentDetails(parsed.address, parsed.payment_id, parsed.amount, parsed.tx_description, parsed.recipient_name);
                                    }
                                    address = text;
                                }
                                text: address

                                MoneroComponents.InlineButton {
                                    small: true
                                    text: qsTr("Resolve") + translationManager.emptyString
                                    visible: TxUtils.isValidOpenAliasAddress(address)
                                    onClicked: {
                                        const openAlias = address;
                                        const response = TxUtils.handleOpenAliasResolution(address, descriptionLine.text);
                                        if (response) {
                                            if (response.confirm && response.address) {
                                                const resolvedAddress = response.address;
                                                const resolvedDescription = response.description;
                                                oa_confirm(openAlias, resolvedAddress, function() {
                                                    recipientRepeater.itemAt(index).children[1].children[0].text = resolvedAddress;
                                                    if (resolvedDescription) {
                                                        descriptionLine.text = resolvedDescription;
                                                        descriptionCheckbox.checked = true;
                                                    }
                                                });
                                                return;
                                            }
                                            if (response.message) {
                                                oa_message(response.message);
                                            }
                                            if (response.address) {
                                                recipientRepeater.itemAt(index).children[1].children[0].text = response.address;
                                            }
                                            if (response.description) {
                                                descriptionLine.text = response.description;
                                                descriptionCheckbox.checked = true;
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                Layout.leftMargin: recipientLayout.colSpacing / 2
                                Layout.rightMargin: recipientLayout.colSpacing / 2
                                color: root.cardBorder
                                opacity: 0.25
                                width: 1
                            }

                            MoneroComponents.LineEdit {
                                KeyNavigation.backtab: parent.children[0]
                                KeyNavigation.tab: index + 1 < recipientRepeater.count ? recipientRepeater.itemAt(index + 1).children[1].children[0] : sendButton
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: recipientLayout.secondRowWidth - recipientLayout.colSpacing / 2
                                Layout.maximumWidth: recipientLayout.secondRowWidth - recipientLayout.colSpacing / 2
                                borderDisabled: true
                                fontFamily: MoneroComponents.Style.fontMonoRegular.name
                                fontSize: 15
                                inputHeight: 36
                                inputPaddingLeft: 0
                                inputPaddingRight: 0
                                inputPaddingTop: 0
                                inputPaddingBottom: 0
                                placeholderFontFamily: MoneroComponents.Style.fontMonoRegular.name
                                placeholderFontSize: 15
                                placeholderLeftMargin: 0
                                placeholderText: "0.00"
                                text: amount
                                onTextChanged: {
                                    text = text.trim().replace(",", ".");
                                    const match = text.match(/^0+(\d.*)/);
                                    if (match) {
                                        const cursorPosition = cursorPosition;
                                        text = match[1];
                                        cursorPosition = Math.max(cursorPosition, 1) - 1;
                                    } else if(text.indexOf('.') === 0){
                                        text = '0' + text;
                                        if (text.length > 2) {
                                            cursorPosition = 1;
                                        }
                                    }
                                    error = walletManager.amountFromString(text) > appWindow.getUnlockedBalance();

                                    amount = text;
                                }
                                validator: RegularExpressionValidator {
                                    regularExpression: /^\s*(\d{1,8})?([\.,]\d{1,12})?\s*$/
                                }
                            }

                            Item {
                                Layout.preferredWidth: recipientLayout.thirdRowWidth
                                Layout.preferredHeight: 32
                                visible: recipientModel.count > 1

                                MoneroComponents.TransferIconButton {
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 28
                                    fontPixelSize: 13
                                    text: FontAwesome.times
                                    tooltip: qsTr("Remove recipient")  + translationManager.emptyString
                                    tooltipLeft: true
                                    onClicked: recipientModel.remove(index);
                                }
                            }

                            MoneroComponents.TextPlain {
                                Layout.preferredWidth: recipientLayout.thirdRowWidth
                                horizontalAlignment: Text.AlignHCenter
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 13
                                font.letterSpacing: 1
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                                text: "XMR"
                                visible: recipientModel.count == 1
                            }
                        }
                    }
                }

                GridLayout {
                    id: totalLayout
                    Layout.topMargin: 10
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 0
                    rowSpacing: 0

                    RowLayout {
                        Layout.column: 0
                        Layout.row: 0
                        Layout.fillWidth: true
                        spacing: 0

                        CheckBox {
                            border: false
                            checked: false
                            enabled: {
                                if (recipientModel.count > 0 && recipientModel.get(0).amount == "(all)") {
                                    return false;
                                }
                                if (recipientModel.count >= recipientModel.maxRecipients) {
                                    return false;
                                }
                                return true;
                            }
                            opacity: enabled ? 1 : 0.4
                            fontAwesomeIcons: true
                            fontSize: 14
                            iconOnTheLeft: true
                            text: qsTr("Add recipient") + translationManager.emptyString
                            toggleOnClick: false
                            uncheckedIcon: FontAwesome.plusCircle
                            onClicked: {
                                recipientModel.newRecipient("", "");
                            }
                        }

                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            Layout.rightMargin: recipientLayout.colSpacing / 2
                            horizontalAlignment: Text.AlignRight
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 13
                            font.letterSpacing: 2
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                            text: recipientModel.count > 1 ? qsTr("Total").toUpperCase() + translationManager.emptyString : ""
                        }
                    }

                    MoneroComponents.LineEdit {
                        id: totalValue
                        Layout.column: 1
                        Layout.row: 0
                        Layout.leftMargin: recipientLayout.colSpacing / 2
                        Layout.preferredWidth: recipientLayout.secondRowWidth - recipientLayout.colSpacing / 2
                        Layout.maximumWidth: recipientLayout.secondRowWidth - recipientLayout.colSpacing / 2
                        borderDisabled: true
                        fontFamily: MoneroComponents.Style.fontMonoMedium.name
                        fontSize: 15
                        inputHeight: 30
                        inputPaddingLeft: 0
                        inputPaddingRight: 0
                        inputPaddingTop: 0
                        inputPaddingBottom: 0
                        readOnly: true
                        text: Utils.prettyAmount(Utils.removeTrailingZeros(walletManager.displayAmount(recipientModel.getAmountTotal())))
                        visible: recipientModel.count > 1
                    }

                    MoneroComponents.TextPlain {
                        Layout.column: 2
                        Layout.row: 0
                        Layout.preferredWidth: recipientLayout.thirdRowWidth
                        Layout.maximumWidth: recipientLayout.thirdRowWidth
                        horizontalAlignment: Text.AlignHCenter
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 13
                        font.letterSpacing: 1
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                        text: "XMR"
                        visible: recipientModel.count > 1
                    }

                    // fiat value of the total
                    MoneroComponents.LineEdit {
                        Layout.column: 1
                        Layout.row: recipientModel.count > 1 ? 1 : 0
                        Layout.leftMargin: recipientLayout.colSpacing / 2
                        Layout.preferredWidth: recipientLayout.secondRowWidth - recipientLayout.colSpacing / 2
                        Layout.maximumWidth: recipientLayout.secondRowWidth - recipientLayout.colSpacing / 2
                        borderDisabled: true
                        fontFamily: MoneroComponents.Style.fontMonoRegular.name
                        fontSize: 14
                        fontColor: MoneroComponents.Style.dimmedFontColor
                        inputHeight: 30
                        inputPaddingLeft: 0
                        inputPaddingRight: 0
                        inputPaddingTop: 0
                        inputPaddingBottom: 0
                        readOnly: true
                        text: Utils.prettyAmount(fiatApiConvertToFiat(walletManager.displayAmount(recipientModel.getAmountTotal())))
                        visible: persistentSettings.fiatPriceEnabled
                    }

                    MoneroComponents.TextPlain {
                        Layout.column: 2
                        Layout.row: recipientModel.count > 1 ? 1 : 0
                        Layout.preferredWidth: recipientLayout.thirdRowWidth
                        Layout.maximumWidth: recipientLayout.thirdRowWidth
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 13
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                        text: fiatApiCurrencySymbol()
                        visible: persistentSettings.fiatPriceEnabled
                    }
                }
            }
        }

        // Priority card: fee level + estimated fee
        Item {
            Layout.fillWidth: true
            implicitHeight: priorityLayout.implicitHeight + 32
            visible: appWindow.walletMode >= 2

            HoverHandler { id: priorityCardHover }

            MoneroComponents.CardPanel {
                anchors.fill: parent
                selected: priorityCardHover.hovered
            }

        ColumnLayout {
            id: priorityLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            // Note: workaround for translations in listElements
            // ListElement: cannot use script for property value, so
            // code like this wont work:
            // ListElement { column1: qsTr("LOW") + translationManager.emptyString ; column2: ""; priority: PendingTransaction.Priority_Low }
            // For translations to work, the strings need to be listed in
            // the file components/StandardDropdown.qml too.

            // Priorites after v5
            ListModel {
                id: priorityModelV5

                ListElement { column1: qsTr("Automatic") ; column2: ""; priority: 0}
                ListElement { column1: qsTr("Slow (x0.2 fee)") ; column2: ""; priority: 1}
                ListElement { column1: qsTr("Normal (x1 fee)") ; column2: ""; priority: 2 }
                ListElement { column1: qsTr("Fast (x5 fee)") ; column2: ""; priority: 3 }
                ListElement { column1: qsTr("Fastest (x200 fee)")  ; column2: "";  priority: 4 }
            }

            MoneroComponents.SectionTitle {
                Layout.fillWidth: true
                text: qsTr("Transaction priority") + translationManager.emptyString
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                StandardDropdown {
                    Layout.maximumWidth: 300; Layout.preferredWidth: 300
                    id: priorityDropdown
                    currentIndex: 0
                    dataModel: priorityModelV5
                }

                MoneroComponents.TextPlain {
                    id: feeLabel
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    leftPadding: estimating ? height + 6 : 0
                    elide: Text.ElideRight
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 14
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    property bool estimating: false
                    property var estimatedFee: null
                    property string estimatedFeeFiat: {
                        if (!persistentSettings.fiatPriceEnabled || estimatedFee == null) {
                            return "";
                        }
                        const fiatFee = fiatApiConvertToFiat(estimatedFee);
                        return " (%1 %3)".arg(fiatFee < 0.01 ? "<0.01" : "~" + fiatFee).arg(fiatApiCurrencySymbol());
                    }
                    property var fee: {
                        estimatedFee = null;
                        estimating = sendButton.enabled;
                        if (!sendButton.enabled || !currentWallet) {
                            return;
                        }
                        var addresses = [];
                        var amounts = [];
                        for (var index = 0; index < recipientModel.count; ++index) {
                            const recipient = recipientModel.get(index);
                            addresses.push(recipient.address);
                            amounts.push(walletManager.amountFromString(recipient.amount));
                        }
                        currentWallet.estimateTransactionFeeAsync(
                            addresses,
                            amounts,
                            priorityModelV5.get(priorityDropdown.currentIndex).priority,
                            function (amount) {
                                if (amount) {
                                    estimatedFee = Utils.removeTrailingZeros(amount);
                                }
                                estimating = false;
                            });
                    }
                    text: {
                        if (!sendButton.enabled || estimatedFee == null) {
                            return ""
                        }
                        return "~%1 XMR%2 %3".arg(estimatedFee)
                            .arg(estimatedFeeFiat)
                            .arg(qsTr("fee") + translationManager.emptyString);
                    }

                    BusyIndicator {
                        anchors.left: parent.left
                        running: feeLabel.estimating
                        visible: running
                        height: 22
                        width: height
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
        }

        // "Schedule the send": now (default) or at a date and time; the app makes the send itself then
        Item {
            id: scheduleCard
            Layout.fillWidth: true
            implicitHeight: scheduleLayout.implicitHeight + 32
            readonly property bool supported: !!appWindow.currentWallet && !appWindow.currentWallet.isHwBacked()
            onSupportedChanged: if (!supported) reset()
            visible: supported && !appWindow.viewOnly && !appWindow.minedSpend && !appWindow.minedAccountActive

            // a scheduled send would run later without the mined address as source
            readonly property bool minedSpend: !!appWindow.minedSpend || appWindow.minedAccountActive
            onMinedSpendChanged: if (minedSpend) reset()
            property bool scheduled: false
            property double nowMs: Date.now()
            // dd/mm/yyyy + hh:mm -> ms, or NaN
            readonly property double whenMs: {
                var d = scheduleDate.text.trim().match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
                var t = scheduleTime.text.trim().match(/^(\d{1,2}):(\d{2})$/);
                if (!d || !t) return NaN;
                var day = +d[1], month = +d[2] - 1, year = +d[3], h = +t[1], m = +t[2];
                if (h > 23 || m > 59) return NaN;
                var date = new Date(year, month, day, h, m, 0, 0);
                return date.getDate() === day && date.getMonth() === month ? date.getTime() : NaN;
            }
            readonly property string whenError: {
                if (!scheduled) return "";
                if (isNaN(whenMs)) return qsTr("Write the date as dd/mm/yyyy and the time as hh:mm") + translationManager.emptyString;
                if (whenMs < nowMs + 60000) return qsTr("The date and time must be in the future") + translationManager.emptyString;
                return "";
            }
            readonly property bool valid: !scheduled || whenError === ""

            function two(n) { return (n < 10 ? "0" : "") + n; }
            function remainingText(ms) {
                var min = Math.max(0, Math.round(ms / 60000));
                if (min < 60) return qsTr("in %1 min").arg(min) + translationManager.emptyString;
                var h = Math.floor(min / 60);
                if (h < 48) return qsTr("in %1 h %2 min").arg(h).arg(min % 60) + translationManager.emptyString;
                return qsTr("in %1 days").arg(Math.floor(h / 24)) + translationManager.emptyString;
            }
            function pick(on) {
                scheduled = on;
                if (on && scheduleDate.text === "" && scheduleTime.text === "") {
                    // default: one hour from now, on the next quarter
                    var d = new Date(Date.now() + 60 * 60000);
                    d.setMinutes(Math.ceil(d.getMinutes() / 15) * 15, 0, 0);
                    scheduleDate.text = two(d.getDate()) + "/" + two(d.getMonth() + 1) + "/" + d.getFullYear();
                    scheduleTime.text = two(d.getHours()) + ":" + two(d.getMinutes());
                }
            }
            function reset() {
                scheduled = false;
                scheduleDate.text = "";
                scheduleTime.text = "";
            }

            Timer {
                interval: 20000
                running: scheduleCard.visible
                repeat: true
                onTriggered: scheduleCard.nowMs = Date.now()
            }

            HoverHandler { id: scheduleCardHover }

            MoneroComponents.CardPanel {
                anchors.fill: parent
                selected: scheduleCardHover.hovered
            }

            ColumnLayout {
                id: scheduleLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                MoneroComponents.SectionTitle {
                    Layout.fillWidth: true
                    text: qsTr("Schedule the send") + translationManager.emptyString
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ScheduleOption {
                        label: qsTr("Now") + translationManager.emptyString
                        selected: !scheduleCard.scheduled
                        onPicked: scheduleCard.pick(false)
                    }
                    ScheduleOption {
                        label: qsTr("Date and time") + translationManager.emptyString
                        selected: scheduleCard.scheduled
                        onPicked: scheduleCard.pick(true)
                    }

                    MoneroComponents.LineEdit {
                        id: scheduleDate
                        visible: scheduleCard.scheduled
                        Layout.leftMargin: 8
                        Layout.preferredWidth: 130
                        inputHeight: 34
                        inputPaddingLeft: 8
                        inputPaddingRight: 8
                        inputPaddingTop: 0
                        inputPaddingBottom: 0
                        fontFamily: MoneroComponents.Style.fontMonoRegular.name
                        fontSize: 14
                        placeholderFontSize: 14
                        placeholderText: "dd/mm/aaaa"
                        error: scheduleCard.scheduled && isNaN(scheduleCard.whenMs) && text !== ""
                    }
                    MoneroComponents.LineEdit {
                        id: scheduleTime
                        visible: scheduleCard.scheduled
                        Layout.preferredWidth: 80
                        inputHeight: 34
                        inputPaddingLeft: 8
                        inputPaddingRight: 8
                        inputPaddingTop: 0
                        inputPaddingBottom: 0
                        fontFamily: MoneroComponents.Style.fontMonoRegular.name
                        fontSize: 14
                        placeholderFontSize: 14
                        placeholderText: "hh:mm"
                        error: scheduleCard.scheduled && isNaN(scheduleCard.whenMs) && text !== ""
                    }

                    MoneroComponents.TextPlain {
                        visible: scheduleCard.scheduled
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        text: scheduleCard.whenError !== "" ? scheduleCard.whenError
                              : qsTr("Will be sent %1").arg(scheduleCard.remainingText(scheduleCard.whenMs - scheduleCard.nowMs)) + translationManager.emptyString
                        color: scheduleCard.whenError !== "" ? "#FF5C5C" : MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                    Item { Layout.fillWidth: true; visible: !scheduleCard.scheduled }
                }

                MoneroComponents.TextPlain {
                    visible: scheduleCard.scheduled || appWindow.walletScheduledSends.length > 0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    text: qsTr("Keep the app open with this wallet selected and synced. A password screen can stay locked only if background-sync mode has not removed spending access. Scheduled payments are unavailable on hardware wallets. If the wallet is closed when a payment becomes due, you must confirm it after reopening. Other sends from the source account are blocked during the previous 25 minutes; funds must still be unlocked at payment time.") + translationManager.emptyString
                }

                // sends already scheduled for this wallet
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: appWindow.walletScheduledSends.length > 0
                    spacing: 6

                    MoneroComponents.TextPlain {
                        text: qsTr("Scheduled sends") + translationManager.emptyString
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 0.8
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }

                    Repeater {
                        model: appWindow.walletScheduledSends
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            readonly property var entry: modelData
                            readonly property bool running: appWindow.scheduledRunningId === entry.id
                            readonly property bool late: entry.error === "late"
                            readonly property bool failed: entry.error !== "" && !late

                            MoneroComponents.TextPlain {
                                Layout.preferredWidth: 150
                                text: new Date(entry.when).toLocaleString(Qt.locale(), "dd/MM/yyyy HH:mm")
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 13
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                            }
                            MoneroComponents.TextPlain {
                                Layout.preferredWidth: 150
                                text: appWindow.scheduledAmountText(entry)
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 13
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                            }
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                themeTransition: false
                                color: late || failed ? "#FF5C5C" : MoneroComponents.Style.dimmedFontColor
                                text: {
                                    var to = entry.recipients.length > 1 ? qsTr("%1 recipients").arg(entry.recipients.length)
                                                                          : entry.recipients[0].address.substring(0, 8) + "…" + entry.recipients[0].address.slice(-6);
                                    if (running) return qsTr("Sending…") + translationManager.emptyString;
                                    if (late) return qsTr("Not sent on time (the app was closed) · %1").arg(to) + translationManager.emptyString;
                                    if (failed) return qsTr("Error: %1 · %2").arg(entry.error).arg(to) + translationManager.emptyString;
                                    return to + " · " + scheduleCard.remainingText(entry.when - scheduleCard.nowMs);
                                }
                            }
                            MoneroComponents.StandardButton {
                                visible: (late || failed) && !running
                                small: true
                                enabled: appWindow.scheduledRunningId === "" && !appWindow.scheduledSaving && entry.state !== "broadcasting"
                                text: qsTr("Send now") + translationManager.emptyString
                                onClicked: appWindow.runScheduledSend(entry.id)
                            }
                            MoneroComponents.StandardButton {
                                visible: !running
                                small: true
                                primary: false
                                text: qsTr("Cancel") + translationManager.emptyString
                                onClicked: appWindow.removeScheduledSend(entry.id)
                            }
                        }
                    }
                }
            }
        }

      MoneroComponents.WarningBox {
          text: qsTr("Description field contents match long payment ID format. \
          Please don't paste long payment ID into description field, your funds might be lost.") + translationManager.emptyString;
          visible: warningLongPidDescription
      }

      // Description (and legacy payment ID) card
      Item {
          Layout.fillWidth: true
          implicitHeight: descriptionLayout.implicitHeight + 24

          HoverHandler { id: descriptionCardHover }

          MoneroComponents.CardPanel {
              anchors.fill: parent
              selected: descriptionCardHover.hovered
          }

      ColumnLayout {
          id: descriptionLayout
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 16
          anchors.topMargin: 12
          spacing: 12

          ColumnLayout {
              spacing: 10

              CheckBox {
                  id: descriptionCheckbox
                  border: false
                  checkedIcon: FontAwesome.minusCircle
                  uncheckedIcon: FontAwesome.plusCircle
                  fontAwesomeIcons: true
                  fontSize: 14
                  iconOnTheLeft: true
                  Layout.fillWidth: true
                  text: qsTr("Add description") + translationManager.emptyString
                  onClicked: {
                      if (!descriptionCheckbox.checked) {
                        descriptionLine.text = "";
                      }
                  }
              }

              LineEdit {
                  id: descriptionLine
                  placeholderFontSize: 15
                  fontSize: 15
                  placeholderText: qsTr("Saved to local wallet history") + " (" + qsTr("only visible to you") + ")" + translationManager.emptyString
                  Layout.fillWidth: true
                  Layout.bottomMargin: 4
                  visible: descriptionCheckbox.checked
              }
          }

          ColumnLayout {
              visible: paymentIdCheckbox.checked
              spacing: 10

              CheckBox {
                  id: paymentIdCheckbox
                  border: false
                  checkedIcon: FontAwesome.minusCircle
                  uncheckedIcon: FontAwesome.plusCircle
                  fontAwesomeIcons: true
                  fontSize: 14
                  iconOnTheLeft: true
                  Layout.fillWidth: true
                  text: qsTr("Add payment ID") + translationManager.emptyString
                  onClicked: {
                      if (!paymentIdCheckbox.checked) {
                        paymentIdLine.text = "";
                      }
                  }
              }

              // payment id input
              LineEditMulti {
                  id: paymentIdLine
                  fontFamily: MoneroComponents.Style.fontMonoRegular.name
                  fontSize: 14
                  placeholderText: qsTr("64 hexadecimal characters") + translationManager.emptyString
                  readOnly: true
                  Layout.fillWidth: true
                  Layout.bottomMargin: 4
                  wrapMode: Text.WrapAnywhere
                  addressValidation: false
                  visible: paymentIdCheckbox.checked
                  error: paymentIdCheckbox.checked
              }
          }
      }
      }

      MoneroComponents.WarningBox {
          id: paymentIdWarningBox
          text: qsTr("Long payment IDs are obsolete. \
          Long payment IDs were not encrypted on the blockchain and would harm your privacy. \
          If the party you're sending to still requires a long payment ID, please notify them.") + translationManager.emptyString;
          visible: root.paymentIdBlocked
      }

      MoneroComponents.WarningBox {
          id: sendButtonWarningBox
          text: root.sendButtonWarning
          visible: root.sendButtonWarning !== ""
      }

      RowLayout {
          Layout.fillWidth: true

          Item {
              Layout.fillWidth: true
          }

          StandardButton {
              id: sendButton
              rightIcon: "qrc:///images/icons/rightArrow.png"
              Layout.topMargin: 4
              Layout.preferredWidth: Math.max(implicitWidth, 160)
              text: (scheduleCard.scheduled ? qsTr("Schedule send") : qsTr("Send")) + translationManager.emptyString
              enabled: root.canSendTransaction && scheduleCard.valid
              onClicked: {
                  console.log("Transfer: paymentClicked")
                  var priority = priorityModelV5.get(priorityDropdown.currentIndex).priority
                  console.log("priority: " + priority)
                  setPaymentId(paymentIdLine.text.trim());
                  if (scheduleCard.scheduled) {
                      appWindow.scheduleSend(recipientModel.getRecipients(), paymentIdLine.text, root.mixin, priority, descriptionLine.text, scheduleCard.whenMs);
                      return;
                  }
                  root.paymentClicked(recipientModel.getRecipients(), paymentIdLine.text, root.mixin, priority, descriptionLine.text)
              }
          }
      }
    } // pageRoot

    ColumnLayout {
        id: advancedLayout
        anchors.top: pageRoot.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 20
        anchors.topMargin: 24
        spacing: 0
        enabled: !viewOnly || pageRoot.enabled

        // Collapsible "Advanced options" panel (same look as the wizard's)
        Item {
            id: showAdvancedCheckbox
            readonly property bool checked: persistentSettings.transferShowAdvanced
            readonly property bool hovered: advHeaderMouse.containsMouse
            visible: appWindow.walletMode >= 2
            Layout.fillWidth: true
            implicitHeight: advColumn.implicitHeight

            MoneroComponents.NeonFrame {
                anchors.fill: parent
                cut: 10
                accent: root.cardBorder
                lineOpacity: showAdvancedCheckbox.checked || showAdvancedCheckbox.hovered ? 0.6 : 0.25
                fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#DADFDB"
                fillOpacity: MoneroComponents.Style.blackTheme ? 0.92 : 0.9
                ticks: false
                Behavior on lineOpacity { NumberAnimation { duration: 150 } }
            }

            ColumnLayout {
                id: advColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                // header row: chevron, title, view-only hint
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
                            property color c: root.cardAccent
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

                        MoneroComponents.TextPlain {
                            text: qsTr("Outputs") + "  ·  " + qsTr("Key images") + "  ·  " + qsTr("Offline transaction signing") + translationManager.emptyString
                            Layout.maximumWidth: parent.width * 0.55
                            elide: Text.ElideRight
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            font.pixelSize: 12
                            color: MoneroComponents.Style.dimmedFontColor
                            visible: !showAdvancedCheckbox.checked
                            themeTransition: false
                        }
                    }

                    MouseArea {
                        id: advHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            persistentSettings.transferShowAdvanced = !persistentSettings.transferShowAdvanced
                        }
                    }
                }

                Rectangle {
                    visible: showAdvancedCheckbox.checked
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.preferredHeight: 1
                    color: root.cardAccent
                    opacity: 0.3
                }

                ColumnLayout {
                    visible: showAdvancedCheckbox.checked
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Layout.topMargin: 14
                    spacing: 8

        MoneroComponents.TransferAdvancedRow {
            title: qsTr("Outputs") + translationManager.emptyString
            button1.text: qsTr("Export") + translationManager.emptyString
            button1.enabled: appWindow.viewOnly
            button1.onClicked: {
                console.log("Transfer: export outputs clicked")
                exportOutputsDialog.open();
            }
            button2.text: qsTr("Import") + translationManager.emptyString
            button2.enabled: !appWindow.viewOnly
            button2.onClicked: {
                console.log("Transfer: import outputs clicked")
                importOutputsDialog.open();
            }
            tooltip: {
                var header = qsTr("Required for cold wallets to sign their corresponding key images") + translationManager.emptyString;
                return "<style type='text/css'>.header{ font-size: 13px; } p{line-height:20px; margin-top:0px; margin-bottom:0px; " +
                       ";} p.orange{color:#ff9323;}</style>" +
                       "<div class='header'>" + header + "</div>" +
                       "<p>" + qsTr("1. Using view-only wallet, export the outputs into a file") + "</p>" +
                       "<p>" + qsTr("2. Using cold wallet, import the outputs file") + "</p>" +
                       translationManager.emptyString
            }
        }

        MoneroComponents.TransferAdvancedRow {
            title: qsTr("Key images") + translationManager.emptyString
            button1.text: qsTr("Export") + translationManager.emptyString
            button1.enabled: !appWindow.viewOnly
            button1.onClicked: {
                console.log("Transfer: export key images clicked")
                exportKeyImagesDialog.open();
            }
            button2.text: qsTr("Import") + translationManager.emptyString
            button2.enabled: appWindow.viewOnly && appWindow.isTrustedDaemon()
            button2.onClicked: {
                console.log("Transfer: import key images clicked")
                importKeyImagesDialog.open();
            }
            tooltip: {
                var errorMessage = "";
                if (appWindow.viewOnly && !appWindow.isTrustedDaemon()){
                    errorMessage = "<p class='orange'>" + qsTr("* To import, you must connect to a local node or a trusted remote node") + "</p>";
                }
                var header = qsTr("Required for view-only wallets to display the real balance") + translationManager.emptyString;
                return "<style type='text/css'>.header{ font-size: 13px; } p{line-height:20px; margin-top:0px; margin-bottom:0px; " +
                       ";} p.orange{color:#ff9323;}</style>" +
                       "<div class='header'>" + header + "</div>" +
                       "<p>" + qsTr("1. Using cold wallet, export the key images into a file") + "</p>" +
                       "<p>" + qsTr("2. Using view-only wallet, import the key images file") + "</p>" +
                       errorMessage + translationManager.emptyString
            }
        }

        MoneroComponents.TransferAdvancedRow {
            title: qsTr("Offline transaction signing") + translationManager.emptyString
            button1.text: qsTr("Create") + translationManager.emptyString
            button1.enabled: root.canCreateOfflineTx
            button1.onClicked: {
                console.log("Transfer: saveTx Clicked")
                var priority = priorityModelV5.get(priorityDropdown.currentIndex).priority
                console.log("priority: " + priority)
                setPaymentId(paymentIdLine.text.trim());
                root.paymentClicked(recipientModel.getRecipients(), paymentIdLine.text, root.mixin, priority, descriptionLine.text)
            }
            button2.text: qsTr("Sign (offline)") + translationManager.emptyString
            button2.enabled: currentWallet !== undefined && !appWindow.viewOnly && !currentWallet.isHwBacked()
            button2.onClicked: {
                console.log("Transfer: sign tx clicked")
                signTxDialog.open();
            }
            button3.text: qsTr("Submit") + translationManager.emptyString
            button3.enabled: appWindow.viewOnly
            button3.onClicked: {
                console.log("Transfer: submit tx clicked")
                submitTxDialog.open();
            }
            tooltip: {
                var errorMessage = "";
                if (appWindow.viewOnly && !root.hasValidTransferInfo) {
                    errorMessage = "<p class='orange'>" + qsTr("* To create a transaction file, please enter address and amount above") + "</p>";
                }
                var header = qsTr("Spend XMR from a cold (offline) wallet") + translationManager.emptyString;
                return "<style type='text/css'>.header{ font-size: 13px; } p{line-height:20px; margin-top:0px; margin-bottom:0px; " +
                       ";} p.orange{color:#ff9323;}</style>" +
                       "<div class='header'>" + header + "</div>" +
                       "<p>" + qsTr("1. Using view-only wallet, export the outputs into a file") + "</p>" +
                       "<p>" + qsTr("2. Using cold wallet, import the outputs file and export the key images") + "</p>" +
                       "<p>" + qsTr("3. Using view-only wallet, import the key images file and create a transaction file") + "</p>" +
                       errorMessage +
                       "<p>" + qsTr("4. Using cold wallet, sign your transaction file") + "</p>" +
                       "<p>" + qsTr("5. Using view-only wallet, submit your signed transaction") + "</p>" + translationManager.emptyString
            }
        }

        MoneroComponents.TransferAdvancedRow {
            title: qsTr("Unmixable outputs") + translationManager.emptyString
            button1.text: qsTr("Sweep") + translationManager.emptyString
            button1.enabled : pageRoot.enabled
            button1.onClicked: {
                console.log("Transfer: sweepUnmixableClicked")
                root.sweepUnmixableClicked()
            }
            tooltip: qsTr("Create a transaction that spends old unmovable outputs") + translationManager.emptyString
        }
                }
            }
        }
    }

    //SignTxDialog
    FileDialog {
        id: signTxDialog
        title: qsTr("Please choose a file") + translationManager.emptyString
        currentFolder: "file://" + appWindow.accountsDir
        nameFilters: [ "Unsigned transfers (*)"]

        onAccepted: {
            var path = walletManager.urlToLocalPath(selectedFile);
            // Load the unsigned tx from file
            var transaction = currentWallet.loadTxFile(path);

            if (transaction.status !== PendingTransaction.Status_Ok) {
                console.error("Can't load unsigned transaction: ", transaction.errorString);
                informationPopup.title = qsTr("Error") + translationManager.emptyString;
                informationPopup.text  = qsTr("Can't load unsigned transaction: ") + transaction.errorString
                informationPopup.onCloseCallback = null
                informationPopup.open();
                // deleting transaction object, we don't want memleaks
                transaction.destroy();
            } else {
                confirmationDialog.text =  qsTr("\nConfirmation message:\n ") + transaction.confirmationMessage
                console.log(transaction.confirmationMessage);

                // Show confirmation dialog
                confirmationDialog.title = qsTr("Confirmation") + translationManager.emptyString
                confirmationDialog.onAcceptedCallback = function() {
                    transaction.sign(path+"_signed");
                    transaction.destroy();
                };
                confirmationDialog.onRejectedCallback = transaction.destroy;

                confirmationDialog.open()
            }

        }
        onRejected: {
            // File dialog closed
            console.log("Canceled")
        }
    }

    //SignTxDialog
    FileDialog {
        id: submitTxDialog
        title: qsTr("Please choose a file") + translationManager.emptyString
        currentFolder: "file://" + appWindow.accountsDir
        nameFilters: [ "signed transfers (*)"]

        onAccepted: {
            if(!currentWallet.submitTxFile(walletManager.urlToLocalPath(selectedFile))){
                informationPopup.title = qsTr("Error") + translationManager.emptyString;
                informationPopup.text  = qsTr("Can't submit transaction: ") + currentWallet.errorString
                informationPopup.onCloseCallback = null
                informationPopup.open();
            } else {
                informationPopup.title = qsTr("Information") + translationManager.emptyString
                informationPopup.text  = qsTr("Monero sent successfully") + translationManager.emptyString
                informationPopup.onCloseCallback = null
                informationPopup.open();
            }
        }
        onRejected: {
            console.log("Canceled")
        }

    }
    
    FileDialog {
        id: exportOutputsDialog
        fileMode: FileDialog.SaveFile
        onAccepted: {
            console.log(walletManager.urlToLocalPath(exportOutputsDialog.selectedFile))
            if (currentWallet.exportOutputs(walletManager.urlToLocalPath(exportOutputsDialog.selectedFile), true)) {
                appWindow.showStatusMessage(qsTr("Outputs successfully exported to file") + translationManager.emptyString, 3);
            } else {
                appWindow.showStatusMessage(currentWallet.errorString, 5);
            }
        }
        onRejected: {
            console.log("Canceled");
        }
    }

    FileDialog {
        id: importOutputsDialog
        title: qsTr("Please choose a file") + translationManager.emptyString
        onAccepted: {
            console.log(walletManager.urlToLocalPath(importOutputsDialog.selectedFile))
            if (currentWallet.importOutputs(walletManager.urlToLocalPath(importOutputsDialog.selectedFile))) {
                appWindow.showStatusMessage(qsTr("Outputs successfully imported to wallet") + translationManager.emptyString, 3);
            } else {
                appWindow.showStatusMessage(currentWallet.errorString, 5);
            }
        }
        onRejected: {
            console.log("Canceled");
        }
    }

    //ExportKeyImagesDialog
    FileDialog {
        id: exportKeyImagesDialog
        fileMode: FileDialog.SaveFile
        onAccepted: {
            console.log(walletManager.urlToLocalPath(exportKeyImagesDialog.selectedFile))
            if (currentWallet.exportKeyImages(walletManager.urlToLocalPath(exportKeyImagesDialog.selectedFile), true)) {
                appWindow.showStatusMessage(qsTr("Key images successfully exported to file") + translationManager.emptyString, 3);
            } else {
                appWindow.showStatusMessage(currentWallet.errorString, 5);
            }
        }
        onRejected: {
            console.log("Canceled");
        }
    }

    //ImportKeyImagesDialog
    FileDialog {
        id: importKeyImagesDialog
        title: qsTr("Please choose a file") + translationManager.emptyString
        onAccepted: {
            console.log(walletManager.urlToLocalPath(importKeyImagesDialog.selectedFile))
            if (currentWallet.importKeyImages(walletManager.urlToLocalPath(importKeyImagesDialog.selectedFile))) {
                appWindow.showStatusMessage(qsTr("Key images successfully imported to wallet") + translationManager.emptyString, 3);
            } else {
                appWindow.showStatusMessage(currentWallet.errorString, 5);
            }
        }
        onRejected: {
            console.log("Canceled");
        }
    }



    Component.onCompleted: {
        //Disable password page until enabled by updateStatus
        pageRoot.enabled = false
    }

    // fires on every page load
    function onPageCompleted() {
        console.log("transfer page loaded")
        updateStatus();
    }

    //TODO: Add daemon sync status
    //TODO: enable send page when we're connected and daemon is synced

    function updateStatus() {
        var messageNotConnected = qsTr("Wallet is not connected to daemon.");
        if(appWindow.walletMode >= 2 && !persistentSettings.useRemoteNode) messageNotConnected += " " + root.startLinkText;
        pageRoot.enabled = true;
        if(typeof currentWallet === "undefined") {
            root.warningContent = messageNotConnected;
            return;
        }

        if (currentWallet.viewOnly) {
           // warningText.text = qsTr("Wallet is view only.")
           //return;
        }
        //pageRoot.enabled = false;

        switch (currentWallet.connected()) {
        case Wallet.ConnectionStatus_Connecting:
            root.warningContent = qsTr("Wallet is connecting to daemon.")
            break
        case Wallet.ConnectionStatus_Disconnected:
            root.warningContent = messageNotConnected;
            break
        case Wallet.ConnectionStatus_WrongVersion:
            root.warningContent = qsTr("Connected daemon is not compatible with GUI. \n" +
                                   "Please upgrade or connect to another daemon")
            break
        default:
            if(!appWindow.daemonSynced){
                root.warningContent = qsTr("Waiting on daemon synchronization to finish.")
            } else {
                // everything OK, enable transfer page
                // Light wallet is always ready
                pageRoot.enabled = true;
                root.warningContent = "";
            }
        }
    }

    // Popuplate fields from addressbook.
    function sendTo(address, paymentId, description, amount) {
        middlePanel.state = 'Transfer';

        fillPaymentDetails(address, paymentId, amount, description);
    }
}
