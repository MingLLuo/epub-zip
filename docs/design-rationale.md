# Design rationale

This document explains why EPUB Zip is intentionally small, native, and focused on the EPUB
container boundary. Normative requirements and project references are collected in
[references.md](references.md).

## Problem statement

The classic ePub Zip-Unzip 64 workflow is valuable because it turns a folder into an EPUB—or an
EPUB back into a folder—with one drag-and-drop action. Its implementation model is dated: an Intel
droplet delegates archive work to shell utilities and gives little visibility into unsafe paths,
resource limits, output replacement, or EPUB-specific ZIP requirements.

The replacement should preserve the direct interaction while making behavior inspectable,
testable, and safe by default on Apple Silicon.

## Product principles

1. **One input determines one action.** A folder is packed; an `.epub` is extracted.
2. **EPUB rules are not generic ZIP defaults.** `mimetype` ordering, compression, exact bytes, and
   local-header fields are checked explicitly.
3. **Untrusted archives are preflighted before writing.** Paths, types, collisions, sizes, and
   expansion ratios are rejected before extraction begins.
4. **Existing work is preserved.** The GUI chooses a unique name. The CLI requires `--force` for
   replacement. A failed replacement restores the previous output.
5. **The GUI and CLI share one core.** There is one implementation of packing, extraction, and
   inspection behavior.
6. **The validation boundary is stated honestly.** Container checks are built in; complete
   publication conformance remains EPUBCheck's job.

## Technology choices

| Decision | Chosen approach | Reason | Rejected alternative |
|---|---|---|---|
| Priority platform | Swift 6 and SwiftUI on macOS 13+ | Native drag/drop, Apple Silicon output, small deployment | Electron or a browser UI would add a runtime and larger distribution |
| ZIP implementation | ZIPFoundation 0.9.x | MIT-licensed Swift API, streaming access, Apple `libcompression`, ZIP64 support | Shelling out to `zip`/`unzip` makes behavior environment-dependent and weakens path control |
| Architecture | `EPUBZipCore` + thin GUI + thin CLI | One rule set, independently testable | Separate GUI and CLI implementations would drift |
| Validation | Focused OCF inspection | Fast enough to run on every operation | Embedding EPUBCheck adds a Java runtime and a much broader responsibility |
| Output strategy | Temporary sibling followed by commit | Invalid or interrupted work does not become the advertised result | Writing directly to the destination exposes partial output |
| Localization | Typed per-target message catalogs | Translations live together; call sites contain intent rather than two long literals | Scattered inline language pairs are hard to review and test |

## Why ZIPFoundation is reused

ZIPFoundation already owns difficult ZIP mechanics: central-directory parsing, Deflate,
checksums, streaming reads and writes, and ZIP64 details. Reimplementing those primitives would
increase both security and interoperability risk.

EPUB Zip deliberately keeps the EPUB-specific policy above the library:

- force `mimetype` to be the first entry and Store-compressed;
- inspect the first local header for an extra field;
- require exact `application/epub+zip` bytes;
- parse `META-INF/container.xml` and locate declared OPF rootfiles;
- reject traversal, symlinks, duplicates, and case-insensitive collisions;
- enforce configured extraction limits;
- use deterministic ordering, timestamps, and permissions.

This division lets the project benefit from a mature library without confusing generic ZIP
support with EPUB conformance.

## Why the checker is intentionally incomplete

The built-in `check` command answers a narrow operational question: “Can this ZIP safely act as an
EPUB OCF container for packing or extraction?” It does not validate package metadata, manifests,
spines, navigation documents, accessibility metadata, content schemas, CSS, or reading-system
behavior.

EPUBCheck is the W3C-maintained conformance checker and remains the correct second step before
publication or distribution. Keeping that boundary avoids misleading users with a partial
“publication valid” claim.

## Safety and determinism

Packing and extraction use sibling temporary paths. The final path is committed only after
validation succeeds. Replacement first moves the old destination to a temporary backup and
restores it if the new commit fails.

Containment checks canonicalize the nearest existing ancestor before comparing components. This
matters on macOS because `/tmp` and `/private/tmp` can name the same location; purely lexical
comparison can produce both false positives and false negatives.

Packed entries use a fixed timestamp, regular-file permissions, and lexical order after the first
`mimetype` entry. Identical source bytes therefore create identical EPUB bytes, which is useful for
review, caching, and reproducible releases.

## Localization structure

`LocalizedMessage` stores English and Simplified Chinese together and can resolve either language
explicitly in tests. Runtime detection checks `EPUBZIP_LANGUAGE` first, then the macOS preferred
language list, and finally falls back to English.

Messages are grouped by responsibility:

```text
CoreStrings   EPUB/ZIP validation and filesystem errors
AppStrings    SwiftUI labels, prompts, and settings
CLIStrings    terminal output, summaries, and usage text
```

Adding a new language requires extending `EPUBZipLanguage`, `LocalizedMessage`, and each catalog;
business code should not change.

## Non-goals

- DRM removal, decryption, or font deobfuscation
- repair of damaged EPUBs
- ebook format conversion
- metadata editing or library management
- full publication validation
- preservation of archive ownership, ACLs, executable bits, or extended attributes

These boundaries keep the app understandable and make security-sensitive behavior reviewable.
