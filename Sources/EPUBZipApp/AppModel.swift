import AppKit
import Combine
import EPUBZipCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
  enum State {
    case idle
    case working(String)
    case success(OperationResult)
    case failure(String)
  }

  @Published var state: State = .idle
  @Published var isDropTargeted = false

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

  func process(_ urls: [URL]) {
    guard !urls.isEmpty, !isWorking else { return }
    let packageDirectory = UserDefaults.standard.bool(forKey: "packageDirectory")
    state = .working(
      urls.count == 1
        ? urls[0].lastPathComponent
        : AppStrings.itemCount(urls.count).localized
    )
    Task {
      do {
        var latest: OperationResult?
        for url in urls {
          latest = try await Task.detached(priority: .userInitiated) {
            try EPUBService().process(
              url,
              packageDirectory: packageDirectory,
              conflictPolicy: .uniquify
            )
          }.value
        }
        if let latest { state = .success(latest) }
      } catch {
        state = .failure(error.localizedDescription)
      }
    }
  }

  func revealResult() {
    guard case .success(let result) = state else { return }
    NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
  }

  func reset() {
    state = .idle
  }
}
