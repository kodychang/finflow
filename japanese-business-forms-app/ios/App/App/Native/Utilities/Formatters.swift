import Foundation
import SwiftUI

enum AppFormatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func yen(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? "¥0"
    }

    static func yen(_ value: Double, language: AppLanguage) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? yen(value)
    }

    static func shortDate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: value)
    }

    static func dateTime(_ value: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: value)
    }
}

extension Color {
    static let appBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1)
            : UIColor(red: 0.978, green: 0.980, blue: 0.982, alpha: 1)
    })
    static let appInk = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.940, green: 0.946, blue: 0.957, alpha: 1)
            : UIColor(red: 0.114, green: 0.118, blue: 0.133, alpha: 1)
    })
    static let appMuted = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.627, green: 0.651, blue: 0.690, alpha: 1)
            : UIColor(red: 0.545, green: 0.565, blue: 0.596, alpha: 1)
    })
    static let appAccent = Color(red: 1.000, green: 0.416, blue: 0.322)
    static let appAccentSoft = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.290, green: 0.110, blue: 0.086, alpha: 1)
            : UIColor(red: 1.000, green: 0.922, blue: 0.902, alpha: 1)
    })
    static let appMint = Color(red: 0.180, green: 0.780, blue: 0.514)
    static let appBlue = Color(red: 0.259, green: 0.494, blue: 0.875)
    static let appDivider = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.192, green: 0.204, blue: 0.231, alpha: 1)
            : UIColor(red: 0.902, green: 0.914, blue: 0.929, alpha: 1)
    })
    static let appPanel = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.086, green: 0.094, blue: 0.110, alpha: 1)
            : UIColor.white
    })
    static let appInputBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.118, green: 0.129, blue: 0.153, alpha: 1)
            : UIColor.white
    })
    static let appSidebar = Color.appBackground
    static let appSidebarCard = Color.appPanel
}

private struct AppButtonAccentKey: EnvironmentKey {
    static let defaultValue = Color.appAccent
}

extension EnvironmentValues {
    var appButtonAccent: Color {
        get { self[AppButtonAccentKey.self] }
        set { self[AppButtonAccentKey.self] = newValue }
    }
}
