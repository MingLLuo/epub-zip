# Usage guide / 使用指南

## Graphical app / 图形应用

1. Open the DMG and drag `EPUB Zip.app` to Applications. / 打开 DMG，将应用拖入“应用程序”。
2. Drop a source folder to create a sibling `.epub`. / 拖入源目录，在同级生成 `.epub`。
3. Drop an `.epub` to create a sibling editable folder. / 拖入 `.epub`，在同级生成可编辑目录。
4. Use **Show in Finder / 在 Finder 中显示** to reveal the result.

The app never overwrites an existing result. If `book.epub` exists, it creates `book 2.epub`,
then `book 3.epub`, and so on. / 图形应用不会覆盖已有结果，而是自动使用递增名称。

The Settings option can reproduce the legacy `Book_pkg.epub` directory name. The result is still
a normal directory, not an EPUB file. / 设置可复现旧工具的 `_pkg.epub` 目录命名，输出本质仍是目录。

## Build and run the included example / 构建内置实例

The repository includes a small EPUB 3 source publication under `Examples/MinimalBook`.
仓库在 `Examples/MinimalBook` 内提供了一个最小 EPUB 3 源目录。

```bash
make example
```

This creates and checks `dist/MinimalBook.epub`. The equivalent explicit commands are:
该命令会创建并检查 `dist/MinimalBook.epub`，等价命令如下：

```bash
swift run epubzip pack -o dist/MinimalBook.epub Examples/MinimalBook
swift run epubzip check dist/MinimalBook.epub
swift run epubzip unpack -o dist/MinimalBook-unpacked dist/MinimalBook.epub
```

The example demonstrates this structure:

```text
MinimalBook/
├── mimetype                    exact bytes: application/epub+zip
├── META-INF/
│   └── container.xml           points to EPUB/package.opf
└── EPUB/
    ├── package.opf             metadata, manifest, and spine
    ├── nav.xhtml               EPUB 3 navigation document
    ├── chapter.xhtml           readable content
    └── style.css
```

## CLI commands / 命令行

### Pack a folder / 打包目录

```bash
epubzip pack BookSource
epubzip pack -o MyBook.epub BookSource
```

The source must contain an exact `mimetype`, `META-INF/container.xml`, and every OPF rootfile
declared by the container. / 源目录必须包含精确的 `mimetype`、容器文件及其声明的 OPF。

### Extract an EPUB / 解包 EPUB

```bash
epubzip unpack MyBook.epub
epubzip unpack -o EditableBook MyBook.epub
epubzip unpack --package MyBook.epub
```

`--package` uses the legacy `MyBook_pkg.epub` directory name.

### Inspect the OCF container / 检查 OCF 容器

```bash
epubzip check MyBook.epub
epubzip check --json MyBook.epub
```

JSON output is stable for automation and contains `path`, `entryCount`, `rootfiles`, and `issues`.
JSON 输出适合脚本处理，包含路径、条目数、rootfile 和问题列表。

### Automatic mode / 自动模式

```bash
epubzip BookSource
epubzip MyBook.epub
epubzip auto BookOne.epub BookTwo.epub
```

A directory is packed; an `.epub` is extracted. Multiple paths are processed in order.
目录会被打包，`.epub` 会被解包；多个路径按顺序处理。

### Output conflicts / 输出冲突

The CLI refuses replacement by default:

```bash
epubzip pack BookSource
# epubzip: Output already exists: .../BookSource.epub
```

Use `--force` only when replacement is intentional:

```bash
epubzip pack --force BookSource
epubzip unpack --force MyBook.epub
```

Replacement is transactional: a failed operation preserves or restores the old output.
替换采用事务式提交，操作失败时保留或恢复原结果。

### Language / 语言

The CLI follows the preferred system language. An environment override is available for scripts:

```bash
EPUBZIP_LANGUAGE=en epubzip --help
EPUBZIP_LANGUAGE=zh-Hans epubzip --help
```

Unsupported or unavailable languages fall back to English.

### Exit status / 退出状态

| Status | Meaning |
|---:|---|
| `0` | Operation succeeded, or `check` found a valid container |
| `1` | `check` completed and found an invalid container |
| `2` | Invalid arguments, unsupported input, I/O failure, or safety rejection |

## What `check` does and does not prove

`check` verifies the ZIP/OCF rules needed by this tool: `mimetype`, safe entry names, entry types,
container XML, and declared OPF presence. It does not prove that metadata, XHTML, navigation,
accessibility, or reading order conform to the full EPUB specification.

Run [EPUBCheck](https://github.com/w3c/epubcheck) before publishing or distributing a book.
出版或分发前，请继续使用 EPUBCheck 做完整规范验证。
