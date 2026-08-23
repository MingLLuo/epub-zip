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
      throw EPUBZipError.operationFailed(CoreStrings.outputExtension.localized)
    }
    let files = try collectFiles(in: source)
    try validateSourceDirectory(files)
    let output = try resolvedOutputURL(requested, policy: conflictPolicy)
    guard !output.isSameOrContained(in: source) else {
      throw EPUBZipError.operationFailed(CoreStrings.outputOverlapsInput.localized)
    }
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
        CoreStrings.createEPUBFailed(error.localizedDescription).localized)
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
    try limits.validate()
    let source = sourceURL.standardizedFileURL
    let report = try inspector.inspect(source, limits: limits)
    guard report.isValid else {
      throw EPUBZipError.invalidEPUB(report.errorSummary)
    }
    let requested = (requestedOutputURL ?? defaultUnpackedURL(for: source, packageDirectory: false))
      .standardizedFileURL
    let output = try resolvedOutputURL(requested, policy: conflictPolicy)
    guard !source.isSameOrContained(in: output) else {
      throw EPUBZipError.operationFailed(CoreStrings.outputOverlapsInput.localized)
    }
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
    var entries: [Entry] = []
    entries.reserveCapacity(min(report.entryCount, limits.maximumEntries))
    for entry in archive {
      guard entries.count < limits.maximumEntries else {
        throw EPUBZipError.extractionLimit(
          CoreStrings.entryLimit(limits.maximumEntries).localized
        )
      }
      entries.append(entry)
    }
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
          throw EPUBZipError.operationFailed(CoreStrings.createFileFailed(target.path).localized)
        }
        let handle = try FileHandle(forWritingTo: target)
        var fileBytes: UInt64 = 0
        do {
          _ = try archive.extract(entry) { chunk in
            let (nextFileBytes, fileOverflow) = fileBytes.addingReportingOverflow(
              UInt64(chunk.count)
            )
            let (nextTotal, totalOverflow) = extractedTotal.addingReportingOverflow(
              UInt64(chunk.count)
            )
            guard !fileOverflow, !totalOverflow,
              nextFileBytes <= limits.maximumFileSize,
              nextTotal <= limits.maximumTotalSize
            else {
              throw EPUBZipError.extractionLimit(CoreStrings.actualSizeLimit.localized)
            }
            fileBytes = nextFileBytes
            extractedTotal = nextTotal
            try handle.write(contentsOf: chunk)
          }
          try handle.close()
        } catch {
          try? handle.close()
          throw error
        }
        guard fileBytes == entry.uncompressedSize else {
          throw EPUBZipError.invalidEPUB(CoreStrings.sizeMismatch(entry.path).localized)
        }
      }
    }

    let extractedFiles = try collectFiles(in: temporary)
    try validateSourceDirectory(extractedFiles)
    try commit(temporary: temporary, to: output, replacing: conflictPolicy == .replace)
    committed = true
    return OperationResult(kind: .unpack, inputURL: source, outputURL: output, report: report)
  }

  public func inspect(
    _ epubURL: URL,
    limits: ExtractionLimits = .default
  ) throws -> InspectionReport {
    try inspector.inspect(epubURL, limits: limits)
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
    var enumerationFailure: (url: URL, error: Error)?
    guard
      let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: keys,
        options: [],
        errorHandler: { url, error in
          enumerationFailure = (url, error)
          return false
        }
      )
    else {
      throw EPUBZipError.operationFailed(CoreStrings.readSourceFailed(root.path).localized)
    }
    var files: [SourceFile] = []
    while let item = enumerator.nextObject() as? URL {
      let values = try item.resourceValues(forKeys: Set(keys))
      if values.isSymbolicLink == true {
        enumerator.skipDescendants()
        throw EPUBZipError.operationFailed(CoreStrings.sourceContainsSymlink(item.path).localized)
      }
      if values.isDirectory == true { continue }
      guard values.isRegularFile == true else {
        throw EPUBZipError.operationFailed(
          CoreStrings.sourceContainsNonRegularFile(item.path).localized
        )
      }
      if item.lastPathComponent == ".DS_Store" { continue }
      let resolvedItem = item.resolvingSymlinksInPath().standardizedFileURL
      let rootComponents = resolvedRoot.pathComponents
      let itemComponents = resolvedItem.pathComponents
      guard itemComponents.count > rootComponents.count,
        Array(itemComponents.prefix(rootComponents.count)) == rootComponents
      else {
        throw EPUBZipError.operationFailed(CoreStrings.fileOutsideSource(item.path).localized)
      }
      let relative = itemComponents.dropFirst(rootComponents.count).joined(separator: "/")
      try SafeArchivePath.validate(relative)
      files.append(.init(url: item, path: relative, size: Int64(values.fileSize ?? 0)))
    }
    if let enumerationFailure {
      throw EPUBZipError.operationFailed(
        CoreStrings.readSourceItemFailed(
          enumerationFailure.url.path,
          enumerationFailure.error.localizedDescription
        ).localized
      )
    }
    return files
  }

  fileprivate func validateSourceDirectory(_ files: [SourceFile]) throws {
    var byName: [String: SourceFile] = [:]
    var pathRegistry = ArchivePathRegistry()
    for file in files {
      do {
        try pathRegistry.insert(path: file.path, isDirectory: false)
      } catch let problem as ArchivePathProblem {
        throw EPUBZipError.invalidEPUB(problem.localizedDescription)
      }
      guard byName[file.path] == nil else {
        throw EPUBZipError.invalidEPUB(CoreStrings.duplicateEntry(file.path).localized)
      }
      byName[file.path] = file
    }
    guard let mimetypeFile = byName["mimetype"] else {
      throw EPUBZipError.invalidEPUB(CoreStrings.missingMimetype.localized)
    }
    let expectedMimetype = Data(EPUBInspector.mediaType.utf8)
    guard mimetypeFile.size == expectedMimetype.count,
      try Data(contentsOf: mimetypeFile.url) == expectedMimetype
    else {
      throw EPUBZipError.invalidEPUB(
        CoreStrings.invalidMimetype(EPUBInspector.mediaType).localized)
    }
    guard let containerFile = byName["META-INF/container.xml"] else {
      throw EPUBZipError.invalidEPUB(CoreStrings.missingContainer.localized)
    }
    let maximumContainerBytes = 4 * 1_024 * 1_024
    guard containerFile.size <= maximumContainerBytes else {
      throw EPUBZipError.invalidEPUB(
        CoreStrings.inspectionSizeLimit(containerFile.path).localized
      )
    }
    let rootfiles: [OCFRootfile]
    do {
      rootfiles = try OCFContainer.parse(Data(contentsOf: containerFile.url))
    } catch {
      throw EPUBZipError.invalidEPUB(
        CoreStrings.parseContainerFailed(error.localizedDescription).localized
      )
    }
    for rootfile in rootfiles {
      try SafeArchivePath.validate(rootfile.fullPath)
      guard byName[rootfile.fullPath] != nil else {
        throw EPUBZipError.invalidEPUB(
          CoreStrings.missingDeclaredRootfile(rootfile.fullPath).localized
        )
      }
    }
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
      throw EPUBZipError.extractionLimit(CoreStrings.entryLimit(limits.maximumEntries).localized)
    }
    var total: UInt64 = 0
    var pathRegistry = ArchivePathRegistry()
    for entry in entries {
      try SafeArchivePath.validate(entry.path, limits: limits)
      guard entry.type != .symlink else {
        throw EPUBZipError.unsafePath(entry.path)
      }
      do {
        try pathRegistry.insert(entry)
      } catch let problem as ArchivePathProblem {
        throw EPUBZipError.invalidEPUB(problem.localizedDescription)
      }
      guard entry.uncompressedSize <= limits.maximumFileSize else {
        throw EPUBZipError.extractionLimit(CoreStrings.fileSizeLimit(entry.path).localized)
      }
      let (newTotal, overflow) = total.addingReportingOverflow(entry.uncompressedSize)
      guard !overflow, newTotal <= limits.maximumTotalSize else {
        throw EPUBZipError.extractionLimit(CoreStrings.totalSizeLimit.localized)
      }
      total = newTotal
      if entry.type == .file, entry.uncompressedSize > 0 {
        guard entry.compressedSize > 0 else {
          throw EPUBZipError.extractionLimit(
            CoreStrings.invalidCompressedSize(entry.path).localized)
        }
        let quotient = entry.uncompressedSize / entry.compressedSize
        let remainder = entry.uncompressedSize % entry.compressedSize
        if quotient > limits.maximumCompressionRatio
          || (quotient == limits.maximumCompressionRatio && remainder > 0)
        {
          throw EPUBZipError.extractionLimit(
            CoreStrings.compressionRatioLimit(entry.path).localized)
        }
      }
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
      throw EPUBZipError.operationFailed(CoreStrings.uniqueOutputFailed.localized)
    }
  }

  fileprivate func temporaryFile(beside output: URL, suffix: String) throws -> URL {
    try fileManager.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    let url = output.deletingLastPathComponent()
      .appendingPathComponent(".epubzip-\(UUID().uuidString)\(suffix)")
    guard fileManager.createFile(atPath: url.path, contents: nil) else {
      throw EPUBZipError.operationFailed(CoreStrings.temporaryFileFailed.localized)
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
    } catch {
      if !fileManager.fileExists(atPath: output.path) {
        do {
          try fileManager.moveItem(at: backup, to: output)
        } catch let restorationError {
          throw EPUBZipError.operationFailed(
            CoreStrings.restoreOutputFailed(
              backup.path,
              restorationError.localizedDescription
            ).localized
          )
        }
      }
      throw error
    }
    try? fileManager.removeItem(at: backup)
  }
}

