# EPUB Zip

[English](README.en.md) | 简体中文

面向 Apple Silicon 的原生 macOS EPUB 打包、解包与容器检查工具，也是经典
**ePub Zip-Unzip 64 3.0** 的现代开源替代品。

```text
拖入目录   → 创建符合 OCF 容器规则的 .epub
拖入 .epub → 创建安全、可编辑的源目录
```

SwiftUI 图形应用和 `epubzip` CLI 共用 `EPUBZipCore`。项目只复用 MIT 许可的
[ZIPFoundation 0.9.20](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.20)，不调用
Shell、Finder Automation、`zip` 或 `unzip`。

> **成熟度：0.4.0 公测版。** 核心安全约束、回归测试和制品校验已形成发布门禁；但默认
> `make app` 只生成 ad-hoc 签名的本地开发包。只有经过 Developer ID 签名、Hardened Runtime、
> Apple 公证、装订并通过 Gatekeeper 验证的制品，才能称为正式发行版。详见
> [发布手册](docs/releasing.md)。

## 快速开始

普通用户应使用发布页中明确标注“Developer ID signed and notarized”的 Apple Silicon DMG。
打开 DMG，将 `EPUB Zip.app` 拖入“应用程序”，然后拖入一个或多个 EPUB/源目录。应用会依次
处理队列，保留每个成功、失败和警告结果，并可一次在 Finder 中显示全部成功输出。

无扩展名的 `epubzip` 是终端命令，不是图形应用。若 macOS 提示未设定用来打开
`epubzip-…-arm64` 的应用程序，请改为打开 DMG 内的 `EPUB Zip.app`，或在“终端”中运行 CLI；
不要双击 CLI 文件或其目录。

开发者可以直接运行内置实例：

```bash
make example
```

它会把 [`Examples/MinimalBook`](Examples/MinimalBook) 打包为 `dist/MinimalBook.epub`，随后用
内置检查器验证容器。

## 为什么另做一个项目

