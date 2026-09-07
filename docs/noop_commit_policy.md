# Commit hygiene for AI development

All development lanes must avoid artificial commits created solely to trigger CI or create activity.

- Do not commit temporary marker files such as `noop`, `tmp`, `oops`, `x`, `ignore`, or equivalent files only to force a push/CI rerun.
- Do not create a file and immediately delete it only to obtain another commit.
- Do not push semantic no-op changes, meaningless whitespace changes, or documentation churn solely to restart CI.
- If CI needs to be rerun, prefer the existing workflow/check rerun mechanism when available. If rerun tooling is unavailable, wait for a meaningful code/test/docs change instead of mutating `main` artificially.
- A commit must represent a coherent repository change with a real code, test, documentation, migration, or configuration purpose.
- Never merge artificial CI-trigger commits into `main`.

This rule applies to every AI implementation lane (A–G). See Issue #225 for the maintenance rationale.
