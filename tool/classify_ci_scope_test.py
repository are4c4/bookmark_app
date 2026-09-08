#!/usr/bin/env python3
"""Deterministic tests for docs-only CI classification."""

from classify_ci_scope import is_docs_only


def main() -> None:
    assert is_docs_only(["docs/AI_PROGRESS.md"])
    assert is_docs_only(["docs/AI_PROGRESS.md", "docs/notes/checkpoint.md"])
    assert not is_docs_only([])
    assert not is_docs_only(["README.md"])
    assert not is_docs_only(["docs/AI_PROGRESS.md", "lib/main.dart"])
    assert not is_docs_only(["docs/AI_PROGRESS.md", ".github/workflows/flutter_ci.yml"])
    assert not is_docs_only(["docs/image.png"])
    print("classify_ci_scope_test: ok")


if __name__ == "__main__":
    main()
