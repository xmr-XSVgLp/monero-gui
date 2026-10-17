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

import "../js/TxUtils.js" as TxUtils
import moneroComponents.AddressBook 1.0
import moneroComponents.AddressBookModel 1.0
import moneroComponents.Clipboard 1.0
import moneroComponents.NetworkType 1.0

Rectangle {
    id: root
    color: "transparent"
    property alias addressbookHeight: mainLayout.height
    property bool selectAndSend: false
    property bool editEntry: false

    Clipboard { id: clipboard }

    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right

        spacing: 20

        // empty address book: intro card
        Item {
            id: addressBookEmptyLayout
            visible: addressBookListView.count == 0
            Layout.fillWidth: true
            implicitHeight: emptyColumn.implicitHeight + 56

            MoneroComponents.CardPanel {
                anchors.fill: parent
                cut: 12
            }

            ColumnLayout {
                id: emptyColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 28
                spacing: 10

                MoneroComponents.SectionTitle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    text: qsTr("Address book") + translationManager.emptyString
                }

                Text {
                    id: titleLabel
                    Layout.fillWidth: true
                    color: MoneroComponents.Style.defaultFontColor
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 26
                    horizontalAlignment: TextInput.AlignLeft
                    wrapMode: Text.WordWrap;
                    leftPadding: 0
                    topPadding: 0
                    text: qsTr("Save your most used addresses here") + translationManager.emptyString
                }

                Text {
                    Layout.fillWidth: true
                    color: MoneroComponents.Style.dimmedFontColor
                    font.family: MoneroComponents.Style.fontRegular.name
                    font.pixelSize: 15
                    horizontalAlignment: TextInput.AlignLeft
                    wrapMode: Text.WordWrap;
                    leftPadding: 0
                    topPadding: 0
                    text: qsTr("This makes it easier to send or receive Monero and reduces errors when typing in addresses manually.") + translationManager.emptyString
                }

                MoneroComponents.StandardButton {
                    id: addFirstEntryButton
                    Layout.topMargin: 14
                    small: true
                    text: qsTr("Add an address") + translationManager.emptyString
                    onClicked: {
                        root.showAddAddress();
                    }
                }
            }
        }

        ColumnLayout {
            id: addressBookLayout
            visible: addressBookListView.count >= 1
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                MoneroComponents.LabelSubheader {
                    Layout.fillWidth: true
                    fontSize: 24
                    textFormat: Text.RichText
                    text: qsTr("Address book") + translationManager.emptyString
                }

                MoneroComponents.StandardButton {
                    id: addAddressButton
                    small: true
                    text: qsTr("Add address") + translationManager.emptyString
                    fontSize: 13
                    onClicked: {
                        root.showAddAddress();
                    }
                }
            }

            ColumnLayout {
                id: addressBookListRow
                property int addressBookListItemHeight: 48
                property int addressBookListSpacing: 6
                Layout.topMargin: 14
                Layout.fillWidth: true
                Layout.minimumWidth: 240
                Layout.preferredHeight: (addressBookListItemHeight + addressBookListSpacing) * addressBookListView.count

                ListView {
                    id: addressBookListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: ListView.StopAtBounds
                    interactive: false
                    spacing: addressBookListRow.addressBookListSpacing
                    delegate: Item {
                        id: tableItem2
                        height: addressBookListRow.addressBookListItemHeight
                        width: addressBookListView.width
                        readonly property bool hovered: rowHover.hovered

                        function doSend() {
                            console.log("Sending to: ", address +" "+ paymentId);
                            middlePanel.sendTo(address, paymentId);
                            leftPanel.selectItem(middlePanel.state)
                        }

                        HoverHandler { id: rowHover }

                        MoneroComponents.CardPanel {
                            anchors.fill: parent
                            cut: 8
                            hovered: tableItem2.hovered
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            visible: root.selectAndSend
                            onClicked: {
                                doSend();
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 9
                            spacing: 12

                            // initial badge
                            Item {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 26

                                MoneroComponents.NeonFrame {
                                    anchors.fill: parent
                                    cut: 5
                                    accent: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
                                    lineOpacity: tableItem2.hovered ? 0.95 : 0.55
                                    fillColor: accent
                                    fillOpacity: tableItem2.hovered ? 0.18 : 0.06
                                    ticks: false
                                }

                                MoneroComponents.TextPlain {
                                    anchors.centerIn: parent
                                    text: description ? description.charAt(0).toUpperCase() : "#"
                                    font.family: MoneroComponents.Style.fontMonoMedium.name
                                    font.pixelSize: 13
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }
                            }

                            MoneroComponents.TextPlain {
                                id: descriptionLabel
                                Layout.fillWidth: true
                                Layout.minimumWidth: 60
                                text: description
                                elide: Text.ElideRight
                                font.family: MoneroComponents.Style.fontMedium.name
                                font.pixelSize: 15
                                color: tableItem2.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.lightGreyFontColor
                                themeTransition: false
                            }

                            MoneroComponents.TextPlain {
                                id: addressLabel
                                Layout.rightMargin: 4
                                text: TxUtils.addressTruncatePretty(address, mainLayout.width < 600 ? 1 : (mainLayout.width < 760 ? 2 : 3));
                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                font.pixelSize: 12
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }

                            RowLayout {
                                spacing: 6

                                MoneroComponents.BookIconButton {
                                    id: sendToButton
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    icon: FontAwesome.arrowRight
                                    iconFamily: FontAwesome.fontFamilySolid
                                    iconStyle: "Solid"
                                    iconSize: 13
                                    tooltip: qsTr("Send to this address") + translationManager.emptyString
                                    onClicked: {
                                        doSend();
                                    }
                                }

                                MoneroComponents.BookIconButton {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    icon: FontAwesome.searchPlus
                                    iconFamily: FontAwesome.fontFamilySolid
                                    iconStyle: "Solid"
                                    iconSize: 13
                                    tooltip: qsTr("See transactions") + translationManager.emptyString
                                    onClicked: doSearchInHistory(address)
                                }

                                MoneroComponents.BookIconButton {
                                    id: editEntryButton
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    image: "qrc:///images/edit-neon.png"
                                    tooltip: qsTr("Edit entry") + translationManager.emptyString
                                    onClicked: {
                                        addressBookListView.currentIndex = index;
                                        root.showEditAddress(address, description);
                                    }
                                }

                                MoneroComponents.BookIconButton {
                                    id: copyButton
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    image: "qrc:///images/copy-neon.png"
                                    tooltip: qsTr("Copy address to clipboard") + translationManager.emptyString
                                    onClicked: {
                                        console.log("Address copied to clipboard");
                                        clipboard.setText(address);
                                        appWindow.showStatusMessage(qsTr("Address copied to clipboard"), 3);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: addContactLayout
            visible: false
            spacing: 0

            MoneroComponents.LabelSubheader {
                Layout.fillWidth: true
                fontSize: 24
                wrapMode: Text.WordWrap
                text: (root.editEntry ? qsTr("Edit entry") : qsTr("Add an address")) + translationManager.emptyString
            }

            Item {
                Layout.topMargin: 14
                Layout.fillWidth: true
                implicitHeight: formColumn.implicitHeight + 40

                MoneroComponents.CardPanel {
                    anchors.fill: parent
                    cut: 12
                }

                ColumnLayout {
                    id: formColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 0

                    // editing: the address cannot change, show it read-only
                    MoneroComponents.TextPlain {
                        visible: root.editEntry
                        Layout.fillWidth: true
                        text: qsTr("Address") + translationManager.emptyString
                        font.family: MoneroComponents.Style.fontRegular.name
                        font.pixelSize: 16
                    }

                    MoneroComponents.TextPlain {
                        visible: root.editEntry
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        text: addressLine.text
                        wrapMode: Text.WrapAnywhere
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 13
                        lineHeight: 1.15
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                    }

                    MoneroComponents.LineEditMulti {
                        id: addressLine
                        visible: !root.editEntry
                        KeyNavigation.backtab: deleteButton.visible ? deleteButton: cancelButton
                        KeyNavigation.tab: resolveButton.visible ? resolveButton : descriptionLine
                        labelText: "<style type='text/css'>a {text-decoration: none; color: #858585; font-size: 14px;}</style> %1"
                            .arg(qsTr("Address")) + translationManager.emptyString
                        placeholderText: {
                            if(persistentSettings.nettype == NetworkType.MAINNET){
                                return "4.. / 8.. / monero:.. / OpenAlias";
                            } else if (persistentSettings.nettype == NetworkType.STAGENET){
                                return "5.. / 7.. / monero:..";
                            } else if(persistentSettings.nettype == NetworkType.TESTNET){
                                return "9.. / B.. / monero:..";
                            }
                        }
                        wrapMode: Text.WrapAnywhere
                        addressValidation: true
                        pasteButton: false
                        onTextChanged: {
                            const parsed = walletManager.parse_uri_to_object(addressLine.text);
                            if (!parsed.error) {
                                addressLine.text = parsed.address;
                                descriptionLine.text = parsed.tx_description;
                            }
                        }
                        onEnterPressed: addButton.enabled ? addButton.clicked() : ""
                        onReturnPressed: addButton.enabled ? addButton.clicked() : ""

                        MoneroComponents.InlineButton {
                            fontFamily: FontAwesome.fontFamilySolid
                            fontStyleName: "Solid"
                            fontPixelSize: 18
                            text: FontAwesome.desktop
                            tooltip: qsTr("Grab QR code from screen") + translationManager.emptyString
                            onClicked: {
                                clearFields();
                                const codes = oshelper.grabQrCodesFromScreen();
                                for (var index = 0; index < codes.length; ++index) {
                                    const parsed = walletManager.parse_uri_to_object(codes[index]);
                                    if (!parsed.error) {
                                        addressLine.text = parsed.address
                                        descriptionLine.text = parsed.recipient_name
                                        break;
                                    } else if (walletManager.addressValid(codes[index], appWindow.persistentSettings.nettype)) {
                                        addressLine.text = codes[index];
                                        break;
                                    }
                                }
                            }
                        }

                        MoneroComponents.InlineButton {
                            buttonColor: MoneroComponents.Style.orange
                            fontFamily: FontAwesome.fontFamily
                            text: FontAwesome.qrcode
                            visible : appWindow.qrScannerEnabled && !addressLine.text
                            onClicked: {
                                cameraUi.state = "Capture"
                                cameraUi.qrcode_decoded.connect(root.updateFromQrCode)
                            }
                        }
                    }

                    MoneroComponents.StandardButton {
                        id: resolveButton
                        KeyNavigation.backtab: addressLine
                        KeyNavigation.tab: descriptionLine
                        Layout.topMargin: 10
                        text: qsTr("Resolve") + translationManager.emptyString
                        visible: TxUtils.isValidOpenAliasAddress(addressLine.text)
                        enabled : visible
                        onClicked: {
                            const openAlias = addressLine.text;
                            const response = TxUtils.handleOpenAliasResolution(addressLine.text, descriptionLine.text);
                            if (response) {
                                if (response.confirm && response.address) {
                                    const resolvedAddress = response.address;
                                    const resolvedDescription = response.description;
                                    oa_confirm(openAlias, resolvedAddress, function() {
                                        addressLine.text = resolvedAddress;
                                        if (resolvedDescription) {
                                            descriptionLine.text = resolvedDescription;
                                        }
                                    });
                                    return;
                                }
                                if (response.message) {
                                    oa_message(response.message);
                                }
                                if (response.address) {
                                    addressLine.text = response.address;
                                }
                                if (response.description) {
                                    descriptionLine.text = response.description;
                                }
                            }
                        }
                    }

                    MoneroComponents.LineEdit {
                        id: descriptionLine
                        KeyNavigation.backtab: resolveButton.visible ? resolveButton : addressLine
                        KeyNavigation.tab: addButton.enabled ? addButton : cancelButton
                        Layout.topMargin: 20
                        Layout.fillWidth: true
                        fontSize: 16
                        placeholderFontSize: 16
                        labelText: "<style type='text/css'>a {text-decoration: none; color: #858585; font-size: 14px;}</style> %1"
                            .arg(qsTr("Description")) + translationManager.emptyString
                        placeholderText: qsTr("Add a name...") + translationManager.emptyString
                        onAccepted: addButton.enabled ? addButton.clicked() : ""
                    }
                    RowLayout {
                        Layout.topMargin: 20
                        Layout.alignment: Qt.AlignRight

                        MoneroComponents.StandardButton {
                            id: cancelButton
                            KeyNavigation.backtab: addButton
                            KeyNavigation.tab: deleteButton.visible ? deleteButton : addressLine
                            small: true
                            text: qsTr("Cancel") + translationManager.emptyString
                            primary: false
                            onClicked: root.showAddressBook();
                        }

                        MoneroComponents.StandardButton {
                            id: deleteButton
                            KeyNavigation.backtab: cancelButton
                            KeyNavigation.tab: addressLine
                            small: true
                            visible: root.editEntry
                            text: qsTr("Delete") + translationManager.emptyString
                            primary: false
                            onClicked: {
                                currentWallet.addressBook.deleteRow(addressBookListView.currentIndex);
                                root.showAddressBook();
                            }
                        }

                        MoneroComponents.StandardButton {
                            id: addButton
                            KeyNavigation.backtab: descriptionLine
                            KeyNavigation.tab: cancelButton
                            small: true
                            text: (root.editEntry ? qsTr("Save") : qsTr("Add")) + translationManager.emptyString
                            enabled: root.checkInformation(addressLine.text, appWindow.persistentSettings.nettype)
                            onClicked: {
                                if (!root.editEntry) {
                                    if (currentWallet.addressBook.addRow(addressLine.text.trim(),"", descriptionLine.text)) {
                                        console.log("Entry added")
                                    } else {
                                        informationPopup.title = qsTr("Error") + translationManager.emptyString;
                                        // TODO: check currentWallet.addressBook.errorString() instead.
                                        if (currentWallet.addressBook.errorCode() === AddressBook.Invalid_Address)
                                            informationPopup.text  = qsTr("Invalid address") + translationManager.emptyString
                                        else if (currentWallet.addressBook.errorCode() === AddressBook.Invalid_Payment_Id)
                                            informationPopup.text  = currentWallet.addressBook.errorString()
                                        else
                                            informationPopup.text  = qsTr("Can't create entry") + translationManager.emptyString

                                        informationPopup.onCloseCallback = null
                                        informationPopup.open();
                                    }
                                } else {
                                    currentWallet.addressBook.setDescription(addressBookListView.currentIndex, descriptionLine.text);
                                    console.log("Description edited")
                                }
                                root.showAddressBook()
                            }
                        }
                    }
                }
            }
        }
    }

    function checkInformation(address, nettype) {
        address = address.trim()
        var address_ok = walletManager.addressValid(address, nettype)
        addressLine.error = !address_ok
        return address_ok
    }

    function clearFields() {
        addressLine.text = "";
        descriptionLine.text = "";
    }

    function showAddressBook() {
        addressBookEmptyLayout.visible = addressBookListView.count == 0
        addressBookLayout.visible = addressBookListView.count >= 1;
        addContactLayout.visible = false;
        clearFields();
    }

    function showAddAddress() {
        root.editEntry = false;
        addressBookEmptyLayout.visible = false
        addressBookLayout.visible = false;
        addContactLayout.visible = true;
        addressLine.forceActiveFocus();
    }

    function showEditAddress(address, description) {
        //TODO: real contact editing, requires API change
        root.editEntry = true;
        addressBookEmptyLayout.visible = false
        addressBookLayout.visible = false;
        addContactLayout.visible = true;
        addressLine.text = address;
        descriptionLine.text = description;
        addressLine.forceActiveFocus();
        addressLine.cursorPosition = addressLine.text.length;
    }

    function updateFromQrCode(address, payment_id, amount, tx_description, recipient_name) {
        console.log("updateFromQrCode")
        addressLine.text = address
        descriptionLine.text = recipient_name
        cameraUi.qrcode_decoded.disconnect(updateFromQrCode)
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

    MoneroComponents.StandardDialog {
        // dynamically change onclose handler
        property var onCloseCallback
        id: oaPopup
        cancelVisible: false
        onAccepted: {
            if (onCloseCallback) {
                onCloseCallback()
            }
        }
    }
    function onPageCompleted() {
        console.log("adress book");
        addressBookListView.model = currentWallet.addressBookModel;
        showAddressBook();
    }

    function onPageClosed() {
        root.selectAndSend = false;
        root.editEntry = false;
        clearFields();
    }
}
