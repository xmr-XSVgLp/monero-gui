// Custom addresses page (Wallet+): looks for addresses of this wallet that start or end with a text,
// among the ones a restore scans by default (50 accounts x 200 addresses, wallet2 subaddress lookahead).
// Nothing is created to search. "Save to mined" keeps the address in the "Mined addresses account" (wallet cache
// attribute walletplus.mined) and has the wallet watch only that index (one-off subaddress), without creating
// the addresses before it.

import QtQuick
import QtQuick.Layouts

import moneroComponents.Clipboard 1.0

import "../components" as MoneroComponents
import "../js/Utils.js" as Utils

Rectangle {
    id: pageCustom
    color: "transparent"

    property alias customAddressesHeight: mainLayout.height
    // search range "accounts:addresses"; 50:200 is what a restore checks by default (wallet2 lookahead)
    readonly property double maxAddresses: 200000000
    readonly property int defaultAccounts: 50
    readonly property int defaultPerAccount: 200
    readonly property var range: {
        var m = rangeInput.text.trim().match(/^(\d{1,6}):(\d{1,8})$/);
        if (!m) return null;
        var a = +m[1], b = +m[2];
        return a >= 1 && b >= 1 && a <= 100000 && b <= 10000000 && a * b <= maxAddresses ? { accounts: a, perAccount: b } : null;
    }
    readonly property int accounts: range ? range.accounts : defaultAccounts
    readonly property int perAccount: range ? range.perAccount : defaultPerAccount
    readonly property bool customRange: accounts !== defaultAccounts || perAccount !== defaultPerAccount
    // endless range: addresses 0, 1, 2… without end in the range's first accounts (the number before the colon),
    // until Stop (or 500 matches); few accounts, so saving a far match never creates thousands of them
    readonly property bool endless: endlessCheck.checked
    readonly property int endlessAccounts: {
        var m = rangeInput.text.trim().match(/^(\d{1,6})(:|$)/);
        var a = m ? +m[1] : defaultAccounts;
        return a >= 1 && a <= 1000 ? a : defaultAccounts;
    }
    readonly property bool rangeOk: endless || !!range
    property double progressScanned: 0
    property double progressTotal: 0
    property bool cancelled: false
    readonly property string base58: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    Clipboard { id: clipboard }

    readonly property color hit: MoneroComponents.Style.blackTheme ? "#3DDC84" : "#1E7D46"

    property int walletGeneration: 0
    property bool busy: false
    property var results: []
    property double scanned: 0
    property string searched: ""

    readonly property string pattern: patternInput.text.trim()
    readonly property string invalidChars: {
        var bad = "";
        for (var i = 0; i < pattern.length; ++i)
            if (base58.indexOf(pattern[i]) < 0 && (!ignoreCase.checked || base58.toLowerCase().indexOf(pattern[i].toLowerCase()) < 0) && bad.indexOf(pattern[i]) < 0)
                bad += pattern[i];
        return bad;
    }
    // chance that one address character is c: 1/58 in base58, ignoring case a letter matches both forms
    function charProb(c) {
        if (!ignoreCase.checked) return 1 / 58;
        var forms = 0;
        if (base58.indexOf(c.toUpperCase()) >= 0) ++forms;
        if (c.toLowerCase() !== c.toUpperCase() && base58.indexOf(c.toLowerCase()) >= 0) ++forms;
        return Math.max(1, forms) / 58;
    }
    // rough number of hits expected among the 10,000 addresses; subaddresses always start with "8"
    // and the second character is only 2-9 or A-C (11 values)
    readonly property real expected: endless ? 0 : expectedFor(accounts * perAccount)
    // chance that one address matches (used for the time estimate)
    readonly property real perAddress: (ignoreCase.checked, atStart.checked, atEnd.checked, anywhere.checked, expectedFor(1))
    function expectedFor(total) {
        if (pattern.length === 0) return 0;
        var end = 0, start = 0, p, i;
        if (atEnd.checked) {
            p = 1;
            for (i = 0; i < pattern.length; ++i) p *= charProb(pattern[i]);
            end = total * p;
        }
        if (atStart.checked && !startImpossible) {
            p = pattern.length > 1 ? 1 / 11 : 1;
            for (i = 2; i < pattern.length; ++i) p *= charProb(pattern[i]);
            start = total * p;
        }
        // anywhere: about 95 - length positions in the address (counted once even if start/end are also on)
        if (anywhere.checked) {
            p = 1;
            for (i = 0; i < pattern.length; ++i) p *= charProb(pattern[i]);
            return Math.max(start + end, total * Math.max(1, 95 - pattern.length) * p);
        }
        return start + end;
    }
    readonly property bool startImpossible: atStart.checked && pattern !== "" && (pattern[0] !== "8"
        || (pattern.length > 1 && "23456789ABC".indexOf(ignoreCase.checked ? pattern[1].toUpperCase() : pattern[1]) < 0))

    // speed and time estimate while searching
    property double searchStartMs: 0
    property double lastHitScanned: 0
    readonly property real rate: {
        var secs = (clock.now - searchStartMs) / 1000;
        return busy && secs > 0.5 ? progressScanned / secs : 0;
    }
    readonly property double sinceHit: Math.max(0, progressScanned - lastHitScanned)
    // addresses checked against the average a match needs (1 / chance per address)
    readonly property real hitFraction: perAddress > 0 ? Math.min(1, sinceHit * perAddress) : 0
    readonly property real rangeFraction: progressTotal > 0 ? Math.min(1, progressScanned / progressTotal) : 0
    readonly property real barFraction: progressTotal > 0 ? rangeFraction : hitFraction
    function duration(secs) {
        if (!isFinite(secs) || secs < 0) return "?";
        if (secs < 60) return qsTr("%1 s").arg(Math.max(1, Math.round(secs))) + translationManager.emptyString;
        if (secs < 3600) return qsTr("%1 min %2 s").arg(Math.floor(secs / 60)).arg(Math.round(secs % 60)) + translationManager.emptyString;
        if (secs < 86400) return qsTr("%1 h %2 min").arg(Math.floor(secs / 3600)).arg(Math.round(secs % 3600 / 60)) + translationManager.emptyString;
        if (secs < 86400 * 365) return qsTr("%1 days %2 h").arg(Math.floor(secs / 86400)).arg(Math.round(secs % 86400 / 3600)) + translationManager.emptyString;
        return qsTr("%1 years").arg((secs / (86400 * 365)).toLocaleString(Qt.locale(), "f", secs > 86400 * 365 * 100 ? 0 : 1)) + translationManager.emptyString;
    }
    readonly property string etaText: {
        if (!busy) return "";
        if (rate <= 0 || perAddress <= 0) return qsTr("Measuring speed…") + translationManager.emptyString;
        var left = 1 / perAddress - sinceHit;
        var next = left > 0 ? qsTr("Next match in about %1").arg(duration(left / rate)) + translationManager.emptyString
                            : qsTr("Next match: any moment now (luck is behind the average)") + translationManager.emptyString;
        var end = progressTotal > 0 ? " · " + qsTr("range finished in %1").arg(duration((progressTotal - progressScanned) / rate)) + translationManager.emptyString : "";
        return next + end;
    }
    Timer {
        id: clock
        property double now: Date.now()
        interval: 500
        repeat: true
        running: pageCustom.busy
        onTriggered: now = Date.now()
    }

    function search() {
        if (!currentWallet || busy || pattern === "" || !rangeOk || (!atStart.checked && !atEnd.checked && !anywhere.checked))
            return;
        busy = true;
        results = [];
        searched = pattern;
        cancelled = false;
        progressScanned = 0;
        lastHitScanned = 0;
        searchStartMs = Date.now();
        clock.now = searchStartMs;
        progressTotal = endless ? 0 : accounts * perAccount;
        var generation = walletGeneration;
        currentWallet.findAddressesAsync(pattern, atStart.checked, atEnd.checked, anywhere.checked, ignoreCase.checked,
                                         endless ? endlessAccounts : accounts, endless ? 0 : perAccount, function(json, count, stopped) {
            if (generation !== walletGeneration) return;
            busy = false;
            scanned = count;
            cancelled = stopped;
            try { results = JSON.parse(json); } catch (e) { results = []; }
        });
    }

    // the matched part in colour, the rest as it is
    function highlighted(r) {
        var a = r.address, n = searched.length;
        var color = pageCustom.hit.toString();
        var mark = function(t) { return "<font color='" + color + "'><b>" + t + "</b></font>"; };
        // only somewhere in the middle: mark that part
        if (!r.start && !r.end && r.pos >= 0)
            return a.substring(0, r.pos) + mark(a.substring(r.pos, r.pos + n)) + a.substring(r.pos + n);
        var head = r.start ? n : 0, tail = r.end ? n : 0;
        if (head + tail > a.length) tail = 0;
        return (head ? mark(a.substring(0, head)) : "") + a.substring(head, a.length - tail)
             + (tail ? mark(a.substring(a.length - tail)) : "");
    }

    // mined addresses of this wallet (main.qml keeps them in the wallet cache)
    readonly property var mined: (appWindow.minedAddressesTick, currentWallet ? appWindow.minedAddresses() : [])
    function isMined(r) {
        return mined.some(function(m) { return m.account === r.account && m.index === r.index; });
    }

    property bool adding: false
    function saveMined(r) {
        var w = currentWallet;
        if (!w || adding) return;
        if (isMined(r)) {
            appWindow.showStatusMessage(qsTr("It is already in the mined addresses account") + translationManager.emptyString, 3);
            return;
        }
        adding = true;
        w.addMinedAddressAsync(r.account, r.index, function(ok, error) {
            adding = false;
            w.startRefresh();
            w.subaddressAccount.getAll();
            if (!ok) {
                appWindow.showStatusMessage(qsTr("The wallet could not watch this address") + translationManager.emptyString
                                            + (error ? ": " + error : ""), 8);
                return;
            }
            var list = appWindow.minedAddresses().slice();
            list.push({ account: r.account, index: r.index, address: r.address, label: searched, added: Date.now() });
            appWindow.setMinedAddresses(list);
            appWindow.showStatusMessage(qsTr("Saved in the mined addresses account") + translationManager.emptyString, 4);
        });
    }

    // balances of the mined addresses (any account, existing or not); bumps on every wallet update
    property int balanceTick: 0
    function minedBalance(m, unlocked) {
        return (balanceTick, currentWallet ? currentWallet.addressBalance(m.account, m.index, unlocked) : 0);
    }
    // the change of a send from a mined address goes to 0:1 (primary account), tagged in the history
    readonly property var changeRows: []
    readonly property var minedRows: mined.concat(changeRows)
    readonly property string minedTotal: {
        var t = 0;
        for (var i = 0; i < minedRows.length; ++i) t += minedBalance(minedRows[i], false);
        return walletManager.displayAmount(t);
    }

    function removeMined(m) {
        // while syncing, a payment to it may not be found yet
        if (!appWindow.walletSynced || !appWindow.daemonSynced) {
            appWindow.showStatusMessage(qsTr("Wait until the wallet is synchronized: it may have received something not found yet") + translationManager.emptyString, 6);
            return;
        }
        // once it received something it stays: its history and change belong to the mined addresses account
        if (currentWallet && currentWallet.addressUsed(m.account, m.index)) {
            appWindow.showStatusMessage(qsTr("This address already has transactions, so it stays in the mined addresses account for good") + translationManager.emptyString, 6);
            return;
        }
        confirmationDialog.title = qsTr("Remove mined address") + translationManager.emptyString;
        confirmationDialog.text = qsTr("It leaves the list and, from the next time you open the wallet, the wallet stops watching it: funds sent to it after that would not show up.") + translationManager.emptyString;
        confirmationDialog.okText = qsTr("Remove") + translationManager.emptyString;
        confirmationDialog.cancelText = qsTr("Cancel") + translationManager.emptyString;
        confirmationDialog.onAcceptedCallback = function() {
            appWindow.setMinedAddresses(appWindow.minedAddresses().filter(function(x) { return !(x.account === m.account && x.index === m.index); }));
        };
        confirmationDialog.onRejectedCallback = null;
        confirmationDialog.open();
    }

    // outside what the wallet looks at now (created addresses + lookahead): funds sent there would not be seen
    // until the address is added (creating up to it moves the lookahead)
    function detectable(r) {
        var w = currentWallet;
        if (!w) return false;
        var nAcc = w.numSubaddressAccounts();
        var created = r.account < nAcc ? w.numSubaddresses(r.account) : 0;
        return r.account < nAcc + defaultAccounts && r.index < created + defaultPerAccount;
    }
    function beyondDefault(r) { return r.account >= defaultAccounts || r.index >= defaultPerAccount; }

    Connections {
        target: currentWallet
        ignoreUnknownSignals: true
        function onUpdated() { pageCustom.balanceTick++; }
        function onMoneyReceived() { pageCustom.balanceTick++; }
        function onUnconfirmedMoneyReceived() { pageCustom.balanceTick++; }
        function onAddressSearchProgress(done, total) { pageCustom.progressScanned = done; pageCustom.progressTotal = total; }
        // matches appear while the search goes on; the final list (sorted) replaces them at the end
        function onAddressSearchHit(json) {
            if (!pageCustom.busy) return;
            try {
                var fresh = JSON.parse(json);
                if (fresh.length) {
                    pageCustom.results = pageCustom.results.concat(fresh);
                    pageCustom.lastHitScanned = pageCustom.progressScanned;
                }
            } catch (e) {}
        }
    }

    Connections {
        target: appWindow
        function onCurrentWalletChanged() {
            pageCustom.walletGeneration++;
            pageCustom.busy = false;
            pageCustom.adding = false;
            pageCustom.results = [];
            pageCustom.searched = "";
            pageCustom.scanned = 0;
            pageCustom.progressScanned = 0;
            pageCustom.progressTotal = 0;
            pageCustom.cancelled = false;
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.margins: 20
        anchors.topMargin: 40
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 20

        MoneroComponents.LabelSubheader {
            Layout.fillWidth: true
            fontSize: 24
            text: qsTr("Mine addresses") + translationManager.emptyString
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 14
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
            text: qsTr("Looks for an address of this wallet that starts, ends with or contains your text. By default among the %1 accounts × %2 addresses a restore checks, so funds sent to one are found again when you restore with the seed. You can widen the range; addresses outside it need a bigger \"subaddress lookahead\" when restoring.").arg(pageCustom.defaultAccounts).arg(pageCustom.defaultPerAccount) + translationManager.emptyString
        }

        // ---------- mined addresses account ----------
        Item {
            Layout.fillWidth: true
            visible: pageCustom.mined.length > 0
            implicitHeight: minedLayout.implicitHeight + 32

            MoneroComponents.CardPanel { anchors.fill: parent }

            ColumnLayout {
                id: minedLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    MoneroComponents.SectionTitle {
                        Layout.fillWidth: true
                        text: qsTr("Mined addresses account") + translationManager.emptyString
                    }
                    MoneroComponents.TextPlain {
                        font.family: MoneroComponents.Style.fontMonoMedium.name
                        font.pixelSize: 14
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        textFormat: Text.RichText
                        text: (persistentSettings.hideBalance ? "?.??" : Utils.prettyAmountRich(pageCustom.minedTotal, Math.round(font.pixelSize * 0.65))) + " XMR"
                    }
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                    text: qsTr("The wallet watches each of these addresses on its own, without creating any account or address for them. What they receive counts in the total balance and is spent from here with Send. The change of a send goes to the primary account (address 0:1) and the transaction is tagged \"(mined address change)\". To restore them elsewhere, write down their account and address number.") + translationManager.emptyString
                }

                Repeater {
                    model: pageCustom.minedRows
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        readonly property var m: modelData
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: MoneroComponents.Style.dividerColor; opacity: MoneroComponents.Style.dividerOpacity }
                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            wrapMode: Text.WrapAnywhere
                            font.family: MoneroComponents.Style.fontMonoRegular.name
                            font.pixelSize: 13
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                            text: m.address
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: 12
                                color: MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                                text: (m.change ? qsTr("Change") : "\u201C" + m.label + "\u201D") + " · " + qsTr("Account %1 · address %2").arg(m.account).arg(m.index) + translationManager.emptyString
                                      + (pageCustom.beyondDefault(m) ? " · " + qsTr("to restore it use subaddress lookahead %1:%2").arg(Math.max(50, m.account + 1)).arg(Math.max(200, m.index + 1)) + translationManager.emptyString : "")
                            }
                            MoneroComponents.StandardButton {
                                small: true
                                primary: false
                                text: qsTr("Copy") + translationManager.emptyString
                                onClicked: {
                                    clipboard.setText(m.address);
                                    appWindow.showStatusMessage(qsTr("Address copied to clipboard") + translationManager.emptyString, 3);
                                }
                            }
                            MoneroComponents.TextPlain {
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 13
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                                textFormat: Text.RichText
                                text: (persistentSettings.hideBalance ? "?.??" : Utils.prettyAmountRich(walletManager.displayAmount(pageCustom.minedBalance(m, false)), Math.round(font.pixelSize * 0.65))) + " XMR"
                            }
                            MoneroComponents.StandardButton {
                                small: true
                                enabled: !appWindow.viewOnly && pageCustom.minedBalance(m, true) > 0
                                text: qsTr("Send") + translationManager.emptyString
                                onClicked: appWindow.spendFromMined(m)
                            }
                            MoneroComponents.StandardButton {
                                small: true
                                primary: false
                                visible: !m.change && !(pageCustom.balanceTick, currentWallet && currentWallet.addressUsed(m.account, m.index))
                                enabled: appWindow.walletSynced && appWindow.daemonSynced
                                tooltip: enabled ? "" : qsTr("Wait until the wallet is synchronized") + translationManager.emptyString
                                text: qsTr("Remove") + translationManager.emptyString
                                onClicked: pageCustom.removeMined(m)
                            }
                        }
                    }
                }
            }
        }

        // ---------- search ----------
        Item {
            Layout.fillWidth: true
            implicitHeight: searchLayout.implicitHeight + 32

            MoneroComponents.CardPanel { anchors.fill: parent }

            ColumnLayout {
                id: searchLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MoneroComponents.LineEdit {
                        id: patternInput
                        Layout.preferredWidth: 260
                        inputHeight: 38
                        inputPaddingTop: 0
                        inputPaddingBottom: 0
                        fontFamily: MoneroComponents.Style.fontMonoRegular.name
                        fontSize: 16
                        placeholderFontSize: 15
                        placeholderText: qsTr("e.g. 8888") + translationManager.emptyString
                        error: pageCustom.invalidChars !== ""
                        input.maximumLength: 12
                        onAccepted: pageCustom.search()
                    }

                    MoneroComponents.TextPlain {
                        text: qsTr("Range") + translationManager.emptyString
                        font.pixelSize: 13
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                    MoneroComponents.LineEdit {
                        id: rangeInput
                        Layout.preferredWidth: 140
                        inputHeight: 38
                        inputPaddingTop: 0
                        inputPaddingBottom: 0
                        fontFamily: MoneroComponents.Style.fontMonoRegular.name
                        fontSize: 15
                        text: "50:200"
                        error: !pageCustom.rangeOk
                        onAccepted: pageCustom.search()
                    }

                    MoneroComponents.StandardButton {
                        visible: pageCustom.busy
                        primary: false
                        text: qsTr("Stop") + translationManager.emptyString
                        onClicked: currentWallet.cancelAddressSearch()
                    }

                    MoneroComponents.StandardButton {
                        text: (pageCustom.busy ? qsTr("Searching…") : qsTr("Search")) + translationManager.emptyString
                        enabled: !pageCustom.busy && pageCustom.rangeOk && pageCustom.pattern !== "" && pageCustom.invalidChars === "" && (atStart.checked || atEnd.checked || anywhere.checked) && !!currentWallet
                        onClicked: pageCustom.search()
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    spacing: 20
                    MoneroComponents.CheckBox {
                        id: atStart
                        Layout.preferredWidth: atStart.width
                        checked: true
                        fontSize: 13
                        text: qsTr("At the start") + translationManager.emptyString
                    }
                    MoneroComponents.CheckBox {
                        id: atEnd
                        Layout.preferredWidth: atEnd.width
                        checked: true
                        fontSize: 13
                        text: qsTr("At the end") + translationManager.emptyString
                    }
                    MoneroComponents.CheckBox {
                        id: anywhere
                        Layout.preferredWidth: anywhere.width
                        checked: false
                        fontSize: 13
                        text: qsTr("Anywhere") + translationManager.emptyString
                    }
                    MoneroComponents.CheckBox {
                        id: endlessCheck
                        Layout.preferredWidth: endlessCheck.width
                        checked: false
                        enabled: !pageCustom.busy
                        fontSize: 13
                        text: qsTr("Endless range") + translationManager.emptyString
                    }
                    MoneroComponents.CheckBox {
                        id: ignoreCase
                        Layout.preferredWidth: ignoreCase.width
                        checked: true
                        fontSize: 13
                        text: qsTr("Ignore upper/lower case") + translationManager.emptyString
                    }
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    visible: !pageCustom.rangeOk || pageCustom.customRange || pageCustom.busy || pageCustom.endless
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    themeTransition: false
                    color: !pageCustom.rangeOk ? "#FF5C5C" : MoneroComponents.Style.dimmedFontColor
                    text: !pageCustom.rangeOk ? qsTr("Write the range as accounts:addresses, e.g. 100:1000 (up to 200,000,000 addresses).") + translationManager.emptyString
                          : pageCustom.busy && pageCustom.progressTotal === 0 ? qsTr("Checked %1 addresses, now at address %2 of each account… (it goes on until you press Stop)").arg(Math.round(pageCustom.progressScanned).toLocaleString(Qt.locale(), "f", 0)).arg(Math.floor(pageCustom.progressScanned / pageCustom.endlessAccounts).toLocaleString(Qt.locale(), "f", 0)) + translationManager.emptyString
                          : pageCustom.endless && !pageCustom.busy ? qsTr("Endless: it goes through addresses 0, 1, 2… without end in the first %1 accounts (the number before the colon, up to 1000) and does not stop until you press Stop or it has 500 matches. Matches show up as they are found. Far-away addresses are not found by a normal restore: write down their account and address number.").arg(pageCustom.endlessAccounts) + translationManager.emptyString
                          : pageCustom.busy ? qsTr("Checked %1 of %2 addresses…").arg(Math.round(pageCustom.progressScanned).toLocaleString(Qt.locale(), "f", 0)).arg(Math.round(pageCustom.progressTotal).toLocaleString(Qt.locale(), "f", 0)) + translationManager.emptyString
                          : qsTr("%1 addresses: large ranges take a while (all cores but one are used; you can stop it). Addresses beyond 50:200 are not found by a normal restore: write down their account and address number, or keep this wallet's files.").arg((pageCustom.accounts * pageCustom.perAccount).toLocaleString(Qt.locale(), "f", 0)) + translationManager.emptyString
                }

                // progress like the sync bars: range done, or (endless) addresses checked against the average a match needs
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: pageCustom.busy
                    spacing: 4
                    readonly property bool dark: MoneroComponents.Style.blackTheme
                    readonly property color accent: dark ? "#FFC23D" : "#B07A00"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 11
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.5
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                            text: (pageCustom.progressTotal > 0 ? qsTr("Searching the range") : qsTr("Towards the next match")) + translationManager.emptyString
                        }
                        MoneroComponents.TextPlain {
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 11
                            color: MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                            text: Math.floor(pageCustom.barFraction * 100) + "%"
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: MoneroComponents.Style.defaultFontColor
                            opacity: parent.parent.dark ? 0.12 : 0.15
                        }
                        Rectangle {
                            height: parent.height
                            radius: 3
                            width: Math.max(height, parent.width * pageCustom.barFraction)
                            color: parent.parent.accent
                            Behavior on width { NumberAnimation { duration: 400 } }
                        }
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        text: pageCustom.etaText + (pageCustom.rate > 0 ? " · " + qsTr("%1 addresses/s").arg(Math.round(pageCustom.rate).toLocaleString(Qt.locale(), "f", 0)) + translationManager.emptyString : "")
                    }
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    themeTransition: false
                    color: pageCustom.invalidChars !== "" ? "#FF5C5C" : MoneroComponents.Style.dimmedFontColor
                    text: pageCustom.invalidChars !== ""
                          ? qsTr("Addresses never contain %1 (they use base58: no 0, O, I or l).").arg(pageCustom.invalidChars) + translationManager.emptyString
                          : pageCustom.pattern === "" ? qsTr("Addresses always start with 8 (the main one with 4) and the second character is only 2-9 or A-C, so at the start write the whole beginning, like 8888. The end can be anything. Each extra character makes a match about 30-60 times less likely.") + translationManager.emptyString
                          : (pageCustom.startImpossible && !anywhere.checked && !atEnd.checked ? qsTr("No address can start like that (they start with 8 and then 2-9 or A-C). ") + translationManager.emptyString : "")
                            + (pageCustom.expected >= 1 ? qsTr("About %1 matches expected.").arg(Math.round(pageCustom.expected)) + translationManager.emptyString
                          : pageCustom.expected > 0 ? qsTr("About a %1 % chance of finding one.").arg(pageCustom.expected < 0.001 ? "<0.1" : (pageCustom.expected * 100).toFixed(1)) + translationManager.emptyString : "")
                }
            }
        }

        // ---------- results ----------
        MoneroComponents.TextPlain {
            visible: pageCustom.searched !== "" && (!pageCustom.busy || pageCustom.results.length > 0)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            color: MoneroComponents.Style.defaultFontColor
            themeTransition: false
            text: pageCustom.busy ? qsTr("%1 addresses with \"%2\" so far…").arg(pageCustom.results.length).arg(pageCustom.searched) + translationManager.emptyString
                  : pageCustom.results.length === 0
                  ? qsTr("No address with \"%1\" among the %2 checked.").arg(pageCustom.searched).arg(pageCustom.scanned) + translationManager.emptyString
                  : qsTr("%1 addresses with \"%2\" among the %3 checked.").arg(pageCustom.results.length).arg(pageCustom.searched).arg(pageCustom.scanned) + translationManager.emptyString
                  + (pageCustom.cancelled ? " " + qsTr("(stopped)") + translationManager.emptyString : "")
        }

        Repeater {
            model: pageCustom.results
            delegate: Item {
                Layout.fillWidth: true
                implicitHeight: resultLayout.implicitHeight + 24
                readonly property var r: modelData

                HoverHandler { id: resultHover }
                MoneroComponents.CardPanel { anchors.fill: parent; selected: resultHover.hovered }

                ColumnLayout {
                    id: resultLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.StyledText
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 13
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        text: pageCustom.highlighted(r)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: 12
                            color: pageCustom.beyondDefault(r) ? "#FFC434" : MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                            text: (r.account === 0 && r.index === 0 ? qsTr("Main address") : qsTr("Account %1 · address %2").arg(r.account).arg(r.index)) + translationManager.emptyString
                                  + (pageCustom.beyondDefault(r) ? " · " + qsTr("to restore it use subaddress lookahead %1:%2").arg(Math.max(50, r.account + 1)).arg(Math.max(200, r.index + 1)) + translationManager.emptyString : "")
                                  + (pageCustom.isMined(r) ? " · " + qsTr("in the mined addresses account") + translationManager.emptyString
                                     : !pageCustom.detectable(r) ? " · " + qsTr("save it to mined before using it") + translationManager.emptyString : "")
                        }
                        MoneroComponents.StandardButton {
                            small: true
                            primary: false
                            enabled: pageCustom.detectable(r) || pageCustom.isMined(r)
                            text: qsTr("Copy") + translationManager.emptyString
                            onClicked: {
                                clipboard.setText(r.address);
                                appWindow.showStatusMessage(qsTr("Address copied to clipboard") + translationManager.emptyString, 3);
                            }
                        }
                        MoneroComponents.StandardButton {
                            small: true
                            enabled: !pageCustom.adding && !pageCustom.isMined(r)
                            text: (pageCustom.isMined(r) ? qsTr("Saved") : qsTr("Save to mined")) + translationManager.emptyString
                            onClicked: pageCustom.saveMined(r)
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 20 }
    }
}
