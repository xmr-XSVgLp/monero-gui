import QtQuick
import QtQuick.Layouts
import moneroComponents.Clipboard 1.0

import "../components" as MoneroComponents

// External IPs of the local node: monerod's peers (get_connections), refreshed every 3 s while on screen.
// Click an IP to copy it. Used in Security > Connections and Settings > Node / Network.
ColumnLayout {
    id: peersView
    spacing: 10

    property bool showTitle: false
    property var peers: []
    property bool loading: false
    property string error: ""

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color goodColor: dark ? "#5FD08F" : "#1E8E4E"
    readonly property color warnColor: dark ? "#FFC23D" : "#A86F00"
    readonly property color badColor: dark ? "#FF5C5C" : "#C62828"

    // the IP the peers see: which way monerod goes out
    readonly property string routeText: {
        var sync = persistentSettings.netSync === "nym" ? "NymVPN" : persistentSettings.netSync === "i2p" ? "I2P" : "Tor";
        var tx = persistentSettings.netTx === "i2p" ? ".i2p" : persistentSettings.netTx === "both" ? ".onion / .i2p" : ".onion";
        return qsTr("through %1 (--proxy); your transactions only to %2 peers").arg(sync).arg(tx) + translationManager.emptyString;
    }


    function load() {
        loading = true;
        oshelper.nodeRpc(appWindow.localDaemonAddress, "", "/json_rpc", "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_connections\"}", 8000,
                         function(ok, ms, body, err) {
            loading = false;
            if (!ok) {
                peers = [];
                error = qsTr("The local node does not answer (%1).").arg(err) + translationManager.emptyString;
                return;
            }
            try {
                var c = JSON.parse(body).result.connections || [];
                c.sort(function(a, b) { return (b.live_time || 0) - (a.live_time || 0); });
                peers = c;
                error = "";
            } catch (e) {
                peers = [];
                error = qsTr("Unexpected answer from the local node.") + translationManager.emptyString;
            }
        });
    }

    // flag emoji from a 2-letter country code (regional indicator letters)
    function flag(cc) {
        if (!cc || cc.length !== 2) return "";
        return String.fromCodePoint(0x1F1E6 + cc.charCodeAt(0) - 65, 0x1F1E6 + cc.charCodeAt(1) - 65);
    }

    // .onion / .i2p peers have no IP or country: show a short name (full one copied on click)
    function anonNet(host) {
        if (/\.onion$/i.test(host)) return "TOR";
        if (/\.i2p$/i.test(host)) return "I2P";
        return "";
    }
    function shortHost(host) {
        return anonNet(host) !== "" && host.length > 22 ? host.slice(0, 8) + "…" + host.slice(-12) : host;
    }

    function liveTime(s) {
        if (s >= 3600) return Math.floor(s / 3600) + " h " + Math.floor((s % 3600) / 60) + " min";
        if (s >= 60) return Math.floor(s / 60) + " min";
        return s + " s";
    }

    Timer {
        id: peersTimer
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: peersView.visible && !persistentSettings.useRemoteNode && appWindow.daemonRunning
        onTriggered: if (!peersView.loading) peersView.load()
    }

    Clipboard { id: peerClipboard }

    MoneroComponents.TextPlain {
        visible: peersView.showTitle
        text: qsTr("External IPs of the local node") + translationManager.emptyString
        font.family: MoneroComponents.Style.fontMonoMedium.name
        font.pixelSize: 12
        font.letterSpacing: 1
        color: MoneroComponents.Style.defaultFontColor
        themeTransition: false
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
            text: peersView.error !== "" ? peersView.error
                  : peersView.peers.length > 0 ? qsTr("%1 peers connected now. They see the IP monerod leaves with: %2.").arg(peersView.peers.length).arg(peersView.routeText) + translationManager.emptyString
                  : qsTr("The Monero nodes monerod is connected to right now, with their IP and port.") + translationManager.emptyString
        }
        // live indicator (refreshes every 3 s while shown)
        Row {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: peersView.error !== "" ? peersView.badColor : peersView.goodColor
                SequentialAnimation on opacity {
                    running: peersTimer.running
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1.0; duration: 700 }
                }
            }
            MoneroComponents.TextPlain {
                text: qsTr("LIVE") + translationManager.emptyString
                font.family: MoneroComponents.Style.fontMonoMedium.name
                font.pixelSize: 11
                font.letterSpacing: 2
                color: peersView.error !== "" ? peersView.badColor : peersView.goodColor
                themeTransition: false
            }
        }
    }

    Repeater {
        model: peersView.peers.slice(0, 40)
        delegate: RowLayout {
            Layout.fillWidth: true
            spacing: 14
            // click: copy the IP
            MoneroComponents.TextPlain {
                id: peerIp
                readonly property string ip: modelData.host || modelData.ip || "?"
                readonly property string net: peersView.anonNet(ip)
                Layout.preferredWidth: 200
                Layout.maximumWidth: 200
                elide: Text.ElideMiddle
                // hidden-service peers come without a port in get_connections
                text: peersView.shortHost(ip) + (modelData.port && modelData.port !== "0" ? ":" + modelData.port : "")
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                font.underline: ipArea.containsMouse
                color: ipArea.containsMouse ? peersView.goodColor : MoneroComponents.Style.defaultFontColor
                themeTransition: false
                MouseArea {
                    id: ipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        peerClipboard.setText(peerIp.ip);
                        appWindow.showStatusMessage((peerIp.net !== "" ? qsTr("Address copied: %1") : qsTr("IP copied: %1")).arg(peerIp.ip) + translationManager.emptyString, 3);
                    }
                }
            }
            // country from the offline GeoIP base (oshelper.geoIpReady re-reads it once the base is loaded)
            // hidden service: no IP, so no location; the network's logo and name instead of the flag
            Row {
                readonly property string cc: peerIp.net !== "" ? "" : (oshelper.geoIpReady, oshelper.ipCountry(peerIp.ip))
                Layout.preferredWidth: 56
                spacing: 4
                MoneroComponents.NetIcon {
                    visible: peerIp.net !== ""
                    net: peerIp.net === "I2P" ? "i2p" : "tor"
                    anchors.verticalCenter: parent.verticalCenter
                }
                MoneroComponents.TextPlain {
                    anchors.verticalCenter: parent.verticalCenter
                    text: peerIp.net !== "" ? peerIp.net : parent.cc !== "" ? peersView.flag(parent.cc) + " " + parent.cc : "—"
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: peerIp.net === "TOR" ? "#B07CFF" : peerIp.net === "I2P" ? (MoneroComponents.Style.blackTheme ? "#5EC8FF" : "#1F6FA8")
                           : MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                }
            }
            MoneroComponents.TextPlain {
                Layout.preferredWidth: 60
                text: modelData.incoming ? "IN" : "OUT"
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                color: modelData.incoming ? peersView.warnColor : MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: (modelData.state || "") + " · " + qsTr("block %1").arg(modelData.height || 0) + " · " + peersView.liveTime(modelData.live_time || 0) + translationManager.emptyString
                font.family: MoneroComponents.Style.fontMonoRegular.name
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
        }
    }

    MoneroComponents.TextPlain {
        visible: peersView.peers.length > 0
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 11
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: oshelper.geoIpReady
              ? qsTr("Countries from the offline DB-IP base (IP Geolocation by DB-IP): the IPs are not sent anywhere.") + translationManager.emptyString
                + (peersView.peers.some(function(p) { return peersView.anonNet(p.host || "") !== ""; })
                   ? " " + qsTr(".onion peers are Tor hidden services: they have no public IP or location (that is the point). Click to copy the full address.") + translationManager.emptyString : "")
              : qsTr("Countries are not available: this build does not include the offline GeoIP base.") + translationManager.emptyString
    }
}
