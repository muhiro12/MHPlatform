"""Exercise release selection against isolated Git repositories."""

from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("next-version.sh").resolve()


class NextVersionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = self.directory.name
        self.git("init", "--quiet")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release@example.com")
        self.commit()

    def git(self, *arguments):
        return subprocess.run(
            ["git", *arguments], cwd=self.root, check=True,
            capture_output=True, text=True,
        )

    def commit(self):
        self.git("commit", "--quiet", "--allow-empty", "-m", "Test release")

    def select(self, version=""):
        return subprocess.run(
            ["bash", str(SCRIPT), version], cwd=self.root,
            capture_output=True, text=True,
        )

    def expect_version(self, expected, requested=""):
        result = self.select(requested)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), expected)

    def test_first_release(self):
        self.expect_version("1.0.0")

    def test_legacy_minor_transition(self):
        self.git("tag", "1.13")
        self.commit()
        self.expect_version("1.14.0")

    def test_patch_resets_and_numeric_sorting(self):
        self.git("tag", "1.9.9")
        self.git("tag", "1.14.3")
        self.commit()
        self.expect_version("1.15.0")

    def test_rerun_of_release_commit_is_empty(self):
        for tag in ("1.13", "1.14.0"):
            with self.subTest(tag=tag):
                self.git("tag", tag)
                self.expect_version("")
                self.git("tag", "-d", tag)

    def test_unrelated_tags_are_ignored(self):
        self.git("tag", "preview")
        self.git("tag", "2.0.0-beta.1")
        self.expect_version("1.0.0")

    def test_explicit_major_and_patch(self):
        self.git("tag", "1.14.0")
        self.commit()
        self.expect_version("2.0.0", "2.0.0")
        self.expect_version("1.14.1", "1.14.1")

    def test_invalid_versions_are_rejected(self):
        for version in ("v1.14.0", "1.14", "01.14.0", "1.14.0-beta.1", "0.9.0"):
            with self.subTest(version=version):
                self.assertNotEqual(self.select(version).returncode, 0)

    def test_existing_or_decreasing_versions_are_rejected(self):
        self.git("tag", "1.14.0")
        self.commit()
        for version in ("1.14.0", "1.13.9"):
            with self.subTest(version=version):
                self.assertNotEqual(self.select(version).returncode, 0)


if __name__ == "__main__":
    unittest.main()
