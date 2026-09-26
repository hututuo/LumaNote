#!/usr/bin/env python3
"""Launch the packaged candidate only on a disposable GitHub-hosted Mac."""
import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
import time

BUNDLE_ID = 'com.hututuo.lumanote'


def require_hosted_runner(env):
    expected = {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted', 'RUNNER_OS': 'macOS', 'GITHUB_REPOSITORY': 'hututuo/LumaNote'}
    if any(env.get(key) != value for key, value in expected.items()):
        raise RuntimeError('Refusing to launch outside the disposable hosted project runner')


def validate_archive(manifest_path, source_sha):
    manifest = json.loads(manifest_path.read_text())
    filename = manifest['filename']
    if pathlib.Path(filename).name != filename or not filename.endswith('.zip'):
        raise ValueError('Invalid archive filename')
    if manifest['source_sha'] != source_sha:
        raise ValueError('Source SHA mismatch')
    archive = manifest_path.parent / filename
    if archive.stat().st_size != manifest['size_bytes']:
        raise ValueError('Archive size mismatch')
    if hashlib.sha256(archive.read_bytes()).hexdigest() != manifest['sha256']:
        raise ValueError('Archive checksum mismatch')
    return manifest, archive


def jxa(code):
    return subprocess.check_output(['/usr/bin/osascript', '-l', 'JavaScript', '-e', "ObjC.import('AppKit'); " + code], text=True, timeout=10).strip()


def readiness(pid):
    return json.loads(jxa('var a = $.NSRunningApplication.runningApplicationWithProcessIdentifier(' + str(pid) + '); JSON.stringify({finishedLaunching: Boolean(a.finishedLaunching), terminated: Boolean(a.terminated)});'))


def run(args, report):
    require_hosted_runner(os.environ)
    manifest, archive = validate_archive(args.manifest, args.source_sha)
    report.update(source_sha=args.source_sha, candidate_sha256=manifest['sha256'], scenario=args.scenario)
    existing = jxa('$.NSRunningApplication.runningApplicationsWithBundleIdentifier(' + json.dumps(BUNDLE_ID) + ').count;')
    if existing != '0':
        raise RuntimeError('Existing application instance found; refusing to interfere')
    support = pathlib.Path.home() / 'Library' / 'Application Support' / 'QuietNote'
    preferences = pathlib.Path.home() / 'Library' / 'Preferences' / (BUNDLE_ID + '.plist')
    if support.exists() or preferences.exists():
        raise RuntimeError('Runner profile is not fresh; refusing to replace existing data')
    legacy = support / 'note.md'
    fixture = b'# Legacy fixture\n\n**Preserve** this Markdown exactly.\n- [ ] Existing task\n'
    if args.scenario == 'legacy':
        support.mkdir(parents=True)
        legacy.write_bytes(fixture)
    with tempfile.TemporaryDirectory(prefix='lumanote-smoke-', dir=os.environ['RUNNER_TEMP']) as temp:
        install = pathlib.Path(temp) / 'Applications'
        install.mkdir()
        subprocess.run(['/usr/bin/ditto', '-x', '-k', str(archive), str(install)], check=True)
        app = install / 'LumaNote.app'
        subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        executable = app / 'Contents' / 'MacOS' / 'QuietNote'
        env = dict(os.environ, PATH='/usr/bin:/bin:/usr/sbin:/sbin')
        for key in ('DEVELOPER_DIR', 'SDKROOT', 'TOOLCHAINS', 'DYLD_LIBRARY_PATH', 'DYLD_FRAMEWORK_PATH'):
            env.pop(key, None)
        with (pathlib.Path(temp) / 'app-output.log').open('wb') as output:
            process = subprocess.Popen([str(executable), '-SUEnableAutomaticChecks', 'NO', '-SUAutomaticallyUpdate', 'NO'], env=env, stdout=output, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 45
                while True:
                    if process.poll() is not None:
                        raise RuntimeError('Candidate exited before startup completed')
                    state = readiness(process.pid)
                    if state['finishedLaunching'] and not state['terminated']:
                        break
                    if time.monotonic() >= deadline:
                        raise RuntimeError('AppKit launch readiness timeout')
                    time.sleep(0.5)
                time.sleep(15)
                if process.poll() is not None or readiness(process.pid)['terminated']:
                    raise RuntimeError('Candidate exited during startup observation')
                report['appkit_startup'] = 'PASS'
                report['observed_alive_seconds'] = 15
                accepted = jxa('$.NSRunningApplication.runningApplicationWithProcessIdentifier(' + str(process.pid) + ').terminate;')
                if accepted != 'true':
                    raise RuntimeError('Normal application quit request was rejected')
                if process.wait(timeout=15) != 0:
                    raise RuntimeError('Candidate did not quit successfully')
                report['normal_quit'] = 'PASS'
            finally:
                # Only the child created here is ever terminated.
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
    current = pathlib.Path(subprocess.check_output(['/usr/bin/defaults', 'read', BUNDLE_ID, 'currentFilePath'], text=True).strip())
    if args.scenario == 'legacy':
        if current != legacy or legacy.read_bytes() != fixture:
            raise RuntimeError('Legacy note selection or byte preservation failed')
        report['synthetic_legacy_note_preservation'] = 'PASS'
    else:
        if current.parent != support or current.suffix != '.md' or not current.read_bytes():
            raise RuntimeError('Fresh default note creation failed')
        report['fresh_default_note'] = 'PASS'
    report['status'] = 'PASS'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=pathlib.Path, required=True)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--scenario', choices=['fresh', 'legacy'], required=True)
    parser.add_argument('--report', type=pathlib.Path, required=True)
    args = parser.parse_args()
    report = {'status': 'FAIL', 'visual_and_gesture_acceptance': 'NOT_RUN', 'real_user_data_upgrade': 'NOT_RUN', 'gatekeeper_download_acceptance': 'NOT_RUN', 'machine_without_developer_tools': 'NOT_RUN'}
    try:
        run(args, report)
    except Exception as error:
        report['error'] = str(error)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return report['status'] != 'PASS'


if __name__ == '__main__':
    raise SystemExit(main())
