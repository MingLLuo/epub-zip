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
4. **The input is immutable.** No conflict policy, including replace, may select the input or an
   output whose containment relationship could destroy it.
5. **Existing output is preserved.** The GUI chooses a unique name. The CLI requires `--force`
   for replacement. A failed replacement restores the previous output.
6. **Accepted work remains visible.** A graphical batch records every success, warning, and failure
   and never acknowledges a drop that it then silently discards.
7. **The GUI and CLI share one core.** There is one implementation of packing, extraction, and
   inspection behavior.
8. **The validation boundary is stated honestly.** Container checks are built in; complete
   publication conformance remains EPUBCheck's job.

## Technology choices

| Decision | Chosen approach | Reason | Rejected alternative |
|---|---|---|---|
| Priority platform | Swift 6 and SwiftUI on macOS 13+ | Native drag/drop, Apple Silicon output, small deployment | Electron or a browser UI adds a runtime and larger distribution |
| ZIP implementation | ZIPFoundation 0.9.20 | MIT-licensed Swift API, streaming, Apple `libcompression`, ZIP64 | Shelling out makes behavior environment-dependent and weakens path control |
| Architecture | `EPUBZipCore` + thin GUI + thin CLI | One rule set, independently testable | Separate implementations drift |
| Validation | Shared strict OCF inspection | One namespace/hierarchy/media-type interpretation for all operations | Best-effort or duplicate parsers create acceptance drift |
| Output strategy | Temporary sibling followed by commit | Invalid work never becomes the advertised result | Direct destination writes expose partial output |
| Localization | Typed per-target message catalogs | Translation pairs remain reviewable at intent-driven call sites | Scattered inline pairs are difficult to test |
| GUI workflow | Sequential, appendable batch queue | Predictable disk pressure and complete per-item reporting | Concurrent writes complicate conflicts and recovery |
| Release trust | Ad-hoc locally; Developer ID + notarization for production | Separates developer convenience from publisher identity | Calling an ad-hoc bundle a release misleads users |

## Why ZIPFoundation is reused

ZIPFoundation already owns difficult ZIP mechanics: central-directory parsing, Deflate,
checksums, streaming reads and writes, and ZIP64 details. Reimplementing those primitives would
increase both security and interoperability risk.

EPUB Zip deliberately keeps EPUB-specific policy above the library:

- force `mimetype` to be the first entry and Store-compressed;
- inspect its first local header and require exact `application/epub+zip` bytes;
- parse `META-INF/container.xml` once and require its OCF namespace, hierarchy, version,
  `full-path`, and OPF media type;
- reject traversal, symlinks, duplicates, case collisions, and file/directory topology conflicts;
- enforce entry and path limits while iterating, then enforce declared and actual extraction sizes;
- use deterministic ordering, timestamps, and permissions.

This division benefits from a mature archive library without confusing generic ZIP support with
EPUB conformance. The exact dependency version and MIT notice are pinned and included in binary
distributions.

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

The final output is resolved before temporary work begins and then compared against the input.
Packing rejects an output equal to or inside the source directory. Extraction rejects an output
equal to or containing the input EPUB. These rules remain mandatory for the replace policy, because
`--force` grants permission to replace an output—not to destroy the input.

Containment checks canonicalize the nearest existing ancestor before comparing components. This
matters on macOS because `/tmp` and `/private/tmp` can name the same location; purely lexical
comparison can produce both false positives and false negatives.

Archive metadata is attacker-controlled. The inspector uses an available classic EOCD count as an
early rejection, but still bounds the iterator itself before retaining entries. Total and
per-component path bytes are bounded before filesystem mapping. A shared trie catches topology
conflicts such as an `EPUB` file alongside `EPUB/package.opf`.

Packed entries use a fixed timestamp, regular-file permissions, and lexical order after the first
`mimetype` entry. Identical supported source trees create identical EPUB bytes, which helps review
and caching. This promise covers the EPUB container; Swift binaries and DMGs can still vary with
Xcode, SDK, signing timestamp, or packaging environment.

## Why OCF parsing is strict and shared

`container.xml` controls which package document the tool trusts. Treating the root namespace,
`container/rootfiles/rootfile` hierarchy, version `1.0`, `full-path`, or
`application/oebps-package+xml` media type as optional would let a malformed publication pass one
path and fail later in another.

The same `OCFContainer` parser is used for source validation and archive inspection. Required OCF
fields are errors. The parser may ignore explicitly foreign extension namespaces and the OCF
`links` subtree, but it does not reinterpret unknown elements in the OCF namespace.

## Why the GUI uses a sequential batch

Users commonly select or drop more than one book. A single “latest result” loses evidence when an
earlier item fails or warns, while rejecting input during a running task makes the drop interaction
unreliable. The app maintains an appendable queue, processes one item at a time, and stores all
successes and failures for the final summary.

Sequential processing keeps disk pressure and conflict-name selection deterministic. It also
creates a small testable state model: idle, working with live counts, and finished with the complete
summary. The resizable, scrollable result view and explicit progress accessibility values keep that
state observable without adding a document-management interface.

## Localization structure

`LocalizedMessage` stores English and Simplified Chinese together and can resolve either language
explicitly in tests. Runtime detection checks `EPUBZIP_LANGUAGE` first, then the macOS preferred
language list, and finally falls back to English.

Only English and Simplified Chinese are supported. Traditional Chinese is not silently treated as
Simplified Chinese; like every other unsupported language, it falls back to English. This is more
honest than presenting a different written standard as if it were a matching translation.

Messages are grouped by responsibility:

```text
CoreStrings   EPUB/ZIP validation and filesystem errors
AppStrings    SwiftUI labels, progress, and batch summaries
CLIStrings    terminal output, summaries, and usage text
```

Adding a language requires extending `EPUBZipLanguage`, `LocalizedMessage`, and each catalog;
business code should not change. If the language set grows enough to need external translators, the
catalog API can remain while storage moves to String Catalog resources.

## Distribution and privacy boundary

The app bundle includes a purpose-built icon and an Apple privacy manifest declaring no tracking or
collected data. The manifest also records the required-reason API category used for app settings.
Keeping these beside bundle metadata lets packaging verification detect an omitted resource.

Ad-hoc signing is sufficient to verify a locally assembled bundle but conveys no publisher
identity. A production release requires a Developer ID certificate, Hardened Runtime, Apple
notarization, a stapled ticket, and Gatekeeper assessment. The repository automates and documents
those checks, but maintainer credentials remain an external prerequisite. This is why 0.4.0 is
described as public beta until a specific distributed artifact passes the production gate.

Binary packages include both the project MIT license and the ZIPFoundation notice. Reusing a
permissive dependency reduces implementation risk, but it does not remove attribution obligations.

## Maturity without scope inflation

For this filesystem utility, maturity means that destructive boundaries are explicit and tested,
the GUI does not lose batch outcomes, builds are versioned and inspectable, dependencies and
licenses are reviewable, and production trust claims are verifiable. It does not mean growing into
an EPUB editor or duplicating EPUBCheck.

The maintained gates are recorded in
[`ADR 0003`](adr/0003-maturity-and-release-gates.md), the operational sequence in
[`releasing.md`](releasing.md), and the supported threat boundary in
[`../SECURITY.md`](../SECURITY.md).

## Non-goals

- DRM removal, decryption, or font deobfuscation
- repair of damaged EPUBs
- ebook format conversion
- metadata editing or library management
- full publication validation
- preservation of archive ownership, ACLs, executable bits, or extended attributes

These boundaries keep the app understandable and make security-sensitive behavior reviewable.
