# ADR 0002: Typed localization catalogs

- Status: Accepted
- Date: 2026-08-17

## Context

Version 0.2 added English by placing English and Simplified Chinese literals together at every
call site. This made language coverage visible, but mixed translation data with archive logic,
SwiftUI layout, and CLI parsing. Language detection also depended directly on process state, which
made it difficult to test without mutating global environment variables.

## Decision

Use a small shared localization value type and one typed catalog per responsibility:

- `LocalizedMessage` stores both supported translations and resolves an explicit language;
- `EPUBZipLocalization` detects an environment override or preferred macOS language;
- `CoreStrings` owns validation and filesystem messages;
- `AppStrings` owns graphical interface text;
- `CLIStrings` owns terminal messages and usage text.

Call sites select a named message and request `.localized`; they do not contain translated
literals. Language detection accepts explicit inputs for deterministic unit tests.

## Why not String Catalog resources yet

The project is a Swift Package with a manually assembled `.app` bundle and a standalone CLI. A
shared value-type catalog keeps GUI, CLI, and core errors consistent without introducing multiple
resource bundles or changing the release script. It also keeps interpolation type-safe and makes
both translations visible in ordinary code review.

If the language count or translator workflow grows, migrating the same typed catalog surface to
`.xcstrings` is compatible with this decision: call sites can remain unchanged.

## Consequences

- Translation pairs are centralized and searchable.
- Business logic becomes shorter and easier to audit.
- Language fallback behavior is explicitly tested.
- Adding a language currently requires extending each message value in source.
- The core continues to use the detected language when constructing human-readable issues; JSON
  issue codes remain stable for automation.
