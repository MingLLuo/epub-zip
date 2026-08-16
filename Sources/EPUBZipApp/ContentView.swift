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
      Text("目录打包 · EPUB 解包 · 自动检查")
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
      Text("拖入 EPUB 或源目录")
    case .working(let name):
      Text("正在处理 \(name)")
    case .success(let result):
      Text(result.kind == .pack ? "EPUB 已创建" : "EPUB 已解包")
    case .failure:
      Text("没有完成")
    }
  }

  @ViewBuilder
  private var stateDetail: some View {
    switch model.state {
    case .idle:
      Text("拖入目录会生成 EPUB；拖入 .epub 会生成可编辑目录。已有同名结果不会被覆盖。")
    case .working:
      Text("正在检查结构并安全写入临时位置…")
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
      Button("选择文件或目录…") { model.chooseItems() }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    case .success:
      HStack {
        Button("在 Finder 中显示") { model.revealResult() }
          .buttonStyle(.borderedProminent)
        Button("继续处理") { model.reset() }
      }
    case .failure:
      HStack {
        Button("重新选择…") { model.chooseItems() }
          .buttonStyle(.borderedProminent)
        Button("返回") { model.reset() }
      }
    case .working:
      EmptyView()
    }
  }

  private var footer: some View {
    HStack {
      Label("Apple Silicon 原生", systemImage: "cpu")
      Spacer()
      Text("不会修改输入文件")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}
