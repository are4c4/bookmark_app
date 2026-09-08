# Drift migration coordination

Drift schema history is a compatibility contract. Concurrent AI development may safely allow many patch-sized UI/service changes, but schema evolution must behave as a **single-writer lease** because independently valid migration branches can become incompatible when combined.

## Migration-sensitive work

The advisory migration lease currently covers:

- `lib/data/app_database_schema.dart`;
- `lib/data/app_database_migrations.dart`;
- edits to the `schemaVersion` declaration in `lib/data/app_database.dart`.

An ordinary `app_database.dart` refactor does **not** acquire the migration lease unless its diff changes `schemaVersion`. It remains subject to the normal shared-hotspot rules for `app_database.dart`.

## Before starting a migration

1. Re-read the active Issue, current `main`, open PRs, and lane handoff.
2. Search open PRs for migration-sensitive files/schemaVersion ownership.
3. If another migration writer is active, sequence behind it instead of independently choosing a new migration number/order.
4. After the active migration merges, refresh from current `main`, re-read the integrated schema/migration history, then choose the next version/step.

Do not reserve a migration number from chat history or a stale branch. GitHub `main` is authoritative.

## Pull-request audit

`AI Migration Lease Audit` runs a lightweight read-only check on pull requests. For a migration-sensitive PR it inspects other open PRs and warns when another migration owner exists.

The audit distinguishes a real `schemaVersion` diff from unrelated AppDatabase edits. For open PRs it uses the GitHub file patch and falls back to comparing the schemaVersion declaration in base/head file contents if GitHub omits the patch.

Warnings are advisory initially. They are a sequencing requirement to re-audit, not permission for automation to renumber or rewrite another lane's migration.

## Ownership boundaries

The single-writer lease coordinates **when** schema migrations integrate; it does not transfer **what** the schema should mean to Lane G.

- Lane B still owns Relation/data-integrity semantics for integrity-sensitive schema evolution.
- Lane C owns Database/View/schema product UX.
- Primitive/Object/Search/Storage lanes own their domain semantics when their feature requires persistence changes.
- Lane G owns the coordination guard and behavior-preserving migration-body maintenance.

Historical migrations, migration order, import/export/backup compatibility, and user data preservation remain correctness contracts. Never delete or rewrite them merely to resolve branch conflicts.
