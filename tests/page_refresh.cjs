const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const history=fs.readFileSync('pages/History.qml','utf8');
const accounts=fs.readFileSync('pages/Account.qml','utf8');
function extract(s,n){let a=s.indexOf('    function '+n+'(');assert(a>=0);return s.slice(a,s.indexOf('\n    }',a)+6);}
let cleared=0;
const c={txModelData:[{hash:'old'}],txData:[{hash:'old'}],txDataCollapsed:['old'],txCount:1,txOffset:10,txListViewModel:{clear(){cleared++;}},currentWallet:null,model:null};c.root=c;
vm.createContext(c);vm.runInContext(['clearTransactions','updateTransactionsFromModel','update'].map(n=>extract(history,n)).join('\n'),c);
c.update();assert.equal(c.txData.length,0);assert.equal(c.txCount,0);assert.equal(c.txOffset,0);assert.equal(c.txDataCollapsed.length,0);assert.equal(cleared,1);
c.currentWallet={history:{},isBackgroundSyncing:()=>true};c.model={};c.txModelData=[{hash:'old'}];c.updateTransactionsFromModel();assert.equal(c.txModelData.length,0);
assert.match(history,/readonly property var model: appWindow.currentWallet \? appWindow.currentWallet.historyModel : null/);
assert.match(history,/onModelChanged: \{ walletGeneration\+\+; clearTransactions\(\); \}/);
let refreshed=0,updated=0;
const w={currentSubaddressAccount:0,trimUnusedAccountsAsync(k,cb){cb(2,1,'');},subaddressAccount:{refresh(){refreshed++;}},subaddress:{refresh(){}},startRefresh(){}};
const a={trimming:false,qsTr:s=>s,translationManager:{emptyString:''},confirmationDialog:{open(){}},subaddressAccountListRow:{balanceTick:0},appWindow:{currentWallet:w,rewatchMinedAddresses(){},onWalletUpdate(){updated++;},showStatusMessage(){}}};
vm.createContext(a);vm.runInContext("String.prototype.arg=function(v){return this.replace(/%[12]/,v)};"+extract(accounts,'trimEmptyAccounts'),a);
a.trimEmptyAccounts();a.confirmationDialog.onAcceptedCallback();assert.equal(refreshed,1);assert.equal(updated,1);assert.equal(a.subaddressAccountListRow.balanceTick,1);
console.log('PASS: clear old transaction rows, null/background wallet, bound history model, immediate account refresh');
