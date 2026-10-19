// Swaps page: two tables with the same columns.
// Wagyu: quotes for 1 coin -> XMR, 1 XMR -> coin (amount A), A coin -> XMR (amount B), difference = B - 1 XMR in %.
// NonKYC: the same numbers from the best bid/ask of its primary XMR markets.
// ChangeNOW: the same three quotes as Wagyu, from its estimated exchange amount (standard flow, fees included).
// Every refresh is appended to a CSV file (oshelper.swapsLogPath()) to compare prices over time.

import QtQuick
import QtQuick.Layouts

import "../components" as MoneroComponents
import "../js/Utils.js" as Utils
import "../js/SwapHistory.js" as SwapHistory

Rectangle {
    id: pageSwaps
    color: "transparent"

    property alias swapsHeight: mainLayout.height
    property string lastUpdate: ""
    property int pending: 0

    readonly property string quoteUrl: "https://api-beta.wagyu.xyz/v2/swaps/quote"
    readonly property int xmrChainId: 0
    readonly property string xmrToken: "XMR"
    readonly property string oneXmr: "1000000000000"   // atomic units

    // Wagyu catalog entries (GET /v2/swaps/assets)
    readonly property var coins: [
        { key: "btc",  name: "Bitcoin",            symbol: "BTC",  chainId: 20000000000001,   token: "bitcoin",                                    decimals: 8,  color: "#F7931A" },
        { key: "eth",  name: "Ethereum",           symbol: "ETH",  chainId: 1,                token: "0x0000000000000000000000000000000000000000", decimals: 18, color: "#8C8CF5" },
        { key: "sol",  name: "Solana",             symbol: "SOL",  chainId: 1151111081099710, token: "11111111111111111111111111111111",           decimals: 9,  color: "#14F195" },
        { key: "usdt", name: "Tether (Ethereum)",  symbol: "USDT", chainId: 1,                token: "0xdAC17F958D2ee523a2206206994597C13D831ec7", decimals: 6,  color: "#26A17B" },
        { key: "zec",  name: "Zcash",              symbol: "ZEC",  chainId: 133,              token: "ZEC",                                        decimals: 8,  color: "#F4B728" }
    ]

    // NonKYC XMR markets (GET /api/v2/tickers), shown with the same rows as Wagyu
    readonly property string nonKycUrl: "https://api.nonkyc.io/api/v2/tickers"
    // only NonKYC's primary XMR markets, in this order
    readonly property var nkPrimary: ["XMR_USDT", "XMR_USDC", "XMR_BTC"]
    property var nkMarkets: []
    property string nkError: ""

    function refreshNonKyc() {
        request(false, nonKycUrl, "", function(url, resp, error) {
            if (error) {
                nkError = error;
                console.log("Swaps: NonKYC failed: " + error);
                done();
                return;
            }
            try {
                var list = JSON.parse(resp);
                var markets = [];
                var r = Object.assign({}, results);
                for (var i = 0; i < list.length; i++) {
                    var t = list[i];
                    var base = t.base_currency, quoteCur = t.target_currency;
                    if (nkPrimary.indexOf(t.ticker_id) < 0) continue;
                    var bid = parseFloat(t.bid), ask = parseFloat(t.ask);
                    if (!(bid > 0) || !(ask > 0)) continue;
                    var other = base === "XMR" ? quoteCur : base;
                    var out, one;
                    if (base === "XMR") {      // XMR_OTHER: sell XMR at bid, buy XMR back at ask
                        out = bid;
                        one = 1 / ask;
                    } else {                   // OTHER_XMR: buy OTHER at ask, sell it at bid
                        out = 1 / ask;
                        one = bid;
                    }
                    var key = "nk_" + t.ticker_id;
                    markets.push({ key: key, symbol: other, decimals: 8,
                                   name: t.ticker_id.replace("_", "/"),
                                   sub: qsTr("vol. $%1").arg(Utils.prettyAmount(Math.round(parseFloat(t.usd_volume_est) || 0))) + translationManager.emptyString,
                                   color: pageSwaps.coinColor(other),
                                   order: nkPrimary.indexOf(t.ticker_id) });
                    r[key] = { out: out.toFixed(12), one: one.toFixed(12), back: (bid / ask).toFixed(12), diff: (bid / ask - 1) * 100,
                               bid: t.bid, ask: t.ask, volume: t.usd_volume_est };
                }
                markets.sort(function(a, b) { return a.order - b.order; });
                results = r;
                nkMarkets = markets;
                nkError = "";
            } catch (e) {
                nkError = "bad JSON";
                console.log("Swaps: NonKYC bad JSON: " + e);
            }
            done();
        });
    }

    // ChangeNOW (GET /v1/exchange-amount/<amount>/<from>_<to>, no API key needed)
    readonly property string cnUrl: "https://api.changenow.io/v1/exchange-amount/"
    // probe: amount of the coin used for "1 coin -> XMR" (stablecoins are below ChangeNOW's minimum at 1 unit)
    readonly property var cnCoins: [
        { key: "cn_btc",  name: "Bitcoin",            symbol: "BTC",  ticker: "btc",       probe: 1,   color: "#F7931A" },
        { key: "cn_eth",  name: "Ethereum",           symbol: "ETH",  ticker: "eth",       probe: 1,   color: "#8C8CF5" },
        { key: "cn_sol",  name: "Solana",             symbol: "SOL",  ticker: "sol",       probe: 1,   color: "#14F195" },
        { key: "cn_usdt", name: "Tether (Ethereum)",  symbol: "USDT", ticker: "usdterc20", probe: 100, color: "#26A17B" },
        { key: "cn_ltc",  name: "Litecoin",           symbol: "LTC",  ticker: "ltc",       probe: 1,   color: "#A6A9AA" },
        { key: "cn_zec",  name: "Zcash",              symbol: "ZEC",  ticker: "zec",       probe: 1,   color: "#F4B728" }
    ]

    function cnQuote(amount, from, to, callback) {
        request(false, cnUrl + amount + "/" + from + "_" + to, "", function(u, resp, error) {
            if (error) { callback(NaN, error); return; }
            try {
                var q = JSON.parse(resp);
                var amt = parseFloat(q.estimatedAmount);
                if (!(amt > 0)) { callback(NaN, q.message || q.error || "no estimatedAmount"); return; }
                callback(amt, "");
            } catch (e) {
                callback(NaN, "bad JSON");
            }
        });
    }

    property string cnError: ""

    function cnQuoteCoin(c) {
        setResult(c.key, { loading: true });
        // 1 XMR -> coin, and that amount back to XMR
        cnQuote(1, "xmr", c.ticker, function(out, err) {
            if (!(out > 0)) {
                setResult(c.key, { loading: false, error: err });
                cnError = err;
                console.log("Swaps: ChangeNOW XMR->" + c.symbol + " failed: " + err);
                done(); done();
                return;
            }
            setResult(c.key, { out: out.toFixed(12) });
            cnQuote(out, c.ticker, "xmr", function(back, err2) {
                if (!(back > 0)) {
                    setResult(c.key, { loading: false, error: err2 });
                    console.log("Swaps: ChangeNOW " + c.symbol + "->XMR failed: " + err2);
                } else {
                    setResult(c.key, { loading: false, back: back.toFixed(12), diff: (back - 1) * 100, error: "" });
                }
                done();
            });
            done();
        });
        // 1 coin -> XMR (measured on the probe amount)
        cnQuote(c.probe, c.ticker, "xmr", function(xmr, err) {
            if (!(xmr > 0)) {
                setResult(c.key, { oneError: err });
                console.log("Swaps: ChangeNOW " + c.symbol + "->XMR (1) failed: " + err);
            } else {
                setResult(c.key, { one: (xmr / c.probe).toFixed(12) });
            }
            done();
        });
    }

    function coinColor(symbol) {
        var known = { BTC: "#F7931A", ETH: "#8C8CF5", SOL: "#14F195", USDT: "#26A17B", USDC: "#2775CA", EURC: "#4F8FF7",
                      ZEC: "#F4B728", LTC: "#A6A9AA", HYPE: "#97FCE4" };
        return known[symbol] || "#8C8C8C";
    }

    // results per coin key: { out: "…", back: "…", diff: NaN, error: "" }
    property var results: ({})

    function setResult(key, fields) {
        var r = Object.assign({}, results);
        r[key] = Object.assign({}, r[key] || {}, fields);
        results = r;
    }

    // atomic integer string -> decimal string
    function fromAtomic(s, decimals) {
        s = String(s).replace(/^0+/, "");
        if (s === "") s = "0";
        while (s.length <= decimals) s = "0" + s;
        var i = s.slice(0, s.length - decimals);
        var d = s.slice(s.length - decimals);
        return decimals > 0 ? i + "." + d : i;
    }

    function shortAmount(dec, maxDecimals) {
        var n = parseFloat(dec);
        if (isNaN(n)) return "—";
        return Utils.removeTrailingZeros(n.toFixed(maxDecimals));
    }

    function quote(fromChainId, fromToken, toChainId, toToken, amount, callback) {
        request(true, quoteUrl, JSON.stringify({
                             fromChainId: fromChainId, fromToken: fromToken,
                             toChainId: toChainId, toToken: toToken,
                             fromAmount: amount }),
                         function(url, resp, error) {
                             if (error) { callback(null, error); return; }
                             try {
                                 var q = JSON.parse(resp);
                                 if (!q.toAmount) { callback(null, "no toAmount"); return; }
                                 callback(q, "");
                             } catch (e) {
                                 callback(null, "bad JSON");
                             }
                         });
    }

    // swap prices are on only with "Price conversion" (Settings > Node / Network): asking the
    // exchanges exposes the IP address like the fiat price sources do
    // only fetched when the page is opened (onPageCompleted) or with Refresh, never at startup
    readonly property bool pricesEnabled: persistentSettings.fiatPriceEnabled
    // turned off: drop the queued requests so nothing else reaches the exchanges
    onPricesEnabledChanged: if (!pricesEnabled) requestQueue.length = 0

    // the app has 4 background threads, shared with the wallet (opening, sync): the swap
    // requests (slow through Nym) never take more than 2 of them, the rest wait in this queue
    readonly property int maxInFlight: 2
    readonly property var requestQueue: []
    property int inFlight: 0

    function request(post, url, body, callback) {
        requestQueue.push({ post: post, url: url, body: body, callback: callback });
        pumpRequests();
    }

    function pumpRequests() {
        if (!pricesEnabled) {
            requestQueue.length = 0;
            return;
        }
        while (inFlight < maxInFlight && requestQueue.length > 0) {
            var r = requestQueue.shift();
            inFlight++;
            var cb = (function(req) {
                return function(u, resp, error) {
                    inFlight--;
                    req.callback(u, resp, error);
                    pumpRequests();
                };
            })(r);
            if (r.post)
                network.postJSON(r.url, r.body, cb);
            else
                network.getJSON(r.url, cb);
        }
    }

    function refresh() {
        if (!pricesEnabled)
            return;
        results = ({});
        nkMarkets = [];
        cnError = "";
        pending = coins.length * 2 + 1 + cnCoins.length * 3;
        refreshNonKyc();
        for (var j = 0; j < cnCoins.length; j++)
            cnQuoteCoin(cnCoins[j]);
        for (var i = 0; i < coins.length; i++) {
            quoteCoin(coins[i]);
            quoteOneCoin(coins[i]);
        }
    }

    // 1 coin -> XMR
    function quoteOneCoin(c) {
        var one = "1" + new Array(c.decimals + 1).join("0");
        quote(c.chainId, c.token, xmrChainId, xmrToken, one, function(q, err) {
            if (!q) {
                setResult(c.key, { oneError: err });
                console.log("Swaps: 1 " + c.symbol + "->XMR failed: " + err);
            } else {
                setResult(c.key, { one: fromAtomic(q.toAmount, 12) });
            }
            done();
        });
    }

    function done() {
        pending = Math.max(0, pending - 1);
        if (pending === 0) {
            lastUpdate = new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss");
            saveHistory();
        }
    }

    // ---- price history (CSV) ----
    readonly property string historyHeader: "fecha_utc,fuente,mercado,moneda,swap_1_moneda_a_xmr,swap_1_xmr_a_moneda,vuelta_a_xmr,diferencia_pct,bid,ask,volumen_usd_24h"
    property string historyPath: typeof oshelper !== "undefined" && oshelper.swapsLogPath ? oshelper.swapsLogPath() : ""
    property string historyStatus: ""

    function csvField(v) {
        if (v === undefined || v === null || (typeof v === "number" && isNaN(v))) return "";
        var t = String(v);
        return /[",\n]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t;
    }

    function saveHistory() {
        if (historyPath === "") return;
        var now = new Date().toISOString();
        var lines = "";
        var rows = [];
        for (var i = 0; i < coins.length; i++)
            rows.push({ src: "wagyu", market: "XMR/" + coins[i].symbol, coin: coins[i] });
        for (var j = 0; j < nkMarkets.length; j++)
            rows.push({ src: "nonkyc", market: nkMarkets[j].name, coin: nkMarkets[j] });
        for (var c = 0; c < cnCoins.length; c++)
            rows.push({ src: "changenow", market: "XMR/" + cnCoins[c].symbol, coin: cnCoins[c] });
        var count = 0;
        for (var k = 0; k < rows.length; k++) {
            var res = results[rows[k].coin.key] || {};
            if (res.out === undefined && res.one === undefined) continue;
            lines += [now, rows[k].src, rows[k].market, rows[k].coin.symbol, res.one, res.out, res.back,
                      res.diff !== undefined ? res.diff.toFixed(4) : "", res.bid, res.ask, res.volume]
                     .map(csvField).join(",") + "\n";
            count++;
        }
        if (count === 0) return;
        var ok = oshelper.appendCsv(historyPath, historyHeader, lines);

        // the routes of this refresh go to a second file next to it
        var rlines = "";
        for (var m = 0; m < routes.length; m++) {
            var rt = routes[m];
            rlines += [now, m + 1, rt.coin, rt.from, rt.to, rt.out.toFixed(12), rt.xmr.toFixed(12), rt.pct.toFixed(4), rt.exact ? "exacta" : "aprox"]
                      .map(csvField).join(",") + "\n";
        }
        if (rlines !== "")
            ok = oshelper.appendCsv(routesPath, routesHeader, rlines) && ok;

        loadCompare();
        historyStatus = ok
            ? qsTr("%1 prices saved").arg(count) + translationManager.emptyString
            : qsTr("Could not save the price history") + translationManager.emptyString;
    }

    // ---- routes: XMR -> coin on one exchange, coin -> XMR on the same or the other one ----
    readonly property string routesHeader: "fecha_utc,puesto,moneda,ida_xmr_a_moneda_en,vuelta_moneda_a_xmr_en,moneda_recibida,xmr_final,beneficio_pct,calculo"
    readonly property string routesPath: historyPath !== "" ? historyPath.replace(/precios-swaps\.csv$/, "rutas-swaps.csv") : ""
    property var routes: buildRoutes(results, nkMarkets)

    function buildRoutes(res, markets) {
        // per symbol, what each exchange gives: out = coin for 1 XMR, one = XMR for 1 coin, back = exact round trip
        var venues = {};
        function add(sym, venue, r) {
            if (!r || r.out === undefined) return;
            var out = parseFloat(r.out), one = parseFloat(r.one), back = parseFloat(r.back);
            if (!(out > 0)) return;
            venues[sym] = venues[sym] || {};
            venues[sym][venue] = { out: out, one: one, back: back };
        }
        for (var i = 0; i < coins.length; i++) add(coins[i].symbol, "Wagyu", res[coins[i].key]);
        for (var j = 0; j < markets.length; j++) add(markets[j].symbol, "NonKYC", res[markets[j].key]);
        for (var k = 0; k < cnCoins.length; k++) add(cnCoins[k].symbol, "ChangeNOW", res[cnCoins[k].key]);

        var list = [];
        for (var sym in venues) {
            var v = venues[sym];
            for (var a in v) {
                for (var b in v) {
                    // only between different exchanges, with the price of 1 coin applied to the amount
                    if (a === b || !(v[b].one > 0)) continue;
                    var xmr = v[a].out * v[b].one, exact = false;
                    list.push({ coin: sym, from: a, to: b, out: v[a].out, xmr: xmr, pct: (xmr - 1) * 100, exact: exact,
                                color: coinColor(sym) });
                }
            }
        }
        list.sort(function(x, y) { return y.pct - x.pct; });
        return list;
    }

    function quoteCoin(c) {
        setResult(c.key, { loading: true });
        quote(xmrChainId, xmrToken, c.chainId, c.token, oneXmr, function(q, err) {
            if (!q) {
                setResult(c.key, { loading: false, error: err });
                console.log("Swaps: XMR->" + c.symbol + " failed: " + err);
                done();
                return;
            }
            var out = fromAtomic(q.toAmount, c.decimals);
            setResult(c.key, { out: out, outUsd: q.toAmountUsd });
            // and back: the coin amount we would get -> XMR
            quote(c.chainId, c.token, xmrChainId, xmrToken, q.toAmount, function(q2, err2) {
                if (!q2) {
                    setResult(c.key, { loading: false, error: err2 });
                    console.log("Swaps: " + c.symbol + "->XMR failed: " + err2);
                    done();
                    return;
                }
                var back = fromAtomic(q2.toAmount, 12);
                setResult(c.key, { loading: false, back: back, diff: (parseFloat(back) - 1) * 100, error: "" });
                done();
            });
        });
    }


    // ---- compare with an earlier refresh (from precios-swaps.csv) ----
    readonly property var compareSpans: [
        { label: qsTr("1 h"),     ms: 3600 * 1000 },
        { label: qsTr("24 h"),    ms: 24 * 3600 * 1000 },
        { label: qsTr("7 days"),  ms: 7 * 24 * 3600 * 1000 },
        { label: qsTr("30 days"), ms: 30 * 24 * 3600 * 1000 },
        { label: qsTr("First"),   ms: -1 }
    ]
    property int compareIndex: 1
    property var compareRows: []        // { src, coin, then, now, pct }
    property string compareThen: ""
    property string compareNow: ""

    function loadCompare() {
        compareRows = [];
        compareThen = compareNow = "";
        if (historyPath === "") return;
        var h = SwapHistory.parse(oshelper.readTextFile(historyPath));
        if (h.times.length < 2) return;
        var now = h.times[h.times.length - 1];
        var span = compareSpans[compareIndex].ms;
        var then = span < 0 ? h.times[0] : SwapHistory.snapshotAt(h, now - span);
        if (then === now) then = h.times[h.times.length - 2];
        var past = {};
        h.byTime[then].forEach(function(row) { past[row.src + "/" + row.coin] = row.out; });
        var rows = [];
        h.byTime[now].forEach(function(row) {
            var before = past[row.src + "/" + row.coin];
            if (!(before > 0) || !(row.out > 0)) return;
            rows.push({ src: SwapHistory.sourceName(row.src), coin: row.coin, then: before, now: row.out,
                        pct: (row.out / before - 1) * 100 });
        });
        compareRows = rows;
        compareThen = Qt.formatDateTime(new Date(then), "dd/MM/yyyy hh:mm");
        compareNow = Qt.formatDateTime(new Date(now), "dd/MM/yyyy hh:mm");
    }

    onCompareIndexChanged: loadCompare()

    function onPageCompleted() {
        loadCompare();
        if (Object.keys(results).length === 0 || pending === 0)
            refresh();
    }

    // fixed column widths shared by the header and every row
    readonly property int assetColWidth: 190
    readonly property int diffColWidth: 96

    // one cell with an amount, right aligned, small decimals after the third
    component AmountCell: MoneroComponents.TextPlain {
        property string amount: ""
        property string unit: ""
        property string fallback: "…"
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        horizontalAlignment: Text.AlignRight
        text: amount !== "" ? Utils.prettyAmountRich(amount, Math.round(font.pixelSize * 0.68)) + " <span style=\"font-size:" + Math.round(font.pixelSize * 0.75) + "px\">" + unit + "</span>"
                            : fallback
        textFormat: Text.RichText
        font.family: MoneroComponents.Style.fontMonoMedium.name
        font.pixelSize: 15
        color: MoneroComponents.Style.defaultFontColor
        themeTransition: false
    }

    // column titles
    component HeaderCell: MoneroComponents.TextPlain {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        horizontalAlignment: Text.AlignRight
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 0.8
        font.capitalization: Font.AllUppercase
        color: MoneroComponents.Style.dimmedFontColor
        themeTransition: false
    }

    component HeaderRow: Rectangle {
        property string assetLabel: qsTr("Asset") + translationManager.emptyString
        Layout.fillWidth: true
        implicitHeight: 34
        color: MoneroComponents.Style.blackTheme ? "#0DFFFFFF" : "#0A000000"
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 1
            color: MoneroComponents.Style.orange
            opacity: 0.45
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            HeaderCell {
                Layout.fillWidth: false
                Layout.preferredWidth: pageSwaps.assetColWidth
                horizontalAlignment: Text.AlignLeft
                text: assetLabel
            }
            HeaderCell { text: qsTr("1 coin → XMR") + translationManager.emptyString }
            HeaderCell { text: qsTr("1 XMR → coin") + translationManager.emptyString }
            HeaderCell { text: qsTr("Back to XMR") + translationManager.emptyString }
            HeaderCell {
                Layout.fillWidth: false
                Layout.preferredWidth: pageSwaps.diffColWidth
                text: qsTr("Diff.") + translationManager.emptyString
            }
        }
    }

    // one row: asset | 1 coin -> XMR | 1 XMR -> coin | back to XMR | difference
    component SwapRow: Rectangle {
        id: row
        property var coin
        property int rowIndex: 0
        property var res: pageSwaps.results[coin.key] || {}
        // NonKYC rows show the market pair as title and the volume below
        readonly property bool isMarket: coin.sub !== undefined
        Layout.fillWidth: true
        implicitHeight: 50
        color: rowIndex % 2 === 1 ? (MoneroComponents.Style.blackTheme ? "#08FFFFFF" : "#06000000") : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            RowLayout {
                Layout.preferredWidth: pageSwaps.assetColWidth
                Layout.maximumWidth: pageSwaps.assetColWidth
                spacing: 10
                Rectangle {
                    width: 9; height: 9; radius: 4.5
                    color: coin.color
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: row.isMarket ? coin.name : coin.symbol
                        font.family: MoneroComponents.Style.fontMonoBold.name
                        font.pixelSize: 15
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                    }
                    MoneroComponents.TextPlain {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: row.isMarket ? coin.sub : coin.name
                        font.pixelSize: 11
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                }
            }

            AmountCell {
                amount: res.one !== undefined ? pageSwaps.shortAmount(res.one, 8) : ""
                unit: "XMR"
                fallback: res.oneError ? "error" : "…"
            }
            AmountCell {
                amount: res.out !== undefined ? pageSwaps.shortAmount(res.out, coin.decimals > 8 ? 8 : coin.decimals) : ""
                unit: coin.symbol
                fallback: res.error ? "error" : (res.loading ? "…" : "—")
            }
            AmountCell {
                amount: res.back !== undefined ? pageSwaps.shortAmount(res.back, 8) : ""
                unit: "XMR"
                fallback: res.error ? "error" : (res.loading ? "…" : "—")
            }

            MoneroComponents.TextPlain {
                Layout.preferredWidth: pageSwaps.diffColWidth
                horizontalAlignment: Text.AlignRight
                text: res.diff !== undefined && !isNaN(res.diff) ? (res.diff >= 0 ? "+" : "") + res.diff.toFixed(2) + " %"
                                                                  : (res.error ? "error" : (res.loading ? "…" : "—"))
                font.family: MoneroComponents.Style.fontMonoBold.name
                font.pixelSize: 15
                color: res.diff === undefined || isNaN(res.diff) ? MoneroComponents.Style.dimmedFontColor
                       : res.diff >= -1 ? (MoneroComponents.Style.blackTheme ? "#5FD08F" : "#1E8E4E")
                       : res.diff >= -3 ? (MoneroComponents.Style.blackTheme ? "#FFC23D" : "#A86F00")
                       : (MoneroComponents.Style.blackTheme ? "#FF5C5C" : "#C62828")
                themeTransition: false
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: MoneroComponents.Style.defaultFontColor
            opacity: 0.07
        }
    }

    // a table card: title + source on the right, header, rows, note below
    component SwapTable: Item {
        id: table
        property string title
        property string source
        property string note
        property var model: []
        property string emptyText: "…"
        Layout.fillWidth: true
        implicitHeight: tableCol.implicitHeight + 30
        MoneroComponents.CardPanel { anchors.fill: parent }
        ColumnLayout {
            id: tableCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 0
            RowLayout {
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                MoneroComponents.SectionTitle {
                    Layout.fillWidth: true
                    text: table.title
                }
                MoneroComponents.TextPlain {
                    text: table.source
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }
            HeaderRow { }
            Repeater {
                model: table.model
                delegate: SwapRow { coin: modelData; rowIndex: index }
            }
            MoneroComponents.TextPlain {
                visible: table.model.length === 0
                Layout.leftMargin: 16
                Layout.topMargin: 12
                text: table.emptyText
                font.pixelSize: 13
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 10
                wrapMode: Text.WordWrap
                text: table.note
                font.pixelSize: 11
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }
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

        MoneroComponents.MarketsNavbar { current: "Swaps" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MoneroComponents.LabelSubheader {
                Layout.fillWidth: true
                fontSize: 24
                text: qsTr("Swaps") + translationManager.emptyString
            }

            MoneroComponents.TextPlain {
                text: pageSwaps.pending > 0 ? (qsTr("Updating…") + translationManager.emptyString)
                                            : (pageSwaps.lastUpdate !== "" ? qsTr("Updated %1").arg(pageSwaps.lastUpdate) + translationManager.emptyString : "")
                font.pixelSize: 12
                color: MoneroComponents.Style.dimmedFontColor
                themeTransition: false
            }

            MoneroComponents.StandardButton {
                small: true
                enabled: pageSwaps.pending === 0 && pageSwaps.pricesEnabled
                text: qsTr("Refresh") + translationManager.emptyString
                onClicked: pageSwaps.refresh()
            }
        }

        // price conversion off: nothing is asked to the exchanges
        RowLayout {
            visible: !pageSwaps.pricesEnabled
            Layout.fillWidth: true
            spacing: 16

            MoneroComponents.TextPlain {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Swap prices are off. They are turned on together with the price conversion in Settings > Node / Network.") + translationManager.emptyString
                font.pixelSize: 14
                color: MoneroComponents.Style.defaultFontColor
                themeTransition: false
            }

            MoneroComponents.StandardButton {
                small: true
                text: qsTr("Open settings") + translationManager.emptyString
                onClicked: {
                    middlePanel.settingsView.settingsStateViewState = "Node";
                    appWindow.showPageRequest("Settings");
                }
            }
        }

        MoneroComponents.TextPlain {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("What you get for swapping 1 unit of each coin to XMR, for swapping 1 XMR to the coin, and for swapping that result back to XMR. The difference is what you would lose (or gain) on the round trip.") + translationManager.emptyString
            font.pixelSize: 13
            color: MoneroComponents.Style.dimmedFontColor
            themeTransition: false
        }

        SwapTable {
            title: "Wagyu"
            source: "wagyu.xyz"
            model: pageSwaps.coins
            note: qsTr("Swap quotes with fees included. Each refresh sends %1 requests to Wagyu.").arg(pageSwaps.coins.length * 3) + translationManager.emptyString
        }

        SwapTable {
            title: "NonKYC"
            source: "nonkyc.io"
            model: pageSwaps.nkMarkets
            emptyText: pageSwaps.nkError !== "" ? "error: " + pageSwaps.nkError : "…"
            note: qsTr("Best bid and ask of its primary XMR markets (1 request). Trading fees are not included and only small amounts fill at these prices; the difference is the bid/ask spread.") + translationManager.emptyString
        }

        SwapTable {
            title: "ChangeNOW"
            source: "changenow.io"
            model: pageSwaps.cnCoins
            note: (pageSwaps.cnError !== "" ? qsTr("Last error: %1").arg(pageSwaps.cnError) + " · " : "")
                  + qsTr("Estimated amounts of the standard flow, fees included. Stablecoins are measured on 100 units (below that is under ChangeNOW's minimum). Each refresh sends %1 requests to ChangeNOW.").arg(pageSwaps.cnCoins.length * 3) + translationManager.emptyString
        }

        // routes ranked by result
        Item {
            Layout.fillWidth: true
            implicitHeight: routesCol.implicitHeight + 30
            MoneroComponents.CardPanel { anchors.fill: parent }
            ColumnLayout {
                id: routesCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 16
                spacing: 0
                RowLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 10
                    Layout.fillWidth: true
                    MoneroComponents.SectionTitle {
                        Layout.fillWidth: true
                        text: qsTr("Best routes") + translationManager.emptyString
                    }
                    MoneroComponents.TextPlain {
                        text: qsTr("1 XMR → coin → XMR") + translationManager.emptyString
                        font.family: MoneroComponents.Style.fontMonoRegular.name
                        font.pixelSize: 11
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    color: MoneroComponents.Style.blackTheme ? "#0DFFFFFF" : "#0A000000"
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                        height: 1
                        color: MoneroComponents.Style.orange
                        opacity: 0.45
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        HeaderCell { Layout.fillWidth: false; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignLeft; text: "#" }
                        HeaderCell { Layout.fillWidth: false; Layout.preferredWidth: pageSwaps.assetColWidth - 40; horizontalAlignment: Text.AlignLeft; text: qsTr("Coin") + translationManager.emptyString }
                        HeaderCell { horizontalAlignment: Text.AlignLeft; text: qsTr("XMR → coin") + translationManager.emptyString }
                        HeaderCell { horizontalAlignment: Text.AlignLeft; text: qsTr("Coin → XMR") + translationManager.emptyString }
                        HeaderCell { text: qsTr("You end with") + translationManager.emptyString }
                        HeaderCell { Layout.fillWidth: false; Layout.preferredWidth: pageSwaps.diffColWidth; text: qsTr("Result") + translationManager.emptyString }
                    }
                }
                Repeater {
                    model: pageSwaps.routes
                    delegate: Rectangle {
                        id: routeRow
                        readonly property bool top3: index < 3
                        Layout.fillWidth: true
                        implicitHeight: 44
                        color: top3 ? (MoneroComponents.Style.blackTheme ? "#1400FF41" : "#1400A82D")
                             : index % 2 === 1 ? (MoneroComponents.Style.blackTheme ? "#08FFFFFF" : "#06000000") : "transparent"
                        Rectangle {
                            visible: routeRow.top3
                            width: 3; height: parent.height
                            color: MoneroComponents.Style.orange
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12
                            MoneroComponents.TextPlain {
                                Layout.preferredWidth: 28
                                text: index + 1
                                font.family: MoneroComponents.Style.fontMonoBold.name
                                font.pixelSize: 14
                                color: routeRow.top3 ? MoneroComponents.Style.defaultFontColor : MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                            RowLayout {
                                Layout.preferredWidth: pageSwaps.assetColWidth - 40
                                Layout.maximumWidth: pageSwaps.assetColWidth - 40
                                spacing: 10
                                Rectangle { width: 9; height: 9; radius: 4.5; color: modelData.color }
                                MoneroComponents.TextPlain {
                                    Layout.fillWidth: true
                                    text: modelData.coin
                                    font.family: MoneroComponents.Style.fontMonoBold.name
                                    font.pixelSize: 15
                                    color: MoneroComponents.Style.defaultFontColor
                                    themeTransition: false
                                }
                            }
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                text: modelData.from
                                font.pixelSize: 14
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                            }
                            MoneroComponents.TextPlain {
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                text: modelData.to
                                font.pixelSize: 14
                                color: MoneroComponents.Style.defaultFontColor
                                themeTransition: false
                            }
                            AmountCell {
                                amount: pageSwaps.shortAmount(modelData.xmr, 8)
                                unit: "XMR"
                            }
                            MoneroComponents.TextPlain {
                                Layout.preferredWidth: pageSwaps.diffColWidth
                                horizontalAlignment: Text.AlignRight
                                text: (modelData.pct >= 0 ? "+" : "") + modelData.pct.toFixed(2) + " %"
                                font.family: MoneroComponents.Style.fontMonoBold.name
                                font.pixelSize: 15
                                color: modelData.pct >= -1 ? (MoneroComponents.Style.blackTheme ? "#5FD08F" : "#1E8E4E")
                                     : modelData.pct >= -3 ? (MoneroComponents.Style.blackTheme ? "#FFC23D" : "#A86F00")
                                     : (MoneroComponents.Style.blackTheme ? "#FF5C5C" : "#C62828")
                                themeTransition: false
                            }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                            height: 1
                            color: MoneroComponents.Style.defaultFontColor
                            opacity: 0.07
                        }
                    }
                }
                MoneroComponents.TextPlain {
                    visible: pageSwaps.routes.length === 0
                    Layout.leftMargin: 16
                    Layout.topMargin: 12
                    text: "…"
                    font.pixelSize: 13
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 10
                    wrapMode: Text.WordWrap
                    text: qsTr("Turning 1 XMR into a coin on one exchange and back into XMR on the other, with the prices of this refresh, best first. The top 3 are highlighted. Estimated with the price for 1 coin on the second exchange. Not included: NonKYC trading fees, deposit and withdrawal fees between exchanges, and the time the transfers take (prices move meanwhile).") + translationManager.emptyString
                    font.pixelSize: 11
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
            }
        }

        // compare the last refresh with an earlier one
        Item {
            Layout.fillWidth: true
            visible: pageSwaps.historyPath !== ""
            implicitHeight: cmpCol.implicitHeight + 32
            MoneroComponents.CardPanel { anchors.fill: parent }
            ColumnLayout {
                id: cmpCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    MoneroComponents.SectionTitle {
                        Layout.fillWidth: true
                        text: qsTr("Compare with an earlier date") + translationManager.emptyString
                    }
                    Repeater {
                        model: pageSwaps.compareSpans
                        delegate: Item {
                            readonly property bool on: index === pageSwaps.compareIndex
                            width: Math.max(56, spanText.implicitWidth + 22)
                            height: 30
                            MoneroComponents.NeonFrame {
                                anchors.fill: parent
                                cut: 6
                                accent: MoneroComponents.Style.blackTheme ? "#E8ECE9" : "#2B3A30"
                                lineOpacity: parent.on ? 0.95 : (spanArea.containsMouse ? 0.6 : 0.3)
                                fillColor: accent
                                fillOpacity: parent.on ? 0.12 : 0.0
                                ticks: false
                            }
                            MoneroComponents.TextPlain {
                                id: spanText
                                anchors.centerIn: parent
                                text: modelData.label + translationManager.emptyString
                                font.family: MoneroComponents.Style.fontMonoMedium.name
                                font.pixelSize: 12
                                font.bold: true
                                color: parent.on ? MoneroComponents.Style.textAccent : MoneroComponents.Style.dimmedFontColor
                                themeTransition: false
                            }
                            MouseArea {
                                id: spanArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pageSwaps.compareIndex = index
                            }
                        }
                    }
                }

                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: pageSwaps.compareRows.length > 0
                          ? qsTr("XMR → coin for 1 XMR on %1 compared with the last refresh (%2). Green: you get more coin now.").arg(pageSwaps.compareThen).arg(pageSwaps.compareNow) + translationManager.emptyString
                          : qsTr("Needs at least two refreshes saved in precios-swaps.csv.") + translationManager.emptyString
                    font.pixelSize: 12
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }

                GridLayout {
                    Layout.fillWidth: true
                    visible: pageSwaps.compareRows.length > 0
                    columns: 5
                    columnSpacing: 12
                    rowSpacing: 5
                    Repeater {
                        model: [qsTr("Exchange"), qsTr("Coin"), qsTr("Then"), qsTr("Now"), qsTr("Change")]
                        delegate: MoneroComponents.TextPlain {
                            Layout.fillWidth: true
                            horizontalAlignment: index < 2 ? Text.AlignLeft : Text.AlignRight
                            text: modelData + translationManager.emptyString
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 11
                            color: MoneroComponents.Style.dimmedFontColor
                            themeTransition: false
                        }
                    }
                    Repeater {
                        model: pageSwaps.compareRows.length * 5
                        delegate: MoneroComponents.TextPlain {
                            readonly property var row: pageSwaps.compareRows[Math.floor(index / 5)]
                            readonly property int col: index % 5
                            Layout.fillWidth: true
                            horizontalAlignment: col < 2 ? Text.AlignLeft : Text.AlignRight
                            text: !row ? "" : col === 0 ? row.src : col === 1 ? row.coin
                                  : col === 2 ? row.then.toPrecision(6) : col === 3 ? row.now.toPrecision(6)
                                  : (row.pct >= 0 ? "+" : "") + row.pct.toFixed(2) + " %"
                            font.family: MoneroComponents.Style.fontMonoMedium.name
                            font.pixelSize: 13
                            color: col === 4 && row ? (row.pct > 0 ? "#3DDC84" : row.pct < 0 ? "#FF5A5A" : MoneroComponents.Style.defaultFontColor)
                                                    : MoneroComponents.Style.defaultFontColor
                            themeTransition: false
                        }
                    }
                }
            }
        }

        // price history file
        Item {
            Layout.fillWidth: true
            visible: pageSwaps.historyPath !== ""
            implicitHeight: histCol.implicitHeight + 32
            MoneroComponents.CardPanel { anchors.fill: parent }
            ColumnLayout {
                id: histCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    MoneroComponents.SectionTitle {
                        Layout.fillWidth: true
                        text: qsTr("Price history") + translationManager.emptyString
                    }
                    MoneroComponents.TextPlain {
                        text: pageSwaps.historyStatus
                        font.pixelSize: 12
                        color: MoneroComponents.Style.dimmedFontColor
                        themeTransition: false
                    }
                    MoneroComponents.StandardButton {
                        small: true
                        text: qsTr("Open folder") + translationManager.emptyString
                        onClicked: oshelper.openFolder(pageSwaps.historyPath.substring(0, pageSwaps.historyPath.lastIndexOf("/")))
                    }
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("Every refresh adds one line per coin and market to precios-swaps.csv, and the ranked routes to rutas-swaps.csv, with the date and time (UTC). Open them with Numbers or Excel, or import them into a database, to compare prices between dates.") + translationManager.emptyString
                    font.pixelSize: 13
                    color: MoneroComponents.Style.dimmedFontColor
                    themeTransition: false
                }
                MoneroComponents.TextPlain {
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    text: pageSwaps.historyPath.substring(0, pageSwaps.historyPath.lastIndexOf("/") + 1)
                    font.family: MoneroComponents.Style.fontMonoRegular.name
                    font.pixelSize: 12
                    color: MoneroComponents.Style.defaultFontColor
                    themeTransition: false
                }
            }
        }
    }
}
