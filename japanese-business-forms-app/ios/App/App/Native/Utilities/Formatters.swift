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
}

extension Color {
    static let appBackground = Color(red: 0.956, green: 0.956, blue: 0.944)
    static let appInk = Color(red: 0.094, green: 0.102, blue: 0.106)
    static let appMuted = Color(red: 0.431, green: 0.451, blue: 0.467)
    static let appAccent = Color(red: 0.875, green: 1.0, blue: 0.0)
    static let appPanel = Color.white
    static let appSidebar = Color(red: 0.141, green: 0.149, blue: 0.157)
    static let appSidebarCard = Color(red: 0.188, green: 0.196, blue: 0.204)
}
