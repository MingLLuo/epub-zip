# Architecture

## Components

```text
SwiftUI drop window ─┐
                     ├─> EPUBZipCore ─> ZIPFoundation ─> Apple libcompression
epubzip CLI ─────────┘
```

`EPUBZipCore` owns EPUB rules, path safety, limits, conflict policy, temporary output, and inspection. ZIPFoundation owns ZIP parsing, compression, decompression, CRC checks, ZIP64 details, and streaming I/O.

The GUI and CLI contain no archive logic.

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

## Native app

The SwiftUI application has one primary drop zone. It uses `Task.detached` to keep archive work off the main actor, then publishes only the final result. GUI conflicts use `.uniquify`; a previous output is never silently replaced.

The release script builds `arm64` by default, creates a conventional `.app` bundle, ad-hoc signs it for local verification, and packages it as a ZIP. Universal `arm64 x86_64` output is optional.

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
