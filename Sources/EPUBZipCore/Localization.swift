import Foundation

public enum EPUBZipLanguage: String, Sendable {
  case english = "en"
  case simplifiedChinese = "zh-Hans"
}

/// A message whose translations live together and can be resolved explicitly in tests.
public struct LocalizedMessage: Sendable, Equatable {
  public let english: String
  public let simplifiedChinese: String

  public init(english: String, simplifiedChinese: String) {
    self.english = english
    self.simplifiedChinese = simplifiedChinese
  }

  public func resolved(for language: EPUBZipLanguage) -> String {
    switch language {
    case .english: english
    case .simplifiedChinese: simplifiedChinese
    }
  }

  public var localized: String {
    resolved(for: EPUBZipLocalization.currentLanguage)
  }
}

/// Resolves the app and CLI language without coupling messages to Foundation bundles.
///
/// macOS application-language settings appear in `Locale.preferredLanguages`. CLI users
/// can override detection with `EPUBZIP_LANGUAGE=en` or `EPUBZIP_LANGUAGE=zh-Hans`.
public enum EPUBZipLocalization {
  public static var currentLanguage: EPUBZipLanguage {
    detectLanguage(
      override: ProcessInfo.processInfo.environment["EPUBZIP_LANGUAGE"],
      preferredLanguages: Locale.preferredLanguages
    )
  }

  public static func detectLanguage(
    override: String?,
    preferredLanguages: [String]
  ) -> EPUBZipLanguage {
    if let overrideLanguage = language(for: override) {
      return overrideLanguage
    }
    return preferredLanguages.lazy.compactMap(language(for:)).first ?? .english
  }

  private static func language(for identifier: String?) -> EPUBZipLanguage? {
    guard let identifier else { return nil }
    let languageCode = Locale.Language(identifier: identifier).languageCode?.identifier
    switch languageCode {
    case "zh": return .simplifiedChinese
    case "en": return .english
    default: return nil
    }
  }
}
