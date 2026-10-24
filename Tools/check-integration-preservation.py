#!/usr/bin/env python3
"""Compare opaque digests only; never emit account or preference contents."""
from pathlib import Path
import argparse
import hashlib
import json
import datetime
import re

ROOT = Path(__file__).resolve().parent.parent

def compare_baseline(original, current):
    if isinstance(original, list):
        return {'comparable': False, 'unchanged': {},
                'reason': 'Legacy array has no item names or digest algorithm; mapping cannot be inferred. Original retained.'}
    values = original.get('digests') if isinstance(original, dict) else None
    if not isinstance(values, dict) or set(values) != set(current):
        return {'comparable': False, 'unchanged': {}, 'reason': 'Named digest items do not match the monitored scope.'}
    if any(value is not None and (not isinstance(value, str) or not re.fullmatch(r'[0-9a-f]{64}', value)) for value in values.values()):
        return {'comparable': False, 'unchanged': {}, 'reason': 'Invalid SHA-256 digest in baseline.'}
    return {'comparable': True, 'unchanged': {name: values[name] == value for name, value in current.items()}}

def digest(path):
    if not path.exists():
        return None
    if path.is_file():
        return hashlib.sha256(path.read_bytes()).hexdigest()
    result = hashlib.sha256()
    for f in sorted(p for p in path.rglob('*') if p.is_file()):
        result.update(str(f.relative_to(path)).encode() + b'\0' + hashlib.sha256(f.read_bytes()).digest())
    return result.hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['before', 'after'])
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    assert output.is_relative_to(ROOT / '.build'), 'Evidence must stay in the workspace .build directory'
    home_dir = Path.home()
    monitored = {
        'installedProduct': Path('/Applications/Catpacity.app'),
        'productPreferences': home_dir / 'Library/Preferences/com.yeonsik.catpacity.plist',
        'codexAuthentication': home_dir / '.codex/auth.json',
        'claudeConfiguration': home_dir / '.claude.json',
        'claudeHookSettings': home_dir / '.claude/settings.json',
    }
    current = {name: digest(path) for name,path in monitored.items()}
    if args.mode == 'before':
        assert not output.exists(), 'Do not replace an existing preservation baseline'
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps({'schemaVersion': 1, 'algorithm': 'sha256-file-or-sorted-path-and-raw-file-digest',
                                     'capturedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(), 'digests':current},indent=2)+'\n')
        print('Preservation baseline captured (contents withheld).')
    else:
        original = json.loads(output.read_text())
        report = {'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'baselineSHA256': hashlib.sha256(output.read_bytes()).hexdigest(),
                  **compare_baseline(original, current),
                  'scope':'File digests only; keychain and OS login-item database not audited. No product login-item registration code executed.'}
        output.with_name(output.stem + '-result.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2))
        if not report['comparable']:
            raise SystemExit(2)
        if not all(report['unchanged'].values()):
            raise SystemExit('Preserved file changed; investigate without restoring it')

if __name__ == '__main__':
    main()
