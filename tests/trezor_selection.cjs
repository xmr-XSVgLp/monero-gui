const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const main = fs.readFileSync('main.qml', 'utf8');
function extract(source, name) {
 const start = source.indexOf('    function ' + name + '(');
 assert(start >= 0, name);
 return source.slice(start, source.indexOf('\n    }', start) + 6);
}
for (const devices of [[], [{path:'webusb:1',label:'Safe 3'}], [{path:'webusb:1'},{path:'ble:7'}]]) {
 let chosen=null, selection=null, cancelled=false, opened=0;
 const c={openingTrezorLabel:'old Safe 7', qsTr:s=>s,
  walletManager:{setTrezorDevicePath:p=>selection=p, trezorDevicesAsync:(ble,cb)=>cb(JSON.stringify(devices))},
  rememberTrezorDevices(){}, hideProcessingSplash(){}, rememberTrezorWallet(){},
  withKnownTrezorNames:l=>l,jsonSetting:()=>({'wallet':'ble:7'}),
  trezorPicker:{open(list,preselect,accept,cancel){opened++;this.accept=accept;this.cancel=cancel;},connectionName:()=> 'Bluetooth'}};
 vm.createContext(c);vm.runInContext(extract(main,'chooseTrezor'),c);
 c.chooseTrezor('wallet',p=>chosen=p,()=>cancelled=true);
 assert.equal(opened,1);assert.equal(chosen,null,'never auto-connect the USB device');
 c.trezorPicker.accept('ble:7');assert.equal(selection,'ble:7');assert.equal(chosen,'ble:7');
 assert.equal(c.openingTrezorLabel,'Trezor · Bluetooth');
 c.trezorPicker.cancel();assert.equal(selection,'');assert.equal(cancelled,true);
}
const picker=fs.readFileSync('components/TrezorPicker.qml','utf8');
let pending;
const c={visible:true,searching:false,searchGeneration:0,devices:[{path:'webusb:1'}],selectedPath:'webusb:1',chosenCallback:null,cancelledCallback:null,
 appWindow:{modalDialogs:1,rememberTrezorDevices(){},withKnownTrezorNames:l=>l},walletManager:{trezorDevicesAsync:(ble,cb)=>pending=cb}};
c.root=c;vm.createContext(c);vm.runInContext(['searchBluetooth','finish'].map(n=>extract(picker,n)).join('\n'),c);
c.searchBluetooth();c.finish(true);assert.equal(c.visible,true,'Enter cannot select while scanning');
c.finish(false);pending('[{"path":"ble:7"}]');assert.equal(c.devices[0].path,'webusb:1','late scan cannot change closed picker');
console.log('PASS: explicit choice with zero/one/multiple USB devices, BLE choice, cancellation and stale discovery');

// A device settings request cannot cross a wallet switch while it is pending.
const guard={middlePanel:{trezorView:{busy:'label'}},isQuitting:true,qsTr:s=>s,showStatusMessage(){}};
vm.createContext(guard);vm.runInContext(extract(main,'closeWallet'),guard);
let closed=false;guard.closeWallet(()=>closed=true,'park');assert.equal(closed,false);assert.equal(guard.isQuitting,false);
console.log('PASS: wallet switch waits for pending device operations');
