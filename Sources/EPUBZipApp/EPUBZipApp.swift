import SwiftUI

@main
struct EPUBZipApp: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    Window("EPUB Zip", id: "main") {
      ContentView(model: model)
    }
    .defaultSize(width: 600, height: 500)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button(AppStrings.choose.localized) { model.chooseItems() }
          .keyboardShortcut("o")
      }
    }

    Settings {
      SettingsView()
    }
  }
}
