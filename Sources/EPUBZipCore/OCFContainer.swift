import Foundation

struct OCFRootfile: Sendable, Equatable {
  static let packageMediaType = "application/oebps-package+xml"

  let fullPath: String
  let mediaType: String
}

enum OCFContainer {
  static let namespace = "urn:oasis:names:tc:opendocument:xmlns:container"

  static func parse(_ data: Data) throws -> [OCFRootfile] {
    let delegate = ParserDelegate()
    let parser = XMLParser(data: data)
    parser.shouldProcessNamespaces = true
    parser.delegate = delegate

    guard parser.parse() else {
      throw delegate.failure ?? parser.parserError
        ?? OCFContainerError(CoreStrings.invalidContainerXML.localized)
    }
    guard delegate.sawContainer, delegate.sawRootfiles, !delegate.rootfiles.isEmpty else {
      throw OCFContainerError(CoreStrings.invalidContainerStructure.localized)
    }
    return delegate.rootfiles
  }
}

private struct OCFContainerError: LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? { message }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
  private enum Element: String {
    case container
    case rootfiles
    case rootfile
  }

  var rootfiles: [OCFRootfile] = []
  var failure: Error?
  var sawContainer = false
  var sawRootfiles = false

  private var stack: [Element] = []
  private var ignoredForeignDepth = 0
  private var ignoredLinksDepth = 0
  private var sawLinks = false

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName _: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    guard failure == nil else { return }

    if ignoredLinksDepth > 0 {
      ignoredLinksDepth += 1
      return
    }
    if ignoredForeignDepth > 0 {
      ignoredForeignDepth += 1
      return
    }
    guard namespaceURI == OCFContainer.namespace else {
      ignoredForeignDepth = 1
      return
    }

    switch stack {
    case []:
      guard elementName == Element.container.rawValue, !sawContainer else {
        fail(parser, CoreStrings.invalidContainerRoot.localized)
        return
      }
      guard attributeDict["version"] == "1.0" else {
        fail(parser, CoreStrings.invalidContainerVersion.localized)
        return
      }
      sawContainer = true
      stack.append(.container)

    case [.container]:
      if elementName == Element.rootfiles.rawValue {
        guard !sawRootfiles, !sawLinks else {
          fail(parser, CoreStrings.invalidContainerStructure.localized)
          return
        }
        sawRootfiles = true
        stack.append(.rootfiles)
      } else if elementName == "links" {
        guard sawRootfiles, !sawLinks else {
          fail(parser, CoreStrings.invalidContainerStructure.localized)
          return
        }
        sawLinks = true
        ignoredLinksDepth = 1
      } else {
        fail(parser, CoreStrings.invalidContainerElement(elementName).localized)
      }

    case [.container, .rootfiles]:
      guard elementName == Element.rootfile.rawValue else {
        fail(parser, CoreStrings.invalidContainerElement(elementName).localized)
        return
      }
      guard let fullPath = attributeDict["full-path"], !fullPath.isEmpty else {
        fail(parser, CoreStrings.invalidRootfileDeclaration("full-path").localized)
        return
      }
      guard attributeDict["media-type"] == OCFRootfile.packageMediaType else {
        fail(parser, CoreStrings.invalidRootfileMediaType(fullPath).localized)
        return
      }
      rootfiles.append(
        OCFRootfile(fullPath: fullPath, mediaType: OCFRootfile.packageMediaType)
      )
      stack.append(.rootfile)

    default:
      fail(parser, CoreStrings.invalidContainerElement(elementName).localized)
    }
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName _: String?
  ) {
    guard failure == nil else { return }
    if ignoredLinksDepth > 0 {
      ignoredLinksDepth -= 1
      return
    }
    if ignoredForeignDepth > 0 {
      ignoredForeignDepth -= 1
      return
    }
    guard namespaceURI == OCFContainer.namespace,
      let expected = stack.last,
      expected.rawValue == elementName
    else {
      fail(parser, CoreStrings.invalidContainerStructure.localized)
      return
    }
    stack.removeLast()
  }

  func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    if failure == nil { failure = parseError }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    guard ignoredLinksDepth == 0, ignoredForeignDepth == 0, stack.last == .rootfile else {
      return
    }
    guard string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      fail(parser, CoreStrings.invalidContainerStructure.localized)
      return
    }
  }

  func parserDidEndDocument(_ parser: XMLParser) {
    guard stack.isEmpty else {
      fail(parser, CoreStrings.invalidContainerStructure.localized)
      return
    }
  }

  private func fail(_ parser: XMLParser, _ message: String) {
    failure = OCFContainerError(message)
    parser.abortParsing()
  }
}
