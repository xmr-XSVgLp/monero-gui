// Run with node tests/nym_lifecycle.cjs. No daemon or external network is used.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(path.join(__dirname, '..', 'main.qml'), 'utf8');
const names = ['nymVpnConnect', 'nymVpnResetInfo', 'nymVpnFail', 'nymVpnRestart',
    'nymVpnDisconnect', 'nymVpnProxyUp', 'approvedRoute', 'cancelConnectionTest', 'startDaemon'];
const functions = names.map(name => {
    const start = source.indexOf('    function ' + name + '(');
    assert(start >= 0, name);
    return source.slice(start, source.indexOf('\n    }', start) + 6);
}).join('\n');
const timer = () => ({stop() {}, restart() {}});
function setup() {
    const commands = [], c = {
        console: {log() {}}, isQuitting: false, nymVpnSessionGen: 0, nymVpnState: 'off', nymVpnRestarting: false,
        nymVpnIp: 'known', nymVpnIpPlace: '', nymVpnEntryId: '', nymVpnExitId: '', nymVpnRouteNote: '',
        nymVpnInfoGen: 0, nymVpnInfoLoading: false, connTestGen: 0, connTesting: false, connTest: {},
        nymVpnPollTimer: timer(), nymVpnIpRetryTimer: timer(), nymVpnInfoWatchdog: timer(),
        translationManager: {emptyString: ''}, qsTr: s => s, Qt: {callLater() {}},
        nymVpnLoadInfo() {},
        currentWallet: {pauseRefresh() {}, startRefresh() {}},
        daemonManager: {start(...args) { c.daemonArgs = args; }},
        informationPopup: {open() {}},
        persistentSettings: {nymVpnSocksAddress: '127.0.0.1:17890', nymVpnEnabled: false,
            nymVpnRequired: false, proxyEnabled: false, proxyAddress: '127.0.0.1:9050',
            walletMode: 2, extremePrivacy: false},
        oshelper: {
            cancelConnectionTest() {},
            nymClient: {
                address: '127.0.0.1:17890',
                start() { commands.push('start'); },
                reconnect() { commands.push('reconnect'); },
                stop() { commands.push('stop'); }
            }

        }
    };
    c.appWindow = c;
    vm.createContext(c);
    vm.runInContext('String.prototype.arg = function(v) { return this.replace(/%[0-9]+/, v); };\n' + functions, c);
    return {c, commands};
}
let {c, commands} = setup();
c.nymVpnConnect();
assert.equal(c.persistentSettings.nymVpnEnabled, true);
assert.equal(c.nymVpnRestarting, true, 'traffic blocked before startup');
assert.deepEqual(commands, ['start']);
c.nymVpnState = 'connected';
c.nymVpnRestarting = false;
c.nymVpnRestart();
assert.equal(c.nymVpnRestarting, true, 'traffic blocked before reconnect');
assert.deepEqual(commands, ['start', 'reconnect']);
c.nymVpnFail('connection failed');
assert.equal(c.nymVpnRestarting, true, 'failed connection must not fall back to direct');
c.nymVpnDisconnect();
assert.deepEqual(commands, ['start', 'reconnect', 'stop']);
assert.equal(c.nymVpnState, 'off');
assert.equal(c.persistentSettings.proxyAddress, '127.0.0.1:9050');
assert.equal(c.persistentSettings.proxyEnabled, false);
assert.equal(c.persistentSettings.nymVpnEnabled, false);
({c} = setup());
c.persistentSettings.nymVpnEnabled = true;
c.startDaemon('');
assert(c.daemonArgs[0].includes('--proxy 127.0.0.1:17890'));
assert(c.daemonArgs[0].includes('--out-peers 4'));
assert(c.daemonArgs[0].includes('--block-sync-size 5'));
c.startDaemon('--out-peers=6 --block-sync-size 8');
assert(!c.daemonArgs[0].includes('--out-peers 4'));
assert(!c.daemonArgs[0].includes('--block-sync-size 5'));
c.persistentSettings.nymVpnEnabled = false;
c.startDaemon('');
assert.equal(c.daemonArgs[0], '', 'direct mode must keep existing defaults');
assert(!source.includes('restartNymVpnDaemon'));
assert(!source.includes('stopNymVpnDetached'));
assert(!source.includes('["socks5", "disable"]'));
assert(!source.includes('["account", "forget"]'));
assert(!source.includes('runNymVpnc'));
console.log('PASS: independent lifecycle, fail-closed reconnect, settings restoration and node proxy flags');

// The saved preference is not proof of a live connection (failed login regression).
const panel = fs.readFileSync(path.join(__dirname, '..', 'components', 'NymVpnPanel.qml'), 'utf8');
const buttons = panel.split('MoneroComponents.StandardButton {');
const visibility = label => {
    const block = buttons.find(b => b.includes('qsTr("' + label + '")'));
    assert(block, label);
    return block.match(/visible:\s*([^\n]+)/)[1];
};
for (const [state, expected] of [
    ['off', [true, false, false]], ['error', [true, false, false]],
    ['working', [false, false, true]], ['connected', [false, true, true]],
    ['ready', [false, true, true]]
]) {
    const context = {nymPanel: {state_: state, active: ['connected', 'ready'].includes(state), needsInstall: false},
        persistentSettings: {nymVpnEnabled: true}, appWindow: {nymVpnRestarting: true}};
    const actual = ['Connect', 'Reconnect', 'Disconnect'].map(label => vm.runInNewContext(visibility(label), context));
    assert.deepEqual(actual, expected, 'connection buttons in ' + state);
}
console.log('PASS: connection buttons reflect live state, including failed authentication');
