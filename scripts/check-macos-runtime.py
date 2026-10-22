#!/usr/bin/env python3
"""Validate runtime resources and launch bundled helpers without developer settings.
Only version/invalid-argument checks are used: no wallet or network is opened.
"""
import json
import os
import pathlib
import subprocess
import sys
import tempfile

EXECUTABLES = ("monero-wallet-gui", "monerod", "xmr-nym-client", "tor/tor", "i2pd/i2pd")
FILES = ("PlugIns/platforms/libqcocoa.dylib", "Resources/ban_list.txt")

def resource_errors(app):
    app = app.resolve()
    errors = []
    for name in EXECUTABLES:
        path = app / "Contents/MacOS" / name
        if not path.is_file() or not os.access(path, os.X_OK):
            errors.append("Missing executable: " + name)
    for name in FILES:
        path = app / "Contents" / name
        if not path.is_file() or path.stat().st_size == 0:
            errors.append("Missing resource: " + name)
    if not any((app / "Contents/MacOS/i2pd/certificates/reseed").glob("*.crt")):
        errors.append("Missing I2P reseed certificates")
    tls = app / "Contents/PlugIns/tls"
    if not any((tls / name).is_file() for name in ("libqsecuretransportbackend.dylib", "libqopensslbackend.dylib")):
        errors.append("Missing Qt TLS backend")
    for path in app.rglob("*"):
        if path.is_symlink() and not path.resolve().is_relative_to(app):
            errors.append("External symlink: " + str(path.relative_to(app)))
    return errors

def smoke(app):
    with tempfile.TemporaryDirectory(prefix="xmr-runtime-") as home:
        env = {"HOME": home, "TMPDIR": home, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
               "SSL_CERT_FILE": "/etc/ssl/cert.pem"}
        for name in EXECUTABLES[1:]:
            # Nym has no version command; no arguments must fail before any connection.
            args = [] if name == "xmr-nym-client" else ["--version"]
            result = subprocess.run([str(app / "Contents/MacOS" / name), *args],
                                    cwd=home, env=env, capture_output=True, text=True, timeout=20)
            if name == "xmr-nym-client":
                messages = []
                for line in (result.stdout + result.stderr).splitlines():
                    try:
                        messages.append(json.loads(line))
                    except ValueError:
                        pass
                ok = result.returncode == 1 and any(m.get("event") == "error" and
                    "Authenticated mode requires" in m.get("message", "") for m in messages)
            else:
                ok = result.returncode == 0
            if not ok:
                raise RuntimeError(name + ": " + (result.stdout + result.stderr)[:1200])
            print("OK: " + name + " starts with temporary HOME and system-only PATH")

if __name__ == "__main__":
    app = pathlib.Path(sys.argv[1]).resolve()
    errors = resource_errors(app)
    if errors:
        sys.exit("ERROR: incomplete portable bundle:\n" + "\n".join(errors))
    try:
        smoke(app)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        sys.exit("ERROR: " + str(error))
