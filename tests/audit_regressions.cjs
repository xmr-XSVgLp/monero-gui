const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const main = fs.readFileSync('main.qml', 'utf8');
function extract(source, name) {
 const start = source.indexOf('    function ' + name + '(');
 assert(start >= 0, name);
 return source.slice(start, source.indexOf('\n    }', start) + 6);
}
function setup() {
 const writes=[], c={middlePanel:{trezorView:{busy:""}},scheduledSends:[], scheduledSaving:0, scheduledLoadFailed:false,
 scheduledWalletCounts:{},scheduledExitApproved:false,scheduledReserveMs:1500000,
 scheduledRunningId:'', scheduledRequestId:0, transactionRequestId:0, scheduledCommitting:false,
 persistentSettings:{wallet_path:'wallet',scheduledSends:'[]',sync(){}},
 qsTr:s=>s, showStatusMessage(){}, console:{log(){},error(){}},
 jsonList:s=>JSON.parse(s), viewOnly:false,walletSynced:true,daemonSynced:true,
 approvedRoute:()=>true, activeTransactionRequestId:0, transaction:null,minedSpend:null,minedAccountActive:false,
 PendingTransaction:{Status_Ok:0}, created:0, committed:0, disposed:0};
 Object.defineProperty(c,'walletScheduledSends',{get:()=>c.scheduledSends});
 c.currentWallet={isHwBacked:()=>false,currentSubaddressAccount:0,isBackgroundSyncing:()=>false,getCacheAttribute:()=> '[]',setCacheAttribute:()=>true,
 storeAsync:cb=>writes.push(cb),createTransactionAsync(){c.created++},
 disposeTransaction(){c.disposed++},commitTransactionAsync(){c.committed++}};
 vm.createContext(c);
 vm.runInContext(['scheduledPaymentsAllowed','requestScheduledExit','scheduledReservation','blockReservedSpend','rememberScheduledCount','loadScheduledSends','setScheduledSends','scheduledEntry','updateScheduledSend','runScheduledSend','onScheduledCreated'].map(n=>extract(main,n)).join('\n'),c);
 return {c,writes};
}
const entry={id:'one',wallet:'wallet',recipients:[{address:'test',amount:'1'}],when:0};
{
 const {c,writes}=setup(); c.scheduledSends=[entry]; c.runScheduledSend('one');
 assert.equal(c.created,1);
 c.onScheduledCreated({status:0,txCount:1});
 assert.equal(c.committed,0,'broadcast waits for durable storage');
 assert.equal(c.scheduledSends[0].state,'broadcasting');
 writes.shift()(true); // clearing previous error
 writes.shift()(true); // persisted broadcast marker
 assert.equal(c.committed,1);
 c.scheduledRunningId=''; c.runScheduledSend('one');
 assert.equal(c.created,1,'uncertain broadcast cannot be resent');
}
{
 const {c,writes}=setup(); c.scheduledSends=[entry]; c.runScheduledSend('one');
 c.onScheduledCreated({status:0,txCount:1}); writes.shift()(true); writes.shift()(false);
 assert.equal(c.committed,0,'storage failure blocks broadcast'); assert(c.scheduledLoadFailed);
}
{
 const {c,writes}=setup(); c.persistentSettings.scheduledSends=JSON.stringify([entry]);
 c.loadScheduledSends(c.currentWallet);
 assert.equal(JSON.parse(c.persistentSettings.scheduledSends).length,1,'legacy retained until save');
 writes.shift()(true); assert.equal(c.persistentSettings.scheduledSends,'[]');
}
for (const field of ['viewOnly','transaction','minedSpend']) {
 const {c}=setup(); c.scheduledSends=[entry]; c[field]=true; c.runScheduledSend('one'); assert.equal(c.created,0,field);
}
{
 const {c}=setup(); c.scheduledSends=[{...entry,wallet:'another'}];c.runScheduledSend('one'); assert.equal(c.created,0);
 c.currentWallet.getCacheAttribute=()=>'{bad'; c.loadScheduledSends(c.currentWallet); assert(c.scheduledLoadFailed);
}
const trading=fs.readFileSync('pages/TradingData.qml','utf8');
const ctx={splitKey:key=>({days:Number(key.split('/').pop())})};vm.createContext(ctx);
vm.runInContext(extract(trading,'refreshInterval'),ctx);
assert.equal(ctx.refreshInterval('eur/1'),900000);
assert.equal(ctx.refreshInterval('eur/90'),21600000);
assert.equal(ctx.refreshInterval('eur/365'),86400000);
assert(!extract(main,'handlePayment').includes('console.log'));
console.log('PASS: durable broadcast barrier, uncertain-send protection, migration, storage failures, wallet guards, market expiry and payment logging');
{
 const {c,writes}=setup(); c.persistentSettings.scheduledSends=JSON.stringify([entry]);
 c.loadScheduledSends(c.currentWallet); writes.shift()(false);
 assert.equal(JSON.parse(c.persistentSettings.scheduledSends).length,1,'failed migration preserves legacy data');
 assert(c.scheduledLoadFailed);
}
{
 const {c}=setup(); c.scheduledSends=[{...entry,account:2}];
 c.currentWallet.currentSubaddressAccount=1; c.runScheduledSend('one');
 assert.equal(c.created,0,'never use another source account');
}
for (const condition of ['scheduledRunningId','scheduledSaving']) {
 const {c}=setup(); c[condition]=condition === 'scheduledSaving' ? 1 : 'one';
 vm.runInContext(extract(main,'closeWallet'),c);
 let closed=false;c.closeWallet(()=>closed=true,'park');assert.equal(closed,false,'wallet switch waits for operation');
}
{
 const {c}=setup();c.currentWallet.getCacheAttribute=()=>JSON.stringify([{...entry,wallet:'old-path'}]);
 c.loadScheduledSends(c.currentWallet);assert.equal(c.scheduledSends[0].wallet,'wallet','moving wallet retains its schedule');
}
console.log('PASS: migration failure, source-account mismatch, close/switch guards and moved wallet');
for (const lateness of [1, 60000, 14*60000, 30*60000]) {
 const {c}=setup();c.currentWallet.getCacheAttribute=()=>JSON.stringify([{...entry,when:Date.now()-lateness}]);
 c.loadScheduledSends(c.currentWallet);
 assert.equal(c.scheduledSends[0].error,'late','every overdue reopened payment requires consent');
}
{
 const {c}=setup(); const now=Date.now(); c.Date={now:()=>now};
 c.scheduledSends=[{...entry,account:0,when:now+25*60000}];
 assert(c.scheduledReservation(0,''),'25-minute boundary reserves source account');
 assert(!c.scheduledReservation(1,''),'other accounts remain usable');
 assert(!c.scheduledReservation(0,'one'),'scheduled payment can spend its own reservation');
 c.scheduledSends=[{...entry,account:0,when:now+25*60000+1}];
 assert(!c.scheduledReservation(0,''),'outside window is not reserved');
 c.scheduledSends=[{...entry,account:0,when:now+60000,error:'late'}];
 assert(!c.scheduledReservation(0,''),'pending manual confirmation is not an automatic reservation');
}
{
 const {c}=setup();let options,closed=false;
 c.scheduledWalletCounts={wallet:1};c.scheduledExitDialog={open(...args){options=args;}};
 assert.equal(c.requestScheduledExit(()=>closed=true),false);
 assert.equal(closed,false);assert.equal(options[2],'Keep open');assert.equal(options[3],'Close anyway');
 options[4]();assert.equal(closed,true);assert.equal(c.scheduledWalletCounts.wallet,1,'exit never deletes schedules');
}
{
 const {c}=setup();c.scheduledSends=[entry];c.currentWallet.isBackgroundSyncing=()=>true;
 c.runScheduledSend('one');assert.equal(c.created,0,'background-sync lock cannot spend');
}
assert(extract(main,'handlePayment').includes('blockReservedSpend'));
assert(extract(main,'handleSweepUnmixable').includes('blockReservedSpend'));
assert(extract(main,'handleTransactionConfirmed').includes('blockReservedSpend'),'recheck reservation at commit');
console.log('PASS: overdue reopen at every delay, reservation boundaries, account isolation, shutdown consent and background-sync lock');

{
 const {c}=setup();c.currentWallet.isHwBacked=()=>true;
 c.currentWallet.getCacheAttribute=()=>{throw new Error('hardware schedule must not be loaded');};
 c.loadScheduledSends(c.currentWallet);
 assert.equal(c.scheduledSends.length,0);
 assert.equal(c.scheduledWalletCounts.wallet,0);
 c.scheduledSends=[entry];c.runScheduledSend('one');assert.equal(c.created,0);
 assert.equal(c.scheduledReservation(0,''),undefined);
 vm.runInContext(['scheduleSend','scheduledCheck','promptLateScheduledSend'].map(n=>extract(main,n)).join('\n'),c);
 c.scheduleSend([], '', 0, 0, '', Date.now());c.scheduledCheck();c.promptLateScheduledSend();
 assert.equal(c.created,0);
}
console.log('PASS: hardware wallets cannot load, schedule, reserve or execute scheduled payments');
