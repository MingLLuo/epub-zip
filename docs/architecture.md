# Architecture

## Design goals

1. Produce OCF-conforming ZIP containers without relying on command-line archive tools.
2. Treat EPUB files and source directories as untrusted input.
3. Never replace a previous output until the new result has completed and passed structural checks.
4. Keep the core deterministic and portable.

## Pack pipeline

```text
source directory
  -> walk without following symlinks
  -> validate mimetype and META-INF/container.xml
  -> verify every declared OPF rootfile exists
  -> write a temporary ZIP
       1. mimetype: Store, no extra field
       2. remaining files: lexical order, Deflate
  -> inspect generated container
  -> atomically commit output
```

Directory entries are omitted. File timestamps are not copied into ZIP headers, so unchanged inputs produce byte-identical archives with the same Go version and compression implementation.

## Unpack pipeline

```text
EPUB file
  -> parse central directory
  -> validate names, types, counts, sizes, and ratios
  -> extract into a temporary sibling directory
  -> validate the extracted OCF structure
  -> atomically commit output
```

Archive permissions are not trusted. Extracted directories use `0755`; regular files use `0644`. Symbolic links and non-normalized paths are rejected.

## Scope of validation

The built-in checker covers the ZIP/OCF boundary:

- `mimetype` ordering, method, extra fields, and exact content
- allowed ZIP compression methods
- absence of ZIP encryption
- safe, normalized, non-colliding entry names
- `META-INF/container.xml` parsing
- presence of declared OPF rootfiles

It does not validate package metadata, manifests, spines, navigation documents, accessibility metadata, CSS, media resources, or reading-system behavior. Run EPUBCheck for publication-level validation.

## Explicit non-goals

- DRM removal or decryption
- automatic repair of corrupt ZIP structures
- conversion between EPUB, PDF, MOBI, KFX, or other formats
- preserving executable bits, ownership, ACLs, or extended attributes
