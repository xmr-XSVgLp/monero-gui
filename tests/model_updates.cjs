const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
function read(f){return fs.readFileSync(f,'utf8');}
function extract(s,n){const a=s.indexOf('    function '+n+'(');assert(a>=0,n);return s.slice(a,s.indexOf('\n    }',a)+6);}
const history=read('pages/History.qml');let copies=0,filters=0,page=0;
const h={initialized:true,model:{},appWindow:{currentWallet:{}},txPage:4,txMax:5,txCount:7,updateTransactionsFromModel(){copies++;},updateFilter(){filters++;},paginationJump(p){page=p;}};h.root=h;
vm.createContext(h);vm.runInContext(extract(history,'syncModelRows'),h);h.syncModelRows();assert.equal(copies,1);assert.equal(filters,1);assert.equal(page,2,'clamp page after deleting rows');
h.txCount=0;h.syncModelRows();assert.equal(page,1);h.appWindow.currentWallet=null;h.syncModelRows();assert.equal(copies,2,'ignore queued updates after close');
// Selected receive label and address follow the current account using local data.
let label='renamed',account=1;
const w={get currentSubaddressAccount(){return account;},numSubaddresses:()=>2,address:(a,i)=>a+':'+i,getSubaddressLabel:()=>label};
const r={appWindow:{currentWallet:w},subaddressListView:{currentIndex:1},selectedAddressDrescription:{},qsTr:s=>s,translationManager:{emptyString:''}};
vm.createContext(r);vm.runInContext(extract(read('pages/Receive.qml'),'updateSelectedAddressDisplay'),r);r.updateSelectedAddressDisplay();assert.equal(r.selectedAddressDrescription.text,'renamed');assert.equal(r.appWindow.current_address,'1:1');
label='new label';r.updateSelectedAddressDisplay();assert.equal(r.selectedAddressDrescription.text,'new label');
account=2;r.subaddressListView.currentIndex=0;r.updateSelectedAddressDisplay();assert.equal(r.appWindow.current_address,'2:0');r.appWindow.currentWallet=null;r.updateSelectedAddressDisplay();
assert.match(history,/onModelReset\(\).*Qt.callLater\(root.syncModelRows\)/);
assert.match(read('pages/TradingData.qml'),/onModelReset\(\).*Qt.callLater\(pageTrading.loadBalanceEvents\)/);
console.log('PASS: local model changes rebuild history without refresh; pagination clamped; receiving address and label update immediately');
