# Architecture

## System boundary

```text
SwiftUI App ─┐
             ├── EPUBZipCore ── ZIPFoundation 0.9.20 ── Apple libcompression
epubzip CLI ─┘
```

`EPUBZipCore` owns EPUB/OCF rules, path and resource limits, input/output containment, conflict
policy, temporary output, transactional commit, and inspection reports. ZIPFoundation owns ZIP
records, compression/decompression, CRC, ZIP64 mechanics, and streaming I/O. The GUI and CLI
translate user intent into core calls; they do not implement archive policy.

This boundary is deliberate: ZIPFoundation is a generic archive library, while requirements such
as the first stored `mimetype` entry and strict `container.xml` semantics belong to EPUB Zip.

## Core validation components

| Component | Single responsibility |
|---|---|
| `SafeArchivePath` | Reject invalid syntax and enforce total/component UTF-8 byte limits |
| `ArchivePathRegistry` | Detect duplicates, case collisions, and file/directory topology conflicts |
| `OCFContainer` | Parse the OCF namespace, hierarchy, version, and OPF rootfile declarations |
| `EPUBInspector` | Produce a stable report without writing output |
| `EPUBService` | Orchestrate pack/unpack, limits, conflict policy, temporary work, and final commit |
| `ZIPStructure` | Read the small amount of local-header/EOCD data needed for EPUB-specific checks |

Inspection and extraction use the same path and OCF validators. This avoids the dangerous state in
which `check` accepts an archive but extraction interprets its paths or container differently.
JSON issue `code` values remain language-neutral; only their human-readable messages are localized.

## Inspect pipeline

```text
EPUB file
  -> open ZIP
  -> reject classic EOCD entry count above the limit when available
  -> iterate entries with an independent hard bound
  -> inspect first local header and exact mimetype bytes
  -> validate every path and shared path topology
  -> reject symbolic links
  -> parse bounded META-INF/container.xml with OCFContainer
  -> require every declared OPF rootfile to be a regular archive entry
  -> return InspectionReport
```

The entry bound is applied while iterating, not after `Array(archive)` has materialized
attacker-controlled metadata. `mimetype` and `container.xml` reads are also bounded. A ZIP64 or
otherwise unavailable classic count therefore still cannot bypass the iteration limit.

## Pack pipeline

```text
source directory
  -> enumerate without following symbolic links
  -> validate archive-relative paths and source OCF structure
  -> resolve the final conflict policy
  -> reject an output equal to or inside the source
  -> write a temporary sibling ZIP
       1. mimetype: Store, first, no extra field
       2. remaining files: lexical order, Deflate
  -> inspect the generated container
  -> transactionally commit the output
```

Directory entries and `.DS_Store` files are omitted. Entries use fixed timestamps and regular-file
permissions, so identical supported source trees produce byte-identical EPUB containers. This
determinism applies to generated EPUB data, not necessarily to Swift binaries, ZIP distributions,
or DMGs produced by different toolchain versions.

## Unpack pipeline

```text
EPUB file
  -> inspect with the requested ExtractionLimits
  -> resolve the final conflict policy
  -> reject an output equal to or containing the input
  -> create a fresh temporary sibling directory
  -> iterate and preflight entries again with the same bounds
  -> stream extraction while checking actual file and total byte counts
  -> validate the extracted OCF source tree
  -> transactionally commit the output
```

The output-overlap check happens before temporary extraction and still applies to the replace
policy. Containment resolves each path's nearest existing ancestor before component comparison;
this handles equivalent macOS paths such as `/tmp` and `/private/tmp`, including a final
component that does not yet exist.

Archive permissions are not trusted. Extracted directories use `0755`; regular files use `0644`.
Ownership, ACLs, extended attributes, executable bits, and symbolic links are not restored. If a
replacement commit fails, the service attempts to restore the previous destination.

## Default limits

The same `ExtractionLimits` value is passed through inspection and extraction:

| Resource | Default |
|---|---:|
| Entry count | 20,000 |
| One uncompressed file | 512 MiB |
| Total uncompressed data | 2 GiB |
| Compression ratio | 1,000:1 |
| Archive path | 4,096 UTF-8 bytes |
| One path component | 255 UTF-8 bytes |

Library callers can select stricter limits. Invalid or internally inconsistent limit values are
rejected rather than silently normalized.

## Native app state model

```text
idle
  -> working(current item, completed count, live total)
       -> append newly dropped/opened items to the same queue
       -> record each success, warnings, or failure
  -> finished(all successes, all failures)
```

The app processes one item at a time off the main actor. An item failure does not cancel later
items, and a drop accepted while work is active updates the same batch total rather than being
discarded. A completed summary keeps all output paths and diagnostics; “Show in Finder” reveals all
successful outputs. Starting input after completion creates a fresh batch.

The window is resizable and long summaries scroll. Progress has an accessibility label and value,
while decorative state artwork is hidden from assistive technologies. There is intentionally no
document-library, metadata editor, or advanced archive-control surface.

## Localization

```text
LocalizedMessage + language resolver
  ├── CoreStrings   validation and filesystem errors
  ├── AppStrings    SwiftUI labels, progress, and batch summaries
  └── CLIStrings    terminal output and usage
```

English is the base/fallback language; Simplified Chinese is the second supported language.
`EPUBZIP_LANGUAGE` provides deterministic CLI/test selection. Traditional Chinese and every other
unsupported language fall back to English rather than being mapped to Simplified Chinese.

Keeping interpolation and translation pairs in typed catalogs makes missing messages reviewable.
If the language set grows enough to need external translators, the catalog API can be retained
while storage moves to String Catalog resources.

## Application bundle and trust levels

The build assembles a conventional macOS bundle with an app icon, `PrivacyInfo.xcprivacy`, project
license, and third-party notices. It targets `arm64` explicitly by default; a universal
`arm64 x86_64` artifact is optional.

The default local path uses an ad-hoc signature for bundle-integrity checks. A production artifact
adds Developer ID signing with Hardened Runtime, Apple notarization, stapling, and Gatekeeper
assessment. Those trust levels are intentionally not conflated; see [releasing.md](releasing.md).

## Verification strategy

- Core tests cover valid round trips, malformed ZIP/OCF inputs, containment aliases, input
  preservation, entry/path limits, and topology conflicts.
- App-model tests use an injected async processor to cover batch ordering, partial failure,
  warnings, fresh batches, and invalid drops without invoking archive I/O.
- `make example` exercises a real EPUB source tree through packing and inspection.
- `make verify` checks version copies, dependency/resource/license requirements, and packaging
  assumptions.
- CI runs the same public entry points on an Apple Silicon macOS runner and inspects the assembled
  app, not only its unbundled executable.

## Validation boundary and non-goals

The built-in checker covers the ZIP/OCF boundary required for safe pack/unpack. It does not validate
package metadata, manifests, spines, navigation documents, accessibility metadata, XHTML, CSS,
media resources, scripts, or reading-system behavior. EPUBCheck remains the publication-level
validator.

Explicit non-goals are DRM removal, corrupt-archive repair, ebook format conversion, metadata or
library management, and preservation of untrusted filesystem metadata.

## Further reading

- [Design rationale](design-rationale.md)
- [References and prior art](references.md)
- [Usage guide](usage.md)
- [Release guide](releasing.md)
- [Security policy](../SECURITY.md)
- [ADR 0001](adr/0001-apple-silicon-native-swift.md)
- [ADR 0002](adr/0002-typed-localization-catalogs.md)
- [ADR 0003](adr/0003-maturity-and-release-gates.md)
