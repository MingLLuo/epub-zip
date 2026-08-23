import Foundation
import ZIPFoundation

enum SafeArchivePath {
  static func validate(_ path: String, limits: ExtractionLimits = .default) throws {
    guard !path.isEmpty, !path.contains("\0"), !path.contains("\\"), !path.hasPrefix("/") else {
      throw EPUBZipError.unsafePath(path)
    }
    guard path.utf8.count <= limits.maximumPathBytes else {
      throw EPUBZipError.extractionLimit(
        CoreStrings.archivePathTooLong(path, maximum: limits.maximumPathBytes).localized
      )
    }
    let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
    guard !trimmed.isEmpty else { return }
    let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
    guard !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
      throw EPUBZipError.unsafePath(path)
    }
    guard components.allSatisfy({ $0.utf8.count <= limits.maximumPathComponentBytes }) else {
      throw EPUBZipError.extractionLimit(
        CoreStrings.archivePathComponentTooLong(
          path,
          maximum: limits.maximumPathComponentBytes
        ).localized
      )
    }
  }
}

struct ArchivePathProblem: LocalizedError {
  let code: String
  let message: String

  var errorDescription: String? { message }
}

struct ArchivePathRegistry {
  private enum Kind {
    case file
    case directory
  }

  private final class Node {
    let component: String
    let firstPath: String
    var kind: Kind?
    var declaredPath: String?
    var children: [String: Node] = [:]

    init(component: String = "", firstPath: String = "") {
      self.component = component
      self.firstPath = firstPath
    }
  }

  private let root = Node()

  mutating func insert(_ entry: Entry) throws {
    try insert(path: entry.path, isDirectory: entry.type == .directory)
  }

  mutating func insert(path: String, isDirectory: Bool) throws {
    let normalized = path.hasSuffix("/") ? String(path.dropLast()) : path
    let components = normalized.split(separator: "/").map(String.init)
    var node = root

    for (index, component) in components.enumerated() {
      let key = component.folding(
        options: [.caseInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
      )
      if let existing = node.children[key] {
        guard existing.component == component else {
          throw ArchivePathProblem(
            code: "case-collision",
            message: CoreStrings.caseCollision(existing.firstPath, path).localized
          )
        }
        node = existing
      } else {
        let child = Node(component: component, firstPath: path)
        node.children[key] = child
        node = child
      }

      if index < components.count - 1, node.kind == .file {
        throw topology(node.declaredPath ?? node.firstPath, path)
      }
    }

    let kind: Kind = isDirectory ? .directory : .file
    if let existingKind = node.kind {
      let existingPath = node.declaredPath ?? node.firstPath
      if existingKind != kind || existingPath != path {
        throw topology(existingPath, path)
      }
      throw ArchivePathProblem(
        code: "duplicate-entry",
        message: CoreStrings.duplicateEntry(path).localized
      )
    }
    if kind == .file, let descendant = node.children.values.first?.firstPath {
      throw topology(path, descendant)
    }
    node.kind = kind
    node.declaredPath = path
  }

  private func topology(_ first: String, _ second: String) -> ArchivePathProblem {
    ArchivePathProblem(
      code: "path-topology",
      message: CoreStrings.pathTopologyCollision(first, second).localized
    )
  }
}
