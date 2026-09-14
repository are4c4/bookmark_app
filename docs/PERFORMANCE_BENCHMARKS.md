# Performance benchmarks

The repository performance benchmark is an **advisory measurement harness**, not a merge gate.
It exists to make long-term scaling changes visible before optimization work is proposed.

## What is measured

`tool/performance_benchmark.dart` builds a deterministic synthetic workspace in an isolated in-memory database and then measures production application boundaries for:

1. Generic Database page-state loading;
2. canonical Object Search queries after the Search index has been built outside the timed operation;
3. Relation picker selection/candidate loading.

Fixture creation, schema/bootstrap work and Search index construction are setup costs and are intentionally excluded from scenario timings.

## Profiles

- `small`: fast smoke validation used by normal Flutter Test and benchmark-related pull requests;
- `medium`: useful manual investigation profile and the manual workflow default;
- `large`: scheduled trend profile with thousands of Objects.

The generated data contains no personal Vault content, network dependency or wall-clock-derived fixture values.

## Running locally

```sh
dart run tool/performance_benchmark.dart \
  --profile=medium \
  --warmups=1 \
  --samples=5 \
  --source-sha=local \
  --json=build/performance/report.json \
  --markdown=build/performance/summary.md
```

The GitHub Actions `Performance Benchmark` workflow uploads the JSON/Markdown report with source-SHA provenance. Benchmark-related pull requests run the `small` profile to prove the workflow itself remains executable, weekly scheduled runs use `large`, and manual runs use the selected profile.

## Interpreting results

GitHub-hosted runners have unavoidable timing variance. Do not create a blocking millisecond threshold from one run.
Before proposing a regression budget:

1. compare the same profile, Flutter/Dart runtime and operating-system runner class;
2. collect multiple unchanged-source runs;
3. use the report's repeated samples (median and p95), not one fastest/slowest sample;
4. document the observed unchanged-source spread for that metric;
5. only promote a narrow metric to a blocking budget when the proposed threshold is comfortably outside normal variance.

A performance regression should first identify a measured production bottleneck. Benchmark infrastructure changes and product optimization changes should remain separate whenever practical.
