import EPUBZipCore

enum CLIStrings {
  static func version(_ version: String) -> String {
    "epubzip \(version)"
  }

  static func error(_ description: String) -> String {
    "epubzip: \(description)"
  }

  static func created(_ path: String) -> LocalizedMessage {
    message("Created \(path)", "已创建 \(path)")
  }

  static func extracted(_ path: String) -> LocalizedMessage {
    message("Extracted \(path)", "已解包 \(path)")
  }

  static let valid = message("Valid", "有效")
  static let invalid = message("Invalid", "无效")

  static func reportSummary(isValid: Bool, path: String, entryCount: Int) -> LocalizedMessage {
    let englishStatus = isValid ? valid.english : invalid.english
    let simplifiedChineseStatus = isValid ? valid.simplifiedChinese : invalid.simplifiedChinese
    let englishEntry = entryCount == 1 ? "entry" : "entries"
    return message(
      "\(englishStatus): \(path) (\(entryCount) \(englishEntry))",
      "\(simplifiedChineseStatus)：\(path)（\(entryCount) 个条目）"
    )
  }

  static func inspectionIssue(_ issue: InspectionIssue) -> LocalizedMessage {
    let englishSeverity: String
    let simplifiedChineseSeverity: String
    switch issue.severity {
    case .warning:
      englishSeverity = "warning"
      simplifiedChineseSeverity = "警告"
    case .error:
      englishSeverity = "error"
      simplifiedChineseSeverity = "错误"
    }
    return message(
      "- \(englishSeverity) [\(issue.code)]: \(issue.message)",
      "- \(simplifiedChineseSeverity) [\(issue.code)]：\(issue.message)"
    )
  }

  static func rootfiles(_ paths: [String]) -> LocalizedMessage {
    let joinedPaths = paths.joined(separator: ", ")
    return message("rootfiles: \(joinedPaths)", "根文件：\(joinedPaths)")
  }

  static func missingOptionValue(_ name: String) -> LocalizedMessage {
    message("\(name) requires a value", "\(name) 缺少参数")
  }

  static func duplicateOption(_ displayName: String) -> LocalizedMessage {
    message(
      "Option \(displayName) may only be specified once",
      "选项 \(displayName) 只能指定一次"
    )
  }

  static func unknownOption(_ name: String) -> LocalizedMessage {
    message("Unknown option: \(name)", "未知选项：\(name)")
  }

  static let packUsage = message(
    "epubzip pack [-o output.epub] [--force] <directory>",
    "epubzip pack [-o 输出.epub] [--force] <目录>"
  )

  static let unpackUsage = message(
    "epubzip unpack [-o directory] [--package] [--force] <book.epub>",
    "epubzip unpack [-o 目录] [--package] [--force] <图书.epub>"
  )

  static let checkUsage = message(
    "epubzip check [--json] <book.epub>",
    "epubzip check [--json] <图书.epub>"
  )

  static let autoUsage = message(
    "epubzip auto [--package] [--force] <path>...",
    "epubzip auto [--package] [--force] <路径>..."
  )

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
    Use -- before paths that begin with a hyphen.
    """,
    """
    epubzip — 原生 EPUB 打包、解包与容器检查工具

    用法：
      epubzip pack [-o 输出.epub] [--force] <目录>
      epubzip unpack [-o 目录] [--package] [--force] <图书.epub>
      epubzip check [--json] <图书.epub>
      epubzip auto [--package] [--force] <路径>...
      epubzip <路径>...

    未指定子命令时，目录会被打包，.epub 文件会被解包。
    路径以连字符开头时，请在路径前使用 --。
    """
  )

  private static func message(
    _ english: String,
    _ simplifiedChinese: String
  ) -> LocalizedMessage {
    LocalizedMessage(english: english, simplifiedChinese: simplifiedChinese)
  }
}
