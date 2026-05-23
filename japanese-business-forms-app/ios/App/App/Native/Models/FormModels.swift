import Foundation
import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case japanese
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var nativeTitle: String {
        switch self {
        case .japanese: return "日本語"
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    var settingsSubtitle: String {
        switch self {
        case .japanese: return "日本の帳票表現"
        case .simplifiedChinese: return "中国大陆用语"
        case .english: return "United States wording"
        }
    }

    var flagIcon: String {
        switch self {
        case .japanese: return "🇯🇵"
        case .simplifiedChinese: return "🇨🇳"
        case .english: return "🇺🇸"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .japanese: return "ja_JP"
        case .simplifiedChinese: return "zh_CN"
        case .english: return "en_US"
        }
    }

    static func from(_ rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .japanese
    }
}

enum AppText {
    static func value(_ key: Key, _ language: AppLanguage) -> String {
        switch (key, language) {
        case (.home, .japanese): return "ホーム"
        case (.home, .simplifiedChinese): return "首页"
        case (.home, .english): return "Home"
        case (.create, .japanese): return "作成"
        case (.create, .simplifiedChinese): return "创建"
        case (.create, .english): return "Create"
        case (.preview, .japanese): return "プレビュー"
        case (.preview, .simplifiedChinese): return "预览"
        case (.preview, .english): return "Preview"
        case (.settings, .japanese): return "設定"
        case (.settings, .simplifiedChinese): return "设置"
        case (.settings, .english): return "Settings"
        case (.projects, .japanese): return "プロジェクト"
        case (.projects, .simplifiedChinese): return "项目"
        case (.projects, .english): return "Projects"
        case (.customers, .japanese): return "取引先"
        case (.customers, .simplifiedChinese): return "客户"
        case (.customers, .english): return "Customers"
        case (.products, .japanese): return "商品"
        case (.products, .simplifiedChinese): return "商品"
        case (.products, .english): return "Products"
        case (.documents, .japanese): return "帳票"
        case (.documents, .simplifiedChinese): return "表单"
        case (.documents, .english): return "Forms"
        case (.searchPrompt, .japanese): return "帳票、取引先、商品を検索"
        case (.searchPrompt, .simplifiedChinese): return "搜索表单、客户、商品"
        case (.searchPrompt, .english): return "Search forms, customers, products"
        case (.customerForms, .japanese): return "顧客向け帳票"
        case (.customerForms, .simplifiedChinese): return "给客户的表单"
        case (.customerForms, .english): return "Customer Forms"
        case (.vendorForms, .japanese): return "仕入先向け帳票"
        case (.vendorForms, .simplifiedChinese): return "给供应商的表单"
        case (.vendorForms, .english): return "Vendor Forms"
        case (.management, .japanese): return "管理"
        case (.management, .simplifiedChinese): return "管理"
        case (.management, .english): return "Management"
        case (.recentDocuments, .japanese): return "最近の帳票"
        case (.recentDocuments, .simplifiedChinese): return "最近表单"
        case (.recentDocuments, .english): return "Recent Forms"
        case (.noSavedDocuments, .japanese): return "保存済みなし"
        case (.noSavedDocuments, .simplifiedChinese): return "没有已保存内容"
        case (.noSavedDocuments, .english): return "No saved forms"
        case (.accountManagement, .japanese): return "設定・アカウント管理"
        case (.accountManagement, .simplifiedChinese): return "设置与账户管理"
        case (.accountManagement, .english): return "Settings and Account"
        case (.accountManagementSubtitle, .japanese): return "表示言語、外観、帳票配色、備份を管理します。"
        case (.accountManagementSubtitle, .simplifiedChinese): return "管理显示语言、外观、表单配色与备份。"
        case (.accountManagementSubtitle, .english): return "Manage language, appearance, form colors, and backups."
        case (.languageSettings, .japanese): return "言語"
        case (.languageSettings, .simplifiedChinese): return "语言"
        case (.languageSettings, .english): return "Language"
        case (.interfaceLanguage, .japanese): return "操作画面の言語"
        case (.interfaceLanguage, .simplifiedChinese): return "操作界面语言"
        case (.interfaceLanguage, .english): return "Interface Language"
        case (.pdfLanguage, .japanese): return "PDF帳票の言語"
        case (.pdfLanguage, .simplifiedChinese): return "PDF 表单语言"
        case (.pdfLanguage, .english): return "PDF Language"
        case (.appearance, .japanese): return "外観"
        case (.appearance, .simplifiedChinese): return "外观"
        case (.appearance, .english): return "Appearance"
        case (.darkMode, .japanese): return "ダークモード"
        case (.darkMode, .simplifiedChinese): return "深色模式"
        case (.darkMode, .english): return "Dark Mode"
        case (.syncButtonColor, .japanese): return "ボタン色を帳票配色に合わせる"
        case (.syncButtonColor, .simplifiedChinese): return "按钮颜色同步表格配色"
        case (.syncButtonColor, .english): return "Match buttons to table color"
        case (.tableColor, .japanese): return "帳票配色"
        case (.tableColor, .simplifiedChinese): return "表格配色"
        case (.tableColor, .english): return "Table Color"
        case (.basicInfo, .japanese): return "基本情報"
        case (.basicInfo, .simplifiedChinese): return "基本信息"
        case (.basicInfo, .english): return "Basic Info"
        case (.businessPartner, .japanese): return "取引先"
        case (.businessPartner, .simplifiedChinese): return "交易对象"
        case (.businessPartner, .english): return "Business Partner"
        case (.issuer, .japanese): return "発行者"
        case (.issuer, .simplifiedChinese): return "开具方"
        case (.issuer, .english): return "Issuer"
        case (.lineItems, .japanese): return "明細"
        case (.lineItems, .simplifiedChinese): return "明细"
        case (.lineItems, .english): return "Line Items"
        case (.notes, .japanese): return "備考"
        case (.notes, .simplifiedChinese): return "备注"
        case (.notes, .english): return "Notes"
        case (.save, .japanese): return "保存"
        case (.save, .simplifiedChinese): return "保存"
        case (.save, .english): return "Save"
        case (.saved, .japanese): return "保存済み"
        case (.saved, .simplifiedChinese): return "已保存"
        case (.saved, .english): return "Saved"
        case (.draftAutosaving, .japanese): return "草稿を自動保存中"
        case (.draftAutosaving, .simplifiedChinese): return "正在自动保存草稿"
        case (.draftAutosaving, .english): return "Autosaving draft"
        case (.saveComplete, .japanese): return "保存が完了しました。"
        case (.saveComplete, .simplifiedChinese): return "保存完成。"
        case (.saveComplete, .english): return "Saved."
        case (.pdfPreview, .japanese): return "PDFプレビュー"
        case (.pdfPreview, .simplifiedChinese): return "PDF 预览"
        case (.pdfPreview, .english): return "PDF Preview"
        case (.savePDF, .japanese): return "PDF保存"
        case (.savePDF, .simplifiedChinese): return "保存 PDF"
        case (.savePDF, .english): return "Save PDF"
        case (.pdfExportError, .japanese): return "PDFを書き出せませんでした。"
        case (.pdfExportError, .simplifiedChinese): return "无法导出 PDF。"
        case (.pdfExportError, .english): return "Could not export PDF."
        case (.previewGenerating, .japanese): return "PNGプレビュー生成中"
        case (.previewGenerating, .simplifiedChinese): return "正在生成 PNG 预览"
        case (.previewGenerating, .english): return "Generating PNG preview"
        case (.previewError, .japanese): return "PNGプレビューを生成できませんでした。"
        case (.previewError, .simplifiedChinese): return "无法生成 PNG 预览。"
        case (.previewError, .english): return "Could not generate PNG preview."
        }
    }

    enum Key {
        case home, create, preview, settings, projects, customers, products
        case documents, searchPrompt, customerForms, vendorForms, management, recentDocuments, noSavedDocuments
        case accountManagement, accountManagementSubtitle, languageSettings, interfaceLanguage, pdfLanguage
        case appearance, darkMode, syncButtonColor, tableColor
        case basicInfo, businessPartner, issuer, lineItems, notes
        case save, saved, draftAutosaving, saveComplete
        case pdfPreview, savePDF, pdfExportError, previewGenerating, previewError
    }
}

enum DocumentType: String, CaseIterable, Identifiable, Codable {
    case estimate
    case customerOrder
    case purchaseOrder
    case delivery
    case invoice
    case receipt
    case acceptance
    case customerFiles
    case vendorEstimate
    case vendorReceipt
    case paymentNotice

    var id: String { rawValue }

    var title: String {
        localizedTitle(.japanese)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .estimate:
            return localized(language, japanese: "見積書", chinese: "报价单", english: "Quote")
        case .customerOrder:
            return localized(language, japanese: "客先注文記録", chinese: "客户订单记录", english: "Customer Order Record")
        case .purchaseOrder:
            return localized(language, japanese: "発注書", chinese: "采购订单", english: "Purchase Order")
        case .delivery:
            return localized(language, japanese: "納品書", chinese: "送货单", english: "Delivery Note")
        case .invoice:
            return localized(language, japanese: "請求書", chinese: "发票", english: "Invoice")
        case .receipt:
            return localized(language, japanese: "領収書", chinese: "收据", english: "Receipt")
        case .acceptance:
            return localized(language, japanese: "受領書", chinese: "收货确认单", english: "Acceptance Receipt")
        case .customerFiles:
            return localized(language, japanese: "プロジェクト管理", chinese: "项目管理", english: "Project Documents")
        case .vendorEstimate:
            return localized(language, japanese: "仕入先見積記録", chinese: "厂商报价单记录", english: "Vendor Quote Record")
        case .vendorReceipt:
            return localized(language, japanese: "仕入先領収書記録", chinese: "厂商收据记录", english: "Vendor Receipt Record")
        case .paymentNotice:
            return localized(language, japanese: "支払通知書", chinese: "支付告知通知书", english: "Payment Notice")
        }
    }

    var subtitle: String {
        localizedSubtitle(.japanese)
    }

    func localizedSubtitle(_ language: AppLanguage) -> String {
        switch self {
        case .estimate: return localized(language, japanese: "Quotation", chinese: "Quotation", english: "Quotation")
        case .customerOrder: return localized(language, japanese: "Customer Order Record", chinese: "Customer Order Record", english: "Customer Order Record")
        case .purchaseOrder: return localized(language, japanese: "Purchase Order", chinese: "Purchase Order", english: "Purchase Order")
        case .delivery: return localized(language, japanese: "Delivery Note", chinese: "Delivery Note", english: "Delivery Note")
        case .invoice: return localized(language, japanese: "Invoice", chinese: "Invoice", english: "Invoice")
        case .receipt: return localized(language, japanese: "Receipt", chinese: "Receipt", english: "Receipt")
        case .acceptance: return localized(language, japanese: "Acceptance Receipt", chinese: "Acceptance Receipt", english: "Acceptance Receipt")
        case .customerFiles: return localized(language, japanese: "Project Documents", chinese: "Project Documents", english: "Project Documents")
        case .vendorEstimate: return localized(language, japanese: "Vendor Quotation", chinese: "Vendor Quotation", english: "Vendor Quotation")
        case .vendorReceipt: return localized(language, japanese: "Vendor Receipt", chinese: "Vendor Receipt", english: "Vendor Receipt")
        case .paymentNotice: return localized(language, japanese: "Payment Notice", chinese: "Payment Notice", english: "Payment Notice")
        }
    }

    var pageTitle: String {
        localizedPageTitle(.japanese)
    }

    func localizedPageTitle(_ language: AppLanguage) -> String {
        switch self {
        case .customerOrder, .vendorEstimate, .vendorReceipt, .paymentNotice:
            return localizedTitle(language)
        case .customerFiles:
            return localized(language, japanese: "プロジェクト管理", chinese: "文件与项目管理", english: "Files and Project Management")
        default:
            switch language {
            case .japanese: return "\(localizedTitle(language))作成"
            case .simplifiedChinese: return "创建\(localizedTitle(language))"
            case .english: return "Create \(localizedTitle(language))"
            }
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
        case .vendorEstimate: return "VEST"
        case .vendorReceipt: return "VRCT"
        case .paymentNotice: return "PAY"
        }
    }

    var totalLabel: String {
        localizedTotalLabel(.japanese)
    }

    func localizedTotalLabel(_ language: AppLanguage) -> String {
        switch self {
        case .estimate: return localized(language, japanese: "御見積金額", chinese: "报价金额", english: "Quote Total")
        case .customerOrder: return localized(language, japanese: "注文金額", chinese: "订单金额", english: "Order Total")
        case .purchaseOrder: return localized(language, japanese: "発注金額", chinese: "采购金额", english: "Purchase Total")
        case .delivery: return localized(language, japanese: "納品金額", chinese: "送货金额", english: "Delivery Total")
        case .invoice: return localized(language, japanese: "ご請求金額", chinese: "应付金额", english: "Amount Due")
        case .receipt: return localized(language, japanese: "領収金額", chinese: "收款金额", english: "Amount Received")
        case .acceptance: return localized(language, japanese: "受領金額", chinese: "收货金额", english: "Accepted Amount")
        case .customerFiles: return localized(language, japanese: "記録金額", chinese: "记录金额", english: "Recorded Amount")
        case .vendorEstimate: return localized(language, japanese: "見積金額", chinese: "报价金额", english: "Quote Total")
        case .vendorReceipt: return localized(language, japanese: "領収金額", chinese: "收款金额", english: "Receipt Amount")
        case .paymentNotice: return localized(language, japanese: "支払通知金額", chinese: "支付通知金额", english: "Payment Notice Amount")
        }
    }

    var isAttachmentRecord: Bool {
        switch self {
        case .customerOrder, .vendorEstimate, .vendorReceipt, .paymentNotice:
            return true
        default:
            return false
        }
    }

    var isVendorForm: Bool {
        switch self {
        case .vendorEstimate, .purchaseOrder, .acceptance, .vendorReceipt, .paymentNotice:
            return true
        default:
            return false
        }
    }

    private func localized(_ language: AppLanguage, japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

enum ProjectDirection: String, CaseIterable, Identifiable, Codable {
    case customer
    case vendor

    var id: String { rawValue }

    var title: String {
        localizedTitle(.japanese)
    }

    var subtitle: String {
        localizedSubtitle(.japanese)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .customer:
            switch language {
            case .japanese: return "顧客向け"
            case .simplifiedChinese: return "给客户"
            case .english: return "Customer"
            }
        case .vendor:
            switch language {
            case .japanese: return "仕入先向け"
            case .simplifiedChinese: return "给供应商"
            case .english: return "Vendor"
            }
        }
    }

    func localizedSubtitle(_ language: AppLanguage) -> String {
        switch self {
        case .customer:
            switch language {
            case .japanese: return "見積・受注・納品・請求・領収"
            case .simplifiedChinese: return "报价、订单、送货、发票、收据"
            case .english: return "Quote, order, delivery, invoice, receipt"
            }
        case .vendor:
            switch language {
            case .japanese: return "見積記録・発注・受領・領収・支払通知"
            case .simplifiedChinese: return "报价记录、采购、收货、收据、付款通知"
            case .english: return "Quote record, purchase, acceptance, receipt, payment notice"
            }
        }
    }

    var requiredTypes: [DocumentType] {
        switch self {
        case .customer: return [.estimate, .customerOrder, .delivery, .invoice, .receipt]
        case .vendor: return [.vendorEstimate, .purchaseOrder, .acceptance, .vendorReceipt, .paymentNotice]
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

    var customerOrderRecords: [BusinessDocument] {
        documents
            .filter { $0.type == .customerOrder }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func document(for type: DocumentType) -> BusinessDocument? {
        documents(for: type).first
    }

    func documents(for type: DocumentType) -> [BusinessDocument] {
        documents
            .filter { $0.type == type }
            .sorted { $0.updatedAt > $1.updatedAt }
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

struct OrderAttachment: Identifiable, Codable, Equatable {
    var id = UUID()
    var filename = ""
    var contentType = ""
    var data = Data()
    var uploadedAt = Date()

    var isPDF: Bool {
        contentType == "application/pdf" || filename.lowercased().hasSuffix(".pdf")
    }

    var isImage: Bool {
        contentType.hasPrefix("image/")
    }

    var fileSizeText: String {
        let bytes = Double(data.count)
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", bytes / 1_048_576)
        }
        if bytes >= 1_024 {
            return "\(Int(bytes / 1_024)) KB"
        }
        return "\(data.count) B"
    }
}

struct CustomerProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var contact = ""
    var phone: String?
    var email: String?
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

enum TextTemplateKind: String, CaseIterable, Identifiable, Codable {
    case payment
    case note
    case condition

    var id: String { rawValue }

    var title: String {
        localizedTitle(.japanese)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .payment:
            switch language {
            case .japanese: return "振込口座"
            case .simplifiedChinese: return "汇款账户"
            case .english: return "Payment Account"
            }
        case .note:
            switch language {
            case .japanese: return "備考"
            case .simplifiedChinese: return "备注"
            case .english: return "Notes"
            }
        case .condition:
            switch language {
            case .japanese: return "条件"
            case .simplifiedChinese: return "条件"
            case .english: return "Terms"
            }
        }
    }

    var subtitle: String {
        localizedSubtitle(.japanese)
    }

    func localizedSubtitle(_ language: AppLanguage) -> String {
        switch self {
        case .payment:
            switch language {
            case .japanese: return "振込先口座"
            case .simplifiedChinese: return "收款账户"
            case .english: return "Bank transfer details"
            }
        case .note:
            switch language {
            case .japanese: return "帳票に表示する備考"
            case .simplifiedChinese: return "显示在表单上的备注"
            case .english: return "Notes shown on forms"
            }
        case .condition:
            switch language {
            case .japanese: return "取引条件"
            case .simplifiedChinese: return "交易条件"
            case .english: return "Business terms"
            }
        }
    }

    var systemImage: String {
        switch self {
        case .payment: return "banknote"
        case .note: return "text.alignleft"
        case .condition: return "checklist"
        }
    }
}

struct TextTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: TextTemplateKind = .note
    var title = ""
    var content = ""
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
    var customerPhone: String?
    var customerEmail: String?

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
    var orderAttachments: [OrderAttachment]?
    var paymentProofDate: Date?
    var paymentProofAmount: Double?
    var paymentProofAttachments: [OrderAttachment]?
    var googleDrivePDFFileID: String?
    var googleDriveJSONFileID: String?
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
        if type.isVendorForm {
            document.paymentProofDate = document.transactionDate
            document.paymentProofAmount = document.total
            document.paymentProofAttachments = []
        }
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
        case .vendorEstimate: return "仕入先から受領した見積書ファイルを添付し、プロジェクト・日時・番号を記録してください。"
        case .vendorReceipt: return "仕入先から受領した領収書ファイルを添付し、プロジェクト・日時・番号を記録してください。"
        case .paymentNotice: return "支払告知・支払通知書ファイルを添付し、プロジェクト・日時・番号を記録してください。"
        }
    }

    private static func defaultMemo(for type: DocumentType) -> String {
        switch type {
        case .customerFiles: return "見積書、請求書、領収書などを同じ画面で管理します。"
        case .customerOrder: return "受領した注文ファイル、希望納期、関連見積番号を確認してください。"
        case .vendorEstimate: return "仕入先見積書、現場写真、LINE截圖、契約関連資料をまとめて保存します。"
        case .vendorReceipt: return "領収書、支払証憑、関連する確認資料をまとめて保存します。"
        case .paymentNotice: return "支払告知通知書、支払予定、関連証憑をまとめて保存します。"
        default: return ""
        }
    }
}
