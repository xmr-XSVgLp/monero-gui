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
import QtQuick.Dialogs

import moneroComponents.Wallet 1.0

import "../../js/Utils.js" as Utils
import "../../js/Windows.js" as Windows
import "../../components" as MoneroComponents

Rectangle {
    color: "transparent"
    Layout.fillWidth: true
    property alias layoutHeight: settingsUI.height

    ColumnLayout {
        id: settingsUI
        property int itemHeight: 60
        Layout.fillWidth: true
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        anchors.topMargin: 0
        spacing: 12


        // ---- appearance ----
        MoneroComponents.SectionTitle {
            Layout.fillWidth: true
            text: qsTr("Appearance") + translationManager.emptyString
        }

        MoneroComponents.SettingsCard {
            MoneroComponents.CheckBox {
                id: themeCheckbox
                checked: !MoneroComponents.Style.blackTheme
                text: qsTr("Light theme") + translationManager.emptyString
                toggleOnClick: false
                onClicked: {
                    MoneroComponents.Style.blackTheme = !MoneroComponents.Style.blackTheme;
                }
            }

            MoneroComponents.CheckBox {
                checked: persistentSettings.displayWalletNameInTitleBar
                onClicked: persistentSettings.displayWalletNameInTitleBar = !persistentSettings.displayWalletNameInTitleBar
                text: qsTr("Display wallet name in title bar") + translationManager.emptyString
            }

            MoneroComponents.CheckBox {
                id: hideBalanceCheckBox
                checked: persistentSettings.hideBalance
                onClicked: {
                    persistentSettings.hideBalance = !persistentSettings.hideBalance
                    appWindow.updateBalance();
                }
                text: qsTr("Hide balance") + translationManager.emptyString
            }

            MoneroComponents.CheckBox {
                checked: persistentSettings.priceTicker
                onClicked: persistentSettings.priceTicker = !persistentSettings.priceTicker
                text: qsTr("Show XMR price ticker at the bottom") + translationManager.emptyString
            }

            MoneroComponents.TextPlain {
                visible: persistentSettings.priceTicker && !persistentSettings.fiatPriceEnabled
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Needs the prices on: Node / Network tab, External connections.") + translationManager.emptyString
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.StandardButton {
                visible: !persistentSettings.customDecorations
                Layout.topMargin: 4
                small: true
                text: qsTr("Change language") + translationManager.emptyString

                onClicked: {
                    appWindow.toggleLanguageView();
                }
            }
        }

        // ---- matrix effects ----
        MoneroComponents.SectionTitle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: "MATRIX FX"
        }

        MoneroComponents.SettingsCard {
            MoneroComponents.CheckBox {
                checked: persistentSettings.fxMatrixRain
                onClicked: persistentSettings.fxMatrixRain = !persistentSettings.fxMatrixRain
                text: "Lluvia Matrix de fondo"
            }

            MoneroComponents.CheckBox {
                checked: persistentSettings.fxPageGlitch
                onClicked: persistentSettings.fxPageGlitch = !persistentSettings.fxPageGlitch
                text: "Efecto glitch al cambiar de página"
            }

            MoneroComponents.CheckBox {
                checked: persistentSettings.fxSounds
                onClicked: persistentSettings.fxSounds = !persistentSettings.fxSounds
                text: "Sonidos de la interfaz"
            }
        }

        // ---- macOS menu bar ----
        MoneroComponents.SectionTitle {
            visible: Qt.platform.os === "osx"
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: qsTr("Menu bar") + translationManager.emptyString
        }

        MoneroComponents.SettingsCard {
            visible: Qt.platform.os === "osx"

            MoneroComponents.CheckBox {
                checked: persistentSettings.menuBarEnabled
                onClicked: persistentSettings.menuBarEnabled = !persistentSettings.menuBarEnabled
                text: qsTr("Show icon in the macOS menu bar") + translationManager.emptyString
            }

            ColumnLayout {
                visible: persistentSettings.menuBarEnabled
                Layout.leftMargin: 32
                spacing: 6

                MoneroComponents.TextPlain {
                    text: qsTr("Next to the icon show:") + translationManager.emptyString
                    font.pixelSize: 14
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.menuBarPrice
                    onClicked: { persistentSettings.menuBarPrice = !persistentSettings.menuBarPrice; Qt.callLater(appWindow.updateMenuBar); }
                    text: qsTr("XMR price in") + translationManager.emptyString
                }

                // unit buttons on their own row (the checkbox text has no implicit width in a RowLayout)
                RowLayout {
                    Layout.leftMargin: 32
                    spacing: 10
                    Repeater {
                        model: ["BTC", "EUR", "USD"]
                        MoneroComponents.StandardButton {
                            small: true
                            primary: persistentSettings.menuBarPriceUnit === modelData
                            enabled: persistentSettings.menuBarPrice
                            text: modelData === "BTC" ? "mBTC" : modelData
                            onClicked: { persistentSettings.menuBarPriceUnit = modelData; Qt.callLater(appWindow.updateMenuBar); }
                        }
                    }
                }

                MoneroComponents.CheckBox {
                    enabled: persistentSettings.menuBarPrice
                    checked: persistentSettings.menuBarChange
                    onClicked: { persistentSettings.menuBarChange = !persistentSettings.menuBarChange; Qt.callLater(appWindow.updateMenuBar); }
                    text: qsTr("24 h change (▲/▼)") + translationManager.emptyString
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.menuBarBalance
                    onClicked: { persistentSettings.menuBarBalance = !persistentSettings.menuBarBalance; Qt.callLater(appWindow.updateMenuBar); }
                    text: qsTr("Wallet balance (hidden if the balance is hidden)") + translationManager.emptyString
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.menuBarSync
                    onClicked: { persistentSettings.menuBarSync = !persistentSettings.menuBarSync; Qt.callLater(appWindow.updateMenuBar); }
                    text: qsTr("Node sync % while synchronizing") + translationManager.emptyString
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.menuBarNym
                    onClicked: { persistentSettings.menuBarNym = !persistentSettings.menuBarNym; Qt.callLater(appWindow.updateMenuBar); }
                    text: qsTr("NYM status") + translationManager.emptyString
                }
            }
        }

        // ---- macOS desktop widget ----
        MoneroComponents.SectionTitle {
            visible: Qt.platform.os === "osx"
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: qsTr("Desktop widget") + translationManager.emptyString
        }

        MoneroComponents.SettingsCard {
            visible: Qt.platform.os === "osx"

            MoneroComponents.CheckBox {
                checked: persistentSettings.desktopWidgetEnabled
                onClicked: persistentSettings.desktopWidgetEnabled = !persistentSettings.desktopWidgetEnabled
                text: qsTr("Show a panel on the wallpaper (drag to move, double click opens the wallet)") + translationManager.emptyString
            }

            ColumnLayout {
                visible: persistentSettings.desktopWidgetEnabled
                Layout.leftMargin: 32
                spacing: 6

                MoneroComponents.TextPlain {
                    text: qsTr("Price in:") + translationManager.emptyString
                    font.pixelSize: 14
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                RowLayout {
                    spacing: 10
                    Repeater {
                        model: ["BTC", "EUR", "USD"]
                        MoneroComponents.StandardButton {
                            small: true
                            primary: persistentSettings.desktopWidgetUnit === modelData
                            text: modelData === "BTC" ? "mBTC" : modelData
                            onClicked: persistentSettings.desktopWidgetUnit = modelData
                        }
                    }
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.desktopWidgetChart
                    onClicked: persistentSettings.desktopWidgetChart = !persistentSettings.desktopWidgetChart
                    text: qsTr("24 h chart") + translationManager.emptyString
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.desktopWidgetBalance
                    onClicked: persistentSettings.desktopWidgetBalance = !persistentSettings.desktopWidgetBalance
                    text: qsTr("Wallet balance (hidden if the balance is hidden)") + translationManager.emptyString
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.desktopWidgetNode
                    onClicked: persistentSettings.desktopWidgetNode = !persistentSettings.desktopWidgetNode
                    text: qsTr("Node status") + translationManager.emptyString
                }

                MoneroComponents.CheckBox {
                    checked: persistentSettings.desktopWidgetNym
                    onClicked: persistentSettings.desktopWidgetNym = !persistentSettings.desktopWidgetNym
                    text: qsTr("NYM status") + translationManager.emptyString
                }

                MoneroComponents.TextPlain {
                    text: qsTr("Background opacity:") + translationManager.emptyString
                    font.pixelSize: 14
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                RowLayout {
                    spacing: 10
                    Repeater {
                        model: [0.3, 0.5, 0.75, 0.95]
                        MoneroComponents.StandardButton {
                            small: true
                            primary: Math.abs(persistentSettings.desktopWidgetOpacity - modelData) < 0.01
                            text: Math.round(modelData * 100) + "%"
                            onClicked: persistentSettings.desktopWidgetOpacity = modelData
                        }
                    }
                }
            }
        }

        // ---- security ----
        MoneroComponents.SectionTitle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: qsTr("Security") + translationManager.emptyString
        }

        MoneroComponents.SettingsCard {
            MoneroComponents.CheckBox {
                checked: persistentSettings.askPasswordBeforeSending
                text: qsTr("Ask for password before sending a transaction") + translationManager.emptyString
                toggleOnClick: false
                onClicked: {
                    if (persistentSettings.askPasswordBeforeSending) {
                        passwordDialog.onAcceptedCallback = function() {
                            if (appWindow.walletPassword === passwordDialog.password){
                                persistentSettings.askPasswordBeforeSending = false;
                            } else {
                                passwordDialog.showError(qsTr("Wrong password"));
                            }
                        }
                        passwordDialog.onRejectedCallback = null;
                        passwordDialog.open()
                    } else {
                        persistentSettings.askPasswordBeforeSending = true;
                    }
                }
            }

            MoneroComponents.CheckBox {
                id: userInActivityCheckbox
                checked: persistentSettings.lockOnUserInActivity
                onClicked: persistentSettings.lockOnUserInActivity = !persistentSettings.lockOnUserInActivity
                text: qsTr("Lock wallet on inactivity") + translationManager.emptyString
            }

            MoneroComponents.CheckBox {
                checked: persistentSettings.quickWalletSwitch
                onClicked: {
                    persistentSettings.quickWalletSwitch = !persistentSettings.quickWalletSwitch;
                    appWindow.forgetOtherUnlockedWallets();
                    if (persistentSettings.quickWalletSwitch && appWindow.currentWallet)
                        appWindow.rememberUnlockedWallet(persistentSettings.wallet_path, appWindow.walletPassword, persistentSettings.nettype);
                }
                text: qsTr("Keep unlocked wallets syncing in the background and switch between them without the password (only in memory, forgotten on lock or quit)") + translationManager.emptyString
            }

            MoneroComponents.Slider {
                visible: userInActivityCheckbox.checked
                Layout.fillWidth: true
                Layout.leftMargin: 35
                Layout.rightMargin: 8
                from: 1
                stepSize: 1
                to: 60
                value: persistentSettings.lockOnUserInActivityInterval
                text: {
                    var minutes = value > 1 ? qsTr("minutes") : qsTr("minute");
                    return qsTr("After ") + value + " " + minutes + translationManager.emptyString;
                }
                onMoved: persistentSettings.lockOnUserInActivityInterval = value
            }

            MoneroComponents.CheckBox {
                id: backgroundSyncCheckbox
                visible: !!currentWallet && !currentWallet.isHwBacked() && !appWindow.viewOnly
                checked: appWindow.backgroundSyncType != Wallet.BackgroundSync_Off
                text: qsTr("Sync in the background when locked") + translationManager.emptyString
                toggleOnClick: false
                onClicked: {
                    if (currentWallet && appWindow) {
                        appWindow.showProcessingSplash(qsTr("Updating settings..."))

                        // TODO: add support for custom background password option
                        var newBackgroundSyncType = Wallet.BackgroundSync_Off
                        if (currentWallet.getBackgroundSyncType() === Wallet.BackgroundSync_Off)
                            newBackgroundSyncType = Wallet.BackgroundSync_ReusePassword

                        // TODO: don't keep the wallet password in memory on the appWindow
                        // https://github.com/monero-project/monero-gui/issues/1537#issuecomment-410055329
                        currentWallet.setupBackgroundSync(newBackgroundSyncType, appWindow.walletPassword)
                    }
                }
            }
        }

        // ---- general ----
        MoneroComponents.SectionTitle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: qsTr("General") + translationManager.emptyString
        }

        MoneroComponents.SettingsCard {
            MoneroComponents.CheckBox {
                id: checkForUpdatesCheckBox
                enabled: !disableCheckUpdatesFlag
                checked: persistentSettings.checkForUpdates && !disableCheckUpdatesFlag
                onClicked: persistentSettings.checkForUpdates = !persistentSettings.checkForUpdates
                text: qsTr("Check for updates periodically") + translationManager.emptyString
            }

            MoneroComponents.CheckBox {
                checked: persistentSettings.autosave
                onClicked: persistentSettings.autosave = !persistentSettings.autosave
                text: qsTr("Autosave") + translationManager.emptyString
            }

            MoneroComponents.Slider {
                Layout.fillWidth: true
                Layout.leftMargin: 35
                Layout.rightMargin: 8
                visible: persistentSettings.autosave
                from: 1
                stepSize: 1
                to: 60
                value: persistentSettings.autosaveMinutes
                text: "%1 %2 %3".arg(qsTr("Every")).arg(value).arg(qsTr("minute(s)")) + translationManager.emptyString
                onMoved: persistentSettings.autosaveMinutes = value
            }

            MoneroComponents.CheckBox {
                checked: persistentSettings.askStopLocalNode
                onClicked: persistentSettings.askStopLocalNode = !persistentSettings.askStopLocalNode
                text: qsTr("Ask to stop local node during program exit") + translationManager.emptyString
            }
        }
    }

    Component.onCompleted: {
        console.log('SettingsLayout loaded');
    }
}

