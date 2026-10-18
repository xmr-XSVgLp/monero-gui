import QtQuick
import QtQuick.Layouts

import "../../components" as MoneroComponents

// Security > Nodes: a node manager that measures latency, availability, version and stability, with
// favourites, your own list and manual rotation. The score does not depend on speed alone.
ColumnLayout {
    id: tab
    spacing: 16

    readonly property var suggested: ["xmr-node.cakewallet.com:18081", "node.sethforprivacy.com:18089",
                                      "nodes.hashvault.pro:18081", "node.monerodevs.org:18089"]
    property var nodes: []
    property bool measuring: false
    property int measureIndex: -1
    property bool onlyFavorites: false
    property string message: ""
    property color messageColor: MoneroComponents.Style.dimmedFontColor

    function load() {
        var list = [];
        try { list = JSON.parse(persistentSettings.securityNodes) || []; } catch (e) { list = []; }
        var seen = {};
        for (var i = 0; i < list.length; ++i)
            seen[list[i].address] = true;
        for (var j = 0; j < remoteNodesModel.count; ++j) {
            var a = remoteNodesModel.get(j).address;
            if (a && !seen[a]) { list.push({ address: a, favorite: false, mine: true, samples: [] }); seen[a] = true; }
        }
        if (list.length === 0)
            for (var k = 0; k < suggested.length; ++k)
                list.push({ address: suggested[k], favorite: false, mine: false, samples: [] });
        nodes = list;
    }

    function save() {
        persistentSettings.securityNodes = JSON.stringify(nodes);
        nodes = nodes.slice();
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
        if (s.availability === 0) return 0;
        var fresh = reference.height === 0 ? 1 : Math.max(0, 1 - Math.max(0, reference.height - s.height) / 10);
        var version = reference.version === "" ? 1 : (compareVersions(s.version, reference.version) >= 0 ? 1
                    : s.version.split(".").slice(0, 2).join(".") === reference.version.split(".").slice(0, 2).join(".") ? 0.6 : 0.2);
        var stability = s.ms === 0 ? 1 : Math.max(0, 1 - s.jitter / Math.max(s.ms, 1));
        var speed = Math.max(0, Math.min(1, 1 - (s.ms - 300) / 4700));
        return Math.round(100 * (0.35 * s.availability + 0.25 * fresh + 0.15 * version + 0.15 * stability + 0.10 * speed));
    }

    function scoreColor(v) {
        return v < 0 ? securityPage.offColor : v >= 75 ? securityPage.goodColor : v >= 50 ? securityPage.warnColor : securityPage.badColor;
    }

    function isCurrent(address) {
        return persistentSettings.useRemoteNode && remoteNodesModel.currentRemoteNode().address === address;
    }

    function measure(index, all) {
        var proxy = securityPage.proxyForRequests();
        if (proxy === null) {
            measuring = false;
            measureIndex = -1;
            message = qsTr("Extreme privacy is on and there is no approved route: nodes are not measured.") + translationManager.emptyString;
            messageColor = securityPage.badColor;
            return;
        }
        if (index >= nodes.length) {
            measuring = false;
            measureIndex = -1;
            message = qsTr("Measured through: %1").arg(securityPage.route.text) + translationManager.emptyString;
            messageColor = MoneroComponents.Style.dimmedFontColor;
            return;
        }
        measuring = true;
        measureIndex = index;
        var address = nodes[index].address;
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
            if (all)
                measure(index + 1, true);
            else {
                measuring = false;
                measureIndex = -1;
            }
        });
    }

    function use(address) {
        var i = remoteNodesModel.appendIfNotExists({ address: address, username: "", password: "", trusted: false });
        remoteNodesModel.applyRemoteNode(i);
        message = qsTr("Now using %1 as remote node.").arg(address) + translationManager.emptyString;
        messageColor = securityPage.goodColor;
        nodes = nodes.slice();
    }

    // manual rotation: a random node among the good ones (score >= 50), not the fastest
    function rotate() {
        var pool = [];
        for (var i = 0; i < nodes.length; ++i) {
            var n = nodes[i];
            if ((onlyFavorites && !n.favorite) || isCurrent(n.address)) continue;
            if (score(n) >= 50) pool.push(n.address);
        }
        if (pool.length === 0) {
            message = qsTr("No other node with a score of 50 or more. Measure the list first.") + translationManager.emptyString;
            messageColor = securityPage.warnColor;
            return;
        }
        use(pool[Math.floor(Math.random() * pool.length)]);
    }

    function addNode(address) {
        address = address.trim().replace(/\/+$/, "");
        if (!/^(https?:\/\/)?[A-Za-z0-9.\-\[\]:]+:\d{2,5}$/.test(address)) {
            message = qsTr("Write it as host:port, for example node.example.com:18089") + translationManager.emptyString;
            messageColor = securityPage.badColor;
            return false;
        }
        for (var i = 0; i < nodes.length; ++i)
            if (nodes[i].address === address) return false;
        nodes.push({ address: address, favorite: false, mine: true, samples: [] });
        save();
        message = "";
        return true;
    }

    function onPageCompleted() {
        load();
    }

    Component.onCompleted: load()

    MoneroComponents.TextPlain {
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
                text: qsTr("Route: ") + translationManager.emptyString + securityPage.route.text
                font.pixelSize: 12
                color: securityPage.route.color
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
                Layout.fillWidth: true
                spacing: 12
                visible: !tab.onlyFavorites || modelData.favorite

                MoneroComponents.TextPlain {
                    text: modelData.favorite ? "★" : "☆"
                    font.pixelSize: 18
                    color: modelData.favorite ? securityPage.warnColor : MoneroComponents.Style.dimmedFontColor
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
                            color: securityPage.goodColor
                            themeTransition: false
                        }
                        MoneroComponents.TextPlain {
                            visible: modelData.mine
                            text: qsTr("my list") + translationManager.emptyString
                            font.pixelSize: 11
                            color: securityPage.blue
                            themeTransition: false
                        }
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                        text: tab.measuring && tab.measureIndex === index ? qsTr("measuring…") + translationManager.emptyString
                              : nodeRow.st.count === 0 ? qsTr("not measured yet") + translationManager.emptyString
                              : [qsTr("%1 % up (%2 tests)").arg(Math.round(nodeRow.st.availability * 100)).arg(nodeRow.st.count),
                                 nodeRow.st.ms ? qsTr("%1 ms ±%2").arg(nodeRow.st.ms).arg(nodeRow.st.jitter) : "",
                                 nodeRow.st.height ? (tab.reference.height - nodeRow.st.height > 2 ? qsTr("%1 blocks behind").arg(tab.reference.height - nodeRow.st.height)
                                                                                                   : qsTr("up to date")) : "",
                                 nodeRow.st.version ? "v" + nodeRow.st.version : "",
                                 nodeRow.st.last && !nodeRow.st.last.ok ? qsTr("last test failed") : ""
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
                    enabled: !nodeRow.current
                    text: qsTr("Use") + translationManager.emptyString
                    onClicked: tab.use(modelData.address)
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
                        onClicked: { tab.nodes.splice(index, 1); tab.save(); }
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
                }
            }
        }
    }

    MoneroComponents.TextPlain {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 12
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
        text: qsTr("Each test asks the node for /get_info only (height, version, sync state); it does not send anything about your wallet. Using your own local node is still the most private option.") + translationManager.emptyString
    }
}
