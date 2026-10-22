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
import moneroComponents.Subaddress 1.0
import moneroComponents.SubaddressModel 1.0
import "../js/TxUtils.js" as TxUtils

Rectangle {
    id: pageReceive
    color: "transparent"
    property var model
    property alias receiveHeight: mainLayout.height
    property var state: "Address"

    // Wallet+: an address group as text ("addr,addr" or "addr:amount,..."), fixed height, scrolls, click copies
    component GroupTextBox: Item {

        MoneroComponents.ReceiveFieldBackground {
            anchors.fill: parent
            focused: groupMouse.containsMouse
            warning: !!pageReceive.selectedGroup && pageReceive.groupUsed(pageReceive.selectedGroup)
        }
        Flickable {
            id: groupFlick
            anchors.left: parent.left
            anchors.right: groupCopy.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            clip: true
            contentWidth: width
            contentHeight: groupText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: groupFlick.contentHeight > groupFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded }
        MoneroComponents.TextPlain {
            id: groupText
            width: groupFlick.width - 12
            text: pageReceive.groupText
            wrapMode: Text.WrapAnywhere
            color: groupMouse.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.defaultFontColor
            font.pixelSize: 12
            font.family: MoneroComponents.Style.fontMonoRegular.name
            lineHeight: 1.15
            themeTransition: false
            MouseArea {
                id: groupMouse
                hoverEnabled: true
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    clipboard.setText(pageReceive.groupText);
                    appWindow.showStatusMessage(qsTr("Addresses copied to clipboard") + translationManager.emptyString, 3);
                }
            }
        }
        }
        MoneroComponents.ReceiveIconButton {
            id: groupCopy
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 8
            icon: "copy"
            tooltip: qsTr("Copy the addresses to clipboard") + translationManager.emptyString
            onClicked: {
                clipboard.setText(pageReceive.groupText);
                appWindow.showStatusMessage(qsTr("Addresses copied to clipboard") + translationManager.emptyString, 3);
            }
        }
    }


    function renameSubaddressLabel(_index){
        inputDialog.labelText = qsTr("Set the label of the selected address:") + translationManager.emptyString;
        inputDialog.onAcceptedCallback = function() {
            appWindow.currentWallet.subaddress.setLabel(appWindow.currentWallet.currentSubaddressAccount, _index, inputDialog.inputText);
        }
        inputDialog.onRejectedCallback = null;
        inputDialog.open(appWindow.currentWallet.getSubaddressLabel(appWindow.currentWallet.currentSubaddressAccount, _index))
    }

    // subaddresses of the current account that already received a transaction: { index: true }
    property var usedAddresses: ({})
    readonly property bool currentAddressUsed: usedAddresses[appWindow.current_subaddress_table_index] === true
    readonly property color usedColor: MoneroComponents.Style.blackTheme ? "#FF5C5C" : "#C62828"
    // primary address (account 0, address 0, starts with 4): blue, only copied through the QR code
    readonly property bool currentIsPrimary: appWindow.currentWallet ? appWindow.currentWallet.currentSubaddressAccount === 0
                                                                       && appWindow.current_subaddress_table_index === 0 : false
    readonly property bool copyBlocked: currentAddressUsed || currentIsPrimary
    readonly property color primaryColor: MoneroComponents.Style.blackTheme ? "#6CB8FF" : "#1565C0"

    function updateUsedAddresses() {
        var used = {};
        if (appWindow.currentWallet) {
            var list = appWindow.currentWallet.history.usedSubaddresses();
            for (var i = 0; i < list.length; ++i)
                used[list[i]] = true;
        }
        usedAddresses = used;
    }

    Connections {
        target: appWindow.currentWallet ? appWindow.currentWallet.history : null
        function onRefreshFinished() { pageReceive.updateUsedAddresses(); }
    }

    // ---- Wallet+ address groups (Create addresses in bulk): consecutive addresses shown as one row ----
    property var selectedGroup: null
    readonly property var groups: (appWindow.addressGroupsTick, appWindow.currentWallet
        ? appWindow.addressGroups().filter(function(g) { return g.account === appWindow.currentWallet.currentSubaddressAccount; })
        : [])
    function groupAt(i) {
        for (var k = 0; k < groups.length; ++k)
            if (i >= groups[k].from && i < groups[k].from + groups[k].count)
                return groups[k];
        return null;
    }
    function groupAddresses(g) {
        var list = [];
        for (var k = 0; g && k < g.count; ++k)
            list.push(appWindow.currentWallet.address(g.account, g.from + k));
        return list;
    }
    function groupUsed(g) {
        for (var k = 0; k < g.count; ++k)
            if (usedAddresses[g.from + k] === true) return true;
        return false;
    }
    function selectGroup(g) {
        selectedGroup = g;
        subaddressListView.currentIndex = g.from;
        updateSelectedAddressDisplay();
        splitRandom();
    }
    readonly property var selectedGroupAddresses: selectedGroup ? groupAddresses(selectedGroup) : []
    // payment request of a group: the total split at random among its addresses (piconero)
    property var groupAmounts: []
    function piconeroText(n) {
        var s = String(Math.round(n));
        while (s.length < 13) s = "0" + s;
        var frac = s.slice(-12).replace(/0+$/, "");
        return s.slice(0, -12) + (frac ? "." + frac : "");
    }
    // "1.25" -> 1250000000000 (piconero), without going through quint64
    function piconeroFromText(t) {
        var m = String(t).trim().replace(",", ".").match(/^(\d*)(?:\.(\d{0,12}))?\d*$/);
        if (!m || (m[1] === "" && !m[2])) return 0;
        var frac = (m[2] || "");
        while (frac.length < 12) frac += "0";
        return Number(m[1] || "0") * 1e12 + Number(frac);
    }
    function splitRandom() {
        var total = piconeroFromText(amountToReceiveXMR.text);
        var n = selectedGroup ? selectedGroup.count : 0;
        if (!n || !(total >= n)) { groupAmounts = []; return; }
        // random weights 0.4..1.6, rounded to piconero; what rounding leaves goes to a random address
        var w = [], sum = 0, k;
        for (k = 0; k < n; ++k) { w.push(0.4 + Math.random() * 1.2); sum += w[k]; }
        var amounts = [], given = 0;
        for (k = 0; k < n; ++k) { amounts.push(Math.max(1, Math.floor(total * w[k] / sum))); given += amounts[k]; }
        amounts[Math.floor(Math.random() * n)] += total - given;
        groupAmounts = amounts;
    }
    // what is copied and pasted in Send: "addr,addr,..." or "addr:amount,addr:amount,..."
    readonly property string groupText: {
        var a = selectedGroupAddresses;
        if (state == "PaymentRequest" && groupAmounts.length === a.length && a.length > 0)
            return a.map(function(x, k) { return x + ":" + piconeroText(groupAmounts[k]); }).join(",");
        return a.join(",");
    }
    Connections {
        target: appWindow.currentWallet
        ignoreUnknownSignals: true
        function onCurrentSubaddressAccountChanged() { pageReceive.selectedGroup = null; }
    }
    property bool creatingGroup: false
    function createGroup(count, label) {
        var w = appWindow.currentWallet;
        if (!w || creatingGroup) return;
        creatingGroup = true;
        var account = w.currentSubaddressAccount;
        w.addSubaddressesAsync(account, count, label, function(first, n) {
            creatingGroup = false;
            w.subaddress.refresh(account);
            var list = appWindow.addressGroups().slice();
            var g = { account: account, from: first, count: n, label: label };
            list.push(g);
            appWindow.setAddressGroups(list);
            selectGroup(g);
            appWindow.showStatusMessage(qsTr("%1 addresses created as one group").arg(n) + translationManager.emptyString, 4);
        });
    }
    function renameGroup(g) {
        inputDialog.labelText = qsTr("Set the label of the address group:") + translationManager.emptyString;
        inputDialog.onAcceptedCallback = function() {
            var label = inputDialog.inputText;
            for (var k = 0; k < g.count; ++k)
                appWindow.currentWallet.setSubaddressLabel(g.account, g.from + k, label);
            var list = appWindow.addressGroups().map(function(x) {
                return x.account === g.account && x.from === g.from ? { account: x.account, from: x.from, count: x.count, label: label } : x;
            });
            appWindow.setAddressGroups(list);
            appWindow.currentWallet.subaddress.refresh(g.account);
            if (selectedGroup && selectedGroup.from === g.from) selectedGroup = groupAt(g.from);
        };
        inputDialog.onRejectedCallback = null;
        inputDialog.open(g.label);
    }

    function createNewAddress() {
        inputDialog.labelText = qsTr("Set the label of the new address:") + translationManager.emptyString
        inputDialog.onAcceptedCallback = function() {
            appWindow.currentWallet.subaddress.addRow(appWindow.currentWallet.currentSubaddressAccount, inputDialog.inputText)
            current_subaddress_table_index = appWindow.currentWallet.numSubaddresses(appWindow.currentWallet.currentSubaddressAccount) - 1
            subaddressListView.currentIndex = current_subaddress_table_index
        }
        inputDialog.onRejectedCallback = null;
        inputDialog.open()
    }

    function updateSelectedAddressDisplay() {
        appWindow.current_subaddress_table_index = subaddressListView.currentIndex;
        appWindow.current_address = appWindow.currentWallet.address(
            appWindow.currentWallet.currentSubaddressAccount,
            subaddressListView.currentIndex
        );
        if (subaddressListView.currentIndex == 0) {
            selectedAddressDrescription.text = qsTr("Primary address") + translationManager.emptyString;
        } else {
            var selectedAddressLabel = appWindow.currentWallet.getSubaddressLabel(appWindow.currentWallet.currentSubaddressAccount, appWindow.current_subaddress_table_index);
            if (selectedAddressLabel == "") {
                selectedAddressDrescription.text = "(" + qsTr("no label") + ")" + translationManager.emptyString
            } else {
                selectedAddressDrescription.text = selectedAddressLabel
            }
        }
    }

    function generateQRCodeString() {
        if (pageReceive.selectedGroup)
            return pageReceive.groupText;
        if (pageReceive.state == "PaymentRequest") {
            return walletManager.make_uri(appWindow.current_address,
                amountToReceiveXMR.text,
                txDescriptionInput.text, receiverNameInput.text);
        } else {
            return walletManager.make_uri(appWindow.current_address);
        }
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

        spacing: 28

        readonly property bool dark: MoneroComponents.Style.blackTheme
        readonly property color softBorder: dark ? "#E8ECE9" : "#2B3A30"
        readonly property color accentColor: dark ? "#4E9E6A" : "#2E7D4A"
        readonly property color dimmedColor: MoneroComponents.Style.dimmedFontColor

        ColumnLayout {
            id: selectedAddressDetailsColumn
            Layout.fillWidth: true
            spacing: 0
            property int qrSize: 220

            MoneroComponents.Navbar {
                id: receiveNavbar
                Layout.alignment: Qt.AlignHCenter

                MoneroComponents.NavbarItem {
                    active: state == "Address"
                    text: qsTr("Address") + translationManager.emptyString
                    onSelected: state = "Address"
                }

                MoneroComponents.NavbarItem {
                    active: state == "PaymentRequest"
                    text: qsTr("Payment request") + translationManager.emptyString
                    onSelected: {
                        state = "PaymentRequest";
                        qrCodeTextMouseArea.hoverEnabled = true;
                        if (pageReceive.selectedGroup && pageReceive.groupAmounts.length === 0) pageReceive.splitRandom();
                    }
                }
            }

            // QR + details card. Its top margin keeps the QR frame (brackets, glow) clear of the tabs.
            Item {
                id: qrCard
                property int pad: 20
                readonly property bool wide: mainLayout.width >= 620
                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.preferredHeight: qrCardGrid.implicitHeight + 2 * pad

                MoneroComponents.CardPanel {
                    anchors.fill: parent
                    cut: 12
                }

                GridLayout {
                    id: qrCardGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: qrCard.pad
                    columns: qrCard.wide ? 2 : 1
                    columnSpacing: 28
                    rowSpacing: 12

                    // QR slot: leaves room for the QrFrame brackets (drawn outside the code)
                    // and for the Monero badge that sits on its bottom edge.
                    Item {
                        id: qrSlot
                        visible: !pageReceive.selectedGroup
                        Layout.alignment: qrCard.wide ? (Qt.AlignTop | Qt.AlignLeft) : Qt.AlignHCenter
                        Layout.preferredWidth: selectedAddressDetailsColumn.qrSize + 40
                        Layout.preferredHeight: selectedAddressDetailsColumn.qrSize + 52

                        Rectangle {
                            id: qrContainer
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            width: selectedAddressDetailsColumn.qrSize
                            height: width
                            color: MoneroComponents.Style.blackTheme ? "white" : "transparent"
                            radius: 4

                            Image {
                                id: qrCode
                                anchors.fill: parent
                                anchors.margins: 1
                                smooth: false
                                fillMode: Image.PreserveAspectFit
                                source: pageReceive.selectedGroup ? "" : "image://qrcode/" + generateQRCodeString();

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onEntered: qrCodeTooltip.tooltipPopup.open()
                                    onExited: qrCodeTooltip.tooltipPopup.close()
                                    onClicked: (mouse) => {
                                        if (mouse.button == Qt.LeftButton){
                                            walletManager.saveQrCodeToClipboard(generateQRCodeString());
                                            appWindow.showStatusMessage(qsTr("QR code copied to clipboard") + translationManager.emptyString, 3);
                                        } else if (mouse.button == Qt.RightButton){
                                            qrMenu.x = this.mouseX;
                                            qrMenu.y = this.mouseY;
                                            qrMenu.open()
                                        }
                                    }
                                }
                            }

                            MoneroComponents.QrFrame {
                                anchors.fill: parent
                                accent: mainLayout.accentColor
                            }

                            Menu {
                                id: qrMenu
                                title: "QrCode"
                                currentIndex: menuItem1.hovered ? 0 : menuItem2.hovered ? 1 : -1

                                MenuItem {
                                    id: menuItem1
                                    text: qsTr("Copy to clipboard") + translationManager.emptyString;
                                    onTriggered: walletManager.saveQrCodeToClipboard(generateQRCodeString())
                                }

                                MenuItem {
                                    id: menuItem2
                                    text: qsTr("Save as Image") + translationManager.emptyString;
                                    onTriggered: qrFileDialog.open()
                                }
                            }

                            MoneroComponents.Tooltip {
                                id: qrCodeTooltip
                                text: qsTr("Left click: copy QR code to clipboard") + "<br>" +  qsTr("Right click: save QR code as image file") + translationManager.emptyString
                            }
                        }
                    }

                    // right side (below the QR on narrow windows)
                    ColumnLayout {
                        id: qrDetailsColumn
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: qrCard.wide ? 8 : 0
                        spacing: 12

                        /* ---- Address tab ---- */
                        MoneroComponents.SectionTitle {
                            id: selectedaddressIndex
                            Layout.fillWidth: true
                            visible: pageReceive.state == "Address"
                            text: pageReceive.selectedGroup
                                  ? qsTr("Addresses #%1 to #%2").arg(pageReceive.selectedGroup.from).arg(pageReceive.selectedGroup.from + pageReceive.selectedGroup.count - 1) + translationManager.emptyString
                                  : qsTr("Address #") + subaddressListView.currentIndex + translationManager.emptyString
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: pageReceive.state == "Address"
                            spacing: 8

                            MoneroComponents.TextPlain {
                                id: selectedAddressDrescription
                                Layout.fillWidth: true
                                text: "(" + qsTr("no label") + ")" + translationManager.emptyString
                                elide: Text.ElideRight
                                font.family: MoneroComponents.Style.fontMedium.name
                                font.pixelSize: 16
                                color: selectedAddressDrescriptionMouseArea.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                                tooltip: subaddressListView.currentIndex > 0 ? qsTr("Edit address label") : "" + translationManager.emptyString
                                MouseArea {
                                    id: selectedAddressDrescriptionMouseArea
                                    visible: subaddressListView.currentIndex > 0
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.tooltip ? parent.tooltipPopup.open() : ""
                                    onExited: parent.tooltip ? parent.tooltipPopup.close() : ""
                                    onClicked: {
                                        renameSubaddressLabel(appWindow.current_subaddress_table_index);
                                    }
                                }
                            }

                            MoneroComponents.ReceiveIconButton {
                                visible: subaddressListView.currentIndex > 0
                                icon: "edit"
                                tooltip: qsTr("Edit address label") + translationManager.emptyString
                                onClicked: renameSubaddressLabel(appWindow.current_subaddress_table_index)
                            }
                        }

                        // full address in an inset box, click (or the button) to copy
                        Item {
                            id: selectedAddressBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: selectedAddress.implicitHeight + 24
                            visible: pageReceive.state == "Address" && !pageReceive.selectedGroup

                            MoneroComponents.ReceiveFieldBackground {
                                anchors.fill: parent
                                focused: selectedAddressMouseArea.containsMouse
                                warning: pageReceive.currentAddressUsed
                                info: pageReceive.currentIsPrimary
                            }

                            MoneroComponents.TextPlain {
                                id: selectedAddress
                                anchors.left: parent.left
                                anchors.right: selectedAddressCopy.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                text: appWindow.current_address ? appWindow.current_address : ""
                                wrapMode: Text.WrapAnywhere
                                color: pageReceive.currentAddressUsed ? pageReceive.usedColor
                                       : pageReceive.currentIsPrimary ? pageReceive.primaryColor
                                       : selectedAddressMouseArea.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.defaultFontColor
                                font.pixelSize: 13
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                lineHeight: 1.15
                                themeTransition: false
                                tooltip: qsTr("Copy address to clipboard") + translationManager.emptyString
                                MouseArea {
                                    id: selectedAddressMouseArea
                                    enabled: !pageReceive.copyBlocked
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.tooltip ? parent.tooltipPopup.open() : ""
                                    onExited: parent.tooltip ? parent.tooltipPopup.close() : ""
                                    onClicked: {
                                        clipboard.setText(appWindow.current_address);
                                        appWindow.showStatusMessage(qsTr("Address copied to clipboard") + translationManager.emptyString, 3);
                                    }
                                }
                            }

                            MoneroComponents.ReceiveIconButton {
                                id: selectedAddressCopy
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "copy"
                                enabled: !pageReceive.copyBlocked
                                opacity: enabled ? 1 : 0.3
                                tooltip: qsTr("Copy address to clipboard") + translationManager.emptyString
                                onClicked: {
                                    clipboard.setText(appWindow.current_address);
                                    appWindow.showStatusMessage(qsTr("Address copied to clipboard") + translationManager.emptyString, 3);
                                }
                            }
                        }

                        // already used: warn and offer a fresh subaddress instead of reusing this one
                        RowLayout {
                            Layout.fillWidth: true
                            visible: pageReceive.state == "Address" && pageReceive.currentAddressUsed && !pageReceive.selectedGroup
                            spacing: 10
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: qsTr("This address already received a transaction. Reusing it lets anyone who knows it link your payments, so copying is disabled. Use a new address.") + translationManager.emptyString
                                font.pixelSize: 13
                                color: pageReceive.usedColor
                                themeTransition: false
                            }
                            MoneroComponents.StandardButton {
                                small: true
                                text: qsTr("Create new address") + translationManager.emptyString
                                fontSize: 13
                                onClicked: pageReceive.createNewAddress()
                            }
                        }

                        // primary address: explain why it is blue and cannot be copied from the box
                        RowLayout {
                            Layout.fillWidth: true
                            visible: pageReceive.state == "Address" && pageReceive.currentIsPrimary && !pageReceive.currentAddressUsed && !pageReceive.selectedGroup
                            spacing: 10
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: qsTr("This is your primary address (it starts with 4). Everyone who has it can link all the payments you receive on it, so it cannot be copied from here: use the QR code (right click to copy it) or, better, a new address.") + translationManager.emptyString
                                font.pixelSize: 13
                                color: pageReceive.primaryColor
                                themeTransition: false
                            }
                            MoneroComponents.StandardButton {
                                small: true
                                text: qsTr("Create new address") + translationManager.emptyString
                                fontSize: 13
                                onClicked: pageReceive.createNewAddress()
                            }
                        }

                        MoneroComponents.StandardButton {
                            Layout.topMargin: 4
                            small: true
                            text: qsTr("Show on device") + translationManager.emptyString
                            fontSize: 14
                            visible: pageReceive.state == "Address" && !pageReceive.selectedGroup && (appWindow.currentWallet ? appWindow.currentWallet.isHwBacked() : false)
                            onClicked: {
                                appWindow.deviceShowAddress = appWindow.current_address;
                                appWindow.currentWallet.deviceShowAddressAsync(
                                    appWindow.currentWallet.currentSubaddressAccount,
                                    appWindow.current_subaddress_table_index,
                                    '');
                            }
                        }

                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            visible: !!pageReceive.selectedGroup
                            wrapMode: Text.WordWrap
                            font.pixelSize: 12
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                            text: (pageReceive.state == "PaymentRequest"
                                   ? qsTr("Write the total: it is split at random among the %1 addresses. Copy the request and paste it in Send: each address is filled in with its amount.").arg(pageReceive.selectedGroup ? pageReceive.selectedGroup.count : 0)
                                   : qsTr("%1 addresses separated by commas. Paste them in the address field of Send and they are filled in as %1 recipients.").arg(pageReceive.selectedGroup ? pageReceive.selectedGroup.count : 0))
                                  + translationManager.emptyString
                        }

                        /* ---- Payment request tab ---- */
                        MoneroComponents.SectionTitle {
                            Layout.fillWidth: true
                            visible: pageReceive.state == "PaymentRequest"
                            text: qsTr("Payment request") + translationManager.emptyString
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: pageReceive.state == "PaymentRequest"
                            spacing: 18

                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: !pageReceive.selectedGroup
                                Layout.preferredWidth: pageReceive.selectedGroup ? 360 : -1
                                Layout.maximumWidth: pageReceive.selectedGroup ? 360 : Number.POSITIVE_INFINITY
                                spacing: 8

                                GridLayout {
                                    id: paymentRequestGridLayout
                                    columns: 3
                                    rows: 4
                                    visible: pageReceive.state == "PaymentRequest"
                                    Layout.fillWidth: true
                                    columnSpacing: 10
                                    rowSpacing: 8

                                    MoneroComponents.Label {
                                        id: amountTitleFiat
                                        Layout.preferredWidth: 100
                                        visible: persistentSettings.fiatPriceEnabled
                                        fontSize: 13
                                        color: MoneroComponents.Style.dimmedFontColor
                                        text: qsTr("Amount") + translationManager.emptyString
                                    }

                                    MoneroComponents.Input {
                                        id: amountToReceiveFiat
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        visible: persistentSettings.fiatPriceEnabled
                                        topPadding: 0
                                        bottomPadding: 0
                                        leftPadding: 10
                                        font.family: MoneroComponents.Style.fontMonoRegular.name
                                        font.pixelSize: 14
                                        font.bold: false
                                        horizontalAlignment: TextInput.AlignLeft
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        color: MoneroComponents.Style.defaultFontColor
                                        placeholderTextColor: Qt.rgba(mainLayout.dimmedColor.r, mainLayout.dimmedColor.g, mainLayout.dimmedColor.b, 0.55)
                                        placeholderText: "0.00"

                                        background: MoneroComponents.ReceiveFieldBackground {
                                            focused: amountToReceiveFiat.activeFocus
                                        }
                                        onTextEdited: {
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
                                            if (amountToReceiveFiat.text == "") {
                                                amountToReceiveXMR.text = "";
                                            } else {
                                                amountToReceiveXMR.text = fiatApiConvertToXMR(amountToReceiveFiat.text);
                                            }
                                        }
                                        validator: RegularExpressionValidator {
                                            regularExpression: /^\s*(\d{1,8})?([\.,]\d{1,2})?\s*$/
                                        }
                                    }

                                    MoneroComponents.Label {
                                        Layout.preferredWidth: 40
                                        visible: persistentSettings.fiatPriceEnabled
                                        fontSize: 13
                                        fontFamily: MoneroComponents.Style.fontMonoMedium.name
                                        color: MoneroComponents.Style.dimmedFontColor
                                        text: appWindow.fiatApiCurrencySymbol();
                                    }

                                    MoneroComponents.Label {
                                        id: amountTitleXMR
                                        Layout.preferredWidth: 100
                                        fontSize: 13
                                        color: MoneroComponents.Style.dimmedFontColor
                                        text: persistentSettings.fiatPriceEnabled ? "" : qsTr("Amount") + translationManager.emptyString
                                    }

                                    MoneroComponents.Input {
                                        id: amountToReceiveXMR
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        topPadding: 0
                                        bottomPadding: 0
                                        leftPadding: 10
                                        font.family: MoneroComponents.Style.fontMonoRegular.name
                                        font.pixelSize: 14
                                        font.bold: false
                                        horizontalAlignment: TextInput.AlignLeft
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        color: MoneroComponents.Style.defaultFontColor
                                        placeholderTextColor: Qt.rgba(mainLayout.dimmedColor.r, mainLayout.dimmedColor.g, mainLayout.dimmedColor.b, 0.55)
                                        placeholderText: pageReceive.selectedGroup ? qsTr("Total") + translationManager.emptyString : "0.000000000000"
                                        onTextChanged: if (pageReceive.selectedGroup) pageReceive.splitRandom()

                                        background: MoneroComponents.ReceiveFieldBackground {
                                            focused: amountToReceiveXMR.activeFocus
                                        }
                                        onTextEdited: {
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
                                            if (amountToReceiveXMR.text == "") {
                                                amountToReceiveFiat.text = "";
                                            } else {
                                                amountToReceiveFiat.text = fiatApiConvertToFiat(amountToReceiveXMR.text);
                                            }
                                        }
                                        validator: RegularExpressionValidator {
                                            regularExpression: /^\s*(\d{1,8})?([\.,]\d{1,12})?\s*$/
                                        }
                                    }

                                    MoneroComponents.Label {
                                        Layout.preferredWidth: 40
                                        fontSize: 13
                                        fontFamily: MoneroComponents.Style.fontMonoMedium.name
                                        color: MoneroComponents.Style.dimmedFontColor
                                        text: "XMR"
                                    }

                                    MoneroComponents.Label {
                                        id: txDescription
                                        visible: !pageReceive.selectedGroup
                                        Layout.preferredWidth: 100
                                        fontSize: 13
                                        color: MoneroComponents.Style.dimmedFontColor
                                        text: qsTr("Description") + translationManager.emptyString
                                        tooltip: qsTr("What is being payed for (a product, service, donation) (optional)") + translationManager.emptyString
                                        tooltipIconVisible: true
                                    }

                                    MoneroComponents.Input {
                                        id: txDescriptionInput
                                        visible: !pageReceive.selectedGroup
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        maximumLength: 800
                                        topPadding: 0
                                        bottomPadding: 0
                                        leftPadding: 10
                                        font.pixelSize: 14
                                        font.bold: false
                                        horizontalAlignment: TextInput.AlignLeft
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        color: MoneroComponents.Style.defaultFontColor
                                        placeholderTextColor: Qt.rgba(mainLayout.dimmedColor.r, mainLayout.dimmedColor.g, mainLayout.dimmedColor.b, 0.55)
                                        placeholderText: qsTr("Visible to the sender") + translationManager.emptyString

                                        background: MoneroComponents.ReceiveFieldBackground {
                                            focused: txDescriptionInput.activeFocus
                                        }
                                    }

                                    Item { visible: !pageReceive.selectedGroup; Layout.preferredWidth: 40; Layout.preferredHeight: 1 }

                                    MoneroComponents.Label {
                                        id: receiverNameLabel
                                        visible: !pageReceive.selectedGroup
                                        Layout.preferredWidth: 100
                                        fontSize: 13
                                        color: MoneroComponents.Style.dimmedFontColor
                                        text: qsTr("Your name") + translationManager.emptyString
                                        tooltip: qsTr("Your name, company or website (optional)") + translationManager.emptyString
                                        tooltipIconVisible: true
                                    }

                                    MoneroComponents.Input {
                                        id: receiverNameInput
                                        visible: !pageReceive.selectedGroup
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        topPadding: 0
                                        bottomPadding: 0
                                        leftPadding: 10
                                        font.pixelSize: 14
                                        font.bold: false
                                        horizontalAlignment: TextInput.AlignLeft
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        color: MoneroComponents.Style.defaultFontColor
                                        placeholderTextColor: Qt.rgba(mainLayout.dimmedColor.r, mainLayout.dimmedColor.g, mainLayout.dimmedColor.b, 0.55)
                                        placeholderText: qsTr("Visible to the sender") + translationManager.emptyString
                                        maximumLength: 100

                                        background: MoneroComponents.ReceiveFieldBackground {
                                            focused: receiverNameInput.activeFocus
                                        }
                                    }

                                    Item { visible: !pageReceive.selectedGroup; Layout.preferredWidth: 40; Layout.preferredHeight: 1 }
                                }

                                MoneroComponents.StandardButton {
                                    small: true
                                    primary: false
                                    visible: pageReceive.state == "PaymentRequest" && !!pageReceive.selectedGroup
                                    text: qsTr("Split again") + translationManager.emptyString
                                    fontSize: 13
                                    onClicked: {
                                        pageReceive.splitRandom();
                                        if (pageReceive.groupAmounts.length === 0)
                                            appWindow.showStatusMessage(qsTr("Write the total amount first") + translationManager.emptyString, 3);
                                    }
                                }

                                // the split, one line per address
                                ListView {
                                    id: groupAmountsList
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(count, 6) * 20
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar { policy: groupAmountsList.contentHeight > groupAmountsList.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded }
                                    visible: pageReceive.state == "PaymentRequest" && pageReceive.groupAmounts.length > 0
                                             && pageReceive.groupAmounts.length === pageReceive.selectedGroupAddresses.length
                                        model: visible ? pageReceive.groupAmounts.length : 0
                                        delegate: RowLayout {
                                            width: groupAmountsList.width - 14
                                            height: 20
                                            spacing: 10
                                            MoneroComponents.TextPlain {
                                                Layout.preferredWidth: 46
                                                text: "#" + (pageReceive.selectedGroup.from + index)
                                                font.pixelSize: 12
                                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                                color: MoneroComponents.Style.dimmedFontColor
                                                themeTransition: false
                                            }
                                            MoneroComponents.TextPlain {
                                                Layout.fillWidth: true
                                                text: TxUtils.addressTruncatePretty(pageReceive.selectedGroupAddresses[index] || "", 1)
                                                font.pixelSize: 12
                                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                                color: MoneroComponents.Style.dimmedFontColor
                                                elide: Text.ElideRight
                                                themeTransition: false
                                            }
                                            MoneroComponents.TextPlain {
                                                text: pageReceive.piconeroText(pageReceive.groupAmounts[index]) + " XMR"
                                                font.pixelSize: 12
                                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                                color: MoneroComponents.Style.defaultFontColor
                                                themeTransition: false
                                            }
                                        }
                                }
                            }

                            // the group's request: one column, the whole width left
                            GroupTextBox {
                                visible: !!pageReceive.selectedGroup
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 84
                            }
                        }

                        /* ---- address group: all its addresses, comma separated ---- */
                        GroupTextBox {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            visible: pageReceive.state == "Address" && !!pageReceive.selectedGroup
                        }

                        // the payment request URI, click to copy
                        Item {
                            id: qrCodeTextBox
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.preferredHeight: qrCodeText.implicitHeight + 22
                            visible: qrCodeText.visible && !pageReceive.selectedGroup

                            MoneroComponents.ReceiveFieldBackground {
                                anchors.fill: parent
                                focused: qrCodeTextMouseArea.containsMouse
                            }

                            MoneroComponents.TextPlain {
                                id: qrCodeText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                visible: paymentRequestGridLayout.visible
                                font.pixelSize: 12
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                color: qrCodeTextMouseArea.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.dimmedFontColor
                                text: generateQRCodeString();
                                wrapMode: Text.WrapAnywhere
                                tooltip: qsTr("Copy payment request to clipboard") + translationManager.emptyString
                                themeTransition: false

                                MouseArea {
                                    id: qrCodeTextMouseArea
                                    hoverEnabled: false //true when Payment request navbar button is clicked (fix bug displaying tooltip when navbar button is clicked)
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.tooltipPopup.open()
                                    onExited: parent.tooltipPopup.close()
                                    onClicked: {
                                        clipboard.setText(qrCodeText.text);
                                        appWindow.showStatusMessage(qsTr("Payment request copied to clipboard") + translationManager.emptyString, 3);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: addressRow
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                MoneroComponents.SectionTitle {
                    Layout.fillWidth: false
                    text: qsTr("Addresses") + translationManager.emptyString
                }

                MoneroComponents.CheckBox {
                    id: hideUsedCheckBox
                    // CheckBox sizes itself from its label; give the layout that width so the text is not cut
                    Layout.preferredWidth: hideUsedCheckBox.width
                    Layout.leftMargin: 12
                    text: qsTr("Hide used addresses") + translationManager.emptyString
                    fontSize: 13
                    checked: persistentSettings.hideUsedAddresses
                    onClicked: persistentSettings.hideUsedAddresses = !persistentSettings.hideUsedAddresses
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.StandardButton {
                    id: bulkAddressButton
                    small: true
                    primary: false
                    enabled: !pageReceive.creatingGroup && !!appWindow.currentWallet
                    text: (pageReceive.creatingGroup ? qsTr("Creating…") : qsTr("Create addresses in bulk")) + translationManager.emptyString
                    fontSize: 13
                    onClicked: {
                        bulkCount.text = "10";
                        bulkLabel.text = "";
                        bulkPopup.open();
                    }
                }

                MoneroComponents.StandardButton {
                    id: createAddressButton
                    small: true
                    text: qsTr("Create new address") + translationManager.emptyString
                    fontSize: 13
                    onClicked: {
                        inputDialog.labelText = qsTr("Set the label of the new address:") + translationManager.emptyString
                        inputDialog.onAcceptedCallback = function() {
                            appWindow.currentWallet.subaddress.addRow(appWindow.currentWallet.currentSubaddressAccount, inputDialog.inputText)
                            current_subaddress_table_index = appWindow.currentWallet.numSubaddresses(appWindow.currentWallet.currentSubaddressAccount) - 1
                            subaddressListView.currentIndex = current_subaddress_table_index
                        }
                        inputDialog.onRejectedCallback = null;
                        inputDialog.open()
                    }
                }

            }

            ColumnLayout {
                id: subaddressListRow
                property int subaddressListItemHeight: 48
                property int subaddressListSpacing: 6
                Layout.topMargin: 14
                Layout.fillWidth: true
                Layout.minimumWidth: 240
                // hidden (used) rows take no space
                // mined addresses live in the mined addresses account only (Wallet+)
                function isMined(i) {
                    var w = appWindow.currentWallet;
                    return (appWindow.minedAddressesTick, !!w && w.isMinedAddress(w.currentSubaddressAccount, i));
                }
                function isHiddenRow(i) {
                    var g = pageReceive.groupAt(i);
                    if (g) return i !== g.from;   // a group shows as its first row only
                    return (persistentSettings.hideUsedAddresses && pageReceive.usedAddresses[i] === true) || isMined(i);
                }
                readonly property int shownCount: {
                    appWindow.minedAddressesTick;
                    pageReceive.groups;
                    var n = 0;
                    for (var i = 0; i < subaddressListView.count; ++i)
                        if (!isHiddenRow(i)) n++;
                    return n;
                }
                // thousands of addresses (e.g. created up to a far "mined" one): a list as tall as all its rows
                // builds every row at once and freezes the window, so long lists scroll inside a fixed height
                // and only the visible rows exist
                readonly property bool longList: shownCount > 60
                Layout.preferredHeight: (subaddressListItemHeight + subaddressListSpacing) * (longList ? 12 : shownCount)
                visible: shownCount >= 1

                ListView {
                    id: subaddressListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: ListView.StopAtBounds
                    interactive: subaddressListRow.longList
                    reuseItems: true
                    ScrollBar.vertical: ScrollBar { policy: subaddressListRow.longList ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
                    // the spacing lives in each delegate, so a hidden row leaves no gap
                    spacing: 0

                    delegate: Item {
                      readonly property bool hiddenRow: subaddressListRow.isHiddenRow(index)
                      width: subaddressListView.width
                      height: hiddenRow ? 0 : subaddressListRow.subaddressListItemHeight + subaddressListRow.subaddressListSpacing
                      visible: !hiddenRow

                      readonly property var group: pageReceive.groupAt(index)
                      MoneroComponents.ReceiveAddressRow {
                        id: tableItem2
                        width: subaddressListView.width
                        height: subaddressListRow.subaddressListItemHeight
                        addressIndex: index
                        label: group ? "▦ " + group.label + "  ·  " + qsTr("%1 addresses").arg(group.count) + translationManager.emptyString
                                     : model.label !== "" ? model.label : "(" + qsTr("no label") + ")" + translationManager.emptyString
                        address: group ? qsTr("#%1 to #%2").arg(group.from).arg(group.from + group.count - 1) + translationManager.emptyString
                                       : TxUtils.addressTruncatePretty(model.address, mainLayout.width < 560 ? 1 : (mainLayout.width < 680 ? 2 : 3))
                        selected: group ? !!pageReceive.selectedGroup && pageReceive.selectedGroup.from === group.from
                                        : index === appWindow.current_subaddress_table_index && !pageReceive.selectedGroup
                        historyTooltip: qsTr("See transactions") + translationManager.emptyString
                        editTooltip: qsTr("Edit address label") + translationManager.emptyString
                        copyTooltip: qsTr("Copy address to clipboard") + translationManager.emptyString
                        used: group ? pageReceive.groupUsed(group) : pageReceive.usedAddresses[index] === true
                        usedText: qsTr("USED") + translationManager.emptyString
                        primary: index === 0 && appWindow.currentWallet && appWindow.currentWallet.currentSubaddressAccount === 0
                        primaryText: qsTr("PRIMARY") + translationManager.emptyString

                        onClicked: {
                            if (group) { pageReceive.selectGroup(group); return; }
                            pageReceive.selectedGroup = null;
                            subaddressListView.currentIndex = index;
                            updateSelectedAddressDisplay();
                        }
                        onHistoryClicked: doSearchInHistory(model.address)
                        onEditClicked: group ? pageReceive.renameGroup(group) : renameSubaddressLabel(index)
                        onCopyClicked: {
                            clipboard.setText(group ? pageReceive.groupAddresses(group).join(",") : model.address);
                            appWindow.showStatusMessage((group ? qsTr("Addresses copied to clipboard") : qsTr("Address copied to clipboard")) + translationManager.emptyString, 3);
                        }
                      }
                    }
                    onCurrentItemChanged: updateSelectedAddressDisplay()
                }
            }
        }

        Popup {
            id: bulkPopup
            parent: Overlay.overlay
            anchors.centerIn: parent
            modal: true
            focus: true
            width: 380
            padding: 20
            readonly property int count: parseInt(bulkCount.text)
            readonly property bool valid: count >= 2 && count <= 50
            background: MoneroComponents.CardPanel { cut: 12 }
            onOpened: bulkCount.input.forceActiveFocus()

            contentItem: ColumnLayout {
                spacing: 12
                MoneroComponents.SectionTitle {
                    Layout.fillWidth: true
                    text: qsTr("Create addresses in bulk") + translationManager.emptyString
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    text: qsTr("They are created in a row and shown as one row with one label. You can copy them all at once, separated by commas.") + translationManager.emptyString
                }
                MoneroComponents.LineEdit {
                    id: bulkCount
                    Layout.fillWidth: true
                    labelText: qsTr("How many (2 to 50)") + translationManager.emptyString
                    labelFontSize: 13
                    inputHeight: 36
                    error: text !== "" && !bulkPopup.valid
                    validator: RegularExpressionValidator { regularExpression: /^\d{0,2}$/ }
                    onAccepted: bulkCreate.clicked()
                }
                MoneroComponents.LineEdit {
                    id: bulkLabel
                    Layout.fillWidth: true
                    labelText: qsTr("Label") + translationManager.emptyString
                    labelFontSize: 13
                    inputHeight: 36
                    placeholderText: qsTr("e.g. Group 1") + translationManager.emptyString
                    onAccepted: bulkCreate.clicked()
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Item { Layout.fillWidth: true }
                    MoneroComponents.StandardButton {
                        small: true
                        primary: false
                        text: qsTr("Cancel") + translationManager.emptyString
                        onClicked: bulkPopup.close()
                    }
                    MoneroComponents.StandardButton {
                        id: bulkCreate
                        small: true
                        enabled: bulkPopup.valid
                        text: qsTr("Create") + translationManager.emptyString
                        onClicked: {
                            if (!bulkPopup.valid) return;
                            var label = bulkLabel.text.trim() !== "" ? bulkLabel.text.trim() : qsTr("Group") + translationManager.emptyString;
                            bulkPopup.close();
                            pageReceive.createGroup(bulkPopup.count, label);
                        }
                    }
                }
            }
        }

        MessageDialog {
            id: receivePageDialog
            buttons: MessageDialog.Ok
        }

        FileDialog {
            id: qrFileDialog
            title: qsTr("Please choose a name") + translationManager.emptyString
            fileMode: FileDialog.SaveFile
            nameFilters: ["Image (*.png)"]
            onAccepted: {
                if(!walletManager.saveQrCode(generateQRCodeString(), walletManager.urlToLocalPath(selectedFile))) {
                    console.log("Failed to save QrCode to file " + walletManager.urlToLocalPath(selectedFile) )
                    receivePageDialog.title = qsTr("Save QrCode") + translationManager.emptyString;
                    receivePageDialog.text = qsTr("Failed to save QrCode to ") + walletManager.urlToLocalPath(selectedFile) + translationManager.emptyString;
                    receivePageDialog.open()
                } else {
                    appWindow.showStatusMessage(qsTr("QR code saved to ") + walletManager.urlToLocalPath(selectedFile) + translationManager.emptyString, 3);
                }
            }
        }
    }

    function onPageCompleted() {
        console.log("Receive page loaded");
        pageReceive.clearFields();
        subaddressListView.model = appWindow.currentWallet.subaddressModel;

        if (appWindow.currentWallet) {
            appWindow.currentWallet.subaddress.refresh(appWindow.currentWallet.currentSubaddressAccount)
            var numSubaddresses = appWindow.currentWallet.numSubaddresses(appWindow.currentWallet.currentSubaddressAccount);
            if (subaddressListView.currentIndex == -1 || subaddressListView.currentIndex >= numSubaddresses) {
                subaddressListView.currentIndex = 0;
            }
            updateSelectedAddressDisplay();
            updateUsedAddresses();
        }
    }

    function clearFields() {
        amountToReceiveFiat.text = "";
        amountToReceiveXMR.text = "";
        txDescriptionInput.text = "";
        receiverNameInput.text = "";
    }

    function onPageClosed() {
    }
}
