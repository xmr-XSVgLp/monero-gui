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

    function renameSubaddressLabel(_index){
        inputDialog.labelText = qsTr("Set the label of the selected address:") + translationManager.emptyString;
        inputDialog.onAcceptedCallback = function() {
            appWindow.currentWallet.subaddress.setLabel(appWindow.currentWallet.currentSubaddressAccount, _index, inputDialog.inputText);
        }
        inputDialog.onRejectedCallback = null;
        inputDialog.open(appWindow.currentWallet.getSubaddressLabel(appWindow.currentWallet.currentSubaddressAccount, _index))
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
                                source: "image://qrcode/" + generateQRCodeString();

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
                            text: qsTr("Address #") + subaddressListView.currentIndex + translationManager.emptyString
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
                            visible: pageReceive.state == "Address"

                            MoneroComponents.ReceiveFieldBackground {
                                anchors.fill: parent
                                focused: selectedAddressMouseArea.containsMouse
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
                                color: selectedAddressMouseArea.containsMouse ? MoneroComponents.Style.textAccent : MoneroComponents.Style.defaultFontColor
                                font.pixelSize: 13
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                lineHeight: 1.15
                                themeTransition: false
                                tooltip: qsTr("Copy address to clipboard") + translationManager.emptyString
                                MouseArea {
                                    id: selectedAddressMouseArea
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
                                tooltip: qsTr("Copy address to clipboard") + translationManager.emptyString
                                onClicked: {
                                    clipboard.setText(appWindow.current_address);
                                    appWindow.showStatusMessage(qsTr("Address copied to clipboard") + translationManager.emptyString, 3);
                                }
                            }
                        }

                        MoneroComponents.StandardButton {
                            Layout.preferredWidth: 220
                            Layout.topMargin: 4
                            small: true
                            text: qsTr("Show on device") + translationManager.emptyString
                            fontSize: 14
                            visible: pageReceive.state == "Address" && (appWindow.currentWallet ? appWindow.currentWallet.isHwBacked() : false)
                            onClicked: {
                                appWindow.currentWallet.deviceShowAddressAsync(
                                    appWindow.currentWallet.currentSubaddressAccount,
                                    appWindow.current_subaddress_table_index,
                                    '');
                            }
                        }

                        /* ---- Payment request tab ---- */
                        MoneroComponents.SectionTitle {
                            Layout.fillWidth: true
                            visible: pageReceive.state == "PaymentRequest"
                            text: qsTr("Payment request") + translationManager.emptyString
                        }

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
                                placeholderText: "0.000000000000"

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
                                Layout.preferredWidth: 100
                                fontSize: 13
                                color: MoneroComponents.Style.dimmedFontColor
                                text: qsTr("Description") + translationManager.emptyString
                                tooltip: qsTr("What is being payed for (a product, service, donation) (optional)") + translationManager.emptyString
                                tooltipIconVisible: true
                            }

                            MoneroComponents.Input {
                                id: txDescriptionInput
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

                            Item { Layout.preferredWidth: 40; Layout.preferredHeight: 1 }

                            MoneroComponents.Label {
                                id: receiverNameLabel
                                Layout.preferredWidth: 100
                                fontSize: 13
                                color: MoneroComponents.Style.dimmedFontColor
                                text: qsTr("Your name") + translationManager.emptyString
                                tooltip: qsTr("Your name, company or website (optional)") + translationManager.emptyString
                                tooltipIconVisible: true
                            }

                            MoneroComponents.Input {
                                id: receiverNameInput
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

                            Item { Layout.preferredWidth: 40; Layout.preferredHeight: 1 }
                        }

                        // the payment request URI, click to copy
                        Item {
                            id: qrCodeTextBox
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.preferredHeight: qrCodeText.implicitHeight + 22
                            visible: qrCodeText.visible

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
                    Layout.fillWidth: true
                    text: qsTr("Addresses") + translationManager.emptyString
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
                Layout.preferredHeight: (subaddressListItemHeight + subaddressListSpacing) * subaddressListView.count
                visible: subaddressListView.count >= 1

                ListView {
                    id: subaddressListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: ListView.StopAtBounds
                    interactive: false
                    spacing: subaddressListRow.subaddressListSpacing

                    delegate: MoneroComponents.ReceiveAddressRow {
                        id: tableItem2
                        width: subaddressListView.width
                        height: subaddressListRow.subaddressListItemHeight
                        addressIndex: index
                        label: model.label !== "" ? model.label : "(" + qsTr("no label") + ")" + translationManager.emptyString
                        address: TxUtils.addressTruncatePretty(model.address, mainLayout.width < 560 ? 1 : (mainLayout.width < 680 ? 2 : 3))
                        selected: index === appWindow.current_subaddress_table_index
                        historyTooltip: qsTr("See transactions") + translationManager.emptyString
                        editTooltip: qsTr("Edit address label") + translationManager.emptyString
                        copyTooltip: qsTr("Copy address to clipboard") + translationManager.emptyString

                        onClicked: subaddressListView.currentIndex = index
                        onHistoryClicked: doSearchInHistory(model.address)
                        onEditClicked: renameSubaddressLabel(index)
                        onCopyClicked: {
                            console.log("Address copied to clipboard");
                            clipboard.setText(model.address);
                            appWindow.showStatusMessage(qsTr("Address copied to clipboard"),3);
                        }
                    }
                    onCurrentItemChanged: updateSelectedAddressDisplay()
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
