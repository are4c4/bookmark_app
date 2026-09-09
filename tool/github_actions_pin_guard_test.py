#!/usr/bin/env python3

import unittest

import github_actions_pin_guard as guard


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


if __name__ == "__main__":
    unittest.main()
