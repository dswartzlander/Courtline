import hashlib, json, os, pathlib, re, stat, zipfile
request = json.loads(pathlib.Path('updates/ios-pinned-validation/request.json').read_text())
assert request.get('validationOnly') is True, 'Not a validation-only request'
name = request['filename']
assert name == 'CourtLine-Pinned-Test-v1.0.zip', 'Unexpected source filename'
expected = request['sha256']
assert re.fullmatch(r'[0-9a-f]{64}', expected), 'Invalid expected checksum'
archive = pathlib.Path('updates/ios-pinned-validation') / name
assert archive.stat().st_size <= 16 * 1024 * 1024, 'Oversized archive'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected, 'Source checksum mismatch'
root = pathlib.Path(os.environ['RUNNER_TEMP']) / 'courtline-pinned-test'
root.mkdir(exist_ok=False)
with zipfile.ZipFile(archive) as z:
    entries = z.infolist()
    assert 4 <= len(entries) <= 400, 'Unexpected archive entries'
    assert sum(x.file_size for x in entries) <= 64 * 1024 * 1024, 'Oversized extracted source'
    seen = set()
    for x in entries:
        p = pathlib.PurePosixPath(x.filename)
        assert not p.is_absolute() and '..' not in p.parts and '\\' not in x.filename, 'Unsafe archive path'
        assert p.parts and p.parts[0] == 'CourtLine-Pinned-Test.swiftpm', 'Unexpected package root'
        assert x.filename not in seen, 'Duplicate archive path'
        seen.add(x.filename)
        mode = x.external_attr >> 16
        assert not stat.S_ISLNK(mode), 'Symlink not allowed'
        assert x.file_size <= 12 * 1024 * 1024, 'Oversized source entry'
    assert 'CourtLine-Pinned-Test.swiftpm/Package.swift' in seen, 'Missing package manifest'
    z.extractall(root)
print('Verified source snapshot SHA-256:', expected)
print('Native validation only; no source scripts or package plugins are executed.')
