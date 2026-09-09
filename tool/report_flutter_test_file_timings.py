#!/usr/bin/env python3
"""Collect and summarize per-file Flutter test timing diagnostics."""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class FileTiming:
    path: str
    active_milliseconds: int
    wall_milliseconds: int
    test_count: int


@dataclass
class _SuiteState:
    path: str
    first_start: int | None = None
    last_done: int | None = None
    active_milliseconds: int = 0
    test_count: int = 0


@dataclass(frozen=True)
class _ActiveTest:
    suite_id: int
    started_at: int


def _normalize_suite_path(raw_path: str, repo_root: Path) -> str:
    value = raw_path.replace("\\", "/")
    path = Path(value)
    root = repo_root.resolve()
    if path.is_absolute():
        try:
            relative = path.resolve().relative_to(root)
        except ValueError as error:
            raise ValueError(
                f"suite path is outside repository root: {raw_path}"
            ) from error
    else:
        relative = Path(value)
    if any(part in {"", ".", ".."} for part in relative.parts):
        raise ValueError(f"invalid suite path: {raw_path}")
    normalized = relative.as_posix()
    if not normalized.startswith("test/") or not normalized.endswith("_test.dart"):
        raise ValueError(f"unexpected Flutter test suite path: {normalized}")
    return normalized


def collect_file_timings(events_path: Path, repo_root: Path) -> list[FileTiming]:
    suites: dict[int, _SuiteState] = {}
    active_tests: dict[int, _ActiveTest] = {}

    with events_path.open("r", encoding="utf-8") as source:
        for line_number, raw_line in enumerate(source, start=1):
            line = raw_line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError as error:
                raise ValueError(
                    f"invalid JSON event at line {line_number}: {error.msg}"
                ) from error
            if not isinstance(event, dict):
                raise ValueError(f"event at line {line_number} is not an object")
            event_type = event.get("type")
            event_time = event.get("time")
            if not isinstance(event_time, int) or event_time < 0:
                raise ValueError(f"event at line {line_number} has invalid time")

            if event_type == "suite":
                suite = event.get("suite")
                if not isinstance(suite, dict):
                    raise ValueError(
                        f"suite event at line {line_number} has no suite object"
                    )
                suite_id = suite.get("id")
                path = suite.get("path")
                if not isinstance(suite_id, int) or not isinstance(path, str):
                    raise ValueError(
                        f"suite event at line {line_number} has invalid id/path"
                    )
                normalized = _normalize_suite_path(path, repo_root)
                existing = suites.get(suite_id)
                if existing is not None and existing.path != normalized:
                    raise ValueError(f"suite id {suite_id} changed path")
                suites.setdefault(suite_id, _SuiteState(path=normalized))
                continue

            if event_type == "testStart":
                test = event.get("test")
                if not isinstance(test, dict):
                    raise ValueError(
                        f"testStart at line {line_number} has no test object"
                    )
                test_id = test.get("id")
                suite_id = test.get("suiteID")
                if not isinstance(test_id, int) or not isinstance(suite_id, int):
                    raise ValueError(
                        f"testStart at line {line_number} has invalid id/suiteID"
                    )
                if suite_id not in suites:
                    raise ValueError(f"testStart references unknown suite {suite_id}")
                if test_id in active_tests:
                    raise ValueError(f"test id {test_id} started twice")
                active_tests[test_id] = _ActiveTest(
                    suite_id=suite_id,
                    started_at=event_time,
                )
                state = suites[suite_id]
                state.first_start = (
                    event_time
                    if state.first_start is None
                    else min(state.first_start, event_time)
                )
                continue

            if event_type == "testDone":
                test_id = event.get("testID")
                if not isinstance(test_id, int):
                    raise ValueError(
                        f"testDone at line {line_number} has invalid testID"
                    )
                active = active_tests.pop(test_id, None)
                if active is None:
                    raise ValueError(f"testDone references inactive test {test_id}")
                if event_time < active.started_at:
                    raise ValueError(f"test {test_id} completed before it started")
                state = suites[active.suite_id]
                state.active_milliseconds += event_time - active.started_at
                state.last_done = (
                    event_time
                    if state.last_done is None
                    else max(state.last_done, event_time)
                )
                state.test_count += 1

    if active_tests:
        dangling = ", ".join(str(test_id) for test_id in sorted(active_tests))
        raise ValueError(f"incomplete test events for id(s): {dangling}")
    if not suites:
        raise ValueError("no Flutter test suites were reported")

    timings: list[FileTiming] = []
    seen_paths: set[str] = set()
    for suite_id, state in sorted(suites.items()):
        if state.path in seen_paths:
            raise ValueError(f"duplicate suite path reported: {state.path}")
        seen_paths.add(state.path)
        if (
            state.first_start is None
            or state.last_done is None
            or state.test_count == 0
        ):
            raise ValueError(f"suite {suite_id} ({state.path}) has no completed tests")
        timings.append(
            FileTiming(
                path=state.path,
                active_milliseconds=state.active_milliseconds,
                wall_milliseconds=state.last_done - state.first_start,
                test_count=state.test_count,
            )
        )
    return sorted(timings, key=lambda item: item.path)


