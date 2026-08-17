# Contributing

Issues and pull requests are welcome.

## Before submitting a change

```bash
make format
make lint
make test
make build
```

Changes to archive parsing or extraction must include a regression test. Security-sensitive tests should demonstrate that no file is written outside the temporary output directory and that a failed operation preserves an existing destination.

Keep the project focused and the main window simple. Add dependencies only when they provide a clear, reviewed security or interoperability benefit. ZIPFoundation is the only runtime dependency in the initial architecture.

Important design changes should be recorded as a short ADR under `docs/adr/` and committed separately from their implementation.

Keep localized text in the typed catalog for its target (`CoreStrings`, `AppStrings`, or
`CLIStrings`). Do not place parallel English and Chinese literals in business logic or SwiftUI
layout code. Add a deterministic localization test when changing language detection.

Documentation that states an EPUB or ZIP requirement should link to the normative source listed in
`docs/references.md`. The included `Examples/MinimalBook` must remain packable with `make example`.
