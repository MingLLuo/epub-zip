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

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation): MIT-licensed Swift ZIP library built
  on Apple's `libcompression`; EPUB Zip pins the compatible 0.9 series in `Package.resolved`.
- [Apple Compression framework](https://developer.apple.com/documentation/compression): native
  compression primitives used by ZIPFoundation on Apple platforms.
- [SwiftUI `dropDestination`](https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:)):
  native typed drag-and-drop API used by the main window.
- [Swift Package Manager](https://www.swift.org/documentation/package-manager/): dependency and
  product definition used by the repository.

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
| `META-INF/container.xml` and OPF rootfiles | `ContainerXML`, `sourceRootfiles` |
| Store and Deflate only | `EPUBService.add` |
| Safe archive paths and collision rejection | `SafeArchivePath`, `EPUBService.preflight` |
| Native drag/drop | `ContentView.dropDestination` |
| Full-publication validation remains external | `docs/design-rationale.md`, README validation note |
