import QtQuick

import "../components" as MoneroComponents

// Falling glyph columns. Cheap: one Text per column, moved by the scene graph.
Item {
    id: rain
    property color accent: MoneroComponents.Style.orange
    property color headColor: MoneroComponents.Style.blackTheme ? "#E8FFE8" : "#003B00"
    property int fontPx: 14
    property int colW: 18
    property bool running: visible && opacity > 0
    readonly property string glyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789XMR$#"
    clip: true

    function glyph() {
        return glyphs.charAt(Math.floor(Math.random() * glyphs.length));
    }

    function hex2(a) {
        var v = Math.max(0, Math.min(255, Math.round(a * 255))).toString(16);
        return v.length < 2 ? "0" + v : v;
    }

    function rgbHex(c) {
        return hex2(c.r) + hex2(c.g) + hex2(c.b);
    }

    Repeater {
        id: columns
        model: rain.width > 0 ? Math.ceil(rain.width / rain.colW) : 0

        Item {
            id: col
            x: index * rain.colW
            width: rain.colW
            height: rain.height
            property var chars: []
            property int len: 10

            function build() {
                var base = rain.rgbHex(rain.accent), head = rain.rgbHex(rain.headColor);
                var s = "";
                for (var i = 0; i < chars.length; ++i) {
                    var a = i === chars.length - 1 ? 1.0 : 0.15 + 0.75 * (i + 1) / chars.length;
                    var c = i === chars.length - 1 ? head : base;
                    s += (i ? "<br>" : "") + "<font color=\"#" + rain.hex2(a) + c + "\">" + chars[i] + "</font>";
                }
                trail.text = s;
            }

            property real speed: 60     // px per second
            property real wait: 0       // seconds before falling again

            function reset() {
                len = 8 + Math.floor(Math.random() * 20);
                var a = [];
                for (var i = 0; i < len; ++i) a.push(rain.glyph());
                chars = a;
                build();
                speed = 45 + Math.random() * 110;
                wait = Math.random() * 5;
                trail.y = -trail.height;
            }

            function step(dt) {
                if (wait > 0) { wait -= dt; return; }
                trail.y += speed * dt;
                if (trail.y > rain.height) reset();
            }

            Component.onCompleted: {
                reset();
                // start mid-screen so the first frame is already full
                trail.y = Math.random() * rain.height - trail.height;
                wait = 0;
            }

            function mutate() {
                if (!chars.length) return;
                var a = chars;
                a[Math.floor(Math.random() * a.length)] = rain.glyph();
                a[a.length - 1] = rain.glyph();
                chars = a;
                build();
            }

            Text {
                id: trail
                y: -height
                width: rain.colW
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.StyledText
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: rain.fontPx
                lineHeightMode: Text.FixedHeight
                lineHeight: rain.fontPx + 3
            }

        }
    }

    Timer {
        id: frameTimer
        interval: 33
        repeat: true
        running: rain.running
        property double last: 0
        onRunningChanged: last = 0
        onTriggered: {
            var now = Date.now();
            var dt = last > 0 ? Math.min(0.1, (now - last) / 1000) : 0.033;
            last = now;
            for (var i = 0; i < columns.count; ++i) {
                var it = columns.itemAt(i);
                if (it) it.step(dt);
            }
        }
    }

    Timer {
        interval: 110
        repeat: true
        running: rain.running
        onTriggered: {
            var n = columns.count;
            for (var k = 0; k < 4 && n > 0; ++k) {
                var it = columns.itemAt(Math.floor(Math.random() * n));
                if (it) it.mutate();
            }
        }
    }
}
