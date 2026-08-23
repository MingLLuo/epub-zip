# Usage guide / 使用指南

## Choose the correct artifact / 选择正确的制品

Regular users should install `EPUB Zip.app` from an Apple Silicon DMG explicitly marked as
Developer ID signed and notarized. / 普通用户应安装明确标注已通过 Developer ID 签名和 Apple 公证
的 Apple Silicon DMG 中的 `EPUB Zip.app`。

The extensionless `epubzip` is a command-line executable. If macOS reports that no application is
set to open `epubzip-…-arm64`, a CLI file or its directory was opened in Finder. Open the DMG for
the graphical app, or run the executable from Terminal. / 无扩展名的 `epubzip` 是命令行程序。
若 macOS 提示未设定用来打开 `epubzip-…-arm64` 的应用程序，说明在 Finder 中误开了 CLI
文件或目录；图形界面请打开 DMG，CLI 则应在“终端”中运行。

The default `make app` output is ad-hoc signed for local development. It is not a production
release and should not be redistributed as one. / 默认 `make app` 产物只经过 ad-hoc 签名，用于
本地开发验证，不应作为正式发行版转发。

## Graphical app / 图形应用

1. Open the DMG and drag `EPUB Zip.app` to Applications. / 打开 DMG，将应用拖入“应用程序”。
2. Drop one or more source folders to create sibling `.epub` files. / 拖入一个或多个源目录，
   在同级生成 `.epub`。
3. Drop one or more `.epub` files to create sibling editable folders. / 拖入一个或多个
   `.epub`，在同级生成可编辑目录。
4. Keep adding files while a batch runs if needed; accepted items join the same queue. / 运行中仍可
   继续添加文件，已接受的项目会加入同一队列。
5. Review every success, warning, and failure, then choose **Show in Finder / 在 Finder 中显示**
   to reveal all completed outputs. / 查看全部成功、警告和失败，再一次显示所有成功输出。

Items are processed sequentially. One failure does not stop later inputs, and the final scrollable
summary retains every outcome. Starting another operation after completion begins a fresh batch. /
项目按顺序处理；单项失败不会终止后续项目，最终可滚动摘要会保留全部结果。完成后再次添加输入
会开始新批次。

The app never overwrites an existing result. If `book.epub` exists, it creates `book 2.epub`,
then `book 3.epub`, and so on. / 图形应用不会覆盖已有结果，而会自动使用递增名称。

The Settings option can reproduce the legacy `Book_pkg.epub` directory name. The result remains a
normal directory, not an EPUB file. / 设置可复现旧工具的 `_pkg.epub` 目录命名；输出本质仍是目录。

## Build and run the included example / 构建并运行内置实例

The repository includes a small EPUB 3 source publication under `Examples/MinimalBook`. /
仓库在 `Examples/MinimalBook` 内提供了一个最小 EPUB 3 源目录。

```bash
make example
```

This creates and checks `dist/MinimalBook.epub`. The equivalent explicit commands are: /
该命令会创建并检查 `dist/MinimalBook.epub`，等价命令如下：

```bash
swift run epubzip pack -o dist/MinimalBook.epub Examples/MinimalBook
swift run epubzip check dist/MinimalBook.epub
swift run epubzip unpack -o dist/MinimalBook-unpacked dist/MinimalBook.epub
```

The example demonstrates this structure: / 实例结构如下：

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

## CLI installation / 安装 CLI

```bash
make build
unzip dist/epubzip-0.4.0-arm64-cli-development.zip
cd epubzip-0.4.0-arm64-cli-development
./epubzip --version
```

Keep the leading `./` unless the binary has been deliberately installed into a directory on
`PATH`. The CLI package also contains its README, project license, and third-party notices. /
除非已经把程序安装到 `PATH` 目录，否则请保留开头的 `./`。CLI 包还包含说明、项目许可证和
第三方许可声明。

## CLI commands / 命令行

### Pack a folder / 打包目录

```bash
./epubzip pack BookSource
./epubzip pack -o MyBook.epub BookSource
```

The source must contain an exact 20-byte `mimetype`, a valid
`META-INF/container.xml`, and every OPF rootfile declared by the container. /
源目录必须包含精确的 20 字节 `mimetype`、有效的 `META-INF/container.xml`，以及容器声明的
每个 OPF rootfile。

### Extract an EPUB / 解包 EPUB

```bash
./epubzip unpack MyBook.epub
./epubzip unpack -o EditableBook MyBook.epub
./epubzip unpack --package MyBook.epub
```

`--package` uses the legacy `MyBook_pkg.epub` directory name. /
`--package` 使用旧工具的 `MyBook_pkg.epub` 目录名称。

### Inspect the OCF container / 检查 OCF 容器

```bash
./epubzip check MyBook.epub
./epubzip check --json MyBook.epub
```

JSON is intended for automation and contains `path`, `entryCount`, `rootfiles`, and `issues`.
Issue `code` values are stable and language-neutral; `message` is localized. /
JSON 适合自动化，包含 `path`、`entryCount`、`rootfiles` 和 `issues`；问题 `code` 稳定且
不依赖语言，`message` 会本地化。

### Automatic and multi-input mode / 自动与多输入模式

```bash
./epubzip BookSource
./epubzip MyBook.epub
./epubzip auto BookOne.epub BookTwo.epub
```

A directory is packed; an `.epub` is extracted. Multiple paths are processed in order. /
目录会被打包，`.epub` 会被解包；多个路径按顺序处理。

## Output conflicts and input protection / 输出冲突与输入保护

The CLI refuses replacement by default: / CLI 默认拒绝替换：

