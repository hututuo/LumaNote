import importlib.util
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'check-public-history.py'
spec = importlib.util.spec_from_file_location('history_gate', SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class HistoryGateTests(unittest.TestCase):
    def test_synthetic_credentials(self):
        self.assertIn('github-token', gate.violations('sample.txt', b'ghp_' + b'A' * 36))
        self.assertIn('private-key', gate.violations('sample.txt', b'-----BEGIN ' + b'OPENSSH PRIVATE KEY-----'))

    def test_private_paths_and_public_entry(self):
        self.assertIn('private-path', gate.violations('handoffs/internal.md', b'notes'))
        self.assertIn('private-path', gate.violations('docs/releases/version-audit.md', b'notes'))
        self.assertEqual([], gate.violations('CONTEXT.md', b'See AGENTS.md and private context.'))

    def test_only_the_existing_home_fixture_is_allowed(self):
        sample = b'/' + b'Users/ceshi/Applications/Sample.app'
        self.assertEqual([], gate.violations('app/QuietNote/Tests/ClipboardDetectorTests.swift', sample))
        self.assertIn('personal-home', gate.violations('README.md', sample))

    def test_reused_base_blob_under_private_path_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp)
            env = dict(os.environ, GIT_AUTHOR_NAME='Test', GIT_COMMITTER_NAME='Test', GIT_AUTHOR_EMAIL='test@example.invalid', GIT_COMMITTER_EMAIL='test@example.invalid')
            def git(*args):
                return subprocess.check_output(['git', '-C', temp, *args], env=env, stderr=subprocess.DEVNULL).decode().strip()
            git('init', '--initial-branch=main')
            (path / 'public.txt').write_text('Existing content')
            git('add', 'public.txt'); git('commit', '-m', 'Base')
            base = git('rev-parse', 'HEAD')
            (path / 'handoffs').mkdir()
            git('mv', 'public.txt', 'handoffs/internal.md')
            git('commit', '-m', 'Move existing blob')
            result = subprocess.run(['python3', str(SCRIPT), '--base', base], cwd=temp, capture_output=True, text=True)
            self.assertEqual(1, result.returncode, result.stdout + result.stderr)
            self.assertIn('private-path', result.stdout)

    def test_deleted_intermediate_secret_still_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp)
            env = dict(os.environ, GIT_AUTHOR_NAME='Test', GIT_COMMITTER_NAME='Test', GIT_AUTHOR_EMAIL='test@example.invalid', GIT_COMMITTER_EMAIL='test@example.invalid')
            def git(*args):
                return subprocess.check_output(['git', '-C', temp, *args], env=env, stderr=subprocess.DEVNULL).decode().strip()
            git('init', '--initial-branch=main')
            git('commit', '--allow-empty', '-m', 'Base')
            base = git('rev-parse', 'HEAD')
            secret = 'ghp_' + 'A' * 36
            (path / 'sample.txt').write_text(secret)
            git('add', 'sample.txt'); git('commit', '-m', 'Intermediate')
            git('rm', 'sample.txt'); git('commit', '-m', 'Remove')
            result = subprocess.run(['python3', str(SCRIPT), '--base', base], cwd=temp, capture_output=True, text=True)
            self.assertEqual(1, result.returncode, result.stdout + result.stderr)
            self.assertIn('github-token', result.stdout)
            self.assertNotIn(secret, result.stdout + result.stderr)

if __name__ == '__main__':
    unittest.main()
