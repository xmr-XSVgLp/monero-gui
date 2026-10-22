const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
function moduleFrom(path){const c={};vm.createContext(c);vm.runInContext(fs.readFileSync(path,'utf8').replace('.pragma library',''),c);return c;}
const policy=moduleFrom('js/PriceSources.js'),prices=moduleFrom('js/TransactionPrices.js');
assert.equal(policy.sourceForUrl('https://api.kraken.com/0/public/Ticker'),'kraken');
assert.equal(policy.sourceForUrl('https://api.kraken.com.attacker.test/test'),'');
assert.equal(policy.sourceForUrl('http://api.kraken.com/test'),'');
assert.equal(policy.historySource('{}','coinpaprika','eur'),'kraken');
assert.equal(policy.historySource('{}','kraken','gbp'),'coingecko');
assert.equal(policy.historySource('{"coingecko":false}','kraken','gbp'),'');
assert.equal(policy.historySource(JSON.stringify(Object.fromEntries(policy.catalog.map(s=>[s.key,false]))),'kraken','usd'),'');
assert.notEqual(policy.historySource('{}','kucoin','eur'),'kucoin','do not use today FX for historical EUR');
const cache={'usd/1':{prices:[[1000,100],[1100,200]]},'kraken:usd/1':{prices:[[1000,50],[1100,60]]}};
const q=prices.compare(cache,'usd',1001,1200,'kraken');assert.equal(q.historical[1],50);assert.equal(q.latest[1],60);
assert.equal(prices.value(q.historical,2.5),125);assert.equal(prices.value(q.latest,-2.5),150);assert.equal(prices.value(null,2.5),null);assert.equal(prices.value(q.latest,0),0);
assert.equal(prices.compare(cache,'eur',1001,1200,'kraken').historical,null);
const main=fs.readFileSync('main.qml','utf8');
function extract(n){let a=main.indexOf('    function '+n+'(');return main.slice(a,main.indexOf('\n    }',a)+6);}
let calls=0,reply,output;
const c={PriceSources:policy,persistentSettings:{fiatPriceEnabled:true,priceSourcesJson:'{}'},priceSourceEnabled(k){return policy.enabled(c.persistentSettings.priceSourcesJson,k)},network:{getJSON(url,cb){calls++;reply=cb;},postJSON(url,body,cb){calls++;reply=cb;}}};
vm.createContext(c);vm.runInContext(['priceRequestAllowed','priceGetJSON','pricePostJSON'].map(extract).join('\n'),c);
const url='https://api.kraken.com/0/public/Ticker';
c.priceGetJSON(url,(u,r,e)=>output={r,e});assert.equal(calls,1);
c.persistentSettings.priceSourcesJson='{"kraken":false}';reply(url,'old prices','');assert.equal(output.r,'');assert(output.e);
c.priceGetJSON(url,(u,r,e)=>output={r,e});assert.equal(calls,1);assert(output.e);
c.persistentSettings.fiatPriceEnabled=false;c.pricePostJSON('https://api-beta.wagyu.xyz/v2/swaps/quote','{}',()=>{});assert.equal(calls,1);
console.log('PASS: sources disabled before dispatch and after reply; primary-history fallback; currency/source isolation; transaction amount valuation');

// Persisted favorites keep at least one currency and move the primary if removed.
c.persistentSettings.favoriteCurrenciesJson='["USD","EUR"]';
c.persistentSettings.fiatPriceCurrency='xmrusd';
Object.defineProperty(c,'favoriteCurrencies',{get(){return JSON.parse(c.persistentSettings.favoriteCurrenciesJson);}});
c.fiatApiCurrencySymbol=()=>c.persistentSettings.fiatPriceCurrency.slice(3).toUpperCase();
vm.runInContext(extract('setFavoriteCurrency'),c);
c.setFavoriteCurrency('USD',false);assert.equal(c.persistentSettings.fiatPriceCurrency,'xmreur');
c.setFavoriteCurrency('EUR',false);assert.equal(c.favoriteCurrencies.length,1);
c.setFavoriteCurrency('BTC',true);assert.deepEqual(c.favoriteCurrencies,['EUR','BTC']);
console.log('PASS: favorite currencies persist, cannot all be removed, and primary follows removal');

// Switching providers restores only their own cached ticker, immediately.
const live={persistentSettings:{fiatPriceProvider:'kraken'},fiatTickers:{},fiatPriceUSD:200,fiatPriceUSD7d:180,fiatPriceUSD24h:190,fiatHistoryTimestamp:123};
live.appWindow=live;
vm.createContext(live);
vm.runInContext(['rememberFiatTicker','restoreFiatTicker','fiatApiHistoryReceived'].map(extract).join('\n'),live);
live.rememberFiatTicker();
live.persistentSettings.fiatPriceProvider='coinpaprika';live.restoreFiatTicker();
assert.equal(live.fiatPriceUSD,0,'never display previous provider as new provider');
live.fiatPriceUSD=240;live.fiatPriceUSD7d=220;live.fiatPriceUSD24h=230;live.rememberFiatTicker();
live.persistentSettings.fiatPriceProvider='kraken';live.restoreFiatTicker();
assert.equal(live.fiatPriceUSD,200);assert.equal(live.fiatPriceUSD7d,180);assert.equal(live.fiatHistoryTimestamp,0);
live.persistentSettings.fiatPriceProvider='coinpaprika';live.restoreFiatTicker();
live.fiatApiHistoryReceived('old Kraken request','invalid JSON','');
assert.equal(live.fiatPriceUSD7d,220,'late Kraken history cannot overwrite CoinPaprika');
console.log('PASS: immediate provider cache switches and late history isolation');
