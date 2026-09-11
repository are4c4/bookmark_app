#!/usr/bin/env python3
"""Deterministic tests for docs-only CI classification."""

from __future__ import annotations

import subprocess
from unittest.mock import patch

from classify_ci_scope import effective_diff_refs, is_docs_only


def _completed(stdout: str = "", returncode: int = 0) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        args=["git"],
        returncode=returncode,
        stdout=stdout,
        stderr="",
    )


def _assert_value_error(callback, expected: str) -> None:
    try:
        callback()
    except ValueError as error:
        assert expected in str(error), error
    else:
        raise AssertionError("expected ValueError")


def main() -> None:
    assert is_docs_only(["docs/AI_PROGRESS.md"])
    assert is_docs_only(["docs/AI_PROGRESS.md", "docs/notes/checkpoint.md"])
    assert not is_docs_only([])
    assert not is_docs_only(["README.md"])
    assert not is_docs_only(["docs/AI_PROGRESS.md", "lib/main.dart"])
    assert not is_docs_only(["docs/AI_PROGRESS.md", ".github/workflows/flutter_ci.yml"])
    assert not is_docs_only(["docs/image.png"])

    with patch(
        "classify_ci_scope.subprocess.run",
        side_effect=[
            _completed("merge-sha\n"),
            _completed("merge-sha current-base pr-head\n"),
        ],
    ):
        # The historical event base is deliberately stale. A verified synthetic
        # merge is authoritative for the effective current-base landing diff.
        assert effective_diff_refs(
            "pull_request",
            "stale-event-base",
            "pr-head",
            "merge-sha",
        ) == ("HEAD^1", "HEAD")

    with patch("classify_ci_scope.subprocess.run") as run:
        assert effective_diff_refs("push", "before", "after", "") == (
            "before",
            "after",
        )
        run.assert_not_called()

    with patch(
        "classify_ci_scope.subprocess.run",
        side_effect=[_completed("different-checkout\n")],
    ):
        _assert_value_error(
            lambda: effective_diff_refs(
                "pull_request", "stale", "pr-head", "merge-sha"
            ),
            "does not match GITHUB_SHA",
        )

    with patch(
        "classify_ci_scope.subprocess.run",
        side_effect=[
            _completed("merge-sha\n"),
            _completed("merge-sha only-one-parent\n"),
        ],
    ):
        _assert_value_error(
            lambda: effective_diff_refs(
                "pull_request", "stale", "pr-head", "merge-sha"
            ),
            "two-parent synthetic merge",
        )

    with patch(
        "classify_ci_scope.subprocess.run",
        side_effect=[
            _completed("merge-sha\n"),
            _completed("merge-sha current-base wrong-head\n"),
        ],
    ):
        _assert_value_error(
            lambda: effective_diff_refs(
                "pull_request", "stale", "pr-head", "merge-sha"
            ),
            "second parent does not match",
        )

    _assert_value_error(
        lambda: effective_diff_refs("pull_request", "stale", "pr-head", ""),
        "GITHUB_SHA is missing",
    )
    _assert_value_error(
        lambda: effective_diff_refs("pull_request", "stale", "", "merge-sha"),
        "head SHA is missing",
    )

    print("classify_ci_scope_test: ok")


if __name__ == "__main__":
    main()
