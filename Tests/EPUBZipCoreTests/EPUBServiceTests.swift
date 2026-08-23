import Foundation
import Testing
import ZIPFoundation

@testable import EPUBZipCore

@Suite(.serialized)
struct EPUBServiceTests {
  @Test
  func localizationDetectionAndResolution() {
    #expect(
      EPUBZipLocalization.detectLanguage(
        override: "en", preferredLanguages: ["zh-Hans"]
      ) == .english
    )
    #expect(
      EPUBZipLocalization.detectLanguage(
        override: "zh-CN", preferredLanguages: ["en-US"]
      ) == .simplifiedChinese
    )
    #expect(
      EPUBZipLocalization.detectLanguage(
        override: nil, preferredLanguages: ["ja-JP", "zh-Hans"]
      ) == .simplifiedChinese
    )
    #expect(
      EPUBZipLocalization.detectLanguage(
        override: nil, preferredLanguages: ["zh-Hant", "en-US"]
      ) == .english
    )
    #expect(
      EPUBZipLocalization.detectLanguage(
        override: "zh-TW", preferredLanguages: ["zh-Hans"]
      ) == .english
    )
    #expect(
      EPUBZipLocalization.detectLanguage(
        override: "unsupported", preferredLanguages: ["zh-Hans"]
      ) == .english
    )

    let message = CoreStrings.outputExtension
    #expect(message.resolved(for: .english).contains(".epub extension"))
    #expect(message.resolved(for: .simplifiedChinese).contains(".epub 扩展名"))
  }

  @Test
  func packInspectAndUnpackRoundTrip() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("source"))
    let epub = workspace.url.appendingPathComponent("book.epub")
    let service = EPUBService()

    let packed = try service.pack(directory: source, to: epub)
    #expect(packed.report.isValid)
    #expect(packed.report.rootfiles == ["EPUB/book.opf"])

    let firstHeader = try Data(contentsOf: epub, options: .mappedIfSafe)
    #expect(String(data: firstHeader.subdata(in: 30..<38), encoding: .utf8) == "mimetype")
    #expect(firstHeader[8] == 0 && firstHeader[9] == 0)
    #expect(firstHeader[28] == 0 && firstHeader[29] == 0)

    let output = workspace.url.appendingPathComponent("unpacked", isDirectory: true)
    let unpacked = try service.unpack(epub: epub, to: output)
    #expect(unpacked.kind == .unpack)
    #expect(
      try String(contentsOf: output.appendingPathComponent("EPUB/chapter.xhtml"), encoding: .utf8)
        == "<html/>")
    let attributes = try FileManager.default.attributesOfItem(
      atPath: output.appendingPathComponent("EPUB/chapter.xhtml").path
    )
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o644)
  }

  @Test
  func packingIsReproducible() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("source"))
    let first = workspace.url.appendingPathComponent("first.epub")
    let second = workspace.url.appendingPathComponent("second.epub")
    let service = EPUBService()
    _ = try service.pack(directory: source, to: first)
    _ = try service.pack(directory: source, to: second)
    #expect(try Data(contentsOf: first) == Data(contentsOf: second))
  }

  @Test
  func rejectsMimetypeWithNewline() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("source"))
    try Data((EPUBInspector.mediaType + "\n").utf8).write(
      to: source.appendingPathComponent("mimetype"))
    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().pack(
        directory: source,
        to: workspace.url.appendingPathComponent("bad.epub")
      )
    }
  }

  @Test
  func rejectsTraversalBeforeWriting() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let archiveURL = workspace.url.appendingPathComponent("evil.epub")
    try createArchive(
      at: archiveURL,
      entries: [
        ("mimetype", EPUBInspector.mediaType, .none),
        ("../escaped", "owned", .deflate),
      ]
    )

    let output = workspace.url.appendingPathComponent("output", isDirectory: true)
    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().unpack(epub: archiveURL, to: output)
    }
    #expect(
      !FileManager.default.fileExists(atPath: workspace.url.appendingPathComponent("escaped").path))
    #expect(!FileManager.default.fileExists(atPath: output.path))
  }

  @Test
  func rejectsSymlinkEntries() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let archiveURL = workspace.url.appendingPathComponent("link.epub")
    do {
      let archive = try Archive(url: archiveURL, accessMode: .create)
      let data = Data("target".utf8)
      try archive.addEntry(with: "link", type: .symlink, uncompressedSize: Int64(data.count)) {
        position, size in
        let start = Int(position)
        return data.subdata(in: start..<min(start + size, data.count))
      }
    }
    let report = try EPUBService().inspect(archiveURL)
    #expect(!report.isValid)
    #expect(report.issues.contains { $0.code == "symlink" })
  }

  @Test
  func failedReplacementPreservesExistingOutput() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let output = workspace.url.appendingPathComponent("book.epub")
    try Data("old".utf8).write(to: output)
    let invalidSource = workspace.url.appendingPathComponent("invalid-source")
    try FileManager.default.createDirectory(at: invalidSource, withIntermediateDirectories: true)

    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().pack(
        directory: invalidSource,
        to: output,
        conflictPolicy: .replace
      )
    }
    #expect(try String(contentsOf: output, encoding: .utf8) == "old")
  }

  @Test
  func uniquifiesWithoutOverwriting() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("source"))
    let output = workspace.url.appendingPathComponent("book.epub")
    try Data("existing".utf8).write(to: output)
    let result = try EPUBService().pack(
      directory: source,
      to: output,
      conflictPolicy: .uniquify
    )
    #expect(result.outputURL.lastPathComponent == "book 2.epub")
    #expect(try String(contentsOf: output, encoding: .utf8) == "existing")
  }

  @Test
  func packNeverReplacesItsSourceDirectory() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("package.epub"))

    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().pack(
        directory: source,
        to: source,
        conflictPolicy: .replace
      )
    }
    #expect(try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
    #expect(
      try String(contentsOf: source.appendingPathComponent("EPUB/chapter.xhtml"), encoding: .utf8)
        == "<html/>"
    )
  }

  @Test
  func containmentRecognizesEquivalentTmpAliases() throws {
    let name = "epubzip-alias-tests-\(UUID().uuidString)"
    let publicRoot = URL(fileURLWithPath: "/tmp").appendingPathComponent(name)
    let canonicalRoot = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(name)
    defer { try? FileManager.default.removeItem(at: canonicalRoot) }
    let source = try validSource(at: publicRoot.appendingPathComponent("source"))
    let output = canonicalRoot.appendingPathComponent("source/inside.epub")

    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().pack(directory: source, to: output)
    }
    #expect(!FileManager.default.fileExists(atPath: output.path))
  }

  @Test
  func unpackNeverReplacesADirectoryContainingItsInput() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("source"))
    let containingDirectory = workspace.url.appendingPathComponent("incoming", isDirectory: true)
    try FileManager.default.createDirectory(
      at: containingDirectory,
      withIntermediateDirectories: true
    )
    let epub = containingDirectory.appendingPathComponent("book.epub")
    _ = try EPUBService().pack(directory: source, to: epub)

    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().unpack(
        epub: epub,
        to: containingDirectory,
        conflictPolicy: .replace
      )
    }
    #expect(FileManager.default.fileExists(atPath: epub.path))
    #expect(try EPUBService().inspect(epub).isValid)
  }

  @Test
  func inspectionStopsAtTheConfiguredEntryLimit() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("source"))
    let epub = workspace.url.appendingPathComponent("book.epub")
    _ = try EPUBService().pack(directory: source, to: epub)

    let limits = ExtractionLimits(maximumEntries: 3)
    let report = try EPUBService().inspect(epub, limits: limits)
    #expect(!report.isValid)
    #expect(report.entryCount == 4)
    #expect(report.issues.contains { $0.code == "entry-limit" })
  }

  @Test(arguments: [
    """
    <?xml version="1.0"?>
    <bogus version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="EPUB/book.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </bogus>
    """,
    """
    <?xml version="1.0"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="EPUB/book.opf"/>
      </rootfiles>
    </container>
    """,
    """
    <?xml version="1.0"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="EPUB/book.opf" media-type="text/xml"/>
      </rootfiles>
    </container>
    """,
  ])
  func rejectsNonconformingContainerDocuments(_ invalidContainer: String) throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let source = try validSource(at: workspace.url.appendingPathComponent("source"))
    try write(invalidContainer, to: source.appendingPathComponent("META-INF/container.xml"))
    let output = workspace.url.appendingPathComponent("invalid.epub")

    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().pack(directory: source, to: output)
    }
    #expect(!FileManager.default.fileExists(atPath: output.path))
  }

  @Test
  func rejectsFileDirectoryTopologyConflictsDuringInspection() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let archiveURL = workspace.url.appendingPathComponent("topology.epub")
    try createArchive(
      at: archiveURL,
      entries: [
        ("mimetype", EPUBInspector.mediaType, .none),
        ("META-INF/container.xml", containerXML, .deflate),
        ("EPUB/book.opf", "<package/>", .deflate),
        ("EPUB", "conflicting file", .deflate),
      ]
    )

    let report = try EPUBService().inspect(archiveURL)
    #expect(!report.isValid)
    #expect(report.issues.contains { $0.code == "path-topology" })

    let output = workspace.url.appendingPathComponent("output")
    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().unpack(epub: archiveURL, to: output)
    }
    #expect(!FileManager.default.fileExists(atPath: output.path))
  }

  @Test
  func rejectsPathsThatCannotBeCreatedOnTheDefaultMacOSFileSystem() throws {
    let workspace = try TestWorkspace()
    defer { workspace.remove() }
    let archiveURL = workspace.url.appendingPathComponent("long-path.epub")
    let longComponent = String(repeating: "a", count: 256)
    try createArchive(
      at: archiveURL,
      entries: [
        ("mimetype", EPUBInspector.mediaType, .none),
        ("META-INF/container.xml", containerXML, .deflate),
        ("EPUB/book.opf", "<package/>", .deflate),
        ("EPUB/\(longComponent)", "content", .deflate),
      ]
    )

    let report = try EPUBService().inspect(archiveURL)
    #expect(!report.isValid)
    #expect(report.issues.contains { $0.code == "unsafe-path" })
  }
}