EPUB 不是任意 ZIP。[W3C EPUB 3.3](https://www.w3.org/TR/epub-33/#sec-zip-container-mime)
要求根目录 `mimetype` 必须排在第一个、内容精确为 `application/epub+zip`、不得压缩，并且
本地 ZIP 头不能带 extra field。通用压缩工具的默认行为不一定满足这些约束。

调研的开源项目各有所长：

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) 提供成熟 Swift ZIP 基础；
- [Honeycrisp](https://github.com/kyrielie/honeycrisp) 展示原生 SwiftUI EPUB 体验；
- [EPUBCheck](https://github.com/w3c/epubcheck) 提供完整出版级验证；
- [epub-utils](https://github.com/ernestofgonzalez/epub-utils) 提供丰富的终端检查能力。

没有一个轻量项目同时提供 Apple Silicon 原生拖放、EPUB 合规打包、防御性解包，以及共用核心
的 CLI。本项目复用 ZIPFoundation 的 ZIP/Deflate/CRC/ZIP64 能力，把 EPUB 规则和文件系统安全
策略留在自身核心。详细比较见[设计缘由](docs/design-rationale.md)和[参考资料](docs/references.md)。

## 主要能力

- 原生 `arm64` macOS 应用，最低 macOS 13；通用二进制为可选构建
- 可调整大小的单窗口批量队列；失败不终止后续项目，长诊断可滚动阅读
- 进度状态具备辅助功能标签；装饰图像对辅助技术隐藏
- 英文和简体中文；繁体中文及其他未支持语言明确回退英文
- `mimetype` 固定为第一个 ZIP 条目、Store 模式、零 extra field
- 共享的严格 OCF 解析器检查命名空间、层级、版本、`full-path` 和 OPF media type
- 拒绝 Zip Slip、绝对路径、反斜线、符号链接、重复/大小写冲突及文件—目录拓扑冲突
- 在读取完整中央目录前限制条目数，并限制路径、单文件、总解压大小和压缩比
- 拒绝输出覆盖输入、位于打包源目录中，或在解包时成为输入的祖先；`--force` 也不能绕过
- 先写临时位置，验证成功后再事务式提交；GUI 自动选择不冲突的输出名
- 固定条目顺序、时间和权限，支持可重复生成 EPUB
- 应用包包含图标和 `PrivacyInfo.xcprivacy`；项目声明不跟踪、不收集数据
- 图形应用、CLI 和测试共用 `EPUBZipCore`

默认解包限制为 20,000 个条目、单文件 512 MiB、总计 2 GiB、压缩比 1,000:1、单路径
4,096 UTF-8 字节及单路径组件 255 字节。CLI 使用这些默认值；库调用方可通过
`ExtractionLimits` 收紧限制。

> 内置 `check` 只检查 ZIP/OCF 容器边界，不验证元数据、manifest、spine、导航、XHTML、
> 无障碍或阅读器行为。出版前请继续使用 [EPUBCheck](https://github.com/w3c/epubcheck)。

## 安装和构建

需要 Xcode 16 或更高版本。默认只构建 Apple Silicon：

```bash
make verify
make test
make app
make source
```

主要产物：

```text
dist/EPUB Zip-0.4.0-arm64-development.dmg
dist/EPUB Zip-0.4.0-arm64-development.zip
dist/EPUB-Zip-0.4.0-source.zip
```

这些本地 `make app` 产物仅为 **ad-hoc 签名的开发版**，适合本机验证，不应作为正式公开下载。
正式发行还需要维护者证书和 Apple 公证凭据；完整步骤见[发布手册](docs/releasing.md)。

可选通用版本：

```bash
ARCHS="arm64 x86_64" make app
```

## CLI 实例

构建并解压 CLI 包：

```bash
make build
unzip dist/epubzip-0.4.0-arm64-cli-development.zip
cd epubzip-0.4.0-arm64-cli-development
```

打包、解包和检查：

```bash
./epubzip pack BookSource
./epubzip pack -o MyBook.epub BookSource
./epubzip unpack MyBook.epub
./epubzip unpack --package MyBook.epub
./epubzip check MyBook.epub
./epubzip check --json MyBook.epub
```

也可省略子命令：

```bash
./epubzip BookSource
./epubzip MyBook.epub
```

CLI 默认拒绝覆盖。确定需要替换时传入 `--force`；输入保护始终生效。脚本可明确选择输出语言：

```bash
EPUBZIP_LANGUAGE=en ./epubzip --help
EPUBZIP_LANGUAGE=zh-Hans ./epubzip --help
```

完整选项、退出状态、批量行为和故障排查见[使用指南](docs/usage.md)。

## 最小 EPUB 源目录

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

`mimetype` 必须是不带换行的 20 字节 ASCII 文本 `application/epub+zip`。可复制
[`Examples/MinimalBook`](Examples/MinimalBook) 作为起点。

## 架构与维护

```text
SwiftUI App ─┐
             ├── EPUBZipCore ── ZIPFoundation ── Apple libcompression
epubzip CLI ─┘
```

路径、OCF、限制和事务提交只在核心实现；本地化文本按职责集中在 `CoreStrings`、
`AppStrings` 和 `CLIStrings`。重要设计变化以 ADR 和独立 Git 提交记录。

- [架构与处理管线](docs/architecture.md)
- [设计缘由与非目标](docs/design-rationale.md)
- [使用指南与实例](docs/usage.md)
- [规范、平台和相似项目参考](docs/references.md)
- [成熟度与发布门禁 ADR](docs/adr/0003-maturity-and-release-gates.md)
- [发布手册](docs/releasing.md)
- [贡献指南](CONTRIBUTING.md)
- [安全策略](SECURITY.md)

## 开发

```bash
make format
make lint
make test
make example
make verify
make build
make app
make source
```

`make verify` 检查版本一致性、依赖锁定、许可/隐私资源和制品前置条件。CI 使用同一入口，并在
Apple Silicon runner 上验证核心、GUI 状态模型、示例和应用包。

## 许可证

项目采用 [MIT](LICENSE)。二进制发行同时包含项目许可证和
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 中的第三方许可说明。
