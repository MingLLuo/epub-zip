import Foundation
import ZIPFoundation

public struct EPUBInspector: Sendable {
  public static let mediaType = "application/epub+zip"

  public init() {}

  public func inspect(_ url: URL) throws -> InspectionReport {
    let archive: Archive
    do {
      archive = try Archive(url: url, accessMode: .read)
    } catch {
      throw EPUBZipError.invalidEPUB(
        CoreStrings.readZIPFailed(error.localizedDescription).localized)
    }

    let entries = Array(archive)
    var issues: [InspectionIssue] = []
    var rootfiles: [String] = []

    func add(_ severity: InspectionIssue.Severity, _ code: String, _ message: String) {
      issues.append(.init(severity: severity, code: code, message: message))
    }

    if entries.isEmpty {
      add(.error, "empty", CoreStrings.emptyZIP.localized)
      return InspectionReport(path: url.path, entryCount: 0, rootfiles: [], issues: issues)
    }

    do {
      let first = try ZIPStructure.firstLocalHeader(at: url)
      if first.name != "mimetype" {
        add(.error, "mimetype-order", CoreStrings.mimetypeOrder.localized)
      }
      if first.compressionMethod != 0 {
        add(.error, "mimetype-compression", CoreStrings.mimetypeStored.localized)
      }
      if first.extraFieldLength != 0 {
        add(.error, "mimetype-extra", CoreStrings.mimetypeExtraField.localized)
      }
    } catch {
      add(
        .error, "zip-header",
        CoreStrings.firstZIPHeaderFailed(error.localizedDescription).localized)
    }

    if let declaredCount = try ZIPStructure.classicEntryCount(at: url),
      declaredCount != entries.count
    {
      add(
        .error,
        "entry-count",
        CoreStrings.entryCountMismatch(declared: declaredCount, readable: entries.count).localized
      )
    }

    var byName: [String: Entry] = [:]
    var foldedNames: [String: String] = [:]
    for entry in entries {
      do {
        try SafeArchivePath.validate(entry.path)
      } catch {
        add(.error, "unsafe-path", "\(entry.path)：\(error.localizedDescription)")
      }
      if byName[entry.path] != nil {
        add(.error, "duplicate-entry", CoreStrings.duplicateEntry(entry.path).localized)
      } else {
        byName[entry.path] = entry
      }
      let folded = entry.path.folding(
        options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      if let previous = foldedNames[folded], previous != entry.path {
        add(.error, "case-collision", CoreStrings.caseCollision(previous, entry.path).localized)
      } else {
        foldedNames[folded] = entry.path
      }
      if entry.type == .symlink {
        add(.error, "symlink", CoreStrings.symlinkEntry(entry.path).localized)
      }
    }

    guard let mimetype = byName["mimetype"] else {
      add(.error, "mimetype-missing", CoreStrings.missingMimetype.localized)
      return InspectionReport(
        path: url.path,
        entryCount: entries.count,
        rootfiles: rootfiles,
        issues: issues
      )
    }
    if mimetype.type != .file || mimetype.isCompressed {
      add(.error, "mimetype-compression", CoreStrings.mimetypeRegularFile.localized)
    }
    do {
      let data = try read(mimetype, from: archive, maximumBytes: 128)
      if String(data: data, encoding: .ascii) != Self.mediaType {
        add(.error, "mimetype-content", CoreStrings.invalidMimetype(Self.mediaType).localized)
      }
    } catch {
      add(.error, "mimetype-read", error.localizedDescription)
    }

    guard let container = byName["META-INF/container.xml"] else {
      add(.error, "container-missing", CoreStrings.missingContainer.localized)
      return InspectionReport(
        path: url.path,
        entryCount: entries.count,
        rootfiles: rootfiles,
        issues: issues
      )
    }
    do {
      let data = try read(container, from: archive, maximumBytes: 4 * 1_024 * 1_024)
      let parsed = try ContainerXML.parse(data)
      rootfiles = parsed.map(\.fullPath)
      if parsed.isEmpty {
        add(.error, "rootfile-missing", CoreStrings.missingRootfileDeclaration.localized)
      }
      for rootfile in parsed {
        do {
          try SafeArchivePath.validate(rootfile.fullPath)
        } catch {
          add(.error, "rootfile-path", CoreStrings.unsafeRootfile(rootfile.fullPath).localized)
          continue
        }
        if byName[rootfile.fullPath] == nil {
          add(
            .error, "rootfile-not-found",
            CoreStrings.missingDeclaredRootfile(rootfile.fullPath).localized)
        }
        if !rootfile.mediaType.isEmpty,
          rootfile.mediaType != "application/oebps-package+xml"
        {
          add(
            .warning, "rootfile-media-type",
            CoreStrings.nonstandardRootfileMediaType(rootfile.fullPath).localized)
        }
      }
    } catch {
      add(
        .error, "container-xml",
        CoreStrings.parseContainerFailed(error.localizedDescription).localized)
    }

    return InspectionReport(
      path: url.path,
      entryCount: entries.count,
      rootfiles: rootfiles,
      issues: issues
    )
  }

  private func read(_ entry: Entry, from archive: Archive, maximumBytes: Int) throws -> Data {
    guard entry.uncompressedSize <= UInt64(maximumBytes) else {
      throw EPUBZipError.invalidEPUB(CoreStrings.inspectionSizeLimit(entry.path).localized)
    }
    var result = Data()
    _ = try archive.extract(entry) { chunk in
      guard result.count + chunk.count <= maximumBytes else {
        throw EPUBZipError.invalidEPUB(CoreStrings.inspectionSizeLimit(entry.path).localized)
      }
      result.append(chunk)
    }
    return result
  }
}

private enum ZIPStructure {
  struct LocalHeader {
    let name: String
    let compressionMethod: UInt16
    let extraFieldLength: UInt16
  }

