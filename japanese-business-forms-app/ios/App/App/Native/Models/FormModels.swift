import Foundation
import SwiftUI
import UIKit

enum DocumentType: String, CaseIterable, Identifiable, Codable {
    case estimate
    case customerOrder
    case purchaseOrder
    case delivery
    case invoice
    case receipt
    case acceptance
    case customerFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estimate: return "見積書"
        case .customerOrder: return "客先注文記録"
        case .purchaseOrder: return "発注書"
        case .delivery: return "納品書"
        case .invoice: return "請求書"
        case .receipt: return "領収書"
        case .acceptance: return "受領書"
        case .customerFiles: return "專案管理"
        }
    }

    var subtitle: String {
        switch self {
        case .estimate: return "Quotation"
        case .customerOrder: return "Customer Order Record"
        case .purchaseOrder: return "Purchase Order"
        case .delivery: return "Delivery Note"
        case .invoice: return "Invoice"
        case .receipt: return "Receipt"
        case .acceptance: return "Acceptance Receipt"
        case .customerFiles: return "Project Documents"
        }
    }

    var pageTitle: String {
        switch self {
        case .customerOrder: return "客先注文記録"
        case .customerFiles: return "文件與專案管理"
        default: return "\(title)作成"
        }
    }

    var prefix: String {
        switch self {
        case .estimate: return "EST"
        case .customerOrder: return "ORD"
        case .purchaseOrder: return "PO"
        case .delivery: return "DLV"
        case .invoice: return "INV"
        case .receipt: return "RCT"
        case .acceptance: return "ACP"
        case .customerFiles: return "CF"
        }
    }

    var totalLabel: String {
        switch self {
        case .estimate: return "御見積金額"
        case .customerOrder: return "注文金額"
        case .purchaseOrder: return "発注金額"
        case .delivery: return "納品金額"
        case .invoice: return "ご請求金額"
        case .receipt: return "領収金額"
        case .acceptance: return "受領金額"
        case .customerFiles: return "記録金額"
        }
    }
}

enum ProjectDirection: String, CaseIterable, Identifiable, Codable {
    case customer
    case vendor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .customer: return "給客戶"
        case .vendor: return "給廠商"
        }
    }

    var subtitle: String {
        switch self {
        case .customer: return "見積・受注・納品・請求・領収"
        case .vendor: return "発注・受領"
        }
    }

    var requiredTypes: [DocumentType] {
        switch self {
        case .customer: return [.estimate, .customerOrder, .delivery, .invoice, .receipt]
        case .vendor: return [.purchaseOrder, .acceptance]
        }
    }

    var firstType: DocumentType {
        requiredTypes[0]
    }
}

struct ProjectArchive: Identifiable, Equatable {
    let id: UUID
    var name: String
    var direction: ProjectDirection
    var customerName: String
    var updatedAt: Date
    var documents: [BusinessDocument]

    var completedCount: Int {
        direction.requiredTypes.filter { type in
            documents.contains { $0.type == type }
        }.count
    }

    func document(for type: DocumentType) -> BusinessDocument? {
        documents
            .filter { $0.type == type }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }
}

struct LineItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var model = ""
    var specification = ""
    var quantity: Double = 1
    var unitPrice: Double = 0

    var amount: Double { quantity * unitPrice }
}

struct CustomerProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var contact = ""
    var address = ""
    var updatedAt = Date()
}

struct IssuerProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var registration = ""
    var contact = ""
    var phone = ""
    var email = ""
    var address = ""
    var logoData: Data?
    var logoScale: Double?
    var updatedAt = Date()
}

struct ProductProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var model = ""
    var specification = ""
    var unitPrice: Double = 0
    var updatedAt = Date()
}

