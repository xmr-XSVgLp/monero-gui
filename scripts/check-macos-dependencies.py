#!/usr/bin/env python3
"""Reject a bundle with missing or external non-system Mach-O dependencies."""
import pathlib
import re
import subprocess
import sys

MAGICS = {bytes.fromhex(s) for s in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}

def macho(path):
    try:
        with path.open('rb') as stream:
            return stream.read(4) in MAGICS
    except OSError:
        return False

def output(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE)

def rpaths(binary):
    return re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset', output('otool', '-l', str(binary)))

def check(app):
    app = app.resolve()
    main_dir = app / 'Contents/MacOS'
    main = main_dir / 'monero-wallet-gui'
    main_paths = rpaths(main)
    problems = []
    binaries = [p for p in app.rglob('*') if p.is_file() and not p.is_symlink() and macho(p)]
    def inside(path):
        return path.resolve().is_relative_to(app)
    for binary in binaries:
        own_id = output('otool', '-D', str(binary)).splitlines()[1:]
        deps = re.findall(r'^\s+(.+?) \(compatibility version', output('otool', '-L', str(binary)), re.M)
        # Helpers may live in a subdirectory of Contents/MacOS; their loader
        # paths remain relative to their own executable, not the wallet.
        executable_dir = binary.parent if binary.is_relative_to(main_dir) and '.dylib' not in binary.name else main_dir
        def expand(path):
            return pathlib.Path(path.replace('@loader_path', str(binary.parent)).replace('@executable_path', str(executable_dir)))
        search = [expand(p) for p in rpaths(binary)]
        search += [pathlib.Path(p.replace('@executable_path', str(main_dir)).replace('@loader_path', str(main_dir))) for p in main_paths]
        for dep in deps:
            if dep in own_id or dep.startswith(('/System/Library/', '/usr/lib/')):
                continue
            if dep.startswith('@rpath/'):
                candidates = [p / dep[len('@rpath/'):] for p in search]
            elif dep.startswith(('@loader_path/', '@executable_path/')):
                candidates = [expand(dep)]
            else:
                candidates = [pathlib.Path(dep)]
            if not any(p.is_file() and inside(p) for p in candidates):
                problems.append(f'{binary.relative_to(app)} -> {dep}')
        for path in rpaths(binary):
            if path.startswith('/') and not inside(pathlib.Path(path)):
                problems.append(f'{binary.relative_to(app)} -> external rpath {path}')
    if problems:
        print('ERROR: unresolved or external dependencies:', file=sys.stderr)
        print('\n'.join(sorted(set(problems))), file=sys.stderr)
        return 1
    print(f'OK: dependencies of all {len(binaries)} Mach-O files resolve inside the app or macOS')
    return 0

if __name__ == '__main__':
    if sys.argv[1] == '--list':
        root = pathlib.Path(sys.argv[2])
        for path in root.rglob('*'):
            if path.is_file() and not path.is_symlink() and macho(path):
                print(path)
    else:
        sys.exit(check(pathlib.Path(sys.argv[1])))
