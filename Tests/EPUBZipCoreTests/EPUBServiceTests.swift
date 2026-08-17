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
        override: "unsupported", preferredLanguages: []
      ) == .english
    )

    let message = CoreStrings.outputExtension
    #expect(message.resolved(for: .english).contains(".epub extension"))
    #expect(message.resolved(for: .simplifiedChinese).contains(".epub 扩展名"))
  }

  @Test
  func packInspectAndUnpackRoundTrip() throws {
    let source = try validSource()
    let root = try temporaryDirectory()
    let epub = root.appendingPathComponent("book.epub")
    let service = EPUBService()

    let packed = try service.pack(directory: source, to: epub)
    #expect(packed.report.isValid)
    #expect(packed.report.rootfiles == ["EPUB/book.opf"])

    let firstHeader = try Data(contentsOf: epub, options: .mappedIfSafe)
    #expect(String(data: firstHeader.subdata(in: 30..<38), encoding: .utf8) == "mimetype")
    #expect(firstHeader[8] == 0 && firstHeader[9] == 0)
    #expect(firstHeader[28] == 0 && firstHeader[29] == 0)

    let output = root.appendingPathComponent("unpacked", isDirectory: true)
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
    let source = try validSource()
    let root = try temporaryDirectory()
    let first = root.appendingPathComponent("first.epub")
    let second = root.appendingPathComponent("second.epub")
    let service = EPUBService()
    _ = try service.pack(directory: source, to: first)
    _ = try service.pack(directory: source, to: second)
    #expect(try Data(contentsOf: first) == Data(contentsOf: second))
  }

  @Test
  func rejectsMimetypeWithNewline() throws {
    let source = try validSource()
    try Data((EPUBInspector.mediaType + "\n").utf8).write(
      to: source.appendingPathComponent("mimetype"))
    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().pack(
        directory: source,
        to: source.deletingLastPathComponent().appendingPathComponent("bad.epub")
      )
    }
  }

  @Test
  func rejectsTraversalBeforeWriting() throws {
    let root = try temporaryDirectory()
    let archiveURL = root.appendingPathComponent("evil.epub")
    let archive = try Archive(url: archiveURL, accessMode: .create)
    try add("mimetype", content: EPUBInspector.mediaType, to: archive, method: .none)
    try add("../escaped", content: "owned", to: archive, method: .deflate)

    let output = root.appendingPathComponent("output", isDirectory: true)
    #expect(throws: EPUBZipError.self) {
      _ = try EPUBService().unpack(epub: archiveURL, to: output)
    }
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("escaped").path))
    #expect(!FileManager.default.fileExists(atPath: output.path))
  }

  @Test
  func rejectsSymlinkEntries() throws {
    let root = try temporaryDirectory()
    let archiveURL = root.appendingPathComponent("link.epub")
    let archive = try Archive(url: archiveURL, accessMode: .create)
    let data = Data("target".utf8)
    try archive.addEntry(with: "link", type: .symlink, uncompressedSize: Int64(data.count)) {
      position, size in
      let start = Int(position)
      return data.subdata(in: start..<min(start + size, data.count))
    }
    let report = try EPUBService().inspect(archiveURL)
    #expect(!report.isValid)
    #expect(report.issues.contains { $0.code == "symlink" })
  }

  @Test
  func failedReplacementPreservesExistingOutput() throws {
    let root = try temporaryDirectory()
    let output = root.appendingPathComponent("book.epub")
    try Data("old".utf8).write(to: output)
    let invalidSource = try temporaryDirectory()

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
    let source = try validSource()
    let root = try temporaryDirectory()
    let output = root.appendingPathComponent("book.epub")
    try Data("existing".utf8).write(to: output)
    let result = try EPUBService().pack(
      directory: source,
      to: output,
      conflictPolicy: .uniquify
    )
    #expect(result.outputURL.lastPathComponent == "book 2.epub")
    #expect(try String(contentsOf: output, encoding: .utf8) == "existing")
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

private func validSource() throws -> URL {
  let root = try temporaryDirectory()
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

private func temporaryDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "epubzip-tests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

private func write(_ content: String, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try Data(content.utf8).write(to: url)
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
