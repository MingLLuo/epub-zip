# EPUB Zip

English | [简体中文](README.md)

A native Apple Silicon macOS tool for packing, extracting, and inspecting EPUB containers, and a
modern open-source alternative to the classic **ePub Zip-Unzip 64 3.0**.

```text
Drop a folder → create an OCF-compliant .epub
Drop an .epub → create a safe, editable source folder
```

The SwiftUI app and `epubzip` CLI share `EPUBZipCore`. The only runtime dependency is the
MIT-licensed
[ZIPFoundation 0.9.20](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.20); the project
does not invoke shell commands, Finder Automation, `zip`, or `unzip`.

> **Maturity: 0.4.0 public beta.** Core safety invariants, regression tests, and artifact checks are
> release gates. However, the default `make app` output is only an ad-hoc-signed local development
> build. An artifact is a production release only after Developer ID signing, Hardened Runtime,
> Apple notarization, stapling, and Gatekeeper assessment. See the [release guide](docs/releasing.md).

## Quick start

Regular users should choose an Apple Silicon DMG explicitly marked “Developer ID signed and
notarized” on the release page. Open the DMG, drag `EPUB Zip.app` to Applications, and then drop one
or more EPUBs or source folders. The app drains the batch in order, preserves every success,
failure, and warning, and can reveal all successful outputs in Finder at once.

The extensionless `epubzip` is a terminal command, not a graphical app. If macOS says no
application is set to open `epubzip-…-arm64`, open `EPUB Zip.app` from the DMG instead, or run the
CLI in Terminal; do not double-click the CLI file or its directory.

Developers can run the included publication example:

```bash
make example
```

This packs [`Examples/MinimalBook`](Examples/MinimalBook) into `dist/MinimalBook.epub` and checks the
result with the built-in inspector.

## Why this project exists

