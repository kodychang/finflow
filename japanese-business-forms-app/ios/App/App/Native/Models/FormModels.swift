import Foundation
import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case japanese
    case simplifiedChinese
    case traditionalChinese
    case english
    case korean
    case nepali
    case french
    case vietnamese

    var id: String { rawValue }

    var nativeTitle: String {
        switch self {
        case .japanese: return "日本語"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .korean: return "한국어"
        case .nepali: return "नेपाली"
        case .french: return "Français"
        case .vietnamese: return "Tiếng Việt"
        }
    }

    var settingsSubtitle: String {
        switch self {
        case .japanese: return "日本の帳票表現"
        case .simplifiedChinese: return "中国大陆用语"
        case .traditionalChinese: return "繁體中文用語"
        case .english: return "United States wording"
        case .korean: return "한국어 업무 양식 표현"
        case .nepali: return "नेपाली इन्टरफेस"
        case .french: return "Interface en français"
        case .vietnamese: return "Giao diện tiếng Việt"
        }
    }

    var flagIcon: String {
        switch self {
        case .japanese: return "🇯🇵"
        case .simplifiedChinese: return "🇨🇳"
        case .traditionalChinese: return "🇹🇼"
        case .english: return "🇺🇸"
        case .korean: return "🇰🇷"
        case .nepali: return "🇳🇵"
        case .french: return "🇫🇷"
        case .vietnamese: return "🇻🇳"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .japanese: return "ja_JP"
        case .simplifiedChinese: return "zh_CN"
        case .traditionalChinese: return "zh_TW"
        case .english: return "en_US"
        case .korean: return "ko_KR"
        case .nepali: return "ne_NP"
        case .french: return "fr_FR"
        case .vietnamese: return "vi_VN"
        }
    }

    static func from(_ rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .japanese
    }

    static var systemDefault: AppLanguage {
        fromPreferredLanguages(Locale.preferredLanguages)
    }

    static func fromPreferredLanguages(_ identifiers: [String]) -> AppLanguage {
        for identifier in identifiers {
            let normalized = identifier.lowercased()
            if normalized.hasPrefix("ko") { return .korean }
            if normalized.hasPrefix("zh-hant") || normalized.hasPrefix("zh_tw") || normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh_hk") || normalized.hasPrefix("zh-hk") { return .traditionalChinese }
            if normalized.hasPrefix("zh") { return .simplifiedChinese }
            if normalized.hasPrefix("ja") { return .japanese }
            if normalized.hasPrefix("ne") { return .nepali }
            if normalized.hasPrefix("fr") { return .french }
            if normalized.hasPrefix("vi") { return .vietnamese }
            if normalized.hasPrefix("en") { return .english }
        }
        return .japanese
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
        case (let key, .korean): return koreanValue(key)
        case (let key, .traditionalChinese): return traditionalChineseValue(key)
        case (let key, .nepali): return nepaliValue(key)
        case (let key, .french): return frenchValue(key)
        case (let key, .vietnamese): return vietnameseValue(key)
        }
    }

    private static func traditionalChineseValue(_ key: Key) -> String {
        switch key {
        case .home: return "首頁"
        case .create: return "建立"
        case .preview: return "預覽"
        case .settings: return "設定"
        case .projects: return "專案"
        case .customers: return "客戶"
        case .products: return "商品"
        case .documents: return "表單"
        case .searchPrompt: return "搜尋表單、客戶、商品"
        case .customerForms: return "客戶表單"
        case .vendorForms: return "供應商表單"
        case .management: return "管理"
        case .recentDocuments: return "最近表單"
        case .noSavedDocuments: return "沒有已儲存表單"
        case .accountManagement: return "設定與帳戶"
        case .accountManagementSubtitle: return "管理語言、外觀、表單配色與備份。"
        case .languageSettings: return "語言"
        case .interfaceLanguage: return "操作介面語言"
        case .pdfLanguage: return "PDF 表單語言"
        case .appearance: return "外觀"
        case .darkMode: return "深色模式"
        case .syncButtonColor: return "按鈕顏色同步表單配色"
        case .tableColor: return "表單配色"
        case .basicInfo: return "基本資訊"
        case .businessPartner: return "交易對象"
        case .issuer: return "開立方"
        case .lineItems: return "明細"
        case .notes: return "備註"
        case .save: return "儲存"
        case .saved: return "已儲存"
        case .draftAutosaving: return "正在自動儲存草稿"
        case .saveComplete: return "儲存完成。"
        case .pdfPreview: return "PDF 預覽"
        case .savePDF: return "儲存 PDF"
        case .pdfExportError: return "無法匯出 PDF。"
        case .previewGenerating: return "正在產生 PNG 預覽"
        case .previewError: return "無法產生 PNG 預覽。"
        }
    }

    private static func nepaliValue(_ key: Key) -> String {
        switch key {
        case .home: return "गृह"
        case .create: return "बनाउनुहोस्"
        case .preview: return "पूर्वावलोकन"
        case .settings: return "सेटिङ"
        case .projects: return "परियोजना"
        case .customers: return "ग्राहक"
        case .products: return "उत्पादन"
        case .documents: return "फारम"
        case .searchPrompt: return "फारम, ग्राहक, उत्पादन खोज्नुहोस्"
        case .customerForms: return "ग्राहक फारम"
        case .vendorForms: return "आपूर्तिकर्ता फारम"
        case .management: return "व्यवस्थापन"
        case .recentDocuments: return "हालका फारम"
        case .noSavedDocuments: return "सुरक्षित फारम छैन"
        case .accountManagement: return "सेटिङ र खाता"
        case .accountManagementSubtitle: return "भाषा, रूप, फारम रङ र ब्याकअप व्यवस्थापन गर्नुहोस्।"
        case .languageSettings: return "भाषा"
        case .interfaceLanguage: return "इन्टरफेस भाषा"
        case .pdfLanguage: return "PDF भाषा"
        case .appearance: return "रूप"
        case .darkMode: return "डार्क मोड"
        case .syncButtonColor: return "बटन रङ फारम रङसँग मिलाउनुहोस्"
        case .tableColor: return "तालिका रङ"
        case .basicInfo: return "आधारभूत जानकारी"
        case .businessPartner: return "व्यापार साझेदार"
        case .issuer: return "जारीकर्ता"
        case .lineItems: return "वस्तुहरू"
        case .notes: return "टिप्पणी"
        case .save: return "सुरक्षित गर्नुहोस्"
        case .saved: return "सुरक्षित भयो"
        case .draftAutosaving: return "मस्यौदा स्वतः सुरक्षित हुँदैछ"
        case .saveComplete: return "सुरक्षित भयो।"
        case .pdfPreview: return "PDF पूर्वावलोकन"
        case .savePDF: return "PDF सुरक्षित गर्नुहोस्"
        case .pdfExportError: return "PDF निर्यात गर्न सकिएन।"
        case .previewGenerating: return "PNG पूर्वावलोकन बनाउँदै"
        case .previewError: return "PNG पूर्वावलोकन बनाउन सकिएन।"
        }
    }

    private static func frenchValue(_ key: Key) -> String {
        switch key {
        case .home: return "Accueil"
        case .create: return "Créer"
        case .preview: return "Aperçu"
        case .settings: return "Réglages"
        case .projects: return "Projets"
        case .customers: return "Clients"
        case .products: return "Produits"
        case .documents: return "Formulaires"
        case .searchPrompt: return "Rechercher formulaires, clients, produits"
        case .customerForms: return "Formulaires client"
        case .vendorForms: return "Formulaires fournisseur"
        case .management: return "Gestion"
        case .recentDocuments: return "Formulaires récents"
        case .noSavedDocuments: return "Aucun formulaire enregistré"
        case .accountManagement: return "Réglages et compte"
        case .accountManagementSubtitle: return "Gérer la langue, l'apparence, les couleurs et les sauvegardes."
        case .languageSettings: return "Langue"
        case .interfaceLanguage: return "Langue de l'interface"
        case .pdfLanguage: return "Langue du PDF"
        case .appearance: return "Apparence"
        case .darkMode: return "Mode sombre"
        case .syncButtonColor: return "Adapter les boutons à la couleur du formulaire"
        case .tableColor: return "Couleur du tableau"
        case .basicInfo: return "Infos de base"
        case .businessPartner: return "Partenaire"
        case .issuer: return "Émetteur"
        case .lineItems: return "Lignes"
        case .notes: return "Notes"
        case .save: return "Enregistrer"
        case .saved: return "Enregistré"
        case .draftAutosaving: return "Enregistrement automatique du brouillon"
        case .saveComplete: return "Enregistré."
        case .pdfPreview: return "Aperçu PDF"
        case .savePDF: return "Enregistrer le PDF"
        case .pdfExportError: return "Impossible d'exporter le PDF."
        case .previewGenerating: return "Génération de l'aperçu PNG"
        case .previewError: return "Impossible de générer l'aperçu PNG."
        }
    }

    private static func vietnameseValue(_ key: Key) -> String {
        switch key {
        case .home: return "Trang chủ"
        case .create: return "Tạo"
        case .preview: return "Xem trước"
        case .settings: return "Cài đặt"
        case .projects: return "Dự án"
        case .customers: return "Khách hàng"
        case .products: return "Sản phẩm"
        case .documents: return "Biểu mẫu"
        case .searchPrompt: return "Tìm biểu mẫu, khách hàng, sản phẩm"
        case .customerForms: return "Biểu mẫu khách hàng"
        case .vendorForms: return "Biểu mẫu nhà cung cấp"
        case .management: return "Quản lý"
        case .recentDocuments: return "Biểu mẫu gần đây"
        case .noSavedDocuments: return "Chưa có biểu mẫu đã lưu"
        case .accountManagement: return "Cài đặt và tài khoản"
        case .accountManagementSubtitle: return "Quản lý ngôn ngữ, giao diện, màu biểu mẫu và sao lưu."
        case .languageSettings: return "Ngôn ngữ"
        case .interfaceLanguage: return "Ngôn ngữ giao diện"
        case .pdfLanguage: return "Ngôn ngữ PDF"
        case .appearance: return "Giao diện"
        case .darkMode: return "Chế độ tối"
        case .syncButtonColor: return "Đồng bộ màu nút với màu biểu mẫu"
        case .tableColor: return "Màu bảng"
        case .basicInfo: return "Thông tin cơ bản"
        case .businessPartner: return "Đối tác"
        case .issuer: return "Bên phát hành"
        case .lineItems: return "Chi tiết"
        case .notes: return "Ghi chú"
        case .save: return "Lưu"
        case .saved: return "Đã lưu"
        case .draftAutosaving: return "Đang tự động lưu bản nháp"
        case .saveComplete: return "Đã lưu."
        case .pdfPreview: return "Xem trước PDF"
        case .savePDF: return "Lưu PDF"
        case .pdfExportError: return "Không thể xuất PDF."
        case .previewGenerating: return "Đang tạo xem trước PNG"
        case .previewError: return "Không thể tạo xem trước PNG."
        }
    }

    private static func koreanValue(_ key: Key) -> String {
        switch key {
        case .home: return "홈"
        case .create: return "작성"
        case .preview: return "미리보기"
        case .settings: return "설정"
        case .projects: return "프로젝트"
        case .customers: return "거래처"
        case .products: return "상품"
        case .documents: return "양식"
        case .searchPrompt: return "양식, 거래처, 상품 검색"
        case .customerForms: return "고객용 양식"
        case .vendorForms: return "공급업체용 양식"
        case .management: return "관리"
        case .recentDocuments: return "최근 양식"
        case .noSavedDocuments: return "저장된 양식 없음"
        case .accountManagement: return "설정 및 계정"
        case .accountManagementSubtitle: return "언어, 화면 표시, 양식 색상과 백업을 관리합니다."
        case .languageSettings: return "언어"
        case .interfaceLanguage: return "앱 화면 언어"
        case .pdfLanguage: return "PDF 양식 언어"
        case .appearance: return "화면 표시"
        case .darkMode: return "다크 모드"
        case .syncButtonColor: return "버튼 색상을 양식 색상에 맞추기"
        case .tableColor: return "양식 색상"
        case .basicInfo: return "기본 정보"
        case .businessPartner: return "거래처"
        case .issuer: return "발행자"
        case .lineItems: return "상세 항목"
        case .notes: return "비고"
        case .save: return "저장"
        case .saved: return "저장됨"
        case .draftAutosaving: return "초안 자동 저장 중"
        case .saveComplete: return "저장되었습니다."
        case .pdfPreview: return "PDF 미리보기"
        case .savePDF: return "PDF 저장"
        case .pdfExportError: return "PDF를 내보낼 수 없습니다."
        case .previewGenerating: return "PNG 미리보기 생성 중"
        case .previewError: return "PNG 미리보기를 생성할 수 없습니다."
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

enum AppInlineLocalization {
    static func value(english: String, chinese: String, language: AppLanguage) -> String {
        switch language {
        case .traditionalChinese:
            return traditionalChinese[english] ?? convertToTraditionalChinese(chinese)
        case .nepali:
            return nepali[english] ?? english
        case .french:
            return french[english] ?? english
        case .vietnamese:
            return vietnamese[english] ?? english
        default:
            return english
        }
    }

    private static func convertToTraditionalChinese(_ text: String) -> String {
        var result = text
        for (source, target) in traditionalReplacements {
            result = result.replacingOccurrences(of: source, with: target)
        }
        return result
    }

    private static let traditionalReplacements: [(String, String)] = [
        ("数据", "資料"), ("资料", "資料"), ("文件", "檔案"), ("表单", "表單"), ("项目", "專案"),
        ("客户", "客戶"), ("供应商", "供應商"), ("厂商", "廠商"), ("产品", "產品"), ("商品", "商品"),
        ("品项", "品項"), ("模板", "範本"), ("设置", "設定"), ("导览", "導覽"), ("说明", "說明"),
        ("订阅", "訂閱"), ("备份", "備份"), ("预览", "預覽"), ("输出", "輸出"), ("共享", "分享"),
        ("汇款", "匯款"), ("备注", "備註"), ("条件", "條件"), ("编号", "編號"), ("登记", "登記"),
        ("联系", "聯絡"), ("邮箱", "信箱"), ("电话", "電話"), ("地址", "地址"), ("删除", "刪除"),
        ("恢复", "復原"), ("还原", "還原"), ("覆盖", "覆蓋"), ("无法", "無法"), ("读取", "讀取"),
        ("导入", "匯入"), ("上传", "上傳"), ("同步", "同步"), ("登录", "登入"), ("退出", "登出"),
        ("启用", "啟用"), ("隐藏", "隱藏"), ("显示", "顯示"), ("选择", "選擇"), ("创建", "建立"),
        ("新增", "新增"), ("编辑", "編輯"), ("保存", "儲存"), ("已保存", "已儲存"), ("机", "機"),
        ("这", "這"), ("个", "個"), ("会", "會"), ("后", "後"), ("内", "內"), ("从", "從"),
        ("与", "與"), ("为", "為"), ("优先", "優先"), ("请", "請"), ("税", "稅"), ("发票", "發票"),
        ("付款", "付款"), ("请款", "請款"), ("收据", "收據"), ("电子", "電子"), ("帐簿", "帳簿"),
        ("资讯", "資訊"), ("信息", "資訊"), ("经营者", "經營者"), ("购买", "購買"), ("财务", "財務"),
        ("技术", "技術"), ("问题", "問題"), ("页面", "頁面"), ("视频", "影片"), ("教程", "教學"),
        ("工作流", "工作流程"), ("确认", "確認"), ("清除", "清除"), ("彻底", "徹底")
    ]

    private static let traditionalChinese: [String: String] = [
        "Data Management": "資料管理",
        "Manage company, files, projects, customers, products, and templates.": "管理公司、檔案、專案、客戶、商品與範本。",
        "Management Menu": "管理選單",
        "Company": "公司",
        "File Management": "檔案管理",
        "Templates": "範本",
        "Stamp Management": "印章管理",
        "Company details and registration": "公司資訊、登記編號與聯絡方式",
        "Browse saved forms by partner": "依客戶/供應商整理已儲存表單",
        "Track forms by project": "依專案追蹤表單進度",
        "Customer and vendor profiles": "客戶與供應商候選資料",
        "Product and item profiles": "商品與品項候選資料",
        "Payment, notes, and terms": "匯款、備註與條件文字",
        "Default stamp for PDF stamping": "PDF 蓋章用預設印章",
        "Customer and Vendor Management": "客戶/供應商管理",
        "Saved customers and vendors appear as suggestions when entering company names.": "輸入公司名稱時，會顯示這裡儲存的客戶/供應商候選項。",
        "Customers and Vendors": "客戶/供應商列表",
        "No saved customers or vendors. Use the add button to register one.": "尚未儲存客戶/供應商。請使用新增按鈕登錄。",
        "Add Customer or Vendor": "新增客戶/供應商資料",
        "Edit Customer or Vendor": "編輯客戶/供應商資料",
        "Company / Name": "公司名稱 / 姓名",
        "Sample Co., Ltd.": "範例有限公司",
        "Accounting Team": "財務部",
        "Save Customer or Vendor": "儲存客戶/供應商資料",
        "Update Customer or Vendor": "更新客戶/供應商資料",
        "Used by Saved Forms": "已被儲存表單使用",
        "Create New Data": "建立全新資料",
        "Update Existing Data": "更新現有資料",
        "Delete Candidate Data": "刪除候選資料",
        "Product and Item Management": "商品/品項管理",
        "Save product names, models, specifications, and unit prices for line item entry.": "儲存輸入明細時使用的商品名、型號、規格與單價候選項。",
        "Products and Items": "商品/品項列表",
        "No saved products or items. Use the add button to register one.": "尚未儲存商品/品項。請使用新增按鈕登錄。",
        "Add Item Information": "新增品項資訊",
        "Edit Item Information": "編輯品項資訊",
        "Item Name": "品項名稱",
        "Specification": "規格",
        "Model": "型號",
        "Unit Price": "單價",
        "Save Item Information": "儲存品項資訊",
        "Update Item Information": "更新品項資訊",
        "Payment and Note Templates": "匯款與備註範本",
        "Save payment accounts, notes, and terms for reuse while editing forms.": "儲存匯款帳戶、備註與條件，編輯表單時可重複使用。",
        "Add Template": "新增範本",
        "Edit Template": "編輯範本",
        "Category": "分類",
        "Template Name": "範本名稱",
        "Example: Bank Account / Standard Notes": "例：銀行帳戶 / 標準備註",
        "Content": "內容",
        "Save Template": "儲存範本",
        "Update Template": "更新範本",
        "Subscription and Pro": "訂閱與 Pro",
        "Manage Pro": "Pro 管理",
        "Active": "已啟用",
        "Preview sharing and Google Drive backup": "預覽分享與 Google Drive 備份",
        "Local Backup": "本機備份",
        "Clear Data": "清除資料",
        "Clear This Device's App Data": "清除本機 App 資料",
        "First Guide": "首次導覽",
        "Load Demo Test Data": "載入測試示範資料",
        "Load Demo Test Data?": "要載入測試示範資料嗎？",
        "Start with the Basics": "先了解基本用法",
        "Create Company Information": "建立公司資訊",
        "Create Product Information": "建立產品資訊",
        "Create Customer Information": "建立客戶資訊",
        "Create a Form": "建立表單",
        "Preview": "預覽",
        "Electronic Bookkeeping Guide": "電子帳簿等保存制度說明",
        "What the App Supports": "App 支援內容",
        "By Form Type": "依表單類型",
        "Notes": "注意事項",
        "Start Guide": "開始導覽"
    ]

    private static let nepali: [String: String] = [
        "Data Management": "डाटा व्यवस्थापन",
        "Manage company, files, projects, customers, products, and templates.": "कम्पनी, फाइल, परियोजना, ग्राहक, उत्पादन र टेम्प्लेट व्यवस्थापन गर्नुहोस्।",
        "Management Menu": "व्यवस्थापन मेनु",
        "Company": "कम्पनी",
        "File Management": "फाइल व्यवस्थापन",
        "Templates": "टेम्प्लेट",
        "Stamp Management": "छाप व्यवस्थापन",
        "Company details and registration": "कम्पनी विवरण र दर्ता",
        "Browse saved forms by partner": "साझेदार अनुसार सुरक्षित फारम हेर्नुहोस्",
        "Track forms by project": "परियोजना अनुसार फारम ट्र्याक गर्नुहोस्",
        "Customer and vendor profiles": "ग्राहक र आपूर्तिकर्ता प्रोफाइल",
        "Product and item profiles": "उत्पादन र वस्तु प्रोफाइल",
        "Payment, notes, and terms": "भुक्तानी, नोट र सर्तहरू",
        "Default stamp for PDF stamping": "PDF छापका लागि पूर्वनिर्धारित छाप",
        "Customer and Vendor Management": "ग्राहक र आपूर्तिकर्ता व्यवस्थापन",
        "Saved customers and vendors appear as suggestions when entering company names.": "कम्पनी नाम लेख्दा सुरक्षित ग्राहक र आपूर्तिकर्ता सुझावका रूपमा देखिन्छन्।",
        "Customers and Vendors": "ग्राहक र आपूर्तिकर्ता",
        "No saved customers or vendors. Use the add button to register one.": "सुरक्षित ग्राहक वा आपूर्तिकर्ता छैन। थप्ने बटनबाट दर्ता गर्नुहोस्।",
        "Add": "थप्नुहोस्",
        "Use": "प्रयोग गर्नुहोस्",
        "Edit": "सम्पादन",
        "Cancel": "रद्द",
        "Add Customer or Vendor": "ग्राहक वा आपूर्तिकर्ता थप्नुहोस्",
        "Edit Customer or Vendor": "ग्राहक वा आपूर्तिकर्ता सम्पादन गर्नुहोस्",
        "Company / Name": "कम्पनी / नाम",
        "Sample Co., Ltd.": "Sample Co., Ltd.",
        "Contact": "सम्पर्क व्यक्ति",
        "Accounting Team": "लेखा टोली",
        "Phone": "फोन",
        "Email": "इमेल",
        "Address": "ठेगाना",
        "Save Customer or Vendor": "ग्राहक वा आपूर्तिकर्ता सुरक्षित गर्नुहोस्",
        "Update Customer or Vendor": "ग्राहक वा आपूर्तिकर्ता अद्यावधिक गर्नुहोस्",
        "Used by Saved Forms": "सुरक्षित फारमहरूले प्रयोग गरेको",
        "Create New Data": "नयाँ डाटा बनाउनुहोस्",
        "Update Existing Data": "हालको डाटा अद्यावधिक गर्नुहोस्",
        "Delete Candidate Data": "उम्मेदवार डाटा मेटाउनुहोस्",
        "Product and Item Management": "उत्पादन र वस्तु व्यवस्थापन",
        "Save product names, models, specifications, and unit prices for line item entry.": "लाइन आइटमका लागि उत्पादन नाम, मोडेल, विशिष्टता र एकाइ मूल्य सुरक्षित गर्नुहोस्।",
        "Products and Items": "उत्पादन र वस्तुहरू",
        "No saved products or items. Use the add button to register one.": "सुरक्षित उत्पादन वा वस्तु छैन। थप्ने बटनबाट दर्ता गर्नुहोस्।",
        "Add Item Information": "वस्तु जानकारी थप्नुहोस्",
        "Edit Item Information": "वस्तु जानकारी सम्पादन गर्नुहोस्",
        "Item Name": "वस्तु नाम",
        "Item": "वस्तु",
        "Specification": "विशिष्टता",
        "Model": "मोडेल",
        "Unit Price": "एकाइ मूल्य",
        "Save Item Information": "वस्तु जानकारी सुरक्षित गर्नुहोस्",
        "Update Item Information": "वस्तु जानकारी अद्यावधिक गर्नुहोस्",
        "Payment and Note Templates": "भुक्तानी र नोट टेम्प्लेट",
        "Save payment accounts, notes, and terms for reuse while editing forms.": "फारम सम्पादन गर्दा पुन: प्रयोग गर्न भुक्तानी खाता, नोट र सर्त सुरक्षित गर्नुहोस्।",
        "Add Template": "टेम्प्लेट थप्नुहोस्",
        "Edit Template": "टेम्प्लेट सम्पादन गर्नुहोस्",
        "Category": "वर्ग",
        "Template Name": "टेम्प्लेट नाम",
        "Example: Bank Account / Standard Notes": "उदाहरण: बैंक खाता / मानक नोट",
        "Content": "सामग्री",
        "Save Template": "टेम्प्लेट सुरक्षित गर्नुहोस्",
        "Update Template": "टेम्प्लेट अद्यावधिक गर्नुहोस्",
        "Subscription and Pro": "सदस्यता र Pro",
        "Manage Pro": "Pro व्यवस्थापन",
        "Active": "सक्रिय",
        "Preview sharing and Google Drive backup": "पूर्वावलोकन साझेदारी र Google Drive ब्याकअप",
        "Local Backup": "स्थानीय ब्याकअप",
        "Clear Data": "डाटा हटाउनुहोस्",
        "Clear This Device's App Data": "यस उपकरणको App डाटा हटाउनुहोस्",
        "First Guide": "पहिलो मार्गदर्शन",
        "Load Demo Test Data": "डेमो परीक्षण डाटा लोड गर्नुहोस्",
        "Load Demo Test Data?": "डेमो परीक्षण डाटा लोड गर्ने?",
        "Back": "पछाडि",
        "Next": "अर्को",
        "Finish": "समाप्त",
        "Close": "बन्द",
        "Start with the Basics": "आधारभूतबाट सुरु गर्नुहोस्",
        "Create Company Information": "कम्पनी जानकारी बनाउनुहोस्",
        "Create Product Information": "उत्पादन जानकारी बनाउनुहोस्",
        "Create Customer Information": "ग्राहक जानकारी बनाउनुहोस्",
        "Create a Form": "फारम बनाउनुहोस्",
        "Preview": "पूर्वावलोकन",
        "Electronic Bookkeeping Guide": "इलेक्ट्रोनिक बहीखाता मार्गदर्शन",
        "What the App Supports": "App ले समर्थन गर्ने कुरा",
        "By Form Type": "फारम प्रकार अनुसार",
        "Notes": "नोटहरू",
        "Start Guide": "मार्गदर्शन सुरु गर्नुहोस्"
    ]

    private static let french: [String: String] = [
        "Data Management": "Gestion des donnees",
        "Manage company, files, projects, customers, products, and templates.": "Gerez l'entreprise, les fichiers, les projets, les clients, les produits et les modeles.",
        "Management Menu": "Menu de gestion",
        "Company": "Entreprise",
        "File Management": "Gestion des fichiers",
        "Templates": "Modeles",
        "Stamp Management": "Gestion du cachet",
        "Company details and registration": "Details de l'entreprise et immatriculation",
        "Browse saved forms by partner": "Parcourir les formulaires enregistres par partenaire",
        "Track forms by project": "Suivre les formulaires par projet",
        "Customer and vendor profiles": "Profils clients et fournisseurs",
        "Product and item profiles": "Profils produits et articles",
        "Payment, notes, and terms": "Paiement, notes et conditions",
        "Default stamp for PDF stamping": "Cachet par defaut pour les PDF",
        "Customer and Vendor Management": "Gestion clients et fournisseurs",
        "Saved customers and vendors appear as suggestions when entering company names.": "Les clients et fournisseurs enregistres apparaissent comme suggestions lors de la saisie du nom d'entreprise.",
        "Customers and Vendors": "Clients et fournisseurs",
        "No saved customers or vendors. Use the add button to register one.": "Aucun client ou fournisseur enregistre. Utilisez le bouton d'ajout pour en creer un.",
        "Add": "Ajouter",
        "Use": "Utiliser",
        "Edit": "Modifier",
        "Cancel": "Annuler",
        "Add Customer or Vendor": "Ajouter un client ou fournisseur",
        "Edit Customer or Vendor": "Modifier un client ou fournisseur",
        "Company / Name": "Entreprise / Nom",
        "Sample Co., Ltd.": "Societe exemple",
        "Contact": "Contact",
        "Accounting Team": "Equipe comptable",
        "Phone": "Telephone",
        "Email": "E-mail",
        "Address": "Adresse",
        "Save Customer or Vendor": "Enregistrer le client ou fournisseur",
        "Update Customer or Vendor": "Mettre a jour le client ou fournisseur",
        "Used by Saved Forms": "Utilise par des formulaires enregistres",
        "Create New Data": "Creer de nouvelles donnees",
        "Update Existing Data": "Mettre a jour les donnees existantes",
        "Delete Candidate Data": "Supprimer les donnees candidates",
        "Product and Item Management": "Gestion produits et articles",
        "Save product names, models, specifications, and unit prices for line item entry.": "Enregistrez les noms, modeles, specifications et prix unitaires pour la saisie des lignes.",
        "Products and Items": "Produits et articles",
        "No saved products or items. Use the add button to register one.": "Aucun produit ou article enregistre. Utilisez le bouton d'ajout pour en creer un.",
        "Add Item Information": "Ajouter les informations d'article",
        "Edit Item Information": "Modifier les informations d'article",
        "Item Name": "Nom de l'article",
        "Item": "Article",
        "Specification": "Specification",
        "Model": "Modele",
        "Unit Price": "Prix unitaire",
        "Save Item Information": "Enregistrer les informations d'article",
        "Update Item Information": "Mettre a jour les informations d'article",
        "Payment and Note Templates": "Modeles de paiement et de notes",
        "Save payment accounts, notes, and terms for reuse while editing forms.": "Enregistrez comptes de paiement, notes et conditions pour les reutiliser dans les formulaires.",
        "Add Template": "Ajouter un modele",
        "Edit Template": "Modifier le modele",
        "Category": "Categorie",
        "Template Name": "Nom du modele",
        "Example: Bank Account / Standard Notes": "Exemple : compte bancaire / notes standard",
        "Content": "Contenu",
        "Save Template": "Enregistrer le modele",
        "Update Template": "Mettre a jour le modele",
        "Subscription and Pro": "Abonnement et Pro",
        "Manage Pro": "Gerer Pro",
        "Active": "Actif",
        "Preview sharing and Google Drive backup": "Partage d'apercu et sauvegarde Google Drive",
        "Local Backup": "Sauvegarde locale",
        "Clear Data": "Effacer les donnees",
        "Clear This Device's App Data": "Effacer les donnees App de cet appareil",
        "First Guide": "Premier guide",
        "Load Demo Test Data": "Charger les donnees de demo",
        "Load Demo Test Data?": "Charger les donnees de demo ?",
        "Back": "Retour",
        "Next": "Suivant",
        "Finish": "Terminer",
        "Close": "Fermer",
        "Start with the Basics": "Commencer par les bases",
        "Create Company Information": "Creer les informations d'entreprise",
        "Create Product Information": "Creer les informations produit",
        "Create Customer Information": "Creer les informations client",
        "Create a Form": "Creer un formulaire",
        "Preview": "Apercu",
        "Electronic Bookkeeping Guide": "Guide de conservation comptable electronique",
        "What the App Supports": "Fonctions prises en charge",
        "By Form Type": "Par type de formulaire",
        "Notes": "Notes",
        "Start Guide": "Demarrer le guide"
    ]

    private static let vietnamese: [String: String] = [
        "Data Management": "Quan ly du lieu",
        "Manage company, files, projects, customers, products, and templates.": "Quan ly cong ty, tep, du an, khach hang, san pham va mau.",
        "Management Menu": "Menu quan ly",
        "Company": "Cong ty",
        "File Management": "Quan ly tep",
        "Templates": "Mau",
        "Stamp Management": "Quan ly con dau",
        "Company details and registration": "Thong tin cong ty va dang ky",
        "Browse saved forms by partner": "Xem bieu mau da luu theo doi tac",
        "Track forms by project": "Theo doi bieu mau theo du an",
        "Customer and vendor profiles": "Ho so khach hang va nha cung cap",
        "Product and item profiles": "Ho so san pham va hang muc",
        "Payment, notes, and terms": "Thanh toan, ghi chu va dieu kien",
        "Default stamp for PDF stamping": "Con dau mac dinh cho PDF",
        "Customer and Vendor Management": "Quan ly khach hang va nha cung cap",
        "Saved customers and vendors appear as suggestions when entering company names.": "Khach hang va nha cung cap da luu se hien goi y khi nhap ten cong ty.",
        "Customers and Vendors": "Khach hang va nha cung cap",
        "No saved customers or vendors. Use the add button to register one.": "Chua co khach hang hoac nha cung cap da luu. Hay dung nut them de dang ky.",
        "Add": "Them",
        "Use": "Dung",
        "Edit": "Sua",
        "Cancel": "Huy",
        "Add Customer or Vendor": "Them khach hang hoac nha cung cap",
        "Edit Customer or Vendor": "Sua khach hang hoac nha cung cap",
        "Company / Name": "Cong ty / Ten",
        "Sample Co., Ltd.": "Cong ty mau",
        "Contact": "Nguoi lien he",
        "Accounting Team": "Bo phan ke toan",
        "Phone": "Dien thoai",
        "Email": "Email",
        "Address": "Dia chi",
        "Save Customer or Vendor": "Luu khach hang hoac nha cung cap",
        "Update Customer or Vendor": "Cap nhat khach hang hoac nha cung cap",
        "Used by Saved Forms": "Dang duoc bieu mau da luu su dung",
        "Create New Data": "Tao du lieu moi",
        "Update Existing Data": "Cap nhat du lieu hien co",
        "Delete Candidate Data": "Xoa du lieu goi y",
        "Product and Item Management": "Quan ly san pham va hang muc",
        "Save product names, models, specifications, and unit prices for line item entry.": "Luu ten san pham, mau, quy cach va don gia de nhap hang muc.",
        "Products and Items": "San pham va hang muc",
        "No saved products or items. Use the add button to register one.": "Chua co san pham hoac hang muc da luu. Hay dung nut them de dang ky.",
        "Add Item Information": "Them thong tin hang muc",
        "Edit Item Information": "Sua thong tin hang muc",
        "Item Name": "Ten hang muc",
        "Item": "Hang muc",
        "Specification": "Quy cach",
        "Model": "Mau ma",
        "Unit Price": "Don gia",
        "Save Item Information": "Luu thong tin hang muc",
        "Update Item Information": "Cap nhat thong tin hang muc",
        "Payment and Note Templates": "Mau thanh toan va ghi chu",
        "Save payment accounts, notes, and terms for reuse while editing forms.": "Luu tai khoan thanh toan, ghi chu va dieu kien de dung lai khi sua bieu mau.",
        "Add Template": "Them mau",
        "Edit Template": "Sua mau",
        "Category": "Phan loai",
        "Template Name": "Ten mau",
        "Example: Bank Account / Standard Notes": "Vi du: Tai khoan ngan hang / Ghi chu chuan",
        "Content": "Noi dung",
        "Save Template": "Luu mau",
        "Update Template": "Cap nhat mau",
        "Subscription and Pro": "Dang ky va Pro",
        "Manage Pro": "Quan ly Pro",
        "Active": "Dang kich hoat",
        "Preview sharing and Google Drive backup": "Chia se xem truoc va sao luu Google Drive",
        "Local Backup": "Sao luu cuc bo",
        "Clear Data": "Xoa du lieu",
        "Clear This Device's App Data": "Xoa du lieu App tren thiet bi nay",
        "First Guide": "Huong dan dau tien",
        "Load Demo Test Data": "Tai du lieu demo",
        "Load Demo Test Data?": "Tai du lieu demo?",
        "Back": "Quay lai",
        "Next": "Tiep",
        "Finish": "Hoan tat",
        "Close": "Dong",
        "Start with the Basics": "Bat dau voi thao tac co ban",
        "Create Company Information": "Tao thong tin cong ty",
        "Create Product Information": "Tao thong tin san pham",
        "Create Customer Information": "Tao thong tin khach hang",
        "Create a Form": "Tao bieu mau",
        "Preview": "Xem truoc",
        "Electronic Bookkeeping Guide": "Huong dan luu tru so sach dien tu",
        "What the App Supports": "Noi dung App ho tro",
        "By Form Type": "Theo loai bieu mau",
        "Notes": "Ghi chu",
        "Start Guide": "Bat dau huong dan"
    ]
}

enum KoreanGlossary {
    private static let values: [String: String] = [
        "Home": "홈",
        "Create": "작성",
        "Preview": "미리보기",
        "Settings": "설정",
        "Projects": "프로젝트",
        "Customers": "거래처",
        "Products": "상품",
        "Forms": "양식",
        "Management": "관리",
        "Save": "저장",
        "Saved": "저장됨",
        "Cancel": "취소",
        "Delete": "삭제",
        "Edit": "편집",
        "Close": "닫기",
        "Add": "추가",
        "Copy": "복사",
        "Search": "검색",
        "Company": "회사",
        "Templates": "템플릿",
        "Files": "파일",
        "Data": "데이터",
        "Pro": "Pro",
        "Language": "언어",
        "Appearance": "화면 표시",
        "Dark Mode": "다크 모드",
        "Interface Language": "앱 화면 언어",
        "PDF Language": "PDF 언어",
        "Basic Info": "기본 정보",
        "Business Partner": "거래처",
        "Issuer": "발행자",
        "Line Items": "상세 항목",
        "Notes": "비고",
        "PDF Preview": "PDF 미리보기",
        "Save PDF": "PDF 저장",
        "No saved forms": "저장된 양식 없음",
        "No saved projects.": "저장된 프로젝트가 없습니다.",
        "No matching support items.": "일치하는 지원 항목이 없습니다.",
        "No partner": "거래처 없음",
        "Not selected": "선택 안 됨",
        "Not created": "미작성",
        "Project settings": "프로젝트 설정",
        "Project Settings": "프로젝트 설정",
        "Project Category": "프로젝트 분류",
        "Customer or Vendor": "고객 또는 공급업체",
        "Create Project": "프로젝트 작성",
        "New Project": "새 프로젝트",
        "Select Project": "프로젝트 선택",
        "Available Recent Projects": "최근 프로젝트",
        "Create New Project": "새 프로젝트 작성",
        "File Management": "파일 관리",
        "Files and Projects": "파일 및 프로젝트",
        "Company Information": "회사 정보",
        "Create Company Information": "회사 정보 등록",
        "Create Product Information": "상품 정보 등록",
        "Create Customer Information": "거래처 정보 등록",
        "Create a Form": "양식 작성",
        "Start with the Basics": "먼저 사용 방법 확인",
        "Search forms, customers, products": "양식, 거래처, 상품 검색",
        "Customer Forms": "고객용 양식",
        "Vendor Forms": "공급업체용 양식",
        "Settings and Account": "설정 및 계정",
        "Manage language, appearance, form colors, and backups.": "언어, 화면 표시, 양식 색상과 백업을 관리합니다.",
        "Table Color": "양식 색상",
        "Match buttons to table color": "버튼 색상을 양식 색상에 맞추기",
        "Autosaving draft": "초안 자동 저장 중",
        "Saved.": "저장되었습니다.",
        "Could not export PDF.": "PDF를 내보낼 수 없습니다.",
        "Generating PNG preview": "PNG 미리보기 생성 중",
        "Could not generate PNG preview.": "PNG 미리보기를 생성할 수 없습니다.",
        "No form to preview": "미리볼 양식이 없습니다",
        "Create Form": "양식 작성",
        "Go to Projects": "프로젝트로 이동",
        "Save and Leave": "저장하고 나가기",
        "Discard and Leave": "버리고 나가기",
        "Keep Editing": "계속 편집",
        "Import Backup File": "백업 파일 가져오기",
        "Merge with Existing Data": "기존 데이터에 병합",
        "Replace with Backup": "백업으로 새로 만들기",
        "Backup Import": "백업 가져오기",
        "Could not read the backup file.": "백업 파일을 읽을 수 없습니다.",
        "Backup content was merged with existing data.": "백업 내용을 기존 데이터에 병합했습니다.",
        "New data was created from the backup.": "백업에서 새 데이터를 만들었습니다.",
        "Could not import the backup file.": "백업 파일을 가져올 수 없습니다.",
        "The form file was opened.": "양식 파일을 열었습니다.",
        "Could not open the form file.": "양식 파일을 열 수 없습니다.",
        "Service Center": "서비스 센터",
        "After-Sales Service": "고객 지원",
        "Video Tutorial": "영상 튜토리얼",
        "Frequently Asked Questions": "자주 묻는 질문",
        "Workflow Tutorials": "작업 흐름 튜토리얼",
        "Refunds": "환불",
        "Service and Technical Support": "서비스 및 기술 지원",
        "Open Support Website": "지원 웹사이트 열기",
        "Open on YouTube": "YouTube에서 열기",
        "Open Apple Refund Request": "Apple 환불 요청 열기",
        "Review on the App Store": "App Store에서 평가하기",
        "Open service center": "서비스 센터 열기",
        "Payment and Note Templates": "결제 및 비고 템플릿",
        "Payment Account": "입금 계좌",
        "Terms": "조건",
        "Bank transfer details": "계좌 이체 정보",
        "Notes shown on forms": "양식에 표시되는 비고",
        "Business terms": "거래 조건"
    ]

    static func value(for english: String) -> String {
        values[english] ?? english
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
    case vendorInvoice
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
            return localized(language, japanese: "受注", chinese: "受注", english: "Order Received")
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
        case .vendorInvoice:
            return localized(language, japanese: "仕入先請求書記録", chinese: "厂商请款书记录", english: "Vendor Invoice Record")
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
        case .customerOrder: return localized(language, japanese: "受注", chinese: "受注", english: "Order Received")
        case .purchaseOrder: return localized(language, japanese: "Purchase Order", chinese: "Purchase Order", english: "Purchase Order")
        case .delivery: return localized(language, japanese: "Delivery Note", chinese: "Delivery Note", english: "Delivery Note")
        case .invoice: return localized(language, japanese: "Invoice", chinese: "Invoice", english: "Invoice")
        case .receipt: return localized(language, japanese: "Receipt", chinese: "Receipt", english: "Receipt")
        case .acceptance: return localized(language, japanese: "Acceptance Receipt", chinese: "Acceptance Receipt", english: "Acceptance Receipt")
        case .customerFiles: return localized(language, japanese: "Project Documents", chinese: "Project Documents", english: "Project Documents")
        case .vendorEstimate: return localized(language, japanese: "Vendor Quotation", chinese: "Vendor Quotation", english: "Vendor Quotation")
        case .vendorInvoice: return localized(language, japanese: "Vendor Invoice", chinese: "Vendor Invoice", english: "Vendor Invoice")
        case .vendorReceipt: return localized(language, japanese: "Vendor Receipt", chinese: "Vendor Receipt", english: "Vendor Receipt")
        case .paymentNotice: return localized(language, japanese: "Payment Notice", chinese: "Payment Notice", english: "Payment Notice")
        }
    }

    var pageTitle: String {
        localizedPageTitle(.japanese)
    }

    func localizedPageTitle(_ language: AppLanguage) -> String {
        switch self {
        case .customerOrder, .vendorEstimate, .vendorInvoice, .vendorReceipt, .paymentNotice:
            return localizedTitle(language)
        case .customerFiles:
            return localized(language, japanese: "プロジェクト管理", chinese: "文件与项目管理", english: "Files and Project Management")
        default:
            switch language {
            case .japanese: return "\(localizedTitle(language))作成"
            case .simplifiedChinese, .traditionalChinese: return "创建\(localizedTitle(language))"
            case .english, .korean, .nepali, .french, .vietnamese: return "Create \(localizedTitle(language))"
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
        case .vendorInvoice: return "VINV"
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
        case .customerOrder: return localized(language, japanese: "受注金額", chinese: "受注金额", english: "Order Received Total")
        case .purchaseOrder: return localized(language, japanese: "発注金額", chinese: "采购金额", english: "Purchase Total")
        case .delivery: return localized(language, japanese: "納品金額", chinese: "送货金额", english: "Delivery Total")
        case .invoice: return localized(language, japanese: "ご請求金額", chinese: "应付金额", english: "Amount Due")
        case .receipt: return localized(language, japanese: "領収金額", chinese: "收款金额", english: "Amount Received")
        case .acceptance: return localized(language, japanese: "受領金額", chinese: "收货金额", english: "Accepted Amount")
        case .customerFiles: return localized(language, japanese: "記録金額", chinese: "记录金额", english: "Recorded Amount")
        case .vendorEstimate: return localized(language, japanese: "見積金額", chinese: "报价金额", english: "Quote Total")
        case .vendorInvoice: return localized(language, japanese: "請求金額", chinese: "请款金额", english: "Invoice Amount")
        case .vendorReceipt: return localized(language, japanese: "領収金額", chinese: "收款金额", english: "Receipt Amount")
        case .paymentNotice: return localized(language, japanese: "支払通知金額", chinese: "支付通知金额", english: "Payment Notice Amount")
        }
    }

    var isAttachmentRecord: Bool {
        switch self {
        case .customerOrder, .vendorEstimate, .vendorInvoice, .vendorReceipt, .paymentNotice:
            return true
        default:
            return false
        }
    }

    var isVendorForm: Bool {
        switch self {
        case .vendorEstimate, .vendorInvoice, .purchaseOrder, .acceptance, .vendorReceipt, .paymentNotice:
            return true
        default:
            return false
        }
    }

    var showsDueDate: Bool {
        switch self {
        case .invoice, .paymentNotice:
            return true
        default:
            return false
        }
    }

    var showsLinePrices: Bool {
        switch self {
        case .estimate, .invoice, .receipt, .purchaseOrder, .paymentNotice:
            return true
        default:
            return false
        }
    }

    var showsSummaryTotals: Bool { showsLinePrices }

    var showsTax: Bool {
        showsLinePrices
    }

    var showsPaymentDetails: Bool {
        self == .invoice
    }

    var showsIssuerRegistration: Bool {
        switch self {
        case .invoice, .receipt:
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
        case .korean: return KoreanGlossary.value(for: english)
        case .traditionalChinese: return chinese
        case .nepali, .french, .vietnamese: return english
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
            case .simplifiedChinese, .traditionalChinese: return "给客户"
            case .english, .korean, .nepali, .french, .vietnamese: return "Customer"
            }
        case .vendor:
            switch language {
            case .japanese: return "仕入先向け"
            case .simplifiedChinese, .traditionalChinese: return "给供应商"
            case .english, .korean, .nepali, .french, .vietnamese: return "Vendor"
            }
        }
    }

    func localizedSubtitle(_ language: AppLanguage) -> String {
        switch self {
        case .customer:
            switch language {
            case .japanese: return "見積・受注・納品・請求・領収"
            case .simplifiedChinese, .traditionalChinese: return "报价、订单、送货、发票、收据"
            case .english, .korean, .nepali, .french, .vietnamese: return "Quote, order, delivery, invoice, receipt"
            }
        case .vendor:
            switch language {
            case .japanese: return "見積記録・発注・受領・請求・領収"
            case .simplifiedChinese, .traditionalChinese: return "报价记录、采购、收货、请款、收据"
            case .english, .korean, .nepali, .french, .vietnamese: return "Quote record, purchase, acceptance, invoice, receipt"
            }
        }
    }

    var requiredTypes: [DocumentType] {
        switch self {
        case .customer: return [.estimate, .customerOrder, .delivery, .invoice, .receipt]
        case .vendor: return [.vendorEstimate, .purchaseOrder, .acceptance, .vendorInvoice, .vendorReceipt]
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
            case .simplifiedChinese, .traditionalChinese: return "汇款账户"
            case .english, .korean, .nepali, .french, .vietnamese: return "Payment Account"
            }
        case .note:
            switch language {
            case .japanese: return "備考"
            case .simplifiedChinese, .traditionalChinese: return "备注"
            case .english, .korean, .nepali, .french, .vietnamese: return "Notes"
            }
        case .condition:
            switch language {
            case .japanese: return "条件"
            case .simplifiedChinese, .traditionalChinese: return "条件"
            case .english, .korean, .nepali, .french, .vietnamese: return "Terms"
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
            case .simplifiedChinese, .traditionalChinese: return "收款账户"
            case .english, .korean, .nepali, .french, .vietnamese: return "Bank transfer details"
            }
        case .note:
            switch language {
            case .japanese: return "帳票に表示する備考"
            case .simplifiedChinese, .traditionalChinese: return "显示在表单上的备注"
            case .english, .korean, .nepali, .french, .vietnamese: return "Notes shown on forms"
            }
        case .condition:
            switch language {
            case .japanese: return "取引条件"
            case .simplifiedChinese, .traditionalChinese: return "交易条件"
            case .english, .korean, .nepali, .french, .vietnamese: return "Business terms"
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
        case .customerOrder: return "受注資料を添付し、取引内容を確認してください。"
        case .purchaseOrder: return "注文内容をご確認の上、手配をお願いいたします。"
        case .delivery: return "上記の通り納品いたします。"
        case .invoice: return "振込手数料は貴社にてご負担ください。"
        case .receipt: return "上記の金額を領収いたしました。"
        case .acceptance: return "上記の通り、受領いたしました。"
        case .customerFiles: return "取引先から受領した書類ファイルを管理します。"
        case .vendorEstimate: return "仕入先から受領した見積書ファイルを添付し、プロジェクト・日時・番号を記録してください。"
        case .vendorInvoice: return "仕入先から受領した請求書ファイルを添付し、プロジェクト・日時・番号を記録してください。"
        case .vendorReceipt: return "仕入先から受領した領収書ファイルを添付し、プロジェクト・日時・番号を記録してください。"
        case .paymentNotice: return "支払告知・支払通知書ファイルを添付し、プロジェクト・日時・番号を記録してください。"
        }
    }

    private static func defaultMemo(for type: DocumentType) -> String {
        switch type {
        case .customerFiles: return "見積書、請求書、領収書などを同じ画面で管理します。"
        case .customerOrder: return "受注ファイル、希望納期、関連見積番号を確認してください。"
        case .vendorEstimate: return "仕入先見積書、現場写真、LINE截圖、契約関連資料をまとめて保存します。"
        case .vendorInvoice: return "仕入先請求書、関連する納品・発注資料、支払予定資料をまとめて保存します。"
        case .vendorReceipt: return "領収書、支払証憑、関連する確認資料をまとめて保存します。"
        case .paymentNotice: return "支払告知通知書、支払予定、関連証憑をまとめて保存します。"
        default: return ""
        }
    }
}
