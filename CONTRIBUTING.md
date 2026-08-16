# Contributing

Issues and pull requests are welcome.

## Before submitting a change

```bash
go fmt ./...
go vet ./...
go test -race ./...
```

Changes to archive parsing or extraction must include a regression test. Security-sensitive tests should demonstrate that no file is written outside the temporary output directory and that a failed operation preserves an existing destination.

Please keep the project dependency-free unless a new dependency provides a clear, reviewed security or interoperability benefit.
