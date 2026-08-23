import EPUBZipCore
import Foundation

enum CLIArgumentError: LocalizedError, Sendable, Equatable {
  case missingOptionValue(String)
  case duplicateOption(String)
  case unknownOption(String)
  case invalidArguments(LocalizedMessage)

  var errorDescription: String? {
    switch self {
    case .missingOptionValue(let name):
      CLIStrings.missingOptionValue(name).localized
    case .duplicateOption(let displayName):
      CLIStrings.duplicateOption(displayName).localized
    case .unknownOption(let name):
      CLIStrings.unknownOption(name).localized
    case .invalidArguments(let usage):
      usage.localized
    }
  }
}

/// Consumes command options while preserving operands exactly as supplied.
///
/// Known options may appear before or after ordinary operands. The first `--`
/// ends option parsing, so subsequent values (including names such as `--force`)
/// are always treated as paths.
struct Options {
  private var arguments: [String]

  init(_ arguments: [String]) {
    self.arguments = arguments
  }

  mutating func flag(_ name: String) throws -> Bool {
    let matches = optionIndices { $0 == name }
    guard matches.count <= 1 else {
      throw CLIArgumentError.duplicateOption(name)
    }
    guard let index = matches.first else { return false }
    arguments.remove(at: index)
    return true
  }

  mutating func value(for names: [String]) throws -> String? {
    precondition(!names.isEmpty)
    let matches = optionIndices { names.contains($0) }
    let displayName = names.joined(separator: "/")
    guard matches.count <= 1 else {
      throw CLIArgumentError.duplicateOption(displayName)
    }
    guard let index = matches.first else { return nil }

    let optionName = arguments[index]
    let optionBoundary = arguments.firstIndex(of: "--") ?? arguments.endIndex
    let valueIndex = arguments.index(after: index)
    guard valueIndex < optionBoundary, !arguments[valueIndex].hasPrefix("-") else {
      throw CLIArgumentError.missingOptionValue(optionName)
    }

    let value = arguments[valueIndex]
    arguments.removeSubrange(index...valueIndex)
    return value
  }

  mutating func singlePath(usage: LocalizedMessage) throws -> String {
    let operands = try consumeOperands()
    guard operands.count == 1, let path = operands.first, !path.isEmpty else {
      throw CLIArgumentError.invalidArguments(usage)
    }
    return path
  }

  mutating func paths(usage: LocalizedMessage) throws -> [String] {
    let operands = try consumeOperands()
    guard !operands.isEmpty, !operands.contains(where: \.isEmpty) else {
      throw CLIArgumentError.invalidArguments(usage)
    }
    return operands
  }

  private func optionIndices(where predicate: (String) -> Bool) -> [Int] {
    let optionBoundary = arguments.firstIndex(of: "--") ?? arguments.endIndex
    return arguments[..<optionBoundary].indices.filter { predicate(arguments[$0]) }
  }

  private mutating func consumeOperands() throws -> [String] {
    let optionBoundary = arguments.firstIndex(of: "--") ?? arguments.endIndex
    let optionsAndOperands = arguments[..<optionBoundary]
    if let unknownOption = optionsAndOperands.first(where: { $0.hasPrefix("-") }) {
      throw CLIArgumentError.unknownOption(unknownOption)
    }

    var operands = Array(optionsAndOperands)
    if optionBoundary < arguments.endIndex {
      operands.append(contentsOf: arguments[arguments.index(after: optionBoundary)...])
    }
    arguments.removeAll(keepingCapacity: false)
    return operands
  }
}
