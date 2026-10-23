import QtQuick

import "../components" as MoneroComponents

// Raised title bar button with a coloured picture: "wallet" (brown leather wallet, switch wallet) or
// "safe" (steel safe with a gold dial, accounts of this seed). Bevelled frame, lighter on hover, pressed
// look while held or while its menu is open.
Item {
    id: root
    property string kind: "wallet"
    property bool active: false          // its menu is open
    property string badge: ""            // small number in the corner (open wallets)
    readonly property bool hovered: area.containsMouse
    readonly property bool down: area.pressed || active
    readonly property bool dark: MoneroComponents.Style.blackTheme
    signal clicked()

    implicitWidth: 40
    implicitHeight: 30

    // shadow under the button
    Rectangle {
        x: 0; y: 2
        width: parent.width; height: parent.height
        radius: 6
        color: root.dark ? "#B0000000" : "#40000000"
        visible: !root.down
    }

    Rectangle {
        id: face
        x: 0; y: root.down ? 1 : 0
        width: parent.width; height: parent.height
        radius: 6
        border.width: 1
        border.color: root.hovered || root.active ? (root.kind === "wallet" ? "#E0A262" : "#C9CED6")
                                                  : (root.dark ? "#5A4A3A" : "#8C7A66")
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.down ? (root.dark ? "#1E1A16" : "#CFC6BB")
                                                           : root.hovered ? (root.dark ? "#4A4038" : "#FFFFFF")
                                                                          : (root.dark ? "#3A322B" : "#F4EEE7") }
            GradientStop { position: 1.0; color: root.down ? (root.dark ? "#2A241E" : "#DDD4C9")
                                                           : (root.dark ? "#1C1815" : "#D9CFC3") }
        }
        // top highlight line
        Rectangle {
            x: 4; y: 1
            width: parent.width - 8; height: 1
            color: root.dark ? "#30FFFFFF" : "#B0FFFFFF"
            visible: !root.down
        }

        Canvas {
            id: pic
            anchors.centerIn: parent
            width: 28; height: 23
            property var deps: [root.kind, root.hovered]
            onDepsChanged: requestPaint()
            function rr(ctx, x, y, w, h, r) {
                ctx.beginPath();
                ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
                ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
                ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r); ctx.closePath();
            }
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 22, height / 18);   // drawn on a 22 x 18 grid
                var lift = root.hovered ? 1.12 : 1.0;
                function shade(hex, f) {
                    var n = parseInt(hex.slice(1), 16);
                    var r = Math.min(255, Math.round((n >> 16) * f)), g = Math.min(255, Math.round(((n >> 8) & 255) * f)),
                        b = Math.min(255, Math.round((n & 255) * f));
                    return "rgb(" + r + "," + g + "," + b + ")";
                }
                if (root.kind === "wallet") {
                    // card sticking out of the top (Monero orange)
                    ctx.fillStyle = shade("#FF6600", lift);
                    rr(ctx, 4, 1, 12, 7, 1.5); ctx.fill();
                    // leather body
                    var g = ctx.createLinearGradient(0, 4, 0, 17);
                    g.addColorStop(0, shade("#A8713F", lift)); g.addColorStop(1, shade("#6B4321", lift));
                    ctx.fillStyle = g;
                    rr(ctx, 1, 4, 20, 13, 3); ctx.fill();
                    ctx.strokeStyle = "#3E250F"; ctx.lineWidth = 1;
                    rr(ctx, 1.5, 4.5, 19, 12, 2.5); ctx.stroke();
                    // stitching
                    ctx.strokeStyle = shade("#E2B98A", lift); ctx.lineWidth = 0.8;
                    ctx.setLineDash ? ctx.setLineDash([1.5, 1.2]) : null;
                    rr(ctx, 3, 6, 16, 9, 1.5); ctx.stroke();
                    ctx.setLineDash ? ctx.setLineDash([]) : null;
                    // strap with a gold stud
                    ctx.fillStyle = shade("#5A3519", lift);
                    rr(ctx, 13, 8, 9, 6, 2); ctx.fill();
                    ctx.strokeStyle = "#3E250F"; ctx.stroke();
                    ctx.fillStyle = shade("#F2C14E", lift);
                    ctx.beginPath(); ctx.arc(17.5, 11, 1.7, 0, 2 * Math.PI); ctx.fill();
                } else {
                    // steel safe
                    var s = ctx.createLinearGradient(0, 1, 0, 16);
                    s.addColorStop(0, shade("#AEB6BF", lift)); s.addColorStop(1, shade("#5B636C", lift));
                    ctx.fillStyle = s;
                    rr(ctx, 2, 1, 18, 14, 2.5); ctx.fill();
                    ctx.strokeStyle = "#2B3036"; ctx.lineWidth = 1;
                    rr(ctx, 2.5, 1.5, 17, 13, 2); ctx.stroke();
                    // door
                    ctx.strokeStyle = shade("#3A4048", 1); ctx.lineWidth = 0.9;
                    rr(ctx, 4.5, 3.5, 13, 9, 1.5); ctx.stroke();
                    // feet
                    ctx.fillStyle = "#2B3036";
                    ctx.fillRect(4, 15, 3, 2); ctx.fillRect(15, 15, 3, 2);
                    // gold dial with ticks
                    ctx.fillStyle = shade("#F2C14E", lift);
                    ctx.beginPath(); ctx.arc(10, 8, 3.2, 0, 2 * Math.PI); ctx.fill();
                    ctx.strokeStyle = "#8A6514"; ctx.lineWidth = 0.8; ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(10, 8); ctx.lineTo(10, 5.6); ctx.stroke();
                    // handle
                    ctx.strokeStyle = shade("#F2C14E", lift); ctx.lineWidth = 1.6;
                    ctx.beginPath(); ctx.moveTo(15.2, 6); ctx.lineTo(15.2, 10); ctx.stroke();
                }
            }
        }
    }

    // number of open wallets
    Rectangle {
        visible: root.badge !== ""
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -7
        anchors.topMargin: -7
        width: Math.max(18, badgeText.implicitWidth + 8)
        height: 18
        radius: 9
        // fixed gold disc with a black number: readable with every theme and palette
        color: "#F2C14E"
        border.width: 1.5
        border.color: root.dark ? "#1C1815" : "#5A3519"
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.badge
            color: "#000000"
            font.pixelSize: 12
            font.bold: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
