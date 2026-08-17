import Foundation
import ZIPFoundation

public struct EPUBService: Sendable {
  private let inspector = EPUBInspector()

  private var fileManager: FileManager { .default }

  public init() {}

  public func process(
    _ inputURL: URL,
    packageDirectory: Bool = false,
    conflictPolicy: ConflictPolicy = .uniquify,
    limits: ExtractionLimits = .default
  ) throws -> OperationResult {
    let values = try inputURL.resourceValues(forKeys: [.isDirectoryKey])
    if values.isDirectory == true {
      return try pack(
        directory: inputURL,
        to: defaultPackedURL(for: inputURL),
        conflictPolicy: conflictPolicy
      )
    }
    guard inputURL.pathExtension.caseInsensitiveCompare("epub") == .orderedSame else {
      throw EPUBZipError.unsupportedInput(inputURL)
    }
    return try unpack(
      epub: inputURL,
      to: defaultUnpackedURL(for: inputURL, packageDirectory: packageDirectory),
      conflictPolicy: conflictPolicy,
      limits: limits
    )
  }

  public func pack(
    directory sourceURL: URL,
    to requestedOutputURL: URL? = nil,
    conflictPolicy: ConflictPolicy = .fail
  ) throws -> OperationResult {
    let source = sourceURL.standardizedFileURL
    let requested = (requestedOutputURL ?? defaultPackedURL(for: source)).standardizedFileURL
    guard try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
      throw EPUBZipError.unsupportedInput(source)
    }
    guard requested.pathExtension.caseInsensitiveCompare("epub") == .orderedSame else {
      throw EPUBZipError.operationFailed(
        EPUBZipLocalization.text(
          "The output file must use the .epub extension",
          zhHans: "输出文件必须使用 .epub 扩展名"
        )
      )
    }
    guard !requested.isContained(in: source) else {
      throw EPUBZipError.operationFailed(
        EPUBZipLocalization.text(
          "The output cannot be inside the source folder being packed",
          zhHans: "输出不能位于要打包的源目录内"
        )
      )
    }

    let files = try collectFiles(in: source)
    try validateSourceDirectory(source, files: files)
    let output = try resolvedOutputURL(requested, policy: conflictPolicy)
    let temporary = try temporaryFile(beside: output, suffix: ".epub")
    var committed = false
    defer {
      if !committed { try? fileManager.removeItem(at: temporary) }
    }

    do {
      let archive = try Archive(url: temporary, accessMode: .create)
      let ordered = files.sorted {
        if $0.path == "mimetype" { return true }
        if $1.path == "mimetype" { return false }
        return $0.path < $1.path
      }
      for file in ordered {
        try add(file, to: archive, stored: file.path == "mimetype")
      }
    } catch {
      throw EPUBZipError.operationFailed(
        EPUBZipLocalization.text(
          "Could not create EPUB: \(error.localizedDescription)",
          zhHans: "创建 EPUB 失败：\(error.localizedDescription)"
        )
      )
    }

