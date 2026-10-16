import QtQuick

// "Decrypt" text effect: when `source` changes, `output` shows random digits that
// lock into the real value from left to right. Bind a Text's text to `output`.
Item {
    id: fx
    property string source: ""
    property string output: source
    property int frames: 18
    property int frame: 0
    visible: false

    function scramble(ch) {
        if (/[0-9?]/.test(ch))
            return String(Math.floor(Math.random() * 10));
        if (/[A-Za-z]/.test(ch))
            return "ABCDEF0123456789".charAt(Math.floor(Math.random() * 16));
        return ch;
    }

    function render() {
        var s = fx.source, out = "";
        var locked = Math.floor(s.length * fx.frame / fx.frames);
        for (var i = 0; i < s.length; ++i)
            out += i < locked ? s.charAt(i) : scramble(s.charAt(i));
        fx.output = out;
    }

    onSourceChanged: {
        fx.frame = 0;
        render();
        ticker.restart();
    }

    Timer {
        id: ticker
        interval: 38
        repeat: true
        onTriggered: {
            fx.frame += 1;
            if (fx.frame >= fx.frames) {
                stop();
                fx.output = fx.source;
            } else {
                fx.render();
            }
        }
    }
}
