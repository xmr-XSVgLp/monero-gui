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
import QtQuick.Effects
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import moneroComponents.NetworkType 1.0
import moneroComponents.WalletKeysFilesModel 1.0
import FontAwesome

import "../js/Wizard.js" as Wizard
import "../components"
import "../components" as MoneroComponents
import "../components/effects/" as MoneroEffects

Rectangle {
    id: wizardOpenWallet1

    color: "transparent"
    property alias pageHeight: pageRoot.height
    property alias pageRoot: pageRoot
    property alias recentWallets: recentList
    property string viewName: "wizardOpenWallet1"
    property int walletCount: walletKeysFilesModel.rowCount()
    // wallets in the "XMR" folder of USB / SD volumes, checked every few seconds while this page is shown
    property var usbWallets: []

    property var usbRoots: []

    function refreshUsbWallets() {
        var list = oshelper.removableWallets();
        if (JSON.stringify(list) !== JSON.stringify(usbWallets))
            usbWallets = list;
        var roots = oshelper.removableVolumes().map(function(v) { return v.root + "/"; });
        if (JSON.stringify(roots) !== JSON.stringify(usbRoots))
            usbRoots = roots;
    }

    function onDrive(path) {
        for (var i = 0; i < usbRoots.length; ++i)
            if (path.indexOf(usbRoots[i]) === 0)
                return true;
        return false;
    }

    Timer {
        interval: 3000
        repeat: true
        running: wizardOpenWallet1.visible && wizardStateView.state === "wizardOpenWallet1"
        triggeredOnStart: true
        onTriggered: wizardOpenWallet1.refreshUsbWallets()
    }

    WalletKeysFilesModel {
        id: walletKeysFilesModel
    }

    ColumnLayout {
        id: pageRoot
        Layout.alignment: Qt.AlignHCenter;
        width: parent.width - 100
        Layout.fillWidth: true
        anchors.horizontalCenter: parent.horizontalCenter;
        KeyNavigation.tab: openWalletFromFileHeader

        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: wizardController.wizardSubViewTopMargin
            Layout.maximumWidth: wizardController.wizardSubViewWidth
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            WizardHeader {
                id: openWalletFromFileHeader
                title: qsTr("Open a wallet from file") + translationManager.emptyString
                subtitle: qsTr("Import an existing .keys wallet file from your computer.") + translationManager.emptyString
                Accessible.role: Accessible.StaticText
                Accessible.name: title + ". " + subtitle
                Keys.onUpPressed: wizardNav.btnNext.forceActiveFocus();
                Keys.onBacktabPressed: wizardNav.btnNext.forceActiveFocus();
                Keys.onDownPressed: recentList.itemAt(0).forceActiveFocus();
                Keys.onTabPressed: recentList.itemAt(0).forceActiveFocus();
            }

            // ---- wallets on USB / SD volumes ----
            RowLayout {
                visible: wizardOpenWallet1.usbWallets.length > 0
                Layout.topMargin: 14
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 6; height: 6
                    color: MoneroComponents.Style.blackTheme ? "#6CB8FF" : "#1565C0"
                }

                MoneroComponents.TextPlain {
                    text: qsTr("USB / SD wallets").toUpperCase() + translationManager.emptyString
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    text: wizardOpenWallet1.usbWallets.length
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    opacity: 0.7
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.TextPlain {
                    text: qsTr("Close the wallet before unplugging the drive") + translationManager.emptyString
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }

            Flow {
                id: usbFlow
                visible: wizardOpenWallet1.usbWallets.length > 0
                spacing: 10
                Layout.topMargin: 4
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight

                Repeater {
                    model: wizardOpenWallet1.usbWallets

                    delegate: Item {
                        id: usbItem
                        height: flow.itemHeight
                        width: Math.floor((usbFlow.width - (flow.columns - 1) * usbFlow.spacing) / flow.columns)
                        readonly property bool dark: MoneroComponents.Style.blackTheme
                        readonly property color blue: dark ? "#6CB8FF" : "#1565C0"
                        readonly property bool hovered: usbMouseArea.containsMouse || usbItem.focus
                        activeFocusOnTab: true
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.fileName + ". " + modelData.volume
                        Keys.onEnterPressed: wizardController.openWalletFile(modelData.path)
                        Keys.onReturnPressed: wizardController.openWalletFile(modelData.path)

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            accent: usbItem.blue
                            lineOpacity: usbItem.focus ? 1.0 : (usbItem.hovered ? 0.9 : 0.45)
                            fillColor: usbItem.dark ? "#0C130E" : "#DADFDB"
                            fillOpacity: usbItem.dark ? 0.92 : 0.9
                            glow: usbItem.hovered ? 0.3 : 0.0
                            ticks: usbItem.hovered
                            Behavior on lineOpacity { NumberAnimation { duration: 150 } }
                        }

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            lineOpacity: 0
                            fillColor: usbItem.blue
                            fillOpacity: usbItem.hovered ? 0.12 : 0.05
                            ticks: false
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            // chosen icon, else: mainnet wallet on the drive = purple USB stick instead of the safe
                            MoneroComponents.WalletIcon {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                kind: {
                                    wizardOpenWallet1.iconRevision;
                                    var chosen = wizardOpenWallet1.chosenIcon(modelData.path);
                                    if (chosen !== "") return chosen;
                                    if (/trezor|tzr/.test(modelData.fileName.toLowerCase())) return "trezor";
                                    return modelData.networktype === 1 ? "testnet" : modelData.networktype === 2 ? "stagenet" : "usb";
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: modelData.fileName
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMedium.name
                                    font.pixelSize: 15
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }

                                // drive name and last change
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: modelData.volume + " · " + Qt.formatDate(new Date(modelData.modified * 1000), "dd/MM/yyyy")
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 11
                                    color: usbItem.blue
                                    themeTransition: false
                                }
                            }
                        }

                        MouseArea {
                            id: usbMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wizardController.openWalletFile(modelData.path)
                        }
                    }
                }
            }

            RowLayout {
                visible: wizardOpenWallet1.walletCount > 0
                Layout.topMargin: 14
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 6; height: 6
                    color: MoneroComponents.Style.blackTheme ? "#4E9E6A" : "#2E7D4A"
                }

                MoneroComponents.TextPlain {
                    text: qsTr("Recently opened").toUpperCase() + translationManager.emptyString
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.TextPlain {
                    text: wizardOpenWallet1.walletCount
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    opacity: 0.7
                    themeTransition: false
                }

                Item { Layout.fillWidth: true }
            }

            Flow {
                id: flow
                visible: wizardOpenWallet1.walletCount > 0
                spacing: 10
                clip: true

                property int _height: 0
                property int itemHeight: 64
                property int maxRows: 5
                property int columns: wizardController.layoutScale <= 1 ? 2 : 3

                Layout.topMargin: 4
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: _height

                function calcHeight(){
                    var rows = Math.min(Math.ceil(wizardOpenWallet1.walletCount / flow.columns), flow.maxRows);
                    return rows * flow.itemHeight + Math.max(0, rows - 1) * flow.spacing + 4;
                }

                Repeater {
                    id: recentList
                    clip: true
                    model: walletKeysFilesModel.proxyModel
                    Layout.fillWidth: true
                    Layout.minimumWidth: flow.itemHeight
                    Layout.preferredHeight: parent.height

                    function moveUp(itemIndex) {
                        if (itemIndex == 0) {
                            openWalletFromFileHeader.forceActiveFocus();
                        } else {
                            recentList.itemAt(itemIndex - 1).forceActiveFocus();
                        }
                    }

                    function moveDown(itemIndex) {
                        if (itemIndex + 1 == recentList.count) {
                            wizardNav.btnPrev.forceActiveFocus();
                        } else {
                            recentList.itemAt(itemIndex + 1).forceActiveFocus();
                        }
                    }

                    function openSelectedWalletFile(path) {
                        wizardController.openWalletFile(path);
                    }

                    delegate: Item {
                        // inherited roles from walletKeysFilesModel:
                        // index, fileName, modified, accessed, path, networktype, address
                        id: item
                        height: flow.itemHeight
                        width: Math.floor((flow.width - (flow.columns - 1) * flow.spacing) / flow.columns)
                        property string walletFileName: fileName
                        property string networkType: {
                            if(networktype === 0 && appWindow.walletMode >= 2) return qsTr("Mainnet");
                            else if(networktype === 1) return qsTr("Testnet");
                            else if(networktype === 2) return qsTr("Stagenet");
                            return "";
                        }
                        readonly property bool dark: MoneroComponents.Style.blackTheme
                        readonly property color border: dark ? "#E8ECE9" : "#2B3A30"
                        readonly property color accent: dark ? "#4E9E6A" : "#2E7D4A"
                        readonly property bool hovered: itemMouseArea.containsMouse || item.focus || editArea.containsMouse
                        readonly property bool inUse: wizardOpenWallet1.walletInUse(path)

                        Accessible.role: Accessible.ListItem
                        Accessible.name: {
                            if (networktype === 0) var networkTypeText = qsTr("Mainnet wallet") + translationManager.emptyString;
                            if (networktype === 1) var networkTypeText = qsTr("Testnet wallet") + translationManager.emptyString;
                            if (networktype === 2) var networkTypeText = qsTr("Stagenet wallet") + translationManager.emptyString;

                            return fileName + ". " + networkTypeText;
                        }
                        Keys.onUpPressed: recentList.moveUp(index);
                        Keys.onBacktabPressed: recentList.moveUp(index);
                        Keys.onDownPressed: recentList.moveDown(index);
                        Keys.onTabPressed: recentList.moveDown(index);
                        Keys.onEnterPressed: recentList.openSelectedWalletFile(path);
                        Keys.onReturnPressed: recentList.openSelectedWalletFile(path);

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            accent: item.border
                            lineOpacity: item.focus ? 1.0 : (item.hovered ? 0.85 : 0.22)
                            fillColor: item.dark ? "#0C130E" : "#DADFDB"
                            fillOpacity: item.dark ? 0.92 : 0.9
                            glow: item.hovered ? 0.3 : 0.0
                            ticks: item.hovered
                            Behavior on lineOpacity { NumberAnimation { duration: 150 } }
                        }

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 9
                            lineOpacity: 0
                            fillColor: item.accent
                            fillOpacity: item.hovered ? 0.10 : 0.0
                            ticks: false
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            MoneroComponents.WalletIcon {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                kind: {
                                    wizardOpenWallet1.iconRevision;
                                    var chosen = wizardOpenWallet1.chosenIcon(path);
                                    if (chosen !== "") return chosen;
                                    var name = fileName.toLowerCase();
                                    if (networktype === 1) return "testnet";
                                    if (networktype === 2) return "stagenet";
                                    if (name.includes("viewonly")) return "viewonly";
                                    if (/trezor|tzr|trial/.test(name)) return "trezor";
                                    if (name.includes("ledger")) return "ledger";
                                    return wizardOpenWallet1.onDrive(path) ? "usb" : "safe";
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: fileName
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMedium.name
                                    font.pixelSize: 15
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }

                                // short address, or the last time the file changed
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: address && address.length > 12
                                          ? address.substring(0, 6) + "…" + address.substring(address.length - 6)
                                          : Qt.formatDate(new Date(modified * 1000), "dd/MM/yyyy")
                                    elide: Text.ElideRight
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 11
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                            }

                            // network badge (testnet/stagenet, or mainnet in advanced mode)
                            Item {
                                visible: item.networkType !== ""
                                // on hover the badge slides left so the 3 buttons don't cover it
                                Layout.rightMargin: item.hovered ? 32 : 0
                                implicitWidth: netText.implicitWidth + 12
                                implicitHeight: netText.implicitHeight + 6

                                MoneroComponents.NeonFrame {
                                    anchors.fill: parent
                                    cut: 4
                                    accent: networktype === 0 ? item.border : (networktype === 1 ? "#FFB200" : "#00E8FF")
                                    lineOpacity: 0.5
                                    fillColor: accent
                                    fillOpacity: 0.08
                                    ticks: false
                                }

                                MoneroComponents.TextPlain {
                                    id: netText
                                    anchors.centerIn: parent
                                    text: item.networkType.toUpperCase()
                                    font.family: MoneroComponents.Style.fontMonoRegular.name
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: recentList.openSelectedWalletFile(path);
                        }

                        // one edit button on hover: opens the wallet editor (name, icon, delete)
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: item.hovered
                            width: 28
                            height: 28
                            radius: 4
                            color: item.dark ? "#0C130E" : "#DADFDB"
                            border.width: 1
                            border.color: editArea.containsMouse ? item.border : Qt.rgba(item.border.r, item.border.g, item.border.b, 0.35)
                            Text {
                                anchors.centerIn: parent
                                text: "\uf044"
                                font.family: FontAwesome.fontFamily
                                font.styleName: "Regular"
                                font.pixelSize: 13
                                color: MoneroComponents.Style.defaultFontColor
                            }
                        }

                        // declared after the tile's own MouseArea so it sits on top
                        MouseArea {
                            id: editArea
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wizardOpenWallet1.editWallet(path, fileName, item.inUse)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            WizardNav {
                id: wizardNav
                Layout.topMargin: 0
                progressEnabled: false
                btnPrev.text: appWindow.width <= 506 ? "<" : qsTr("Back to menu") + translationManager.emptyString
                btnNext.text: appWindow.width <= 760 ? qsTr("Browse") : qsTr("Browse filesystem") + translationManager.emptyString
                btnNext.width: appWindow.width <= 506 ? 80 : appWindow.width <= 760 ? 120 : 330
                btnNext.visible: true
                btnPrevKeyNavigationBackTab: recentList.itemAt(recentList.count - 1)
                btnNextKeyNavigationTab: openWalletFromFileHeader

                onPrevClicked: {
                    wizardStateView.state = "wizardHome";
                }
                onNextClicked: {
                    wizardController.openWallet();
                }
            }
        }
    }

    // icon the user chose for a wallet, kept in "<wallet>.json" next to its files ("" = automatic, from the name)
    property int iconRevision: 0
    readonly property var iconChoices: [
        { kind: "", label: qsTr("Automatic") },
        { kind: "safe", label: qsTr("Safe") },
        { kind: "trezor", label: "Trezor" },
        { kind: "viewonly", label: qsTr("View only") },
        { kind: "usb", label: "USB" },
        { kind: "custom/safe-grey", label: qsTr("Grey safe") },
        { kind: "custom/safe-red", label: qsTr("Red safe") },
        { kind: "custom/wallet-leather", label: qsTr("Leather") },
        { kind: "custom/wallet-neon", label: qsTr("Neon") },
        { kind: "custom/purse-red", label: qsTr("Purse") },
        { kind: "custom/coins-stack", label: qsTr("Stack") },
        { kind: "custom/coin-gold", label: qsTr("Gold") },
        { kind: "custom/coin-silver", label: qsTr("Silver") },
        { kind: "custom/coins-cyan", label: qsTr("Coins") },
        { kind: "custom/piggy-pink", label: qsTr("Piggy bank") },
        { kind: "custom/cards-violet", label: qsTr("Cards") },
        { kind: "custom/coin-bag-blue", label: qsTr("Coin bag") }
    ]

    function walletJson(path) {
        var text = oshelper.readTextFile(String(path).replace(/\.keys$/, "") + ".json");
        try { return JSON.parse(text) || {}; } catch (e) { return {}; }
    }

    function chosenIcon(path) {
        var icon = walletJson(path).icon;
        return typeof icon === "string" ? icon : "";
    }

    function setWalletIcon(path, kind) {
        var data = walletJson(path);
        if (kind === "") delete data.icon;
        else data.icon = kind;
        oshelper.writeTextFile(String(path).replace(/\.keys$/, "") + ".json", JSON.stringify(data, null, 2) + "\n");
        iconRevision++;
    }

    function editWallet(path, name, inUse) {
        walletEditor.walletPath = path;
        walletEditor.walletName = name;
        walletEditor.inUse = inUse;
        walletEditor.current = chosenIcon(path);
        nameField.text = name;
        walletEditor.open();
    }

    // icon first (its .json is renamed together with the wallet), then the name
    function saveWalletEdit() {
        var path = walletEditor.walletPath;
        if (walletEditor.current !== chosenIcon(path))
            setWalletIcon(path, walletEditor.current);
        var newName = nameField.text.trim();
        if (!walletEditor.inUse && newName !== "" && newName !== walletEditor.walletName) {
            var r = oshelper.renameWallet(path, newName);
            if (!r.ok) {
                showError(qsTr("Rename wallet") + translationManager.emptyString, r.error);
                return;
            }
            appWindow.moveWalletSettings(path, r.path);
        }
        walletEditor.close();
        reloadWallets();
    }

    function reloadWallets() {
        walletKeysFilesModel.refresh(appWindow.accountsDir);
        wizardOpenWallet1.walletCount = walletKeysFilesModel.rowCount();
        flow._height = flow.calcHeight();
    }

    // the open wallet, or one kept unlocked for switching, cannot be renamed or deleted
    function walletInUse(path) {
        var key = String(path).replace(/\.keys$/, "");
        return (appWindow.currentWallet && String(appWindow.currentWallet.path).replace(/\.keys$/, "") === key)
               || appWindow.isParkedWallet(path);
    }

    function showError(title, error) {
        informationPopup.title = title;
        informationPopup.text = error === "exists" ? qsTr("There is already a wallet with that name.") + translationManager.emptyString
                              : error === "invalid name" ? qsTr("That name is not valid: do not use / \\ : or start with a dot.") + translationManager.emptyString
                              : error;
        informationPopup.onCloseCallback = null;
        informationPopup.open();
    }

    function deleteWallet(path, name) {
        confirmationDialog.title = qsTr("Delete wallet") + translationManager.emptyString;
        confirmationDialog.text = qsTr("Move the wallet \"%1\" to the Trash?\n\nIts files go to the macOS Trash, so you can still put them back from Finder until you empty it. Without its seed (or the Trezor that created it) the funds can not be recovered once the Trash is emptied.").arg(name) + translationManager.emptyString;
        confirmationDialog.onAcceptedCallback = function() {
            var r = oshelper.trashWallet(path);
            if (!r.ok) {
                showError(qsTr("Delete wallet") + translationManager.emptyString, r.error);
                return;
            }
            appWindow.moveWalletSettings(path, "");
            reloadWallets();
        };
        confirmationDialog.onRejectedCallback = null;
        confirmationDialog.open();
    }

    function onPageCompleted(previousView){
        if(previousView.viewName == "wizardHome"){
            reloadWallets();
        }
    }

    // wallet editor: name, icon, save / cancel / delete
    Popup {
        id: walletEditor
        property string walletPath: ""
        property string walletName: ""
        property string current: ""
        property bool inUse: false
        readonly property bool dark: MoneroComponents.Style.blackTheme
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        focus: true
        padding: 22
        width: Math.min(620, (parent ? parent.width : 620) - 40)

        Overlay.modal: Rectangle { color: walletEditor.dark ? "#B3000000" : "#80000000" }

        background: MoneroComponents.NeonFrame {
            cut: 12
            accent: walletEditor.dark ? "#E8ECE9" : "#2B3A30"
            lineOpacity: 0.6
            fillColor: walletEditor.dark ? "#0C130E" : "#E6EAE7"
            fillOpacity: 0.98
            ticks: true
        }

        contentItem: ColumnLayout {
            spacing: 14

            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                text: qsTr("Edit wallet") + translationManager.emptyString
                elide: Text.ElideRight
                font.family: MoneroComponents.Style.fontMedium.name
                font.pixelSize: 17
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }

            MoneroComponents.TextPlain {
                text: qsTr("Name") + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                enabled: !walletEditor.inUse
                selectByMouse: true
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 15
                color: MoneroComponents.Style.defaultFontColor
                selectionColor: walletEditor.dark ? "#4E9E6A" : "#2E7D4A"
                leftPadding: 10
                rightPadding: 10
                topPadding: 8
                bottomPadding: 8
                background: MoneroComponents.NeonFrame {
                    cut: 6
                    accent: walletEditor.dark ? "#E8ECE9" : "#2B3A30"
                    lineOpacity: nameField.activeFocus ? 0.9 : 0.35
                    fillColor: walletEditor.dark ? "#000000" : "#FFFFFF"
                    fillOpacity: 0.25
                    ticks: false
                }
                onAccepted: wizardOpenWallet1.saveWalletEdit()
            }

            MoneroComponents.TextPlain {
                visible: walletEditor.inUse
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("This wallet is open: close it to rename or delete it.") + translationManager.emptyString
                font.pixelSize: 11
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.TextPlain {
                Layout.topMargin: 4
                text: qsTr("Icon") + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Saved in \"%1.json\" next to the wallet, so it goes with it when you copy it.").arg(walletEditor.walletName) + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            Flow {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: wizardOpenWallet1.iconChoices
                    delegate: Item {
                        width: 78
                        height: 92
                        readonly property bool selected: walletEditor.current === modelData.kind
                        readonly property bool over: choiceArea.containsMouse

                        MoneroComponents.NeonFrame {
                            anchors.fill: parent
                            cut: 7
                            accent: parent.selected ? (walletEditor.dark ? "#4E9E6A" : "#2E7D4A") : (walletEditor.dark ? "#E8ECE9" : "#2B3A30")
                            lineOpacity: parent.selected ? 1 : (parent.over ? 0.8 : 0.25)
                            fillColor: accent
                            fillOpacity: parent.selected ? 0.12 : (parent.over ? 0.06 : 0)
                            ticks: parent.selected
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Item {
                                width: 44
                                height: 44
                                anchors.horizontalCenter: parent.horizontalCenter

                                MoneroComponents.WalletIcon {
                                    visible: modelData.kind !== ""
                                    anchors.fill: parent
                                    kind: modelData.kind
                                }
                                // automatic: decided from the file name, as before
                                MoneroComponents.TextPlain {
                                    visible: modelData.kind === ""
                                    anchors.centerIn: parent
                                    text: "A"
                                    font.family: MoneroComponents.Style.fontMonoMedium.name
                                    font.pixelSize: 26
                                    color: MoneroComponents.Style.dimmedFontColor
                                    themeTransition: false
                                }
                            }

                            MoneroComponents.TextPlain {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label + translationManager.emptyString
                                font.pixelSize: 11
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                            }
                        }

                        MouseArea {
                            id: choiceArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: walletEditor.current = modelData.kind
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                MoneroComponents.StandardButton {
                    visible: !walletEditor.inUse
                    small: true
                    accent: walletEditor.dark ? "#FF4D4D" : "#C62828"
                    textColor: walletEditor.dark ? "#FFD6D6" : "#C62828"
                    text: qsTr("Delete wallet") + translationManager.emptyString
                    onClicked: {
                        walletEditor.close();
                        wizardOpenWallet1.deleteWallet(walletEditor.walletPath, walletEditor.walletName);
                    }
                }

                Item { Layout.fillWidth: true }

                MoneroComponents.StandardButton {
                    small: true
                    accent: walletEditor.dark ? "#8C8C8C" : "#6B6B6B"
                    textColor: walletEditor.dark ? "#D0D0D0" : "#4A4A4A"
                    text: qsTr("Cancel") + translationManager.emptyString
                    onClicked: walletEditor.close()
                }

                MoneroComponents.StandardButton {
                    small: true
                    accent: walletEditor.dark ? "#5FD08F" : "#1E8E4E"
                    text: qsTr("Save") + translationManager.emptyString
                    onClicked: wizardOpenWallet1.saveWalletEdit()
                }
            }
        }
    }
}
