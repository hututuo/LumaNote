#!/usr/bin/env python3
"""Check every newly reachable object, even when a later commit deletes it."""
import argparse
import re
import subprocess

RULES = {
    'private-key': re.compile(rb'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'),
    'github-token': re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,255}|github_pat_[A-Za-z0-9_]{30,255})\b'),
    'api-token': re.compile(rb'\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{24,255}'),
    'personal-home': re.compile(rb'/(?:Users|home)/[^/\s"\x27<>]+/'),
    'task-identifier': re.compile(rb'(?i)(?:thread|session|project).{0,100}[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'),
}
PRIVATE_PATH = re.compile(r'(^|/)(?:handoffs|verification|private|\.codex|\.agents|plans)(?:/|$)|/superpowers/|docs/releases/.*-audit\.md$|(^|/)\.env(?:\.|$)|\.(?:p12|pfx|pem|key|sqlite|sqlite3)$')

def git(*args):
    return subprocess.check_output(['git', *args])

def violations(path, data):
    result = ['private-path'] if PRIVATE_PATH.search(path) else []
    for label, regex in RULES.items():
        matches = list(regex.finditer(data))
        # Existing public regression fixture, not a maintainer's home directory.
        if label == 'personal-home' and path == 'app/QuietNote/Tests/ClipboardDetectorTests.swift':
            matches = [m for m in matches if m.group() != b'/' + b'Users/ceshi/']
        if matches:
            result.append(label)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='origin/main')
    parser.add_argument('--head', default='HEAD')
    args = parser.parse_args()
    base = git('rev-parse', '--verify', args.base + '^{commit}').decode().strip()
    head = git('rev-parse', '--verify', args.head + '^{commit}').decode().strip()
    subprocess.run(['git', 'merge-base', '--is-ancestor', base, head], check=True)
    rows = git('rev-list', '--objects', head, '--not', base).decode().splitlines()
    failures = []
    checked = 0
    # A blob reused from the base may appear under a newly private filename.
    for commit in git('rev-list', head, '--not', base).decode().splitlines():
        names = git('diff-tree', '--root', '-r', '-m', '--no-renames', '--no-commit-id', '--name-only', '--diff-filter=AM', '-z', commit)
        for raw_name in set(names.split(b'\x00')) - {b''}:
            path = raw_name.decode()
            data = git('show', commit + ':' + path)
            labels = violations(path, data)
            if labels:
                failures.append((commit, path, ','.join(labels)))
    process = subprocess.Popen(['git', 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for row in rows:
            oid, _, path = row.partition(' ')
            process.stdin.write((oid + '\n').encode()); process.stdin.flush()
            info = process.stdout.readline().split()
            if len(info) != 3:
                raise RuntimeError('Missing object: ' + oid)
            size = int(info[2])
            data = process.stdout.read(size)
            if len(data) != size or process.stdout.read(1) != b'\n':
                raise RuntimeError('Invalid object stream')
            if info[1] not in (b'blob', b'commit', b'tag'):
                continue
            checked += 1
            labels = violations(path, data)
            if labels:
                # Report locations, never matched contents.
                failures.append((oid, path or '[metadata]', ','.join(labels)))
    finally:
        process.stdin.close(); process.stdout.close(); process.wait()
    for oid, path, labels in failures:
        print('FAIL', oid, path, labels)
    print(('FAIL' if failures else 'PASS'), checked, 'new objects checked; inherited history is outside this gate')
    return bool(failures)

if __name__ == '__main__':
    raise SystemExit(main())
