// Feature guide: grouped, collapsible explanations and explicit shortcuts.
import QtQuick
import FontAwesome
import QtQuick.Layouts
import "../components" as UI

Rectangle {
    id: pageWalletPlus
    color: "transparent"
    property alias walletPlusHeight: mainLayout.height
    readonly property bool pricesOn: persistentSettings.fiatPriceEnabled
    function onPageCompleted() {}
    function openPage(page) {
        var showBackups = page === "Backups";
        if (page === "Backups") {
            middlePanel.securityView.tab = "Center";
            page = "Security";
        }
        if (page === "Node" || page === "Interface") {
            middlePanel.settingsView.settingsStateViewState = page === "Interface" ? "UI" : page;
            page = "Settings";
        }
        appWindow.showPageRequest(page);
        middlePanel.flickable.contentY = 0;
        if (showBackups)
            middlePanel.securityView.scrollToBackups();
    }
    function setExpanded(value) {
        for (var i = 0; i < sections.children.length; ++i)
            if (sections.children[i].checked !== undefined)
                sections.children[i].checked = value;
    }
    component GuideSection: UI.CollapsibleCard {
        activeFocusOnTab: true
        Accessible.role: Accessible.CheckBox
        Accessible.name: title
        Accessible.checkable: true
        Accessible.checked: checked
        Keys.onSpacePressed: checked = !checked
        Keys.onReturnPressed: checked = !checked
        Keys.onEnterPressed: checked = !checked
        Accessible.onToggleAction: checked = !checked
    }
    component Feature: ColumnLayout {
        property string heading
        property string description
        property string useCase
        Layout.fillWidth: true
        spacing: 7
        UI.TextPlain {
            Layout.fillWidth: true
            text: heading
            font.pixelSize: 15
            font.bold: true
            color: UI.Style.defaultFontColor
            themeTransition: false
            wrapMode: Text.WordWrap
        }
        UI.TextPlain {
            Layout.fillWidth: true
            text: description
            font.pixelSize: 13
            lineHeight: 1.2
            color: UI.Style.dimmedFontColor
            themeTransition: false
            wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: useText.implicitHeight + 22
            color: UI.Style.blackTheme ? "#15251D" : "#CBD9CF"
            radius: 4
            UI.TextPlain {
                id: useText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 11
                text: useCase
                font.pixelSize: 13
                lineHeight: 1.15
                color: UI.Style.defaultFontColor
                themeTransition: false
                wrapMode: Text.WordWrap
            }
        }
    }
    component GuideAction: UI.StandardButton {
        property string destination: ""
        property string actionText: ""
        readonly property bool needsPrices: destination === "Trading" || destination === "Swaps" || destination === "SwapsNoKyc"
        // Only the first market action offers setup while price connections are disabled.
        property bool offersPriceSetup: false
        visible: !needsPrices || pageWalletPlus.pricesOn || offersPriceSetup
        Layout.topMargin: 3
        Layout.bottomMargin: 12
        Layout.maximumWidth: parent.width
        small: true
        primary: false
        text: needsPrices && !pageWalletPlus.pricesOn ? qsTr("Enable price connections") + translationManager.emptyString : actionText
        onClicked: pageWalletPlus.openPage(needsPrices && !pageWalletPlus.pricesOn ? "Node" : destination)
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 18
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Image {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                source: "qrc:///images/logos/walletplus-logo.png"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                UI.LabelSubheader { Layout.fillWidth: true; fontSize: 26; text: "Wallet+" }
                UI.TextPlain {
                    Layout.fillWidth: true
                    text: qsTr("Discover the tools, expand a section and find a useful way to use each feature.") + translationManager.emptyString
                    color: UI.Style.dimmedFontColor
                    themeTransition: false
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            UI.StandardButton { small: true; primary: false; text: qsTr("Expand all") + translationManager.emptyString; onClicked: pageWalletPlus.setExpanded(true) }
            UI.StandardButton { small: true; primary: false; text: qsTr("Collapse all") + translationManager.emptyString; onClicked: pageWalletPlus.setExpanded(false) }
        }
        ColumnLayout {
            id: sections
            Layout.fillWidth: true
            spacing: 12
            GuideSection {
                objectName: "walletPlusSection0"
                icon: FontAwesome.networkWired
                title: qsTr("Network and privacy") + translationManager.emptyString
                summary: "4 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Private routes") + translationManager.emptyString
                    description: qsTr("Choose a route for the wallet, local-node synchronization and transaction broadcasts in Node / Network settings.") + translationManager.emptyString
                    useCase: qsTr("Separate how you synchronize from how you broadcast a payment. Network clients still need entry and bootstrap connections.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Nym mixnet") + translationManager.emptyString
                    description: qsTr("Independent client for this app, using the 24 words of an active NymVPN account. Reconnect renews the route; the exit is random.") + translationManager.emptyString
                    useCase: qsTr("Use Nym required to block connections when Nym is unavailable. The Nym account phrase is saved locally in nym.conf.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Tor and I2P") + translationManager.emptyString
                    description: qsTr("Built-in clients, discovery of .onion and .i2p nodes, and node lists you can reuse as remote nodes or local-node peers.") + translationManager.emptyString
                    useCase: qsTr("Find a private remote node. I2P has no Internet outproxy and cannot synchronize the local node on its own.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Connection checks") + translationManager.emptyString
                    description: qsTr("Test the selected network: exit IP, proxy, latency, download speed and Monero-node reachability.") + translationManager.emptyString
                    useCase: qsTr("Diagnose slow synchronization before changing nodes or reconnecting. Tests run when you request them.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Node"
                    actionText: qsTr("Configure network") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusSection1"
                icon: FontAwesome.shieldAlt
                title: qsTr("Security") + translationManager.emptyString
                summary: "2 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Connections and node manager") + translationManager.emptyString
                    description: qsTr("Review contacted services and routes. Compare nodes by availability, synchronization, stability and latency; save favourites or rotate nodes.") + translationManager.emptyString
                    useCase: qsTr("Check whether a lagging node is the cause of a stale balance. The spy-node ban list adds another filter.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Extreme privacy and security center") + translationManager.emptyString
                    description: qsTr("Disable optional external services and review file permissions, backups, password strength, connection and session protection.") + translationManager.emptyString
                    useCase: qsTr("Review the setup before using a wallet on a new computer. The checks do not prove that the computer is secure.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Security"
                    actionText: qsTr("Open security") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusSection2"
                icon: FontAwesome.exchangeAlt
                title: qsTr("Send and receive") + translationManager.emptyString
                summary: "2 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Multiple recipients") + translationManager.emptyString
                    description: qsTr("Paste up to 50 comma-separated addresses, optionally as address:amount, to fill several recipients.") + translationManager.emptyString
                    useCase: qsTr("Prepare a batch of payments and review each address, amount and fee before confirming.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Fresh receiving addresses") + translationManager.emptyString
                    description: qsTr("Create 2 to 50 addresses together, hide used addresses and split a payment request across a group.") + translationManager.emptyString
                    useCase: qsTr("Use a different address for each customer or collection. Used addresses are marked to discourage reuse.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Transfer"
                    actionText: qsTr("Prepare payments") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Receive"
                    actionText: qsTr("Open receive") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusScheduledSection"
                icon: FontAwesome.clockO
                title: qsTr("Scheduled payments") + translationManager.emptyString
                Feature {
                    heading: qsTr("Prepare a payment for a specific time") + translationManager.emptyString
                    description: qsTr("In Send, enter the recipient and amount, then choose a date and time instead of Now. The wallet saves the schedule and attempts to create and broadcast the transaction when it is due.") + translationManager.emptyString
                    useCase: qsTr("Prepare a donation, an agreed payment or a transfer between your wallets in advance. Scheduling does not guarantee the exact time of confirmation on the blockchain.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Keep the wallet open and synchronized") + translationManager.emptyString
                    description: qsTr("For automatic sending, keep the app running and this wallet selected, open and synchronized, with a working network connection and enough unlocked funds for the amount and fee.") + translationManager.emptyString
                    useCase: qsTr("Keep the computer awake until the payment has been sent. A screen lock can leave the wallet open, but a lock that removes spending access cannot execute the payment.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("If you close the application") + translationManager.emptyString
                    description: qsTr("Closing the app preserves schedules in the encrypted wallet cache, but they cannot run while the app is closed. On reopening, overdue payments require your confirmation before sending, even if only seconds late.") + translationManager.emptyString
                    useCase: qsTr("If the computer was off or the wallet was closed, review pending payments when you return. The app warns before closing when scheduled payments remain.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Funds and supported wallets") + translationManager.emptyString
                    description: qsTr("Scheduling is disabled for hardware wallets, including Trezor and Ledger. During the 25 minutes before a scheduled payment, other sends from its source account are blocked.") + translationManager.emptyString
                    useCase: qsTr("Have unlocked funds ready beforehand. This buffer reduces conflicts with other sends but does not guarantee that funds will be spendable when the payment is due.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Review and manage pending payments") + translationManager.emptyString
                    description: qsTr("Scheduled payments appear below the send form. Review the recipient, amount and time, or use Send now or Cancel for a pending payment.") + translationManager.emptyString
                    useCase: qsTr("If a broadcast was interrupted and its outcome is uncertain, check the transaction history before creating another payment to avoid sending twice.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Transfer"
                    actionText: qsTr("Schedule a payment") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusSection3"
                icon: FontAwesome.wallet
                title: qsTr("Wallets and accounts") + translationManager.emptyString
                summary: "2 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Several wallets at once") + translationManager.emptyString
                    description: qsTr("Switch between loaded wallets with the title-bar switcher. Background wallets continue synchronizing while their session allows it.") + translationManager.emptyString
                    useCase: qsTr("Keep personal and work wallets ready without reloading them each time. Manage session behaviour in Interface settings.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Seed accounts") + translationManager.emptyString
                    description: qsTr("The safe icon beside the wallet name creates and switches between wallets derived using numbered seed-offset passphrases.") + translationManager.emptyString
                    useCase: qsTr("Separate funds under one seed. To restore account N, keep both the seed and its numbered passphrase; these accounts are not hidden from someone with the seed.") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusAddressMiningSection"
                icon: FontAwesome.magnifyingGlass
                title: qsTr("Custom address mining") + translationManager.emptyString
                Feature {
                    heading: qsTr("A recognizable public address") + translationManager.emptyString
                    description: qsTr("Find a wallet address containing a short text or character pattern. This can make an address published on a website, profile or donation page easier to identify.") + translationManager.emptyString
                    useCase: qsTr("Use a recognizable fragment as a visual reference for your project or public collection. Always verify the full address: the fragment alone does not identify its owner.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("How the search works") + translationManager.emptyString
                    description: qsTr("The wallet derives and checks its own subaddresses until it finds your pattern. This does not mine blocks or earn XMR, and your current address is not edited.") + translationManager.emptyString
                    useCase: qsTr("Enter a short pattern, choose the start, end or any position, and optionally ignore letter case. Longer patterns take more work and may not produce a match in the chosen range.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Search, choose and save") + translationManager.emptyString
                    description: qsTr("Select an account/address range or enable continuous search. Follow the progress and estimated time, stop when needed and use Save to mined on a result you want to keep.") + translationManager.emptyString
                    useCase: qsTr("Searching alone does not add addresses. Saved results appear in the Mined addresses account, where you can manage them and use them for receiving payments.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Keep the recovery information") + translationManager.emptyString
                    description: qsTr("For results beyond the default scan range, keep the account and address indices and a backup of the wallet files. A normal seed restore may not discover distant indices automatically.") + translationManager.emptyString
                    useCase: qsTr("Before publishing a chosen address, save it and retain its recovery details. A public, recognizable address is convenient, but is not a reason to reuse it for every private collection.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "CustomAddresses"
                    actionText: qsTr("Mine a custom address") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusUsbSection"
                icon: FontAwesome.hdd
                title: qsTr("Removable USB wallet") + translationManager.emptyString
                summary: "USB / SD"
                Feature {
                    heading: qsTr("Keep wallet files offline between uses") + translationManager.emptyString
                    description: qsTr("Keep your wallet on a USB drive that you connect only when needed. While unplugged, its files are not accessible to that PC.") + translationManager.emptyString
                    useCase: qsTr("Reduce the time that files containing encrypted private keys are exposed to the computer, and keep the drive separately to reduce exposure if the PC is stolen.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("1. Copy the wallet to USB") + translationManager.emptyString
                    description: qsTr("Connect the drive and use Save to\u2026 for that drive. The copy includes the wallet files, labels, history and encrypted notes in its XMR folder.") + translationManager.emptyString
                    useCase: qsTr("Copying does not remove the original from the PC. Verify that the USB copy opens and keep an independent seed backup before deciding what to do with any local copies.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("2. Connect, open and use") + translationManager.emptyString
                    description: qsTr("Connect the USB and choose its wallet from USB / SD wallets when opening a wallet, or select the wallet file directly from the drive.") + translationManager.emptyString
                    useCase: qsTr("Open the USB copy, synchronize it and carry out the operations you need. Keep the drive connected throughout the session.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("3. Close the wallet and eject") + translationManager.emptyString
                    description: qsTr("Close that wallet and wait for saving and closing to finish. Then eject the USB through macOS and unplug it.") + translationManager.emptyString
                    useCase: qsTr("Switching to another wallet or hiding the window does not close it: wallets can remain loaded in the background.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("What this protects\u2014and what it does not") + translationManager.emptyString
                    description: qsTr("This reduces exposure while the USB is disconnected. It does not protect an open wallet from malware on the PC and is not a hardware wallet.") + translationManager.emptyString
                    useCase: qsTr("Use a strong wallet password, protect the USB against loss or theft and keep a separate seed backup. A USB drive can fail, and files copied by malware remain exposed after unplugging it.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Backups"
                    actionText: qsTr("Review backups") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusSection4"
                icon: FontAwesome.chartLine
                title: qsTr("Markets and swaps") + translationManager.emptyString
                summary: "3 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Charts, converter and alerts") + translationManager.emptyString
                    description: qsTr("Explore XMR prices and wallet value over time, convert amounts and set price alerts. Historical prices are cached locally.") + translationManager.emptyString
                    useCase: qsTr("Compare periods or receive an alert at a target price. Requires external price connections to be enabled.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Swap comparisons") + translationManager.emptyString
                    description: qsTr("Compare quotes from Wagyu, NonKYC and ChangeNOW, routes and previous prices. The separate No-KYC table compares more providers.") + translationManager.emptyString
                    useCase: qsTr("Estimate what you would receive before choosing a service. Quotes are indicative; exchanges are completed with the provider.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("No-KYC offers") + translationManager.emptyString
                    description: qsTr("Compare buy and sell quotes, spread, minimums and the information shown for each provider.") + translationManager.emptyString
                    useCase: qsTr("Review conditions on the provider\u2019s site before starting. External links open in your browser, outside the wallet\u2019s private route.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Trading"
                    actionText: qsTr("Open markets") + translationManager.emptyString
                    offersPriceSetup: true
                }
                GuideAction {
                    destination: "Swaps"
                    actionText: qsTr("Compare swaps") + translationManager.emptyString
                }
                GuideAction {
                    destination: "SwapsNoKyc"
                    actionText: qsTr("View offers") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusSection5"
                icon: FontAwesome.stickyNote
                title: qsTr("Encrypted notes") + translationManager.emptyString
                summary: "1 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Notes attached to your wallet") + translationManager.emptyString
                    description: qsTr("Notes are encrypted with AES-256-GCM and stored beside the wallet. They unlock with the open wallet and lock when it closes.") + translationManager.emptyString
                    useCase: qsTr("Keep payment references or personal records. On supported Trezor wallets, unlocking also requires confirmation on the device.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Notes"
                    actionText: qsTr("Open notes") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusSection6"
                icon: FontAwesome.microchip
                title: qsTr("Trezor") + translationManager.emptyString
                summary: "2 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Connection and pairing") + translationManager.emptyString
                    description: qsTr("Trezor Safe 7 supports USB and Bluetooth with THP. Select the device when several are connected and confirm pairing on its screen.") + translationManager.emptyString
                    useCase: qsTr("Use the device with the wallet directly. Close Trezor Suite first to avoid competing for the connection.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Personalize your device") + translationManager.emptyString
                    description: qsTr("Change the name, homescreen, brightness, haptics and auto-lock where supported by the model. Device changes require confirmation.") + translationManager.emptyString
                    useCase: qsTr("Distinguish several devices by name and appearance, and choose a suitable auto-lock time.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Trezor"
                    actionText: qsTr("Open Trezor") + translationManager.emptyString
                }
            }
            GuideSection {
                objectName: "walletPlusSection7"
                icon: FontAwesome.palette
                title: qsTr("Appearance and desktop") + translationManager.emptyString
                summary: "2 \u00b7" + " " + qsTr("Tools") + translationManager.emptyString
                Feature {
                    heading: qsTr("Themes and effects") + translationManager.emptyString
                    description: qsTr("Choose dark or light mode, a colour palette and Neon or Matte from the title-bar theme menu. Interface settings control optional effects and sounds.") + translationManager.emptyString
                    useCase: qsTr("Use Matte for a softer appearance and reduce animation or sounds when you want fewer distractions.") + translationManager.emptyString
                }
                Feature {
                    heading: qsTr("Ticker, menu bar and widget") + translationManager.emptyString
                    description: qsTr("Show prices in the scrolling ticker, macOS menu bar or desktop widget, with configurable rows and currency. The widget runs while the app is open.") + translationManager.emptyString
                    useCase: qsTr("Follow prices or node progress without keeping the main window in front. Choose carefully whether to display your balance.") + translationManager.emptyString
                }
                GuideAction {
                    destination: "Interface"
                    actionText: qsTr("Customize interface") + translationManager.emptyString
                }
            }
        }
        UI.TextPlain {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 24
            text: qsTr("XMR Wallet+ is an unofficial fork of the Monero GUI. These shortcuts open tools; they do not enable features or send payments.") + translationManager.emptyString
            font.pixelSize: 12
            color: UI.Style.dimmedFontColor
            themeTransition: false
            wrapMode: Text.WordWrap
        }
    }
}