An EPUB is not an arbitrary ZIP. [W3C EPUB 3.3](https://www.w3.org/TR/epub-33/#sec-zip-container-mime)
requires the root `mimetype` entry to be first, contain exactly `application/epub+zip`, remain
uncompressed, and have no local-header extra field. Generic archive tools do not necessarily
produce those defaults.

Existing open-source projects solve adjacent parts of the problem:

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) provides mature Swift ZIP primitives;
- [Honeycrisp](https://github.com/kyrielie/honeycrisp) demonstrates a native SwiftUI EPUB experience;
- [EPUBCheck](https://github.com/w3c/epubcheck) provides full publication validation;
- [epub-utils](https://github.com/ernestofgonzalez/epub-utils) provides rich terminal inspection.

None of the reviewed lightweight projects combines an Apple Silicon drop target, compliant EPUB
packing, defensive extraction, and a CLI that shares the same core. This project reuses
ZIPFoundation for ZIP, Deflate, CRC, and ZIP64 mechanics while keeping EPUB and filesystem safety
policy in its own core. See the [design rationale](docs/design-rationale.md) and
[references](docs/references.md) for the comparison.

## Features

- Native `arm64` macOS application requiring macOS 13 or later; universal builds remain optional
- Resizable one-window batch queue; failures do not stop later items and long diagnostics scroll
- Accessible progress labels and values; decorative imagery is hidden from assistive technologies
- English and Simplified Chinese; Traditional Chinese and other unsupported languages fall back to English
- Stores `mimetype` first, uncompressed, and without a ZIP extra field
- Shared strict OCF parser checks namespace, hierarchy, version, `full-path`, and OPF media type
- Rejects Zip Slip, absolute paths, backslashes, symlinks, duplicates, case collisions, and
  file/directory topology conflicts
- Bounds entry iteration before materializing the complete central directory, and limits path,
  per-file, total extracted size, and compression ratio
- Rejects output that replaces its input, sits inside a packed source, or becomes an ancestor of an
  unpacked source; `--force` cannot bypass this invariant
- Writes to a temporary sibling and commits transactionally; the GUI chooses a unique output name
- Reproducible EPUB entry ordering, timestamps, and permissions
- App icon and `PrivacyInfo.xcprivacy`; the project declares no tracking or collected data
- GUI, CLI, and tests share `EPUBZipCore`

Default extraction limits are 20,000 entries, 512 MiB per file, 2 GiB total, a 1,000:1 compression
ratio, 4,096 UTF-8 bytes per path, and 255 bytes per path component. The CLI uses these defaults;
library callers can choose stricter values with `ExtractionLimits`.

> Built-in `check` covers only the ZIP/OCF boundary. It does not validate metadata, manifests,
> spines, navigation, XHTML, accessibility, or reading-system behavior. Continue to use
> [EPUBCheck](https://github.com/w3c/epubcheck) before publication.

## Install and build

Xcode 16 or later is required. Apple Silicon is the default target:

```bash
make verify
make test
make app
```

Primary outputs:

```text
dist/EPUB Zip-0.4.0-arm64-development.dmg
dist/EPUB Zip-0.4.0-arm64-development.zip
```

These local `make app` artifacts are **ad-hoc-signed development builds** for local verification,
not official public downloads. A production release also needs maintainer signing and Apple
notarization credentials; follow the [release guide](docs/releasing.md).

An optional universal build can be produced with:

```bash
ARCHS="arm64 x86_64" make app
```

## CLI examples

Build and unpack the CLI distribution:

```bash
make build
unzip dist/epubzip-0.4.0-arm64-cli-development.zip
cd epubzip-0.4.0-arm64-cli-development
```

Pack, extract, and inspect:

```bash
./epubzip pack BookSource
./epubzip pack -o MyBook.epub BookSource
./epubzip unpack MyBook.epub
./epubzip unpack --package MyBook.epub
./epubzip check MyBook.epub
./epubzip check --json MyBook.epub
```

The subcommand can be omitted:

```bash
./epubzip BookSource
./epubzip MyBook.epub
```

The CLI refuses replacement by default. Pass `--force` only when replacement is intentional; input
protection always remains active. Scripts can select a language explicitly:

```bash
EPUBZIP_LANGUAGE=en ./epubzip --help
EPUBZIP_LANGUAGE=zh-Hans ./epubzip --help
```

See the [usage guide](docs/usage.md) for all modes, exit statuses, batch behavior, and troubleshooting.

## Minimal EPUB source

```text
BookSource/
├── mimetype
├── META-INF/
│   └── container.xml
└── EPUB/
    ├── package.opf
    ├── nav.xhtml
    └── chapter.xhtml
```

`mimetype` must be the exact 20-byte ASCII text `application/epub+zip`, with no newline. Copy
[`Examples/MinimalBook`](Examples/MinimalBook) as a starting point.

## Architecture and maintenance

```text
SwiftUI App ─┐
             ├── EPUBZipCore ── ZIPFoundation ── Apple libcompression
epubzip CLI ─┘
```

Path rules, OCF validation, limits, and transactional commits exist only in the core. Localized
text is grouped by responsibility in `CoreStrings`, `AppStrings`, and `CLIStrings`. Important
design changes are recorded as ADRs and separate Git commits.

- [Architecture and pipelines](docs/architecture.md)
- [Design rationale and non-goals](docs/design-rationale.md)
- [Usage guide and examples](docs/usage.md)
- [Specifications, platform guidance, and prior art](docs/references.md)
- [Maturity and release gates ADR](docs/adr/0003-maturity-and-release-gates.md)
- [Release guide](docs/releasing.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Development

```bash
make format
make lint
make test
make example
make verify
make build
make app
```

`make verify` checks version consistency, the dependency lock, license/privacy resources, and
artifact prerequisites. CI uses the same entry points on an Apple Silicon runner to validate the
core, GUI state model, example, and application bundle.

## License

The project is [MIT licensed](LICENSE). Binary distributions also contain the project license and
third-party license notices from [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
