#!/usr/bin/env python3
"""Focused tests for UI Audit machine-summary/report-input generation."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

from ui_audit_report import build_summary, render_h_review_input, write_report_bundle


def _write_manifest(root: Path, *, failed: bool = False, missing_image: bool = False) -> None:
    screenshots = root / "screenshots"
    screenshots.mkdir(parents=True, exist_ok=True)
    (screenshots / "body.png").write_bytes(b"png-body")
    if not missing_image:
        (screenshots / "search.png").write_bytes(b"png-search")

    manifest = {
        "schemaVersion": 1,
        "sourceSha": "abc123",
        "profile": {"name": "desktop-dark-1440x900", "theme": "dark"},
        "scenarios": [
            {"name": "body", "file": "screenshots/body.png", "status": "passed"},
            {
                "name": "search",
                "file": "screenshots/search.png",
                "status": "failed" if failed else "passed",
            },
        ],
    }
    (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


def main() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        _write_manifest(root)
        (root / "test-exit-code.txt").write_text("0\n", encoding="utf-8")

        summary = write_report_bundle(root)
        assert summary["evidenceStatus"] == "complete", summary
        assert summary["sourceSha"] == "abc123"
        assert summary["scenarioCounts"] == {
            "total": 2,
            "passed": 2,
            "failed": 0,
            "unavailable": 0,
        }
        assert (root / "machine-summary.json").is_file()
        report = (root / "h-review-input.md").read_text(encoding="utf-8")
        assert "New actionable findings" in report
        assert "Known findings already owned" in report
        assert "Suspected / subjective observations" in report
        assert "no new actionable UX finding" in report

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        _write_manifest(root, failed=True, missing_image=True)
        (root / "test-exit-code.txt").write_text("1\n", encoding="utf-8")

        summary = build_summary(root)
        assert summary["evidenceStatus"] == "incomplete", summary
        assert summary["scenarioCounts"]["failed"] == 1
        assert summary["scenarioCounts"]["unavailable"] == 1
        assert any("screenshot is unavailable or empty" in item for item in summary["warnings"])
        report = render_h_review_input(summary)
        assert "Evidence warnings" in report
        assert "Capture test exit code: `1`" in report

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        root.mkdir(parents=True, exist_ok=True)
        summary = write_report_bundle(root)
        assert summary["evidenceStatus"] == "unavailable", summary
        assert summary["scenarioCounts"]["total"] == 0
        assert any("manifest.json is unavailable" in item for item in summary["warnings"])
        assert (root / "machine-summary.json").is_file()
        assert (root / "h-review-input.md").is_file()

    print("ui_audit_report_test: ok")


if __name__ == "__main__":
    main()
