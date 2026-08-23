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
    .frame(
      minWidth: 520,
      idealWidth: 600,
      maxWidth: .infinity,
      minHeight: 420,
      idealHeight: 500,
      maxHeight: .infinity
    )
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
        .accessibilityHidden(true)

      stateTitle
        .font(.title3.weight(.medium))
        .multilineTextAlignment(.center)

      stateDetail
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440, maxHeight: 150)

      if case .working(let progress) = model.state {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel(AppStrings.progress.localized)
          .accessibilityValue(
            AppStrings.processingProgress(
              completed: progress.completedCount,
              total: progress.totalCount
            ).localized
          )
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
    case .finished(let summary):
      Image(
        systemName: summary.failures.isEmpty ? "checkmark.circle" : "exclamationmark.triangle"
      )
    }
  }

  private var iconColor: Color {
    switch model.state {
    case .finished(let summary): summary.failures.isEmpty ? .green : .orange
    default: .accentColor
    }
  }

  @ViewBuilder
  private var stateTitle: some View {
    switch model.state {
    case .idle:
      Text(AppStrings.dropPrompt.localized)
    case .working(let progress):
      Text(AppStrings.processing(progress.currentURL.lastPathComponent).localized)
    case .finished(let summary):
      if !summary.failures.isEmpty {
        Text(
          (summary.successes.isEmpty ? AppStrings.failed : AppStrings.completedWithIssues).localized
        )
      } else if summary.successes.count == 1, let result = summary.successes.first {
        Text((result.kind == .pack ? AppStrings.epubCreated : AppStrings.epubExtracted).localized)
      } else {
        Text(AppStrings.itemsCompleted(summary.successes.count).localized)
      }
    }
  }

  @ViewBuilder
  private var stateDetail: some View {
    switch model.state {
    case .idle:
      Text(AppStrings.idleDetail.localized)
    case .working(let progress):
      VStack(spacing: 5) {
        Text(AppStrings.workingDetail.localized)
        Text(
          AppStrings.processingProgress(
            completed: progress.completedCount,
            total: progress.totalCount
          ).localized
        )
      }
    case .finished(let summary):
      summaryDetails(summary)
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
    case .finished(let summary):
      if summary.successes.isEmpty {
        HStack {
          Button(AppStrings.chooseAgain.localized) { model.chooseItems() }
            .buttonStyle(.borderedProminent)
          Button(AppStrings.back.localized) { model.reset() }
        }
      } else {
        HStack {
          Button(AppStrings.showInFinder(summary.successes.count).localized) {
            model.revealResults()
          }
          .buttonStyle(.borderedProminent)
          Button(AppStrings.processAnother.localized) { model.reset() }
        }
      }
    case .working:
      EmptyView()
    }
  }

  private func summaryDetails(_ summary: AppModel.BatchSummary) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 7) {
        if summary.successes.count + summary.failures.count > 1 {
          Text(
            AppStrings.batchCounts(
              successes: summary.successes.count,
              failures: summary.failures.count
            ).localized
          )
          .fontWeight(.medium)
        }
        if summary.warningCount > 0 {
          Label(
            AppStrings.warningCount(summary.warningCount).localized,
            systemImage: "exclamationmark.triangle"
          )
        }
        ForEach(Array(summary.successes.enumerated()), id: \.offset) { _, result in
          Text(result.outputURL.path)
            .textSelection(.enabled)
          ForEach(
            Array(result.report.issues.filter { $0.severity == .warning }.enumerated()),
            id: \.offset
          ) { _, issue in
            Text("• \(issue.message)")
          }
        }
        ForEach(Array(summary.failures.enumerated()), id: \.offset) { _, failure in
          Text(
            AppStrings.failureLine(
              failure.inputURL.lastPathComponent,
              failure.message
            ).localized
          )
          .foregroundStyle(.primary)
          .textSelection(.enabled)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .multilineTextAlignment(.leading)
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
