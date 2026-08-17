# Security policy

## Reporting a vulnerability

Please do not publish an exploitable archive before a fix is available. Open a private security advisory in the repository hosting service and include:

- the affected version or commit;
- a minimal reproducer;
- expected and observed filesystem effects;
- whether existing output can be overwritten or data can escape the destination.

## Security model

EPUB files and source directory names are treated as untrusted. The Swift core rejects path
traversal, symbolic links, duplicate entries, case-insensitive collisions, ZIP encryption,
excessive expansion ratios, and configured size limits. Archive paths are compared after
canonicalizing their nearest existing ancestor so macOS aliases such as `/tmp` and `/private/tmp`
cannot bypass containment checks.

Extraction writes only into a fresh sibling temporary directory. Archive ownership, ACLs,
extended attributes, and executable permissions are not restored. A result is moved into its final
location only after extraction and OCF validation succeed.

These controls reduce risk but do not replace operating-system isolation when processing hostile
archives. Full protection still depends on Swift/Foundation, ZIPFoundation, and filesystem
semantics. The exact validation boundary is documented in
[`docs/design-rationale.md`](docs/design-rationale.md).
