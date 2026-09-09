#!/usr/bin/env python3

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import migration_merge_gate as gate


class MigrationMergeGateTest(unittest.TestCase):
    def _event_path(self, directory: str) -> Path:
        path = Path(directory) / "event.json"
        path.write_text(
            json.dumps(
                {
                    "number": 1092,
                    "pull_request": {
                        "number": 1092,
                        "base": {"sha": "original-old-base"},
                        "head": {"sha": "pr-head"},
                        "merge_commit_sha": "synthetic-merge",
                    },
                }
            ),
            encoding="utf-8",
        )
        return path

    def test_keeps_event_refs_when_original_commits_are_available(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            event_path = self._event_path(directory)
            with mock.patch.dict(
                os.environ,
                {"GITHUB_EVENT_PATH": str(event_path)},
                clear=True,
            ), mock.patch.object(gate, "_commit_available", return_value=True), mock.patch.object(
                gate, "_local_pull_merge_diff_refs"
            ) as fallback:
                gate.hydrate_pull_request_metadata()

                self.assertEqual(os.environ["CI_BASE_SHA"], "original-old-base")
                self.assertEqual(os.environ["CI_HEAD_SHA"], "pr-head")
                self.assertEqual(os.environ["CURRENT_PR_NUMBER"], "1092")
                fallback.assert_not_called()

    def test_missing_original_base_uses_verified_synthetic_merge_diff(self) -> None:
        """Regression: a stale PR base may be absent from fetch-depth:2 checkout."""
        with tempfile.TemporaryDirectory() as directory:
            event_path = self._event_path(directory)
            with mock.patch.dict(
                os.environ,
                {
                    "GITHUB_EVENT_PATH": str(event_path),
                    "CI_BASE_SHA": "original-old-base",
                    "CI_HEAD_SHA": "pr-head",
                    "CURRENT_PR_NUMBER": "1092",
                },
                clear=True,
            ), mock.patch.object(
                gate,
                "_commit_available",
                side_effect=lambda ref: ref != "original-old-base",
            ), mock.patch.object(
                gate,
                "_local_pull_merge_diff_refs",
                return_value=("HEAD^1", "HEAD"),
            ) as fallback:
                gate.hydrate_pull_request_metadata()

                self.assertEqual(os.environ["CI_BASE_SHA"], "HEAD^1")
                self.assertEqual(os.environ["CI_HEAD_SHA"], "HEAD")
                fallback.assert_called_once_with("synthetic-merge")

    def test_unverified_local_checkout_does_not_replace_stale_refs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            event_path = self._event_path(directory)
            with mock.patch.dict(
                os.environ,
                {"GITHUB_EVENT_PATH": str(event_path)},
                clear=True,
            ), mock.patch.object(gate, "_commit_available", return_value=False), mock.patch.object(
                gate,
                "_local_pull_merge_diff_refs",
                return_value=None,
            ):
                gate.hydrate_pull_request_metadata()

                self.assertEqual(os.environ["CI_BASE_SHA"], "original-old-base")
                self.assertEqual(os.environ["CI_HEAD_SHA"], "pr-head")

    def test_merge_checkout_helper_requires_expected_merge_sha(self) -> None:
        rev_parse = mock.Mock(returncode=0, stdout="different-head\n")
        with mock.patch.object(gate.subprocess, "run", return_value=rev_parse):
            self.assertIsNone(gate._local_pull_merge_diff_refs("synthetic-merge"))

    def test_merge_checkout_helper_requires_merge_commit_parents(self) -> None:
        results = [
            mock.Mock(returncode=0, stdout="synthetic-merge\n"),
            mock.Mock(returncode=0, stdout="synthetic-merge one-parent\n"),
        ]
        with mock.patch.object(gate.subprocess, "run", side_effect=results):
            self.assertIsNone(gate._local_pull_merge_diff_refs("synthetic-merge"))


if __name__ == "__main__":
    unittest.main()
