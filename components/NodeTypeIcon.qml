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

// Node type icons drawn in the neon line style: "local" = this computer's node (a server with the
// chain of blocks stored in it), "remote" = a node somewhere on the network (globe with links)
Canvas {
    id: icon
    property string kind: "local"
    property color color: MoneroComponents.Style.defaultFontColor
    property color accent: "#3DDC84"
    property bool lit: false
    implicitWidth: 34
    implicitHeight: 34
    onColorChanged: requestPaint()
    onAccentChanged: requestPaint()
    onLitChanged: requestPaint()
    onKindChanged: requestPaint()

    onPaint: {
        var c = getContext("2d");
        c.reset();
        var w = width, h = height, s = Math.min(w, h) / 34;
        c.save();
        c.translate((w - 34 * s) / 2, (h - 34 * s) / 2);
        c.scale(s, s);
        c.lineJoin = "round";
        c.lineCap = "round";
        var line = Qt.rgba(color.r, color.g, color.b, lit ? 1 : 0.75);
        var acc = Qt.rgba(accent.r, accent.g, accent.b, lit ? 1 : 0.6);
        if (kind === "local") {
            // server: two units with drive lights, below it three linked blocks
            c.strokeStyle = line;
            c.lineWidth = 1.6;
            c.strokeRect(5, 3, 24, 8);
            c.strokeRect(5, 13, 24, 8);
            c.fillStyle = acc;
            c.fillRect(8, 6, 3, 2);
            c.fillRect(8, 16, 3, 2);
            c.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.45);
            c.beginPath(); c.moveTo(15, 7); c.lineTo(26, 7); c.moveTo(15, 17); c.lineTo(26, 17); c.stroke();
            // chain of blocks
            c.strokeStyle = acc;
            c.lineWidth = 1.4;
            for (var i = 0; i < 3; i++) c.strokeRect(4 + i * 10, 25, 6, 6);
            c.beginPath(); c.moveTo(10, 28); c.lineTo(14, 28); c.moveTo(20, 28); c.lineTo(24, 28); c.stroke();
        } else {
            // globe
            c.strokeStyle = line;
            c.lineWidth = 1.6;
            c.beginPath(); c.arc(13, 13, 10, 0, Math.PI * 2); c.stroke();
            c.lineWidth = 1.1;
            c.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.5);
            c.beginPath(); c.ellipse(8.5, 3, 9, 20); c.stroke();
            c.beginPath(); c.moveTo(3, 13); c.lineTo(23, 13); c.moveTo(5, 8); c.lineTo(21, 8); c.moveTo(5, 18); c.lineTo(21, 18); c.stroke();
            // remote server linked to it
            c.strokeStyle = acc;
            c.lineWidth = 1.4;
            c.setLineDash([2, 2]);
            c.beginPath(); c.moveTo(20, 20); c.lineTo(23, 23); c.stroke();
            c.setLineDash([]);
            c.fillStyle = MoneroComponents.Style.blackTheme ? "#0C130E" : "#EEF1EE";
            c.fillRect(23, 23, 9, 9);
            c.strokeRect(23, 23, 9, 9);
            c.fillStyle = acc;
            c.fillRect(25, 26, 2, 2);
        }
        c.restore();
    }
}
