# Architecture

## Components

```text
SwiftUI drop window ─┐
                     ├─> EPUBZipCore ─> ZIPFoundation ─> Apple libcompression
epubzip CLI ─────────┘
```

`EPUBZipCore` owns EPUB rules, path safety, limits, conflict policy, temporary output, and inspection. ZIPFoundation owns ZIP parsing, compression, decompression, CRC checks, ZIP64 details, and streaming I/O.

The GUI and CLI contain no archive logic.

Human-readable text is also separated from behavior:

```text
LocalizedMessage + language resolver
  ├── CoreStrings   validation and filesystem errors
  ├── AppStrings    SwiftUI labels and prompts
  └── CLIStrings    terminal output and usage
```

JSON issue `code` values are language-neutral and stable; only their human-readable `message`
changes with the selected language.

## Pack pipeline

```text
source directory
  -> enumerate without following symlinks
  -> validate mimetype and META-INF/container.xml
  -> verify declared OPF rootfiles exist
  -> write a temporary ZIP
       1. mimetype: Store, first, no extra field
       2. remaining files: lexical order, Deflate
  -> inspect generated container
  -> atomically commit output
```

Directory entries and `.DS_Store` files are omitted. Entries use a fixed timestamp and permissions so unchanged inputs produce byte-identical archives.

## Unpack pipeline

```text
EPUB file
  -> inspect OCF container
  -> preflight names, types, counts, sizes, and ratios
  -> extract into a temporary sibling directory with CRC checks
  -> validate extracted structure
  -> atomically commit output
```

Archive permissions are not trusted. Extracted directories use `0755`; regular files use `0644`. Symbolic links and non-normalized paths are rejected.

Containment comparison resolves the nearest existing ancestor before comparing path components.
This handles equivalent macOS aliases such as `/tmp` and `/private/tmp`, including destinations
whose final component does not exist yet.

## Native app

The SwiftUI application has one primary drop zone. It uses `Task.detached` to keep archive work off the main actor, then publishes only the final result. GUI conflicts use `.uniquify`; a previous output is never silently replaced.

The release script builds `arm64` by default, creates a conventional `.app` bundle, ad-hoc signs it
for local verification, and packages it as a DMG and ZIP. The DMG is the user-facing artifact;
universal `arm64 x86_64` output is optional.

## Validation boundary

The built-in checker covers:

- `mimetype` ordering, method, local-header extra fields, and exact content
- readable ZIP central-directory entry count
- safe, normalized, non-colliding entry names
- rejection of symbolic links
- `META-INF/container.xml` parsing
- presence of declared OPF rootfiles

It does not validate package metadata, manifests, spines, navigation documents, accessibility metadata, CSS, media resources, or reading-system behavior. EPUBCheck remains the publication-level validator.

## Explicit non-goals

- DRM removal or decryption
- automatic repair of corrupt ZIP structures
- conversion between EPUB, PDF, MOBI, KFX, or other formats
- preserving ownership, ACLs, executable bits, or extended attributes
- managing an ebook library

## Further reading

- [Design rationale](design-rationale.md)
- [References and prior art](references.md)
- [Usage guide](usage.md)
- [ADR 0001](adr/0001-apple-silicon-native-swift.md)
- [ADR 0002](adr/0002-typed-localization-catalogs.md)
