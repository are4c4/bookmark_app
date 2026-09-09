#!/usr/bin/env python3
"""Aggregate Flutter test timings and model a deterministic file-level shard plan."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class FileWeight:
    path: str
    milliseconds: int
    samples: int


@dataclass(frozen=True)
class PlannedFile:
    path: str
    milliseconds: int
    source: str


@dataclass(frozen=True)
class PlannedShard:
    shard: int
    total_milliseconds: int
    files: tuple[PlannedFile, ...]


@dataclass(frozen=True)
class ShardPlan:
    fallback_milliseconds: int
    historical_file_count: int
    inventory_file_count: int
    shards: tuple[PlannedShard, ...]


def _median_int(values: list[int]) -> int:
    if not values:
        raise ValueError("median requires at least one value")
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2 == 1:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) // 2


def _normalize_test_path(raw_path: str) -> str:
    value = raw_path.replace("\\", "/")
    path = Path(value)
    if path.is_absolute():
        raise ValueError(f"absolute test path is not allowed: {raw_path}")
    if any(part in {"", ".", ".."} for part in path.parts):
        raise ValueError(f"invalid test path: {raw_path}")
    normalized = path.as_posix()
    if not normalized.startswith("test/") or not normalized.endswith("_test.dart"):
        raise ValueError(f"unexpected Flutter test path: {normalized}")
    return normalized


def _nonnegative_int(raw: object, field: str, source: Path) -> int:
    if isinstance(raw, bool) or not isinstance(raw, int) or raw < 0:
        raise ValueError(f"invalid {field} in {source.name}")
    return raw


def _positive_int(raw: object, field: str, source: Path) -> int:
    value = _nonnegative_int(raw, field, source)
    if value == 0:
        raise ValueError(f"invalid {field} in {source.name}")
    return value


def load_complete_run(
    directory: Path,
    expected_shards: int = 4,
) -> dict[str, int]:
    if expected_shards <= 0:
        raise ValueError("expected_shards must be positive")
    payload_paths = sorted(directory.glob("test-file-timing-*.json"))
    if not payload_paths:
        raise ValueError(f"no per-file timing payloads in {directory}")

    shard_entries: dict[int, dict[str, int]] = {}
    for payload_path in payload_paths:
        payload = json.loads(payload_path.read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            raise ValueError(f"invalid timing payload: {payload_path.name}")
        shard = payload.get("shard")
        if isinstance(shard, bool) or not isinstance(shard, int):
            raise ValueError(f"invalid shard in {payload_path.name}")
        if shard < 0 or shard >= expected_shards:
            raise ValueError(f"unexpected shard {shard} in {payload_path.name}")
        if shard in shard_entries:
            raise ValueError(f"duplicate shard payload: {shard}")

        files = payload.get("files")
        if not isinstance(files, list):
            raise ValueError(f"invalid files list in {payload_path.name}")
        per_shard: dict[str, int] = {}
        for raw_entry in files:
            if not isinstance(raw_entry, dict):
                raise ValueError(f"invalid file entry in {payload_path.name}")
            raw_path = raw_entry.get("path")
            if not isinstance(raw_path, str):
                raise ValueError(f"invalid path in {payload_path.name}")
            path = _normalize_test_path(raw_path)
            if path in per_shard:
                raise ValueError(f"duplicate file timing in shard {shard}: {path}")
            active = _nonnegative_int(
                raw_entry.get("active_milliseconds"),
                "active_milliseconds",
                payload_path,
            )
            _nonnegative_int(
                raw_entry.get("wall_milliseconds"),
                "wall_milliseconds",
                payload_path,
            )
            _positive_int(
                raw_entry.get("test_count"),
                "test_count",
                payload_path,
            )
            per_shard[path] = active
        shard_entries[shard] = per_shard

    expected = set(range(expected_shards))
    actual = set(shard_entries)
    if actual != expected:
        missing = sorted(expected - actual)
        unexpected = sorted(actual - expected)
        raise ValueError(
            "incomplete timing run: "
            f"missing shards={missing} unexpected shards={unexpected}"
        )

    aggregated: dict[str, int] = {}
    for shard in sorted(shard_entries):
        for path, active in shard_entries[shard].items():
            aggregated[path] = aggregated.get(path, 0) + active
    if not aggregated:
        raise ValueError(f"timing run contains no test files: {directory}")
    return dict(sorted(aggregated.items()))


def build_historical_weights(
    run_directories: list[Path],
    expected_shards: int = 4,
) -> dict[str, FileWeight]:
    if not run_directories:
        raise ValueError("at least one timing run is required")
    runs = [
        load_complete_run(directory, expected_shards=expected_shards)
        for directory in run_directories
    ]
    paths = sorted({path for run in runs for path in run})
    result: dict[str, FileWeight] = {}
    for path in paths:
        samples = [run[path] for run in runs if path in run]
        result[path] = FileWeight(
            path=path,
            milliseconds=_median_int(samples),
            samples=len(samples),
        )
    return result


def discover_test_inventory(repo_root: Path) -> list[str]:
    root = repo_root.resolve()
    test_root = root / "test"
    if not test_root.is_dir():
        raise ValueError(f"test directory does not exist: {test_root}")
    files = sorted(
        path.relative_to(root).as_posix()
        for path in test_root.rglob("*_test.dart")
        if path.is_file()
    )
    if not files:
        raise ValueError("no Flutter test files discovered")
    for path in files:
        _normalize_test_path(path)
    return files


def build_plan(
    inventory: list[str],
    historical_weights: dict[str, FileWeight],
    shard_count: int = 4,
) -> ShardPlan:
    if shard_count <= 0:
        raise ValueError("shard_count must be positive")
    normalized_inventory = [_normalize_test_path(path) for path in inventory]
    if len(set(normalized_inventory)) != len(normalized_inventory):
        raise ValueError("test inventory contains duplicate paths")
    if not normalized_inventory:
        raise ValueError("test inventory is empty")

    known_values = [
        historical_weights[path].milliseconds
        for path in normalized_inventory
        if path in historical_weights
    ]
    fallback = max(1, _median_int(known_values)) if known_values else 1000

    planned_files = [
        PlannedFile(
            path=path,
            milliseconds=(
                historical_weights[path].milliseconds
                if path in historical_weights
                else fallback
            ),
            source="history" if path in historical_weights else "fallback",
        )
        for path in normalized_inventory
    ]
    ordered = sorted(planned_files, key=lambda item: (-item.milliseconds, item.path))

    shard_files: list[list[PlannedFile]] = [[] for _ in range(shard_count)]
    shard_totals = [0 for _ in range(shard_count)]
    for item in ordered:
        target = min(range(shard_count), key=lambda shard: (shard_totals[shard], shard))
        shard_files[target].append(item)
        shard_totals[target] += item.milliseconds

    shards = tuple(
        PlannedShard(
            shard=shard,
            total_milliseconds=shard_totals[shard],
            files=tuple(shard_files[shard]),
        )
        for shard in range(shard_count)
    )
    plan = ShardPlan(
        fallback_milliseconds=fallback,
        historical_file_count=sum(
            1 for path in normalized_inventory if path in historical_weights
        ),
        inventory_file_count=len(normalized_inventory),
        shards=shards,
    )
    validate_plan(plan, normalized_inventory)
    return plan


def validate_plan(plan: ShardPlan, inventory: list[str]) -> None:
    expected = set(inventory)
    assigned: list[str] = [
        item.path for shard in plan.shards for item in shard.files
    ]
    if len(assigned) != len(set(assigned)):
        raise ValueError("planned shards contain duplicate test files")
    actual = set(assigned)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise ValueError(
            f"planned shard coverage mismatch: missing={missing} extra={extra}"
        )
    for shard in plan.shards:
        calculated = sum(item.milliseconds for item in shard.files)
        if calculated != shard.total_milliseconds:
            raise ValueError(f"shard {shard.shard} total does not match file weights")


def summarize_plan(plan: ShardPlan, top_contributors: int = 10) -> list[str]:
    totals = [shard.total_milliseconds for shard in plan.shards]
    average = sum(totals) / len(totals)
    skew = max(totals) / average if average else 0.0
    lines = [
        "## Predicted Flutter file-level shard plan",
        "",
        f"- Test files: `{plan.inventory_file_count}`",
        f"- Files with historical timing: `{plan.historical_file_count}`",
        f"- Fallback weight: `{plan.fallback_milliseconds / 1000:.1f}s`",
        f"- Predicted max / average skew: `{skew:.2f}x`",
        "",
        "| Shard | Files | Predicted weight |",
        "| ---: | ---: | ---: |",
    ]
    for shard in plan.shards:
        lines.append(
            f"| {shard.shard} | {len(shard.files)} | "
            f"{shard.total_milliseconds / 1000:.1f}s |"
        )

    contributors = sorted(
        (item for shard in plan.shards for item in shard.files),
        key=lambda item: (-item.milliseconds, item.path),
    )
    lines.extend(
        [
            "",
            "### Largest planned file weights",
            "",
            "| Rank | Test file | Weight | Source |",
            "| ---: | --- | ---: | --- |",
        ]
    )
    for rank, item in enumerate(contributors[:top_contributors], start=1):
        lines.append(
            f"| {rank} | `{item.path}` | "
            f"{item.milliseconds / 1000:.1f}s | {item.source} |"
        )
    return lines


def write_plan(output_path: Path, plan: ShardPlan) -> None:
    payload = {"version": 1, **asdict(plan)}
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--run-directory",
        action="append",
        type=Path,
        required=True,
        help="Directory containing one complete four-shard timing run; repeatable.",
    )
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--shards", type=int, default=4)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--top-contributors", type=int, default=10)
    args = parser.parse_args()

    try:
        weights = build_historical_weights(
            args.run_directory,
            expected_shards=args.shards,
        )
        inventory = discover_test_inventory(args.repo_root)
        plan = build_plan(inventory, weights, shard_count=args.shards)
        if args.output is not None:
            write_plan(args.output, plan)
        print("\n".join(summarize_plan(plan, args.top_contributors)))
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"Flutter test shard planning failed: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
