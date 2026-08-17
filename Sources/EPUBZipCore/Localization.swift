import Foundation

/// Lightweight localization shared by the GUI, CLI, and core library.
///
/// macOS application-language settings are reflected in `Locale.preferredLanguages`.
/// CLI users can override detection with `EPUBZIP_LANGUAGE=en` or
/// `EPUBZIP_LANGUAGE=zh-Hans`.
public enum EPUBZipLocalization {
  public static var usesSimplifiedChinese: Bool {
    let environment = ProcessInfo.processInfo.environment["EPUBZIP_LANGUAGE"]?.lowercased()
    if let environment {
      if environment.hasPrefix("zh") { return true }
      if environment.hasPrefix("en") { return false }
    }
    guard let preferred = Locale.preferredLanguages.first else { return false }
    return Locale.Language(identifier: preferred).languageCode?.identifier == "zh"
  }

  public static func text(_ english: String, zhHans: String) -> String {
    usesSimplifiedChinese ? zhHans : english
  }
}
