import Foundation

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case `default` = "default"
    case jewish = "jewish"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .jewish: return "Jewish"
        }
    }
}

enum ThemePrefs {
    static let theme = "theme"
    static let hasSelectedTheme = "hasSelectedTheme"
}
