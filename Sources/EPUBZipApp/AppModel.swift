import AppKit
import Combine
import EPUBZipCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
  struct BatchProgress {
    let currentURL: URL
    let completedCount: Int
    let totalCount: Int
  }

  struct ItemFailure {
    let inputURL: URL
    let message: String
  }

  struct BatchSummary {
    let successes: [OperationResult]
    let failures: [ItemFailure]

    var warningCount: Int {
      successes.reduce(into: 0) { count, result in
        count += result.report.issues.count { $0.severity == .warning }
      }
    }
  }

  enum State {
    case idle
    case working(BatchProgress)
    case finished(BatchSummary)
  }

  typealias ItemProcessor = @Sendable (URL, Bool) async throws -> OperationResult

  @Published private(set) var state: State = .idle
  @Published var isDropTargeted = false

  private struct PendingItem {
    let url: URL
    let packageDirectory: Bool
  }

  private let processor: ItemProcessor
  private var pendingItems: [PendingItem] = []
  private var successes: [OperationResult] = []
  private var failures: [ItemFailure] = []
  private var totalCount = 0
  private var processingTask: Task<Void, Never>?

  init(
    processor: @escaping ItemProcessor = { url, packageDirectory in
      try await Task.detached(priority: .userInitiated) {
        try EPUBService().process(
          url,
          packageDirectory: packageDirectory,
          conflictPolicy: .uniquify
        )
      }.value
    }
  ) {
    self.processor = processor
  }

  var isWorking: Bool {
    if case .working = state { return true }
    return false
  }

  func chooseItems() {
    let panel = NSOpenPanel()
    panel.message = AppStrings.openPanelMessage.localized
    panel.prompt = AppStrings.process.localized
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.resolvesAliases = true
    guard panel.runModal() == .OK else { return }
    process(panel.urls)
  }

  @discardableResult
  func process(_ urls: [URL]) -> Bool {
    let accepted = urls.filter(\.isFileURL)
    guard !accepted.isEmpty else { return false }

    if processingTask == nil, case .finished = state {
      pendingItems.removeAll()
      successes.removeAll()
      failures.removeAll()
      totalCount = 0
    }

    let packageDirectory = UserDefaults.standard.bool(forKey: "packageDirectory")
    pendingItems.append(
      contentsOf: accepted.map {
        PendingItem(url: $0.standardizedFileURL, packageDirectory: packageDirectory)
      }
    )
    totalCount += accepted.count

    if processingTask != nil {
      refreshProgressTotal()
    } else {
      startProcessing()
    }
    return true
  }

  func revealResults() {
    guard case .finished(let summary) = state else { return }
    let outputs = summary.successes.map(\.outputURL)
    guard !outputs.isEmpty else { return }
    NSWorkspace.shared.activateFileViewerSelecting(outputs)
  }

  func reset() {
    guard !isWorking else { return }
    pendingItems.removeAll()
    successes.removeAll()
    failures.removeAll()
    totalCount = 0
    state = .idle
  }

  private func startProcessing() {
    guard processingTask == nil, let first = pendingItems.first else { return }
    state = .working(
      BatchProgress(currentURL: first.url, completedCount: 0, totalCount: totalCount)
    )
    processingTask = Task { [weak self] in
      await self?.drainQueue()
    }
  }

  private func drainQueue() async {
    while !pendingItems.isEmpty {
      let item = pendingItems.removeFirst()
      let completedCount = successes.count + failures.count
      state = .working(
        BatchProgress(
          currentURL: item.url,
          completedCount: completedCount,
          totalCount: totalCount
        )
      )
      do {
        successes.append(try await processor(item.url, item.packageDirectory))
      } catch {
        failures.append(ItemFailure(inputURL: item.url, message: error.localizedDescription))
      }
    }

    state = .finished(BatchSummary(successes: successes, failures: failures))
    processingTask = nil
  }

  private func refreshProgressTotal() {
    guard case .working(let progress) = state else { return }
    state = .working(
      BatchProgress(
        currentURL: progress.currentURL,
        completedCount: progress.completedCount,
        totalCount: totalCount
      )
    )
  }
}
