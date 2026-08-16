# Security policy

## Reporting a vulnerability

Please do not publish an exploitable archive before a fix is available. Open a private security advisory in the repository hosting service and include:

- the affected version or commit;
- a minimal reproducer;
- expected and observed filesystem effects;
- whether existing output can be overwritten or data can escape the destination.

## Security model

EPUB files and source directory names are treated as untrusted. The project rejects path traversal, symbolic links, duplicate entries, case-insensitive collisions, ZIP encryption, excessive expansion ratios, and configured size limits. Full protection still depends on the Go runtime and operating system filesystem semantics.