private let containerXML = """
  <?xml version="1.0"?>
  <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
    <rootfiles>
      <rootfile full-path="EPUB/book.opf" media-type="application/oebps-package+xml"/>
    </rootfiles>
  </container>
  """

private final class TestWorkspace {
  let url: URL

  init() throws {
    url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "epubzip-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  func remove() {
    try? FileManager.default.removeItem(at: url)
  }
}

private func validSource(at root: URL) throws -> URL {
  try write(EPUBInspector.mediaType, to: root.appendingPathComponent("mimetype"))
  try write(containerXML, to: root.appendingPathComponent("META-INF/container.xml"))
  try write(
    #"<package xmlns="http://www.idpf.org/2007/opf" version="3.0"/>"#,
    to: root.appendingPathComponent("EPUB/book.opf")
  )
  try write("<html/>", to: root.appendingPathComponent("EPUB/chapter.xhtml"))
  try write("ignored", to: root.appendingPathComponent(".DS_Store"))
  return root
}

private func write(_ content: String, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try Data(content.utf8).write(to: url)
}

private func createArchive(
  at url: URL,
  entries: [(path: String, content: String, method: CompressionMethod)]
) throws {
  let archive = try Archive(url: url, accessMode: .create)
  for entry in entries {
    try add(entry.path, content: entry.content, to: archive, method: entry.method)
  }
}

private func add(
  _ path: String,
  content: String,
  to archive: Archive,
  method: CompressionMethod
) throws {
  let data = Data(content.utf8)
  try archive.addEntry(
    with: path,
    type: .file,
    uncompressedSize: Int64(data.count),
    compressionMethod: method
  ) { position, size in
    let start = Int(position)
    return data.subdata(in: start..<min(start + size, data.count))
  }
}
