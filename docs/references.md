# References and prior art

Links in this document point to normative specifications, official platform documentation, or the
upstream open-source projects evaluated for EPUB Zip.

## Normative formats

- [EPUB 3.3 — Open Container Format](https://www.w3.org/TR/epub-33/#sec-ocf): the W3C EPUB
  container model.
- [EPUB 3.3 — file and directory structure](https://www.w3.org/TR/epub-33/#sec-container-file-and-dir-structure):
  requires the common root, `META-INF`, and reserved root `mimetype` file.
- [EPUB 3.3 — ZIP file requirements](https://www.w3.org/TR/epub-33/#sec-zip-container-zipreqs):
  constrains compression methods, encryption, filenames, spanning, and ZIP64 use.
- [EPUB 3.3 — media type identification](https://www.w3.org/TR/epub-33/#sec-zip-container-mime):
  requires `mimetype` first, exact US-ASCII content, no whitespace, Store mode, and no ZIP-header
  extra field.
- [PKWARE .ZIP Application Note](https://support.pkware.com/pkzip/appnote): the ZIP format
  structures underlying OCF.

## Runtime dependencies and platform APIs

- [ZIPFoundation 0.9.20 release](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.20):
  the exact reviewed MIT-licensed Swift ZIP release locked by `Package.resolved`.
- [ZIPFoundation source](https://github.com/weichsel/ZIPFoundation): streaming ZIP library built on
  Apple's `libcompression`; it supplies archive mechanics, not EPUB policy.
- [Apple Compression framework](https://developer.apple.com/documentation/compression): native
  compression primitives used by ZIPFoundation on Apple platforms.
- [SwiftUI `dropDestination`](https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:)):
  native typed drag-and-drop API used by the main window.
- [Swift Package Manager](https://www.swift.org/documentation/package-manager/): dependency and
  product definition used by the repository.

## macOS distribution, privacy, and CI

- [Developer ID](https://developer.apple.com/developer-id/): Apple's identity mechanism for
  distributing Mac software outside the Mac App Store.
- [Configuring the Hardened Runtime](https://developer.apple.com/documentation/xcode/configuring-the-hardened-runtime/):
  runtime protection required for the production signing path.
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution):
  Apple submission, ticket, and distribution guidance.
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files):
  the `PrivacyInfo.xcprivacy` bundle-resource format.
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api):
  reasons recorded for APIs such as preferences storage.
- [GitHub-hosted runner reference](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job):
  documents available macOS labels and the Apple Silicon runner architecture used by CI.

## Validation companion

- [W3C EPUBCheck](https://github.com/w3c/epubcheck): official EPUB publication conformance checker,
  maintained by DAISY on behalf of W3C. EPUB Zip's built-in checker intentionally covers only the
  ZIP/OCF boundary.

## Similar open-source projects reviewed

| Project | What was reused or learned | Why it was not used as the product base |
|---|---|---|
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | ZIP parsing, streaming, Deflate, CRC, ZIP64 | Library rather than an EPUB application |
| [Honeycrisp](https://github.com/kyrielie/honeycrisp) | Native macOS SwiftUI EPUB interaction and ZIPFoundation precedent | Reader; does not pack source folders |
| [EPUBCheck](https://github.com/w3c/epubcheck) | Authoritative publication-validation boundary | Java-based and intentionally much broader than pack/unpack |
| [epub-utils](https://github.com/ernestofgonzalez/epub-utils) | Clear CLI inspection workflows | Python inspection tool; not a native pack/unpack drop target |
| [epub-tools](https://hub.darcs.net/dino/epub-tools) | Prior command-line workflows for EPUB files | Haskell CLI; no native macOS GUI |

No reviewed project simultaneously provided a lightweight Apple Silicon drop target,
EPUB-specific compliant packing, defensive extraction, and a shared native CLI/core. The detailed
architectural decision is recorded in
[ADR 0001](adr/0001-apple-silicon-native-swift.md).

## Mapping references to implementation

| Requirement or decision | Implementation |
|---|---|
| First, exact, uncompressed `mimetype` with no local-header extra field | `EPUBService.add`, `EPUBInspector`, `ZIPStructure` |
| Strict `META-INF/container.xml` and OPF rootfiles | `OCFContainer`, `EPUBInspector`, `EPUBService.validateSourceDirectory` |
| Store and Deflate only | `EPUBService.add` |
| Safe paths, byte limits, and topology/collision rejection | `SafeArchivePath`, `ArchivePathRegistry`, `EPUBService.preflight` |
| Input/output overlap protection | `EPUBService.pack`, `EPUBService.unpack`, URL containment helpers |
| Native drag/drop and complete batch results | `ContentView.dropDestination`, `AppModel` |
| No tracking/data collection and required-reason declaration | `Resources/PrivacyInfo.xcprivacy` |
| Local versus production trust gate | `Scripts/build-app.sh`, `Scripts/notarize.sh`, `docs/releasing.md` |
| Full-publication validation remains external | `docs/design-rationale.md`, README validation note |

Implementation names in this table describe the current 0.4 architecture. When a refactor renames a
component, update this map in the same commit so normative claims remain traceable.
