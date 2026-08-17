# EPUB Zip

[English](README.en.md) | 简体中文

面向 Apple Silicon 的原生 macOS EPUB 打包与解包工具，也是经典 **ePub Zip-Unzip 64
3.0** 的现代开源替代品。

```text
拖入目录   → 创建符合 OCF 容器规则的 .epub
拖入 .epub → 创建安全、可编辑的源目录
```

SwiftUI 图形应用和 `epubzip` CLI 共用同一个 Swift 核心。项目只复用 MIT 许可的
[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)，不调用 Shell、Finder Automation、
`zip` 或 `unzip`。

## 快速开始

普通用户请打开 Apple Silicon DMG，将 `EPUB Zip.app` 拖入“应用程序”，然后把 EPUB 或源目录
拖进窗口。应用不会修改输入，也不会静默覆盖同名结果。

开发者可直接运行内置实例：

```bash
make example
```

它会把 [`Examples/MinimalBook`](Examples/MinimalBook) 打包为 `dist/MinimalBook.epub`，随后用
内置检查器验证容器。

## 为什么另做一个项目

EPUB 不是任意 ZIP：W3C OCF 规范要求根目录 `mimetype` 必须排在第一个、内容必须精确为
`application/epub+zip`、不得压缩，并且本地 ZIP 头不能带 extra field。通用压缩工具的默认
行为不一定满足这些约束。

调研的开源项目各有所长：

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) 提供成熟 Swift ZIP 基础；
- [Honeycrisp](https://github.com/kyrielie/honeycrisp) 展示原生 SwiftUI EPUB 体验；
- [EPUBCheck](https://github.com/w3c/epubcheck) 提供完整出版级验证；
- [epub-utils](https://github.com/ernestofgonzalez/epub-utils) 提供丰富的终端检查能力。

没有一个轻量项目同时提供 Apple Silicon 原生拖放、EPUB 合规打包、防御性解包，以及共用核心
的 CLI。详细比较与取舍见[设计缘由](docs/design-rationale.md)、[参考资料](docs/references.md)和
[ADR 0001](docs/adr/0001-apple-silicon-native-swift.md)。

## 主要能力

- 原生 `arm64` macOS 应用，最低 macOS 13
- 英文和简体中文，按 macOS 首选语言自动切换
- 单窗口拖放，也支持从 Finder 打开 EPUB/目录
- `mimetype` 固定为第一个 ZIP 条目、Store 模式、零 extra field
- 检查 `META-INF/container.xml` 及其声明的 OPF rootfile
- 拒绝 Zip Slip、绝对路径、反斜线、符号链接、重复条目和大小写冲突
- 限制条目数、单文件大小、总解压大小和压缩比
- 先写临时位置，验证成功后再提交输出
- GUI 自动生成 `book 2.epub`；CLI 默认拒绝覆盖
- 固定条目顺序、时间和权限，支持可重复构建
- 图形应用、CLI 和测试共用 `EPUBZipCore`

> 内置 `check` 只检查 ZIP/OCF 容器边界，不验证元数据、manifest、spine、导航、XHTML、
> 无障碍或阅读器行为。出版前请继续使用 [EPUBCheck](https://github.com/w3c/epubcheck)。

## 安装和构建

需要 Xcode 15 或更高版本。默认只构建 Apple Silicon：

```bash
make app
```

产物：

```text
dist/EPUB Zip-0.3.0-arm64.dmg
dist/EPUB Zip-0.3.0-arm64.zip
```

普通用户建议使用 DMG。无扩展名的 `epubzip` 是终端命令，不能作为图形应用双击。

可选通用版本：

```bash
ARCHS="arm64 x86_64" make app
```

## CLI 实例

构建并解压 CLI 包：

```bash
make build
unzip dist/epubzip-0.3.0-arm64-cli.zip
cd epubzip-0.3.0-arm64
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
./epubzip BookSource     # 打包
./epubzip MyBook.epub    # 解包
```

CLI 默认拒绝覆盖。确定需要替换时传入 `--force`。脚本可明确选择输出语言：

```bash
EPUBZIP_LANGUAGE=en ./epubzip --help
EPUBZIP_LANGUAGE=zh-Hans ./epubzip --help
```

完整选项、退出状态和工作示例见[使用指南](docs/usage.md)。

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

## 架构

```text
SwiftUI App ─┐
             ├── EPUBZipCore ── ZIPFoundation ── Apple libcompression
epubzip CLI ─┘
```

本地化文本按职责集中在 `CoreStrings`、`AppStrings` 和 `CLIStrings`，业务代码不包含并排的
双语长字符串。路径安全、OCF 规则和文件提交都只存在于核心库。

更多说明：

- [架构与处理管线](docs/architecture.md)
- [设计缘由与非目标](docs/design-rationale.md)
- [规范、依赖库和相似项目参考](docs/references.md)
- [贡献指南](CONTRIBUTING.md)
- [安全策略](SECURITY.md)

## 开发

```bash
make format
make lint
make test
make example
make build
make app
```

重要设计变化以 ADR 和独立 Git 提交记录。当前发布目标为原生 Apple Silicon；通用二进制是
可选构建，不是默认复杂度。

## 许可证

[MIT](LICENSE)
