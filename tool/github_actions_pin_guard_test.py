#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

import flutter_toolchain_guard as toolchain_guard
import github_actions_pin_guard as guard


VALID_FLUTTER_WORKFLOW = """
name: Test
jobs:
  test:
    steps:
      - name: Set up Flutter
        uses: subosito/flutter-action@0123456789abcdef0123456789abcdef01234567
        with:
          channel: stable
          flutter-version-file: pubspec.yaml
          cache: true
"""


class GithubActionsPinGuardTest(unittest.TestCase):
    def test_accepts_full_commit_sha_with_comment(self) -> None:
        text = """
steps:
  - uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5
"""
        self.assertEqual(guard.unpinned_uses(text), [])

    def test_rejects_moving_tag(self) -> None:
        text = """
steps:
  - uses: actions/checkout@v5
"""
        self.assertEqual(guard.unpinned_uses(text), ["line 3: actions/checkout@v5"])

    def test_accepts_subpath_action_at_commit_sha(self) -> None:
        text = """
steps:
  - uses: actions/cache/save@caa296126883cff596d87d8935842f9db880ef25 # v5
"""
        self.assertEqual(guard.unpinned_uses(text), [])

    def test_local_actions_are_not_required_to_use_remote_sha(self) -> None:
        text = """
steps:
  - uses: ./tool/local-action
"""
        self.assertEqual(guard.unpinned_uses(text), [])


class FlutterToolchainGuardTest(unittest.TestCase):
    def make_repo(self, workflow: str = VALID_FLUTTER_WORKFLOW) -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / toolchain_guard.LOCKFILE).write_text(
            "packages: {}\n", encoding="utf-8"
        )
        workflow_dir = root / toolchain_guard.WORKFLOW_ROOT
        workflow_dir.mkdir(parents=True)
        (workflow_dir / "ci.yml").write_text(workflow, encoding="utf-8")
        return root

    def test_valid_repository_passes(self) -> None:
        root = self.make_repo()
        self.assertEqual(
            toolchain_guard.validate_repository(
                root, tracked={toolchain_guard.LOCKFILE}
            ),
            [],
        )

    def test_missing_lockfile_fails(self) -> None:
        root = self.make_repo()
        (root / toolchain_guard.LOCKFILE).unlink()
        errors = toolchain_guard.validate_repository(
            root, tracked={toolchain_guard.LOCKFILE}
        )
        self.assertTrue(any("lockfile is missing" in error for error in errors))

    def test_untracked_lockfile_fails(self) -> None:
        root = self.make_repo()
        errors = toolchain_guard.validate_repository(root, tracked=set())
        self.assertTrue(any("not tracked by git" in error for error in errors))

    def test_flutter_setup_without_version_file_fails(self) -> None:
        workflow = VALID_FLUTTER_WORKFLOW.replace(
            "flutter-version-file: pubspec.yaml",
            "flutter-version: 3.47.2",
        )
        root = self.make_repo(workflow)
        errors = toolchain_guard.validate_repository(
            root, tracked={toolchain_guard.LOCKFILE}
        )
        self.assertTrue(
            any(
                "must use `flutter-version-file: pubspec.yaml`" in error
                for error in errors
            )
        )

    def test_every_flutter_setup_in_same_workflow_is_checked(self) -> None:
        workflow = VALID_FLUTTER_WORKFLOW + """
  release:
    steps:
      - name: Set up Flutter for release
        uses: subosito/flutter-action@0123456789abcdef0123456789abcdef01234567
        with:
          flutter-version: 3.47.2
          cache: true
"""
        root = self.make_repo(workflow)
        errors = toolchain_guard.validate_repository(
            root, tracked={toolchain_guard.LOCKFILE}
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("ci.yml", errors[0])

    def test_all_flutter_setup_blocks_are_checked_across_yaml_extensions(self) -> None:
        root = self.make_repo()
        second = root / toolchain_guard.WORKFLOW_ROOT / "release.yaml"
        second.write_text(
            VALID_FLUTTER_WORKFLOW.replace(
                "flutter-version-file: pubspec.yaml",
                "flutter-version: 3.47.2",
            ),
            encoding="utf-8",
        )
        errors = toolchain_guard.validate_repository(
            root, tracked={toolchain_guard.LOCKFILE}
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("release.yaml", errors[0])

    def test_non_flutter_actions_do_not_require_version_file(self) -> None:
        root = self.make_repo(
            """
name: Test
jobs:
  test:
    steps:
      - uses: actions/checkout@0123456789abcdef0123456789abcdef01234567
"""
        )
        self.assertEqual(
            toolchain_guard.validate_repository(
                root, tracked={toolchain_guard.LOCKFILE}
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
