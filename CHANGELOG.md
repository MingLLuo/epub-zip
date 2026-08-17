# Changelog

All notable changes to EPUB Zip are documented here.

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
