.pragma library
var catalog = [
    {key:"kraken", name:"Kraken", host:"api.kraken.com", ticker:true, history:true, use:"Precio actual y gráficos"},
    {key:"coingecko", name:"CoinGecko", host:"api.coingecko.com", ticker:true, history:true, use:"Precio actual e histórico en varias monedas"},
    {key:"coinpaprika", name:"CoinPaprika", host:"api.coinpaprika.com", ticker:true, history:false, use:"Precio actual; sin series históricas en esta app"},
    {key:"kucoin", name:"KuCoin", host:"api.kucoin.com", ticker:false, history:true, use:"Gráficos de mercado; USD aproximado mediante USDT"},
    {key:"coinmarketcap", name:"CoinMarketCap", host:"api.coinmarketcap.com", ticker:false, history:true, use:"Gráficos de mercado"},
    {key:"frankfurter", name:"Frankfurter", host:"api.frankfurter.dev", ticker:false, history:false, use:"Tipos de cambio de monedas de valoración"},
    {key:"wagyu", name:"Wagyu", host:"api-beta.wagyu.xyz", ticker:false, history:false, use:"Cotizaciones de swaps"},
    {key:"nonkyc", name:"NonKYC", host:"api.nonkyc.io", ticker:false, history:false, use:"Precios de compra y venta"},
    {key:"changenow", name:"ChangeNOW", host:"api.changenow.io", ticker:false, history:false, use:"Cotizaciones de swaps"},
    {key:"moneropricenow", name:"MoneroPriceNow", host:"moneropricenow.com", ticker:false, history:false, use:"Comparación de swaps"}
];
function enabled(settings, key) {
    try { return JSON.parse(settings || "{}")[key] !== false; } catch (e) { return true; }
}
function sourceForUrl(url) {
    var match = /^https:\/\/([^/:?#]+)/i.exec(url);
    if (!match) return "";
    for (var i=0;i<catalog.length;i++) if(catalog[i].host === match[1].toLowerCase()) return catalog[i].key;
    return "";
}
function supportsPair(source, pair) {
    return source === "coingecko" || ["usd","eur","btc"].indexOf(pair) >= 0;
}
function historySource(settings, primary, pair) {
    var choices = catalog.filter(function(s) {
        return s.history && enabled(settings,s.key) && supportsPair(s.key,pair)
            && !(s.key === "kucoin" && pair !== "btc");
    });
    for (var i=0;i<choices.length;i++) if(choices[i].key === primary) return primary;
    return choices.length ? choices[0].key : "";
}
