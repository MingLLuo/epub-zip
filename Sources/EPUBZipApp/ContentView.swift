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
      Text(AppStrings.subtitle.localized)
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
      Text(AppStrings.dropPrompt.localized)
    case .working(let name):
      Text(AppStrings.processing(name).localized)
    case .success(let result):
      Text((result.kind == .pack ? AppStrings.epubCreated : AppStrings.epubExtracted).localized)
    case .failure:
      Text(AppStrings.failed.localized)
    }
  }

  @ViewBuilder
  private var stateDetail: some View {
    switch model.state {
    case .idle:
      Text(AppStrings.idleDetail.localized)
    case .working:
      Text(AppStrings.workingDetail.localized)
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
      Button(AppStrings.choose.localized) {
        model.chooseItems()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    case .success:
      HStack {
        Button(AppStrings.showInFinder.localized) { model.revealResult() }
          .buttonStyle(.borderedProminent)
        Button(AppStrings.processAnother.localized) { model.reset() }
      }
    case .failure:
      HStack {
        Button(AppStrings.chooseAgain.localized) { model.chooseItems() }
          .buttonStyle(.borderedProminent)
        Button(AppStrings.back.localized) { model.reset() }
      }
    case .working:
      EmptyView()
    }
  }

  private var footer: some View {
    HStack {
      Label(AppStrings.nativeAppleSilicon.localized, systemImage: "cpu")
      Spacer()
      Text(AppStrings.inputUnmodified.localized)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}
