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
import "." as MoneroComponents

// Subtle cypherpunk background for list rows: neon wash, glowing side bar, faint scanline on hover.
Item {
    id: fx
    property bool selected: false
    property bool hovered: false
    readonly property color accent: MoneroComponents.Style.orange

    Rectangle {
        anchors.fill: parent
        visible: fx.selected || fx.hovered
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(fx.accent.r, fx.accent.g, fx.accent.b, fx.selected ? 0.14 : 0.07) }
            GradientStop { position: 0.6; color: Qt.rgba(fx.accent.r, fx.accent.g, fx.accent.b, fx.selected ? 0.04 : 0.02) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // selected: neon bar with a soft glow band
    Rectangle {
        visible: fx.selected
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 10
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(fx.accent.r, fx.accent.g, fx.accent.b, 0.35) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        Rectangle {
            width: 2
            height: parent.height
            color: fx.accent
        }
    }

    // thin neon line under the selected row
    Rectangle {
        visible: fx.selected
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width * 0.6
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(fx.accent.r, fx.accent.g, fx.accent.b, 0.5) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: fx.hovered
        Rectangle {
            id: scan
            width: 60
            height: parent.height
            opacity: 0.1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: fx.accent }
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on x {
                from: -scan.width
                to: fx.width
                duration: 1800
                loops: Animation.Infinite
                running: fx.hovered
            }
        }
    }
}
