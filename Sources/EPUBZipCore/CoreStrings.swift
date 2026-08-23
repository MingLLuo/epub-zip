import Foundation

enum CoreStrings {
  static func invalidEPUB(_ message: String) -> LocalizedMessage {
    localized("Invalid EPUB: \(message)", "EPUB 无效：\(message)")
  }

  static func unsupportedInput(_ name: String) -> LocalizedMessage {
    localized(
      "Choose an EPUB file or EPUB source folder: \(name)",
      "请选择 EPUB 文件或 EPUB 源目录：\(name)"
    )
  }

  static func outputExists(_ path: String) -> LocalizedMessage {
    localized("Output already exists: \(path)", "输出已存在：\(path)")
  }

  static func unsafeArchivePath(_ path: String) -> LocalizedMessage {
    localized("The archive contains an unsafe path: \(path)", "压缩包包含不安全路径：\(path)")
  }

  static func extractionStopped(_ reason: String) -> LocalizedMessage {
    localized("Extraction stopped: \(reason)", "解包已停止：\(reason)")
  }

  static let outputExtension = localized(
    "The output file must use the .epub extension",
    "输出文件必须使用 .epub 扩展名"
  )
  static let outputOverlapsInput = localized(
    "The output cannot replace or contain the input",
    "输出不能替换或包含输入"
  )
  static func createEPUBFailed(_ reason: String) -> LocalizedMessage {
    localized("Could not create EPUB: \(reason)", "创建 EPUB 失败：\(reason)")
  }
  static func createFileFailed(_ path: String) -> LocalizedMessage {
    localized("Could not create \(path)", "无法创建 \(path)")
  }
  static let actualSizeLimit = localized(
    "Actual extracted size exceeds the limit",
    "实际解压大小超过限制"
  )
  static func sizeMismatch(_ path: String) -> LocalizedMessage {
    localized(
      "The actual size of \(path) does not match its ZIP header",
      "\(path) 的实际大小与 ZIP 头不一致"
    )
  }
  static func readSourceFailed(_ path: String) -> LocalizedMessage {
    localized("Could not read source folder: \(path)", "无法读取源目录：\(path)")
  }
  static func readSourceItemFailed(_ path: String, _ reason: String) -> LocalizedMessage {
    localized(
      "Could not read \(path): \(reason)",
      "无法读取 \(path)：\(reason)"
    )
  }
  static func sourceContainsSymlink(_ path: String) -> LocalizedMessage {
    localized(
      "The source folder contains a symbolic link: \(path)",
      "源目录包含符号链接：\(path)"
    )
  }
  static func sourceContainsNonRegularFile(_ path: String) -> LocalizedMessage {
    localized(
      "The source folder contains a non-regular file: \(path)",
      "源目录包含非普通文件：\(path)"
    )
  }
  static func fileOutsideSource(_ path: String) -> LocalizedMessage {
    localized("File is outside the source folder: \(path)", "文件不在源目录内：\(path)")
  }

  static let missingMimetype = localized(
    "The root folder is missing mimetype",
    "根目录缺少 mimetype"
  )
  static func invalidMimetype(_ mediaType: String) -> LocalizedMessage {
    localized(
      "mimetype must contain exactly \(mediaType), with no newline",
      "mimetype 内容必须精确为 \(mediaType)，且不能换行"
    )
  }
  static let missingContainer = localized(
    "META-INF/container.xml is missing",
    "缺少 META-INF/container.xml"
  )
  static let missingRootfileDeclaration = localized(
    "container.xml does not declare an OPF rootfile",
    "container.xml 没有声明 OPF rootfile"
  )
  static func missingDeclaredRootfile(_ path: String) -> LocalizedMessage {
    localized(
      "The rootfile declared by container.xml was not found: \(path)",
      "找不到 container.xml 声明的 \(path)"
    )
  }
  static let invalidContainerXML = localized(
    "container.xml could not be parsed",
    "container.xml 无法解析"
  )
  static let invalidContainerRoot = localized(
    "container.xml must have an OCF container root element",
    "container.xml 必须以 OCF container 元素为根节点"
  )
  static let invalidContainerVersion = localized(
    "The OCF container version must be 1.0",
    "OCF container 版本必须为 1.0"
  )
  static let invalidContainerStructure = localized(
    "container.xml must contain exactly one rootfiles element in the OCF namespace",
    "container.xml 必须在 OCF 命名空间中包含且仅包含一个 rootfiles 元素"
  )
  static func invalidContainerElement(_ name: String) -> LocalizedMessage {
    localized(
      "Unexpected OCF element in container.xml: \(name)",
      "container.xml 中存在意外的 OCF 元素：\(name)"
    )
  }
  static func invalidRootfileDeclaration(_ detail: String) -> LocalizedMessage {
    localized("Invalid rootfile declaration: \(detail)", "rootfile 声明无效：\(detail)")
  }
  static func invalidRootfileMediaType(_ path: String) -> LocalizedMessage {
    localized(
      "\(path) must use media-type application/oebps-package+xml",
      "\(path) 的 media-type 必须为 application/oebps-package+xml"
    )
  }
  static func rootfileNotRegularFile(_ path: String) -> LocalizedMessage {
    localized(
      "The declared rootfile is not a regular file: \(path)",
      "声明的 rootfile 不是普通文件：\(path)"
    )
  }
  static let containerNotRegularFile = localized(
    "META-INF/container.xml must be a regular file",
    "META-INF/container.xml 必须是普通文件"
  )

