.pragma library

// CoinGecko samples, in seconds. Do not extrapolate through gaps or beyond coverage.
function compare(cache, pair, timestamp, now, source) {
    if (source === undefined) source = "coingecko";
    if (!source) return {historical:null, latest:null, change:null};
    var prefix = source === "coingecko" ? "" : source + ":";
    var historical = null, latest = null;
    [1, 90, 365].forEach(function(days) {
        var series = cache[prefix + pair + "/" + days];
        var points = series ? series.prices : [];
        if (!points || !points.length) return;
        var last = points[points.length - 1];
        if (valid(last) && last[0] <= now && (!latest || last[0] > latest[0])) latest = last;
        if (!(timestamp > 0) || timestamp > now) return;
        var low = 0, high = points.length;
        while (low < high) {
            var mid = Math.floor((low + high) / 2);
            if (points[mid][0] <= timestamp) low = mid + 1; else high = mid;
        }
        var p = low > 0 ? points[low - 1] : null;
        var tolerance = days === 1 ? 1800 : days === 90 ? (source === "coingecko" ? 7200 : 21600) : 86400;
        if (valid(p) && timestamp - p[0] <= tolerance && (!historical || p[0] > historical[0])) historical = p;
    });
    return {historical: historical, latest: latest,
        change: historical && latest && latest[0] >= timestamp ? (latest[1] / historical[1] - 1) * 100 : null};
}
function valid(point) {
    return point && isFinite(point[0]) && point[0] > 0 && isFinite(point[1]) && point[1] > 0;
}

function value(point, amount) {
    return valid(point) && isFinite(amount) ? Math.abs(amount) * point[1] : null;
}
