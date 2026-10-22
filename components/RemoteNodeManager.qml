import QtQuick
import QtQuick.Layouts
import moneroComponents.NetworkType 1.0

import "../components" as MoneroComponents
import FontAwesome

// Remote node manager (Security > Nodes and Settings > Node / Network > Node): measures latency,
// availability, version and stability, with favourites, edit / add (remoteNodeDialog) and manual
// rotation. The score does not depend on speed alone. It is the same list as the wallet's remote
// nodes (remoteNodesModel): adding, editing or removing here changes that list too; the measurements
// and favourites live in persistentSettings.securityNodes.
ColumnLayout {
    id: tab
    spacing: 16
    property bool showNotes: true          // intro and the notes at the bottom

    readonly property bool dark: MoneroComponents.Style.blackTheme
    readonly property color goodColor: dark ? "#5FD08F" : "#1E8E4E"
    readonly property color warnColor: dark ? "#FFC23D" : "#A86F00"
    readonly property color badColor: dark ? "#FF5C5C" : "#C62828"
    readonly property color offColor: MoneroComponents.Style.dimmedFontColor
    readonly property color blue: dark ? "#6CB8FF" : "#1565C0"

    // the wallet's route to a node, like the wallet itself: .i2p through I2P, .onion through Tor,
    // others through the wallet's network (Network configuration); null = blocked
    function proxyFor(address) {
        var p;
        if (appWindow.isI2pNode(address)) p = appWindow.i2pProxyUp() ? "socks5://" + oshelper.i2pClient.address : "socks5://127.0.0.1:0";
        else if (appWindow.isOnionNode(address)) p = appWindow.torProxyUp() ? "socks5://" + oshelper.torClient.address : "socks5://127.0.0.1:0";
        else p = persistentSettings.getProxyAddress();
        if (p === "socks5://127.0.0.1:0") return null;
        return p.replace(/^socks5:\/\//, "");
    }
    readonly property var route: {
        var p = persistentSettings.getProxyAddress();
        if (p === "socks5://127.0.0.1:0")
            return { text: qsTr("Blocked: nothing goes out") + translationManager.emptyString, color: badColor };
        var a = p.replace(/^socks5:\/\//, "");
        if (appWindow.torProxyUp() && a === oshelper.torClient.address)
            return { text: qsTr("Tor network (%1)").arg(a) + translationManager.emptyString, color: goodColor };
        if (appWindow.nymVpnProxyUp() && a === persistentSettings.nymVpnSocksAddress)
            return { text: qsTr("NymVPN mixnet (%1)").arg(a) + translationManager.emptyString, color: goodColor };
        return { text: qsTr("SOCKS5 proxy %1").arg(a) + translationManager.emptyString, color: goodColor };
    }

    function modelIndex(address) {
        for (var i = 0; i < remoteNodesModel.count; ++i)
            if (remoteNodesModel.get(i).address === address) return i;
        return -1;
    }

    readonly property var suggested: ["xmr-node.cakewallet.com:18081", "node.sethforprivacy.com:18089",
                                      "nodes.hashvault.pro:18081", "node.monerodevs.org:18089"]
    property var nodes: []
    property bool measuring: false
    property int measureIndex: -1
    property bool onlyFavorites: false
    property string message: ""
    property color messageColor: MoneroComponents.Style.dimmedFontColor
    // MRL spy-node ban list packaged in the app: {path, entries, title}
    property var banList: ({ path: "", entries: 0, title: "" })

    function load() {
        var list = [];
        try { list = JSON.parse(persistentSettings.securityNodes) || []; } catch (e) { list = []; }
        // one entry per address
        var seen = {};
        list = list.filter(function(n) { if (!n || seen[n.address]) return false; seen[n.address] = true; return true; });
        // the wallet's saved list is not loaded yet: show the measurements only, sync later
        if (!remoteNodesModel.ready) {
            nodes = list;
            return;
        }
        for (var j = 0; j < remoteNodesModel.count; ++j) {
            var a = remoteNodesModel.get(j).address;
            if (a && !seen[a]) { list.push({ address: a, favorite: false, mine: true, samples: [] }); seen[a] = true; }
        }
        if (list.length === 0)
            for (var k = 0; k < suggested.length; ++k)
                list.push({ address: suggested[k], favorite: false, mine: false, samples: [] });
        // one list: every node here is also a remote node of the wallet
        loading = true;
        for (var m = 0; m < list.length; ++m)
            if (modelIndex(list[m].address) < 0)
                remoteNodesModel.appendIfNotExists({ address: list[m].address, username: "", password: "", trusted: false });
        loading = false;
        nodes = list;
        banList = oshelper.banListInfo();
    }

    property bool loading: false
    property bool saving: false
    function save() {
        saving = true;
        persistentSettings.securityNodes = JSON.stringify(nodes);
        saving = false;
        nodes = nodes.slice();
    }
    // the other manager (Security / Settings) or the wallet's list changed
    Connections {
        target: persistentSettings
        function onSecurityNodesChanged() { if (!tab.saving) tab.load(); }
    }
    Connections {
        target: remoteNodesModel
        function onCountChanged() { if (!tab.loading && remoteNodesModel.ready) tab.load(); }
        function onReadyChanged() { tab.load(); }
    }

    function removeNode(index) {
        var address = nodes[index].address;
        var i = modelIndex(address);
        if (i >= 0 && remoteNodesModel.count <= 1) {
            message = qsTr("The wallet needs at least one remote node: add another one first.") + translationManager.emptyString;
            messageColor = warnColor;
            return;
        }
        nodes.splice(index, 1);
        save();
        if (i >= 0) {
            loading = true;
            remoteNodesModel.removeSelectNextIfNeeded(i);
            loading = false;
        }
    }

    function editNode(index) {
        var old = nodes[index].address;
        var i = modelIndex(old);
        if (i < 0) i = remoteNodesModel.appendIfNotExists({ address: old, username: "", password: "", trusted: false });
        remoteNodeDialog.edit(remoteNodesModel.get(i), function(remoteNode) {
            remoteNodesModel.set(i, remoteNode);
            for (var k = 0; k < nodes.length; ++k)
                if (nodes[k].address === old && remoteNode.address !== old) {
                    nodes[k].address = remoteNode.address;
                    nodes[k].samples = [];
                    delete nodes[k].ban;
                }
            save();
            if (i === remoteNodesModel.selected)
                remoteNodesModel.applyRemoteNode(i);
        });
    }

    function stats(n) {
        var s = n.samples || [];
        var ok = s.filter(function(x) { return x.ok; });
        var r = { count: s.length, availability: s.length ? ok.length / s.length : 0, ms: 0, jitter: 0,
                  height: 0, version: "", last: s.length ? s[s.length - 1] : null };
        if (ok.length) {
            var sum = 0;
            for (var i = 0; i < ok.length; ++i) sum += ok[i].ms;
            r.ms = Math.round(sum / ok.length);
            var v = 0;
            for (var j = 0; j < ok.length; ++j) v += Math.pow(ok[j].ms - r.ms, 2);
            r.jitter = Math.round(Math.sqrt(v / ok.length));
            r.height = ok[ok.length - 1].height || 0;
            r.version = ok[ok.length - 1].version || "";
        }
        return r;
    }

    // highest height and version seen among all nodes, to judge if one is behind
    readonly property var reference: {
        var h = 0, v = "";
        for (var i = 0; i < nodes.length; ++i) {
            var s = stats(nodes[i]);
            if (s.height > h) h = s.height;
            if (compareVersions(s.version, v) > 0) v = s.version;
        }
        return { height: h, version: v };
    }

    function compareVersions(a, b) {
        var x = (a || "").split(/[.-]/), y = (b || "").split(/[.-]/);
        for (var i = 0; i < Math.max(x.length, y.length); ++i) {
            var p = parseInt(x[i] || "0"), q = parseInt(y[i] || "0");
            if (isNaN(p)) p = 0;
            if (isNaN(q)) q = 0;
            if (p !== q) return p - q;
        }
        return 0;
    }

    // 0-100: availability 35 %, up to date 25 %, version 15 %, stability 15 %, speed only 10 %
    function score(n) {
        var s = stats(n);
        if (s.count === 0) return -1;
        if (banState(n) === "spy") return 0;
        if (s.availability === 0) return 0;
        var fresh = reference.height === 0 ? 1 : Math.max(0, 1 - Math.max(0, reference.height - s.height) / 10);
        var version = reference.version === "" ? 1 : (compareVersions(s.version, reference.version) >= 0 ? 1
                    : s.version.split(".").slice(0, 2).join(".") === reference.version.split(".").slice(0, 2).join(".") ? 0.6 : 0.2);
        var stability = s.ms === 0 ? 1 : Math.max(0, 1 - s.jitter / Math.max(s.ms, 1));
        var speed = Math.max(0, Math.min(1, 1 - (s.ms - 300) / 4700));
        return Math.round(100 * (0.35 * s.availability + 0.25 * fresh + 0.15 * version + 0.15 * stability + 0.10 * speed));
    }

    function scoreColor(v) {
        return v < 0 ? tab.offColor : v >= 75 ? tab.goodColor : v >= 50 ? tab.warnColor : tab.badColor;
    }

    // "on": (almost) none of the peers it hands out is on the spy list, "off": 5 % or more are, "spy": the
    // node itself is on it, "unknown": no P2P answer (port 18080 closed) or not clear, "": not checked
    // the spy list holds IPv4 addresses only: it says nothing about .onion / .i2p nodes
    function banState(n) {
        if (appWindow.isOnionNode(n.address) || appWindow.isI2pNode(n.address)) return "";
        return n.ban ? n.ban.state : "";
    }

    function banColor(state) {
        return state === "on" ? tab.goodColor : state === "off" || state === "spy" ? tab.badColor : MoneroComponents.Style.dimmedFontColor;
    }

    function banLabel(state) {
        return (state === "on" ? qsTr("BAN LIST ✓") : state === "off" ? qsTr("NO BAN LIST")
              : state === "spy" ? qsTr("SPY NODE") : state === "unknown" ? qsTr("BAN LIST ?") : "") + translationManager.emptyString;
    }

    function banDetail(n) {
        var b = banState(n) !== "" ? n.ban : null;
        if (!b) return "";
        if (b.state === "spy") return qsTr("this node's IP is on the spy-node list") + translationManager.emptyString;
        if (b.state === "on" && b.banned === 0) return qsTr("none of its %1 peers is on the spy list").arg(b.peers) + translationManager.emptyString;
        if (b.peers > 0) return qsTr("%1 of its %2 peers are on the spy list").arg(b.banned).arg(b.peers) + translationManager.emptyString;
        return qsTr("spy list not checked (no answer on the P2P port)") + translationManager.emptyString;
    }

    // asks the node for its peer list over P2P and compares it with the packaged ban list (mainnet only)
    function checkBan(address, proxy, done) {
        if (persistentSettings.nettype != NetworkType.MAINNET || banList.entries === 0
                || appWindow.isOnionNode(address) || appWindow.isI2pNode(address)) {
            done();
            return;
        }
        oshelper.nodeBanCheck(address, proxy, 20000, function(json) {
            var r = {};
            try { r = JSON.parse(json); } catch (e) {}
            // a node that turned the list on after running a while can still hand out a few stale
            // entries of its saved peer list, so a tiny share still counts as "on"
            var share = r.peers > 0 ? r.banned / r.peers : 0;
            var state = r.selfBanned ? "spy" : !r.ok || (r.peers || 0) < 10 ? "unknown" : share < 0.02 ? "on" : share >= 0.05 ? "off" : "unknown";
            for (var i = 0; i < nodes.length; ++i)
                if (nodes[i].address === address)
                    nodes[i].ban = { t: Date.now(), state: state, peers: r.peers || 0, banned: r.banned || 0 };
            save();
            done();
        });
    }

    function isCurrent(address) {
        return persistentSettings.useRemoteNode && remoteNodesModel.currentRemoteNode().address === address;
    }

    function measure(index, all) {
        if (index >= nodes.length) {
            measuring = false;
            measureIndex = -1;
            message = qsTr("Measured through: %1").arg(route.text) + translationManager.emptyString;
            messageColor = MoneroComponents.Style.dimmedFontColor;
            return;
        }
        var address = nodes[index].address;
        var proxy = proxyFor(address);
        if (proxy === null) {
            // its network is not up: the test is skipped instead of going out another way
            var skipped = { t: Date.now(), ok: false, ms: 0, height: 0, version: "", blocked: true };
            for (var b = 0; b < nodes.length; ++b)
                if (nodes[b].address === address) nodes[b].samples = (nodes[b].samples || []).concat([skipped]).slice(-20);
            save();
            if (all) measure(index + 1, true);
            else {
                measuring = false;
                measureIndex = -1;
                message = (appWindow.remoteNodeBlockedText(address) || qsTr("No route to this node now.")) + translationManager.emptyString;
                messageColor = warnColor;
            }
            return;
        }
        measuring = true;
        measureIndex = index;
        oshelper.nodeRpc(address, proxy, "/get_info", "", 30000, function(ok, ms, body, error) {
            var sample = { t: Date.now(), ok: false, ms: ms, height: 0, version: "" };
            if (ok) {
                try {
                    var info = JSON.parse(body);
                    sample.ok = info.status === "OK" && !info.offline;
                    sample.height = info.height || 0;
                    sample.version = info.version || "";
                    sample.synced = info.synchronized === true || (info.target_height || 0) <= (info.height || 0);
                } catch (e) {}
            }
            for (var i = 0; i < nodes.length; ++i) {
                if (nodes[i].address === address) {
                    var s = (nodes[i].samples || []).concat([sample]);
                    nodes[i].samples = s.slice(-20);
                }
            }
            save();
            checkBan(address, proxy, function() {
                if (all)
                    measure(index + 1, true);
                else {
                    measuring = false;
                    measureIndex = -1;
                }
            });
        });
    }

    function use(address) {
        var i = modelIndex(address);
        if (i < 0) i = remoteNodesModel.appendIfNotExists({ address: address, username: "", password: "", trusted: false });
        remoteNodesModel.applyRemoteNode(i);
        message = qsTr("Now using %1 as remote node.").arg(address) + translationManager.emptyString;
        messageColor = tab.goodColor;
        nodes = nodes.slice();
    }

    // manual rotation: a random node among the good ones (score >= 50), not the fastest
    function rotate() {
        var pool = [];
        for (var i = 0; i < nodes.length; ++i) {
            var n = nodes[i];
            if ((onlyFavorites && !n.favorite) || isCurrent(n.address) || banState(n) === "spy" || !appWindow.remoteNodeAllowed(n.address)) continue;
            if (score(n) >= 50) pool.push(n);
        }
        // nodes known to apply the ban list go first
        var withList = pool.filter(function(x) { return banState(x) === "on"; });
        if (withList.length > 0) pool = withList;
        pool = pool.map(function(x) { return x.address; });
        if (pool.length === 0) {
            message = qsTr("No other node with a score of 50 or more. Measure the list first.") + translationManager.emptyString;
            messageColor = tab.warnColor;
            return;
        }
        use(pool[Math.floor(Math.random() * pool.length)]);
    }

    function addNode(address) {
        address = address.trim().replace(/\/+$/, "");
        if (!/^(https?:\/\/)?[A-Za-z0-9.\-\[\]:]+:\d{2,5}$/.test(address)) {
            message = qsTr("Write it as host:port, for example node.example.com:18089") + translationManager.emptyString;
            messageColor = tab.badColor;
            return false;
        }
        for (var i = 0; i < nodes.length; ++i)
            if (nodes[i].address === address) return false;
        nodes.push({ address: address, favorite: false, mine: true, samples: [] });
        save();
        loading = true;
        remoteNodesModel.appendIfNotExists({ address: address, username: "", password: "", trusted: false });
        loading = false;
        message = "";
        return true;
    }

    function onPageCompleted() {
        load();
    }

    Component.onCompleted: load()

    MoneroComponents.TextPlain {
        visible: tab.showNotes
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: qsTr("Measure the nodes through the app's current route. The score weighs availability (35 %), being up to date with the network (25 %), version (15 %) and stability (15 %); speed only counts 10 %, so a fast node that fails or lags behind does not win.") + translationManager.emptyString
    }

    MoneroComponents.SettingsCard {
        padding: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MoneroComponents.StandardButton {
                small: true
                enabled: !tab.measuring && tab.nodes.length > 0
                text: (tab.measuring ? qsTr("Measuring %1 / %2…").arg(tab.measureIndex + 1).arg(tab.nodes.length) : qsTr("Measure all")) + translationManager.emptyString
                onClicked: { tab.message = ""; tab.measure(0, true); }
            }
            MoneroComponents.StandardButton {
                small: true
                primary: false
                enabled: !tab.measuring
                text: qsTr("Rotate node") + translationManager.emptyString
                tooltip: qsTr("Switches to another node chosen at random among those with a good score") + translationManager.emptyString
                onClicked: tab.rotate()
            }
            MoneroComponents.CheckBox {
                text: qsTr("Only favourites") + translationManager.emptyString
                checked: tab.onlyFavorites
                fontSize: 13
                onClicked: tab.onlyFavorites = !tab.onlyFavorites
            }
            Item { Layout.fillWidth: true }
            MoneroComponents.TextPlain {
                text: qsTr("Route: ") + translationManager.emptyString + tab.route.text
                font.pixelSize: 12
                color: tab.route.color
                themeTransition: false
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            visible: tab.message !== ""
            wrapMode: Text.WordWrap
            text: tab.message
            font.pixelSize: 13
            color: tab.messageColor
            themeTransition: false
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: MoneroComponents.Style.dividerColor; opacity: MoneroComponents.Style.dividerOpacity }

        Repeater {
            model: tab.nodes
            delegate: RowLayout {
                id: nodeRow
                readonly property var st: tab.stats(modelData)
                readonly property int sc: tab.score(modelData)
                readonly property bool current: tab.isCurrent(modelData.address)
                // .onion without Tor, .i2p without I2P, clearnet with the wallet on Tor (main.qml remoteNodeAllowed)
                readonly property string blockedText: (persistentSettings.netWallet, persistentSettings.torEnabled, persistentSettings.i2pEnabled,
                                                       appWindow.remoteNodeBlockedText(modelData.address))
                readonly property int mi: (remoteNodesModel.count, tab.nodes, tab.modelIndex(modelData.address))
                readonly property bool trusted: mi >= 0 && remoteNodesModel.get(mi).trusted === true
                Layout.fillWidth: true
                spacing: 12
                visible: !tab.onlyFavorites || modelData.favorite

                MoneroComponents.TextPlain {
                    text: modelData.favorite ? "★" : "☆"
                    font.pixelSize: 18
                    color: modelData.favorite ? tab.warnColor : MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { tab.nodes[index].favorite = !tab.nodes[index].favorite; tab.save(); }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 26
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: tab.scoreColor(nodeRow.sc)
                    MoneroComponents.TextPlain {
                        anchors.centerIn: parent
                        text: nodeRow.sc < 0 ? "–" : nodeRow.sc
                        font.pixelSize: 13
                        font.bold: true
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        color: tab.scoreColor(nodeRow.sc)
                        themeTransition: false
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        spacing: 8
                        MoneroComponents.TextPlain {
                            text: modelData.address
                            font.pixelSize: 13
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            visible: nodeRow.current
                            text: qsTr("IN USE") + translationManager.emptyString
                            font.pixelSize: 11
                            font.bold: true
                            color: tab.goodColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            visible: nodeRow.trusted
                            text: qsTr("trusted") + translationManager.emptyString
                            font.pixelSize: 11
                            color: tab.blue
                            themeTransition: false
                        }
                        Rectangle {
                            visible: tab.banState(modelData) !== ""
                            implicitWidth: banText.implicitWidth + 12
                            implicitHeight: banText.implicitHeight + 4
                            radius: 3
                            color: "transparent"
                            border.width: 1
                            border.color: tab.banColor(tab.banState(modelData))
                            MoneroComponents.TextPlain {
                                id: banText
                                anchors.centerIn: parent
                                text: tab.banLabel(tab.banState(modelData))
                                font.pixelSize: 10
                                font.bold: true
                                color: tab.banColor(tab.banState(modelData))
                                themeTransition: false
                            }
                        }
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                        text: tab.measuring && tab.measureIndex === index ? qsTr("measuring…") + translationManager.emptyString
                              : nodeRow.blockedText !== "" ? nodeRow.blockedText
                              : nodeRow.st.count === 0 ? qsTr("not measured yet") + translationManager.emptyString
                              : [qsTr("%1 % up (%2 tests)").arg(Math.round(nodeRow.st.availability * 100)).arg(nodeRow.st.count),
                                 nodeRow.st.ms ? qsTr("%1 ms ±%2").arg(nodeRow.st.ms).arg(nodeRow.st.jitter) : "",
                                 nodeRow.st.height ? (tab.reference.height - nodeRow.st.height > 2 ? qsTr("%1 blocks behind").arg(tab.reference.height - nodeRow.st.height)
                                                                                                   : qsTr("up to date")) : "",
                                 nodeRow.st.version ? "v" + nodeRow.st.version : "",
                                 nodeRow.st.last && !nodeRow.st.last.ok ? qsTr("last test failed") : "",
                                 tab.banDetail(modelData)
                                ].filter(function(x) { return x !== ""; }).join(" · ") + translationManager.emptyString
                    }
                }

                MoneroComponents.StandardButton {
                    small: true
                    primary: false
                    enabled: !tab.measuring
                    text: qsTr("Test") + translationManager.emptyString
                    onClicked: tab.measure(index, false)
                }
                MoneroComponents.StandardButton {
                    small: true
                    enabled: !nodeRow.current && nodeRow.blockedText === ""
                    text: qsTr("Use") + translationManager.emptyString
                    onClicked: tab.use(modelData.address)
                }
                MoneroComponents.SettingsIconButton {
                    icon: FontAwesome.edit
                    tooltip: qsTr("Edit remote node") + translationManager.emptyString
                    enabled: !tab.measuring
                    onClicked: tab.editNode(index)
                }
                MoneroComponents.TextPlain {
                    text: "✕"
                    font.pixelSize: 14
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        enabled: !tab.measuring
                        onClicked: tab.removeNode(index)
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: MoneroComponents.Style.dividerColor; opacity: MoneroComponents.Style.dividerOpacity }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MoneroComponents.LineEdit {
                id: newNode
                Layout.fillWidth: true
                fontSize: 14
                placeholderFontSize: 14
                placeholderText: qsTr("Add to my list: host:port") + translationManager.emptyString
                onAccepted: if (tab.addNode(text)) text = ""
            }
            MoneroComponents.StandardButton {
                small: true
                enabled: newNode.text.trim() !== ""
                text: qsTr("Add") + translationManager.emptyString
                onClicked: if (tab.addNode(newNode.text)) newNode.text = ""
            }
            MoneroComponents.StandardButton {
                small: true
                primary: false
                text: qsTr("Add remote node") + translationManager.emptyString
                tooltip: qsTr("Address, port, login and trusted daemon") + translationManager.emptyString
                onClicked: remoteNodeDialog.add(function(remoteNode) { remoteNodesModel.append(remoteNode); })
            }
            MoneroComponents.StandardButton {
                small: true
                primary: false
                text: qsTr("Add suggested") + translationManager.emptyString
                tooltip: qsTr("Cake Wallet, Seth for Privacy, HashVault and MoneroDevs public nodes") + translationManager.emptyString
                onClicked: {
                    for (var i = 0; i < tab.suggested.length; ++i) {
                        var found = false;
                        for (var j = 0; j < tab.nodes.length; ++j)
                            if (tab.nodes[j].address === tab.suggested[i]) found = true;
                        if (!found) tab.nodes.push({ address: tab.suggested[i], favorite: false, mine: false, samples: [] });
                    }
                    tab.save();
                    tab.load();
                }
            }
        }
    }

    MoneroComponents.TextPlain {
        visible: tab.showNotes
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 12
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: qsTr("Each test asks the node for /get_info only (height, version, sync state); it does not send anything about your wallet. Using your own local node is still the most private option.") + translationManager.emptyString
    }

    MoneroComponents.TextPlain {
        visible: tab.showNotes
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 12
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: (tab.banList.entries > 0
               ? qsTr("Spy-node ban list (Monero Research Lab, Boog900/monero-ban-list): %1 entries, %2. Your local node starts with it and with the DNS blocklist. Each test also opens a P2P handshake on port 18080 and compares the peers the node hands out with the list: a node that applies the list never hands out a banned IP.").arg(tab.banList.entries).arg(tab.banList.title)
               : qsTr("The spy-node ban list is not inside this build: run compilar-macos.sh again with internet so it gets downloaded.")) + translationManager.emptyString
    }
}
