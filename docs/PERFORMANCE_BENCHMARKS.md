# Performance benchmarks

The repository performance benchmark is an **advisory measurement harness**, not a merge gate.
It exists to make long-term scaling changes visible before optimization work is proposed.

## What is measured

`tool/performance_benchmark.dart` builds a deterministic synthetic workspace in an isolated in-memory database and then measures production application boundaries for:

1. Generic Database page-state loading;
2. healthy canonical Search preparation through `ObjectGlobalSearchService.prepareWorkspace()`, starting from an already-built deterministic index;
3. canonical Object Search queries against that healthy index;
4. explicit canonical Search rebuild/repair through `ObjectGlobalSearchService.rebuildWorkspace()`;
5. Relation picker selection/candidate loading.

Fixture creation, schema/bootstrap work and the initial Search index construction are setup costs and are intentionally excluded from scenario timings. The explicit rebuild scenario is the exception: it times the production rebuild boundary on purpose so healthy Search-open preparation is not conflated with repair cost.

## Profiles

- `small`: fast smoke validation used by normal Flutter Test and benchmark-related pull requests;
- `medium`: useful manual investigation profile and the manual workflow default;
- `large`: scheduled trend profile with thousands of Objects.

The generated data contains no personal Vault content, network dependency or wall-clock-derived fixture values.

## Running locally

A benchmark run imports Flutter application code, so execute it through the Flutter test runner rather than a pure `dart run` VM. The environment contract below is the same one used by the repository workflow:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
mkdir -p build/performance

PERFORMANCE_BENCHMARK_PROFILE=medium \
PERFORMANCE_BENCHMARK_SOURCE_SHA="$(git rev-parse HEAD)" \
PERFORMANCE_BENCHMARK_WARMUPS=1 \
PERFORMANCE_BENCHMARK_SAMPLES=5 \
PERFORMANCE_BENCHMARK_JSON_PATH=build/performance/run-1.json \
PERFORMANCE_BENCHMARK_MARKDOWN_PATH=build/performance/run-1.md \
  flutter test test/performance_benchmark_smoke_test.dart --reporter=expanded
```

The test writes the requested JSON/Markdown files after validating their shape. Run the same command again with `run-2.json` / `run-2.md` (and optionally a third run) before aggregating unchanged-source variance. Keep the source SHA, profile and runtime equivalent across those repetitions.

To measure unchanged-source variance, produce at least two reports with the same source SHA/profile/runtime/fixture and aggregate them:

```sh
dart run tool/performance_benchmark_variance.dart \
  --input=build/performance/run-1.json \
  --input=build/performance/run-2.json \
  --input=build/performance/run-3.json \
  --json=build/performance/variance.json \
  --markdown=build/performance/variance.md
```

The aggregator fails closed instead of comparing unlike reports when source SHA, profile, runtime, fixture, or ordered scenario identity differs.

## CI repetition contract

The GitHub Actions `Performance Benchmark` workflow keeps each ordinary per-run JSON/Markdown report and also uploads a cross-run variance report with source-SHA provenance.

- benchmark-related pull requests run two independent `small` repetitions so the aggregation path stays bounded while still being exercised;
- weekly scheduled runs use three independent `large` repetitions;
- manual runs use three repetitions of the selected profile.

For each scenario, the variance report records the cross-run min/median/max of the ordinary run medians and p95 values, plus relative spread:

```text
(max - min) / cross-run median
```

That spread is evidence about runner/runtime noise for an unchanged source, not a regression threshold.

## Interpreting results

GitHub-hosted runners have unavoidable timing variance. Do not create a blocking millisecond threshold from one run.
Before proposing a regression budget:

1. compare the same source/profile, Flutter/Dart runtime and operating-system runner class;
2. inspect multiple independent benchmark repetitions, not only the samples inside one invocation;
3. use each run's median/p95 together with the variance report's cross-run relative spread;
4. treat the observed unchanged-source spread as a lower bound on normal measurement noise rather than a product regression by itself;
5. only promote a narrow metric to a blocking budget when repeated evidence shows the proposed threshold is comfortably outside normal variance.

The aggregate report is intentionally advisory. This slice does not introduce a blocking timing threshold or historical performance database.

A performance regression should first identify a measured production bottleneck. Benchmark infrastructure changes and product optimization changes should remain separate whenever practical.