    let report = try inspector.inspect(temporary)
    guard report.isValid else {
      throw EPUBZipError.invalidEPUB(report.errorSummary)
    }
    try commit(temporary: temporary, to: output, replacing: conflictPolicy == .replace)
    committed = true
    return OperationResult(kind: .pack, inputURL: source, outputURL: output, report: report)
  }

  public func unpack(
    epub sourceURL: URL,
    to requestedOutputURL: URL? = nil,
    conflictPolicy: ConflictPolicy = .fail,
    limits: ExtractionLimits = .default
  ) throws -> OperationResult {
    try validate(limits)
    let source = sourceURL.standardizedFileURL
    let report = try inspector.inspect(source)
    guard report.isValid else {
      throw EPUBZipError.invalidEPUB(report.errorSummary)
    }
    let requested = (requestedOutputURL ?? defaultUnpackedURL(for: source, packageDirectory: false))
      .standardizedFileURL
    let output = try resolvedOutputURL(requested, policy: conflictPolicy)
    let temporary = try temporaryDirectory(beside: output)
    var committed = false
    defer {
      if !committed { try? fileManager.removeItem(at: temporary) }
    }

    let archive: Archive
    do {
      archive = try Archive(url: source, accessMode: .read)
    } catch {
      throw EPUBZipError.invalidEPUB(error.localizedDescription)
    }
    let entries = Array(archive)
    try preflight(entries, limits: limits)
    var extractedTotal: UInt64 = 0
    for entry in entries {
      let relativePath = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
      if relativePath.isEmpty { continue }
      let target = temporary.appendingPathComponent(
        relativePath, isDirectory: entry.type == .directory)
      guard target.isContained(in: temporary) else {
        throw EPUBZipError.unsafePath(entry.path)
      }
      switch entry.type {
      case .directory:
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
      case .symlink:
        throw EPUBZipError.unsafePath(entry.path)
      case .file:
        try fileManager.createDirectory(
          at: target.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        guard
          fileManager.createFile(
            atPath: target.path, contents: nil, attributes: [.posixPermissions: 0o644])
        else {
          throw EPUBZipError.operationFailed(
            EPUBZipLocalization.text(
              "Could not create \(target.path)", zhHans: "无法创建 \(target.path)")
          )
        }
        let handle = try FileHandle(forWritingTo: target)
        var fileBytes: UInt64 = 0
        do {
          _ = try archive.extract(entry) { chunk in
            fileBytes += UInt64(chunk.count)
            extractedTotal += UInt64(chunk.count)
            guard fileBytes <= limits.maximumFileSize,
              extractedTotal <= limits.maximumTotalSize
            else {
              throw EPUBZipError.extractionLimit(
                EPUBZipLocalization.text(
                  "Actual extracted size exceeds the limit",
                  zhHans: "实际解压大小超过限制"
                )
              )
            }
            try handle.write(contentsOf: chunk)
          }
          try handle.close()
        } catch {
          try? handle.close()
          throw error
        }
        guard fileBytes == entry.uncompressedSize else {
          throw EPUBZipError.invalidEPUB(
            EPUBZipLocalization.text(
              "The actual size of \(entry.path) does not match its ZIP header",
              zhHans: "\(entry.path) 的实际大小与 ZIP 头不一致"
            )
          )
        }
      }
    }

    let extractedFiles = try collectFiles(in: temporary)
    try validateSourceDirectory(temporary, files: extractedFiles)
    try commit(temporary: temporary, to: output, replacing: conflictPolicy == .replace)
    committed = true
    return OperationResult(kind: .unpack, inputURL: source, outputURL: output, report: report)
  }

  public func inspect(_ epubURL: URL) throws -> InspectionReport {
    try inspector.inspect(epubURL)
  }

  public func defaultPackedURL(for directory: URL) -> URL {
    var name = directory.lastPathComponent
    if name.lowercased().hasSuffix(".epub") {
      name.removeLast(5)
    }
    if name.lowercased().hasSuffix("_pkg") {
      name.removeLast(4)
    }
    var output = directory.deletingLastPathComponent().appendingPathComponent(name)
      .appendingPathExtension("epub")
    if output.standardizedFileURL == directory.standardizedFileURL {
      output = directory.deletingLastPathComponent()
        .appendingPathComponent(name + "-packed")
        .appendingPathExtension("epub")
    }
    return output
  }

  public func defaultUnpackedURL(for epub: URL, packageDirectory: Bool) -> URL {
    let base = epub.deletingPathExtension().lastPathComponent
    let name = packageDirectory ? base + "_pkg.epub" : base
    return epub.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
  }
}

extension EPUBService {
  fileprivate struct SourceFile {
    let url: URL
    let path: String
    let size: Int64
  }

