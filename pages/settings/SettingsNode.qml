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

import FontAwesome

import "../../js/Utils.js" as Utils
import "../../components" as MoneroComponents
import "../../components/effects" as MoneroEffects

Rectangle{
    color: "transparent"
    Layout.fillWidth: true
    property alias nodeHeight: root.height

    // local / remote node toggle: icon + name, selected = lit frame and green tint; the description in a tooltip
    component NodeTypeButton: Item {
        id: typeButton
        property string kind: "local"
        property string label: ""
        property string tip: ""
        property bool selected: false
        readonly property bool hovered: typeArea.containsMouse
        readonly property color accent: MoneroComponents.Style.blackTheme ? "#3DDC84" : "#2E7D4A"
        signal clicked()
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: typeRow.implicitWidth + 30
        implicitHeight: 52

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 9
            accent: typeButton.selected ? typeButton.accent : (MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30")
            lineOpacity: typeButton.selected ? 0.9 : (typeButton.hovered ? 0.6 : 0.3)
            fillColor: typeButton.accent
            fillOpacity: typeButton.selected ? 0.14 : (typeButton.hovered ? 0.05 : 0.0)
            glow: typeButton.selected ? 0.25 : 0.0
            ticks: false
        }
        Row {
            id: typeRow
            anchors.centerIn: parent
            spacing: 10
            MoneroComponents.NodeTypeIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                kind: typeButton.kind
                accent: typeButton.accent
                lit: typeButton.selected || typeButton.hovered
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: typeButton.label
                color: typeButton.selected || typeButton.hovered ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                font.family: MoneroComponents.Style.fontMedium.name
                font.pixelSize: 15
            }
        }
        MoneroComponents.Tooltip {
            id: typeTip
            anchors.fill: parent
            text: typeButton.tip
        }
        MouseArea {
            id: typeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: typeButton.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
            onEntered: typeTip.tooltipPopup.open()
            onExited: typeTip.tooltipPopup.close()
            onClicked: { typeTip.tooltipPopup.close(); typeButton.clicked(); }
        }
    }


    /* main layout */
    ColumnLayout {
        id: root
        anchors.margins: 20
        anchors.topMargin: 0

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right

        spacing: 12

        //! Manage pricing
        readonly property bool fiatRatesConsentNeeded: persistentSettings.fiatPriceCurrency !== "xmrusd" && !persistentSettings.fiatRatesConsentGiven

        // node choice and settings: only in advanced mode (the simple modes pick the node themselves)
        ColumnLayout {
            Layout.fillWidth: true
            visible: appWindow.walletMode >= 2
            spacing: 12

            MoneroComponents.SectionTitle {
                Layout.fillWidth: true
                text: qsTr("Node") + translationManager.emptyString
            }

            // one card: start/stop on the left, local / remote choice on the right (details in tooltips)
            MoneroComponents.SettingsCard {
                padding: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // red while it can stop the daemon, yellow and locked while starting or stopping
                        MoneroComponents.StandardButton {
                            readonly property int busy: appWindow.daemonStartStopInProgress
                            readonly property color busyColor: MoneroComponents.Style.blackTheme ? "#FFD60A" : "#B8860B"
                            visible: !persistentSettings.useRemoteNode
                            Layout.alignment: Qt.AlignVCenter
                            small: true
                            enabled: busy === 0
                            disabledOpacity: 1
                            accent: busy !== 0 ? busyColor : appWindow.daemonRunning ? (MoneroComponents.Style.blackTheme ? "#FF4D4D" : "#C62828") : MoneroComponents.Style.orange
                            textColor: busy !== 0 ? busyColor : appWindow.daemonRunning ? (MoneroComponents.Style.blackTheme ? "#FFD6D6" : "#C62828") : MoneroComponents.Style.textAccent
                            text: (busy === 1 ? qsTr("Starting…") : busy === 2 ? qsTr("Stopping…") : appWindow.daemonRunning ? qsTr("Stop daemon") : qsTr("Start daemon")) + translationManager.emptyString
                            onClicked: {
                                if (busy !== 0)
                                    return;
                                if (appWindow.daemonRunning) {
                                    appWindow.stopDaemon(function() {});
                                } else {
                                    persistentSettings.daemonFlags = daemonFlags.text;
                                    appWindow.startDaemon(persistentSettings.daemonFlags);
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        NodeTypeButton {
                            id: localNodeChoice
                            visible: !isAndroid
                            kind: "local"
                            label: qsTr("Local node") + translationManager.emptyString
                            tip: qsTr("The blockchain is downloaded to your computer. Provides higher security and requires more local storage.") + translationManager.emptyString
                            selected: !persistentSettings.useRemoteNode
                            onClicked: {
                                if (persistentSettings.useRemoteNode) {
                                    persistentSettings.useRemoteNode = false;
                                    appWindow.disconnectRemoteNode();
                                }
                            }
                        }

                        NodeTypeButton {
                            id: remoteNodeChoice
                            kind: "remote"
                            label: qsTr("Remote node") + translationManager.emptyString
                            tip: qsTr("Uses a third-party server to connect to the Monero network. Less secure, but easier on your computer.") + translationManager.emptyString
                            selected: persistentSettings.useRemoteNode
                            onClicked: {
                                if (!persistentSettings.useRemoteNode) {
                                    appWindow.connectRemoteNode();
                                }
                            }
                        }
                    }

                    // external IPs of the local node (same list as Security > Connections)
                    MoneroComponents.NodePeers {
                        visible: !persistentSettings.useRemoteNode && appWindow.daemonRunning
                        Layout.fillWidth: true
                        showTitle: true
                    }

                    Rectangle {
                        visible: !persistentSettings.useRemoteNode
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
                        opacity: 0.15
                    }

                    MoneroComponents.ConnectionCheck {
                        visible: !persistentSettings.useRemoteNode
                        Layout.fillWidth: true
                    }
                }
            }

            // ---- remote node ----
            MoneroComponents.WarningBox {
                text: qsTr("To find a remote node, type 'Monero remote node' into your favorite search engine. Please ensure the node is run by a trusted third-party.") + translationManager.emptyString
                visible: persistentSettings.useRemoteNode
            }

            MoneroComponents.SettingsRemoteNodeList {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: persistentSettings.useRemoteNode
            }

            // blockchain location, startup flags, bootstrap node: folded so they don't take the whole page
            MoneroComponents.CollapsibleCard {
                visible: !persistentSettings.useRemoteNode
                title: qsTr("Local node options") + translationManager.emptyString
                summary: persistentSettings.blockchainDataDir !== "" ? persistentSettings.blockchainDataDir : qsTr("(default)") + translationManager.emptyString

                RowLayout {
                    Layout.fillWidth: true

                    MoneroComponents.LineEditMulti {
                        id: blockchainFolder
                        Layout.preferredWidth: 200
                        Layout.fillWidth: true
                        fontSize: 15
                        labelFontSize: 14
                        property string style: "<style type='text/css'>a {cursor:pointer;text-decoration: underline; color: %1}</style>".arg(MoneroComponents.Style.defaultFontColor)
                        labelText: qsTr("Blockchain location") + style + " <a href='#'> (%1)</a>".arg(qsTr("Change")) + translationManager.emptyString
                        labelButtonText: qsTr("Reset") + translationManager.emptyString
                        labelButtonVisible: text
                        placeholderText: qsTr("(default)") + translationManager.emptyString
                        placeholderFontSize: 15
                        readOnly: true
                        text: persistentSettings.blockchainDataDir
                        addressValidation: false
                        onInputLabelLinkActivated: {
                            //mouse.accepted = false
                            if(persistentSettings.blockchainDataDir !== ""){
                                blockchainFileDialog.currentFolder = "file://" + persistentSettings.blockchainDataDir;
                            }
                            blockchainFileDialog.open();
                            blockchainFolder.focus = true;
                        }
                        onLabelButtonClicked: persistentSettings.blockchainDataDir = ""
                    }
                }

                MoneroComponents.LineEditMulti {
                    id: daemonFlags
                    Layout.fillWidth: true
                    labelFontSize: 14
                    fontSize: 15
                    wrapMode: Text.WrapAnywhere
                    labelText: qsTr("Daemon startup flags") + translationManager.emptyString
                    placeholderText: qsTr("(optional)") + translationManager.emptyString
                    placeholderFontSize: 15
                    text: persistentSettings.daemonFlags
                    addressValidation: false
                    error: text.match(/(^|\s)--(data-dir|bootstrap-daemon-address|non-interactive)/)
                    onEditingFinished: {
                        if (!daemonFlags.error) {
                            persistentSettings.daemonFlags = daemonFlags.text;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !persistentSettings.useRemoteNode

                    ColumnLayout {
                        Layout.fillWidth: true

                        MoneroComponents.RemoteNodeEdit {
                            id: bootstrapNodeEdit
                            Layout.minimumWidth: 100

                            daemonAddrLabelText: qsTr("Bootstrap Address") + translationManager.emptyString
                            daemonPortLabelText: qsTr("Bootstrap Port") + translationManager.emptyString
                            initialAddress: persistentSettings.bootstrapNodeAddress
                            onEditingFinished: {
                                if (daemonAddrText == "auto") {
                                    persistentSettings.bootstrapNodeAddress = daemonAddrText;
                                } else {
                                    persistentSettings.bootstrapNodeAddress = daemonAddrText ? bootstrapNodeEdit.getAddress() : "";
                                }
                                console.log("setting bootstrap node to " + persistentSettings.bootstrapNodeAddress)
                            }
                        }
                    }
                }
            }
        }

        // same NYM VPN panel as the welcome page
        MoneroComponents.NymVpnPanel {
            Layout.fillWidth: true
            Layout.topMargin: 4
        }

        // ---- price conversion (moved here from Interface), folded ----
        // the same checkbox turns on the fiat balance and the swap prices of the Swaps page
        MoneroComponents.CollapsibleCard {
            id: priceCard
            z: 2   // the open dropdowns must draw over the Network card below
            Layout.topMargin: 14
            title: qsTr("External connections") + translationManager.emptyString
            summary: persistentSettings.fiatPriceEnabled
                     ? Utils.capitalize(persistentSettings.fiatPriceProvider) + " · " + persistentSettings.fiatPriceCurrency.replace(/^xmr/, "").toUpperCase() + " · " + qsTr("Swaps") + translationManager.emptyString
                     : qsTr("Off") + translationManager.emptyString

            MoneroComponents.CheckBox {
                id: enableConvertCurrency
                text: qsTr("Show the balance in other currencies and the swap prices") + translationManager.emptyString
                checked: persistentSettings.fiatPriceEnabled
                enabled: !persistentSettings.extremePrivacy
                tooltip: persistentSettings.extremePrivacy ? qsTr("Off while extreme privacy is on (Wallet+ > Security)") + translationManager.emptyString : ""
                onCheckedChanged: {
                    if (!checked) {
                        console.log("Disabled price conversion");
                        persistentSettings.fiatPriceEnabled = false;
                    }
                }
                Connections {
                    target: persistentSettings
                    function onExtremePrivacyChanged() {
                        if (persistentSettings.extremePrivacy)
                            enableConvertCurrency.checked = false;
                    }
                }
            }

            GridLayout {
                visible: enableConvertCurrency.checked
                columns: 2
                Layout.fillWidth: true
                Layout.leftMargin: 35
                columnSpacing: 32

                MoneroComponents.StandardDropdown {
                    id: fiatPriceProviderDropDown
                    Layout.maximumWidth: 200
                    labelText: qsTr("Price source") + translationManager.emptyString
                    labelFontSize: 14
                    dataModel: fiatPriceProvidersModel
                    onChanged: {
                        var obj = dataModel.get(currentIndex);
                        persistentSettings.fiatPriceProvider = obj.data;

                        if(persistentSettings.fiatPriceEnabled)
                            appWindow.fiatApiRefresh();
                    }
                }

                MoneroComponents.StandardDropdown {
                    id: fiatPriceCurrencyDropdown
                    Layout.maximumWidth: 100
                    labelText: qsTr("Currency") + translationManager.emptyString
                    labelFontSize: 14
                    maxDropdownItems: 8
                    dataModel: fiatPriceCurrencyModel
                    onChanged: {
                        var obj = dataModel.get(currentIndex);
                        persistentSettings.fiatPriceCurrency = obj.data;

                        if(persistentSettings.fiatPriceEnabled) {
                            appWindow.fiatApiUpdatePrice();
                            appWindow.fiatApiRefresh();
                        }
                    }
                }

                z: parent.z + 1
            }

            ColumnLayout {
                // Feature needs to be double enabled for security purposes (miss-clicks)
                visible: enableConvertCurrency.checked && (!persistentSettings.fiatPriceEnabled || root.fiatRatesConsentNeeded)
                spacing: 0
                Layout.fillWidth: true
                Layout.leftMargin: 35

                MoneroComponents.WarningBox {
                    text: !persistentSettings.fiatPriceEnabled
                        ? qsTr("Enabling price conversion exposes your IP address to the selected price source, to the swap exchanges listed below, and for currencies other than USD, to the exchange rate provider (frankfurter.dev).") + translationManager.emptyString
                        : qsTr("Using a non-USD currency exposes your IP address to the exchange rate provider (frankfurter.dev).") + translationManager.emptyString;
                }

                MoneroComponents.StandardButton {
                    Layout.topMargin: 10
                    small: true
                    text: !persistentSettings.fiatPriceEnabled
                        ? qsTr("Confirm and enable") + translationManager.emptyString
                        : qsTr("Confirm") + translationManager.emptyString

                    onClicked: {
                        console.log(persistentSettings.fiatPriceEnabled ? "Confirmed exchange rate provider consent" : "Enabled price conversion");
                        persistentSettings.fiatPriceEnabled = true;
                        persistentSettings.fiatRatesConsentGiven = true;
                        appWindow.fiatApiRefresh();
                    }
                }
            }

            // exchanges the Swaps page asks for prices
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                MoneroComponents.TextPlain {
                    text: qsTr("Swaps and exchanges used") + translationManager.emptyString
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                    font.capitalization: Font.AllUppercase
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                Repeater {
                    model: [
                        { name: "Wagyu", host: "wagyu.xyz", what: qsTr("swap quotes, fees included") + translationManager.emptyString, on: true },
                        { name: "NonKYC", host: "nonkyc.io", what: qsTr("exchange order book (bid / ask)") + translationManager.emptyString, on: true },
                        { name: "ChangeNOW", host: "changenow.io", what: qsTr("swap quotes, fees included") + translationManager.emptyString, on: true }
                    ]
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            width: 7; height: 7; radius: 3.5
                            color: modelData.on && persistentSettings.fiatPriceEnabled
                                   ? (MoneroComponents.Style.blackTheme ? "#5FD08F" : "#1E8E4E")
                                   : MoneroComponents.Style.dimmedFontColor
                        }
                        MoneroComponents.TextPlain {
                            Layout.preferredWidth: 110
                            text: modelData.name
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 14
                            color: modelData.on ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            Layout.preferredWidth: 130
                            text: modelData.host
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            font.pixelSize: 12
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.what
                            font.pixelSize: 12
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                    }
                }
            }
        }

        // ---- network (moved here from Interface), folded ----
        // while NymVPN is on or "Nym required" is checked the proxy belongs to Nym: shown, not editable
        MoneroComponents.CollapsibleCard {
            id: networkCard
            readonly property bool nymLocked: persistentSettings.nymVpnEnabled || persistentSettings.nymVpnRequired
            Layout.topMargin: 14
            Layout.bottomMargin: 20
            title: qsTr("Network") + translationManager.emptyString
            summary: (nymLocked ? qsTr("NymVPN") + " · " + persistentSettings.nymVpnSocksAddress
                      : proxyCheckbox.checked ? "Socks5 · " + (socksProxyFlagSet ? socksProxyFlag : persistentSettings.proxyAddress)
                      : qsTr("No proxy")) + translationManager.emptyString

            MoneroComponents.TextPlain {
                visible: networkCard.nymLocked
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Locked while NymVPN is connected or \"Nym required\" is checked: the app uses the Nym proxy.") + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.CheckBox {
                id: proxyCheckbox
                enabled: !socksProxyFlagSet && !networkCard.nymLocked
                checked: networkCard.nymLocked ? true : (socksProxyFlagSet ? socksProxyFlag : persistentSettings.proxyEnabled)
                onClicked: {
                    persistentSettings.proxyEnabled = !persistentSettings.proxyEnabled;
                }
                text: qsTr("Socks5 proxy (%1%2)")
                    .arg(appWindow.walletMode >= 2 ? qsTr("remote node connections, ") : "")
                    .arg(qsTr("updates downloading, fetching price sources")) + translationManager.emptyString
            }

            Item {
                Layout.fillWidth: true
                Layout.leftMargin: 35
                Layout.minimumWidth: 100
                implicitHeight: proxyEdit.implicitHeight
                visible: proxyCheckbox.checked

                MoneroComponents.RemoteNodeEdit {
                    id: proxyEdit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    enabled: !socksProxyFlagSet
                    opacity: networkCard.nymLocked ? 0.6 : 1
                    placeholderFontSize: 15

                    daemonAddrLabelText: qsTr("IP address") + translationManager.emptyString
                    daemonPortLabelText: qsTr("Port") + translationManager.emptyString

                    initialAddress: networkCard.nymLocked ? persistentSettings.nymVpnSocksAddress
                                    : socksProxyFlagSet ? socksProxyFlag : persistentSettings.proxyAddress
                    onEditingFinished: {
                        if (!networkCard.nymLocked)
                            persistentSettings.proxyAddress = proxyEdit.getAddress();
                    }
                }

                // locked by Nym: the address stays readable but takes no clicks or typing
                MouseArea {
                    anchors.fill: parent
                    visible: networkCard.nymLocked
                    acceptedButtons: Qt.AllButtons
                    cursorShape: Qt.ForbiddenCursor
                }
            }
        }
    }

    ListModel {
        id: fiatPriceProvidersModel
    }

    ListModel {
        id: fiatPriceCurrencyModel
    }

    // keep the dropdown in sync when the currency is changed elsewhere (Account page)
    Connections {
        target: persistentSettings
        function onFiatPriceCurrencyChanged() {
            for (var j = 0; j < fiatPriceCurrencyModel.count; ++j) {
                if (fiatPriceCurrencyModel.get(j).data === persistentSettings.fiatPriceCurrency)
                    fiatPriceCurrencyDropdown.currentIndex = j;
            }
        }
    }

    Component.onCompleted: {
        // Dynamically fill fiatPrice dropdown based on `appWindow.fiatPriceAPIs`
        var apis = appWindow.fiatPriceAPIs;
        fiatPriceProvidersModel.clear();

        var i = 0;
        for (var api in apis){
            if (!apis.hasOwnProperty(api))
               continue;

            fiatPriceProvidersModel.append({"column1": Utils.capitalize(api), "data": api});

            if(api === persistentSettings.fiatPriceProvider)
                fiatPriceProviderDropDown.currentIndex = i;
            i += 1;
        }

        var currencies = appWindow.fiatCurrencies;
        fiatPriceCurrencyModel.clear();

        for (var j = 0; j < currencies.length; ++j) {
            const key = "xmr" + currencies[j].toLowerCase();
            fiatPriceCurrencyModel.append({"column1": currencies[j], "data": key});

            if(key === persistentSettings.fiatPriceCurrency)
                fiatPriceCurrencyDropdown.currentIndex = j;
        }

    }
}