enum DocumentColorTemplate: String, CaseIterable, Identifiable {
    case monochrome
    case oceanTable
    case mintTable
    case roseTable
    case amberTable
    case graphiteTable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monochrome: return "日本帳票"
        case .oceanTable: return "海藍表格"
        case .mintTable: return "薄荷表格"
        case .roseTable: return "玫瑰表格"
        case .amberTable: return "琥珀表格"
        case .graphiteTable: return "石墨表格"
        }
    }

    var accent: UIColor {
        switch self {
        case .monochrome: return UIColor(red: 0.180, green: 0.188, blue: 0.192, alpha: 1)
        case .oceanTable: return UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1)
        case .mintTable: return UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1)
        case .roseTable: return UIColor(red: 0.745, green: 0.071, blue: 0.235, alpha: 1)
        case .amberTable: return UIColor(red: 0.706, green: 0.325, blue: 0.035, alpha: 1)
        case .graphiteTable: return UIColor(red: 0.278, green: 0.333, blue: 0.412, alpha: 1)
        }
    }

    var softLine: UIColor {
        switch self {
        case .monochrome: return UIColor(red: 0.851, green: 0.851, blue: 0.831, alpha: 1)
        case .oceanTable: return UIColor(red: 0.749, green: 0.859, blue: 0.996, alpha: 1)
        case .mintTable: return UIColor(red: 0.600, green: 0.965, blue: 0.894, alpha: 1)
        case .roseTable: return UIColor(red: 0.996, green: 0.804, blue: 0.827, alpha: 1)
        case .amberTable: return UIColor(red: 0.992, green: 0.902, blue: 0.541, alpha: 1)
        case .graphiteTable: return UIColor(red: 0.796, green: 0.835, blue: 0.882, alpha: 1)
        }
    }

    var tableHead: UIColor {
        switch self {
        case .monochrome: return UIColor(red: 0.961, green: 0.965, blue: 0.969, alpha: 1)
        case .oceanTable: return UIColor(red: 0.859, green: 0.918, blue: 0.996, alpha: 1)
        case .mintTable: return UIColor(red: 0.800, green: 0.984, blue: 0.945, alpha: 1)
        case .roseTable: return UIColor(red: 1.000, green: 0.894, blue: 0.902, alpha: 1)
        case .amberTable: return UIColor(red: 0.996, green: 0.953, blue: 0.780, alpha: 1)
        case .graphiteTable: return UIColor(red: 0.886, green: 0.910, blue: 0.941, alpha: 1)
        }
    }

    var totalBackground: UIColor {
        switch self {
        case .monochrome: return UIColor(red: 0.961, green: 0.965, blue: 0.969, alpha: 1)
        case .oceanTable: return UIColor(red: 0.937, green: 0.965, blue: 1.000, alpha: 1)
        case .mintTable: return UIColor(red: 0.941, green: 0.992, blue: 0.980, alpha: 1)
        case .roseTable: return UIColor(red: 1.000, green: 0.945, blue: 0.949, alpha: 1)
        case .amberTable: return UIColor(red: 1.000, green: 0.984, blue: 0.922, alpha: 1)
        case .graphiteTable: return UIColor(red: 0.945, green: 0.961, blue: 0.976, alpha: 1)
        }
    }

    var swiftUIColor: Color {
        Color(uiColor: accent)
    }
}

struct BusinessDocument: Identifiable, Codable, Equatable {
    var id = UUID()
    var projectId: UUID?
    var projectName: String?
    var projectDirection: ProjectDirection?
    var type: DocumentType = .invoice
    var number = ""
    var issueDate = Date()
    var transactionDate = Date()
    var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var relatedNumber = ""
    var honorific = "御中"
    var taxRate: Double = 10
    var colorTemplateId: String?

    var customerName = ""
    var customerAddress = ""
    var customerContact = ""

    var issuerName = "NIIX株式会社"
    var issuerRegistration = ""
    var issuerAddress = "東京都"
    var issuerContact = ""
    var issuerPhone = ""
    var issuerEmail = ""
    var issuerLogoData: Data?
    var issuerLogoScale: Double?

    var notes = ""
    var paymentDetails = ""
    var documentMemo = ""
    var lines: [LineItem] = [LineItem(name: "商品・サービス", quantity: 1, unitPrice: 0)]
    var updatedAt = Date()

    var subtotal: Double { lines.reduce(0) { $0 + $1.amount } }
    var tax: Double { subtotal * taxRate / 100 }
    var total: Double { subtotal + tax }
    var colorTemplate: DocumentColorTemplate {
        DocumentColorTemplate(rawValue: colorTemplateId ?? "") ?? .monochrome
    }

    static func blank(type: DocumentType, number: String) -> BusinessDocument {
        var document = BusinessDocument()
        document.type = type
        document.number = number
        document.notes = defaultNotes(for: type)
        document.documentMemo = defaultMemo(for: type)
        return document
    }

    private static func defaultNotes(for type: DocumentType) -> String {
        switch type {
        case .estimate: return "見積条件、納入予定、税率・合計金額を確認してください。"
        case .customerOrder: return "客先から受領した注文資料を添付し、取引内容を確認してください。"
        case .purchaseOrder: return "注文内容をご確認の上、手配をお願いいたします。"
        case .delivery: return "上記の通り納品いたします。"
        case .invoice: return "振込手数料は貴社にてご負担ください。"
        case .receipt: return "上記の金額を領収いたしました。"
        case .acceptance: return "上記の通り、受領いたしました。"
        case .customerFiles: return "取引先から受領した書類ファイルを管理します。"
        }
    }

    private static func defaultMemo(for type: DocumentType) -> String {
        switch type {
        case .customerFiles: return "見積書、請求書、領収書などを同じ画面で管理します。"
        case .customerOrder: return "受領した注文ファイル、希望納期、関連見積番号を確認してください。"
        default: return ""
        }
    }
}
