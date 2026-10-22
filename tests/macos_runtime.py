import importlib.util
import pathlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('runtime', 'scripts/check-macos-runtime.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)

class RuntimeResources(unittest.TestCase):
    def test_missing_helpers_certificates_and_external_links(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = pathlib.Path(temporary) / 'Wallet with spaces.app'
            for name in runtime.EXECUTABLES:
                path = app / 'Contents/MacOS' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('test')
                path.chmod(0o755)
            for name in (*runtime.FILES, 'PlugIns/tls/libqsecuretransportbackend.dylib',
                         'MacOS/i2pd/certificates/reseed/test.crt'):
                path = app / 'Contents' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('test')
            self.assertEqual(runtime.resource_errors(app), [])
            (app / 'Contents/MacOS/i2pd/i2pd').unlink()
            self.assertIn('Missing executable: i2pd/i2pd', runtime.resource_errors(app))
            (app / 'Contents/MacOS/i2pd/certificates/reseed/test.crt').unlink()
            self.assertIn('Missing I2P reseed certificates', runtime.resource_errors(app))
            (app / 'external').symlink_to('/etc')
            self.assertIn('External symlink: external', runtime.resource_errors(app))

if __name__ == '__main__':
    unittest.main()
