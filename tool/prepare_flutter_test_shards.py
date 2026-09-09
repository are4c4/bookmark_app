#!/usr/bin/env python3
"""Prepare and verify deterministic file-level Flutter test shard execution."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import sys
import zlib
from pathlib import Path

import plan_flutter_test_shards as planner

SNAPSHOT_VERSION = 1
SNAPSHOT_ENCODING = "zlib-base64-json"
SNAPSHOT_AGGREGATION = (
    "median_int_of_per_run_sum_active_milliseconds_across_builtin_shards"
)
PLAN_VERSION = 1


def _nonnegative_int(value: object, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise ValueError(f"invalid {field}")
    return value


def _positive_int(value: object, field: str) -> int:
    result = _nonnegative_int(value, field)
    if result == 0:
        raise ValueError(f"invalid {field}")
    return result


def _normalize_path(value: object) -> str:
    if not isinstance(value, str):
        raise ValueError("invalid test path")
    if "\n" in value or "\r" in value or "\0" in value:
        raise ValueError(f"invalid test path: {value!r}")
    normalized = value.replace("\\", "/")
    path = Path(normalized)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise ValueError(f"invalid test path: {value}")
    result = path.as_posix()
    if not result.startswith("test/") or not result.endswith("_test.dart"):
        raise ValueError(f"unexpected Flutter test path: {result}")
    return result


def load_snapshot(
    snapshot_path: Path,
    *,
    expected_source_shards: int = 4,
) -> dict[str, planner.FileWeight]:
    payload = json.loads(snapshot_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("historical timing snapshot must be an object")
    if payload.get("version") != SNAPSHOT_VERSION:
        raise ValueError("unsupported historical timing snapshot version")
    if payload.get("encoding") != SNAPSHOT_ENCODING:
        raise ValueError("unsupported historical timing snapshot encoding")
    if payload.get("aggregation") != SNAPSHOT_AGGREGATION:
        raise ValueError("unsupported historical timing snapshot aggregation")
    if payload.get("expected_source_shards") != expected_source_shards:
        raise ValueError("historical timing snapshot shard contract mismatch")

    source_runs = payload.get("source_runs")
    if not isinstance(source_runs, list) or len(source_runs) < 2:
        raise ValueError("historical timing snapshot requires at least two source runs")
    seen_runs: set[int] = set()
    for run in source_runs:
        if not isinstance(run, dict):
            raise ValueError("invalid source run metadata")
        run_id = _positive_int(run.get("workflow_run_id"), "workflow_run_id")
        if run_id in seen_runs:
            raise ValueError("duplicate source run metadata")
        seen_runs.add(run_id)
        head_sha = run.get("head_sha")
        if not isinstance(head_sha, str) or re.fullmatch(r"[0-9a-f]{40}", head_sha) is None:
            raise ValueError("invalid source run head_sha")
        _positive_int(run.get("file_count"), "source run file_count")

    encoded = payload.get("payload")
    digest = payload.get("payload_sha256")
    if not isinstance(encoded, str) or not isinstance(digest, str):
        raise ValueError("historical timing snapshot payload metadata is missing")
    if re.fullmatch(r"[0-9a-f]{64}", digest) is None:
        raise ValueError("invalid historical timing snapshot digest")
    try:
        compressed = base64.b64decode(encoded, validate=True)
        decoded = zlib.decompress(compressed)
    except (ValueError, zlib.error) as error:
        raise ValueError("historical timing snapshot payload is invalid") from error
    if hashlib.sha256(decoded).hexdigest() != digest:
        raise ValueError("historical timing snapshot digest mismatch")

    entries = json.loads(decoded)
    if not isinstance(entries, list) or not entries:
        raise ValueError("historical timing snapshot contains no file weights")
    weights: dict[str, planner.FileWeight] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("invalid historical file weight entry")
        path = _normalize_path(entry.get("path"))
        if path in weights:
            raise ValueError(f"duplicate historical file weight: {path}")
        milliseconds = _nonnegative_int(entry.get("milliseconds"), "milliseconds")
        samples = _positive_int(entry.get("samples"), "samples")
        weights[path] = planner.FileWeight(path, milliseconds, samples)
    return dict(sorted(weights.items()))


def _parse_plan(plan_path: Path, *, expected_shards: int) -> planner.ShardPlan:
    raw = json.loads(plan_path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or raw.get("version") != PLAN_VERSION:
        raise ValueError("invalid shard plan version")
    fallback = _positive_int(raw.get("fallback_milliseconds"), "fallback_milliseconds")
    historical_count = _nonnegative_int(
        raw.get("historical_file_count"), "historical_file_count"
    )
    inventory_count = _positive_int(raw.get("inventory_file_count"), "inventory_file_count")
    raw_shards = raw.get("shards")
    if not isinstance(raw_shards, list) or len(raw_shards) != expected_shards:
        raise ValueError("invalid shard plan shard count")

    shards: list[planner.PlannedShard] = []
    seen_shards: set[int] = set()
    for raw_shard in raw_shards:
        if not isinstance(raw_shard, dict):
            raise ValueError("invalid shard plan entry")
        shard_id = _nonnegative_int(raw_shard.get("shard"), "shard")
        if shard_id >= expected_shards or shard_id in seen_shards:
            raise ValueError("invalid or duplicate shard id")
        seen_shards.add(shard_id)
        total = _nonnegative_int(
            raw_shard.get("total_milliseconds"), "total_milliseconds"
        )
        raw_files = raw_shard.get("files")
        if not isinstance(raw_files, list):
            raise ValueError("invalid shard file list")
        files: list[planner.PlannedFile] = []
        for raw_file in raw_files:
            if not isinstance(raw_file, dict):
                raise ValueError("invalid planned file entry")
            path = _normalize_path(raw_file.get("path"))
            milliseconds = _nonnegative_int(
                raw_file.get("milliseconds"), "planned file milliseconds"
            )
            source = raw_file.get("source")
            if source not in {"history", "fallback"}:
                raise ValueError("invalid planned file source")
            files.append(planner.PlannedFile(path, milliseconds, source))
        shards.append(planner.PlannedShard(shard_id, total, tuple(files)))

    if seen_shards != set(range(expected_shards)):
        raise ValueError("shard plan ids are incomplete")
    ordered = tuple(sorted(shards, key=lambda shard: shard.shard))
    return planner.ShardPlan(
        fallback_milliseconds=fallback,
        historical_file_count=historical_count,
        inventory_file_count=inventory_count,
        shards=ordered,
    )


def _write_lists(lists_dir: Path, plan: planner.ShardPlan) -> None:
    lists_dir.mkdir(parents=True, exist_ok=True)
    for shard in plan.shards:
        paths = [item.path for item in shard.files]
        if not paths:
            raise ValueError(f"planned shard {shard.shard} is empty")
        target = lists_dir / f"shard-{shard.shard}.txt"
        target.write_text("".join(f"{path}\n" for path in paths), encoding="utf-8")


def _read_list(path: Path) -> list[str]:
    raw = path.read_text(encoding="utf-8")
    if not raw.endswith("\n"):
        raise ValueError(f"shard list must end with newline: {path}")
    lines = raw.splitlines()
    if not lines:
        raise ValueError(f"shard list is empty: {path}")
    return [_normalize_path(line) for line in lines]


def prepare(
    *,
    snapshot_path: Path,
    repo_root: Path,
    output_path: Path,
    lists_dir: Path,
    shard_count: int = 4,
) -> planner.ShardPlan:
    weights = load_snapshot(
        snapshot_path,
        expected_source_shards=shard_count,
    )
    inventory = planner.discover_test_inventory(repo_root)
    plan = planner.build_plan(inventory, weights, shard_count=shard_count)
    planner.validate_plan(plan, inventory)
    if plan.inventory_file_count != len(inventory):
        raise ValueError("planned inventory count mismatch")
    planner.write_plan(output_path, plan)
    _write_lists(lists_dir, plan)
    return plan


def verify(
    *,
    plan_path: Path,
    repo_root: Path,
    lists_dir: Path,
    shard: int,
    shard_count: int = 4,
) -> planner.ShardPlan:
    if shard < 0 or shard >= shard_count:
        raise ValueError("requested shard is outside the plan")
    plan = _parse_plan(plan_path, expected_shards=shard_count)
    inventory = planner.discover_test_inventory(repo_root)
    if plan.inventory_file_count != len(inventory):
        raise ValueError("current test inventory count differs from shard plan")
    planner.validate_plan(plan, inventory)
    history_count = sum(
        1 for planned_shard in plan.shards for item in planned_shard.files
        if item.source == "history"
    )
    if history_count != plan.historical_file_count:
        raise ValueError("historical file count differs from shard plan metadata")

    expected = [item.path for item in plan.shards[shard].files]
    actual = _read_list(lists_dir / f"shard-{shard}.txt")
    if actual != expected:
        raise ValueError(f"shard {shard} file list differs from verified plan")
    return plan


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("--snapshot", type=Path, required=True)
    prepare_parser.add_argument("--repo-root", type=Path, default=Path("."))
    prepare_parser.add_argument("--output", type=Path, required=True)
    prepare_parser.add_argument("--lists-dir", type=Path, required=True)
    prepare_parser.add_argument("--shards", type=int, default=4)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--plan", type=Path, required=True)
    verify_parser.add_argument("--repo-root", type=Path, default=Path("."))
    verify_parser.add_argument("--lists-dir", type=Path, required=True)
    verify_parser.add_argument("--shard", type=int, required=True)
    verify_parser.add_argument("--shards", type=int, default=4)

    args = parser.parse_args()
    try:
        if args.command == "prepare":
            plan = prepare(
                snapshot_path=args.snapshot,
                repo_root=args.repo_root,
                output_path=args.output,
                lists_dir=args.lists_dir,
                shard_count=args.shards,
            )
            print("\n".join(planner.summarize_plan(plan)))
        else:
            plan = verify(
                plan_path=args.plan,
                repo_root=args.repo_root,
                lists_dir=args.lists_dir,
                shard=args.shard,
                shard_count=args.shards,
            )
            print(
                f"Verified shard {args.shard}: "
                f"{len(plan.shards[args.shard].files)} files; "
                f"full inventory={plan.inventory_file_count}"
            )
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"Flutter file-level shard preparation failed: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
