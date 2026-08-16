import SwiftUI

@main
struct EPUBZipApp: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup("EPUB Zip") {
      ContentView(model: model)
    }
    .defaultSize(width: 560, height: 430)
    .windowResizability(.contentSize)

    Settings {
      SettingsView()
    }
  }
}
