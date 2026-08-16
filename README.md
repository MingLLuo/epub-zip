# epubzip

`epubzip` 是一个安全、可移植、可复现的 EPUB 打包与解包工具，也是经典 macOS 工具 **ePub Zip-Unzip 64 3.0** 的现代开源替代品。

它直接使用 Go 标准库读写 ZIP，不拼接 Shell 命令。生成的 EPUB 会把 `mimetype` 放在第一个 ZIP 条目中，以 Store 模式保存且不带额外字段，符合 EPUB Open Container Format（OCF）的关键要求。

## 功能

- 将标准 EPUB 源目录打包为 `.epub`
- 安全地将 `.epub` 解包为目录
- 检查 `mimetype`、ZIP 方法、`container.xml` 和 OPF rootfile
- 防止 Zip Slip、符号链接、大小炸弹和大小写文件名碰撞
- 通过临时路径和原子替换避免半成品
- 固定条目顺序与时间元数据，支持可重复构建
- macOS、Linux 和 Windows 使用同一套核心代码

> `check` 是容器级检查器，不替代完整的 [EPUBCheck](https://www.w3.org/publishing/epubcheck/)。

## 安装

需要 Go 1.22 或更高版本：

```bash
go install ./cmd/epubzip
```

或者在仓库中构建：

```bash
make build
./bin/epubzip version
```

## 使用

### 打包

源目录至少需要包含：

```text
book/
├── mimetype
├── META-INF/
│   └── container.xml
└── EPUB/
    └── book.opf
```

然后执行：

```bash
epubzip pack book
epubzip pack -o release/book.epub book
```

### 解包

```bash
epubzip unpack book.epub
epubzip unpack --package book.epub
```

`--package` 会生成 `book_pkg.epub` 目录，用于模拟旧工具的 iBooks Package 模式。它仍然是目录，不是压缩后的 EPUB。

默认安全限制为 20,000 个条目、单文件 512 MiB、总计 2 GiB、最大压缩比 1000:1。可通过 `unpack` 参数收紧前三项限制。

### 检查

```bash
epubzip check book.epub
epubzip check --json book.epub
```

### 自动判断

和旧工具的拖放分派方式类似：目录会被打包，`.epub` 文件会被解包。

```bash
epubzip book/
epubzip book.epub
epubzip auto first.epub second.epub
```

所有命令默认拒绝覆盖已有输出。确认需要替换时显式传入 `--force`。

## 与旧工具的区别

| 方面 | ePub Zip-Unzip 64 3.0 | epubzip |
|---|---|---|
| 实现 | AppleScript + Shell 命令 | Go 标准库 |
| 平台 | Intel macOS | macOS / Linux / Windows |
| 路径处理 | Shell 字符串拼接 | 结构化文件 API |
| 解包权限 | 所有文件 `755` | 目录 `755`、文件 `644` |
| Zip Slip 防护 | 依赖系统 `unzip` | 内置检查 |
| 资源限制 | 无 | 文件数、大小、压缩比限制 |
| EPUB 检查 | 无 | OCF 容器级检查 |
| 错误恢复 | 可能留下部分输出 | 临时输出成功后再提交 |

旧工具会先执行 `zip -FF` 尝试修复损坏的 ZIP。`epubzip` 当前刻意不自动修复输入，因为“静默修复”可能改变证据或掩盖损坏；它会明确报错。

## 开发

```bash
make fmt
make test
make build
```

架构和安全边界见 [`docs/architecture.md`](docs/architecture.md)，贡献方式见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)
