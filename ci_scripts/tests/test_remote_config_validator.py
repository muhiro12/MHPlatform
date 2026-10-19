"""Exercise the publisher tool with the same policy decoder used by applications."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


VALIDATOR = Path(sys.argv.pop(1)).resolve()


class RemoteConfigValidatorTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.previous = {
            "schemaVersion": 1,
            "bundleIdentifier": "example.app",
            "features": {"remoteUpdate": {"revision": 2, "requirement": None}},
        }

    def validate(self, candidate, previous=None):
        arguments = [str(VALIDATOR)]
        for name, document in [("candidate", candidate), ("previous", previous)]:
            if document is not None:
                path = Path(self.directory.name, name + ".json")
                path.write_text(json.dumps(document))
                arguments.append(str(path))
        return subprocess.run(arguments, capture_output=True, text=True, check=False)

    def test_existing_document_and_unchanged_revision_are_accepted(self):
        self.assertEqual(self.validate(self.previous, self.previous).returncode, 0)

    def test_baseline_and_future_plan_can_be_published_together(self):
        candidate = copy.deepcopy(self.previous)
        update = candidate["features"]["remoteUpdate"]
        update.update({
            "revision": 3,
            "requirement": {"minimumVersion": "2", "effectiveAt": "2026-01-01T00:00:00Z"},
            "scheduledRequirements": [{"minimumVersion": "3", "effectiveAt": "2026-11-01T00:00:00Z"}],
        })
        self.assertEqual(self.validate(candidate, self.previous).returncode, 0)

    def test_rollback_and_reusing_a_changed_revision_are_rejected(self):
        for revision in [1, 2]:
            with self.subTest(revision=revision):
                candidate = copy.deepcopy(self.previous)
                candidate["features"]["remoteUpdate"].update({
                    "revision": revision,
                    "requirement": {"minimumVersion": "2", "effectiveAt": "2026-01-01T00:00:00Z"},
                })
                self.assertNotEqual(self.validate(candidate, self.previous).returncode, 0)

    def test_higher_revision_cancellation_recovers_without_republishing_an_old_file(self):
        previous = copy.deepcopy(self.previous)
        previous["features"]["remoteUpdate"]["requirement"] = {
            "minimumVersion": "2", "effectiveAt": "2026-01-01T00:00:00Z",
        }
        candidate = copy.deepcopy(self.previous)
        candidate["features"]["remoteUpdate"]["revision"] = 3
        self.assertEqual(self.validate(candidate, previous).returncode, 0)

    def test_different_app_identity_is_rejected(self):
        candidate = copy.deepcopy(self.previous)
        candidate["bundleIdentifier"] = "other.app"
        self.assertNotEqual(self.validate(candidate, self.previous).returncode, 0)

    def test_unsupported_feature_formats_and_missing_cancellation_are_rejected(self):
        for change in [{"schemaVersion": 999}, {"requirement": {}}, {"validUntil": None}]:
            with self.subTest(change=change):
                candidate = copy.deepcopy(self.previous)
                candidate["features"]["remoteUpdate"].update(change)
                self.assertNotEqual(self.validate(candidate).returncode, 0)
        del candidate["features"]["remoteUpdate"]["requirement"]
        self.assertNotEqual(self.validate(candidate).returncode, 0)

    def test_unrelated_sections_do_not_change_update_revisions(self):
        candidate = copy.deepcopy(self.previous)
        candidate["features"]["futureFeature"] = "not this validator's policy"
        self.assertEqual(self.validate(candidate, self.previous).returncode, 0)


if __name__ == "__main__":
    unittest.main()
