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
      throw EPUBZipError.invalidEPUB("无法读取 ZIP 容器：\(error.localizedDescription)")
    }

    let entries = Array(archive)
    var issues: [InspectionIssue] = []
    var rootfiles: [String] = []

    func add(_ severity: InspectionIssue.Severity, _ code: String, _ message: String) {
      issues.append(.init(severity: severity, code: code, message: message))
    }

    if entries.isEmpty {
      add(.error, "empty", "ZIP 容器没有条目")
      return InspectionReport(path: url.path, entryCount: 0, rootfiles: [], issues: issues)
    }

    do {
      let first = try ZIPStructure.firstLocalHeader(at: url)
      if first.name != "mimetype" {
        add(.error, "mimetype-order", "mimetype 必须是第一个 ZIP 条目")
      }
      if first.compressionMethod != 0 {
        add(.error, "mimetype-compression", "mimetype 必须以 Store 模式保存")
      }
      if first.extraFieldLength != 0 {
        add(.error, "mimetype-extra", "mimetype 的 ZIP 头不能包含额外字段")
      }
    } catch {
      add(.error, "zip-header", "无法读取首个 ZIP 本地头：\(error.localizedDescription)")
    }

    if let declaredCount = try ZIPStructure.classicEntryCount(at: url),
      declaredCount != entries.count
    {
      add(
        .error,
        "entry-count",
        "ZIP 中央目录声明 \(declaredCount) 个条目，但只能安全读取 \(entries.count) 个"
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
        add(.error, "duplicate-entry", "ZIP 条目重复：\(entry.path)")
      } else {
        byName[entry.path] = entry
      }
      let folded = entry.path.folding(
        options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      if let previous = foldedNames[folded], previous != entry.path {
        add(.error, "case-collision", "\(previous) 与 \(entry.path) 在默认 macOS 文件系统上冲突")
      } else {
        foldedNames[folded] = entry.path
      }
      if entry.type == .symlink {
        add(.error, "symlink", "不允许符号链接条目：\(entry.path)")
      }
    }

    guard let mimetype = byName["mimetype"] else {
      add(.error, "mimetype-missing", "根目录缺少 mimetype")
      return InspectionReport(
        path: url.path,
        entryCount: entries.count,
        rootfiles: rootfiles,
        issues: issues
      )
    }
    if mimetype.type != .file || mimetype.isCompressed {
      add(.error, "mimetype-compression", "mimetype 必须是不压缩的普通文件")
    }
    do {
      let data = try read(mimetype, from: archive, maximumBytes: 128)
      if String(data: data, encoding: .ascii) != Self.mediaType {
        add(.error, "mimetype-content", "mimetype 内容必须精确为 \(Self.mediaType)，且不能换行")
      }
    } catch {
      add(.error, "mimetype-read", error.localizedDescription)
    }

    guard let container = byName["META-INF/container.xml"] else {
      add(.error, "container-missing", "缺少 META-INF/container.xml")
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
        add(.error, "rootfile-missing", "container.xml 没有声明 OPF rootfile")
      }
      for rootfile in parsed {
        do {
          try SafeArchivePath.validate(rootfile.fullPath)
        } catch {
          add(.error, "rootfile-path", "rootfile 路径不安全：\(rootfile.fullPath)")
          continue
        }
        if byName[rootfile.fullPath] == nil {
          add(.error, "rootfile-not-found", "找不到 container.xml 声明的 \(rootfile.fullPath)")
        }
        if !rootfile.mediaType.isEmpty,
          rootfile.mediaType != "application/oebps-package+xml"
        {
          add(.warning, "rootfile-media-type", "\(rootfile.fullPath) 使用了非标准 media-type")
        }
      }
    } catch {
      add(.error, "container-xml", "container.xml 无法解析：\(error.localizedDescription)")
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
      throw EPUBZipError.invalidEPUB("\(entry.path) 超过检查大小限制")
    }
    var result = Data()
    _ = try archive.extract(entry) { chunk in
      guard result.count + chunk.count <= maximumBytes else {
        throw EPUBZipError.invalidEPUB("\(entry.path) 超过检查大小限制")
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
      throw EPUBZipError.invalidEPUB("ZIP 本地头不完整")
    }
    guard header.littleEndianUInt32(at: 0) == 0x0403_4B50 else {
      throw EPUBZipError.invalidEPUB("文件没有以 ZIP 本地头开始")
    }
    let method = header.littleEndianUInt16(at: 8)
    let nameLength = Int(header.littleEndianUInt16(at: 26))
    let extraLength = header.littleEndianUInt16(at: 28)
    guard let nameData = try handle.read(upToCount: nameLength), nameData.count == nameLength,
      let name = String(data: nameData, encoding: .utf8)
    else {
      throw EPUBZipError.invalidEPUB("首个 ZIP 条目名称无效")
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
      throw delegate.parseError ?? parser.parserError ?? EPUBZipError.invalidEPUB("未知 XML 错误")
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
