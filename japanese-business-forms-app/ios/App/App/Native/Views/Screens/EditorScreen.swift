import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import PDFKit

struct EditorScreen: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchaseService: PurchaseService
    let language: AppLanguage
    let onRequirePro: () -> Void
    let onBack: () -> Void
    let onReturnToCreateStart: () -> Void
    var onDocumentSaved: ((BusinessDocument) -> Void)? = nil
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var saveStatus: String
    @State private var didSave = false
    @State private var expandedSection: EditorFormSection? = .basic
    @State private var isAttachmentFileImporterPresented = false
    @State private var attachmentImportTarget: AttachmentImportTarget = .orderAttachment
    @State private var isPaymentProofPhotoPickerPresented = false
    @State private var previewAttachment: OrderAttachment?
    @State private var isProjectInfoPresented = false
    @State private var isProjectAssignmentPresented = false
    @State private var isProjectFormsPreviewPresented = false
    @State private var shouldShowProjectFormsAfterAssignment = false
    @State private var sharePayload: SharePayload?
    @State private var shareError = ""
    @State private var isShareErrorPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isShareProPromptPresented = false
    @State private var isDuplicateCompletePresented = false
    @State private var copyingDocument: BusinessDocument?
    @State private var isSaveToastVisible = false
    @State private var isReturnToCreateStartConfirmationPresented = false
    @State private var didTriggerPullToCreateStart = false

    private let fieldSpacing: CGFloat = 18
    private var currentProject: ProjectArchive? {
        guard let projectId = store.current.projectId else { return nil }
        return store.projects.first { $0.id == projectId }
    }

    private var customerPhone: Binding<String> {
        Binding(
            get: { store.current.customerPhone ?? "" },
            set: { store.current.customerPhone = $0 }
        )
    }

    private var customerEmail: Binding<String> {
        Binding(
            get: { store.current.customerEmail ?? "" },
            set: { store.current.customerEmail = $0 }
        )
    }

    init(
        store: DocumentStore,
        purchaseService: PurchaseService,
        language: AppLanguage,
        onRequirePro: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onReturnToCreateStart: @escaping () -> Void,
        onDocumentSaved: ((BusinessDocument) -> Void)? = nil
    ) {
        self.store = store
        self.purchaseService = purchaseService
        self.language = language
        self.onRequirePro = onRequirePro
        self.onBack = onBack
        self.onReturnToCreateStart = onReturnToCreateStart
        self.onDocumentSaved = onDocumentSaved
        _saveStatus = State(initialValue: AppText.value(.draftAutosaving, language))
        UITextView.appearance().backgroundColor = .clear
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        pullToCreateStartMarker

                        EditorCollapsibleSection(section: .basic, title: AppText.value(.basicInfo, language), statusText: sectionStatusText(for: .basic), statusIsWarning: sectionStatusIsWarning(for: .basic), expandedSection: $expandedSection) {
                            basicSectionFields
                        }

                        if isAttachmentRecord {
                            EditorCollapsibleSection(section: .attachments, title: attachmentSectionTitle, statusText: sectionStatusText(for: .attachments), statusIsWarning: sectionStatusIsWarning(for: .attachments), expandedSection: $expandedSection) {
                                orderAttachmentEditor
                            }
                        }

                        if !isAttachmentRecord {
                            EditorCollapsibleSection(section: .customer, title: AppText.value(.businessPartner, language), statusText: sectionStatusText(for: .customer), statusIsWarning: sectionStatusIsWarning(for: .customer), expandedSection: $expandedSection) {
                            VStack(spacing: fieldSpacing) {
                                FormField(title: fieldText(.customerName)) {
                                    AutocompleteTextField(
                                        placeholder: localized(japanese: "株式会社サンプル", chinese: "示例株式会社", english: "Sample Co., Ltd."),
                                        text: $store.current.customerName,
                                        suggestions: store.customerSuggestions(for: store.current.customerName),
                                        title: { $0.name },
                                        subtitle: { [$0.contact, $0.phone ?? "", $0.email ?? "", $0.address].filter { !$0.isEmpty }.joined(separator: " / ") },
                                        onCommit: { store.rememberCustomerFromCurrent() },
                                        showsClearButton: true,
                                        onClear: {
                                            store.current.customerContact = ""
                                            store.current.customerPhone = nil
                                            store.current.customerEmail = nil
                                            store.current.customerAddress = ""
                                        },
                                        onSelect: { store.apply($0) }
                                    )
                                }
                                FormField(title: fieldText(.contactPerson)) {
                                    TextField("", text: $store.current.customerContact, prompt: .inputPrompt(localized(japanese: "経理部 山田", chinese: "财务部 山田", english: "Accounting / Yamada")))
                                        .onSubmit(store.rememberCustomerFromCurrent)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .flatFormInput()
                                }
                                twoColumnRow {
                                FormField(title: fieldText(.phone)) {
                                        TextField("", text: customerPhone, prompt: .inputPrompt(fieldText(.phone)))
                                            .keyboardType(.phonePad)
                                            .onSubmit(store.rememberCustomerFromCurrent)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                } right: {
                                    FormField(title: fieldText(.email)) {
                                        TextField("", text: customerEmail, prompt: .inputPrompt(fieldText(.email)))
                                            .keyboardType(.emailAddress)
                                            .textInputAutocapitalization(.never)
                                            .onSubmit(store.rememberCustomerFromCurrent)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                }
                                addressInputBlock(title: fieldText(.address), text: $store.current.customerAddress)
                            }
                        }
                        }

                        if !isAttachmentRecord {
                            EditorCollapsibleSection(section: .issuer, title: AppText.value(.issuer, language), statusText: sectionStatusText(for: .issuer), statusIsWarning: sectionStatusIsWarning(for: .issuer), expandedSection: $expandedSection) {
                            VStack(spacing: fieldSpacing) {
                                FormField(title: fieldText(.issuerName)) {
                                    AutocompleteTextField(
                                        placeholder: localized(japanese: "自社名", chinese: "本公司名称", english: "Issuer name"),
                                        text: $store.current.issuerName,
                                        suggestions: store.issuerSuggestions(for: store.current.issuerName),
                                        title: { $0.name },
                                        subtitle: { [$0.registration, $0.phone, $0.email].filter { !$0.isEmpty }.joined(separator: " / ") },
                                        onCommit: { store.rememberIssuerFromCurrent() },
                                        showsClearButton: true,
                                        onClear: {
                                            store.current.issuerRegistration = ""
                                            store.current.issuerContact = ""
                                            store.current.issuerPhone = ""
                                            store.current.issuerEmail = ""
                                            store.current.issuerAddress = ""
                                        },
                                        onSelect: { store.apply($0) }
                                    )
                                }
                                twoColumnRow {
                                    FormField(title: fieldText(.registrationNumber)) {
                                        TextField("", text: $store.current.issuerRegistration, prompt: .inputPrompt("T1234567890123"))
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                } right: {
                                    FormField(title: fieldText(.contactPerson)) {
                                        TextField("", text: $store.current.issuerContact, prompt: .inputPrompt(fieldText(.contactPerson)))
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                }
                                twoColumnRow {
                                    FormField(title: fieldText(.phone)) {
                                        TextField("", text: $store.current.issuerPhone, prompt: .inputPrompt(fieldText(.phone)))
                                            .keyboardType(.phonePad)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                } right: {
                                    FormField(title: fieldText(.email)) {
                                        TextField("", text: $store.current.issuerEmail, prompt: .inputPrompt(fieldText(.email)))
                                            .keyboardType(.emailAddress)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                }
                                addressInputBlock(title: fieldText(.issuerAddress), text: $store.current.issuerAddress)
                            }
                        }
                        }

                        EditorCollapsibleSection(section: .lines, title: AppText.value(.lineItems, language), statusText: sectionStatusText(for: .lines), statusIsWarning: sectionStatusIsWarning(for: .lines), expandedSection: $expandedSection) {
                            lineEditor
                        }

                        if !isAttachmentRecord {
                            EditorCollapsibleSection(section: .notes, title: AppText.value(.notes, language), statusText: sectionStatusText(for: .notes), statusIsWarning: sectionStatusIsWarning(for: .notes), expandedSection: $expandedSection) {
                            VStack(spacing: 12) {
                                FormField(title: fieldText(.notes)) {
                                    TemplateMultilineInput(
                                        text: $store.current.notes,
                                        templates: store.templates(kind: .note),
                                        emptyTemplateText: localized(japanese: "備考テンプレートなし", chinese: "没有备注模板", english: "No note templates"),
                                        language: language,
                                        onSelect: { store.current.notes = $0.content },
                                        onRemember: { store.rememberTextTemplate(kind: .note, content: store.current.notes) }
                                    )
                                }
                                FormField(title: fieldText(.paymentDetails)) {
                                    TemplateMultilineInput(
                                        text: $store.current.paymentDetails,
                                        templates: store.templates(kind: .payment),
                                        emptyTemplateText: localized(japanese: "振込先テンプレートなし", chinese: "没有汇款账户模板", english: "No payment templates"),
                                        language: language,
                                        onSelect: { store.current.paymentDetails = $0.content },
                                        onRemember: { store.rememberTextTemplate(kind: .payment, content: store.current.paymentDetails) }
                                    )
                                }
                                FormField(title: fieldText(.documentMemo)) {
                                    TemplateMultilineInput(
                                        text: $store.current.documentMemo,
                                        templates: store.templates(kind: .condition),
                                        emptyTemplateText: localized(japanese: "条件テンプレートなし", chinese: "没有条件模板", english: "No terms templates"),
                                        language: language,
                                        onSelect: { store.current.documentMemo = $0.content },
                                        onRemember: { store.rememberTextTemplate(kind: .condition, content: store.current.documentMemo) }
                                    )
                                }
                            }
                        }
                        }

                        if isVendorForm {
                            EditorCollapsibleSection(section: .paymentProof, title: paymentProofSectionTitle, statusText: sectionStatusText(for: .paymentProof), statusIsWarning: sectionStatusIsWarning(for: .paymentProof), expandedSection: $expandedSection) {
                                paymentProofEditor
                            }
                        }

                        bottomActionButtons
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .onChange(of: expandedSection) { section in
                    scrollExpandedSection(section, with: scrollProxy)
                }
                .coordinateSpace(name: "editorFormScroll")
                .onPreferenceChange(EditorPullToCreateStartOffsetKey.self, perform: handlePullToCreateStartOffset)
            }
        }
        .overlay {
            if isSaveToastVisible {
                saveToast
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .dismissKeyboardOnTap()
        .onAppear(perform: ensurePaymentProofDefaults)
        .onChange(of: language) { newLanguage in
            if !didSave {
                saveStatus = AppText.value(.draftAutosaving, newLanguage)
            }
        }
        .onChange(of: store.current.id) { _ in
            didSave = false
            saveStatus = AppText.value(.draftAutosaving, language)
            ensurePaymentProofDefaults()
        }
        .onChange(of: store.current.type) { _ in
            ensurePaymentProofDefaults()
        }
        .fileImporter(
            isPresented: $isAttachmentFileImporterPresented,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            handleAttachmentImport(result)
        }
        .sheet(item: $previewAttachment) { attachment in
            OrderAttachmentPreviewSheet(attachment: attachment, language: language)
        }
        .sheet(isPresented: $isPaymentProofPhotoPickerPresented) {
            PaymentProofPhotoPicker { imageData in
                guard store.addPaymentProofImageAttachments(imageData) > 0 else {
                    presentShareError(localized(
                        japanese: "写真を読み込めませんでした。",
                        chinese: "无法读取照片。",
                        english: "Could not load the selected photos."
                    ))
                    return
                }
            }
        }
        .sheet(isPresented: $isProjectInfoPresented) {
            if let currentProject {
                ProjectInfoSheet(store: store, project: currentProject, language: language)
            }
        }
        .sheet(isPresented: $isProjectAssignmentPresented) {
            ProjectAssignmentSheet(
                store: store,
                documentType: store.current.type,
                currentProject: currentProject,
                language: language
            )
        }
        .onChange(of: isProjectAssignmentPresented) { isPresented in
            guard !isPresented, shouldShowProjectFormsAfterAssignment else { return }
            shouldShowProjectFormsAfterAssignment = false
            if currentProject != nil {
                DispatchQueue.main.async {
                    isProjectFormsPreviewPresented = true
                }
            }
        }
        .sheet(isPresented: $isProjectFormsPreviewPresented) {
            if let currentProject {
                ProjectFormsPreviewSheet(store: store, project: currentProject, language: language)
            }
        }
        .sheet(item: $copyingDocument) { document in
            ProjectDocumentCopySheet(store: store, source: document) { copied in
                store.select(copied)
                didSave = true
                saveStatus = AppText.value(.saveComplete, language)
                isDuplicateCompletePresented = true
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
        .confirmationDialog(shareProPromptTitle, isPresented: $isShareProPromptPresented, titleVisibility: .visible) {
            Button(shareProPromptPurchaseTitle) {
                onRequirePro()
            }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(shareProPromptMessage)
        }
        .confirmationDialog(deleteFormTitle, isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button(deleteFormConfirmTitle, role: .destructive) {
                store.delete(store.current)
                didSave = false
                saveStatus = AppText.value(.draftAutosaving, language)
                onBack()
            }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(deleteFormMessage)
        }
        .alert(shareErrorTitle, isPresented: $isShareErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError)
        }
        .alert(localizedDuplicateCompleteTitle, isPresented: $isDuplicateCompletePresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(localizedDuplicateCompleteMessage)
        }
        .confirmationDialog(returnToCreateStartTitle, isPresented: $isReturnToCreateStartConfirmationPresented, titleVisibility: .visible) {
            Button(returnToCreateStartConfirmTitle, role: .destructive) {
                onReturnToCreateStart()
            }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(returnToCreateStartMessage)
        }
    }

    private var isAttachmentRecord: Bool {
        store.current.type.isAttachmentRecord
    }

    private var isVendorForm: Bool {
        store.current.type.isVendorForm
    }

    private var pullToCreateStartMarker: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: EditorPullToCreateStartOffsetKey.self,
                    value: proxy.frame(in: .named("editorFormScroll")).minY
                )
        }
        .frame(height: 0)
    }

    private var paymentProofDateBinding: Binding<Date> {
        Binding(
            get: { store.current.paymentProofDate ?? store.current.transactionDate },
            set: { store.current.paymentProofDate = $0 }
        )
    }

    private var paymentProofAmountBinding: Binding<Double> {
        Binding(
            get: { store.current.paymentProofAmount ?? store.current.total },
            set: { store.current.paymentProofAmount = $0 }
        )
    }

    private var attachmentSectionTitle: String {
        switch (store.current.type, language) {
        case (.customerOrder, .japanese): return "注文ファイル"
        case (.customerOrder, .simplifiedChinese): return "订单文件"
        case (.customerOrder, .english): return "Order Files"
        case (.vendorEstimate, .japanese): return "見積ファイル"
        case (.vendorEstimate, .simplifiedChinese): return "报价文件"
        case (.vendorEstimate, .english): return "Quotation Files"
        case (.vendorReceipt, .japanese): return "領収書ファイル"
        case (.vendorReceipt, .simplifiedChinese): return "收据文件"
        case (.vendorReceipt, .english): return "Receipt Files"
        case (.paymentNotice, .japanese): return "支払通知ファイル"
        case (.paymentNotice, .simplifiedChinese): return "付款通知文件"
        case (.paymentNotice, .english): return "Payment Notice Files"
        case (_, .japanese): return "ファイル"
        case (_, .simplifiedChinese): return "文件"
        case (_, .english): return "Files"
        }
    }

    private var attachmentRecordName: String {
        switch (store.current.type, language) {
        case (.customerOrder, .japanese): return "注文ファイル"
        case (.customerOrder, .simplifiedChinese): return "订单文件"
        case (.customerOrder, .english): return "order file"
        case (.vendorEstimate, .japanese): return "仕入先見積書"
        case (.vendorEstimate, .simplifiedChinese): return "供应商报价单"
        case (.vendorEstimate, .english): return "vendor quotation"
        case (.vendorReceipt, .japanese): return "仕入先領収書"
        case (.vendorReceipt, .simplifiedChinese): return "供应商收据"
        case (.vendorReceipt, .english): return "vendor receipt"
        case (.paymentNotice, .japanese): return "支払通知書"
        case (.paymentNotice, .simplifiedChinese): return "付款通知书"
        case (.paymentNotice, .english): return "payment notice"
        case (_, .japanese): return "ファイル"
        case (_, .simplifiedChinese): return "文件"
        case (_, .english): return "file"
        }
    }

    private var addAttachmentTitle: String {
        switch language {
        case .japanese: return "\(attachmentRecordName)を追加"
        case .simplifiedChinese: return "添加\(attachmentRecordName)"
        case .english: return "Add \(attachmentRecordName)"
        }
    }

    private var attachmentHelpText: String {
        switch language {
        case .japanese: return "画像またはPDFの\(attachmentRecordName)を複数添付できます。"
        case .simplifiedChinese: return "可以添加多个图片或 PDF \(attachmentRecordName)。"
        case .english: return "You can attach multiple images or PDFs for this \(attachmentRecordName)."
        }
    }

    private var paymentProofSectionTitle: String {
        localized(japanese: "支払証明", chinese: "支付证明", english: "Payment Proof")
    }

    private var paymentProofDateTitle: String {
        localized(japanese: "支払日時", chinese: "支付时间", english: "Payment Time")
    }

    private var paymentProofAmountTitle: String {
        localized(japanese: "支払金額", chinese: "支付金额", english: "Payment Amount")
    }

    private var addPaymentProofTitle: String {
        localized(japanese: "支払証明を追加", chinese: "添加支付证明", english: "Add Payment Proof")
    }

    private var uploadPaymentProofFileTitle: String {
        localized(japanese: "ファイルを選択", chinese: "上传文件", english: "Upload File")
    }

    private var uploadPaymentProofPhotoTitle: String {
        localized(japanese: "写真を選択", chinese: "上传照片", english: "Upload Photo")
    }

    private var paymentProofHelpText: String {
        localized(
            japanese: "支払済みの証明として、写真またはPDFを添付できます。",
            chinese: "可上传照片或 PDF 作为支付证明。",
            english: "Attach a photo or PDF as proof of payment."
        )
    }

    private func sectionStatusText(for section: EditorFormSection) -> String? {
        switch section {
        case .basic:
            return localized(
                japanese: "作成日 \(AppFormatters.shortDate(store.current.issueDate))",
                chinese: "建立日期 \(AppFormatters.shortDate(store.current.issueDate))",
                english: "Created \(AppFormatters.shortDate(store.current.issueDate))"
            )
        case .attachments:
            return localizedAttachmentCount(store.current.orderAttachments?.count ?? 0)
        case .customer:
            return companyStatusText(store.current.customerName)
        case .issuer:
            return companyStatusText(store.current.issuerName)
        case .lines:
            return localizedLineCount(store.current.lines.count)
        case .notes:
            return localizedFilledFieldCount([
                store.current.notes,
                store.current.paymentDetails,
                store.current.documentMemo
            ])
        case .paymentProof:
            return localizedAttachmentCount(store.current.paymentProofAttachments?.count ?? 0)
        }
    }

    private func sectionStatusIsWarning(for section: EditorFormSection) -> Bool {
        switch section {
        case .basic:
            return false
        case .attachments:
            return (store.current.orderAttachments?.count ?? 0) == 0
        case .customer:
            return store.current.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .issuer:
            return store.current.issuerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .lines:
            return store.current.lines.isEmpty
        case .notes:
            return [
                store.current.notes,
                store.current.paymentDetails,
                store.current.documentMemo
            ].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .paymentProof:
            return (store.current.paymentProofAttachments?.count ?? 0) == 0
        }
    }

    private func companyStatusText(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return localized(japanese: "会社名未入力", chinese: "未填写公司名称", english: "No company name")
    }

    private func localizedLineCount(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件の明細"
        case .simplifiedChinese: return "\(count) 项明细"
        case .english: return "\(count) line items"
        }
    }

    private func localizedAttachmentCount(_ count: Int) -> String {
        switch language {
        case .japanese: return count == 0 ? "添付なし" : "\(count) 件添付"
        case .simplifiedChinese: return count == 0 ? "无附件" : "\(count) 个附件"
        case .english: return count == 0 ? "No files" : "\(count) files"
        }
    }

    private func localizedFilledFieldCount(_ values: [String]) -> String {
        let count = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        switch language {
        case .japanese: return count == 0 ? "未入力" : "\(count) 項目入力済み"
        case .simplifiedChinese: return count == 0 ? "未填写" : "已填写 \(count) 项"
        case .english: return count == 0 ? "Empty" : "\(count) filled"
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }

    private var cancelTitle: String {
        localized(japanese: "キャンセル", chinese: "取消", english: "Cancel")
    }

    private var localizedBackTitle: String {
        localized(japanese: "戻る", chinese: "返回", english: "Back")
    }

    private var localizedDuplicateTitle: String {
        localized(japanese: "他のプロジェクトへコピー", chinese: "复制到其他项目", english: "Copy to Another Project")
    }

    private var localizedDuplicateCompleteTitle: String {
        localized(japanese: "コピーしました", chinese: "已复制", english: "Duplicated")
    }

    private var localizedDuplicateCompleteMessage: String {
        localized(
            japanese: "指定したプロジェクトへコピーしました。",
            chinese: "已复制到指定项目。",
            english: "The form was copied to the selected project."
        )
    }

    private var returnToCreateStartTitle: String {
        localized(japanese: "作成画面へ戻りますか？", chinese: "要回到作成预设页吗？", english: "Return to the create page?")
    }

    private var returnToCreateStartMessage: String {
        localized(
            japanese: "現在の編集画面を閉じて、帳票種類を選ぶ作成画面へ戻ります。",
            chinese: "将关闭当前编辑画面，回到选择表单类型的作成预设页。",
            english: "This closes the current editor and returns to the form type selection page."
        )
    }

    private var returnToCreateStartConfirmTitle: String {
        localized(japanese: "作成画面へ戻る", chinese: "回到预设页", english: "Return")
    }

    private var shareButtonTitle: String {
        localized(japanese: "共有", chinese: "分享", english: "Share")
    }

    private var sharePDFTitle: String {
        localized(japanese: "PDFを共有", chinese: "分享 PDF", english: "Share PDF")
    }

    private var shareSourceTitle: String {
        localized(japanese: "源ファイルを共有", chinese: "分享源文件", english: "Share Source File")
    }

    private var shareErrorTitle: String {
        localized(japanese: "共有エラー", chinese: "分享错误", english: "Share Error")
    }

    private var shareProPromptTitle: String {
        localized(japanese: "Pro機能です", chinese: "这是 Pro 功能", english: "Pro Feature")
    }

    private var shareProPromptMessage: String {
        localized(
            japanese: "PDFプレビュー画面からの共有はPro機能です。ProにするとPDFを書き出して共有できます。",
            chinese: "从 PDF 预览画面分享属于 Pro 功能。升级 Pro 后，可以导出并分享 PDF。",
            english: "Sharing from PDF Preview is a Pro feature. Upgrade to Pro to export and share PDFs."
        )
    }

    private var shareProPromptPurchaseTitle: String {
        localized(japanese: "購入へ進む", chinese: "前往购买", english: "Go to Purchase")
    }

    private var deleteFormTitle: String {
        localized(japanese: "この帳票を削除しますか？", chinese: "要删除这个表单吗？", english: "Delete this form?")
    }

    private var deleteFormConfirmTitle: String {
        localized(japanese: "削除", chinese: "删除", english: "Delete")
    }

    private var deleteFormMessage: String {
        localized(
            japanese: "この帳票を削除します。この操作は取り消せません。",
            chinese: "将删除这个表单。此操作无法撤销。",
            english: "This form will be deleted. This cannot be undone."
        )
    }

    private func scrollExpandedSection(_ section: EditorFormSection?, with proxy: ScrollViewProxy) {
        guard let section else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.08)) {
                proxy.scrollTo(section, anchor: .top)
            }
        }
    }

    private func handlePullToCreateStartOffset(_ offset: CGFloat) {
        if offset < 24 {
            didTriggerPullToCreateStart = false
            return
        }

        guard offset > 110,
              !didTriggerPullToCreateStart,
              !isReturnToCreateStartConfirmationPresented else { return }
        didTriggerPullToCreateStart = true
        isReturnToCreateStartConfirmationPresented = true
    }

    private var stickyHeader: some View {
        header
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.appBackground)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .zIndex(1)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            AppBackButton(title: localizedBackTitle, action: onBack)

            VStack(alignment: .leading, spacing: 10) {
                projectHeaderControl

                Text(store.current.type.localizedTitle(language))
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                openProjectCopySheet()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 42, height: 42)
                    .background(buttonAccent.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text(localizedDuplicateTitle))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appPanel)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(didSave ? buttonAccent.opacity(0.85) : Color.appDivider, lineWidth: didSave ? 1.4 : 1)
        )
        .cornerRadius(10)
    }

    private var projectHeaderControl: some View {
        Button {
            openProjectFormsPreviewOrAssignment()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption.weight(.semibold))
                Text(projectHeaderText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(buttonAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func openProjectFormsPreviewOrAssignment() {
        if currentProject != nil {
            isProjectFormsPreviewPresented = true
        } else {
            shouldShowProjectFormsAfterAssignment = true
            isProjectAssignmentPresented = true
        }
    }

    private var projectHeaderText: String {
        let direction = projectDirection(for: store.current.type)
        if let currentProject {
            return "\(currentProject.name) / \(currentProject.direction.localizedTitle(language))"
        }
        return localized(
            japanese: "プロジェクト未指定 / \(direction.localizedTitle(language))",
            chinese: "项目未指定 / \(direction.localizedTitle(language))",
            english: "No Project / \(direction.localizedTitle(language))"
        )
    }

    private func projectDirection(for type: DocumentType) -> ProjectDirection {
        ProjectDirection.customer.requiredTypes.contains(type) ? .customer : .vendor
    }

    private var basicSectionFields: some View {
        VStack(spacing: fieldSpacing) {
            if isAttachmentRecord {
                if let projectName = store.current.projectName, !projectName.isEmpty {
                    FormField(title: localized(japanese: "プロジェクト", chinese: "项目", english: "Project")) {
                        Text(projectName)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.appInk)
                            .flatFormInput()
                    }
                }
                twoColumnRow {
                    FormField(title: fieldText(.documentNumber)) {
                        TextField("", text: $store.current.number, prompt: .inputPrompt(fieldText(.documentNumber)))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                } right: {
                    FormField(title: fieldText(.issueDate)) {
                        DatePicker("", selection: $store.current.issueDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                }
                twoColumnRow {
                    FormField(title: fieldText(.transactionDate)) {
                        DatePicker("", selection: $store.current.transactionDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                } right: {
                    FormField(title: fieldText(.relatedNumber)) {
                        RelatedNumberInput(
                            text: $store.current.relatedNumber,
                            candidates: store.relatedDocumentCandidatesForCurrentProject,
                            language: language,
                            placeholder: fieldText(.relatedNumber)
                        )
                    }
                }
            } else {
                twoColumnRow {
                    FormField(title: fieldText(.documentNumber)) {
                        TextField("", text: $store.current.number, prompt: .inputPrompt(fieldText(.documentNumber)))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                } right: {
                    FormField(title: fieldText(.issueDate)) {
                        DatePicker("", selection: $store.current.issueDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                }
                twoColumnRow {
                    FormField(title: fieldText(.transactionDate)) {
                        DatePicker("", selection: $store.current.transactionDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                } right: {
                    FormField(title: fieldText(.dueDate)) {
                        DatePicker("", selection: $store.current.dueDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                }
                twoColumnRow {
                    FormField(title: fieldText(.relatedNumber)) {
                        RelatedNumberInput(
                            text: $store.current.relatedNumber,
                            candidates: store.relatedDocumentCandidatesForCurrentProject,
                            language: language,
                            placeholder: fieldText(.relatedNumber)
                        )
                    }
                } right: {
                    FormField(title: fieldText(.honorific)) {
                        Picker(fieldText(.honorific), selection: $store.current.honorific) {
                            Text(localized(japanese: "御中", chinese: "公司/部门", english: "Company")).tag("御中")
                            Text(localized(japanese: "様", chinese: "个人", english: "Person")).tag("様")
                            Text(localized(japanese: "なし", chinese: "无", english: "None")).tag("")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .pillFormInput()
                    }
                }
                FormField(title: fieldText(.taxRate)) {
                    TextField("", value: $store.current.taxRate, formatter: NumberFormatter.decimal, prompt: .inputPrompt(fieldText(.taxRate)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(PlainTextFieldStyle())
                        .flatFormInput()
                }
            }
        }
    }

    private var orderAttachmentEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                presentAttachmentImporter(for: .orderAttachment)
            } label: {
                Label(addAttachmentTitle, systemImage: "paperclip")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                    .background(buttonAccent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            let attachments = store.current.orderAttachments ?? []
            if attachments.isEmpty {
                Text(attachmentHelpText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.appInputBackground)
                    .cornerRadius(8)
            } else {
                ForEach(attachments) { attachment in
                    OrderAttachmentRow(attachment: attachment, language: language) {
                        previewAttachment = attachment
                    } onDelete: {
                        store.removeOrderAttachment(id: attachment.id)
                    }
                }
            }
        }
    }

    private var paymentProofEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            twoColumnRow {
                FormField(title: paymentProofDateTitle) {
                    DatePicker("", selection: paymentProofDateBinding, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(CompactDatePickerStyle())
                        .pillFormInput()
                }
            } right: {
                FormField(title: paymentProofAmountTitle) {
                    TextField("", value: paymentProofAmountBinding, formatter: NumberFormatter.decimal, prompt: .inputPrompt(paymentProofAmountTitle))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(PlainTextFieldStyle())
                        .flatFormInput()
                }
            }

            HStack(spacing: 10) {
                Button {
                    presentAttachmentImporter(for: .paymentProof)
                } label: {
                    Label(uploadPaymentProofFileTitle, systemImage: "doc.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .background(buttonAccent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    isPaymentProofPhotoPickerPresented = true
                } label: {
                    Label(uploadPaymentProofPhotoTitle, systemImage: "photo.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .background(buttonAccent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }

            let attachments = store.current.paymentProofAttachments ?? []
            if attachments.isEmpty {
                Text(paymentProofHelpText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.appInputBackground)
                    .cornerRadius(8)
            } else {
                ForEach(attachments) { attachment in
                    OrderAttachmentRow(attachment: attachment, language: language) {
                        previewAttachment = attachment
                    } onDelete: {
                        store.removePaymentProofAttachment(id: attachment.id)
                    }
                }
            }
        }
    }

    private var bottomActionButtons: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)

            HStack(spacing: 12) {
                Button {
                    saveDocument()
                } label: {
                    bottomActionTile(
                        title: didSave ? AppText.value(.saved, language) : AppText.value(.save, language),
                        systemImage: didSave ? "checkmark.seal.fill" : "checkmark.circle.fill",
                        foreground: .appInk,
                        iconForeground: buttonAccent
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(Text(AppText.value(.save, language)))

                Button {
                    isDeleteConfirmationPresented = true
                } label: {
                    bottomActionTile(
                        title: deleteFormConfirmTitle,
                        systemImage: "trash",
                        foreground: .appInk,
                        iconForeground: .red
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(Text(deleteFormConfirmTitle))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var saveToast: some View {
        Label(AppText.value(.saved, language), systemImage: "archivebox.fill")
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.appInk.opacity(0.92))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
            .accessibilityHidden(true)
    }

    private func bottomActionTile(title: String, systemImage: String, foreground: Color, iconForeground: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconForeground)
                .frame(width: 32, height: 32)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(foreground)
        .frame(maxWidth: .infinity, minHeight: 92)
        .contentShape(Rectangle())
    }

    private func presentAttachmentImporter(for target: AttachmentImportTarget) {
        attachmentImportTarget = target
        isAttachmentFileImporterPresented = true
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            let importedCount: Int
            switch attachmentImportTarget {
            case .orderAttachment:
                importedCount = store.addOrderAttachments(from: urls)
            case .paymentProof:
                importedCount = store.addPaymentProofAttachments(from: urls)
            }
            if importedCount == 0 {
                presentShareError(localized(
                    japanese: "ファイルを読み込めませんでした。画像またはPDFを選択してください。",
                    chinese: "无法读取文件。请选择图片或 PDF。",
                    english: "Could not read the file. Please choose an image or PDF."
                ))
            }
        case .failure:
            presentShareError(localized(
                japanese: "ファイルを選択できませんでした。",
                chinese: "无法选择文件。",
                english: "Could not choose the file."
            ))
        }
    }

    private func saveDocument() {
        if !isAttachmentRecord {
            rememberNoteTemplates()
        }
        store.saveCurrent()
        onDocumentSaved?(store.current)
        didSave = true
        saveStatus = AppText.value(.saveComplete, language)
        showSaveToast()
    }

    private func showSaveToast() {
        withAnimation(.easeOut(duration: 0.16)) {
            isSaveToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.18)) {
                isSaveToastVisible = false
            }
        }
    }

    private func openProjectCopySheet() {
        if !isAttachmentRecord {
            rememberNoteTemplates()
        }
        store.saveCurrent()
        copyingDocument = store.current
    }

    private func sharePDF() {
        do {
            sharePayload = SharePayload(url: try DocumentPDFExporter.export(store.current, language: store.pdfLanguage))
        } catch {
            presentShareError(localized(japanese: "PDFを書き出せませんでした。", chinese: "无法导出 PDF。", english: "Could not export PDF."))
        }
    }

    private func shareSourceFile() {
        do {
            sharePayload = SharePayload(url: try store.sharedFormFileURL(for: store.current))
        } catch {
            presentShareError(localized(japanese: "源ファイルを書き出せませんでした。", chinese: "无法导出源文件。", english: "Could not export the source file."))
        }
    }

    private func presentShareError(_ message: String) {
        shareError = message
        isShareErrorPresented = true
    }

    private func ensurePaymentProofDefaults() {
        guard isVendorForm else { return }
        if store.current.paymentProofDate == nil {
            store.current.paymentProofDate = store.current.transactionDate
        }
        if store.current.paymentProofAmount == nil {
            store.current.paymentProofAmount = store.current.total
        }
        if store.current.paymentProofAttachments == nil {
            store.current.paymentProofAttachments = []
        }
    }

    private func rememberNoteTemplates() {
        store.rememberTextTemplate(kind: .note, content: store.current.notes)
        store.rememberTextTemplate(kind: .payment, content: store.current.paymentDetails)
        store.rememberTextTemplate(kind: .condition, content: store.current.documentMemo)
    }

    private func twoColumnRow<Left: View, Right: View>(
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            left()
                .frame(maxWidth: .infinity, alignment: .leading)
            right()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addressInputBlock(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
            MultilineTextInput(text: text)
                .multilineFormInput(minHeight: 124)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func fieldText(_ key: EditorFieldText) -> String {
        switch (key, language) {
        case (.documentNumber, .japanese): return "帳票番号"
        case (.documentNumber, .simplifiedChinese): return "表单编号"
        case (.documentNumber, .english): return "Form No."
        case (.issueDate, .japanese): return "発行日"
        case (.issueDate, .simplifiedChinese): return "开具日期"
        case (.issueDate, .english): return "Issue Date"
        case (.transactionDate, .japanese): return "取引年月日"
        case (.transactionDate, .simplifiedChinese): return "交易日期"
        case (.transactionDate, .english): return "Transaction Date"
        case (.dueDate, .japanese): return "支払期限 / 納期"
        case (.dueDate, .simplifiedChinese): return "付款期限 / 交期"
        case (.dueDate, .english): return "Due Date / Delivery Date"
        case (.relatedNumber, .japanese): return "関連番号"
        case (.relatedNumber, .simplifiedChinese): return "关联编号"
        case (.relatedNumber, .english): return "Reference No."
        case (.honorific, .japanese): return "敬称"
        case (.honorific, .simplifiedChinese): return "称谓"
        case (.honorific, .english): return "Honorific"
        case (.taxRate, .japanese): return "税率(%)"
        case (.taxRate, .simplifiedChinese): return "税率(%)"
        case (.taxRate, .english): return "Tax (%)"
        case (.customerName, .japanese): return "会社名 / 氏名"
        case (.customerName, .simplifiedChinese): return "公司名称 / 姓名"
        case (.customerName, .english): return "Company / Name"
        case (.contactPerson, .japanese): return "担当者"
        case (.contactPerson, .simplifiedChinese): return "联系人"
        case (.contactPerson, .english): return "Contact"
        case (.phone, .japanese): return "電話"
        case (.phone, .simplifiedChinese): return "电话"
        case (.phone, .english): return "Phone"
        case (.email, .japanese): return "メール"
        case (.email, .simplifiedChinese): return "邮箱"
        case (.email, .english): return "Email"
        case (.address, .japanese): return "住所"
        case (.address, .simplifiedChinese): return "地址"
        case (.address, .english): return "Address"
        case (.issuerName, .japanese): return "自社名"
        case (.issuerName, .simplifiedChinese): return "本公司名称"
        case (.issuerName, .english): return "Issuer Name"
        case (.registrationNumber, .japanese): return "登録番号"
        case (.registrationNumber, .simplifiedChinese): return "登记编号"
        case (.registrationNumber, .english): return "Registration No."
        case (.issuerAddress, .japanese): return "自社住所"
        case (.issuerAddress, .simplifiedChinese): return "本公司地址"
        case (.issuerAddress, .english): return "Issuer Address"
        case (.notes, .japanese): return "備考"
        case (.notes, .simplifiedChinese): return "备注"
        case (.notes, .english): return "Notes"
        case (.paymentDetails, .japanese): return "振込先 / 匯款情報"
        case (.paymentDetails, .simplifiedChinese): return "汇款信息 / 收款账户"
        case (.paymentDetails, .english): return "Payment Details / Status"
        case (.documentMemo, .japanese): return "条件"
        case (.documentMemo, .simplifiedChinese): return "条件"
        case (.documentMemo, .english): return "Terms"
        case (.itemName, .japanese): return "品目"
        case (.itemName, .simplifiedChinese): return "品项"
        case (.itemName, .english): return "Item"
        case (.specification, .japanese): return "仕様"
        case (.specification, .simplifiedChinese): return "规格"
        case (.specification, .english): return "Specifications"
        case (.model, .japanese): return "型番"
        case (.model, .simplifiedChinese): return "型号"
        case (.model, .english): return "Model"
        case (.quantity, .japanese): return "数量"
        case (.quantity, .simplifiedChinese): return "数量"
        case (.quantity, .english): return "Quantity"
        case (.unitPrice, .japanese): return "単価"
        case (.unitPrice, .simplifiedChinese): return "单价"
        case (.unitPrice, .english): return "Unit Price"
        case (.amount, .japanese): return "金額"
        case (.amount, .simplifiedChinese): return "金额"
        case (.amount, .english): return "Amount"
        }
    }

    private var lineEditor: some View {
        VStack(spacing: 18) {
            ForEach($store.current.lines) { $line in
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(localized(japanese: "明細", chinese: "明细", english: "Line Item"))
                            .font(.caption.weight(.black))
                            .foregroundColor(.appMuted)
                        Spacer()
                        Button {
                            store.removeLine(id: line.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    FormField(title: fieldText(.itemName)) {
                        AutocompleteTextField(
                            placeholder: fieldText(.itemName),
                            text: $line.name,
                            suggestions: store.productSuggestions(for: line.name),
                            title: { $0.name },
                            subtitle: { [$0.model, $0.specification, AppFormatters.yen($0.unitPrice)].filter { !$0.isEmpty }.joined(separator: " / ") },
                            onCommit: { store.rememberProduct(line) },
                            showsClearButton: true,
                            onClear: {
                                line.model = ""
                                line.specification = ""
                                line.unitPrice = 0
                            },
                            onSelect: { product in
                                line.name = product.name
                                line.model = product.model
                                line.specification = product.specification
                                line.unitPrice = product.unitPrice
                            }
                        )
                    }
                    FormField(title: fieldText(.specification)) {
                        TextField("", text: $line.specification, prompt: .inputPrompt(fieldText(.specification)))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    twoColumnRow {
                        FormField(title: fieldText(.model)) {
                            TextField("", text: $line.model, prompt: .inputPrompt(fieldText(.model)))
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    } right: {
                        FormField(title: fieldText(.quantity)) {
                            TextField("", value: $line.quantity, formatter: NumberFormatter.decimal, prompt: .inputPrompt(fieldText(.quantity)))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    }
                    twoColumnRow {
                        FormField(title: fieldText(.unitPrice)) {
                            TextField("", value: $line.unitPrice, formatter: NumberFormatter.decimal, prompt: .inputPrompt(fieldText(.unitPrice)))
                                .keyboardType(.numberPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    } right: {
                        FormField(title: fieldText(.amount)) {
                            Text(AppFormatters.yen(line.amount))
                                .font(.body.weight(.semibold))
                                .foregroundColor(.appInk)
                                .flatFormInput()
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                store.addLine()
            } label: {
                Label(localized(japanese: "行を追加", chinese: "添加一行", english: "Add Line"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                    .background(buttonAccent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
    }
}

private enum EditorFieldText {
    case documentNumber, issueDate, transactionDate, dueDate, relatedNumber, honorific, taxRate
    case customerName, contactPerson, phone, email, address
    case issuerName, registrationNumber, issuerAddress
    case notes, paymentDetails, documentMemo
    case itemName, specification, model, quantity, unitPrice, amount
}

private enum AttachmentImportTarget {
    case orderAttachment
    case paymentProof
}

private struct OrderAttachmentRow: View {
    let attachment: OrderAttachment
    let language: AppLanguage
    let onPreview: () -> Void
    let onDelete: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                attachmentThumbnail
                    .frame(width: 68, height: 68)
                    .background(Color.appInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))

                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.filename)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(2)
                    Text("\(attachment.isPDF ? "PDF" : localized(japanese: "画像", chinese: "图片", english: "Image")) / \(attachment.fileSizeText) / \(AppFormatters.shortDate(attachment.uploadedAt))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }

                Spacer()

                Button(action: onPreview) {
                    Image(systemName: "eye")
                        .font(.body.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }

            inlinePreview
                .frame(maxWidth: .infinity)
                .frame(height: attachment.isPDF ? 320 : 220)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        }
        .padding(12)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var attachmentThumbnail: some View {
        if attachment.isImage, let image = UIImage(data: attachment.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            Image(systemName: attachment.isPDF ? "doc.richtext.fill" : "doc.fill")
                .font(.title2.weight(.semibold))
                .foregroundColor(buttonAccent)
        }
    }

    @ViewBuilder
    private var inlinePreview: some View {
        if attachment.isImage, let image = UIImage(data: attachment.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else if attachment.isPDF {
            PDFAttachmentView(data: attachment.data)
        } else {
            Label(localized(japanese: "プレビューできないファイル形式です", chinese: "无法预览此文件格式", english: "This file format cannot be previewed."), systemImage: "doc")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct OrderAttachmentPreviewSheet: View {
    let attachment: OrderAttachment
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if attachment.isImage, let image = UIImage(data: attachment.data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                    .background(Color.appBackground)
                } else if attachment.isPDF {
                    PDFAttachmentView(data: attachment.data)
                        .background(Color.appBackground)
                } else {
                    Text(localized(japanese: "プレビューできないファイル形式です", chinese: "无法预览此文件格式", english: "This file format cannot be previewed."))
                        .foregroundColor(.appMuted)
                }
            }
            .navigationTitle(attachment.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "閉じる", chinese: "关闭", english: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct PaymentProofPhotoPicker: UIViewControllerRepresentable {
    let onComplete: ([Data]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([Data]) -> Void

        init(onComplete: @escaping ([Data]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            let group = DispatchGroup()
            var selectedImages = Array<Data?>(repeating: nil, count: results.count)
            let lock = NSLock()

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                group.enter()
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        let data = (object as? UIImage)?.jpegData(compressionQuality: 0.9)
                        lock.lock()
                        selectedImages[index] = data
                        lock.unlock()
                        group.leave()
                    }
                } else {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        lock.lock()
                        selectedImages[index] = data
                        lock.unlock()
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                self.onComplete(selectedImages.compactMap { $0 })
            }
        }
    }
}

private struct PDFAttachmentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor.systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
        uiView.autoScales = true
    }
}

private struct RelatedNumberInput: View {
    @Binding var text: String
    let candidates: [BusinessDocument]
    let language: AppLanguage
    let placeholder: String
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: .inputPrompt(placeholder))
                .textFieldStyle(PlainTextFieldStyle())

            if !candidates.isEmpty {
                Menu {
                    ForEach(candidates) { document in
                        Button {
                            text = document.number
                        } label: {
                            Text(menuTitle(for: document))
                        }
                    }
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.body.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(selectionLabel))
            }
        }
        .flatFormInput()
    }

    private var selectionLabel: String {
        switch language {
        case .japanese: return "プロジェクト内の帳票を選択"
        case .simplifiedChinese: return "选择项目内的表单"
        case .english: return "Select form in project"
        }
    }

    private func menuTitle(for document: BusinessDocument) -> String {
        let type = document.type.localizedTitle(language)
        return "\(type) \(document.number)"
    }
}

enum EditorFormSection: Hashable {
    case basic
    case attachments
    case customer
    case issuer
    case lines
    case notes
    case paymentProof
}

private struct EditorPullToCreateStartOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct EditorCollapsibleSection<Content: View>: View {
    let section: EditorFormSection
    let title: String
    let statusText: String?
    let statusIsWarning: Bool
    @Binding var expandedSection: EditorFormSection?
    @ViewBuilder var content: Content
    @Environment(\.appButtonAccent) private var buttonAccent

    private var isExpanded: Bool {
        expandedSection == section
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.title3.weight(.regular))
                    .foregroundColor(.appInk)
                Spacer()
                if let statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(statusIsWarning ? .red : .appInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: 190, alignment: .trailing)
                }
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.06)) {
                        expandedSection = isExpanded ? nil : section
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundColor(buttonAccent)
                        .frame(width: 28, height: 28)
                        .background(buttonAccent.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .id(section)
    }
}

private struct TemplateMultilineInput: View {
    @Binding var text: String
    let templates: [TextTemplate]
    let emptyTemplateText: String
    let language: AppLanguage
    let onSelect: (TextTemplate) -> Void
    let onRemember: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var isTemplatePickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    guard !availableTemplates.isEmpty else { return }
                    isTemplatePickerPresented = true
                } label: {
                    Label(localized(japanese: "テンプレート選択", chinese: "选择模板", english: "Choose Template"), systemImage: "list.bullet.rectangle")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(height: 44)
                }
                .disabled(availableTemplates.isEmpty)
                .opacity(availableTemplates.isEmpty ? 0.45 : 1)
                Spacer()
                Button {
                    onRemember()
                } label: {
                    Label(localized(japanese: "保存", chinese: "保存", english: "Save"), systemImage: "tray.and.arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(height: 44)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }

            MultilineTextInput(text: $text)
                .multilineFormInput(minHeight: 82)
                .onDisappear(perform: onRemember)
        }
        .sheet(isPresented: $isTemplatePickerPresented) {
            TemplatePickerSheet(
                templates: availableTemplates,
                emptyTemplateText: emptyTemplateText,
                language: language,
                onSelect: { template in
                    onSelect(template)
                    isTemplatePickerPresented = false
                }
            )
        }
    }

    private var availableTemplates: [TextTemplate] {
        templates.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct TemplatePickerSheet: View {
    let templates: [TextTemplate]
    let emptyTemplateText: String
    let language: AppLanguage
    let onSelect: (TextTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if templates.isEmpty {
                    Text(emptyTemplateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)
                } else {
                    ForEach(templates) { template in
                        Button {
                            onSelect(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(template.title.isEmpty ? String(template.content.prefix(32)) : template.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.appInk)
                                    .lineLimit(2)
                                Text(template.content)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.appMuted)
                                    .lineLimit(4)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle(localized(japanese: "テンプレート選択", chinese: "选择模板", english: "Choose Template"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "閉じる", chinese: "关闭", english: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct ProjectFormsPreviewSheet: View {
    @ObservedObject var store: DocumentStore
    let project: ProjectArchive
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    projectSummaryCard

                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 14) {
                        ForEach(project.direction.requiredTypes) { type in
                            let documents = project.documents(for: type)
                            if documents.isEmpty {
                                ProjectFormPreviewThumbnail(
                                    document: nil,
                                    type: type,
                                    language: language,
                                    pdfLanguage: store.pdfLanguage,
                                    isCurrentDocument: false
                                ) {
                                    store.openProjectForm(project: project, type: type)
                                    dismiss()
                                }
                            } else {
                                ForEach(documents) { document in
                                    ProjectFormPreviewThumbnail(
                                        document: document,
                                        type: type,
                                        language: language,
                                        pdfLanguage: store.pdfLanguage,
                                        isCurrentDocument: document.id == store.current.id
                                    ) {
                                        store.select(document)
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localized(japanese: "プロジェクト帳票", chinese: "项目表单", english: "Project Forms"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "閉じる", chinese: "关闭", english: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var projectSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 38, height: 38)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(projectSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
            }

            Text(localized(
                japanese: "空白のプレビューをタップすると、その種類の新しい帳票を作成します。",
                chinese: "点击空白预览小图，可以建立该类型的新表单。",
                english: "Tap a blank preview to create a new form of that type."
            ))
            .font(.caption.weight(.semibold))
            .foregroundColor(.appMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDivider))
        .cornerRadius(10)
    }

    private var projectSubtitle: String {
        let completed = "\(project.completedCount)/\(project.direction.requiredTypes.count)"
        let customer = project.customerName.isEmpty ? localized(japanese: "取引先未入力", chinese: "未填写客户/厂商", english: "No customer/vendor") : project.customerName
        return "\(project.direction.localizedTitle(language)) / \(completed) / \(customer)"
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct ProjectFormPreviewThumbnail: View {
    let document: BusinessDocument?
    let type: DocumentType
    let language: AppLanguage
    let pdfLanguage: AppLanguage
    let isCurrentDocument: Bool
    let action: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var thumbnail: UIImage?
    @State private var didFail = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    Color.white

                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if document == nil {
                        blankPreview
                    } else if didFail {
                        fallbackPreview
                    } else {
                        ProgressView()
                            .scaleEffect(0.75)
                    }

                    previewFooter

                    if isCurrentDocument {
                        currentDocumentIndicator
                    }
                }
                .aspectRatio(0.70, contentMode: .fit)
                .background(Color.white)
                .cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(document == nil ? buttonAccent.opacity(0.45) : Color.appDivider, style: StrokeStyle(lineWidth: 1, dash: document == nil ? [5, 4] : [])))
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)

                Text(type.localizedTitle(language))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task(id: taskID) {
            loadThumbnail()
        }
    }

    private var blankPreview: some View {
        VStack(spacing: 9) {
            Image(systemName: "plus.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundColor(buttonAccent)
            Text(localized(japanese: "未作成", chinese: "未建立", english: "Blank"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
            Text(localized(japanese: "タップして作成", chinese: "点击建立", english: "Tap to create"))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appMuted)
        }
        .multilineTextAlignment(.center)
        .padding(10)
    }

    private var fallbackPreview: some View {
        VStack(spacing: 9) {
            Image(systemName: "doc.text.fill")
                .font(.title2.weight(.semibold))
                .foregroundColor(buttonAccent)
            Text(type.localizedTitle(language))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(10)
    }

    private var previewFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer()
            Text(footerDateText)
                .font(.system(size: 8, weight: .semibold))
                .lineLimit(1)
            Text(footerNumberText)
                .font(.system(size: 8, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundColor(.appInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.white.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 38),
            alignment: .bottom
        )
    }

    private var currentDocumentIndicator: some View {
        VStack {
            HStack {
                Circle()
                    .fill(Color.appBlue)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: Color.appBlue.opacity(0.22), radius: 3, x: 0, y: 1)
                Spacer()
            }
            Spacer()
        }
        .padding(8)
    }

    private var taskID: String {
        guard let document else { return "blank-\(type.rawValue)-\(language.rawValue)" }
        return "\(document.id.uuidString)-\(document.updatedAt.timeIntervalSince1970)-\(pdfLanguage.rawValue)"
    }

    private var footerDateText: String {
        guard let document else {
            return localized(japanese: "空白", chinese: "空白", english: "Blank")
        }
        return AppFormatters.shortDate(document.updatedAt)
    }

    private var footerNumberText: String {
        guard let document else {
            return type.localizedTitle(language)
        }
        return document.number.isEmpty ? type.localizedTitle(language) : document.number
    }

    private func loadThumbnail() {
        guard let document, thumbnail == nil else { return }
        do {
            thumbnail = try DocumentPDFExporter.previewImage(for: document, language: pdfLanguage, scale: 1)
            didFail = false
        } catch {
            didFail = true
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct ProjectAssignmentSheet: View {
    @ObservedObject var store: DocumentStore
    let documentType: DocumentType
    let currentProject: ProjectArchive?
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var pendingProjectChange: ProjectArchive?

    private var direction: ProjectDirection {
        ProjectDirection.customer.requiredTypes.contains(documentType) ? .customer : .vendor
    }

    private var compatibleProjects: [ProjectArchive] {
        store.projects.filter { $0.direction == direction }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(localized(japanese: "プロジェクト情報", chinese: "项目信息", english: "Project Info"))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appInk)
                        Text(localized(
                            japanese: "この帳票を所属させるプロジェクトを選択するか、新しいプロジェクトを作成します。",
                            chinese: "请选择这个表单所属的项目，或建立新项目。",
                            english: "Choose the project this form belongs to, or create a new project."
                        ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)
                    }

                    projectTypeCard
                    projectListCard
                    createProjectButton
                }
                .padding(18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localized(japanese: "プロジェクト指定", chinese: "指定项目", english: "Assign Project"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "閉じる", chinese: "关闭", english: "Close")) {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(projectChangeConfirmTitle, isPresented: projectChangeConfirmationBinding, titleVisibility: .visible) {
            Button(projectChangeConfirmButtonTitle) {
                guard let project = pendingProjectChange else { return }
                store.assignCurrentDocument(to: project)
                pendingProjectChange = nil
                dismiss()
            }
            Button(localized(japanese: "キャンセル", chinese: "取消", english: "Cancel"), role: .cancel) {
                pendingProjectChange = nil
            }
        } message: {
            Text(projectChangeConfirmMessage)
        }
    }

    private var projectTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(japanese: "プロジェクトタイプ", chinese: "项目类型", english: "Project Type"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
            HStack(spacing: 10) {
                Image(systemName: direction == .customer ? "person.crop.square" : "building.2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 38, height: 38)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(direction.localizedTitle(language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text(documentType.localizedTitle(language))
                        .font(.caption.weight(.regular))
                        .foregroundColor(.appMuted)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .cornerRadius(8)
        }
    }

    private var projectListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(japanese: "所属プロジェクト", chinese: "所属项目", english: "Assigned Project"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)

            if compatibleProjects.isEmpty {
                Text(localized(japanese: "選択できるプロジェクトはありません。", chinese: "没有可选择的项目。", english: "No compatible projects."))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.appInputBackground)
                    .cornerRadius(8)
            } else {
                VStack(spacing: 10) {
                    ForEach(compatibleProjects) { project in
                        Button {
                            selectProject(project)
                        } label: {
                            projectRow(project)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func projectRow(_ project: ProjectArchive) -> some View {
        let isCurrent = currentProject?.id == project.id
        return HStack(spacing: 12) {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "folder.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isCurrent ? .white : buttonAccent)
                .frame(width: 40, height: 40)
                .background(isCurrent ? buttonAccent : buttonAccent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(project.direction.localizedTitle(language))
                    .font(.caption.weight(.regular))
                    .foregroundColor(.appMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 58)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isCurrent ? buttonAccent : Color.appDivider))
        .cornerRadius(8)
    }

    private func selectProject(_ project: ProjectArchive) {
        if currentProject?.id == project.id {
            dismiss()
            return
        }
        if currentProject != nil {
            pendingProjectChange = project
        } else {
            store.assignCurrentDocument(to: project)
            dismiss()
        }
    }

    private var createProjectButton: some View {
        Button {
            store.createProjectFromCurrent(direction: direction)
            dismiss()
        } label: {
            Label(localized(japanese: "現在の帳票で新しいプロジェクトを作成", chinese: "用当前表单建立新项目", english: "Create New Project from This Form"), systemImage: "folder.badge.plus")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(buttonAccent)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var projectChangeConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingProjectChange != nil },
            set: { isPresented in
                if !isPresented {
                    pendingProjectChange = nil
                }
            }
        )
    }

    private var projectChangeConfirmTitle: String {
        localized(japanese: "所属プロジェクトを変更しますか？", chinese: "要更改所属项目吗？", english: "Change assigned project?")
    }

    private var projectChangeConfirmButtonTitle: String {
        localized(japanese: "変更する", chinese: "确认更改", english: "Change")
    }

    private var projectChangeConfirmMessage: String {
        let currentName = currentProject?.name ?? localized(japanese: "未指定", chinese: "未指定", english: "None")
        let nextName = pendingProjectChange?.name ?? ""
        return localized(
            japanese: "この帳票の所属を「\(currentName)」から「\(nextName)」へ変更します。よろしいですか？",
            chinese: "此表单的所属项目将从「\(currentName)」更改为「\(nextName)」。确定要更改吗？",
            english: "This form will move from \"\(currentName)\" to \"\(nextName)\". Continue?"
        )
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct ProjectInfoSheet: View {
    @ObservedObject var store: DocumentStore
    let project: ProjectArchive
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var projectName: String
    @State private var isEditingProjectName = false

    init(store: DocumentStore, project: ProjectArchive, language: AppLanguage) {
        self.store = store
        self.project = project
        self.language = language
        _projectName = State(initialValue: project.name)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 10) {
                            if isEditingProjectName {
                                TextField(localizedProjectNameTitle, text: $projectName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .flatFormInput()
                            } else {
                                Text(projectName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.appInk)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.78)
                            }

                            Spacer(minLength: 0)

                            Button {
                                if isEditingProjectName {
                                    saveProjectName()
                                } else {
                                    isEditingProjectName = true
                                }
                            } label: {
                                Image(systemName: isEditingProjectName ? "checkmark.circle.fill" : "pencil.circle.fill")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(buttonAccent)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Text(projectSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                    }
                    .padding(.vertical, 6)
                }

                Section(localized(japanese: "表單を選択 / 作成", chinese: "选择 / 建立表单", english: "Select / Create Form")) {
                    ForEach(project.direction.requiredTypes) { type in
                        projectFormRow(type)
                    }
                }
            }
            .navigationTitle(localized(japanese: "プロジェクト情報", chinese: "项目信息", english: "Project Info"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "閉じる", chinese: "关闭", english: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveProjectName() {
        let cleanName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            projectName = project.name
            isEditingProjectName = false
            return
        }
        projectName = cleanName
        store.renameProject(project: project, name: cleanName)
        isEditingProjectName = false
    }

    @ViewBuilder
    private func projectFormRow(_ type: DocumentType) -> some View {
        let documents = project.documents(for: type)

        if documents.count > 1 {
            NavigationLink {
                ProjectDocumentListView(
                    documents: documents,
                    type: type,
                    language: language,
                    onSelect: { document in
                        store.select(document)
                        dismiss()
                    }
                )
            } label: {
                projectFormRowContent(type: type, count: documents.count, numberText: localizedCountText(documents.count), isCreated: true)
            }
        } else {
            Button {
                if let document = documents.first {
                    store.select(document)
                } else {
                    store.openProjectForm(project: project, type: type)
                }
                dismiss()
            } label: {
                projectFormRowContent(
                    type: type,
                    count: documents.count,
                    numberText: documents.first?.number ?? localized(japanese: "未作成 - タップして作成", chinese: "未建立 - 点击建立", english: "Not created - tap to create"),
                    isCreated: !documents.isEmpty
                )
            }
        }
    }

    private func projectFormRowContent(type: DocumentType, count: Int, numberText: String, isCreated: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isCreated ? "doc.text.fill" : "plus.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundColor(isCreated ? .appMuted : buttonAccent)
                .frame(width: 44, height: 44)
            Text("\(type.localizedTitle(language)) / \(numberText)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer()
            Image(systemName: count > 1 ? "list.bullet" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
        }
        .frame(height: 44)
    }

    private var projectSummary: String {
        let customer = project.customerName.isEmpty ? localized(japanese: "取引先未入力", chinese: "未填写客户/厂商", english: "No customer/vendor") : project.customerName
        switch language {
        case .japanese:
            return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) 件完了 / \(customer)"
        case .simplifiedChinese:
            return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) 个完成 / \(customer)"
        case .english:
            return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) complete / \(customer)"
        }
    }

    private func localizedCountText(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件 - タップして選択"
        case .simplifiedChinese: return "\(count) 个 - 点击选择"
        case .english: return "\(count) forms - tap to choose"
        }
    }

    private var localizedProjectNameTitle: String {
        localized(japanese: "プロジェクト名", chinese: "项目名称", english: "Project Name")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct ProjectDocumentListView: View {
    let documents: [BusinessDocument]
    let type: DocumentType
    let language: AppLanguage
    let onSelect: (BusinessDocument) -> Void

    var body: some View {
        List {
            ForEach(documents) { document in
                Button {
                    onSelect(document)
                } label: {
                    Text(documentListTitle(document))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle(type.localizedTitle(language))
    }

    private func documentListTitle(_ document: BusinessDocument) -> String {
        let number = document.number.isEmpty ? "-" : document.number
        let date = AppFormatters.shortDate(document.updatedAt)
        let customer = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return customer.isEmpty ? "\(number) / \(date)" : "\(number) / \(date) / \(customer)"
    }
}

private struct EditorHeaderActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(configuration.isPressed ? tint.opacity(0.78) : tint)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

extension NumberFormatter {
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
