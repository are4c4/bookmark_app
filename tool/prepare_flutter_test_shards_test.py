#!/usr/bin/env python3

import base64
import hashlib
import json
import tempfile
import unittest
import zlib
from pathlib import Path

import prepare_flutter_test_shards as prepare


class PrepareFlutterTestShardsTest(unittest.TestCase):
    def _write_snapshot(
        self,
        path: Path,
        entries: list[dict[str, object]],
        *,
        digest_override: str | None = None,
    ) -> None:
        raw = json.dumps(entries, sort_keys=True, separators=(",", ":")).encode()
        payload = {
            "version": 1,
            "encoding": "zlib-base64-json",
            "expected_source_shards": 4,
            "aggregation": (
                "median_int_of_per_run_sum_active_milliseconds_across_builtin_shards"
            ),
            "source_runs": [
                {
                    "workflow_run_id": 1001,
                    "head_sha": "a" * 40,
                    "file_count": len(entries),
                },
                {
                    "workflow_run_id": 1002,
                    "head_sha": "b" * 40,
                    "file_count": len(entries),
                },
            ],
            "payload_sha256": digest_override or hashlib.sha256(raw).hexdigest(),
            "payload": base64.b64encode(zlib.compress(raw, 9)).decode(),
        }
        path.write_text(
            json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )

    def _make_repo(self, root: Path, paths: list[str]) -> None:
        for relative in paths:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("// test\n", encoding="utf-8")

    def test_snapshot_round_trip_and_digest_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            snapshot = root / "weights.json"
            self._write_snapshot(
                snapshot,
                [
                    {"path": "test/a_test.dart", "milliseconds": 1200, "samples": 2},
                    {"path": "test/b_test.dart", "milliseconds": 800, "samples": 2},
                ],
            )
            weights = prepare.load_snapshot(snapshot)
            self.assertEqual(weights["test/a_test.dart"].milliseconds, 1200)
            self.assertEqual(weights["test/a_test.dart"].samples, 2)

            self._write_snapshot(
                snapshot,
                [{"path": "test/a_test.dart", "milliseconds": 1200, "samples": 2}],
                digest_override="0" * 64,
            )
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                prepare.load_snapshot(snapshot)

    def test_prepare_assigns_current_inventory_once_with_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            snapshot = root / "weights.json"
            self._make_repo(
                root,
                [
                    "test/a_test.dart",
                    "test/b_test.dart",
                    "test/new_test.dart",
                    "test/nested/c_test.dart",
                ],
            )
            self._write_snapshot(
                snapshot,
                [
                    {"path": "test/a_test.dart", "milliseconds": 4000, "samples": 2},
                    {"path": "test/b_test.dart", "milliseconds": 2000, "samples": 2},
                    {"path": "test/nested/c_test.dart", "milliseconds": 1000, "samples": 2},
                ],
            )
            plan_path = root / "plan.json"
            lists_dir = root / "lists"
            plan = prepare.prepare(
                snapshot_path=snapshot,
                repo_root=root,
                output_path=plan_path,
                lists_dir=lists_dir,
                shard_count=4,
            )

            assigned = [item.path for shard in plan.shards for item in shard.files]
            self.assertCountEqual(
                assigned,
                [
                    "test/a_test.dart",
                    "test/b_test.dart",
                    "test/new_test.dart",
                    "test/nested/c_test.dart",
                ],
            )
            self.assertEqual(len(assigned), len(set(assigned)))
            by_path = {
                item.path: item for shard in plan.shards for item in shard.files
            }
            self.assertEqual(by_path["test/new_test.dart"].source, "fallback")
            for shard in range(4):
                prepare.verify(
                    plan_path=plan_path,
                    repo_root=root,
                    lists_dir=lists_dir,
                    shard=shard,
                    shard_count=4,
                )

    def test_verify_fails_if_list_or_inventory_changes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            snapshot = root / "weights.json"
            files = [f"test/t{i}_test.dart" for i in range(4)]
            self._make_repo(root, files)
            self._write_snapshot(
                snapshot,
                [
                    {"path": path, "milliseconds": 1000 + i, "samples": 2}
                    for i, path in enumerate(files)
                ],
            )
            plan_path = root / "plan.json"
            lists_dir = root / "lists"
            prepare.prepare(
                snapshot_path=snapshot,
                repo_root=root,
                output_path=plan_path,
                lists_dir=lists_dir,
            )

            shard_zero = lists_dir / "shard-0.txt"
            shard_zero.write_text("test/t1_test.dart\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "differs from verified plan"):
                prepare.verify(
                    plan_path=plan_path,
                    repo_root=root,
                    lists_dir=lists_dir,
                    shard=0,
                )

            prepare.prepare(
                snapshot_path=snapshot,
                repo_root=root,
                output_path=plan_path,
                lists_dir=lists_dir,
            )
            (root / "test" / "added_test.dart").write_text("// added\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "inventory count differs"):
                prepare.verify(
                    plan_path=plan_path,
                    repo_root=root,
                    lists_dir=lists_dir,
                    shard=0,
                )

    def test_malformed_snapshot_metadata_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            snapshot = root / "weights.json"
            self._write_snapshot(
                snapshot,
                [{"path": "../outside_test.dart", "milliseconds": 100, "samples": 2}],
            )
            with self.assertRaisesRegex(ValueError, "invalid test path"):
                prepare.load_snapshot(snapshot)


if __name__ == "__main__":
    unittest.main()