  static func entryLimit(_ maximum: Int) -> LocalizedMessage {
    localized("Entry count exceeds \(maximum)", "条目数超过 \(maximum)")
  }
  static func duplicateEntry(_ path: String) -> LocalizedMessage {
    localized("Duplicate ZIP entry: \(path)", "ZIP 条目重复：\(path)")
  }
  static func pathTopologyCollision(_ first: String, _ second: String) -> LocalizedMessage {
    localized(
      "ZIP entry paths conflict as a file and directory: \(first), \(second)",
      "ZIP 条目发生文件与目录路径冲突：\(first)、\(second)"
    )
  }
  static func archivePathTooLong(_ path: String, maximum: Int) -> LocalizedMessage {
    localized(
      "The ZIP path exceeds \(maximum) UTF-8 bytes: \(path)",
      "ZIP 路径超过 \(maximum) 个 UTF-8 字节：\(path)"
    )
  }
  static func archivePathComponentTooLong(_ path: String, maximum: Int) -> LocalizedMessage {
    localized(
      "A ZIP path component exceeds \(maximum) UTF-8 bytes: \(path)",
      "ZIP 路径组件超过 \(maximum) 个 UTF-8 字节：\(path)"
    )
  }
  static func fileSizeLimit(_ path: String) -> LocalizedMessage {
    localized("\(path) exceeds the per-file size limit", "\(path) 超过单文件大小限制")
  }
  static let totalSizeLimit = localized(
    "Total extracted size exceeds the limit",
    "总解压大小超过限制"
  )
  static func invalidCompressedSize(_ path: String) -> LocalizedMessage {
    localized("\(path) has an invalid compressed size", "\(path) 的压缩大小异常")
  }
  static func compressionRatioLimit(_ path: String) -> LocalizedMessage {
    localized("\(path) exceeds the compression-ratio limit", "\(path) 的压缩比超过限制")
  }
  static let invalidLimits = localized(
    "All extraction limits must be greater than zero",
    "所有解包限制必须大于零"
  )
  static let uniqueOutputFailed = localized(
    "Could not generate a unique output name",
    "无法为输出生成唯一名称"
  )
  static let temporaryFileFailed = localized(
    "Could not create a temporary file",
    "无法创建临时文件"
  )
  static func restoreOutputFailed(_ backup: String, _ reason: String) -> LocalizedMessage {
    localized(
      "Could not restore the previous output. Its backup remains at \(backup): \(reason)",
      "无法恢复原输出；备份仍保留在 \(backup)：\(reason)"
    )
  }

  static func readZIPFailed(_ reason: String) -> LocalizedMessage {
    localized("Could not read ZIP container: \(reason)", "无法读取 ZIP 容器：\(reason)")
  }
  static let emptyZIP = localized("The ZIP container has no entries", "ZIP 容器没有条目")
  static let mimetypeOrder = localized(
    "mimetype must be the first ZIP entry",
    "mimetype 必须是第一个 ZIP 条目"
  )
  static let mimetypeStored = localized(
    "mimetype must be stored without compression",
    "mimetype 必须以 Store 模式保存"
  )
  static let mimetypeExtraField = localized(
    "The mimetype ZIP header must not contain an extra field",
    "mimetype 的 ZIP 头不能包含额外字段"
  )
  static func firstZIPHeaderFailed(_ reason: String) -> LocalizedMessage {
    localized(
      "Could not read the first ZIP local header: \(reason)",
      "无法读取首个 ZIP 本地头：\(reason)"
    )
  }
  static func entryCountMismatch(declared: Int, readable: Int) -> LocalizedMessage {
    localized(
      "The ZIP central directory declares \(declared) entries, but only \(readable) can be read safely",
      "ZIP 中央目录声明 \(declared) 个条目，但只能安全读取 \(readable) 个"
    )
  }
  static func caseCollision(_ first: String, _ second: String) -> LocalizedMessage {
    localized(
      "\(first) and \(second) collide on the default macOS file system",
      "\(first) 与 \(second) 在默认 macOS 文件系统上冲突"
    )
  }
  static func unsafePathDetail(_ path: String, _ reason: String) -> LocalizedMessage {
    localized("\(path): \(reason)", "\(path)：\(reason)")
  }
  static func symlinkEntry(_ path: String) -> LocalizedMessage {
    localized("Symbolic-link entries are not allowed: \(path)", "不允许符号链接条目：\(path)")
  }
  static let mimetypeRegularFile = localized(
    "mimetype must be a regular uncompressed file",
    "mimetype 必须是不压缩的普通文件"
  )
  static func unsafeRootfile(_ path: String) -> LocalizedMessage {
    localized("Unsafe rootfile path: \(path)", "rootfile 路径不安全：\(path)")
  }
  static func parseContainerFailed(_ reason: String) -> LocalizedMessage {
    localized("Could not parse container.xml: \(reason)", "container.xml 无法解析：\(reason)")
  }
  static func inspectionSizeLimit(_ path: String) -> LocalizedMessage {
    localized("\(path) exceeds the inspection size limit", "\(path) 超过检查大小限制")
  }
  static let incompleteZIPHeader = localized(
    "The ZIP local header is incomplete",
    "ZIP 本地头不完整"
  )
  static let missingZIPHeader = localized(
    "The file does not begin with a ZIP local header",
    "文件没有以 ZIP 本地头开始"
  )
  static let invalidFirstEntryName = localized(
    "The first ZIP entry name is invalid",
    "首个 ZIP 条目名称无效"
  )

  private static func localized(
    _ english: String,
    _ simplifiedChinese: String
  ) -> LocalizedMessage {
    LocalizedMessage(english: english, simplifiedChinese: simplifiedChinese)
  }
}
