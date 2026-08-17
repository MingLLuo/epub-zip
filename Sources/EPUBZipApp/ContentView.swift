import EPUBZipCore
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(spacing: 22) {
      header
      dropZone
      footer
    }
    .padding(28)
    .frame(width: 560, height: 430)
    .background {
      LinearGradient(
        colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.06)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .onOpenURL { model.process([$0]) }
  }

  private var header: some View {
    VStack(spacing: 6) {
      Text("EPUB Zip")
        .font(.system(size: 28, weight: .semibold, design: .rounded))
      Text(appText("Folder to EPUB · EPUB to folder · Validation", zhHans: "目录打包 · EPUB 解包 · 自动检查"))
        .foregroundStyle(.secondary)
    }
  }

  private var dropZone: some View {
    VStack(spacing: 15) {
      stateIcon
        .font(.system(size: 50, weight: .light))
        .foregroundStyle(iconColor)

      stateTitle
        .font(.title3.weight(.medium))
        .multilineTextAlignment(.center)

      stateDetail
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .frame(maxWidth: 380)

      if model.isWorking {
        ProgressView()
          .controlSize(.small)
      } else {
        actionButtons
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      model.isDropTargeted
        ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor)
    )
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(
          model.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
          style: StrokeStyle(lineWidth: model.isDropTargeted ? 2 : 1, dash: [7, 5])
        )
    }
    .dropDestination(for: URL.self) { urls, _ in
      model.process(urls)
      return !urls.isEmpty
    } isTargeted: {
      model.isDropTargeted = $0
    }
  }

  @ViewBuilder
  private var stateIcon: some View {
    switch model.state {
    case .idle:
      Image(systemName: "arrow.down.doc")
    case .working:
      Image(systemName: "shippingbox")
    case .success:
      Image(systemName: "checkmark.circle")
    case .failure:
      Image(systemName: "exclamationmark.triangle")
    }
  }

  private var iconColor: Color {
    switch model.state {
    case .success: .green
    case .failure: .orange
    default: .accentColor
    }
  }

  @ViewBuilder
  private var stateTitle: some View {
    switch model.state {
    case .idle:
      Text(appText("Drop an EPUB or source folder", zhHans: "拖入 EPUB 或源目录"))
    case .working(let name):
      Text(appText("Processing \(name)", zhHans: "正在处理 \(name)"))
    case .success(let result):
      Text(
        result.kind == .pack
          ? appText("EPUB created", zhHans: "EPUB 已创建")
          : appText("EPUB extracted", zhHans: "EPUB 已解包")
      )
    case .failure:
      Text(appText("Could not complete", zhHans: "没有完成"))
    }
  }

  @ViewBuilder
  private var stateDetail: some View {
    switch model.state {
    case .idle:
      Text(
        appText(
          "Drop a folder to create an EPUB, or drop an .epub to create an editable folder. Existing results are never overwritten.",
          zhHans: "拖入目录会生成 EPUB；拖入 .epub 会生成可编辑目录。已有同名结果不会被覆盖。"
        )
      )
    case .working:
      Text(
        appText(
          "Validating the structure and writing safely to a temporary location…",
          zhHans: "正在检查结构并安全写入临时位置…"
        )
      )
    case .success(let result):
      Text(result.outputURL.path)
        .textSelection(.enabled)
    case .failure(let message):
      Text(message)
        .textSelection(.enabled)
    }
  }

  @ViewBuilder
  private var actionButtons: some View {
    switch model.state {
    case .idle:
      Button(appText("Choose File or Folder…", zhHans: "选择文件或目录…")) {
        model.chooseItems()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    case .success:
      HStack {
        Button(appText("Show in Finder", zhHans: "在 Finder 中显示")) { model.revealResult() }
          .buttonStyle(.borderedProminent)
        Button(appText("Process Another", zhHans: "继续处理")) { model.reset() }
      }
    case .failure:
      HStack {
        Button(appText("Choose Again…", zhHans: "重新选择…")) { model.chooseItems() }
          .buttonStyle(.borderedProminent)
        Button(appText("Back", zhHans: "返回")) { model.reset() }
      }
    case .working:
      EmptyView()
    }
  }

  private var footer: some View {
    HStack {
      Label(appText("Native Apple Silicon", zhHans: "Apple Silicon 原生"), systemImage: "cpu")
      Spacer()
      Text(appText("Input files are never modified", zhHans: "不会修改输入文件"))
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}
