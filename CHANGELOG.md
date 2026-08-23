# Changelog

All notable changes to EPUB Zip are documented here.

## 0.4.0 — 2026-08-23

- Prevented every operation, including `--force`, from replacing its own input or selecting an
  output whose containment relationship could destroy the input.
- Bounded archive entry iteration before materializing the complete central directory; added
  limits for total path bytes and path-component bytes.
- Added shared path-topology validation to reject file/directory ancestor conflicts in inspection
  and extraction.
- Replaced duplicate `container.xml` parsing with one strict OCF parser that validates the
  namespace, hierarchy, version, rootfile path, and OPF media type.
- Reworked the SwiftUI app around a persistent batch queue that records all successes, warnings,
  and failures, continues after an item error, and reveals all successful outputs.
- Made the window resizable, preserved full diagnostics, and added explicit accessibility labels
  while hiding decorative status imagery.
- Corrected language fallback so Traditional Chinese and every other unsupported locale use
  English instead of Simplified Chinese.
- Added an application icon, a privacy manifest declaring no tracking or collected data, GUI state
  tests, and additional security regression coverage.
- Added version/artifact verification, explicit Apple Silicon packaging checks, license notices,
  and a documented production gate for Developer ID signing, Hardened Runtime, notarization,
  stapling, and Gatekeeper assessment.
- Added clean-source provenance for App/CLI packages and a source archive whose embedded commit ID
  is checked alongside binary artifacts.
- Updated the minimum toolchain to Xcode 16 and kept ZIPFoundation pinned to 0.9.20.

## 0.3.0 — 2026-08-17

- Centralized English and Simplified Chinese text in typed core, app, and CLI catalogs.
- Made language detection deterministic and added localization regression coverage.
- Fixed containment checks for equivalent macOS paths such as `/tmp` and `/private/tmp`.
- Added design rationale, normative references, prior-art comparison, a bilingual usage guide, and
  an executable minimal EPUB 3 example.
- Centralized release artifact naming around the root `VERSION` file.

## 0.2.0 — 2026-08-17

- Added automatic English and Simplified Chinese support across the GUI, CLI, and core errors.
- Added bilingual command-line instructions and an English README.

## 0.1.0 — 2026-08-17

- Added a native SwiftUI drag-and-drop application for Apple Silicon Macs.
- Added EPUB-compliant directory packing with first, stored, extra-field-free `mimetype`.
- Added safe EPUB extraction with path, symlink, collision, size, and compression-ratio checks.
- Added OCF container inspection and JSON output through the CLI.
- Added atomic output commits, non-destructive GUI conflict naming, and reproducible archives.
- Added an `arm64` app packaging script, M1 GitHub Actions CI, seven regression tests, and project documentation.
- Added a user-friendly DMG and packaged the CLI separately with terminal instructions.
