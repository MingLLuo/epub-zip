import EPUBZipCore
import Testing

@testable import EPUBZipCLI

struct OptionsTests {
  @Test
  func parsesKnownOptionsInAnyOrder() throws {
    var options = Options(["source", "--force", "--output", "book.epub"])

    #expect(try options.value(for: ["-o", "--output"]) == "book.epub")
    #expect(try options.flag("--force"))
    #expect(try options.singlePath(usage: CLIStrings.packUsage) == "source")
  }

  @Test
  func optionTerminatorPreservesHyphenPrefixedPaths() throws {
    var options = Options(["--force", "--", "--force"])

    #expect(try options.flag("--force"))
    #expect(try options.singlePath(usage: CLIStrings.autoUsage) == "--force")
  }

  @Test
  func optionsAfterTerminatorRemainOperands() throws {
    var options = Options(["--", "--package", "-book.epub"])

    #expect(try !options.flag("--package"))
    #expect(
      try options.paths(usage: CLIStrings.autoUsage) == ["--package", "-book.epub"]
    )
  }

  @Test
  func rejectsOptionWithoutValue() {
    var options = Options(["-o"])

    #expect(throws: CLIArgumentError.missingOptionValue("-o")) {
      _ = try options.value(for: ["-o", "--output"])
    }
  }

  @Test
  func rejectsAnotherOptionAsAValue() {
    var options = Options(["-o", "--force", "source"])

    #expect(throws: CLIArgumentError.missingOptionValue("-o")) {
      _ = try options.value(for: ["-o", "--output"])
    }
  }

  @Test
  func rejectsDuplicateAliasesForTheSameOption() {
    var options = Options(["-o", "first.epub", "--output", "second.epub", "source"])

    #expect(throws: CLIArgumentError.duplicateOption("-o/--output")) {
      _ = try options.value(for: ["-o", "--output"])
    }
  }

  @Test
  func rejectsDuplicateFlags() {
    var options = Options(["--force", "source", "--force"])

    #expect(throws: CLIArgumentError.duplicateOption("--force")) {
      _ = try options.flag("--force")
    }
  }

  @Test
  func rejectsUnknownOptionsBeforeTerminator() {
    var options = Options(["--unknown", "source"])

    #expect(throws: CLIArgumentError.unknownOption("--unknown")) {
      _ = try options.singlePath(usage: CLIStrings.packUsage)
    }
  }

  @Test
  func rejectsMissingAndExtraOperands() {
    var missing = Options([])
    var extra = Options(["one", "two"])

    #expect(throws: CLIArgumentError.invalidArguments(CLIStrings.packUsage)) {
      _ = try missing.singlePath(usage: CLIStrings.packUsage)
    }
    #expect(throws: CLIArgumentError.invalidArguments(CLIStrings.packUsage)) {
      _ = try extra.singlePath(usage: CLIStrings.packUsage)
    }
  }

  @Test
  func userFacingLabelsHaveEnglishAndSimplifiedChineseForms() {
    let warning = InspectionIssue(severity: .warning, code: "fixture", message: "detail")

    #expect(CLIStrings.packUsage.resolved(for: .english).contains("<directory>"))
    #expect(CLIStrings.packUsage.resolved(for: .simplifiedChinese).contains("<目录>"))
    #expect(CLIStrings.inspectionIssue(warning).resolved(for: .english).contains("warning"))
    #expect(CLIStrings.inspectionIssue(warning).resolved(for: .simplifiedChinese).contains("警告"))
    #expect(
      CLIStrings.rootfiles(["EPUB/book.opf"]).resolved(for: .english).hasPrefix("rootfiles:"))
    #expect(
      CLIStrings.rootfiles(["EPUB/book.opf"]).resolved(for: .simplifiedChinese).hasPrefix("根文件："))
    #expect(
      CLIStrings.reportSummary(isValid: true, path: "book.epub", entryCount: 1)
        .resolved(for: .english).contains("1 entry)"))
    #expect(
      CLIStrings.reportSummary(isValid: false, path: "book.epub", entryCount: 2)
        .resolved(for: .simplifiedChinese).hasPrefix("无效："))
  }
}
