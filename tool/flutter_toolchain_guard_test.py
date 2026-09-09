#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

import flutter_toolchain_guard as guard


VALID_WORKFLOW = """
name: Test
jobs:
  test:
    steps:
      - name: Set up Flutter
        uses: subosito/flutter-action@0123456789abcdef
        with:
          channel: stable
          flutter-version-file: pubspec.yaml
          cache: true
"""


class FlutterToolchainGuardTest(unittest.TestCase):
    def make_repo(self, workflow: str = VALID_WORKFLOW) -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / guard.LOCKFILE).write_text("packages: {}\n", encoding="utf-8")
        workflow_dir = root / guard.WORKFLOW_ROOT
        workflow_dir.mkdir(parents=True)
        (workflow_dir / "ci.yml").write_text(workflow, encoding="utf-8")
        return root

    def test_valid_repository_passes(self) -> None:
        root = self.make_repo()
        self.assertEqual(
            guard.validate_repository(root, tracked={guard.LOCKFILE}),
            [],
        )

    def test_missing_lockfile_fails(self) -> None:
        root = self.make_repo()
        (root / guard.LOCKFILE).unlink()
        errors = guard.validate_repository(root, tracked={guard.LOCKFILE})
        self.assertTrue(any("lockfile is missing" in error for error in errors))

    def test_untracked_lockfile_fails(self) -> None:
        root = self.make_repo()
        errors = guard.validate_repository(root, tracked=set())
        self.assertTrue(any("not tracked by git" in error for error in errors))

    def test_flutter_setup_without_version_file_fails(self) -> None:
        workflow = VALID_WORKFLOW.replace(
            "flutter-version-file: pubspec.yaml",
            "flutter-version: 3.47.2",
        )
        root = self.make_repo(workflow)
        errors = guard.validate_repository(root, tracked={guard.LOCKFILE})
        self.assertTrue(
            any(
                "must use `flutter-version-file: pubspec.yaml`" in error
                for error in errors
            )
        )

    def test_all_flutter_setup_blocks_are_checked_across_yaml_extensions(self) -> None:
        root = self.make_repo()
        second = root / guard.WORKFLOW_ROOT / "release.yaml"
        second.write_text(
            VALID_WORKFLOW.replace(
                "flutter-version-file: pubspec.yaml",
                "flutter-version: 3.47.2",
            ),
            encoding="utf-8",
        )
        errors = guard.validate_repository(root, tracked={guard.LOCKFILE})
        self.assertEqual(len(errors), 1)
        self.assertIn("release.yaml", errors[0])

    def test_non_flutter_actions_do_not_require_version_file(self) -> None:
        root = self.make_repo(
            """
name: Test
jobs:
  test:
    steps:
      - uses: actions/checkout@0123456789abcdef
"""
        )
        self.assertEqual(
            guard.validate_repository(root, tracked={guard.LOCKFILE}),
            [],
        )


if __name__ == "__main__":
    unittest.main()