```bash
./epubzip pack BookSource
# epubzip: Output already exists: .../BookSource.epub
```

Use `--force` only when replacing an existing output is intentional: /
仅在确实需要替换已有输出时使用 `--force`：

```bash
./epubzip pack --force BookSource
./epubzip unpack --force MyBook.epub
```

Replacement is transactional: a failed operation preserves or restores the old output. `--force`
never grants permission to alter the input. Packing rejects an output equal to or inside the source
directory; extraction rejects an output equal to or containing the input EPUB. These checks resolve
equivalent filesystem paths such as `/tmp` and `/private/tmp`. /
替换采用事务式提交，失败时保留或恢复旧输出。`--force` 永远不代表可以修改输入：打包会拒绝
等于源目录或位于其中的输出，解包会拒绝等于输入 EPUB 或包含该输入的输出；检查也会解析
`/tmp` 与 `/private/tmp` 这类等价路径。

## Validation and resource limits / 验证与资源限制

The default CLI limits are: / CLI 默认限制如下：

| Resource / 资源 | Limit / 上限 |
|---|---:|
| Entries / 条目数 | 20,000 |
| One uncompressed file / 单个未压缩文件 | 512 MiB |
| Total uncompressed data / 未压缩总量 | 2 GiB |
| Compression ratio / 压缩比 | 1,000:1 |
| Archive path / 归档路径 | 4,096 UTF-8 bytes / 字节 |
| One path component / 单个路径组件 | 255 UTF-8 bytes / 字节 |

The inspector applies entry/path bounds before retaining the whole central-directory view.
Inspection and extraction also reject unsafe syntax, symlinks, duplicates, case collisions, and a
path that is both a file and a directory/ancestor. Unpack additionally preflights per-file, total,
and ratio limits, then enforces actual streamed byte counts. Library clients can pass a stricter
`ExtractionLimits`; the CLI currently uses the documented defaults. /
检查器会在保留完整中央目录视图前限制条目数与路径。检查和解包也会拒绝不安全语法、符号链接、
重复、大小写冲突，以及同一路径同时充当文件与目录/祖先。解包还会预检单文件、总量和压缩比，
并在流式写入时再次限制实际字节数。库调用方可传入更严格的 `ExtractionLimits`；CLI 当前使用
上述默认值。

`container.xml` must use the OCF namespace and required hierarchy, declare version `1.0`, and
provide at least one rootfile with a safe `full-path` and exact
`application/oebps-package+xml` media type. Every declared rootfile must be a regular file. /
`container.xml` 必须使用 OCF 命名空间与必要层级，声明版本 `1.0`，并至少提供一个路径安全、
media type 精确为 `application/oebps-package+xml` 的 rootfile；每个声明项都必须是普通文件。

## Language / 语言

The CLI follows the preferred system language. An environment override is available for scripts: /
CLI 跟随系统首选语言，脚本可使用环境变量明确指定：

```bash
EPUBZIP_LANGUAGE=en ./epubzip --help
EPUBZIP_LANGUAGE=zh-Hans ./epubzip --help
```

English and Simplified Chinese are supported. Traditional Chinese and every other unsupported or
invalid override fall back to English. / 当前支持英文和简体中文；繁体中文以及其他不支持或无效的
覆盖值会回退英文。

## Exit status / 退出状态

| Status / 状态 | Meaning / 含义 |
|---:|---|
| `0` | Operation succeeded, or `check` found a valid container / 操作成功，或检查有效 |
| `1` | `check` completed and found an invalid container / 检查完成但容器无效 |
| `2` | Invalid arguments, unsupported input, I/O failure, or safety rejection / 参数、输入、I/O 或安全拒绝 |

## Troubleshooting / 故障排查

| Symptom / 现象 | Action / 处理 |
|---|---|
| No application can open `epubzip-…-arm64` / 未设定打开应用 | Use `EPUB Zip.app` for the GUI; run `./epubzip` in Terminal / 图形界面打开 App，命令行在终端运行 |
| Gatekeeper does not trust a local build / Gatekeeper 不信任本地包 | Use a signed/notarized production artifact or build from reviewed source; do not relabel an ad-hoc build as a release / 使用已签名公证的正式制品或从已审查源码构建 |
| `container-xml` or rootfile error / 容器或 rootfile 错误 | Compare namespace, hierarchy, version, path, and media type with the minimal example / 对照最小实例逐项检查 |
| Entry/path/size/ratio limit / 超出条目、路径、大小或压缩比 | Treat the file as untrusted; inspect its origin before increasing library limits / 按不可信文件处理，先核实来源 |
| Output overlaps input / 输出与输入重叠 | Choose a sibling output that neither contains nor sits inside the input / 选择与输入不存在包含关系的同级输出 |

## What `check` does and does not prove

`check` verifies the ZIP/OCF rules needed by this tool: first stored exact `mimetype`, bounded safe
entry names and topology, supported entry types, strict container XML, and declared OPF presence.
It does not prove that metadata, XHTML, navigation, accessibility, scripts, or reading order
conform to the complete EPUB specification. /
`check` 验证本工具所需的 ZIP/OCF 边界：首个且未压缩的精确 `mimetype`、有界且安全的路径与
拓扑、受支持条目类型、严格容器 XML 及已声明 OPF 是否存在；它不证明元数据、XHTML、导航、
无障碍、脚本或阅读顺序符合完整 EPUB 规范。

Run [EPUBCheck](https://github.com/w3c/epubcheck) before publishing or distributing a book. /
出版或分发前，请继续使用 EPUBCheck 做完整规范验证。
