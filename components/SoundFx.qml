import QtQuick
import QtMultimedia

// Optional UI sounds. Loaded through a Loader in main.qml, so if Qt Multimedia
// is missing the app keeps working, just silently.
Item {
    function play(name) {
        var s = { "click": click, "boot": boot, "send": send, "alert": alert, "glitch": glitch }[name];
        if (s) s.play();
    }
    SoundEffect { id: click;  source: "qrc:///images/sounds/click.wav";  volume: 0.35 }
    SoundEffect { id: boot;   source: "qrc:///images/sounds/boot.wav";   volume: 0.5 }
    SoundEffect { id: send;   source: "qrc:///images/sounds/send.wav";   volume: 0.5 }
    SoundEffect { id: alert;  source: "qrc:///images/sounds/alert.wav";  volume: 0.5 }
    SoundEffect { id: glitch; source: "qrc:///images/sounds/glitch.wav"; volume: 0.25 }
}
