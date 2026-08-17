import EPUBZipCore
import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

@main
enum EPUBZipCLI {
  static func main() {
    exit(Int32(run(Array(CommandLine.arguments.dropFirst()))))
  }

  static func run(_ arguments: [String]) -> Int {
    guard let first = arguments.first else {
      printUsage(to: .standardError)
      return 2
    }
    if ["help", "--help", "-h"].contains(first) {
      printUsage(to: .standardOutput)
      return 0
    }
    if ["version", "--version"].contains(first) {
      print("epubzip \(EPUBZipCoreVersion.current)")
      return 0
    }

    do {
      switch first {
      case "pack":
        try pack(Array(arguments.dropFirst()))
      case "unpack":
        try unpack(Array(arguments.dropFirst()))
      case "check":
        return try check(Array(arguments.dropFirst()))
      case "auto":
        try auto(Array(arguments.dropFirst()))
      default:
        try auto(arguments)
      }
      return 0
    } catch {
      write("epubzip: \(error.localizedDescription)\n", to: .standardError)
      return 2
    }
  }

  private static func pack(_ arguments: [String]) throws {
    var parser = Options(arguments)
    let output = try parser.value(for: ["-o", "--output"])
    let force = parser.flag("--force")
    let input = try parser.singlePath(usage: "epubzip pack [-o output.epub] [--force] <directory>")
    let service = EPUBService()
    let result = try service.pack(
      directory: fileURL(input),
      to: output.map(fileURL),
      conflictPolicy: force ? .replace : .fail
    )
    print(localized("Created \(result.outputURL.path)", "已创建 \(result.outputURL.path)"))
  }

  private static func unpack(_ arguments: [String]) throws {
    var parser = Options(arguments)
    let output = try parser.value(for: ["-o", "--output"])
    let force = parser.flag("--force")
    let package = parser.flag("--package")
    let input = try parser.singlePath(
      usage: "epubzip unpack [-o directory] [--package] [--force] <book.epub>")
    let service = EPUBService()
    let inputURL = fileURL(input)
    let destination =
      output.map(fileURL) ?? service.defaultUnpackedURL(for: inputURL, packageDirectory: package)
    let result = try service.unpack(
      epub: inputURL,
      to: destination,
      conflictPolicy: force ? .replace : .fail
    )
    print(localized("Extracted \(result.outputURL.path)", "已解包 \(result.outputURL.path)"))
  }

  private static func check(_ arguments: [String]) throws -> Int {
    var parser = Options(arguments)
    let json = parser.flag("--json")
    let input = try parser.singlePath(usage: "epubzip check [--json] <book.epub>")
    let report = try EPUBService().inspect(fileURL(input))
    if json {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      FileHandle.standardOutput.write(try encoder.encode(report))
      write("\n", to: .standardOutput)
    } else {
      let status =
        report.isValid ? localized("Valid", "有效") : localized("Invalid", "无效")
      print(
        localized(
          "\(status): \(report.path) (\(report.entryCount) entries)",
          "\(status)：\(report.path)（\(report.entryCount) 个条目）"
        )
      )
      for issue in report.issues {
        print("- \(issue.severity.rawValue) [\(issue.code)]: \(issue.message)")
      }
      if !report.rootfiles.isEmpty {
        print("rootfiles: \(report.rootfiles.joined(separator: ", "))")
      }
    }
    return report.isValid ? 0 : 1
  }

  private static func auto(_ arguments: [String]) throws {
    var parser = Options(arguments)
    let force = parser.flag("--force")
    let package = parser.flag("--package")
    let paths = try parser.paths(usage: "epubzip auto [--package] [--force] <path>...")
    let service = EPUBService()
    for path in paths {
      let result = try service.process(
        fileURL(path),
        packageDirectory: package,
        conflictPolicy: force ? .replace : .fail
      )
      print(
        result.kind == .pack
          ? localized("Created \(result.outputURL.path)", "已创建 \(result.outputURL.path)")
          : localized("Extracted \(result.outputURL.path)", "已解包 \(result.outputURL.path)")
      )
    }
  }

  private static func fileURL(_ path: String) -> URL {
    URL(
      fileURLWithPath: path,
      relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    )
    .standardizedFileURL
  }

  private static func printUsage(to handle: FileHandle) {
    let english = """
      epubzip — Native EPUB packing, extraction, and container validation

      Usage:
        epubzip pack [-o output.epub] [--force] <directory>
        epubzip unpack [-o directory] [--package] [--force] <book.epub>
        epubzip check [--json] <book.epub>
        epubzip auto [--package] [--force] <path>...
        epubzip <path>...

      Without a subcommand, folders are packed and .epub files are extracted.
      """
    let chinese = """
      epubzip — 原生 EPUB 打包、解包与容器检查工具

      用法：
        epubzip pack [-o output.epub] [--force] <directory>
        epubzip unpack [-o directory] [--package] [--force] <book.epub>
        epubzip check [--json] <book.epub>
        epubzip auto [--package] [--force] <path>...
        epubzip <path>...

      未指定子命令时，目录会被打包，.epub 文件会被解包。
      """
    write(localized(english, chinese) + "\n", to: handle)
  }

  private static func localized(_ english: String, _ chinese: String) -> String {
    EPUBZipLocalization.text(english, zhHans: chinese)
  }

  private static func write(_ string: String, to handle: FileHandle) {
    handle.write(Data(string.utf8))
  }
}

private struct Options {
  private var arguments: [String]

  init(_ arguments: [String]) {
    self.arguments = arguments
  }

  mutating func flag(_ name: String) -> Bool {
    guard let index = arguments.firstIndex(of: name) else { return false }
    arguments.remove(at: index)
    return true
  }

  mutating func value(for names: [String]) throws -> String? {
    for name in names {
      guard let index = arguments.firstIndex(of: name) else { continue }
      guard arguments.indices.contains(index + 1) else {
        throw EPUBZipError.operationFailed(
          EPUBZipLocalization.text(
            "\(name) requires a value", zhHans: "\(name) 缺少参数")
        )
      }
      arguments.remove(at: index)
      return arguments.remove(at: index)
    }
    return nil
  }

  mutating func singlePath(usage: String) throws -> String {
    guard arguments.count == 1, let path = arguments.first, !path.hasPrefix("-") else {
      throw EPUBZipError.operationFailed(usage)
    }
    return path
  }

  mutating func paths(usage: String) throws -> [String] {
    guard !arguments.isEmpty, !arguments.contains(where: { $0.hasPrefix("-") }) else {
      throw EPUBZipError.operationFailed(usage)
    }
    return arguments
  }
}