extension URL {
  fileprivate func isContained(in directory: URL) -> Bool {
    let root = directory.canonicalizedForContainment.pathComponents
    let candidate = canonicalizedForContainment.pathComponents
    return candidate.count > root.count && Array(candidate.prefix(root.count)) == root
  }

  fileprivate func isSameOrContained(in directory: URL) -> Bool {
    let root = directory.canonicalizedForContainment.pathComponents
    let candidate = canonicalizedForContainment.pathComponents
    return candidate.count >= root.count && Array(candidate.prefix(root.count)) == root
  }

  /// Resolves aliases in the nearest existing ancestor, then restores any non-existing suffix.
  /// `URL.resolvingSymlinksInPath()` alone does not consistently canonicalize `/tmp` for a path
  /// whose final component has not been created yet.
  private var canonicalizedForContainment: URL {
    let fileManager = FileManager.default
    var ancestor = standardizedFileURL
    var suffix: [String] = []

    while !fileManager.fileExists(atPath: ancestor.path), ancestor.pathComponents.count > 1 {
      suffix.insert(ancestor.lastPathComponent, at: 0)
      ancestor.deleteLastPathComponent()
    }

    var canonical = ancestor.resolvingSymlinksInPath().standardizedFileURL
    for component in suffix {
      canonical.appendPathComponent(component)
    }
    return canonical.standardizedFileURL
  }
}

extension InspectionReport {
  fileprivate var errorSummary: String {
    issues.filter { $0.severity == .error }.map(\.message).joined(
      separator: EPUBZipLocalization.currentLanguage == .simplifiedChinese ? "；" : "; "
    )
  }
}