def write_shard_payload(
    output_path: Path,
    shard: int,
    timings: list[FileTiming],
) -> None:
    payload = {
        "shard": shard,
        "files": [asdict(item) for item in timings],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def load_shard_payloads(directory: Path) -> list[tuple[int, FileTiming]]:
    result: list[tuple[int, FileTiming]] = []
    seen: set[tuple[int, str]] = set()
    for path in sorted(directory.glob("test-file-timing-*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        shard = payload.get("shard")
        files = payload.get("files")
        if not isinstance(shard, int) or not isinstance(files, list):
            raise ValueError(f"invalid file timing artifact: {path.name}")
        for raw in files:
            if not isinstance(raw, dict):
                raise ValueError(f"invalid file timing entry in {path.name}")
            item = FileTiming(
                path=str(raw["path"]),
                active_milliseconds=int(raw["active_milliseconds"]),
                wall_milliseconds=int(raw["wall_milliseconds"]),
                test_count=int(raw["test_count"]),
            )
            key = (shard, item.path)
            if key in seen:
                raise ValueError(
                    f"duplicate file timing: shard {shard} {item.path}"
                )
            seen.add(key)
            result.append((shard, item))
    return result


def summarize_file_timings(
    entries: list[tuple[int, FileTiming]],
    limit: int,
) -> list[str]:
    lines = ["## Slowest Flutter test files", ""]
    if not entries:
        lines.append("⚠️ No per-file timing artifacts were available.")
        return lines
    ranked = sorted(
        entries,
        key=lambda entry: (
            -entry[1].active_milliseconds,
            entry[1].path,
            entry[0],
        ),
    )
    lines.extend(
        [
            "Advisory first-pass timing only; no performance threshold is merge-blocking.",
            "",
            "| Rank | Shard | Test file | Active time | Wall span | Tests |",
            "| ---: | ---: | --- | ---: | ---: | ---: |",
        ]
    )
    for rank, (shard, item) in enumerate(ranked[:limit], start=1):
        lines.append(
            f"| {rank} | {shard} | `{item.path}` | "
            f"{item.active_milliseconds / 1000:.1f}s | "
            f"{item.wall_milliseconds / 1000:.1f}s | {item.test_count} |"
        )
    return lines


def emit_actions_warning(message: str) -> None:
    escaped = (
        message.replace("%", "%25")
        .replace("\r", "%0D")
        .replace("\n", "%0A")
    )
    print(f"::warning title=Flutter Test file timing::{escaped}")


def _collect(args: argparse.Namespace) -> int:
    try:
        timings = collect_file_timings(args.events, args.repo_root)
        write_shard_payload(args.output, args.shard, timings)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        emit_actions_warning(f"Could not collect per-file timings: {error}")
        return 0
    return 0


def _summarize(args: argparse.Namespace) -> int:
    try:
        entries = load_shard_payloads(args.directory)
        lines = summarize_file_timings(entries, args.limit)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        emit_actions_warning(f"Could not summarize per-file timings: {error}")
        return 0
    text = "\n".join(lines) + "\n"
    print(text, end="")
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary:
            summary.write(text)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    collect_parser = subparsers.add_parser("collect")
    collect_parser.add_argument("--events", type=Path, required=True)
    collect_parser.add_argument("--repo-root", type=Path, required=True)
    collect_parser.add_argument("--output", type=Path, required=True)
    collect_parser.add_argument("--shard", type=int, required=True)
    collect_parser.set_defaults(handler=_collect)

    summarize_parser = subparsers.add_parser("summarize")
    summarize_parser.add_argument(
        "--directory",
        type=Path,
        default=Path("ci-artifacts"),
    )
    summarize_parser.add_argument("--limit", type=int, default=15)
    summarize_parser.set_defaults(handler=_summarize)

    args = parser.parse_args()
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
