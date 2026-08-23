# Security policy

## Supported versions

Security fixes are developed for the latest minor line. During the 0.4 public beta, the support
policy is:

| Version | Security fixes |
|---|---|
| 0.4.x | Yes |
| 0.3.x and earlier | No; reproduce against the latest version when possible |

The project has not yet declared a stable 1.0 compatibility guarantee. A security fix may tighten
validation and reject an archive accepted by an older version. Still report an older-version issue
if testing the current version is unsafe or impractical; state that limitation in the advisory.

## Reporting a vulnerability

Please do not publish an exploitable archive before a fix is available. Open a private security
advisory in the repository hosting service and include:

- the affected version or commit;
- the smallest safe reproducer or construction steps;
- expected and observed filesystem effects;
- whether existing output can be overwritten, the input can be altered, or data can escape the
  destination;
- macOS and hardware versions, and whether the GUI, CLI, or core API was used.

Do not attach a confidential book when a synthetic archive can demonstrate the issue. Maintainers
will coordinate disclosure after a regression test and fixed build are available; no response-time
SLA is promised for this volunteer project.

## Security model

EPUB archives, source directory contents, entry names, container XML, and requested destinations are
treated as untrusted. The Swift core enforces these invariants before advertising a result:

- normalized relative entry paths only: no absolute paths, NUL, backslashes, empty components,
  `.`, or `..`;
- no symbolic links, duplicate paths, case-insensitive collisions, or a path
  that is both a file and an ancestor/directory;
- bounded entry iteration, path lengths, file size, total extracted size, and compression ratio;
- strict OCF namespace, element hierarchy, version, rootfile path, and OPF media type;
- a resolved output must not replace its input, live inside a packed source, or contain an EPUB
  being extracted; this remains true under `--force`;
- containment compares canonicalized nearest existing ancestors so equivalent macOS paths such as
  `/tmp` and `/private/tmp` cannot bypass the checks.

Default extraction limits are:

| Resource | Limit |
|---|---:|
| Entries | 20,000 |
| One uncompressed file | 512 MiB |
| Total uncompressed data | 2 GiB |
| Compression ratio | 1,000:1 |
| Archive path | 4,096 UTF-8 bytes |
| One path component | 255 UTF-8 bytes |

Inspection separately caps the `mimetype` read at 128 bytes and `container.xml` at 4 MiB; a valid
`mimetype` is exactly 20 bytes.

Extraction writes only into a fresh sibling temporary directory. Archive ownership, ACLs,
extended attributes, and executable permissions are not restored. Regular files receive `0644`
and directories receive `0755`. A result is moved into its final location only after extraction
and OCF validation succeed. Replacement uses a temporary backup and attempts restoration if the
commit fails.

## Scope and residual risk

The built-in checker validates the ZIP/OCF boundary used for safe packing and extraction. It does
not validate package metadata, manifest/spine semantics, XHTML, scripts, media, accessibility, or
reading-system behavior. It also does not remove DRM, repair damaged archives, or scan content for
malware. Use [EPUBCheck](https://github.com/w3c/epubcheck) for publication conformance and an
isolated account or virtual machine for intentionally hostile samples.

Protection still depends on macOS filesystem semantics, Foundation XML parsing,
[ZIPFoundation 0.9.20](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.20), and Apple
`libcompression`. Resource limits reduce denial-of-service risk; they do not make CPU, memory, or
disk consumption constant. The exact validation boundary is documented in
[`docs/design-rationale.md`](docs/design-rationale.md).

## Distribution integrity

`make app` uses an ad-hoc signature by default. That proves bundle consistency during local
development but does not identify a publisher or satisfy the production trust gate. Public
production artifacts must be Developer ID signed with Hardened Runtime, notarized by Apple,
stapled, and assessed by Gatekeeper as described in
[`docs/releasing.md`](docs/releasing.md). Binary packages must include `LICENSE` and
`THIRD_PARTY_NOTICES.md`.
