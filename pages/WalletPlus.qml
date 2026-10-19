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
        // what a click anywhere on the card does (buttons and links inside keep their own action)
        property var action: null
        readonly property bool hot: cardArea.containsMouse && action !== null
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 300
        implicitHeight: cardBody.implicitHeight + 36

        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 12
            accent: card.hot ? pageWalletPlus.blue : pageWalletPlus.neutral
            lineOpacity: card.hot ? 0.9 : 0.35
            fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#DADFDB"
            fillOpacity: 0.92
            glow: card.hot ? 0.35 : 0.0
        }
        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.action !== null ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (card.action !== null) card.action()
        }
        MoneroComponents.TextPlain {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            visible: card.action !== null
            text: "→"
            font.pixelSize: 18
            color: pageWalletPlus.blue
            opacity: card.hot ? 1 : 0.45
            themeTransition: false
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
                Layout.rightMargin: 24
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
                text: qsTr("Extra tools that XMR Wallet+ adds to the Monero wallet. All of them are optional: click a card to open it. Links open in your browser, which does not go through Nym.") + translationManager.emptyString
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: pageWalletPlus.width > 900 ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            Card {
                title: qsTr("Markets") + translationManager.emptyString
                body: qsTr("XMR price in EUR, USD and BTC from 24 hours to all the history recorded, the value of this wallet over time, a converter and price alerts with a notification. Prices are saved in CSV files on this computer.") + translationManager.emptyString
                status: pageWalletPlus.pricesOn ? "" : (qsTr("Needs price conversion, which is off: nothing connects to the price services.") + translationManager.emptyString)
                statusColor: pageWalletPlus.warn
                action: function() { pageWalletPlus.pricesOn ? pageWalletPlus.openPage("Trading") : pageWalletPlus.openNodeSettings() }
                Link { url: "https://www.coingecko.com/es/monedas/monero" }
            }

            Card {
                title: qsTr("Swaps") + translationManager.emptyString
                body: qsTr("Compares how much you get when changing XMR for BTC, ETH, SOL, USDT and other coins on Wagyu, NonKYC and ChangeNOW, shows the best route between exchanges and compares with earlier prices. It only shows quotes: the swap itself is done on each exchange.") + translationManager.emptyString
                status: pageWalletPlus.pricesOn ? (qsTr("In Markets, Swaps tab") + translationManager.emptyString) : (qsTr("Needs price conversion, which is off: nothing connects to the price services.") + translationManager.emptyString)
                statusColor: pageWalletPlus.pricesOn ? MoneroComponents.Style.dimmedFontColor : pageWalletPlus.warn
                action: function() { pageWalletPlus.pricesOn ? pageWalletPlus.openPage("Swaps") : pageWalletPlus.openNodeSettings() }
                Link { url: "https://wagyu.xyz" }
                Link { url: "https://nonkyc.io" }
                Link { url: "https://changenow.io" }
            }

            Card {
                title: qsTr("Security") + translationManager.emptyString
                body: qsTr("Where every connection of the app goes, a manager that scores and rotates nodes, extreme privacy mode (nothing leaves without Nym or a proxy) and a security center: file permissions, password strength and wallet backups.") + translationManager.emptyString
                status: persistentSettings.extremePrivacy ? (qsTr("Extreme privacy is on") + translationManager.emptyString) : ""
                statusColor: pageWalletPlus.good
                action: function() { pageWalletPlus.openPage("Security") }
            }

            Card {
                title: qsTr("Notes") + translationManager.emptyString
                body: (pageWalletPlus.hardware
                       ? qsTr("Private notes saved next to the wallet and encrypted with AES-256-GCM. They open with the wallet password and a confirmation on the Trezor, so the file is useless without that Trezor.")
                       : qsTr("Private notes saved next to the wallet and encrypted with AES-256-GCM. They open with the wallet password and the key comes from the wallet keys.")) + translationManager.emptyString
                action: function() { pageWalletPlus.openPage("Notes") }
            }

            Card {
                title: "NYM VPN"
                body: qsTr("Sends this app through the Nym mixnet with its own Nym client, including the local node, so nodes and price services do not see your IP. It only needs the 24 words of a NymVPN account. With \"Nym required\" nothing connects while Nym is down.") + translationManager.emptyString
                status: pageWalletPlus.nymText()
                statusColor: (appWindow.nymVpnState === "connected" || appWindow.nymVpnState === "ready") ? pageWalletPlus.good : MoneroComponents.Style.dimmedFontColor
                action: function() { pageWalletPlus.openNodeSettings() }
                Link { url: "https://nymvpn.com" }
            }

            Card {
                title: "Trezor"
                body: qsTr("Trezor Safe 7 over USB and Bluetooth with the encrypted Trezor Host Protocol, and the Safe 5. Customize the device from here: name, wallpaper with your own gallery, brightness, haptic feedback and auto-lock.") + translationManager.emptyString
                status: pageWalletPlus.hardware ? (qsTr("This wallet uses a hardware wallet") + translationManager.emptyString) : ""
                statusColor: pageWalletPlus.good
                action: function() { pageWalletPlus.openPage("Trezor") }
                Link { url: "https://trezor.io/trezor-safe-7" }
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
