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


// Network icon shared by the NYM / TOR / I2P panels and the Network configuration buttons:
// nym = three nested rings (green), tor = onion bulb (purple), i2p = the official I2P mark
// (two rows of four dots in green, yellow and red).

import QtQuick

import "." as MoneroComponents

Canvas {
    id: icon
    property string net: "tor"
    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color nymGreen: dark ? "#3DDC84" : "#2E7D4A"
    readonly property color torPurple: dark ? "#B48CFF" : "#6B3FA0"
    width: net === "i2p" ? 22 : 16
    height: net === "i2p" ? 12 : 16
    implicitWidth: width
    implicitHeight: height
    onNetChanged: requestPaint()
    onDarkChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (net === "i2p") {
            var g = "#60AB60", y = "#FFC434", r = "#E15647";
            var rows = [[g, y, g, r], [y, r, y, g]];
            for (var row = 0; row < 2; ++row)
                for (var col = 0; col < 4; ++col) {
                    ctx.fillStyle = rows[row][col];
                    ctx.beginPath();
                    ctx.arc(2.75 + col * 5.5, 3 + row * 6, 2.5, 0, 2 * Math.PI);
                    ctx.fill();
                }
        } else if (net === "nym") {
            ctx.strokeStyle = nymGreen;
            ctx.lineWidth = 1.3;
            for (var rr = 7; rr >= 2; rr -= 2.5) {
                ctx.beginPath();
                ctx.arc(8, 8.5, rr, 0, 2 * Math.PI);
                ctx.stroke();
            }
            ctx.fillStyle = nymGreen;
            ctx.beginPath();
            ctx.arc(8, 8.5, 1.2, 0, 2 * Math.PI);
            ctx.fill();
        } else {
            ctx.strokeStyle = torPurple;
            ctx.lineWidth = 1.3;
            var cloves = [[5, 10], [11, 10], [8, 8.5]];
            for (var i = 0; i < cloves.length; ++i) {
                ctx.beginPath();
                ctx.ellipse(cloves[i][0] - 3.2, cloves[i][1] - 4.5, 6.4, 9);
                ctx.stroke();
            }
            ctx.beginPath();
            ctx.moveTo(8, 4); ctx.lineTo(8, 1);
            ctx.stroke();
        }
    }
}
