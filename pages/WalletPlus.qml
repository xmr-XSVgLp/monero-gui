// Wallet+ page: overview of the extra tools of XMR Wallet+ (Trading data, Swaps, Notes, NYM VPN,
// Trezor Safe 7, privacy) with shortcuts to each page and links to the services behind them.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents

Rectangle {
    id: pageWalletPlus
    color: "transparent"

    property alias walletPlusHeight: mainLayout.height
    readonly property color neutral: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
    readonly property color blue: MoneroComponents.Style.blackTheme ? "#6CB8FF" : "#1565C0"
    readonly property color good: MoneroComponents.Style.blackTheme ? "#3DDC84" : "#1E7D45"
    readonly property color warn: MoneroComponents.Style.blackTheme ? "#E0A84A" : "#9A5B00"
    readonly property bool pricesOn: persistentSettings.fiatPriceEnabled
    readonly property bool hardware: currentWallet ? currentWallet.isHwBacked() : false

    function openPage(page) {
        appWindow.showPageRequest(page);
        middlePanel.flickable.contentY = 0;
    }

    function openNodeSettings() {
        middlePanel.settingsView.settingsStateViewState = "Node";
        openPage("Settings");
    }

    function nymText() {
        var s = appWindow.nymVpnState;
        if (s === "connected" || s === "ready")
            return qsTr("Connected: this app goes through the Nym mixnet") + translationManager.emptyString;
        if (s === "working")
            return qsTr("Connecting…") + translationManager.emptyString;
        if (s === "missing")
            return qsTr("NymVPN is not installed") + translationManager.emptyString;
        return qsTr("Off") + translationManager.emptyString;
    }

    function onPageCompleted() {
    }

    // one card per extra feature
    component Card: Item {
        id: card
        default property alias content: extra.data
        property string title: ""
        property string body: ""
        property string status: ""
        property color statusColor: MoneroComponents.Style.dimmedFontColor
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 300
        implicitHeight: cardBody.implicitHeight + 36

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 12
            accent: pageWalletPlus.neutral
            lineOpacity: 0.35
            fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#DADFDB"
            fillOpacity: 0.92
            glow: 0.0
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            width: 2
            color: pageWalletPlus.blue
            opacity: 0.8
        }

        ColumnLayout {
            id: cardBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 10

            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                text: card.title
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 1
                color: pageWalletPlus.blue
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                text: card.body
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                lineHeight: 1.15
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                visible: card.status !== ""
                text: card.status
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: card.statusColor
                themeTransition: false
            }
            Flow {
                id: extra
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8
            }
        }
    }

    // link that opens in the system browser
    component Link: MoneroComponents.TextPlain {
        property string url: ""
        text: "↗ " + url.replace(/^https:\/\//, "").replace(/\/$/, "")
        font.pixelSize: 12
        font.family: MoneroComponents.Style.fontMonoRegular.name
        font.underline: linkArea.containsMouse
        color: pageWalletPlus.blue
        themeTransition: false
        height: 28
        verticalAlignment: Text.AlignVCenter
        MouseArea {
            id: linkArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(parent.url)
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            MoneroComponents.LabelSubheader {
                Layout.fillWidth: true
                fontSize: 24
                text: "Wallet+"
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
                text: qsTr("Extra tools that XMR Wallet+ adds to the Monero wallet. All of them are optional: open them from the menu under Wallet+ or from here. Links open in your browser, which does not go through Nym.") + translationManager.emptyString
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: pageWalletPlus.width > 900 ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            Card {
                title: qsTr("Trading data") + translationManager.emptyString
                body: qsTr("XMR price in EUR, USD and BTC from 24 hours to all the history recorded, the value of this wallet over time, a converter and price alerts with a notification. Prices are saved in CSV files on this computer.") + translationManager.emptyString
                status: pageWalletPlus.pricesOn ? "" : (qsTr("Needs price conversion, which is off: nothing connects to the price services.") + translationManager.emptyString)
                statusColor: pageWalletPlus.warn
                MoneroComponents.StandardButton {
                    small: true
                    visible: pageWalletPlus.pricesOn
                    text: qsTr("Open") + translationManager.emptyString
                    onClicked: pageWalletPlus.openPage("Trading")
                }
                MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    visible: !pageWalletPlus.pricesOn
                    text: qsTr("Settings") + translationManager.emptyString
                    onClicked: pageWalletPlus.openNodeSettings()
                }
                Link { url: "https://www.coingecko.com/es/monedas/monero" }
            }

            Card {
                title: qsTr("Swaps") + translationManager.emptyString
                body: qsTr("Compares how much you get when changing XMR for BTC, ETH, SOL, USDT and other coins on Wagyu, NonKYC and ChangeNOW, shows the best route between exchanges and compares with earlier prices. It only shows quotes: the swap itself is done on each exchange.") + translationManager.emptyString
                status: pageWalletPlus.pricesOn ? "" : (qsTr("Needs price conversion, which is off: nothing connects to the price services.") + translationManager.emptyString)
                statusColor: pageWalletPlus.warn
                MoneroComponents.StandardButton {
                    small: true
                    visible: pageWalletPlus.pricesOn
                    text: qsTr("Open") + translationManager.emptyString
                    onClicked: pageWalletPlus.openPage("Swaps")
                }
                Link { url: "https://wagyu.xyz" }
                Link { url: "https://nonkyc.io" }
                Link { url: "https://changenow.io" }
            }

            Card {
                title: qsTr("Notes") + translationManager.emptyString
                body: (pageWalletPlus.hardware
                       ? qsTr("Private notes saved next to the wallet and encrypted with AES-256-GCM. They open with the wallet password and a confirmation on the Trezor, so the file is useless without that Trezor.")
                       : qsTr("Private notes saved next to the wallet and encrypted with AES-256-GCM. They open with the wallet password and the key comes from the wallet keys.")) + translationManager.emptyString
                MoneroComponents.StandardButton {
                    small: true
                    text: qsTr("Open") + translationManager.emptyString
                    onClicked: pageWalletPlus.openPage("Notes")
                }
            }

            Card {
                title: "NYM VPN"
                body: qsTr("Sends only this app through the Nym mixnet, including the local node, so nodes and price services do not see your IP. With \"Nym required\" nothing connects while Nym is down. You need the NymVPN app and an account.") + translationManager.emptyString
                status: pageWalletPlus.nymText()
                statusColor: (appWindow.nymVpnState === "connected" || appWindow.nymVpnState === "ready") ? pageWalletPlus.good : MoneroComponents.Style.dimmedFontColor
                MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    text: qsTr("Node / Network") + translationManager.emptyString
                    onClicked: pageWalletPlus.openNodeSettings()
                }
                Link { url: "https://nymvpn.com" }
            }

            Card {
                title: "Trezor Safe 7"
                body: qsTr("Support for the Trezor Safe 7 over USB and Bluetooth, with the new encrypted Trezor Host Protocol and pairing with the code shown on the device. The Trezor name appears in the title bar. Close Trezor Suite before opening the wallet.") + translationManager.emptyString
                status: pageWalletPlus.hardware ? (qsTr("This wallet uses a hardware wallet") + translationManager.emptyString) : ""
                statusColor: pageWalletPlus.good
                Link { url: "https://trezor.io/trezor-safe-7" }
            }

            Card {
                title: qsTr("Privacy") + translationManager.emptyString
                body: qsTr("The marks in the title bar show at a glance whether Nym is on, whether the node is local or remote and whether a Trezor is in use. Turning price conversion off stops every request to price services and exchanges.") + translationManager.emptyString
                MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    text: qsTr("Node / Network") + translationManager.emptyString
                    onClicked: pageWalletPlus.openNodeSettings()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            MoneroComponents.TextPlain {
                text: qsTr("XMR Wallet+ is an unofficial fork of the Monero GUI.") + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            Link { url: "https://github.com/xmr-XSVgLp/monero-gui" }
            Link { url: "https://getmonero.org" }
            Item { Layout.fillWidth: true }
        }
    }
}
