const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const main=fs.readFileSync('main.qml','utf8'), trading=fs.readFileSync('pages/TradingData.qml','utf8');
function fn(text,n){const a=text.indexOf('    function '+n+'(');return text.slice(a,text.indexOf('\n    }',a)+6);}
let symbol='USD',updates=0;
const c={fiatPriceUSD:200,fiatRates:{USD:1,EUR:0.9},fiatRates7d:{},fiatPriceUSD7d:0,fiatPriceUSD24h:0,fiatApiCurrencySymbol:()=>symbol,updateBalance:()=>updates++,fiatCacheSave:()=>{}};
c.appWindow=c;vm.createContext(c);vm.runInContext(fn(main,'fiatApiUpdatePrice'),c);
c.fiatApiUpdatePrice();assert.equal(c.fiatPrice,200);
symbol='EUR';c.fiatApiUpdatePrice();assert.equal(c.fiatPrice,180);
symbol='GBP';c.fiatApiUpdatePrice();assert.equal(c.fiatPrice,0);assert.equal(updates,3);
let source='kraken',selected;
const m={failed:{},pairs:[{key:'USD',pair:'usd'},{key:'EUR',pair:'eur'}],sources:[{key:'kraken'},{key:'coingecko'}],queue:[],alertsCard:{newPair:0},appWindow:{fiatApiCurrencySymbol:()=>symbol,historicalPriceSource:()=>source,priceSourceEnabled:()=>true},loadSaved(){},select(){selected=m.sources[m.sourceIndex].key+':'+m.pairs[m.pairIndex].pair},keyFor:(src,pair,d)=>src+':'+pair+'/'+d,isStale:()=>false,enqueue(){throw Error('Fresh cache should not request network')}};
vm.createContext(m);vm.runInContext(fn(trading,'applyPreferences'),m);
symbol='EUR';m.applyPreferences();assert.equal(selected,'kraken:eur');source='coingecko';symbol='USD';m.applyPreferences();assert.equal(selected,'coingecko:usd');
console.log('PASS: balance conversion and chart source/currency switch without reopening; missing rates clear old values');
