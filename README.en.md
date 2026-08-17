# EPUB Zip

English | [简体中文](README.md)

A native Apple Silicon macOS tool for packing and extracting EPUB files, and a
modern open-source alternative to the classic **ePub Zip-Unzip 64 3.0**.

Drop an EPUB or source folder into the window:

- Folder → standards-compliant `.epub`
- `.epub` → editable folder
- Automatic validation of `mimetype`, `META-INF/container.xml`, and OPF rootfiles

The project uses Swift 6, SwiftUI, and
[ZIPFoundation](https://github.com/weichsel/ZIPFoundation). It does not invoke
shell commands, Finder Automation, `zip`, or `unzip`.

## Features

- Native `arm64` macOS application requiring macOS 13 or later
- English and Simplified Chinese UI selected from the macOS preferred language
- One-window drag and drop, plus opening EPUB files and folders from Finder
- Stores `mimetype` first, uncompressed, and without ZIP extra fields
- Rejects Zip Slip paths, symbolic links, duplicate entries, and case collisions
- Limits entry count, individual and total sizes, and compression ratio
- Writes to a temporary location and commits output only after validation
- Never silently overwrites; conflicting GUI output becomes `book 2.epub`
- Reproducible entry ordering and timestamps
- Includes an `epubzip` CLI backed by the same core library
- MIT licensed

> Built-in `check` covers the ZIP/OCF container boundary. Continue to use
> [EPUBCheck](https://github.com/w3c/epubcheck) for publication-level validation.

## Build the native app

Xcode 15 or later is required. Apple Silicon is the default target:

```bash
make app
```

Outputs:

```text
dist/EPUB Zip-0.2.0-arm64.dmg
dist/EPUB Zip-0.2.0-arm64.zip
```

For normal use, open the `.dmg` and drag `EPUB Zip.app` to Applications. The
extensionless `epubzip` file is a terminal command and cannot be opened as a GUI.

An optional universal build can be produced with:

```bash
ARCHS="arm64 x86_64" make app
```

## Command line

```bash
make build
unzip dist/epubzip-0.2.0-arm64-cli.zip
cd epubzip-0.2.0-arm64

./epubzip pack book/
./epubzip unpack book.epub
./epubzip unpack --package book.epub
./epubzip check book.epub
```

The CLI follows the system language. Override it when needed:

```bash
EPUBZIP_LANGUAGE=en ./epubzip --help
EPUBZIP_LANGUAGE=zh-Hans ./epubzip --help
```

The CLI refuses to overwrite by default. Pass `--force` only when replacement is
intentional; the GUI always chooses a unique output name.

## Development

```bash
make format
make lint
make test
```

See [architecture.md](docs/architecture.md),
[CONTRIBUTING.md](CONTRIBUTING.md), and [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
