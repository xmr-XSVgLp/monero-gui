const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const main=fs.readFileSync('main.qml','utf8'),account=fs.readFileSync('pages/Account.qml','utf8');
function extract(s,n){const start=s.indexOf('    function '+n+'(');assert(start>=0);return s.slice(start,s.indexOf('\n    }',start)+6);}
let selected=0;
const balances=[12,3],unlocked=[10,2];
const c={currentWallet:{balance:()=>balances[selected],unlockedBalance:()=>unlocked[selected],history:{minutesToUnlock:'20'}},hideBalanceForced:false,persistentSettings:{hideBalance:false,fiatPriceEnabled:true},walletManager:{displayAmount:v=>String(v)},leftPanel:{},middlePanel:{state:'Transfer'},fiatApiUpdateBalance(v){this.fiat=v;}};c.appWindow=c;
vm.createContext(c);vm.runInContext(extract(main,'updateBalance'),c);
const handler=main.match(/function onCurrentSubaddressAccountChanged\(\) \{([^}]+)\}/);assert(handler);
vm.runInContext('function accountChanged(){'+handler[1]+'}',c);
c.accountChanged();assert.equal(c.leftPanel.balanceString,'12');
selected=1;c.accountChanged();assert.equal(c.leftPanel.balanceString,'3');assert.equal(c.leftPanel.balanceUnlockedString,'2');assert.equal(c.fiat,'3');
c.persistentSettings.hideBalance=true;c.accountChanged();assert.equal(c.leftPanel.balanceString,'?.??');
c.currentWallet=null;c.accountChanged();
// The asynchronous trim callback is the only scope with a captured variable named w.
assert.equal((account.match(/currentWallet !== w/g)||[]).length,1);
assert.match(account,/onCurrentIndexChanged: subaddressAccountListRow.balanceTick\+\+/);
console.log('PASS: account-change signal updates total, unlocked and fiat balances synchronously; respects hidden balance; no stale w references');
