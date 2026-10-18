"""Use the Nym core revision from the official VPN release lockfile, locally."""
import pathlib, sys, tomllib, re, os
vpn, core, helper = map(pathlib.Path, sys.argv[1:])
packages = {}
for p in core.rglob('Cargo.toml'):
    if 'target' in p.parts: continue
    try:
        name = tomllib.loads(p.read_text()).get('package', {}).get('name')
        if name: packages[name] = p.parent
    except (ValueError, OSError): pass
p = vpn / 'Cargo.toml'
s = p.read_text()
for name, directory in packages.items():
    # Preserve any explicit features or default-features options on this dependency.
    pattern = r'(?m)^' + re.escape(name) + r' = \{ git = "https://github.com/nymtech/nym", branch = "vpn/release/2026.18-essaouria"(.*?)\}'
    relative = os.path.relpath(directory, vpn)
    s = re.sub(pattern, lambda m: name + ' = { path = "' + relative + '"' + m[1] + '}', s)
if '"crates/xmr-nym-client"' not in s:
    s = s.replace('members = [', 'members = [\n    "crates/xmr-nym-client",', 1)
p.write_text(s)
import shutil
out = vpn / 'crates/xmr-nym-client'
out.mkdir(exist_ok=True)
shutil.copy2(helper / 'Cargo.toml', out / 'Cargo.toml')
shutil.copytree(helper / 'src', out / 'src', dirs_exist_ok=True)