  fileprivate func collectFiles(in root: URL) throws -> [SourceFile] {
    let keys: [URLResourceKey] = [
      .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
    ]
    let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
    guard
      let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: keys,
        options: [],
        errorHandler: { _, _ in false }
      )
    else {
      throw EPUBZipError.operationFailed(
        EPUBZipLocalization.text(
          "Could not read source folder: \(root.path)", zhHans: "无法读取源目录：\(root.path)")
      )
    }
    var files: [SourceFile] = []
    while let item = enumerator.nextObject() as? URL {
      let values = try item.resourceValues(forKeys: Set(keys))
      if values.isSymbolicLink == true {
        enumerator.skipDescendants()
        throw EPUBZipError.operationFailed(
          EPUBZipLocalization.text(
            "The source folder contains a symbolic link: \(item.path)",
            zhHans: "源目录包含符号链接：\(item.path)"
          )
        )
      }
      if values.isDirectory == true { continue }
      guard values.isRegularFile == true else {
        throw EPUBZipError.operationFailed(
          EPUBZipLocalization.text(
            "The source folder contains a non-regular file: \(item.path)",
            zhHans: "源目录包含非普通文件：\(item.path)"
          )
        )
      }
      if item.lastPathComponent == ".DS_Store" { continue }
      let resolvedItem = item.resolvingSymlinksInPath().standardizedFileURL
      let rootComponents = resolvedRoot.pathComponents
      let itemComponents = resolvedItem.pathComponents
      guard itemComponents.count > rootComponents.count,
        Array(itemComponents.prefix(rootComponents.count)) == rootComponents
      else {
        throw EPUBZipError.operationFailed(
          EPUBZipLocalization.text(
            "File is outside the source folder: \(item.path)",
            zhHans: "文件不在源目录内：\(item.path)"
          )
        )
      }
      let relative = itemComponents.dropFirst(rootComponents.count).joined(separator: "/")
      try SafeArchivePath.validate(relative)
      files.append(.init(url: item, path: relative, size: Int64(values.fileSize ?? 0)))
    }
    return files
  }

  fileprivate func validateSourceDirectory(_ root: URL, files: [SourceFile]) throws {
    let names = Set(files.map(\.path))
    guard names.contains("mimetype") else {
      throw EPUBZipError.invalidEPUB(
        EPUBZipLocalization.text(
          "The root folder is missing mimetype", zhHans: "根目录缺少 mimetype")
      )
    }
    let mimetype = root.appendingPathComponent("mimetype")
    guard try Data(contentsOf: mimetype) == Data(EPUBInspector.mediaType.utf8) else {
      throw EPUBZipError.invalidEPUB(
        EPUBZipLocalization.text(
          "mimetype must contain exactly \(EPUBInspector.mediaType), with no newline",
          zhHans: "mimetype 内容必须精确为 \(EPUBInspector.mediaType)，且不能换行"
        )
      )
    }
    let containerURL = root.appendingPathComponent("META-INF/container.xml")
    guard names.contains("META-INF/container.xml") else {
      throw EPUBZipError.invalidEPUB(
        EPUBZipLocalization.text(
          "META-INF/container.xml is missing", zhHans: "缺少 META-INF/container.xml")
      )
    }
    let rootfiles = try sourceRootfiles(from: Data(contentsOf: containerURL))
    guard !rootfiles.isEmpty else {
      throw EPUBZipError.invalidEPUB(
        EPUBZipLocalization.text(
          "container.xml does not declare an OPF rootfile",
          zhHans: "container.xml 没有声明 OPF rootfile"
        )
      )
    }
    for rootfile in rootfiles {
      try SafeArchivePath.validate(rootfile)
      guard names.contains(rootfile) else {
        throw EPUBZipError.invalidEPUB(
          EPUBZipLocalization.text(
            "The rootfile declared by container.xml was not found: \(rootfile)",
            zhHans: "找不到 container.xml 声明的 \(rootfile)"
          )
        )
      }
    }
  }

  fileprivate func sourceRootfiles(from data: Data) throws -> [String] {
    final class Delegate: NSObject, XMLParserDelegate {
      var paths: [String] = []
      var error: Error?

      func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
      ) {
        if elementName == "rootfile", let path = attributeDict["full-path"] { paths.append(path) }
      }

      func parser(_: XMLParser, parseErrorOccurred parseError: Error) { error = parseError }
    }
    let delegate = Delegate()
    let parser = XMLParser(data: data)
    parser.shouldProcessNamespaces = true
    parser.delegate = delegate
    guard parser.parse() else {
      throw EPUBZipError.invalidEPUB(
        delegate.error?.localizedDescription
          ?? EPUBZipLocalization.text(
            "container.xml could not be parsed", zhHans: "container.xml 无法解析")
      )
    }
    return delegate.paths
  }

  fileprivate func add(_ file: SourceFile, to archive: Archive, stored: Bool) throws {
    let handle = try FileHandle(forReadingFrom: file.url)
    defer { try? handle.close() }
    try archive.addEntry(
      with: file.path,
      type: .file,
      uncompressedSize: file.size,
      modificationDate: Date(timeIntervalSince1970: 315_532_800),
      permissions: 0o644,
      compressionMethod: stored ? .none : .deflate
    ) { position, size in
      try handle.seek(toOffset: UInt64(position))
      return try handle.read(upToCount: size) ?? Data()
    }
  }

  fileprivate func preflight(_ entries: [Entry], limits: ExtractionLimits) throws {
    guard entries.count <= limits.maximumEntries else {
      throw EPUBZipError.extractionLimit(
        EPUBZipLocalization.text(
          "Entry count exceeds \(limits.maximumEntries)",
          zhHans: "条目数超过 \(limits.maximumEntries)"
        )
      )
    }
    var total: UInt64 = 0
    var names = Set<String>()
    var foldedNames = Set<String>()
    for entry in entries {
      try SafeArchivePath.validate(entry.path)
      guard names.insert(entry.path).inserted else {
        throw EPUBZipError.invalidEPUB(
          EPUBZipLocalization.text(
            "Duplicate ZIP entry: \(entry.path)", zhHans: "ZIP 条目重复：\(entry.path)")
        )
      }
      let folded = entry.path.folding(
        options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      guard foldedNames.insert(folded).inserted else {
        throw EPUBZipError.invalidEPUB(
          EPUBZipLocalization.text(
            "ZIP entries have a case-insensitive collision on the default macOS file system",
            zhHans: "ZIP 条目在默认 macOS 文件系统上发生大小写冲突"
          )
        )
      }
      guard entry.type != .symlink else {
        throw EPUBZipError.unsafePath(entry.path)
      }
      guard entry.uncompressedSize <= limits.maximumFileSize else {
        throw EPUBZipError.extractionLimit(
          EPUBZipLocalization.text(
            "\(entry.path) exceeds the per-file size limit",
            zhHans: "\(entry.path) 超过单文件大小限制"
          )
        )
      }
      let (newTotal, overflow) = total.addingReportingOverflow(entry.uncompressedSize)
      guard !overflow, newTotal <= limits.maximumTotalSize else {
        throw EPUBZipError.extractionLimit(
          EPUBZipLocalization.text(
            "Total extracted size exceeds the limit", zhHans: "总解压大小超过限制")
        )
      }
      total = newTotal
      if entry.type == .file, entry.uncompressedSize > 0 {
        guard entry.compressedSize > 0 else {
          throw EPUBZipError.extractionLimit(
            EPUBZipLocalization.text(
              "\(entry.path) has an invalid compressed size",
              zhHans: "\(entry.path) 的压缩大小异常"
            )
          )
        }
        if entry.uncompressedSize / entry.compressedSize > limits.maximumCompressionRatio {
          throw EPUBZipError.extractionLimit(
            EPUBZipLocalization.text(
              "\(entry.path) exceeds the compression-ratio limit",
              zhHans: "\(entry.path) 的压缩比超过限制"
            )
          )
        }
      }
    }
  }

  fileprivate func validate(_ limits: ExtractionLimits) throws {
    guard limits.maximumEntries > 0,
      limits.maximumFileSize > 0,
      limits.maximumTotalSize > 0,
      limits.maximumCompressionRatio > 0
    else {
      throw EPUBZipError.operationFailed(
        EPUBZipLocalization.text(
          "All extraction limits must be greater than zero",
          zhHans: "所有解包限制必须大于零"
        )
      )
    }
  }

  fileprivate func resolvedOutputURL(_ requested: URL, policy: ConflictPolicy) throws -> URL {
    guard fileManager.fileExists(atPath: requested.path) else { return requested }
    switch policy {
    case .fail:
      throw EPUBZipError.outputExists(requested)
    case .replace:
      return requested
    case .uniquify:
      let directory = requested.deletingLastPathComponent()
      let ext = requested.pathExtension
      let stem = requested.deletingPathExtension().lastPathComponent
      for index in 2...10_000 {
        var candidate = directory.appendingPathComponent("\(stem) \(index)")
        if !ext.isEmpty { candidate.appendPathExtension(ext) }
        if !fileManager.fileExists(atPath: candidate.path) { return candidate }
      }
      throw EPUBZipError.operationFailed(
        EPUBZipLocalization.text(
          "Could not generate a unique output name", zhHans: "无法为输出生成唯一名称")
      )
    }
  }

  fileprivate func temporaryFile(beside output: URL, suffix: String) throws -> URL {
    try fileManager.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    let url = output.deletingLastPathComponent()
      .appendingPathComponent(".epubzip-\(UUID().uuidString)\(suffix)")
    guard fileManager.createFile(atPath: url.path, contents: nil) else {
      throw EPUBZipError.operationFailed(
        EPUBZipLocalization.text(
          "Could not create a temporary file", zhHans: "无法创建临时文件")
      )
    }
    try fileManager.removeItem(at: url)
    return url
  }

  fileprivate func temporaryDirectory(beside output: URL) throws -> URL {
    try fileManager.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    let url = output.deletingLastPathComponent().appendingPathComponent(
      ".epubzip-\(UUID().uuidString)")
    try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
    return url
  }

  fileprivate func commit(temporary: URL, to output: URL, replacing: Bool) throws {
    guard fileManager.fileExists(atPath: output.path) else {
      try fileManager.moveItem(at: temporary, to: output)
      return
    }
    guard replacing else { throw EPUBZipError.outputExists(output) }
    let backup = output.deletingLastPathComponent().appendingPathComponent(
      ".epubzip-backup-\(UUID().uuidString)")
    try fileManager.moveItem(at: output, to: backup)
    do {
      try fileManager.moveItem(at: temporary, to: output)
      try fileManager.removeItem(at: backup)
    } catch {
      if !fileManager.fileExists(atPath: output.path) {
        try? fileManager.moveItem(at: backup, to: output)
      }
      throw error
    }
  }
}

extension URL {
  fileprivate func isContained(in directory: URL) -> Bool {
    let root = directory.standardizedFileURL.pathComponents
    let candidate = standardizedFileURL.pathComponents
    return candidate.count > root.count && Array(candidate.prefix(root.count)) == root
  }
}

extension InspectionReport {
  fileprivate var errorSummary: String {
    issues.filter { $0.severity == .error }.map(\.message).joined(
      separator: EPUBZipLocalization.usesSimplifiedChinese ? "；" : "; "
    )
  }
}
