import SwiftUI

struct SettingsView: View {
  @AppStorage("packageDirectory") private var packageDirectory = false

  var body: some View {
    Form {
      Toggle(AppStrings.packageDirectory.localized, isOn: $packageDirectory)
      Text(AppStrings.packageDirectoryHelp.localized)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 440)
  }
}
