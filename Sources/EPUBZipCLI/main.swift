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
      print(CLIStrings.version(EPUBZipCoreVersion.current))
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
      write(CLIStrings.error(error.localizedDescription) + "\n", to: .standardError)
      return 2
    }
  }

  private static func pack(_ arguments: [String]) throws {
    var parser = Options(arguments)
    let output = try parser.value(for: ["-o", "--output"])
    let force = try parser.flag("--force")
    let input = try parser.singlePath(usage: CLIStrings.packUsage)
    let service = EPUBService()
    let result = try service.pack(
      directory: fileURL(input),
      to: output.map(fileURL),
      conflictPolicy: force ? .replace : .fail
    )
    print(CLIStrings.created(result.outputURL.path).localized)
  }

  private static func unpack(_ arguments: [String]) throws {
    var parser = Options(arguments)
    let output = try parser.value(for: ["-o", "--output"])
    let force = try parser.flag("--force")
    let package = try parser.flag("--package")
    let input = try parser.singlePath(usage: CLIStrings.unpackUsage)
    let service = EPUBService()
    let inputURL = fileURL(input)
    let destination =
      output.map(fileURL) ?? service.defaultUnpackedURL(for: inputURL, packageDirectory: package)
    let result = try service.unpack(
      epub: inputURL,
      to: destination,
      conflictPolicy: force ? .replace : .fail
    )
    print(CLIStrings.extracted(result.outputURL.path).localized)
  }

  private static func check(_ arguments: [String]) throws -> Int {
    var parser = Options(arguments)
    let json = try parser.flag("--json")
    let input = try parser.singlePath(usage: CLIStrings.checkUsage)
    let report = try EPUBService().inspect(fileURL(input))
    if json {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      FileHandle.standardOutput.write(try encoder.encode(report))
      write("\n", to: .standardOutput)
    } else {
      print(
        CLIStrings.reportSummary(
          isValid: report.isValid,
          path: report.path,
          entryCount: report.entryCount
        )
        .localized)
      for issue in report.issues {
        print(CLIStrings.inspectionIssue(issue).localized)
      }
      if !report.rootfiles.isEmpty {
        print(CLIStrings.rootfiles(report.rootfiles).localized)
      }
    }
    return report.isValid ? 0 : 1
  }

  private static func auto(_ arguments: [String]) throws {
    var parser = Options(arguments)
    let force = try parser.flag("--force")
    let package = try parser.flag("--package")
    let paths = try parser.paths(usage: CLIStrings.autoUsage)
    let service = EPUBService()
    for path in paths {
      let result = try service.process(
        fileURL(path),
        packageDirectory: package,
        conflictPolicy: force ? .replace : .fail
      )
      print(
        result.kind == .pack
          ? CLIStrings.created(result.outputURL.path).localized
          : CLIStrings.extracted(result.outputURL.path).localized
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
    write(CLIStrings.usage.localized + "\n", to: handle)
  }

  private static func write(_ string: String, to handle: FileHandle) {
    handle.write(Data(string.utf8))
  }
}
