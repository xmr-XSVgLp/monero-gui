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


// Security page (Wallet+ > Security): tabs for the app's connections, the node manager, extreme privacy and
// the security center. The tabs share the helpers below (route, colours, status rows).

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents
import "security"

ColumnLayout {
    id: securityPage
    spacing: 0
    property string tab: "Connections"
    readonly property int securityHeight: navbar.height * 3 + tabArea.height

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color goodColor: dark ? "#5FD08F" : "#1E8E4E"
    readonly property color warnColor: dark ? "#FFC23D" : "#A86F00"
    readonly property color badColor: dark ? "#FF5C5C" : "#C62828"
    readonly property color offColor: MoneroComponents.Style.dimmedFontColor
    readonly property color blue: dark ? "#6CB8FF" : "#1565C0"

    // how the app's own requests leave right now: { kind: nym | proxy | direct | blocked, text, color }
    readonly property var route: {
        var p = persistentSettings.getProxyAddress();
        if (p === "socks5://127.0.0.1:0")
            return { kind: "blocked", text: qsTr("Blocked: nothing goes out") + translationManager.emptyString, color: badColor };
        if (p === "")
            return { kind: "direct", text: qsTr("Direct: your real IP") + translationManager.emptyString, color: warnColor };
        var a = p.replace(/^socks5:\/\//, "");
        if (appWindow.nymVpnProxyUp() && a === persistentSettings.nymVpnSocksAddress)
            return { kind: "nym", text: qsTr("NymVPN mixnet (%1)").arg(a) + translationManager.emptyString, color: goodColor };
        return { kind: "proxy", text: qsTr("SOCKS5 proxy %1").arg(a) + translationManager.emptyString, color: goodColor };
    }
    // the proxy for requests made from this page ("" = direct); null while everything is blocked
    function proxyForRequests() {
        var p = persistentSettings.getProxyAddress();
        if (p === "socks5://127.0.0.1:0")
            return null;
        return p.replace(/^socks5:\/\//, "");
    }

    function openSettings(tab) {
        middlePanel.settingsView.settingsStateViewState = tab;
        appWindow.showPageRequest("Settings");
        middlePanel.flickable.contentY = 0;
    }

    function onPageCompleted() {
        var v = tabArea.currentView();
        if (v && typeof v.onPageCompleted === "function")
            v.onPageCompleted();
    }

    MoneroComponents.Navbar {
        id: navbar
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: height
        Layout.bottomMargin: height

        MoneroComponents.NavbarItem {
            active: securityPage.tab === "Connections"
            text: qsTr("Connections") + translationManager.emptyString
            onSelected: securityPage.tab = "Connections"
        }
        MoneroComponents.NavbarItem {
            active: securityPage.tab === "Nodes"
            text: qsTr("Nodes") + translationManager.emptyString
            onSelected: securityPage.tab = "Nodes"
        }
        MoneroComponents.NavbarItem {
            active: securityPage.tab === "Privacy"
            text: qsTr("Extreme privacy") + translationManager.emptyString
            onSelected: securityPage.tab = "Privacy"
        }
        MoneroComponents.NavbarItem {
            active: securityPage.tab === "Center"
            text: qsTr("Security center") + translationManager.emptyString
            onSelected: securityPage.tab = "Center"
        }
    }

    Item {
        id: tabArea
        Layout.fillWidth: true
        Layout.preferredHeight: currentView() ? currentView().implicitHeight : 0
        height: Layout.preferredHeight

        function currentView() {
            return securityPage.tab === "Connections" ? connectionsTab
                 : securityPage.tab === "Nodes" ? nodesTab
                 : securityPage.tab === "Privacy" ? privacyTab : centerTab;
        }

        SecurityConnections { id: connectionsTab; anchors.left: parent.left; anchors.right: parent.right; visible: securityPage.tab === "Connections" }
        SecurityNodes { id: nodesTab; anchors.left: parent.left; anchors.right: parent.right; visible: securityPage.tab === "Nodes" }
        SecurityPrivacy { id: privacyTab; anchors.left: parent.left; anchors.right: parent.right; visible: securityPage.tab === "Privacy" }
        SecurityCenter { id: centerTab; anchors.left: parent.left; anchors.right: parent.right; visible: securityPage.tab === "Center" }
    }

    onTabChanged: {
        middlePanel.flickable.contentY = 0;
        var v = tabArea.currentView();
        if (v && typeof v.onPageCompleted === "function")
            v.onPageCompleted();
    }
}
