import QtQuick

import "../components" as MoneroComponents

// Short digital glitch over `target`: displaced copies of horizontal slices plus
// neon noise bars. Call trigger(). Place it as a sibling above the target.
Item {
    id: fx
    property Item target: null
    property int duration: 420
    property color accent: MoneroComponents.Style.orange
    property int frame: 0
    readonly property int frames: Math.max(1, Math.round(duration / 45))
    visible: false
    enabled: false

    function trigger() {
        if (!target || target.width <= 0 || target.height <= 0) return;
        var p = target.mapToItem(fx, 0, 0);
        area.x = p.x; area.y = p.y;
        area.width = target.width; area.height = target.height;
        frame = 0;
        shuffle();
        visible = true;
        ticker.restart();
    }

    function shuffle() {
        var h = area.height, k = 1 - frame / frames;
        for (var i = 0; i < slices.count; ++i) {
            var s = slices.itemAt(i);
            var sh = 4 + Math.random() * 40;
            s.sy = Math.random() * Math.max(1, h - sh);
            s.sh = sh;
            s.dx = (Math.random() - 0.5) * 60 * k;
            s.visible = Math.random() < 0.75;
        }
        for (var j = 0; j < bars.count; ++j) {
            var b = bars.itemAt(j);
            b.y = Math.random() * h;
            b.height = 1 + Math.random() * 4;
            b.x = Math.random() * area.width * 0.5;
            b.width = area.width * (0.2 + Math.random() * 0.8);
            b.opacity = (0.15 + Math.random() * 0.45) * k;
        }
    }

    Timer {
        id: ticker
        interval: 45
        repeat: true
        onTriggered: {
            fx.frame += 1;
            if (fx.frame >= fx.frames) {
                stop();
                fx.visible = false;
            } else {
                fx.shuffle();
            }
        }
    }

    Item {
        id: area
        clip: true

        Repeater {
            id: slices
            model: 7
            ShaderEffectSource {
                property real sy: 0
                property real sh: 10
                property real dx: 0
                sourceItem: fx.visible ? fx.target : null
                live: true
                hideSource: false
                x: dx
                y: sy
                width: area.width
                height: sh
                sourceRect: Qt.rect(0, sy, area.width, sh)

                Rectangle {
                    anchors.fill: parent
                    color: fx.accent
                    opacity: 0.12
                }
            }
        }

        Repeater {
            id: bars
            model: 9
            Rectangle {
                color: index % 3 === 0 ? (MoneroComponents.Style.blackTheme ? "#FF2BD6" : "#B0007F") : fx.accent
            }
        }
    }
}
