#!/usr/bin/env python3
"""Aggregate Flutter Test shard timing/flake diagnostics for CI summaries."""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ShardTiming:
    shard: int
    elapsed_seconds: int
    first_outcome: str
    rerun_outcome: str

    @property
    def flaky(self) -> bool:
        return self.first_outcome == "failure" and self.rerun_outcome == "success"


def load_timings(directory: Path) -> list[ShardTiming]:
    timings: list[ShardTiming] = []
    for path in sorted(directory.glob("test-timing-*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        timings.append(
            ShardTiming(
                shard=int(payload["shard"]),
                elapsed_seconds=int(payload["elapsed_seconds"]),
                first_outcome=str(payload.get("first_outcome", "unknown")),
                rerun_outcome=str(payload.get("rerun_outcome", "skipped")),
            )
        )
    return sorted(timings, key=lambda item: item.shard)


def summarize(
    timings: list[ShardTiming],
    expected_shards: int,
    skew_warn: float,
    wall_warn_seconds: int,
) -> tuple[list[str], list[str]]:
    warnings: list[str] = []
    lines = ["## Flutter Test health", ""]

    if not timings:
        warnings.append("No shard timing artifacts were available.")
        lines.append("⚠️ No shard timing artifacts were available.")
        return lines, warnings

    if len(timings) != expected_shards:
        warnings.append(f"Expected {expected_shards} shard timings but found {len(timings)}.")

    valid = [timing for timing in timings if timing.elapsed_seconds > 0]
    if not valid:
        warnings.append("No positive shard elapsed times were available.")
        lines.append("⚠️ No positive shard elapsed times were available.")
        return lines, warnings

    total = sum(item.elapsed_seconds for item in valid)
    average = total / len(valid)
    longest = max(valid, key=lambda item: item.elapsed_seconds)
    skew = longest.elapsed_seconds / average if average else 0.0
    flaky = [item for item in timings if item.flaky]

    lines.extend(
        [
            f"- Shards reported: `{len(timings)}/{expected_shards}`",
            f"- Average test time: `{average:.1f}s`",
            f"- Longest shard: `{longest.shard}` at `{longest.elapsed_seconds}s`",
            f"- Max / average skew: `{skew:.2f}x`",
            f"- Fail-then-pass flaky shards: `{', '.join(str(item.shard) for item in flaky) if flaky else 'none'}`",
            "",
            "| Shard | First pass | Rerun | Test time |",
            "| ---: | --- | --- | ---: |",
        ]
    )
    for item in timings:
        lines.append(
            f"| {item.shard} | {item.first_outcome} | {item.rerun_outcome} | {item.elapsed_seconds}s |"
        )

    if skew > skew_warn:
        warnings.append(
            f"Shard skew is {skew:.2f}x (warning threshold {skew_warn:.2f}x); longest shard is {longest.shard}."
        )
    if longest.elapsed_seconds > wall_warn_seconds:
        warnings.append(
            f"Longest shard is {longest.elapsed_seconds}s (warning threshold {wall_warn_seconds}s)."
        )
    if flaky:
        warnings.append(
            "Fail-then-pass rerun detected on shard(s): " + ", ".join(str(item.shard) for item in flaky)
        )

    if warnings:
        lines.extend(["", "### Warnings", *[f"- ⚠️ {warning}" for warning in warnings]])
    return lines, warnings


def emit_actions_warning(message: str) -> None:
    escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::warning title=Flutter Test health::{escaped}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, default=Path("ci-artifacts"))
    parser.add_argument("--expected-shards", type=int, default=int(os.environ.get("EXPECTED_TEST_SHARDS", "4")))
    parser.add_argument("--skew-warn", type=float, default=float(os.environ.get("TEST_SHARD_SKEW_WARN", "1.25")))
    parser.add_argument(
        "--wall-warn-seconds",
        type=int,
        default=int(os.environ.get("TEST_SHARD_WALL_WARN_SECONDS", "360")),
    )
    args = parser.parse_args()

    try:
        timings = load_timings(args.directory)
        lines, warnings = summarize(
            timings,
            expected_shards=args.expected_shards,
            skew_warn=args.skew_warn,
            wall_warn_seconds=args.wall_warn_seconds,
        )
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        emit_actions_warning(f"Could not aggregate shard timing artifacts: {error}")
        return 0

    text = "\n".join(lines) + "\n"
    print(text, end="")
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary:
            summary.write(text)
    for warning in warnings:
        emit_actions_warning(warning)
    return 0


if __name__ == "__main__":
    sys.exit(main())