  static func firstLocalHeader(at url: URL) throws -> LocalHeader {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    guard let header = try handle.read(upToCount: 30), header.count == 30 else {
      throw EPUBZipError.invalidEPUB(CoreStrings.incompleteZIPHeader.localized)
    }
    guard header.littleEndianUInt32(at: 0) == 0x0403_4B50 else {
      throw EPUBZipError.invalidEPUB(CoreStrings.missingZIPHeader.localized)
    }
    let method = header.littleEndianUInt16(at: 8)
    let nameLength = Int(header.littleEndianUInt16(at: 26))
    let extraLength = header.littleEndianUInt16(at: 28)
    guard let nameData = try handle.read(upToCount: nameLength), nameData.count == nameLength,
      let name = String(data: nameData, encoding: .utf8)
    else {
      throw EPUBZipError.invalidEPUB(CoreStrings.invalidFirstEntryName.localized)
    }
    return LocalHeader(name: name, compressionMethod: method, extraFieldLength: extraLength)
  }

  static func classicEntryCount(at url: URL) throws -> Int? {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let size = try handle.seekToEnd()
    let tailSize = min(size, 65_557)
    try handle.seek(toOffset: size - tailSize)
    guard let tail = try handle.read(upToCount: Int(tailSize)) else { return nil }
    guard tail.count >= 22 else { return nil }
    for offset in stride(from: tail.count - 22, through: 0, by: -1) {
      if tail.littleEndianUInt32(at: offset) == 0x0605_4B50 {
        let count = tail.littleEndianUInt16(at: offset + 10)
        return count == .max ? nil : Int(count)
      }
    }
    return nil
  }
}

enum SafeArchivePath {
  static func validate(_ path: String) throws {
    guard !path.isEmpty, !path.contains("\0"), !path.contains("\\"), !path.hasPrefix("/") else {
      throw EPUBZipError.unsafePath(path)
    }
    let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
    guard !trimmed.isEmpty else { return }
    let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
    guard !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
      throw EPUBZipError.unsafePath(path)
    }
  }
}

private struct Rootfile {
  let fullPath: String
  let mediaType: String
}

private final class ContainerXML: NSObject, XMLParserDelegate {
  private var rootfiles: [Rootfile] = []
  private var parseError: Error?

  static func parse(_ data: Data) throws -> [Rootfile] {
    let delegate = ContainerXML()
    let parser = XMLParser(data: data)
    parser.shouldProcessNamespaces = true
    parser.delegate = delegate
    guard parser.parse() else {
      throw delegate.parseError ?? parser.parserError
        ?? EPUBZipError.invalidEPUB(CoreStrings.unknownXMLError.localized)
    }
    return delegate.rootfiles
  }

  func parser(
    _: XMLParser,
    didStartElement elementName: String,
    namespaceURI _: String?,
    qualifiedName _: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    guard elementName == "rootfile", let fullPath = attributeDict["full-path"] else { return }
    rootfiles.append(.init(fullPath: fullPath, mediaType: attributeDict["media-type"] ?? ""))
  }

  func parser(_: XMLParser, parseErrorOccurred parseError: Error) {
    self.parseError = parseError
  }
}

extension Data {
  fileprivate func littleEndianUInt16(at offset: Int) -> UInt16 {
    UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
  }

  fileprivate func littleEndianUInt32(at offset: Int) -> UInt32 {
    UInt32(self[offset])
      | UInt32(self[offset + 1]) << 8
      | UInt32(self[offset + 2]) << 16
      | UInt32(self[offset + 3]) << 24
  }
}
