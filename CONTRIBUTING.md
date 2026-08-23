# Contributing

Issues and pull requests are welcome.

## Development requirements

- macOS 13 or later on Apple Silicon for the primary supported build
- Xcode 16 or later, including the Swift 6 toolchain
- the command-line developer tools selected with `xcode-select`

ZIPFoundation 0.9.20 is resolved from `Package.resolved`. Do not update a locked dependency as a
side effect of an unrelated change.

## Local workflow

```bash
make format
make lint
make test
make example
make verify
make build
make app
```

`make verify` checks version copies, the dependency lock, required license/privacy resources, and
packaging prerequisites. Run it before creating release artifacts. A locally produced app is
ad-hoc signed and remains a development build; maintainers follow
[`docs/releasing.md`](docs/releasing.md) for a production release.

## Change requirements

Changes to archive inspection, packing, extraction, path handling, OCF parsing, or output commit
logic must include a focused regression test. Security-sensitive tests should demonstrate the
relevant invariant, including:

- no file is written outside the temporary output directory;
- the input is never replaced, even with the replace policy;
- a failed operation preserves or restores an existing destination;
- entry, path, size, and compression limits are enforced before unsafe work;
- duplicate, case-colliding, and file/directory-topology paths are rejected.

GUI queue changes should test multiple inputs, partial failure, warnings, and items added while a
batch is running. Accessibility or layout changes should keep long diagnostics reachable without a
fixed window-size assumption.

Keep the project focused and the main window simple. Add dependencies only when they provide a
clear, reviewed security or interoperability benefit. A dependency change must include:

- a rationale and rejected alternatives;
- an upstream version or commit pin;
- license compatibility and an update to `THIRD_PARTY_NOTICES.md`;
- tests for the integration boundary.

ZIPFoundation is the only runtime dependency in the current architecture.

## Localization and documentation

Keep localized text in the typed catalog for its target (`CoreStrings`, `AppStrings`, or
`CLIStrings`). Do not place parallel English and Chinese literals in business logic or SwiftUI
layout code. Add a deterministic localization test when changing language detection. English and
Simplified Chinese are supported; Traditional Chinese and every other unsupported language must
fall back to English.

Keep `README.md` and `README.en.md` equivalent in scope, examples, version numbers, maturity
claims, and release warnings. Bilingual operational instructions belong in `docs/usage.md`.

Documentation that states an EPUB or ZIP requirement should link to the normative source listed in
`docs/references.md`. The included `Examples/MinimalBook` must remain packable with `make example`.

## Design and Git history

Important design changes should be recorded as a short ADR under `docs/adr/` and committed
separately from their implementation. Prefer small commits that each preserve a buildable,
reviewable state:

1. record the decision or release gate;
2. implement the core invariant and tests;
3. update the GUI/CLI integration;
4. update documentation and packaging.

Do not rewrite an accepted ADR to hide a superseded decision. Add an amendment or a new ADR and link
the replacement. Avoid committing `dist/`, local build caches, Finder metadata, credentials, or
notarization profiles.

## Pull-request checklist

- [ ] Formatting and lint pass.
- [ ] Core and GUI state tests pass.
- [ ] `make example` and `make verify` pass.
- [ ] Security-sensitive behavior has a regression test.
- [ ] English and Simplified Chinese remain complete and deterministic.
- [ ] Public API, usage, security, and changelog documentation is updated where applicable.
- [ ] New dependencies and bundled resources have license and privacy review.
