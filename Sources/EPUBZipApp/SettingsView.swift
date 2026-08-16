import SwiftUI

struct SettingsView: View {
  @AppStorage("packageDirectory") private var packageDirectory = false

  var body: some View {
    Form {
      Toggle("将解包目录命名为 “书名_pkg.epub”", isOn: $packageDirectory)
      Text("此选项复现旧工具的 iBooks Package 命名；输出仍是普通目录。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 440)
  }
}
