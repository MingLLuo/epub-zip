import EPUBZipCore

enum CLIStrings {
  static func created(_ path: String) -> LocalizedMessage {
    message("Created \(path)", "已创建 \(path)")
  }
  static func extracted(_ path: String) -> LocalizedMessage {
    message("Extracted \(path)", "已解包 \(path)")
  }
  static let valid = message("Valid", "有效")
  static let invalid = message("Invalid", "无效")
  static func reportSummary(status: String, path: String, entryCount: Int) -> LocalizedMessage {
    message(
      "\(status): \(path) (\(entryCount) entries)",
      "\(status)：\(path)（\(entryCount) 个条目）"
    )
  }
  static func missingOptionValue(_ name: String) -> LocalizedMessage {
    message("\(name) requires a value", "\(name) 缺少参数")
  }
  static let usage = message(
    """
    epubzip — Native EPUB packing, extraction, and container validation

    Usage:
      epubzip pack [-o output.epub] [--force] <directory>
      epubzip unpack [-o directory] [--package] [--force] <book.epub>
      epubzip check [--json] <book.epub>
      epubzip auto [--package] [--force] <path>...
      epubzip <path>...

    Without a subcommand, folders are packed and .epub files are extracted.
    """,
    """
    epubzip — 原生 EPUB 打包、解包与容器检查工具

    用法：
      epubzip pack [-o output.epub] [--force] <directory>
      epubzip unpack [-o directory] [--package] [--force] <book.epub>
      epubzip check [--json] <book.epub>
      epubzip auto [--package] [--force] <path>...
      epubzip <path>...

    未指定子命令时，目录会被打包，.epub 文件会被解包。
    """
  )

  private static func message(
    _ english: String,
    _ simplifiedChinese: String
  ) -> LocalizedMessage {
    LocalizedMessage(english: english, simplifiedChinese: simplifiedChinese)
  }
}
