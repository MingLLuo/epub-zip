import SwiftUI

struct SettingsView: View {
  @AppStorage("packageDirectory") private var packageDirectory = false

  var body: some View {
    Form {
      Toggle(
        appText(
          "Name extracted folders “Book_pkg.epub”",
          zhHans: "将解包目录命名为 “书名_pkg.epub”"
        ),
        isOn: $packageDirectory
      )
      Text(
        appText(
          "This reproduces the legacy iBooks Package naming convention; the output remains a normal folder.",
          zhHans: "此选项复现旧工具的 iBooks Package 命名；输出仍是普通目录。"
        )
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 440)
  }
}
