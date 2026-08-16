# EPUB Zip

一个面向 Apple Silicon 的原生 macOS EPUB 打包与解包工具，也是经典 **ePub Zip-Unzip 64 3.0** 的现代开源替代品。

把 EPUB 或源目录拖进窗口即可：

- 拖入目录 → 创建符合 OCF 规则的 `.epub`
- 拖入 `.epub` → 创建可编辑目录
- 自动检查 `mimetype`、`META-INF/container.xml` 和 OPF rootfile

项目使用 Swift 6、SwiftUI 和 [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)。不调用 Shell、Finder Automation、`zip` 或 `unzip`。

## 为什么另做一个项目

调研过的开源项目各自解决了部分问题：ZIPFoundation 提供可靠的 Swift ZIP 基础；Honeycrisp 展示了原生 EPUB 拖放界面；EPUBCheck 提供完整标准校验。但没有一个轻量项目同时提供 Apple Silicon 原生拖放、EPUB 合规打包和安全解包。

完整调研与决策见 [`docs/adr/0001-apple-silicon-native-swift.md`](docs/adr/0001-apple-silicon-native-swift.md)。

## 特性

- 原生 `arm64` macOS 应用，最低支持 macOS 13
- 单窗口拖放操作，也支持从 Finder 打开 EPUB/目录
- `mimetype` 始终为第一个 ZIP 条目、Store 模式、无额外字段
- 拒绝 Zip Slip、符号链接、重复条目和大小写冲突
- 文件数、单文件大小、总大小和压缩比限制
- 先写临时路径，检查成功后才提交输出
- 同名输出自动生成为 `book 2.epub`，不静默覆盖
- 固定 ZIP 条目顺序和时间，支持可重复构建
- 自带使用同一核心的 `epubzip` CLI
- MIT 许可

> 内置 `check` 只覆盖 ZIP/OCF 容器边界。出版级检查请继续使用 [EPUBCheck](https://github.com/w3c/epubcheck)。

## 构建原生应用

需要 Xcode 15 或更高版本。默认只构建 Apple Silicon：

```bash
make app
```

产物位于：

```text
dist/EPUB Zip-0.1.0-arm64.zip
```

构建通用版本是可选项：

```bash
ARCHS="arm64 x86_64" make app
```

## CLI

```bash
make build

./dist/epubzip pack book/
./dist/epubzip unpack book.epub
./dist/epubzip unpack --package book.epub
./dist/epubzip check book.epub
```

也可省略子命令：

```bash
./dist/epubzip book/       # 打包
./dist/epubzip book.epub   # 解包
```

CLI 默认拒绝覆盖。确定需要替换时传入 `--force`；图形应用始终采用自动避让命名。

## EPUB 源目录

最小结构：

```text
book/
├── mimetype
├── META-INF/
│   └── container.xml
└── EPUB/
    └── book.opf
```

`mimetype` 内容必须精确为 `application/epub+zip`，不能带换行。

## 开发

```bash
make format
make test
make build
make app
```

项目保持三个清晰目标：

```text
EPUBZipCore   EPUB/OCF 规则与安全文件操作
epubzip       自动化命令行入口
EPUBZipApp    SwiftUI 单窗口拖放应用
```

架构说明见 [`docs/architecture.md`](docs/architecture.md)，贡献指南见 [`CONTRIBUTING.md`](CONTRIBUTING.md)，安全策略见 [`SECURITY.md`](SECURITY.md)。

## 许可证

[MIT](LICENSE)
