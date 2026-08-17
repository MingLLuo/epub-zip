import Foundation

public enum EPUBZipCoreVersion {
  public static let current = "0.3.0"
}

public struct ExtractionLimits: Sendable, Equatable {
  public var maximumEntries: Int
  public var maximumFileSize: UInt64
  public var maximumTotalSize: UInt64
  public var maximumCompressionRatio: UInt64

  public init(
    maximumEntries: Int = 20_000,
    maximumFileSize: UInt64 = 512 * 1_024 * 1_024,
    maximumTotalSize: UInt64 = 2 * 1_024 * 1_024 * 1_024,
    maximumCompressionRatio: UInt64 = 1_000
  ) {
    self.maximumEntries = maximumEntries
    self.maximumFileSize = maximumFileSize
    self.maximumTotalSize = maximumTotalSize
    self.maximumCompressionRatio = maximumCompressionRatio
  }

  public static let `default` = ExtractionLimits()
}

public enum ConflictPolicy: Sendable {
  case fail
  case replace
  case uniquify
}

public enum OperationKind: String, Codable, Sendable {
  case pack
  case unpack
}

public struct OperationResult: Sendable {
  public let kind: OperationKind
  public let inputURL: URL
  public let outputURL: URL
  public let report: InspectionReport

  public init(kind: OperationKind, inputURL: URL, outputURL: URL, report: InspectionReport) {
    self.kind = kind
    self.inputURL = inputURL
    self.outputURL = outputURL
    self.report = report
  }
}

public struct InspectionReport: Codable, Sendable {
  public let path: String
  public let entryCount: Int
  public let rootfiles: [String]
  public let issues: [InspectionIssue]

  public var isValid: Bool {
    !issues.contains { $0.severity == .error }
  }

  public init(path: String, entryCount: Int, rootfiles: [String], issues: [InspectionIssue]) {
    self.path = path
    self.entryCount = entryCount
    self.rootfiles = rootfiles
    self.issues = issues
  }
}

public struct InspectionIssue: Codable, Sendable, Equatable {
  public enum Severity: String, Codable, Sendable {
    case warning
    case error
  }

  public let severity: Severity
  public let code: String
  public let message: String

  public init(severity: Severity, code: String, message: String) {
    self.severity = severity
    self.code = code
    self.message = message
  }
}

public enum EPUBZipError: LocalizedError, Sendable {
  case invalidEPUB(String)
  case unsupportedInput(URL)
  case outputExists(URL)
  case unsafePath(String)
  case extractionLimit(String)
  case operationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .invalidEPUB(let message):
      CoreStrings.invalidEPUB(message).localized
    case .unsupportedInput(let url):
      CoreStrings.unsupportedInput(url.lastPathComponent).localized
    case .outputExists(let url):
      CoreStrings.outputExists(url.path).localized
    case .unsafePath(let path):
      CoreStrings.unsafeArchivePath(path).localized
    case .extractionLimit(let message):
      CoreStrings.extractionStopped(message).localized
    case .operationFailed(let message):
      message
    }
  }
}
