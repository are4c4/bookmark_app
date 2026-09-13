# Support diagnostics privacy contract

Related: #1358

Bookmark support diagnostics are a **local, user-invoked troubleshooting snapshot**. They are not telemetry, crash reporting, backup, export, or a copy of the user's Vault.

## Default output

The default JSON may contain only technical metadata needed to reproduce a problem:

- exact app semantic version, build number, source commit, source state, and release channel;
- operating-system/runtime version information;
- the application database schema version expected by the running build;
- whether a Vault is configured, as a boolean only;
- optional aggregate/technical provider fields that pass the privacy contract;
- a bounded current-session event list containing timestamp, fixed category, severity, and fixed event code only.

Every exported diagnostic field carries:

- `privacy`: its machine-readable privacy class;
- `reason`: a fixed diagnostic reason code describing why the field exists.

Provider IDs, field keys, reason codes, event categories/codes, and provider string values are restricted to fixed lowercase diagnostic tokens. This prevents a provider from relabeling arbitrary user-authored text as technical metadata.

## Excluded by default

The support snapshot must not include:

- Object titles, Body text, notes, aliases, or other user-authored content;
- captured URLs or domains;
- raw absolute local paths or Vault/profile paths;
- user file names or file contents;
- tokens, cookies, credentials, secrets, or request headers;
- database/Vault files or backup archives;
- raw exception messages, stack messages, or unbounded log text.

A provider that requests a disallowed privacy class is rejected as `privacy_rejected`. A provider that fails, returns malformed metadata, duplicates fields, or attempts an arbitrary string where only a fixed token is allowed becomes `unavailable` with `provider_error`. One provider failure must not prevent core diagnostics or other providers from being collected.

## Event retention

`DiagnosticEventBuffer` is in-memory only and bounded to 50 events by default. It stores no free-form message field. When capacity is exceeded, the oldest event is dropped. Events disappear when the process ends unless a future focused Issue explicitly defines another persistence contract.

Current F-owned event examples include support-bundle copy lifecycle and Settings-originated Vault create/open/switch/move failures. These record only fixed codes such as `copy_failed` or `open_failed`; the caught exception text is not retained.

## User action and transport

Settings exposes `診断情報をコピー`. Collection and copy happen only after the user invokes that action. Bookmark does not upload the result or require an external telemetry account/API key. The user decides where, if anywhere, to paste or send the copied JSON.

Adding network upload, persisted diagnostic logs, crash-reporting SDKs, raw error text, Vault identifiers beyond the current boolean, or broader data collection requires a separate focused Issue and a fresh privacy review.
