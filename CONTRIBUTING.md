# Contributing

Issues and pull requests are welcome.

## Before submitting a change

```bash
make format
make test
make build
```

Changes to archive parsing or extraction must include a regression test. Security-sensitive tests should demonstrate that no file is written outside the temporary output directory and that a failed operation preserves an existing destination.

Keep the project focused and the main window simple. Add dependencies only when they provide a clear, reviewed security or interoperability benefit. ZIPFoundation is the only runtime dependency in the initial architecture.

Important design changes should be recorded as a short ADR under `docs/adr/` and committed separately from their implementation.
