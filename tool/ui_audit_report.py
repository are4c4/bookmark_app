#!/usr/bin/env python3
"""Build deterministic H-facing review input from a UI Audit artifact bundle."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SUMMARY_SCHEMA_VERSION = 1


def _read_capture_exit_code(root: Path) -> int | None:
    path = root / "test-exit-code.txt"
    if not path.is_file():
        return None
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None


def _load_manifest(root: Path) -> tuple[dict[str, Any] | None, str | None]:
    path = root / "manifest.json"
    if not path.is_file():
        return None, "manifest.json is unavailable"
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return None, f"manifest.json is unreadable: {error}"
    if not isinstance(raw, dict):
        return None, "manifest.json root must be an object"
    return raw, None


def build_summary(root: Path) -> dict[str, Any]:
    manifest, manifest_error = _load_manifest(root)
    capture_exit_code = _read_capture_exit_code(root)
    warnings: list[str] = []
    scenarios: list[dict[str, Any]] = []

    if manifest_error is not None:
        warnings.append(manifest_error)

    source_sha: str | None = None
    profile: dict[str, Any] | None = None
    if manifest is not None:
        raw_source_sha = manifest.get("sourceSha")
        if isinstance(raw_source_sha, str) and raw_source_sha.strip():
            source_sha = raw_source_sha.strip()
        else:
            warnings.append("manifest sourceSha is missing")

        raw_profile = manifest.get("profile")
        if isinstance(raw_profile, dict):
            profile = raw_profile
        else:
            warnings.append("manifest profile is missing")

        raw_scenarios = manifest.get("scenarios")
        if not isinstance(raw_scenarios, list):
            warnings.append("manifest scenarios must be a list")
            raw_scenarios = []

        for index, raw_scenario in enumerate(raw_scenarios):
            if not isinstance(raw_scenario, dict):
                warnings.append(f"scenario[{index}] is not an object")
                continue

            raw_name = raw_scenario.get("name")
            name = raw_name.strip() if isinstance(raw_name, str) else ""
            if not name:
                name = f"scenario-{index + 1}"
                warnings.append(f"scenario[{index}] has no stable name")

            raw_status = raw_scenario.get("status")
            status = raw_status.strip() if isinstance(raw_status, str) else "unknown"
            raw_file = raw_scenario.get("file")
            file_path = raw_file.strip() if isinstance(raw_file, str) else ""

            screenshot_exists = False
            screenshot_bytes = 0
            if file_path:
                screenshot = root / file_path
                if screenshot.is_file():
                    screenshot_exists = True
                    try:
                        screenshot_bytes = screenshot.stat().st_size
                    except OSError:
                        screenshot_bytes = 0
            else:
                warnings.append(f"scenario {name!r} has no screenshot file")

            if not screenshot_exists or screenshot_bytes <= 0:
                warnings.append(f"scenario {name!r} screenshot is unavailable or empty")

            scenarios.append(
                {
                    "name": name,
                    "status": status,
                    "file": file_path or None,
                    "screenshotExists": screenshot_exists,
                    "screenshotBytes": screenshot_bytes,
                }
            )

    passed_count = sum(1 for scenario in scenarios if scenario["status"] == "passed")
    failed_count = sum(1 for scenario in scenarios if scenario["status"] == "failed")
    unavailable_count = sum(
        1
        for scenario in scenarios
        if not scenario["screenshotExists"] or scenario["screenshotBytes"] <= 0
    )

    evidence_complete = (
        manifest is not None
        and source_sha is not None
        and profile is not None
        and capture_exit_code == 0
        and bool(scenarios)
        and passed_count == len(scenarios)
        and unavailable_count == 0
    )
    if evidence_complete:
        evidence_status = "complete"
    elif manifest is None:
        evidence_status = "unavailable"
    else:
        evidence_status = "incomplete"

    return {
        "schemaVersion": SUMMARY_SCHEMA_VERSION,
        "sourceSha": source_sha,
        "profile": profile,
        "captureExitCode": capture_exit_code,
        "evidenceStatus": evidence_status,
        "scenarioCounts": {
            "total": len(scenarios),
            "passed": passed_count,
            "failed": failed_count,
            "unavailable": unavailable_count,
        },
        "scenarios": scenarios,
        "warnings": warnings,
    }


def render_h_review_input(summary: dict[str, Any]) -> str:
    profile = summary.get("profile")
    profile_name = "unavailable"
    if isinstance(profile, dict):
        raw_name = profile.get("name")
        if isinstance(raw_name, str) and raw_name.strip():
            profile_name = raw_name.strip()

    lines = [
        "# UI audit review input",
        "",
        f"- Source SHA: `{summary.get('sourceSha') or 'unavailable'}`",
        f"- Evidence status: `{summary.get('evidenceStatus', 'unavailable')}`",
        f"- Capture test exit code: `{summary.get('captureExitCode') if summary.get('captureExitCode') is not None else 'unavailable'}`",
        f"- Profile: `{profile_name}`",
        "",
        "## Scenarios",
        "",
        "| Scenario | Status | Screenshot | Bytes |",
        "| --- | --- | --- | ---: |",
    ]

    scenarios = summary.get("scenarios")
    if isinstance(scenarios, list) and scenarios:
        for scenario in scenarios:
            if not isinstance(scenario, dict):
                continue
            lines.append(
                "| {name} | {status} | {file} | {size} |".format(
                    name=scenario.get("name", "unknown"),
                    status=scenario.get("status", "unknown"),
                    file=scenario.get("file") or "unavailable",
                    size=scenario.get("screenshotBytes", 0),
                )
            )
    else:
        lines.append("| unavailable | unavailable | unavailable | 0 |")

    warnings = summary.get("warnings")
    if isinstance(warnings, list) and warnings:
        lines.extend(["", "## Evidence warnings", ""])
        lines.extend(f"- {warning}" for warning in warnings)

    lines.extend(
        [
            "",
            "## H advisory review",
            "",
            "- **New actionable findings:** review required; create/refine exactly one focused A–G Issue only for concrete reproducible gaps.",
            "- **Known findings already owned:** search live Issues first and link existing ownership instead of duplicating work.",
            "- **Suspected / subjective observations:** record separately and request human confirmation when the conclusion is ambiguous.",
            "- **Overall outcome:** use `no new actionable UX finding` when the evidence reveals no concrete new gap.",
            "",
            "> Screenshot evidence is advisory and source-SHA-bound. It does not replace live code, behavioral tests, accessibility checks, or product requirements.",
            "",
        ]
    )
    return "\n".join(lines)


def write_report_bundle(root: Path) -> dict[str, Any]:
    root.mkdir(parents=True, exist_ok=True)
    summary = build_summary(root)
    (root / "machine-summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    (root / "h-review-input.md").write_text(
        render_h_review_input(summary),
        encoding="utf-8",
    )
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default="build/ui_audit")
    args = parser.parse_args()
    root = Path(args.root)
    summary = write_report_bundle(root)
    print(
        "ui_audit_report: "
        f"status={summary['evidenceStatus']} "
        f"source={summary.get('sourceSha') or 'unavailable'} "
        f"scenarios={summary['scenarioCounts']['total']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
