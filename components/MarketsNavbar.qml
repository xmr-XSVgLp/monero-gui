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

import "../components" as MoneroComponents

// Tabs at the top of the Markets and Swaps pages: one page each, switched like the Settings tabs
MoneroComponents.Navbar {
    property string current: "Trading"     // middle panel state of the page showing it
    Layout.alignment: Qt.AlignHCenter
    Layout.bottomMargin: 6

    MoneroComponents.NavbarItem {
        active: current === "Trading"
        text: qsTr("Markets") + translationManager.emptyString
        onSelected: if (!active) appWindow.showPageRequest("Trading")
    }
    MoneroComponents.NavbarItem {
        active: current === "Swaps"
        text: qsTr("Swaps") + translationManager.emptyString
        onSelected: if (!active) appWindow.showPageRequest("Swaps")
    }
    MoneroComponents.NavbarItem {
        active: current === "SwapsNoKyc"
        text: "Swaps No-KYC"
        onSelected: if (!active) appWindow.showPageRequest("SwapsNoKyc")
    }
}
