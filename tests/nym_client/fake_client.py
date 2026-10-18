#!/usr/bin/env python3
import json, os, pathlib, sys, time
base = pathlib.Path(__file__).parent
mode = (base / 'mode').read_text()
assert sys.argv[1] == '--authenticated'
assert len(sys.argv) == 5
assert json.loads(sys.stdin.buffer.readline())['mnemonic'] == 'test account'
assert 'test account' not in sys.argv
if mode == 'error':
    print(json.dumps({'event': 'error', 'message': 'test failure'}), flush=True)
    sys.exit(1)
with (base / 'events').open('a') as log:
    log.write('start %d\n' % os.getpid())
print(json.dumps({'event': 'credentials'}), flush=True)
if mode == 'delay':
    time.sleep(0.5)
print(json.dumps({'event': 'ready', 'authenticated': mode != 'unauthenticated', 'address': sys.argv[2], 'entry': 'entry', 'exit': str(os.getpid())}), flush=True)
sys.stdin.buffer.read(1)
with (base / 'events').open('a') as log:
    log.write('stop %d\n' % os.getpid())
