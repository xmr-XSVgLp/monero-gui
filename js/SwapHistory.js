.pragma library

// Reads ~/Monero/xmr-wallet-plus/precios-swaps.csv (written by pages/Swaps.qml after every refresh).
// Columns: fecha_utc,fuente,mercado,moneda,swap_1_moneda_a_xmr,swap_1_xmr_a_moneda,vuelta_a_xmr,...
// Returns { times: [ms, ...] oldest first, byTime: { ms: [ { src, market, coin, one, out }, ... ] } }
function parse(text) {
    var byTime = {};
    var times = [];
    var lines = (text || "").split("\n");
    for (var i = 1; i < lines.length; i++) {
        if (lines[i] === "")
            continue;
        var f = lines[i].split(",");
        if (f.length < 6)
            continue;
        var t = Date.parse(f[0]);
        if (isNaN(t))
            continue;
        if (!byTime[t]) {
            byTime[t] = [];
            times.push(t);
        }
        byTime[t].push({ src: f[1], market: f[2], coin: f[3], one: parseFloat(f[4]), out: parseFloat(f[5]) });
    }
    times.sort(function(a, b) { return a - b; });
    return { times: times, byTime: byTime };
}

// newest snapshot taken at or before `ms` (or the oldest one when all are newer)
function snapshotAt(history, ms) {
    var best = history.times.length > 0 ? history.times[0] : 0;
    for (var i = 0; i < history.times.length; i++) {
        if (history.times[i] <= ms)
            best = history.times[i];
    }
    return best;
}

function sourceName(src) {
    return { wagyu: "Wagyu", nonkyc: "NonKYC", changenow: "ChangeNOW" }[src] || src;
}
