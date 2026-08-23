import EPUBZipCore
import Foundation
import Testing

@testable import EPUBZipApp

@MainActor
@Suite(.serialized)
struct AppModelTests {
  @Test
  func batchPreservesSuccessesFailuresAndWarnings() async {
    let model = AppModel { inputURL, _ in
      if inputURL.lastPathComponent == "bad.epub" {
        throw FixtureError.failed
      }
      return fixtureResult(
        for: inputURL,
        warning: inputURL.lastPathComponent == "warning.epub"
      )
    }
    let inputs = ["first.epub", "bad.epub", "warning.epub"].map {
      URL(fileURLWithPath: "/tmp/\($0)")
    }

    #expect(model.process(inputs))
    await waitUntilFinished(model)

    guard case .finished(let summary) = model.state else {
      Issue.record("Expected a finished batch")
      return
    }
    #expect(summary.successes.count == 2)
    #expect(summary.failures.count == 1)
    #expect(summary.failures.first?.inputURL.lastPathComponent == "bad.epub")
    #expect(summary.warningCount == 1)
    #expect(summary.successes.map(\.inputURL.lastPathComponent) == ["first.epub", "warning.epub"])
  }

  @Test
  func droppingAfterCompletionStartsAFreshBatch() async {
    let model = AppModel { inputURL, _ in fixtureResult(for: inputURL) }

    #expect(model.process([URL(fileURLWithPath: "/tmp/first.epub")]))
    await waitUntilFinished(model)
    #expect(model.process([URL(fileURLWithPath: "/tmp/second.epub")]))
    await waitUntilFinished(model)

    guard case .finished(let summary) = model.state else {
      Issue.record("Expected a finished batch")
      return
    }
    #expect(summary.successes.count == 1)
    #expect(summary.successes.first?.inputURL.lastPathComponent == "second.epub")
  }

  @Test
  func itemsAddedWhileWorkingJoinTheCurrentBatch() async {
    let gate = SuspensionGate()
    let model = AppModel { inputURL, _ in
      await gate.wait()
      return fixtureResult(for: inputURL)
    }

    #expect(model.process([URL(fileURLWithPath: "/tmp/first.epub")]))
    await Task.yield()
    #expect(model.process([URL(fileURLWithPath: "/tmp/second.epub")]))

    guard case .working(let progress) = model.state else {
      Issue.record("Expected an active batch")
      return
    }
    #expect(progress.totalCount == 2)

    await gate.open()
    await waitUntilFinished(model)

    guard case .finished(let summary) = model.state else {
      Issue.record("Expected a finished batch")
      return
    }
    #expect(summary.successes.map(\.inputURL.lastPathComponent) == ["first.epub", "second.epub"])
  }

  @Test
  func rejectsNonFileDropPayloads() {
    let model = AppModel { inputURL, _ in fixtureResult(for: inputURL) }
    #expect(!model.process([URL(string: "https://example.com/book.epub")!]))
    #expect(!model.isWorking)
  }
}

private enum FixtureError: LocalizedError {
  case failed

  var errorDescription: String? { "Fixture failure" }
}

private actor SuspensionGate {
  private var isOpen = false
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    guard !isOpen else { return }
    await withCheckedContinuation { continuation = $0 }
  }

  func open() {
    isOpen = true
    continuation?.resume()
    continuation = nil
  }
}

private func fixtureResult(for inputURL: URL, warning: Bool = false) -> OperationResult {
  let issues =
    warning
    ? [InspectionIssue(severity: .warning, code: "fixture", message: "Fixture warning")]
    : []
  return OperationResult(
    kind: .unpack,
    inputURL: inputURL,
    outputURL: inputURL.deletingPathExtension(),
    report: InspectionReport(
      path: inputURL.path,
      entryCount: 3,
      rootfiles: ["EPUB/book.opf"],
      issues: issues
    )
  )
}

@MainActor
private func waitUntilFinished(_ model: AppModel) async {
  for _ in 0..<1_000 {
    if !model.isWorking { return }
    await Task.yield()
  }
  Issue.record("Batch did not finish")
}
