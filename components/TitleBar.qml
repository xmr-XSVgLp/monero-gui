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
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC

import FontAwesome

import "." as MoneroComponents
import "effects/" as MoneroEffects

Rectangle {
    id: root
    property int mouseX: 0
    property bool customDecorations: persistentSettings.customDecorations
    property bool showMinimizeButton: true
    property bool showMaximizeButton: true
    property bool showCloseButton: true
    property string walletName: ""
    property alias priceChip: priceChip
    property string deviceLabel: ""        // Trezor name, shown after the wallet name
    property bool hardwareWallet: false    // Trezor icon instead of the safe
    property bool removableWallet: false   // opened from a USB / SD drive: purple USB stick instead of the safe

    height: {
        if(!persistentSettings.customDecorations) return 0;
        return 50;
    }

    z: 1
    color: "transparent"

    signal closeClicked
    signal maximizeClicked
    signal minimizeClicked
    signal languageClicked
    signal closeWalletClicked
    signal lockWalletClicked

    state: "default"
    states: [
        State {
            name: "default";
            PropertyChanges { target: btnCloseWallet; visible: true}
            PropertyChanges { target: btnLockWallet; visible: true}
            PropertyChanges { target: btnLanguageToggle; visible: true}
        }, State {
            // show only theme switcher and window controls
            name: "essentials";
            PropertyChanges { target: btnCloseWallet; visible: false}
            PropertyChanges { target: btnLockWallet; visible: false}
            PropertyChanges { target: btnLanguageToggle; visible: false}
        }
    ]

    MoneroEffects.GradientBackground {
        anchors.fill: parent
        duration: 300
        fallBackColor: MoneroComponents.Style.middlePanelBackgroundColor
        initialStartColor: MoneroComponents.Style.titleBarBackgroundGradientStart
        initialStopColor: MoneroComponents.Style.titleBarBackgroundGradientStop
        blackColorStart: MoneroComponents.Style._b_titleBarBackgroundGradientStart
        blackColorStop: MoneroComponents.Style._b_titleBarBackgroundGradientStop
        whiteColorStart: MoneroComponents.Style._w_titleBarBackgroundGradientStart
        whiteColorStop: MoneroComponents.Style._w_titleBarBackgroundGradientStop
        start: Qt.point(width, 0)
        end: Qt.point(0, 0)
    }

    // neon separator under the bar
    Rectangle {
        id: titleBarNeonLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        z: parent.z + 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: MoneroComponents.Style.orange }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: 0.6
    }

    // status chip of the title bar (privacy status)
    component Chip: Item {
        id: chip
        property string label: ""
        property color dot: "#8C8C8C"
        property string tip: ""
        property bool blink: false
        property string page: ""      // page opened on click; Settings > Node / Network when empty
        width: chipRow.implicitWidth + 18
        height: 24
        MoneroComponents.NeonFrame {
            anchors.fill: parent
            cut: 5
            accent: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
            lineOpacity: chipArea.containsMouse ? 0.7 : 0.3
            fillColor: accent
            fillOpacity: chipArea.containsMouse ? 0.08 : 0.03
            ticks: false
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 3.5
                color: chip.dot
                SequentialAnimation on opacity {
                    running: chip.blink
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                    onRunningChanged: if (!running) parent.opacity = 1
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }
        MoneroComponents.Tooltip {
            id: chipTip
            anchors.fill: parent
            text: chip.tip
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: chipTip.tooltipPopup.open()
            onExited: chipTip.tooltipPopup.close()
            onClicked: {
                chipTip.tooltipPopup.close();
                if (chip.page !== "") {
                    appWindow.showPageRequest(chip.page);
                    middlePanel.flickable.contentY = 0;
                    return;
                }
                middlePanel.settingsView.settingsStateViewState = "Node";
                appWindow.showPageRequest("Settings");
            }
        }
    }

    RowLayout {
        z: parent.z + 2
        spacing: 0
        anchors.fill: parent

        // lock wallet
        Rectangle {
            id: btnLockWallet
            color: "transparent"
            Layout.preferredWidth: parent.height
            Layout.preferredHeight: parent.height

            Text {
                text: FontAwesome.lock
                font.family: FontAwesome.fontFamilySolid
                font.pixelSize: 16
                color: MoneroComponents.Style.defaultFontColor
                font.styleName: "Solid"
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.75
            }

            MoneroComponents.Tooltip {
                id: btnLockWalletTooltip
                anchors.fill: parent
                text: qsTr("Lock this wallet") + translationManager.emptyString
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = MoneroComponents.Style.titleBarButtonHoverColor
                    btnLockWalletTooltip.tooltipPopup.open()
                }
                onExited: {
                    parent.color = "transparent"
                    btnLockWalletTooltip.tooltipPopup.close()
                }
                onClicked: root.lockWalletClicked()
            }
        }

        // collapse sidebar
        Rectangle {
            id: btnCloseWallet
            color: "transparent"
            Layout.preferredWidth: parent.height
            Layout.preferredHeight: parent.height


            Text {
                text: FontAwesome.signOutAlt
                font.family: FontAwesome.fontFamilySolid
                font.pixelSize: 16
                color: MoneroComponents.Style.defaultFontColor
                font.styleName: "Solid"
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.75
            }

            MoneroComponents.Tooltip {
                id: btnCloseWalletTooltip
                anchors.fill: parent
                text: qsTr("Close this wallet and return to main menu") + translationManager.emptyString
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = MoneroComponents.Style.titleBarButtonHoverColor
                    btnCloseWalletTooltip.tooltipPopup.open()
                }
                onExited: {
                    parent.color = "transparent"
                    btnCloseWalletTooltip.tooltipPopup.close()
                }
                onClicked: root.closeWalletClicked()
            }
        }

        // language selection
        Rectangle {
            id: btnLanguageToggle
            color: "transparent"
            Layout.preferredWidth: parent.height
            Layout.preferredHeight: parent.height

            Text {
                text: FontAwesome.globe
                font.family: FontAwesome.fontFamilySolid
                font.pixelSize: 16
                color: MoneroComponents.Style.defaultFontColor
                font.styleName: "Solid"
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.75
            }

            MoneroComponents.Tooltip {
                id: btnLanguageToggleTooltip
                anchors.fill: parent
                text: qsTr("Change language") + translationManager.emptyString
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = MoneroComponents.Style.titleBarButtonHoverColor
                    btnLanguageToggleTooltip.tooltipPopup.open()
                }
                onExited: {
                    parent.color = "transparent"
                    btnLanguageToggleTooltip.tooltipPopup.close()
                }
                onClicked: root.languageClicked()
            }
        }

        // switch theme
        Rectangle {
            color: "transparent"
            Layout.preferredWidth: parent.height
            Layout.preferredHeight: parent.height

            Text {
                text: FontAwesome.moonO
                font.family: MoneroComponents.Style.blackTheme ? FontAwesome.fontFamilySolid : FontAwesome.fontFamily
                font.styleName: MoneroComponents.Style.blackTheme ? "Solid" : "Regular"
                font.pixelSize: 15
                color: MoneroComponents.Style.defaultFontColor
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.75
            }

            MoneroComponents.Tooltip {
                id: btnSwitchThemeTooltip
                anchors.fill: parent
                text: qsTr("Theme") + translationManager.emptyString
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = MoneroComponents.Style.titleBarButtonHoverColor
                    btnSwitchThemeTooltip.tooltipPopup.open()
                }
                onExited: {
                    parent.color = "transparent"
                    btnSwitchThemeTooltip.tooltipPopup.close()
                }
                onClicked: {
                    btnSwitchThemeTooltip.tooltipPopup.close();
                    themePopup.visible ? themePopup.close() : themePopup.open();
                }
            }

            // theme list: dark / light and the colour palette (saved in persistentSettings)
            QQC.Popup {
                id: themePopup
                x: 0   // opens to the right: the button sits near the left edge of the window
                y: parent.height + 4
                width: 230
                padding: 10
                closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutsideParent

                function setTheme(palette, dark) {
                    MoneroComponents.Style.themePalette = palette;
                    MoneroComponents.Style.blackTheme = dark;
                    persistentSettings.themePalette = palette;
                    persistentSettings.blackTheme = dark;
                }

                function setPastel(pastel) {
                    MoneroComponents.Style.pastel = pastel;
                    persistentSettings.themePastel = pastel;
                }

                background: MoneroComponents.NeonFrame {
                    cut: 8
                    accent: MoneroComponents.Style.orange
                    lineOpacity: 0.9
                    glow: 0.3
                    fillColor: MoneroComponents.Style.blackTheme ? "#0C0E0D" : "#EEF0EE"
                    fillOpacity: 0.97
                    ticks: false
                }
                contentItem: ColumnLayout {
                    spacing: 4
                    Text {
                        text: qsTr("THEME") + translationManager.emptyString
                        color: MoneroComponents.Style.orange
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        Layout.bottomMargin: 4
                    }
                    // dark / light
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        spacing: 6
                        Repeater {
                            model: [{ dark: true, label: qsTr("Dark") + translationManager.emptyString, icon: FontAwesome.moonO },
                                    { dark: false, label: qsTr("Light") + translationManager.emptyString, icon: "\uf185" }]
                            Rectangle {
                                readonly property bool current: MoneroComponents.Style.blackTheme === modelData.dark
                                Layout.fillWidth: true
                                height: 28
                                radius: 3
                                color: current ? MoneroComponents.Style.c("#2E00FF41")
                                       : modeArea.containsMouse ? Qt.rgba(0.5, 0.5, 0.5, 0.12) : "transparent"
                                border.width: 1
                                border.color: current ? MoneroComponents.Style.orange : Qt.rgba(0.5, 0.5, 0.5, 0.35)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.icon
                                        font.family: FontAwesome.fontFamily
                                        font.pixelSize: 12
                                        color: MoneroComponents.Style.defaultFontColor
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font.family: MoneroComponents.Style.fontRegular.name
                                        font.pixelSize: 12
                                        color: MoneroComponents.Style.defaultFontColor
                                    }
                                }
                                MouseArea {
                                    id: modeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: themePopup.setTheme(MoneroComponents.Style.themePalette, modelData.dark)
                                }
                            }
                        }
                    }
                    // neon / matte (soft colours)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        spacing: 6
                        Repeater {
                            model: [{ pastel: false, label: qsTr("Neon") + translationManager.emptyString, icon: "\uf0e7" },
                                    { pastel: true, label: qsTr("Matte") + translationManager.emptyString, icon: "\uf043" }]
                            Rectangle {
                                readonly property bool current: MoneroComponents.Style.pastel === modelData.pastel
                                Layout.fillWidth: true
                                height: 28
                                radius: 3
                                color: current ? MoneroComponents.Style.c("#2E00FF41")
                                       : toneArea.containsMouse ? Qt.rgba(0.5, 0.5, 0.5, 0.12) : "transparent"
                                border.width: 1
                                border.color: current ? MoneroComponents.Style.orange : Qt.rgba(0.5, 0.5, 0.5, 0.35)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.icon
                                        font.family: FontAwesome.fontFamily
                                        font.pixelSize: 12
                                        color: MoneroComponents.Style.defaultFontColor
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font.family: MoneroComponents.Style.fontRegular.name
                                        font.pixelSize: 12
                                        color: MoneroComponents.Style.defaultFontColor
                                    }
                                }
                                MouseArea {
                                    id: toneArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: themePopup.setPastel(modelData.pastel)
                                }
                            }
                        }
                    }
                    Repeater {
                        model: MoneroComponents.Style.paletteOrder
                        Rectangle {
                            readonly property var pal: MoneroComponents.Style.palettes[modelData]
                            readonly property bool current: MoneroComponents.Style.themePalette === modelData
                            Layout.fillWidth: true
                            height: 30
                            radius: 3
                            color: palArea.containsMouse && !current ? Qt.rgba(0.5, 0.5, 0.5, 0.12) : "transparent"
                            border.width: current ? 1 : 0
                            border.color: pal.mono ? MoneroComponents.Style.defaultFontColor : pal.color
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: pal.color
                                    // black / white swatch: half black with a grey ring so it shows on both themes
                                    border.width: pal.mono ? 1 : 0
                                    border.color: "#808080"
                                    Item {
                                        visible: !!pal.mono
                                        x: 6
                                        width: 6
                                        height: 12
                                        clip: true
                                        Rectangle {
                                            x: -6
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: "#000000"
                                            border.width: 1
                                            border.color: "#808080"
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: pal.name
                                    color: MoneroComponents.Style.defaultFontColor
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.pixelSize: 13
                                }
                                Text {
                                    visible: current
                                    text: "✓"
                                    color: pal.mono ? MoneroComponents.Style.defaultFontColor : pal.color
                                    font.pixelSize: 13
                                }
                            }
                            MouseArea {
                                id: palArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: themePopup.setTheme(modelData, MoneroComponents.Style.blackTheme)
                            }
                        }
                    }
                }
            }
        }

        Item {
            // make dummy space when hiding buttons when titlebar
            // state is 'essentials' in order for the
            // monero logo to still be centered
            Layout.preferredWidth: parent.height * 2  // amount of buttons we hide
            Layout.preferredHeight: parent.height
            visible: root.state == "essentials"
        }

        // XMR price in mBTC with the 24 h trend (hover: every currency), only with prices on
        MoneroComponents.PriceChip {
            id: priceChip
            visible: walletName.length > 0 && typeof appWindow !== "undefined" && persistentSettings.fiatPriceEnabled
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: priceChip.implicitWidth
            Layout.preferredHeight: priceChip.implicitHeight
            Layout.minimumWidth: priceChip.implicitWidth
            Layout.leftMargin: 10
        }

        // monero logo
        Item {
            visible: walletName.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height

            Image {
                id: imgLogo
                width: 265
                height: 32

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                source: MoneroComponents.Style.titleBarLogoSource
                visible: {
                    if(GraphicsInfo.api === GraphicsInfo.Software) return true;
                    if(!MoneroComponents.Style.blackTheme) return true;
                    return false;
                }
            }

            MultiEffect {
                visible: GraphicsInfo.api !== GraphicsInfo.Software && MoneroComponents.Style.blackTheme
                anchors.fill: imgLogo
                source: imgLogo
                saturation: 0.0
            }
        }

        Item {
            visible: walletName.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height

            Row {
                id: walletTitle
                anchors.centerIn: parent
                spacing: 10
                readonly property color accent: root.removableWallet ? (MoneroComponents.Style.blackTheme ? "#A66BFF" : "#6B2FD6")
                                                                     : MoneroComponents.Style.orange
                readonly property color ink: MoneroComponents.Style.blackTheme ? "#FFFFFF" : "#0B1F0F"
                readonly property int nameMax: Math.max(40, parent.width - 170)

                MoneroComponents.SafeIcon {
                    visible: !root.hardwareWallet && !root.removableWallet
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22

                    // seed accounts menu
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seedAccountsPopup.visible ? seedAccountsPopup.close() : seedAccountsPopup.open()
                    }
                }

                MoneroComponents.UsbIcon {
                    visible: !root.hardwareWallet && root.removableWallet
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    accent: walletTitle.accent

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seedAccountsPopup.visible ? seedAccountsPopup.close() : seedAccountsPopup.open()
                    }
                }

                // accounts of this seed: wallet + passphrase 1, 2, 3... (main.qml seedAccounts)
                QQC.Popup {
                    id: seedAccountsPopup
                    x: 0
                    y: walletTitle.height + 14
                    width: 330
                    padding: 12
                    closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

                    property var accounts: []
                    property var parked: ({})
                    function key(p) { return String(p).replace(/\.keys$/, ""); }
                    function refresh() {
                        accounts = appWindow.seedAccounts();
                        var m = {};
                        walletManager.parkedWallets().forEach(function(w) { m[key(w.path)] = w.height; });
                        parked = m;
                    }
                    function stateText(path, current) {
                        if (current) return qsTr("open") + translationManager.emptyString;
                        var h = parked[key(path)];
                        if (h === undefined) return qsTr("closed") + translationManager.emptyString;
                        if (appWindow.daemonTarget > 1 && h >= appWindow.daemonTarget - 1)
                            return qsTr("in background · synced") + translationManager.emptyString;
                        return qsTr("in background · syncing %1").arg(h) + translationManager.emptyString;
                    }
                    onOpened: refresh()
                    Timer {
                        interval: 2000
                        repeat: true
                        running: seedAccountsPopup.visible
                        onTriggered: seedAccountsPopup.refresh()
                    }

                    background: MoneroComponents.NeonFrame {
                        cut: 8
                        accent: MoneroComponents.Style.c("#00FF41")
                        lineOpacity: 0.9
                        glow: 0.3
                        fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#EEF1EE"
                        fillOpacity: 0.97
                        ticks: false
                    }

                    contentItem: ColumnLayout {
                        spacing: 4
                        Text {
                            text: qsTr("ACCOUNTS OF THIS SEED") + translationManager.emptyString
                            color: MoneroComponents.Style.c("#00FF41")
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 11
                            font.letterSpacing: 1
                            Layout.bottomMargin: 4
                        }
                        Repeater {
                            model: seedAccountsPopup.accounts
                            Rectangle {
                                readonly property bool current: modelData.path === persistentSettings.wallet_path
                                Layout.fillWidth: true
                                height: 40
                                radius: 3
                                color: accArea.containsMouse && !current ? MoneroComponents.Style.c("#2600FF41") : "transparent"
                                border.width: current ? 1 : 0
                                border.color: MoneroComponents.Style.c("#5500FF41")
                                MouseArea {
                                    id: accArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: current ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (current) return;
                                        seedAccountsPopup.close();
                                        appWindow.openSeedAccount(modelData.path);
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    Text {
                                        text: current ? "●" : "○"
                                        color: MoneroComponents.Style.c("#00FF41")
                                        font.pixelSize: 10
                                    }
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: (modelData.offset === 0
                                                   ? qsTr("Account 0 · main")
                                                   : qsTr("Account %1 · passphrase \"%1\"").arg(modelData.offset)) + translationManager.emptyString
                                            color: MoneroComponents.Style.defaultFontColor
                                            font.family: MoneroComponents.Style.fontRegular.name
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: seedAccountsPopup.stateText(modelData.path, current)
                                            color: MoneroComponents.Style.dimmedFontColor
                                            font.family: MoneroComponents.Style.fontMonoRegular.name
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            height: 1
                            color: MoneroComponents.Style.c("#3300FF41")
                        }
                        Rectangle {
                            visible: appWindow.canCreateSeedAccount()
                            Layout.fillWidth: true
                            height: 30
                            radius: 3
                            color: newArea.containsMouse ? MoneroComponents.Style.c("#2600FF41") : "transparent"
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                text: "+  " + qsTr("New account (passphrase \"%1\")").arg(
                                          seedAccountsPopup.accounts.length > 0 ? seedAccountsPopup.accounts[seedAccountsPopup.accounts.length - 1].offset + 1 : 1)
                                      + translationManager.emptyString
                                color: MoneroComponents.Style.defaultFontColor
                                font.family: MoneroComponents.Style.fontRegular.name
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: newArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    seedAccountsPopup.close();
                                    appWindow.createSeedAccount();
                                }
                            }
                        }
                        Text {
                            visible: !appWindow.canCreateSeedAccount()
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: (appWindow.viewOnly
                                   ? qsTr("View-only wallets have no seed: new accounts can't be created.")
                                   : qsTr("Open account 0 to create new accounts.")) + translationManager.emptyString
                            color: MoneroComponents.Style.dimmedFontColor
                            font.pixelSize: 11
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            wrapMode: Text.WordWrap
                            text: qsTr("Each account is a separate wallet (address starting with 4) restored from this seed with the seed offset passphrase shown. To recover it elsewhere you need the seed and that passphrase. Accounts share this wallet's password and sync on their own.") + translationManager.emptyString
                            color: MoneroComponents.Style.dimmedFontColor
                            font.pixelSize: 10
                        }
                    }
                }

                MoneroComponents.TrezorIcon {
                    visible: root.hardwareWallet
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 24

                    // opens Wallet+ > Trezor
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appWindow.showPageRequest("Trezor");
                            middlePanel.flickable.contentY = 0;
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "["
                    color: walletTitle.accent
                    font.family: MoneroComponents.Style.fontMonoBold.name
                    font.pixelSize: 19
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, walletTitle.nameMax)
                    elide: Text.ElideRight
                    text: walletName
                    color: walletTitle.ink
                    font.family: MoneroComponents.Style.fontMonoMedium.name
                    font.pixelSize: 16
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "]"
                    color: walletTitle.accent
                    font.family: MoneroComponents.Style.fontMonoBold.name
                    font.pixelSize: 19
                }

                // Trezor name, in brackets like the wallet name
                Row {
                    visible: root.deviceLabel.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "["
                        color: walletTitle.accent
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 19
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, walletTitle.nameMax / 2)
                        elide: Text.ElideRight
                        text: root.deviceLabel
                        color: walletTitle.ink
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 16
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "]"
                        color: walletTitle.accent
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 19
                    }
                }

                // quick wallet switch (main.qml unlockedWallets)
                Rectangle {
                    id: walletSwitchButton
                    // seed accounts (wallets_passphrase) stay in their wallet's own menu, not here
                    readonly property var wallets: appWindow.unlockedWallets.filter(function(w) { return appWindow.seedAccountOffset(w.path) === 0; })
                    visible: persistentSettings.quickWalletSwitch && typeof appWindow.currentWallet !== "undefined" && appWindow.currentWallet !== null
                    anchors.verticalCenter: parent.verticalCenter
                    width: switchRow.implicitWidth + 14
                    height: 22
                    radius: 3
                    color: switchArea.containsMouse || walletSwitchPopup.visible ? MoneroComponents.Style.c("#2600FF41") : "#99000000"
                    border.width: 1
                    border.color: switchArea.containsMouse || walletSwitchPopup.visible ? MoneroComponents.Style.c("#00FF41") : MoneroComponents.Style.c("#5500FF41")

                    Row {
                        id: switchRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "⇄"
                            color: MoneroComponents.Style.c("#00FF41")
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            visible: walletSwitchButton.wallets.length > 1
                            text: walletSwitchButton.wallets.length
                            color: "#FFFFFF"
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: switchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (!walletSwitchPopup.visible) switchTip.tooltipPopup.open()
                        onExited: switchTip.tooltipPopup.close()
                        onClicked: {
                            switchTip.tooltipPopup.close();
                            walletSwitchPopup.visible ? walletSwitchPopup.close() : walletSwitchPopup.open();
                        }
                    }

                    MoneroComponents.Tooltip {
                        id: switchTip
                        text: qsTr("Switch wallet") + translationManager.emptyString
                    }

                    QQC.Popup {
                        id: walletSwitchPopup
                        x: (parent.width - width) / 2
                        y: parent.height + 12
                        width: 250
                        padding: 10
                        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutsideParent

                        // wallets kept loaded in the background: path (without .keys) -> synced height
                        property var parked: ({})
                        function key(p) { return String(p).replace(/\.keys$/, ""); }
                        function refreshParked() {
                            var m = {};
                            walletManager.parkedWallets().forEach(function(w) { m[key(w.path)] = w.height; });
                            parked = m;
                        }
                        function stateText(path, current) {
                            if (current) return qsTr("open") + translationManager.emptyString;
                            var h = parked[key(path)];
                            if (h === undefined) return qsTr("closed · reopens on switch") + translationManager.emptyString;
                            if (appWindow.daemonTarget > 1 && h >= appWindow.daemonTarget - 1)
                                return qsTr("in background · synced") + translationManager.emptyString;
                            return qsTr("in background · syncing %1").arg(h) + translationManager.emptyString;
                        }
                        onOpened: refreshParked()
                        Timer {
                            interval: 2000
                            repeat: true
                            running: walletSwitchPopup.visible
                            onTriggered: walletSwitchPopup.refreshParked()
                        }
                        background: MoneroComponents.NeonFrame {
                            cut: 8
                            accent: MoneroComponents.Style.c("#00FF41")
                            lineOpacity: 0.9
                            glow: 0.3
                            fillColor: MoneroComponents.Style.blackTheme ? "#0C130E" : "#EEF1EE"
                            fillOpacity: 0.97
                            ticks: false
                        }
                        contentItem: ColumnLayout {
                            spacing: 4
                            Text {
                                text: qsTr("UNLOCKED WALLETS") + translationManager.emptyString
                                color: MoneroComponents.Style.c("#00FF41")
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 11
                                font.letterSpacing: 1
                                Layout.bottomMargin: 4
                            }
                            Repeater {
                                model: walletSwitchButton.wallets
                                Rectangle {
                                    // also "current" while one of its seed accounts is open
                                    readonly property bool current: appWindow.seedBasePath(modelData.path) === appWindow.seedBasePath(persistentSettings.wallet_path)
                                    Layout.fillWidth: true
                                    height: 40
                                    radius: 3
                                    color: rowArea.containsMouse && !current ? MoneroComponents.Style.c("#2600FF41") : "transparent"
                                    border.width: current ? 1 : 0
                                    border.color: MoneroComponents.Style.c("#5500FF41")
                                    MouseArea {
                                        id: rowArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: modelData.path === persistentSettings.wallet_path ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: {
                                            // from one of its accounts: back to the wallet itself
                                            if (modelData.path === persistentSettings.wallet_path) return;
                                            walletSwitchPopup.close();
                                            appWindow.switchWallet(modelData.path);
                                        }
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 4
                                        spacing: 6
                                        Text {
                                            text: current ? "●" : "○"
                                            color: MoneroComponents.Style.c("#00FF41")
                                            font.pixelSize: 10
                                        }
                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                width: parent.width
                                                text: modelData.name
                                                elide: Text.ElideRight
                                                color: MoneroComponents.Style.defaultFontColor
                                                font.family: MoneroComponents.Style.fontRegular.name
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                width: parent.width
                                                text: walletSwitchPopup.stateText(modelData.path, current)
                                                elide: Text.ElideRight
                                                color: MoneroComponents.Style.dimmedFontColor
                                                font.family: MoneroComponents.Style.fontMonoRegular.name
                                                font.pixelSize: 10
                                            }
                                        }
                                        Text {
                                            visible: !current
                                            text: "✕"
                                            color: forgetArea.containsMouse ? "#FF5A5A" : MoneroComponents.Style.dimmedFontColor
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 20
                                            horizontalAlignment: Text.AlignHCenter
                                            MouseArea {
                                                id: forgetArea
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: appWindow.forgetUnlockedWallet(modelData.path)
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                height: 1
                                color: MoneroComponents.Style.c("#3300FF41")
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                radius: 3
                                color: openArea.containsMouse ? MoneroComponents.Style.c("#2600FF41") : "transparent"
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "+  " + qsTr("Open another wallet…") + translationManager.emptyString
                                    color: MoneroComponents.Style.defaultFontColor
                                    font.family: MoneroComponents.Style.fontRegular.name
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    id: openArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        walletSwitchPopup.close();
                                        appWindow.showWizard();
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                wrapMode: Text.WordWrap
                                text: qsTr("Unlocked wallets stay loaded and keep syncing in the background. Passwords stay only in memory and are forgotten when the wallet locks or the app quits.") + translationManager.emptyString
                                color: MoneroComponents.Style.dimmedFontColor
                                font.pixelSize: 10
                            }
                        }
                    }
                }


            }
        }

        // privacy status: Nym, node and Trezor, only with a wallet open. Click: Settings > Node / Network
        Row {
            id: privacyStatus
            visible: walletName.length > 0 && typeof appWindow !== "undefined"
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 12
            spacing: 6

            readonly property bool nymUp: persistentSettings.netWallet === "nym" ? appWindow.nymVpnProxyUp() : appWindow.torProxyUp()
            // the wallet's network (Network configuration) is not up yet: its requests wait
            readonly property bool nymWorking: !nymUp
            function netName(n) { return n === "nym" ? "Nym" : n === "i2p" ? "I2P" : n === "both" ? "Tor + I2P" : "Tor"; }
            readonly property bool remote: persistentSettings.useRemoteNode
            readonly property string nodeAddress: remote ? remoteNodesModel.currentRemoteNode().address : "127.0.0.1 (monerod)"

            // one NODE chip: node connection + Nym state in the dot and tooltip
            Chip {
                label: qsTr("NODE") + translationManager.emptyString
                dot: appWindow.disconnected ? "#FF5A5A"
                     : privacyStatus.nymWorking ? "#F5B83D"
                     : "#3DDC84"
                blink: !appWindow.disconnected && privacyStatus.nymWorking
                tip: (privacyStatus.remote ? qsTr("Remote node: %1").arg(privacyStatus.nodeAddress) : qsTr("Local node: %1").arg(privacyStatus.nodeAddress))
                     + " · " + (appWindow.disconnected ? qsTr("disconnected") : qsTr("connected"))
                     + "<br>" + qsTr("Wallet: %1 · Sync: %2 · Transactions: %3")
                                    .arg(privacyStatus.netName(persistentSettings.netWallet))
                                    .arg(privacyStatus.netName(persistentSettings.netSync))
                                    .arg(privacyStatus.netName(persistentSettings.netTx))
                     + "<br>" + (privacyStatus.nymUp ? qsTr("The wallet's network is connected.")
                                                     : qsTr("The wallet's network is connecting: its requests wait, nothing goes out directly."))
                     + translationManager.emptyString
            }

            Chip {
                visible: root.hardwareWallet
                label: "TREZOR"
                page: "Trezor"
                dot: "#3DDC84"
                tip: qsTr("Hardware wallet: %1. The keys never leave the device.").arg(root.deviceLabel !== "" ? root.deviceLabel : "Trezor") + translationManager.emptyString
            }
        }

        // minimize
        Rectangle {
            color: "transparent"
            visible: root.showMinimizeButton
            Layout.preferredWidth: 45  // narrow window buttons, more room for the title
            Layout.preferredHeight: parent.height

            MoneroEffects.ImageMask {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                height: 3
                width: 15
                image: MoneroComponents.Style.titleBarMinimizeSource
                color: MoneroComponents.Style.defaultFontColor
                fontAwesomeFallbackIcon: FontAwesome.minus
                fontAwesomeFallbackSize: 18
                fontAwesomeFallbackOpacity: MoneroComponents.Style.blackTheme ? 0.8 : 0.6
                opacity: 0.75
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.color = MoneroComponents.Style.titleBarButtonHoverColor
                onExited: parent.color = "transparent"
                onClicked: root.minimizeClicked();
            }
        }

        // maximize
        Rectangle {
            id: test
            visible: root.showMaximizeButton
            color: "transparent"
            Layout.preferredWidth: 45  // narrow window buttons, more room for the title
            Layout.preferredHeight: parent.height

            Image {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                source: MoneroComponents.Style.titleBarFullscreenSource
                sourceSize.width: 16
                sourceSize.height: 16
                smooth: true
                mipmap: true
                opacity: 0.75
                rotation: appWindow.visibility === Window.Maximized ? 180 : 0
            }

            MouseArea {
                id: buttonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.color = MoneroComponents.Style.titleBarButtonHoverColor
                onExited: parent.color = "transparent"
                onClicked: root.maximizeClicked();
            }
        }

        // close
        Rectangle {
            visible: root.showCloseButton
            color: "transparent"
            Layout.preferredWidth: 45  // narrow window buttons, more room for the title
            Layout.preferredHeight: parent.height

            MoneroEffects.ImageMask {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                height: 16
                width: 16
                image: MoneroComponents.Style.titleBarCloseSource
                color: MoneroComponents.Style.defaultFontColor
                fontAwesomeFallbackIcon: FontAwesome.times
                fontAwesomeFallbackSize: 21
                fontAwesomeFallbackOpacity: MoneroComponents.Style.blackTheme ? 0.8 : 0.6
                opacity: 0.75
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.color = MoneroComponents.Style.titleBarButtonHoverColor
                onExited: parent.color = "transparent"
                onClicked: root.closeClicked();
            }
        }
    }

    Rectangle {
        z: parent.z + 3
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: MoneroComponents.Style.blackTheme ? 1 : 1
        color: MoneroComponents.Style.titleBarBackgroundBorderColor

        MoneroEffects.ColorTransition {
            targetObj: parent
            blackColor: MoneroComponents.Style._b_titleBarBackgroundBorderColor
            whiteColor: MoneroComponents.Style._w_titleBarBackgroundBorderColor
        }
    }

    MouseArea {
        enabled: persistentSettings.customDecorations
        anchors.fill: parent
        propagateComposedEvents: true
        onPressed: appWindow.startSystemMove()
        onDoubleClicked: root.maximizeClicked()
    }
}
