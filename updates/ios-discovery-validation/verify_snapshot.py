import hashlib, json, os, pathlib, re, stat, zipfile
request = json.loads(pathlib.Path('updates/ios-discovery-validation/request.json').read_text())
assert request.get('validationOnly') is True, 'Not a validation-only request'
name = request['filename']
assert re.fullmatch(r'Courtline-iPad-v1\.0\.(?:[789]|10|11|12|13)-[A-Za-z0-9-]+\.zip', name), 'Unexpected source filename'
expected = request['sha256']
assert re.fullmatch(r'[0-9a-f]{64}', expected), 'Invalid expected checksum'
archive = pathlib.Path('updates/ios-discovery-validation') / name
assert archive.stat().st_size <= 16 * 1024 * 1024, 'Oversized archive'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected, 'Source checksum mismatch'
root = pathlib.Path(os.environ['RUNNER_TEMP']) / 'courtline-ipad-native'
root.mkdir(exist_ok=False)
with zipfile.ZipFile(archive) as z:
    entries = z.infolist()
    assert 4 <= len(entries) <= 400, 'Unexpected archive entries'
    assert sum(x.file_size for x in entries) <= 64 * 1024 * 1024, 'Oversized extracted source'
    seen = set()
    for x in entries:
        p = pathlib.PurePosixPath(x.filename)
        assert not p.is_absolute() and '..' not in p.parts and '\\' not in x.filename, 'Unsafe archive path'
        assert p.parts and p.parts[0] == 'Courtline-iPad.swiftpm', 'Unexpected package root'
        assert x.filename not in seen, 'Duplicate archive path'
        seen.add(x.filename)
        mode = x.external_attr >> 16
        assert not stat.S_ISLNK(mode), 'Symlink not allowed'
        assert x.file_size <= 12 * 1024 * 1024, 'Oversized source entry'
    assert 'Courtline-iPad.swiftpm/Package.swift' in seen, 'Missing package manifest'
    z.extractall(root)
print('Verified source snapshot SHA-256:', expected)
print('Native validation only; no source scripts or package plugins are executed.')

# Validate exact embedded runtime resources, not just editable Web sources.
import base64
package = root / 'Courtline-iPad.swiftpm'
source = (package / 'CourtlineResources.swift').read_text()
pairs = re.findall(r'        "([^"/]+)": """\n(.*?)\n        """', source, re.S)
assert pairs and len(pairs) == len(dict(pairs)), 'Missing or duplicate embedded resources'
embedded = {name: base64.b64decode(''.join(value.split()), validate=True) for name, value in pairs}
expected = {p.name: p.read_bytes() for p in (package / 'Web').iterdir() if p.is_file()}
assert embedded.keys() == expected.keys(), 'Embedded resource inventory mismatch'
for name, content in embedded.items():
    assert content == expected[name], 'Embedded/source mismatch: ' + name
assert b'const verification=' in embedded['courtline-options.js'], 'Missing diagnostic verification renderer'
print('PASS exact embedded/Web byte parity:', len(embedded), 'resources')
