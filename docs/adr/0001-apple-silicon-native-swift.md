# ADR 0001: Apple Silicon native Swift architecture

- Status: Accepted
- Date: 2026-08-17

## Context

The original ePub Zip-Unzip 64 3.0 is an Intel AppleScript droplet that delegates to shell tools. The replacement should preserve its direct drag-and-drop experience while prioritizing Apple Silicon, safe path handling, and maintainable open-source code.

The initial Go prototype proved the EPUB container rules and security model, but a command-line-first cross-platform product does not provide the best native macOS experience.

## Prior-art review

| Project | Useful part | Why it is not the product base |
|---|---|---|
| `weichsel/ZIPFoundation` | Mature MIT-licensed Swift ZIP library based on Apple libcompression; streaming, progress, cancellation, ZIP64 | It is a library, not an EPUB application |
| `kyrielie/honeycrisp` | Demonstrates a small native SwiftUI EPUB app with drag and drop | It is an opinionated reader and does not pack EPUB source directories |
| `w3c/epubcheck` | Authoritative full-publication validation | Java runtime and broad validation scope are too heavy for the always-on core |
| `dino-/epub-tools` | Existing EPUB command-line utilities | Haskell CLI; no native macOS drop target |
| `ernestofgonzalez/epub-utils` | Lightweight EPUB inspection ideas | Python inspection library; no EPUB-compliant packing GUI |

No reviewed project combines a native Apple Silicon drop target with focused EPUB-compliant packing and safe unpacking.

## Decision

Use a single Swift package with three products:

1. `EPUBZipCore`, a platform-neutral Swift library containing EPUB/OCF rules and safe archive operations;
2. `epubzip`, a small CLI for automation and tests;
3. `EPUB Zip`, a SwiftUI macOS application with one drop zone and no document-library UI.

Use ZIPFoundation 0.9.20 or newer within the 0.9 series for ZIP primitives. Keep all EPUB-specific checks in `EPUBZipCore`. Do not shell out to `zip`, `unzip`, Finder, or AppleScript.

The release build targets `arm64` first. A universal build remains an optional release artifact, not the architectural baseline.

## UI rule

The main window answers one question: “What did the user drop?”

- Drop a directory: create a sibling `.epub`.
- Drop an `.epub`: create a sibling directory.
- Show progress, the latest result, and a button to reveal it in Finder.
- Put advanced output and safety controls in Settings, not in the main path.

## Validation boundary

The built-in checker covers ZIP/OCF structure needed for safe pack/unpack. Full semantic publication validation remains an optional EPUBCheck integration later.

## Consequences

- The source becomes smaller and more idiomatic for the priority platform.
- Swift Package Manager adds one audited dependency.
- Linux and Windows are no longer first-class GUI targets.
- CLI portability depends on ZIPFoundation's supported platforms, but macOS arm64 is the tested release target.
- The Go prototype remains in Git history as an executable specification during the migration, then is removed from the main tree.
