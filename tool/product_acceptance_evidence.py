#!/usr/bin/env python3
"""Advisory Product Acceptance Evidence check for pull requests.

The first rollout is intentionally non-blocking for missing product evidence.
It classifies the effective current-base landing diff using production UI paths,
then surfaces missing evidence as GitHub warnings and step-summary guidance.
Internal classifier/diff failures still fail so the advisory itself cannot lie.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import PurePosixPath, Path

from classify_ci_scope import changed_paths, effective_diff_refs

UI_ROOTS = (
    "lib/ui/",
    "lib/views/",
    "lib/widgets/",
)
UI_FEATURE_SUFFIXES = (
    "_page.dart",
    "_screen.dart",
    "_dialog.dart",
    "_view.dart",
    "_widget.dart",
    "_panel.dart",
    "_toolbar.dart",
    "_picker.dart",
)

FIELD_LABELS = {
    "host": "Real host / user scenario",
    "interaction": "Interaction evidence",
    "visual": "Visual evidence",
    "keyboard": "Keyboard / focus",
    "states": "Empty / loading / error",
    "shared": "Shared-host consistency",
    "acceptance": "Acceptance criterion",
}
PLACEHOLDERS = {
    "",
    "n/a",
    "na",
    "none",
    "not applicable",
    "todo",
    "tbd",
    "pending",
    "-",
}


@dataclass(frozen=True)
class EvidenceResult:
    required: bool
    status: str
    ui_paths: tuple[str, ...]
    fields: dict[str, str]
    missing: tuple[str, ...]
    head_sha: str


def probable_user_facing_ui_path(path: str) -> bool:
    normalized = path.strip().replace("\\", "/")
    if not normalized or not normalized.startswith("lib/"):
        return False
    if normalized == "lib/main.dart":
        return True
    if any(normalized.startswith(prefix) for prefix in UI_ROOTS):
        return True
    if normalized.startswith("lib/features/"):
        if "/presentation/" in normalized:
            return True
        name = PurePosixPath(normalized).name
        return name.endswith(UI_FEATURE_SUFFIXES)
    return False


def _normalize_value(value: str) -> str:
    return " ".join(value.strip().split())


def _is_present(value: str) -> bool:
    return _normalize_value(value).lower() not in PLACEHOLDERS


def parse_evidence_fields(body: str) -> dict[str, str]:
    values = {key: "" for key in FIELD_LABELS}
    if not body:
        return values
    for key, label in FIELD_LABELS.items():
        pattern = re.compile(
            rf"^\s*-\s*{re.escape(label)}\s*:\s*(.*?)\s*$",
            flags=re.IGNORECASE | re.MULTILINE,
        )
        match = pattern.search(body)
        if match:
            values[key] = _normalize_value(match.group(1))
    return values


def evaluate(paths: list[str], body: str, head_sha: str) -> EvidenceResult:
    ui_paths = tuple(sorted(path for path in paths if probable_user_facing_ui_path(path)))
    fields = parse_evidence_fields(body)
    if not ui_paths:
        return EvidenceResult(
            required=False,
            status="not-required",
            ui_paths=(),
            fields=fields,
            missing=(),
            head_sha=head_sha,
        )

    missing: list[str] = []
    if not _is_present(fields["host"]):
        missing.append(FIELD_LABELS["host"])
    if not _is_present(fields["acceptance"]):
        missing.append(FIELD_LABELS["acceptance"])
    if not (_is_present(fields["interaction"]) or _is_present(fields["visual"])):
        missing.append("Interaction evidence or Visual evidence")

    return EvidenceResult(
        required=True,
        status="complete" if not missing else "incomplete",
        ui_paths=ui_paths,
        fields=fields,
        missing=tuple(missing),
        head_sha=head_sha,
    )


def _write_output(name: str, value: str) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with Path(output_path).open("a", encoding="utf-8") as handle:
            handle.write(f"{name}={value}\n")
    else:
        print(f"{name}={value}")


def _append_summary(result: EvidenceResult) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return

    lines = [
        "## Product Acceptance Evidence — advisory",
        "",
        f"- Effective PR head: `{result.head_sha or 'unavailable'}`",
        f"- Likely user-facing production UI diff: `{'yes' if result.required else 'no'}`",
        f"- Evidence status: `{result.status}`",
        "- Policy: advisory first rollout; missing product evidence does not change required `merge-gate`.",
    ]
    if result.ui_paths:
        lines.extend(["", "### Classified UI paths", ""])
        lines.extend(f"- `{path}`" for path in result.ui_paths[:20])
        if len(result.ui_paths) > 20:
            lines.append(f"- … and {len(result.ui_paths) - 20} more")

    if result.required:
        lines.extend(["", "### Evidence", ""])
        for key in ("host", "interaction", "visual", "keyboard", "states", "shared", "acceptance"):
            value = result.fields[key] or "not supplied"
            lines.append(f"- **{FIELD_LABELS[key]}:** {value}")
        if result.missing:
            lines.extend(["", "### Missing evidence", ""])
            lines.extend(f"- {item}" for item in result.missing)
        else:
            lines.extend(
                [
                    "",
                    "Evidence fields are present. Reviewers must still verify that the evidence actually proves the focused Issue acceptance on the real host; this check never auto-accepts screenshots or changed goldens.",
                ]
            )
    else:
        lines.extend(
            [
                "",
                "No likely user-facing production UI path was detected, so this PR is not asked to fabricate screenshots or interaction evidence. H/reviewers may still request evidence when the actual behavior is user-facing despite the conservative path heuristic.",
            ]
        )

    with Path(summary_path).open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", default=os.environ.get("GITHUB_EVENT_NAME", ""))
    parser.add_argument("--base", default=os.environ.get("CI_BASE_SHA", ""))
    parser.add_argument("--head", default=os.environ.get("CI_HEAD_SHA", ""))
    parser.add_argument("--body", default=os.environ.get("PRODUCT_ACCEPTANCE_PR_BODY", ""))
    args = parser.parse_args()

    if args.event != "pull_request":
        result = EvidenceResult(
            required=False,
            status="not-required",
            ui_paths=(),
            fields=parse_evidence_fields(args.body),
            missing=(),
            head_sha=args.head,
        )
        _write_output("product_evidence_required", "false")
        _write_output("product_evidence_status", result.status)
        _append_summary(result)
        return 0

    try:
        base_ref, head_ref = effective_diff_refs(
            args.event,
            args.base,
            args.head,
            os.environ.get("GITHUB_SHA", ""),
        )
        paths = changed_paths(base_ref, head_ref)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Unable to classify Product Acceptance Evidence scope: {error}", file=sys.stderr)
        return 2

    result = evaluate(paths, args.body, args.head)
    _write_output("product_evidence_required", "true" if result.required else "false")
    _write_output("product_evidence_status", result.status)
    _append_summary(result)

    if result.required and result.missing:
        missing = ", ".join(result.missing)
        print(
            "::warning title=Product Acceptance Evidence incomplete::"
            f"Likely user-facing UI change is missing: {missing}. "
            "This rollout is advisory; add concise real-host evidence before treating the focused Issue as product-complete."
        )
    elif result.required:
        print("Product Acceptance Evidence fields are present for a likely user-facing UI diff.")
    else:
        print("Product Acceptance Evidence is not required by the conservative UI path classifier.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
