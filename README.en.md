# EPUB Zip

English | [简体中文](README.md)

A native Apple Silicon macOS tool for packing and extracting EPUB files, and a modern open-source
alternative to the classic **ePub Zip-Unzip 64 3.0**.

```text
Drop a folder → create an OCF-compliant .epub
Drop an .epub → create a safe, editable source folder
```

The SwiftUI app and `epubzip` CLI use the same Swift core. The only runtime dependency is the
MIT-licensed [ZIPFoundation](https://github.com/weichsel/ZIPFoundation); the project does not invoke
shell commands, Finder Automation, `zip`, or `unzip`.

## Quick start

Open the Apple Silicon DMG, drag `EPUB Zip.app` to Applications, then drop an EPUB or source folder
into the window. The app never modifies its input or silently replaces an existing result.

Developers can run the included publication example:

```bash
make example
```

This packs [`Examples/MinimalBook`](Examples/MinimalBook) into `dist/MinimalBook.epub` and checks the
result with the built-in inspector.

## Why this project exists

An EPUB is not an arbitrary ZIP. The W3C OCF specification requires the root `mimetype` entry to be
first, contain exactly `application/epub+zip`, remain uncompressed, and have no local-header extra
field. Generic archive tools do not necessarily produce those defaults.

Existing open-source projects solve adjacent parts of the problem:

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) provides mature Swift ZIP primitives;
- [Honeycrisp](https://github.com/kyrielie/honeycrisp) demonstrates a native SwiftUI EPUB experience;
- [EPUBCheck](https://github.com/w3c/epubcheck) provides complete publication validation;
- [epub-utils](https://github.com/ernestofgonzalez/epub-utils) provides rich terminal inspection.

None of the reviewed lightweight projects combines an Apple Silicon drag target, compliant EPUB
packing, defensive extraction, and a CLI that shares the same core. See the
[design rationale](docs/design-rationale.md), [references](docs/references.md), and
[ADR 0001](docs/adr/0001-apple-silicon-native-swift.md) for the comparison and decisions.

## Features

- Native `arm64` macOS application requiring macOS 13 or later
- English and Simplified Chinese selected from the macOS preferred language
- One-window drag and drop, plus opening EPUB files and folders from Finder
- Stores `mimetype` first, uncompressed, and without a ZIP extra field
- Checks `META-INF/container.xml` and every declared OPF rootfile
- Rejects Zip Slip, absolute paths, backslashes, symlinks, duplicates, and case collisions
- Limits entry count, per-file size, total extracted size, and compression ratio
- Writes to a temporary location and commits only after validation
- GUI generates `book 2.epub`; CLI refuses replacement by default
- Reproducible entry ordering, timestamps, and permissions
- GUI, CLI, and tests share `EPUBZipCore`

> Built-in `check` covers only the ZIP/OCF boundary. It does not validate metadata, manifests,
> spines, navigation, XHTML, accessibility, or reading-system behavior. Continue to use
> [EPUBCheck](https://github.com/w3c/epubcheck) before publication.

## Install and build

Xcode 15 or later is required. Apple Silicon is the default target:

```bash
make app
```

Outputs:

```text
dist/EPUB Zip-0.3.0-arm64.dmg
dist/EPUB Zip-0.3.0-arm64.zip
```

The DMG is recommended for normal use. The extensionless `epubzip` file is a terminal command and
cannot be opened as a graphical app.

An optional universal build can be produced with:

```bash
ARCHS="arm64 x86_64" make app
```

## CLI examples

Build and unpack the CLI distribution:

```bash
make build
unzip dist/epubzip-0.3.0-arm64-cli.zip
cd epubzip-0.3.0-arm64
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

The CLI refuses replacement by default; pass `--force` only when replacement is intentional.
Scripts can select a language explicitly:

```bash
EPUBZIP_LANGUAGE=en ./epubzip --help
EPUBZIP_LANGUAGE=zh-Hans ./epubzip --help
```

See the [usage guide](docs/usage.md) for all modes, exit statuses, and a worked example.

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

## Architecture

```text
SwiftUI App ─┐
             ├── EPUBZipCore ── ZIPFoundation ── Apple libcompression
epubzip CLI ─┘
```

Localized text is grouped by responsibility in `CoreStrings`, `AppStrings`, and `CLIStrings`;
business logic contains no parallel bilingual literals. Path safety, OCF rules, and output commits
exist only in the core library.

Further reading:

- [Architecture and pipelines](docs/architecture.md)
- [Design rationale and non-goals](docs/design-rationale.md)
- [Specifications, dependencies, and prior art](docs/references.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Development

```bash
make format
make lint
make test
make example
make build
make app
```

Important design changes are recorded as ADRs and separate Git commits. Native Apple Silicon is
the release target; a universal binary remains optional rather than default complexity.

## License

[MIT](LICENSE)
