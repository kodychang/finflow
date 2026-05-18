import Foundation

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
        case .customerFiles: return "顧客書類"
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
        case .customerFiles: return "Customer Files"
        }
    }

    var pageTitle: String {
        switch self {
        case .customerOrder: return "客先注文記録"
        case .customerFiles: return "顧客書類管理"
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

struct LineItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var model = ""
    var specification = ""
    var quantity: Double = 1
    var unitPrice: Double = 0

    var amount: Double { quantity * unitPrice }
}

struct BusinessDocument: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: DocumentType = .invoice
    var number = ""
    var issueDate = Date()
    var transactionDate = Date()
    var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var relatedNumber = ""
    var honorific = "御中"
    var taxRate: Double = 10

    var customerName = ""
    var customerAddress = ""
    var customerContact = ""

    var issuerName = "NIIX株式会社"
    var issuerRegistration = ""
    var issuerAddress = "東京都"
    var issuerContact = ""
    var issuerPhone = ""
    var issuerEmail = ""

    var notes = ""
    var paymentDetails = ""
    var documentMemo = ""
    var lines: [LineItem] = [LineItem(name: "商品・サービス", quantity: 1, unitPrice: 0)]
    var updatedAt = Date()

    var subtotal: Double { lines.reduce(0) { $0 + $1.amount } }
    var tax: Double { subtotal * taxRate / 100 }
    var total: Double { subtotal + tax }

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
