"""Exercise dependency checks with real Mach-O files, without opening the wallet."""
import pathlib
import subprocess
import tempfile

checker = pathlib.Path(__file__).resolve().parents[1] / 'scripts/check-macos-dependencies.py'
with tempfile.TemporaryDirectory(prefix='xmr-package-test-') as directory:
    root = pathlib.Path(directory)
    app = root / 'Test App.app'
    binaries = app / 'Contents/MacOS'
    frameworks = app / 'Contents/Frameworks'
    binaries.mkdir(parents=True)
    frameworks.mkdir()
    source = root / 'lib.c'
    source.write_text('int value(void) { return 0; }\n')
    library = frameworks / 'libtest.dylib'
    subprocess.run(['clang', '-dynamiclib', str(source), '-install_name', '@rpath/libtest.dylib', '-o', str(library)], check=True)
    source.write_text('int value(void); int main(void) { return value(); }\n')
    executable = binaries / 'monero-wallet-gui'
    subprocess.run(['clang', str(source), str(library), '-Wl,-rpath,@executable_path/../Frameworks', '-Wl,-headerpad_max_install_names', '-o', str(executable)], check=True)
    def result():
        return subprocess.run(['python3', str(checker), str(app)], capture_output=True, text=True)
    assert result().returncode == 0, result().stderr
    outside = root / 'libtest.dylib'
    library.rename(outside)
    assert result().returncode != 0, 'Missing library accepted'
    library.symlink_to(outside)
    assert result().returncode != 0, 'External symlink accepted'
    library.unlink()
    outside.rename(library)
    assert result().returncode == 0
    subprocess.run(['install_name_tool', '-add_rpath', str(root), str(executable)], check=True, capture_output=True)
    assert result().returncode != 0, 'External search path accepted'
print('PASS: complete bundle, missing dylib, external symlink and external rpath')
