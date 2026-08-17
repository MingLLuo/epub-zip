import EPUBZipCore

enum AppStrings {
  static let subtitle = message(
    "Folder to EPUB · EPUB to folder · Validation",
    "目录打包 · EPUB 解包 · 自动检查"
  )
  static let dropPrompt = message("Drop an EPUB or source folder", "拖入 EPUB 或源目录")
  static func processing(_ name: String) -> LocalizedMessage {
    message("Processing \(name)", "正在处理 \(name)")
  }
  static let epubCreated = message("EPUB created", "EPUB 已创建")
  static let epubExtracted = message("EPUB extracted", "EPUB 已解包")
  static let failed = message("Could not complete", "没有完成")
  static let idleDetail = message(
    "Drop a folder to create an EPUB, or drop an .epub to create an editable folder. Existing results are never overwritten.",
    "拖入目录会生成 EPUB；拖入 .epub 会生成可编辑目录。已有同名结果不会被覆盖。"
  )
  static let workingDetail = message(
    "Validating the structure and writing safely to a temporary location…",
    "正在检查结构并安全写入临时位置…"
  )
  static let choose = message("Choose File or Folder…", "选择文件或目录…")
  static let showInFinder = message("Show in Finder", "在 Finder 中显示")
  static let processAnother = message("Process Another", "继续处理")
  static let chooseAgain = message("Choose Again…", "重新选择…")
  static let back = message("Back", "返回")
  static let nativeAppleSilicon = message("Native Apple Silicon", "Apple Silicon 原生")
  static let inputUnmodified = message("Input files are never modified", "不会修改输入文件")
  static let openPanelMessage = message(
    "Choose an EPUB file or a folder containing EPUB source files",
    "选择 EPUB 文件或包含 EPUB 源文件的目录"
  )
  static let process = message("Process", "处理")
  static func itemCount(_ count: Int) -> LocalizedMessage {
    message("\(count) items", "\(count) 个项目")
  }
  static let packageDirectory = message(
    "Name extracted folders “Book_pkg.epub”",
    "将解包目录命名为 “书名_pkg.epub”"
  )
  static let packageDirectoryHelp = message(
    "This reproduces the legacy iBooks Package naming convention; the output remains a normal folder.",
    "此选项复现旧工具的 iBooks Package 命名；输出仍是普通目录。"
  )

  private static func message(
    _ english: String,
    _ simplifiedChinese: String
  ) -> LocalizedMessage {
    LocalizedMessage(english: english, simplifiedChinese: simplifiedChinese)
  }
}
