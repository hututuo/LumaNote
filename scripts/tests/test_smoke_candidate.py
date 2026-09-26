import hashlib
import importlib.util
import json
import pathlib
import plistlib
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'smoke-candidate.py'
spec = importlib.util.spec_from_file_location('candidate_smoke', SCRIPT)
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class SmokeSafetyTests(unittest.TestCase):
    def test_non_ascii_note_path_uses_structured_preferences(self):
        expected = pathlib.Path('/temporary') / '\u793a\u4f8b\u4fbf\u7b7e.md'
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            data = plistlib.dumps({'currentFilePath': str(expected)}, fmt=fmt)
            self.assertEqual(expected, smoke.current_note_path(data))

    def test_local_and_self_hosted_runners_are_rejected(self):
        for env in ({}, {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'self-hosted', 'RUNNER_OS': 'macOS', 'GITHUB_REPOSITORY': 'hututuo/LumaNote'}):
            with self.assertRaises(RuntimeError):
                smoke.require_hosted_runner(env)

    def test_expected_hosted_environment_is_accepted(self):
        smoke.require_hosted_runner({'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted', 'RUNNER_OS': 'macOS', 'GITHUB_REPOSITORY': 'hututuo/LumaNote'})

    def test_manifest_binding_and_integrity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            payload = b'synthetic archive bytes'
            archive = root / 'candidate.zip'
            archive.write_bytes(payload)
            path = root / 'manifest.json'
            manifest = dict(filename=archive.name, source_sha='a' * 40, size_bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest())
            path.write_text(json.dumps(manifest))
            self.assertEqual(archive, smoke.validate_archive(path, 'a' * 40)[1])
            for field, value in [('filename', '../candidate.zip'), ('source_sha', 'b' * 40), ('size_bytes', 0), ('sha256', '0' * 64)]:
                path.write_text(json.dumps(dict(manifest, **{field: value})))
                with self.assertRaises(ValueError):
                    smoke.validate_archive(path, 'a' * 40)


if __name__ == '__main__':
    unittest.main()
