const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
function source(f){return fs.readFileSync(f,'utf8');}
function extract(s,n){let a=s.indexOf('    function '+n+'(');assert(a>=0,n);return s.slice(a,s.indexOf('\n    }',a)+6);}
// A result from the previous notes file cannot unlock or overwrite the new editor.
let unlockReply, saveReply;
const n={walletGeneration:1,busy:false,unlocked:false,currentWallet:{notesUnlockAsync(p,cb){unlockReply=cb;},notesSaveAsync(p,cb){saveReply=cb;}},appWindow:{walletPassword:'test'},notes:[],error:'',select(){throw Error('old editor populated');}};
vm.createContext(n);vm.runInContext(['unlock','save'].map(x=>extract(source('pages/Notes.qml'),x)).join('\n'),n);
n.unlock();n.walletGeneration++;n.busy=false;unlockReply(true,'{"notes":[{"title":"old"}]}','');assert.equal(n.unlocked,false);assert.equal(n.notes.length,0);
n.unlocked=true;n.save();n.walletGeneration++;n.saving=false;n.error='new wallet';saveReply(false,'old error');assert.equal(n.error,'new wallet');assert.equal(n.saving,false);
// Mining completion from an old wallet must not restore its results after a switch.
let reply;
const m={currentWallet:{findAddressesAsync(...args){reply=args.at(-1);}},walletGeneration:1,busy:false,pattern:'abc',rangeOk:true,atStart:{checked:false},atEnd:{checked:true},anywhere:{checked:false},ignoreCase:{checked:true},clock:{},endless:false,accounts:1,perAccount:10};
vm.createContext(m);vm.runInContext(extract(source('pages/CustomAddresses.qml'),'search'),m);m.search();m.walletGeneration++;m.results=[];m.busy=false;reply('[{"address":"old"}]',10,false);assert.equal(m.results.length,0);assert.equal(m.busy,false);
// An outstanding node request cannot repaint a different wallet's security page.
let nodeReply;
const s={requestGeneration:0,nodeInfo:null,nodeError:'',persistentSettings:{useRemoteNode:false},appWindow:{daemonRunning:true,localDaemonAddress:'localhost'},oshelper:{nodeRpc(...args){nodeReply=args.at(-1);}}};
vm.createContext(s);vm.runInContext(extract(source('pages/security/SecurityCenter.qml'),'loadNode'),s);s.loadNode();s.requestGeneration++;nodeReply(true,1,'{"old":true}','');assert.equal(s.nodeInfo,null);
// Clear every persisted wallet page, and leave Keys so the new seed requires authentication.
const cleared=[];const p={currentView:null,state:'Keys'};for(const name of ['transferView','receiveView','historyView','addressBookView','advancedView','keysView','merchantView'])p[name]={clearFields(){cleared.push(name);}};
p.addressBookView.onPageClosed=()=>{};
p.historyView.clearTransactions=()=>cleared.push('transactions');p.currentView=p.keysView;
vm.createContext(p);vm.runInContext(extract(source('MiddlePanel.qml'),'clearWalletPages'),p);p.clearWalletPages();assert.equal(cleared.length,8);assert.equal(p.state,'Settings');
for(const file of ['pages/settings/SettingsWallet.qml','pages/settings/SettingsInfo.qml'])assert.match(source(file),/appWindow.currentWallet !== owner/);
assert.match(source('pages/security/SecurityCenter.qml'),/ownerPath !== tab.walletPath/);
console.log('PASS: stale notes/mining/security callbacks ignored; all wallet pages cleared; keys authentication and action ownership protected');
