import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import PDFKit
import Vision

struct EditorScreen: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchaseService: PurchaseService
    let language: AppLanguage
    let onRequirePro: () -> Void
    let onBack: () -> Void
    let onReturnToCreateStart: () -> Void
    let onDocumentDeleted: () -> Void
    var onDocumentSaved: ((BusinessDocument) -> Void)? = nil
    @Environment(\.appButtonAccent) private var buttonAccent
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var saveStatus: String
    @State private var didSave = false
    @State private var expandedSection: EditorFormSection? = .basic
    @State private var isAttachmentFileImporterPresented = false
    @State private var attachmentImportTarget: AttachmentImportTarget = .orderAttachment
    @State private var isPaymentProofPhotoPickerPresented = false
    @State private var previewAttachment: OrderAttachment?
    @State private var isProjectInfoPresented = false
    @State private var isProjectFormsPreviewPresented = false
    @State private var sharePayload: SharePayload?
    @State private var shareError = ""
    @State private var isShareErrorPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isShareProPromptPresented = false
    @State private var isDuplicateCompletePresented = false
    @State private var isSavePreviewConfirmationPresented = false
    @State private var copyingDocument: BusinessDocument?
    @State private var isSaveToastVisible = false
    @State private var isReturnToCreateStartConfirmationPresented = false
    @State private var didTriggerPullToCreateStart = false
    @State private var isOCRFileImporterPresented = false
    @State private var isOCRPhotoPickerPresented = false
    @State private var isOCRLanguageSheetPresented = false
    @State private var isOCRReviewPresented = false
    @State private var recognizedOCRText = ""
    @State private var isRecognizingOCR = false
    @State private var ocrProcessingPreview: OCRProcessingPreview?
    @State private var ocrProcessingPhase: OCRProcessingPhase = .scanning
    @AppStorage("native.shokoForms.ocrRecognitionLanguageProfile.v1") private var ocrRecognitionLanguageProfileID = OCRRecognitionLanguageProfile.auto.rawValue

    private let fieldSpacing: CGFloat = 14
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
        onDocumentDeleted: @escaping () -> Void = {},
        onDocumentSaved: ((BusinessDocument) -> Void)? = nil
    ) {
        self.store = store
        self.purchaseService = purchaseService
        self.language = language
        self.onRequirePro = onRequirePro
        self.onBack = onBack
        self.onReturnToCreateStart = onReturnToCreateStart
        self.onDocumentDeleted = onDocumentDeleted
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
                                            .textContentType(.telephoneNumber)
                                            .onSubmit(store.rememberCustomerFromCurrent)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                } right: {
                                    FormField(title: fieldText(.email)) {
                                        TextField("", text: customerEmail, prompt: .inputPrompt(fieldText(.email)))
                                            .keyboardType(.emailAddress)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textContentType(.emailAddress)
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
                                if showsIssuerRegistration {
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
                                } else {
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
                                            .textContentType(.telephoneNumber)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .flatFormInput()
                                    }
                                } right: {
                                    FormField(title: fieldText(.email)) {
                                        TextField("", text: $store.current.issuerEmail, prompt: .inputPrompt(fieldText(.email)))
                                            .keyboardType(.emailAddress)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled(true)
                                            .textContentType(.emailAddress)
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
                                if showsPaymentDetails {
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

                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 940 : .infinity, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 8)
                    .padding(.top, 12)
                    .padding(.bottom, horizontalSizeClass == .regular ? 132 : 116)
                }
                .onChange(of: expandedSection) { section in
                    scrollExpandedSection(section, with: scrollProxy)
                }
                .coordinateSpace(name: "editorFormScroll")
                .onPreferenceChange(EditorPullToCreateStartOffsetKey.self, perform: handlePullToCreateStartOffset)
            }
        }
        .overlay(alignment: .bottomLeading) {
            bottomActionButtons
                .padding(.leading, horizontalSizeClass == .regular ? 44 : 16)
                .padding(.bottom, horizontalSizeClass == .regular ? 28 : 14)
        }
        .overlay {
            if isSaveToastVisible {
                saveToast
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .overlay {
            if let ocrProcessingPreview {
                OCRProcessingOverlay(
                    preview: ocrProcessingPreview,
                    phase: ocrProcessingPhase,
                    language: language
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(20)
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
        .fileImporter(
            isPresented: $isOCRFileImporterPresented,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleOCRImport(result)
        }
        .sheet(isPresented: $isOCRLanguageSheetPresented) {
            OCRLanguageSelectionSheet(
                language: language,
                selectedProfile: ocrRecognitionLanguageProfileBinding,
                onChoosePhoto: {
                    isOCRLanguageSheetPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isOCRPhotoPickerPresented = true
                    }
                },
                onStart: {
                    isOCRLanguageSheetPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isOCRFileImporterPresented = true
                    }
                }
            )
            .compactBottomSheet()
        }
        .sheet(item: $previewAttachment) { attachment in
            OrderAttachmentPreviewSheet(attachment: attachment, language: language)
        }
        .sheet(isPresented: $isOCRReviewPresented) {
            OCRImportReviewSheet(
                text: recognizedOCRText,
                language: language,
                recognitionLanguageTitle: ocrRecognitionLanguageProfile.localizedTitle(language),
                isLinePriceAvailable: showsLinePrices,
                onApply: applyOCRText
            )
        }
        .sheet(isPresented: $isOCRPhotoPickerPresented) {
            OCRPhotoPicker { imageData in
                handleOCRPhotoImport(imageData)
            }
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
        .sheet(isPresented: $isProjectFormsPreviewPresented) {
            ProjectFormsPreviewSheet(store: store, project: currentProject, documentType: store.current.type, language: language)
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
        .confirmationDialog(localizedSavePreviewConfirmTitle, isPresented: $isSavePreviewConfirmationPresented, titleVisibility: .visible) {
            Button(localizedGoToPreviewTitle) {
                onDocumentSaved?(store.current)
            }
            Button(localizedStayOnFormTitle, role: .cancel) {}
        } message: {
            Text(localizedSavePreviewConfirmMessage)
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
                onDocumentDeleted()
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

    private var showsDueDate: Bool {
        store.current.type.showsDueDate
    }

    private var showsTax: Bool {
        store.current.type.showsTax
    }

    private var showsLinePrices: Bool {
        store.current.type.showsLinePrices
    }

    private var showsPaymentDetails: Bool {
        store.current.type.showsPaymentDetails
    }

    private var showsIssuerRegistration: Bool {
        store.current.type.showsIssuerRegistration
    }

    private var ocrRecognitionLanguageProfile: OCRRecognitionLanguageProfile {
        OCRRecognitionLanguageProfile.fromStoredValue(ocrRecognitionLanguageProfileID)
    }

    private var ocrRecognitionLanguageProfileBinding: Binding<OCRRecognitionLanguageProfile> {
        Binding(
            get: { ocrRecognitionLanguageProfile },
            set: { ocrRecognitionLanguageProfileID = $0.rawValue }
        )
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
        case (.customerOrder, .japanese): return "受注ファイル"
        case (.customerOrder, .simplifiedChinese), (.customerOrder, .traditionalChinese): return "受注文件"
        case (.customerOrder, .english), (.customerOrder, .korean), (.customerOrder, .nepali), (.customerOrder, .french), (.customerOrder, .vietnamese): return "Order Received Files"
        case (.vendorEstimate, .japanese): return "見積ファイル"
        case (.vendorEstimate, .simplifiedChinese), (.vendorEstimate, .traditionalChinese): return "报价文件"
        case (.vendorEstimate, .english), (.vendorEstimate, .korean), (.vendorEstimate, .nepali), (.vendorEstimate, .french), (.vendorEstimate, .vietnamese): return "Quotation Files"
        case (.vendorInvoice, .japanese): return "請求書ファイル"
        case (.vendorInvoice, .simplifiedChinese), (.vendorInvoice, .traditionalChinese): return "请款书文件"
        case (.vendorInvoice, .english), (.vendorInvoice, .korean), (.vendorInvoice, .nepali), (.vendorInvoice, .french), (.vendorInvoice, .vietnamese): return "Invoice Files"
        case (.vendorReceipt, .japanese): return "領収書ファイル"
        case (.vendorReceipt, .simplifiedChinese), (.vendorReceipt, .traditionalChinese): return "收据文件"
        case (.vendorReceipt, .english), (.vendorReceipt, .korean), (.vendorReceipt, .nepali), (.vendorReceipt, .french), (.vendorReceipt, .vietnamese): return "Receipt Files"
        case (.paymentNotice, .japanese): return "支払通知ファイル"
        case (.paymentNotice, .simplifiedChinese), (.paymentNotice, .traditionalChinese): return "付款通知文件"
        case (.paymentNotice, .english), (.paymentNotice, .korean), (.paymentNotice, .nepali), (.paymentNotice, .french), (.paymentNotice, .vietnamese): return "Payment Notice Files"
        case (_, .japanese): return "ファイル"
        case (_, .simplifiedChinese), (_, .traditionalChinese): return "文件"
        case (_, .english), (_, .korean), (_, .nepali), (_, .french), (_, .vietnamese): return "Files"
        }
    }

    private var attachmentRecordName: String {
        switch (store.current.type, language) {
        case (.customerOrder, .japanese): return "受注ファイル"
        case (.customerOrder, .simplifiedChinese), (.customerOrder, .traditionalChinese): return "受注文件"
        case (.customerOrder, .english), (.customerOrder, .korean), (.customerOrder, .nepali), (.customerOrder, .french), (.customerOrder, .vietnamese): return "order received file"
        case (.vendorEstimate, .japanese): return "仕入先見積書"
        case (.vendorEstimate, .simplifiedChinese), (.vendorEstimate, .traditionalChinese): return "供应商报价单"
        case (.vendorEstimate, .english), (.vendorEstimate, .korean), (.vendorEstimate, .nepali), (.vendorEstimate, .french), (.vendorEstimate, .vietnamese): return "vendor quotation"
        case (.vendorInvoice, .japanese): return "仕入先請求書"
        case (.vendorInvoice, .simplifiedChinese), (.vendorInvoice, .traditionalChinese): return "供应商请款书"
        case (.vendorInvoice, .english), (.vendorInvoice, .korean), (.vendorInvoice, .nepali), (.vendorInvoice, .french), (.vendorInvoice, .vietnamese): return "vendor invoice"
        case (.vendorReceipt, .japanese): return "仕入先領収書"
        case (.vendorReceipt, .simplifiedChinese), (.vendorReceipt, .traditionalChinese): return "供应商收据"
        case (.vendorReceipt, .english), (.vendorReceipt, .korean), (.vendorReceipt, .nepali), (.vendorReceipt, .french), (.vendorReceipt, .vietnamese): return "vendor receipt"
        case (.paymentNotice, .japanese): return "支払通知書"
        case (.paymentNotice, .simplifiedChinese), (.paymentNotice, .traditionalChinese): return "付款通知书"
        case (.paymentNotice, .english), (.paymentNotice, .korean), (.paymentNotice, .nepali), (.paymentNotice, .french), (.paymentNotice, .vietnamese): return "payment notice"
        case (_, .japanese): return "ファイル"
        case (_, .simplifiedChinese), (_, .traditionalChinese): return "文件"
        case (_, .english), (_, .korean), (_, .nepali), (_, .french), (_, .vietnamese): return "file"
        }
    }

    private var addAttachmentTitle: String {
        switch language {
        case .japanese: return "\(attachmentRecordName)を追加"
        case .simplifiedChinese, .traditionalChinese: return "添加\(attachmentRecordName)"
        case .english, .korean, .nepali, .french, .vietnamese: return "Add \(attachmentRecordName)"
        }
    }

    private var attachmentHelpText: String {
        switch language {
        case .japanese: return "画像またはPDFの\(attachmentRecordName)を複数添付できます。"
        case .simplifiedChinese, .traditionalChinese: return "可以添加多个图片或 PDF \(attachmentRecordName)。"
        case .english, .korean, .nepali, .french, .vietnamese: return "You can attach multiple images or PDFs for this \(attachmentRecordName)."
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
        case .simplifiedChinese, .traditionalChinese: return "\(count) 项明细"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(count) line items"
        }
    }

    private func localizedAttachmentCount(_ count: Int) -> String {
        switch language {
        case .japanese: return count == 0 ? "添付なし" : "\(count) 件添付"
        case .simplifiedChinese, .traditionalChinese: return count == 0 ? "无附件" : "\(count) 个附件"
        case .english, .korean, .nepali, .french, .vietnamese: return count == 0 ? "No files" : "\(count) files"
        }
    }

    private func localizedFilledFieldCount(_ values: [String]) -> String {
        let count = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        switch language {
        case .japanese: return count == 0 ? "未入力" : "\(count) 項目入力済み"
        case .simplifiedChinese, .traditionalChinese: return count == 0 ? "未填写" : "已填写 \(count) 项"
        case .english, .korean, .nepali, .french, .vietnamese: return count == 0 ? "Empty" : "\(count) filled"
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isOCRLanguageSheetPresented = true
            } label: {
                Image(systemName: isRecognizingOCR ? "text.viewfinder" : "viewfinder")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 42, height: 42)
                    .background(buttonAccent.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isRecognizingOCR)
            .accessibilityLabel(Text("\(localized(japanese: "OCRで入力", chinese: "OCR 导入", english: "Import with OCR")) / \(ocrRecognitionLanguageProfile.localizedTitle(language))"))

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
        isProjectFormsPreviewPresented = true
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
                            .lineLimit(1)
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
                    FormField(title: fieldText(.relatedNumber)) {
                        RelatedNumberInput(
                            text: $store.current.relatedNumber,
                            candidates: store.relatedDocumentCandidatesForCurrentProject,
                            language: language,
                            placeholder: fieldText(.relatedNumber)
                        )
                    }
                }
                twoColumnRow {
                    FormField(title: fieldText(.issueDate)) {
                        DatePicker("", selection: $store.current.issueDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                } right: {
                    FormField(title: fieldText(.transactionDate)) {
                        DatePicker("", selection: $store.current.transactionDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
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
                    FormField(title: fieldText(.relatedNumber)) {
                        RelatedNumberInput(
                            text: $store.current.relatedNumber,
                            candidates: store.relatedDocumentCandidatesForCurrentProject,
                            language: language,
                            placeholder: fieldText(.relatedNumber)
                        )
                    }
                }
                twoColumnRow {
                    FormField(title: fieldText(.issueDate)) {
                        DatePicker("", selection: $store.current.issueDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                } right: {
                    FormField(title: fieldText(.transactionDate)) {
                        DatePicker("", selection: $store.current.transactionDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(CompactDatePickerStyle())
                            .pillFormInput()
                    }
                }
                if showsDueDate && showsTax {
                    twoColumnRow {
                        dueDateField
                    } right: {
                        taxRateField
                    }
                    honorificField
                } else if showsDueDate {
                    twoColumnRow {
                        dueDateField
                    } right: {
                        honorificField
                    }
                } else if showsTax {
                    twoColumnRow {
                        taxRateField
                    } right: {
                        honorificField
                    }
                } else {
                    honorificField
                }
            }
        }
    }

    private var dueDateField: some View {
        FormField(title: fieldText(.dueDate)) {
            DatePicker("", selection: $store.current.dueDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(CompactDatePickerStyle())
                .pillFormInput()
        }
    }

    private var taxRateField: some View {
        FormField(title: fieldText(.taxRate)) {
            TextField("", value: $store.current.taxRate, formatter: NumberFormatter.decimal, prompt: .inputPrompt(fieldText(.taxRate)))
                .keyboardType(.decimalPad)
                .textFieldStyle(PlainTextFieldStyle())
                .flatFormInput()
        }
    }

    private var honorificField: some View {
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

    private var orderAttachmentEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                presentAttachmentImporter(for: .orderAttachment)
            } label: {
                Label(addAttachmentTitle, systemImage: "paperclip")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
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

            FormField(title: fieldText(.taxRate)) {
                TextField("", value: $store.current.taxRate, formatter: NumberFormatter.decimal, prompt: .inputPrompt(fieldText(.taxRate)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .flatFormInput()
            }

            HStack(spacing: 10) {
                Button {
                    presentAttachmentImporter(for: .paymentProof)
                } label: {
                    Label(uploadPaymentProofFileTitle, systemImage: "doc.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
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
        HStack(spacing: 8) {
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
        .padding(8)
        .background(Color.appPanel.opacity(0.96))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appDivider.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 22, x: 0, y: 10)
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
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(iconForeground)
                .frame(width: 28, height: 24)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundColor(foreground)
        .frame(width: 76, height: 58)
        .background(Color.white.opacity(0.001))
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

    private func handleOCRPhotoImport(_ imageData: Data?) {
        guard let imageData else {
            presentShareError(ocrImportErrorMessage(for: OCRImportValidationError.unsupportedFile))
            return
        }
        let startedAt = Date()
        isRecognizingOCR = true
        ocrProcessingPreview = OCRProcessingPreview(data: imageData, filename: localized(japanese: "写真", chinese: "照片", english: "Photo"), isPDF: false)
        ocrProcessingPhase = .scanning
        let profile = ocrRecognitionLanguageProfile
        let recognitionLanguages = profile.recognitionLanguages(interfaceLanguage: language)
        Task {
            do {
                let text = try await OCRTextRecognizer.recognizeText(fromImageData: imageData, recognitionLanguages: recognitionLanguages)
                await completeOCRProcessing(.success(text), startedAt: startedAt)
            } catch {
                await completeOCRProcessing(.failure(ocrImportErrorMessage(for: error)), startedAt: startedAt)
            }
        }
    }

    private func handleOCRImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let startedAt = Date()
            isRecognizingOCR = true
            beginOCRProcessingPreview(for: url)
            let profile = ocrRecognitionLanguageProfile
            let recognitionLanguages = profile.recognitionLanguages(interfaceLanguage: language)
            Task {
                do {
                    let text = try await OCRTextRecognizer.recognizeText(from: url, recognitionLanguages: recognitionLanguages)
                    await completeOCRProcessing(.success(text), startedAt: startedAt)
                } catch {
                    await completeOCRProcessing(.failure(ocrImportErrorMessage(for: error)), startedAt: startedAt)
                }
            }
        case .failure:
            presentShareError(localized(japanese: "画像またはPDFを選択できませんでした。", chinese: "无法选择图片或 PDF。", english: "Could not choose the image or PDF."))
        }
    }

    private func beginOCRProcessingPreview(for url: URL) {
        ocrProcessingPhase = .scanning
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else {
            ocrProcessingPreview = OCRProcessingPreview(data: nil, filename: url.lastPathComponent, isPDF: url.pathExtension.localizedCaseInsensitiveCompare("pdf") == .orderedSame)
            return
        }
        let isPDF = UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true
            || data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46])
        ocrProcessingPreview = OCRProcessingPreview(data: data, filename: url.lastPathComponent, isPDF: isPDF)
    }

    @MainActor
    private func completeOCRProcessing(_ outcome: OCRProcessingOutcome, startedAt: Date) async {
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 5 {
            try? await Task.sleep(nanoseconds: UInt64((5 - elapsed) * 1_000_000_000))
        }

        switch outcome {
        case .success(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                ocrProcessingPhase = .failed
                isRecognizingOCR = false
                ocrProcessingPreview = nil
                presentShareError(localized(japanese: "文字を認識できませんでした。", chinese: "没有识别到文字。", english: "No text was recognized."))
            } else {
                ocrProcessingPhase = .completed
                isRecognizingOCR = false
                ocrProcessingPreview = nil
                recognizedOCRText = trimmed
                isOCRReviewPresented = true
            }
        case .failure(let message):
            ocrProcessingPhase = .failed
            isRecognizingOCR = false
            ocrProcessingPreview = nil
            presentShareError(message)
        }
    }

    private func ocrImportErrorMessage(for error: Error) -> String {
        guard let validationError = error as? OCRImportValidationError else {
            return localized(
                japanese: "OCRを実行できませんでした。画像またはPDFを選択してください。",
                chinese: "无法执行 OCR。请选择图片或 PDF。",
                english: "Could not run OCR. Please choose an image or PDF."
            )
        }

        switch validationError {
        case .pdfTooLarge:
            return localized(
                japanese: "PDFは5MB以内のファイルを選択してください。",
                chinese: "PDF 请选择 5MB 以内的文件。",
                english: "Choose a PDF file up to 5 MB."
            )
        case .pdfTooManyPages:
            return localized(
                japanese: "OCRで読み取れるPDFは最大2ページです。",
                chinese: "OCR 可读取的 PDF 最多 2 页。",
                english: "OCR can read PDFs with up to 2 pages."
            )
        case .unsupportedFile:
            return localized(
                japanese: "画像またはPDFを選択してください。PDFは5MB以内、最大2ページまで対応しています。",
                chinese: "请选择图片或 PDF。PDF 支持 5MB 以内、最多 2 页。",
                english: "Choose an image or PDF. PDFs are supported up to 5 MB and 2 pages."
            )
        }
    }

    private func applyOCRText(_ target: OCRImportTarget) {
        let parsed = OCRParsedFormText(text: recognizedOCRText)
        switch target {
        case .customer:
            if !parsed.companyName.isEmpty { store.current.customerName = parsed.companyName }
            if !parsed.contactName.isEmpty { store.current.customerContact = parsed.contactName }
            if !parsed.phone.isEmpty { store.current.customerPhone = parsed.phone }
            if !parsed.email.isEmpty { store.current.customerEmail = parsed.email }
            if !parsed.address.isEmpty { store.current.customerAddress = parsed.address }
            store.rememberCustomerFromCurrent()
            expandedSection = .customer
        case .issuer:
            if !parsed.companyName.isEmpty { store.current.issuerName = parsed.companyName }
            if !parsed.registrationNumber.isEmpty { store.current.issuerRegistration = parsed.registrationNumber }
            if !parsed.contactName.isEmpty { store.current.issuerContact = parsed.contactName }
            if !parsed.phone.isEmpty { store.current.issuerPhone = parsed.phone }
            if !parsed.email.isEmpty { store.current.issuerEmail = parsed.email }
            if !parsed.address.isEmpty { store.current.issuerAddress = parsed.address }
            store.rememberIssuerFromCurrent()
            expandedSection = .issuer
        case .lineItem:
            var line = store.current.lines.first ?? LineItem()
            if !parsed.productName.isEmpty { line.name = parsed.productName }
            if store.current.lines.isEmpty {
                store.current.lines.append(line)
            } else {
                store.current.lines[0] = line
            }
            store.rememberProduct(line)
            expandedSection = .lines
        case .noteTemplate:
            store.current.notes = recognizedOCRText
            store.rememberTextTemplate(kind: .note, content: recognizedOCRText)
            expandedSection = .notes
        case .paymentTemplate:
            store.current.paymentDetails = recognizedOCRText
            store.rememberTextTemplate(kind: .payment, content: recognizedOCRText)
            expandedSection = .notes
        case .termsTemplate:
            store.current.documentMemo = recognizedOCRText
            store.rememberTextTemplate(kind: .condition, content: recognizedOCRText)
            expandedSection = .notes
        }
        isOCRReviewPresented = false
    }

    private func saveDocument() {
        if !isAttachmentRecord {
            rememberNoteTemplates()
        }
        store.saveCurrent()
        didSave = true
        saveStatus = AppText.value(.saveComplete, language)
        showSaveToast()
        isSavePreviewConfirmationPresented = true
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

    private var localizedSavePreviewConfirmTitle: String {
        localized(japanese: "保存しました", chinese: "已保存", english: "Saved")
    }

    private var localizedSavePreviewConfirmMessage: String {
        localized(
            japanese: "保存が完了しました。PDFプレビュー画面へ移動しますか？",
            chinese: "保存已完成。要前往预览页面吗？",
            english: "The form has been saved. Go to the preview screen?"
        )
    }

    private var localizedGoToPreviewTitle: String {
        localized(japanese: "プレビューへ移動", chinese: "前往预览", english: "Go to Preview")
    }

    private var localizedStayOnFormTitle: String {
        localized(japanese: "このまま編集", chinese: "继续编辑", english: "Keep Editing")
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
        HStack(alignment: .top, spacing: horizontalSizeClass == .regular ? 18 : 10) {
            left()
                .frame(maxWidth: .infinity, alignment: .leading)
            right()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addressInputBlock(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
            MultilineTextInput(text: text)
                .multilineFormInput(minHeight: 104)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldText(_ key: EditorFieldText) -> String {
        switch (key, language) {
        case (.documentNumber, .japanese): return "帳票番号"
        case (.documentNumber, .simplifiedChinese), (.documentNumber, .traditionalChinese): return "表单编号"
        case (.documentNumber, .english), (.documentNumber, .korean), (.documentNumber, .nepali), (.documentNumber, .french), (.documentNumber, .vietnamese): return "Form No."
        case (.issueDate, .japanese): return "発行日"
        case (.issueDate, .simplifiedChinese), (.issueDate, .traditionalChinese): return "开具日期"
        case (.issueDate, .english), (.issueDate, .korean), (.issueDate, .nepali), (.issueDate, .french), (.issueDate, .vietnamese): return "Issue Date"
        case (.transactionDate, .japanese): return "取引年月日"
        case (.transactionDate, .simplifiedChinese), (.transactionDate, .traditionalChinese): return "交易日期"
        case (.transactionDate, .english), (.transactionDate, .korean), (.transactionDate, .nepali), (.transactionDate, .french), (.transactionDate, .vietnamese): return "Transaction Date"
        case (.dueDate, .japanese): return "支払期限 / 納期"
        case (.dueDate, .simplifiedChinese), (.dueDate, .traditionalChinese): return "付款期限 / 交期"
        case (.dueDate, .english), (.dueDate, .korean), (.dueDate, .nepali), (.dueDate, .french), (.dueDate, .vietnamese): return "Due Date / Delivery Date"
        case (.relatedNumber, .japanese): return "関連番号"
        case (.relatedNumber, .simplifiedChinese), (.relatedNumber, .traditionalChinese): return "关联编号"
        case (.relatedNumber, .english), (.relatedNumber, .korean), (.relatedNumber, .nepali), (.relatedNumber, .french), (.relatedNumber, .vietnamese): return "Reference No."
        case (.honorific, .japanese): return "敬称"
        case (.honorific, .simplifiedChinese), (.honorific, .traditionalChinese): return "称谓"
        case (.honorific, .english), (.honorific, .korean), (.honorific, .nepali), (.honorific, .french), (.honorific, .vietnamese): return "Honorific"
        case (.taxRate, .japanese): return "税率(%)"
        case (.taxRate, .simplifiedChinese), (.taxRate, .traditionalChinese): return "税率(%)"
        case (.taxRate, .english), (.taxRate, .korean), (.taxRate, .nepali), (.taxRate, .french), (.taxRate, .vietnamese): return "Tax (%)"
        case (.customerName, .japanese): return "会社名 / 氏名"
        case (.customerName, .simplifiedChinese), (.customerName, .traditionalChinese): return "公司名称 / 姓名"
        case (.customerName, .english), (.customerName, .korean), (.customerName, .nepali), (.customerName, .french), (.customerName, .vietnamese): return "Company / Name"
        case (.contactPerson, .japanese): return "担当者"
        case (.contactPerson, .simplifiedChinese), (.contactPerson, .traditionalChinese): return "联系人"
        case (.contactPerson, .english), (.contactPerson, .korean), (.contactPerson, .nepali), (.contactPerson, .french), (.contactPerson, .vietnamese): return "Contact"
        case (.phone, .japanese): return "電話"
        case (.phone, .simplifiedChinese), (.phone, .traditionalChinese): return "电话"
        case (.phone, .english), (.phone, .korean), (.phone, .nepali), (.phone, .french), (.phone, .vietnamese): return "Phone"
        case (.email, .japanese): return "メール"
        case (.email, .simplifiedChinese), (.email, .traditionalChinese): return "邮箱"
        case (.email, .english), (.email, .korean), (.email, .nepali), (.email, .french), (.email, .vietnamese): return "Email"
        case (.address, .japanese): return "住所"
        case (.address, .simplifiedChinese), (.address, .traditionalChinese): return "地址"
        case (.address, .english), (.address, .korean), (.address, .nepali), (.address, .french), (.address, .vietnamese): return "Address"
        case (.issuerName, .japanese): return "自社名"
        case (.issuerName, .simplifiedChinese), (.issuerName, .traditionalChinese): return "本公司名称"
        case (.issuerName, .english), (.issuerName, .korean), (.issuerName, .nepali), (.issuerName, .french), (.issuerName, .vietnamese): return "Issuer Name"
        case (.registrationNumber, .japanese): return "登録番号"
        case (.registrationNumber, .simplifiedChinese), (.registrationNumber, .traditionalChinese): return "登记编号"
        case (.registrationNumber, .english), (.registrationNumber, .korean), (.registrationNumber, .nepali), (.registrationNumber, .french), (.registrationNumber, .vietnamese): return "Registration No."
        case (.issuerAddress, .japanese): return "自社住所"
        case (.issuerAddress, .simplifiedChinese), (.issuerAddress, .traditionalChinese): return "本公司地址"
        case (.issuerAddress, .english), (.issuerAddress, .korean), (.issuerAddress, .nepali), (.issuerAddress, .french), (.issuerAddress, .vietnamese): return "Issuer Address"
        case (.notes, .japanese): return "備考"
        case (.notes, .simplifiedChinese), (.notes, .traditionalChinese): return "备注"
        case (.notes, .english), (.notes, .korean), (.notes, .nepali), (.notes, .french), (.notes, .vietnamese): return "Notes"
        case (.paymentDetails, .japanese): return "振込先 / 匯款情報"
        case (.paymentDetails, .simplifiedChinese), (.paymentDetails, .traditionalChinese): return "汇款信息 / 收款账户"
        case (.paymentDetails, .english), (.paymentDetails, .korean), (.paymentDetails, .nepali), (.paymentDetails, .french), (.paymentDetails, .vietnamese): return "Payment Details / Status"
        case (.documentMemo, .japanese): return "条件"
        case (.documentMemo, .simplifiedChinese), (.documentMemo, .traditionalChinese): return "条件"
        case (.documentMemo, .english), (.documentMemo, .korean), (.documentMemo, .nepali), (.documentMemo, .french), (.documentMemo, .vietnamese): return "Terms"
        case (.itemName, .japanese): return "品目"
        case (.itemName, .simplifiedChinese), (.itemName, .traditionalChinese): return "品项"
        case (.itemName, .english), (.itemName, .korean), (.itemName, .nepali), (.itemName, .french), (.itemName, .vietnamese): return "Item"
        case (.specification, .japanese): return "仕様"
        case (.specification, .simplifiedChinese), (.specification, .traditionalChinese): return "规格"
        case (.specification, .english), (.specification, .korean), (.specification, .nepali), (.specification, .french), (.specification, .vietnamese): return "Specifications"
        case (.model, .japanese): return "型番"
        case (.model, .simplifiedChinese), (.model, .traditionalChinese): return "型号"
        case (.model, .english), (.model, .korean), (.model, .nepali), (.model, .french), (.model, .vietnamese): return "Model"
        case (.quantity, .japanese): return "数量"
        case (.quantity, .simplifiedChinese), (.quantity, .traditionalChinese): return "数量"
        case (.quantity, .english), (.quantity, .korean), (.quantity, .nepali), (.quantity, .french), (.quantity, .vietnamese): return "Quantity"
        case (.unitPrice, .japanese): return "単価"
        case (.unitPrice, .simplifiedChinese), (.unitPrice, .traditionalChinese): return "单价"
        case (.unitPrice, .english), (.unitPrice, .korean), (.unitPrice, .nepali), (.unitPrice, .french), (.unitPrice, .vietnamese): return "Unit Price"
        case (.amount, .japanese): return "金額"
        case (.amount, .simplifiedChinese), (.amount, .traditionalChinese): return "金额"
        case (.amount, .english), (.amount, .korean), (.amount, .nepali), (.amount, .french), (.amount, .vietnamese): return "Amount"
        }
    }

    private var lineEditor: some View {
        VStack(spacing: 14) {
            if showsLinePrices {
                taxRateField
            }

            ForEach($store.current.lines) { $line in
                VStack(alignment: .leading, spacing: 12) {
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
                    FormField(title: fieldText(.specification)) {
                        TextField("", text: $line.specification, prompt: .inputPrompt(fieldText(.specification)))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    if showsLinePrices {
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
                }
                .padding(.vertical, 4)
            }

            Button {
                store.addLine()
            } label: {
                Label(localized(japanese: "行を追加", chinese: "添加一行", english: "Add Line"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
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

private struct OCRProcessingPreview {
    let data: Data?
    let filename: String
    let isPDF: Bool
}

private enum OCRProcessingPhase {
    case scanning
    case completed
    case failed
}

private enum OCRProcessingOutcome {
    case success(String)
    case failure(String)
}

private struct OCRProcessingOverlay: View {
    let preview: OCRProcessingPreview
    let phase: OCRProcessingPhase
    let language: AppLanguage
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var scanProgress: CGFloat = 0
    @State private var overlayOpacity: Double = 1

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    ZStack {
                        documentPreview
                            .frame(width: proxy.size.width * 0.75, height: proxy.size.height * 0.75)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 12)
                            .overlay(scanEffects)

                        phaseBadge
                    }
                    .frame(width: proxy.size.width * 0.82, height: proxy.size.height * 0.78)

                    VStack(spacing: 6) {
                        Text(statusTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                        Text(preview.filename)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.76))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: proxy.size.width * 0.72)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(overlayOpacity)
        }
        .onAppear {
            startAnimations()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusTitle)
    }

    @ViewBuilder
    private var documentPreview: some View {
        if let data = preview.data, preview.isPDF, let image = Self.pdfPreviewImage(from: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
        } else if let data = preview.data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
        } else {
            VStack(spacing: 12) {
                Image(systemName: preview.isPDF ? "doc.richtext.fill" : "photo.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(buttonAccent)
                Text(preview.isPDF ? "PDF" : localized(japanese: "画像", chinese: "图片", english: "Image"))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
            }
        }
    }

    private var scanEffects: some View {
        GeometryReader { proxy in
            ZStack {
                if phase == .scanning {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, buttonAccent.opacity(0.16), buttonAccent.opacity(0.75), buttonAccent.opacity(0.16), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 52)
                        .offset(y: (proxy.size.height - 52) * scanProgress)
                        .blur(radius: 0.6)

                    Rectangle()
                        .fill(buttonAccent.opacity(0.78))
                        .frame(height: 2)
                        .offset(y: (proxy.size.height - 2) * scanProgress)
                }
            }
            .clipped()
        }
    }

    @ViewBuilder
    private var phaseBadge: some View {
        if phase != .scanning {
            VStack(spacing: 8) {
                Image(systemName: phase == .completed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(phase == .completed ? .green : .red)
                Text(phase == .completed ? localized(japanese: "完了", chinese: "完成", english: "Complete") : localized(japanese: "スキャンできません", chinese: "无法扫描", english: "Could Not Scan"))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private var statusTitle: String {
        switch phase {
        case .scanning:
            return localized(japanese: "ファイルを分析中...", chinese: "正在分析文件...", english: "Analyzing file...")
        case .completed:
            return localized(japanese: "分析が完了しました", chinese: "分析完成", english: "Analysis complete")
        case .failed:
            return localized(japanese: "分析できませんでした", chinese: "无法分析", english: "Could not analyze")
        }
    }

    private func startAnimations() {
        scanProgress = 0
        overlayOpacity = 1
        withAnimation(.linear(duration: 3.0)) {
            scanProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 2.0)) {
                overlayOpacity = 0
            }
        }
    }

    private static func pdfPreviewImage(from data: Data) -> UIImage? {
        guard let document = PDFDocument(data: data),
              let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 1.5
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }
}

private enum OCRRecognitionLanguageProfile: String, CaseIterable, Identifiable {
    case auto
    case japanese
    case english
    case chinese
    case korean
    case simplifiedChinese
    case traditionalChinese

    var id: String { rawValue }

    static func fromStoredValue(_ rawValue: String) -> OCRRecognitionLanguageProfile {
        switch OCRRecognitionLanguageProfile(rawValue: rawValue) {
        case .simplifiedChinese, .traditionalChinese:
            return .chinese
        case .some(let profile):
            return profile
        case .none:
            return .auto
        }
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .auto:
            return localized(language, japanese: "自動 / 現在の言語優先", chinese: "自动 / 优先当前语言", english: "Auto / Current language first")
        case .japanese:
            return localized(language, japanese: "日本語", chinese: "日语", english: "Japanese")
        case .english:
            return localized(language, japanese: "英語", chinese: "英语", english: "English")
        case .chinese:
            return localized(language, japanese: "中国語", chinese: "中文", english: "Chinese")
        case .korean:
            return localized(language, japanese: "韓国語", chinese: "韩语", english: "Korean")
        case .simplifiedChinese:
            return localized(language, japanese: "簡体中国語", chinese: "简体中文", english: "Simplified Chinese")
        case .traditionalChinese:
            return localized(language, japanese: "繁体中国語", chinese: "繁体中文", english: "Traditional Chinese")
        }
    }

    func localizedSubtitle(_ language: AppLanguage) -> String {
        let languages = recognitionLanguages(interfaceLanguage: language).joined(separator: " / ")
        switch language {
        case .japanese:
            return "Vision OCR: \(languages)"
        case .simplifiedChinese, .traditionalChinese:
            return "Vision OCR：\(languages)"
        case .english, .korean, .nepali, .french, .vietnamese:
            return "Vision OCR: \(languages)"
        }
    }

    func recognitionLanguages(interfaceLanguage: AppLanguage) -> [String] {
        switch self {
        case .auto:
            var languages: [String]
            switch interfaceLanguage {
            case .japanese:
                languages = ["ja-JP", "en-US"]
            case .simplifiedChinese:
                languages = ["zh-Hans", "en-US"]
            case .traditionalChinese:
                languages = ["zh-Hant", "en-US"]
            case .english:
                languages = ["en-US", "ja-JP"]
            case .korean:
                languages = ["ko-KR", "en-US", "ja-JP"]
            case .nepali, .french, .vietnamese:
                languages = ["en-US", "ja-JP"]
            }
            for fallback in ["ja-JP", "en-US", "zh-Hans", "zh-Hant", "ko-KR"] where !languages.contains(fallback) {
                languages.append(fallback)
            }
            return languages
        case .japanese:
            return ["ja-JP", "en-US"]
        case .english:
            return ["en-US", "ja-JP"]
        case .chinese:
            return ["zh-Hans", "zh-Hant", "en-US", "ja-JP"]
        case .korean:
            return ["ko-KR", "en-US", "ja-JP"]
        case .simplifiedChinese:
            return ["zh-Hans", "en-US", "ja-JP"]
        case .traditionalChinese:
            return ["zh-Hant", "en-US", "ja-JP"]
        }
    }

    private func localized(_ language: AppLanguage, japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }
}

private struct OCRLanguageSelectionSheet: View {
    let language: AppLanguage
    @Binding var selectedProfile: OCRRecognitionLanguageProfile
    let onChoosePhoto: () -> Void
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localized(japanese: "OCR", chinese: "OCR", english: "OCR"))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Spacer()
                Button(localized(japanese: "閉じる", chinese: "关闭", english: "Close")) {
                    dismiss()
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
            }

            OCRLanguageProfileTagCloud(
                selectedProfile: $selectedProfile,
                language: language,
                tint: buttonAccent
            )

            Text(selectedProfile.localizedSubtitle(language))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(localized(japanese: "PDF 5MB / 2ページ", chinese: "PDF 5MB / 2 页", english: "PDF 5 MB / 2 pages"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)

            HStack(spacing: 12) {
                compactSourceButton(systemImage: "photo.badge.plus", title: localized(japanese: "写真", chinese: "照片", english: "Photo"), isPrimary: true, action: onChoosePhoto)
                compactSourceButton(systemImage: "doc.badge.plus", title: localized(japanese: "ファイル", chinese: "文件", english: "File"), isPrimary: false, action: onStart)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(Color.appBackground)
    }

    private func compactSourceButton(systemImage: String, title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isPrimary ? .white : buttonAccent)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(isPrimary ? buttonAccent : buttonAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text(title))
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }
}

private extension View {
    @ViewBuilder
    func compactBottomSheet() -> some View {
        if #available(iOS 16.0, *) {
            self
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

private struct OCRLanguageProfileTagCloud: View {
    @Binding var selectedProfile: OCRRecognitionLanguageProfile
    let language: AppLanguage
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            languageRow([.auto])
            languageRow([.japanese, .english])
            languageRow([.chinese, .korean])
        }
    }

    private func languageRow(_ profiles: [OCRRecognitionLanguageProfile]) -> some View {
        HStack(spacing: 10) {
            ForEach(profiles) { profile in
                languageTag(profile)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func languageTag(_ profile: OCRRecognitionLanguageProfile) -> some View {
        Button {
            selectedProfile = profile
        } label: {
            HStack(spacing: 6) {
                if selectedProfile == profile {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
                Text(profile.localizedTitle(language))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .foregroundColor(selectedProfile == profile ? .white : .appInk)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(selectedProfile == profile ? tint : Color.appInputBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private enum OCRImportTarget: String, CaseIterable, Identifiable {
    case customer
    case issuer
    case lineItem
    case noteTemplate
    case paymentTemplate
    case termsTemplate

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .customer:
            return localized(language, japanese: "取引先情報に入力", chinese: "填入客户/公司信息", english: "Fill customer info")
        case .issuer:
            return localized(language, japanese: "発行者情報に入力", chinese: "填入本公司/开具方", english: "Fill issuer info")
        case .lineItem:
            return localized(language, japanese: "商品・価格に入力", chinese: "填入商品与价格", english: "Fill product and price")
        case .noteTemplate:
            return localized(language, japanese: "備考テンプレートに保存", chinese: "保存为备注模板", english: "Save as note template")
        case .paymentTemplate:
            return localized(language, japanese: "振込先テンプレートに保存", chinese: "保存为汇款模板", english: "Save as payment template")
        case .termsTemplate:
            return localized(language, japanese: "条件テンプレートに保存", chinese: "保存为条件模板", english: "Save as terms template")
        }
    }

    private func localized(_ language: AppLanguage, japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }
}

private struct OCRImportReviewSheet: View {
    let text: String
    let language: AppLanguage
    let recognitionLanguageTitle: String
    let isLinePriceAvailable: Bool
    let onApply: (OCRImportTarget) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isRecognizedTextExpanded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localized(japanese: "識別した文字", chinese: "识别到的文字", english: "Recognized Text"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)

                        Text(text)
                            .font(.body)
                            .foregroundColor(.appInk)
                            .lineLimit(isRecognizedTextExpanded ? nil : 5)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.appInputBackground)
                            .cornerRadius(8)

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isRecognizedTextExpanded.toggle()
                            }
                        } label: {
                            Text(isRecognizedTextExpanded ? localized(japanese: "閉じる", chinese: "收起", english: "Show less") : localized(japanese: "もっと見る", chinese: "展开更多", english: "Show more"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(localized(japanese: "入力先", chinese: "填入位置", english: "Apply To"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)

                        OCRApplyTargetTagCloud(targets: applyTargets, language: language, onApply: onApply)
                    }
                }
                .padding(18)
            }
            .background(Color.appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "キャンセル", chinese: "取消", english: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(recognitionLanguageTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var applyTargets: [OCRImportTarget] {
        OCRImportTarget.allCases.filter { isLinePriceAvailable || $0 != .lineItem }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }
}

private struct OCRApplyTargetTagCloud: View {
    let targets: [OCRImportTarget]
    let language: AppLanguage
    let onApply: (OCRImportTarget) -> Void
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(targets) { target in
                Button {
                    onApply(target)
                } label: {
                    Text(target.title(language: language))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Color.appPanel)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

private struct OCRParsedFormText {
    let lines: [String]

    init(text: String) {
        lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !Self.isNoiseLine($0) }
    }

    var companyName: String {
        companyCandidates.first ?? ""
    }

    var contactName: String {
        lines.first { line in
            (line.contains("担当") || line.localizedCaseInsensitiveContains("contact") || line.contains("联系人"))
                && !isFormDescription(line)
        }
        .map { cleanContactLine($0) } ?? ""
    }

    var phone: String {
        lines.first(where: isPhone) ?? ""
    }

    var email: String {
        lines.first(where: isEmail) ?? ""
    }

    var address: String {
        lines.first(where: isAddress) ?? ""
    }

    var registrationNumber: String {
        lines.compactMap { line in
            line.range(of: #"T\d{13}"#, options: .regularExpression).map { String(line[$0]) }
        }.first ?? ""
    }

    var productName: String {
        lines.first { isProjectCandidate($0) } ?? ""
    }

    private func isEmail(_ line: String) -> Bool {
        line.contains("@")
    }

    private func isPhone(_ line: String) -> Bool {
        line.range(of: #"\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}"#, options: .regularExpression) != nil
            || line.localizedCaseInsensitiveContains("tel")
            || line.contains("電話")
    }

    private func isAddress(_ line: String) -> Bool {
        line.contains("〒")
            || line.contains("都")
            || line.contains("道")
            || line.contains("府")
            || line.contains("県")
            || line.localizedCaseInsensitiveContains("address")
    }

    private var companyCandidates: [String] {
        lines.filter { line in
            (line.contains("株式会社") || line.contains("有限会社") || line.contains("合同会社") || line.contains("公司") || line.localizedCaseInsensitiveContains("co.,") || line.localizedCaseInsensitiveContains("ltd"))
                && !isFormDescription(line)
                && !isMostlyNumeric(line)
        }
    }

    private func isProjectCandidate(_ line: String) -> Bool {
        guard !isEmail(line),
              !isPhone(line),
              !isAddress(line),
              !isFormDescription(line),
              !isMostlyNumeric(line),
              price(from: line) == nil else { return false }
        return line.count >= 2
    }

    private func isFormDescription(_ line: String) -> Bool {
        let lowered = line.lowercased()
        let keywords = [
            "見積", "請求", "納品", "領収", "注文", "発注", "支払", "帳票", "番号", "日付", "合計", "小計", "税", "金額", "数量", "単価", "明細",
            "报价", "请款", "发票", "发單", "表单", "编号", "日期", "合计", "小计", "税率", "金额", "数量", "单价", "说明", "描述",
            "invoice", "estimate", "quotation", "receipt", "delivery", "payment", "form", "number", "date", "total", "subtotal", "tax", "amount", "quantity", "price", "description"
        ]
        return keywords.contains { lowered.contains($0.lowercased()) }
    }

    private func isMostlyNumeric(_ line: String) -> Bool {
        let meaningful = line.filter { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol }
        guard !meaningful.isEmpty else { return true }
        let digitCount = meaningful.filter(\.isNumber).count
        return Double(digitCount) / Double(meaningful.count) > 0.55
    }

    private func cleanContactLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "担当者", with: "")
            .replacingOccurrences(of: "担当", with: "")
            .replacingOccurrences(of: "联系人", with: "")
            .replacingOccurrences(of: "Contact", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "：", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isNoiseLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let meaningful = trimmed.filter { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol }
        if meaningful.allSatisfy(\.isNumber) { return true }
        return false
    }

    private func price(from line: String) -> Double? {
        let matches = line.matches(for: #"\d[\d,]*(?:\.\d+)?"#)
        return matches
            .compactMap { Double($0.replacingOccurrences(of: ",", with: "")) }
            .filter { $0 >= 1 }
            .max()
    }
}

private enum OCRImportValidationError: Error {
    case pdfTooLarge
    case pdfTooManyPages
    case unsupportedFile
}

private enum OCRTextRecognizer {
    private static let maximumPDFByteCount = 5 * 1024 * 1024
    private static let maximumPDFPageCount = 2

    static func recognizeText(fromImageData data: Data, recognitionLanguages: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                throw OCRImportValidationError.unsupportedFile
            }

            return try recognizeText(in: cgImage, orientation: image.cgImagePropertyOrientation, recognitionLanguages: recognitionLanguages)
        }.value
    }

    static func recognizeText(from url: URL, recognitionLanguages: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)

            if isPDF(url: url, data: data) {
                guard data.count <= maximumPDFByteCount else {
                    throw OCRImportValidationError.pdfTooLarge
                }
                guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else {
                    throw OCRImportValidationError.unsupportedFile
                }
                guard pdf.pageCount <= maximumPDFPageCount else {
                    throw OCRImportValidationError.pdfTooManyPages
                }

                return try (0..<pdf.pageCount)
                    .compactMap { pdf.page(at: $0) }
                    .map { try renderedImage(from: $0) }
                    .map { try recognizeText(in: $0, orientation: .up, recognitionLanguages: recognitionLanguages) }
                    .joined(separator: "\n")
            }

            guard let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                throw OCRImportValidationError.unsupportedFile
            }

            return try recognizeText(in: cgImage, orientation: image.cgImagePropertyOrientation, recognitionLanguages: recognitionLanguages)
        }.value
    }

    private static func isPDF(url: URL, data: Data) -> Bool {
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            return true
        }
        return data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46])
    }

    private static func renderedImage(from page: PDFPage) throws -> CGImage {
        let pageBounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let size = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.translateBy(x: -pageBounds.origin.x, y: -pageBounds.origin.y)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        guard let cgImage = image.cgImage else {
            throw OCRImportValidationError.unsupportedFile
        }
        return cgImage
    }

    private static func recognizeText(in cgImage: CGImage, orientation: CGImagePropertyOrientation, recognitionLanguages: [String]) throws -> String {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
    }
}

private extension String {
    func matches(for pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: self) else { return nil }
            return String(self[matchRange])
        }
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
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
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
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
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
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

private struct OCRPhotoPicker: UIViewControllerRepresentable {
    let onComplete: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: (Data?) -> Void

        init(onComplete: @escaping (Data?) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }

            let provider = result.itemProvider
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    let data = (object as? UIImage)?.jpegData(compressionQuality: 0.92)
                    DispatchQueue.main.async {
                        self.onComplete(data)
                    }
                }
            } else {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    DispatchQueue.main.async {
                        self.onComplete(data)
                    }
                }
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(buttonAccent)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(Text(selectionLabel))
            }
        }
        .flatFormInput()
    }

    private var selectionLabel: String {
        switch language {
        case .japanese: return "プロジェクト内の帳票を選択"
        case .simplifiedChinese, .traditionalChinese: return "选择项目内的表单"
        case .english, .korean, .nepali, .french, .vietnamese: return "Select form in project"
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
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
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
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }
}

private struct ProjectFormsPreviewSheet: View {
    @ObservedObject var store: DocumentStore
    let project: ProjectArchive?
    let documentType: DocumentType
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var selectedProjectID: ProjectArchive.ID?
    @State private var projectName: String
    @State private var isEditingProjectName = false
    @State private var selectedCustomerID: CustomerProfile.ID?
    @State private var newCustomerName = ""

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    init(store: DocumentStore, project: ProjectArchive?, documentType: DocumentType, language: AppLanguage) {
        self.store = store
        self.project = project
        self.documentType = documentType
        self.language = language
        _selectedProjectID = State(initialValue: project?.id)
        _projectName = State(initialValue: project?.name ?? "")
        _selectedCustomerID = State(initialValue: Self.matchedCustomerID(for: project, in: store.customers))
    }

    private var direction: ProjectDirection {
        ProjectDirection.customer.requiredTypes.contains(documentType) ? .customer : .vendor
    }

    private var activeProject: ProjectArchive? {
        let id = selectedProjectID ?? store.current.projectId ?? project?.id
        guard let id else { return nil }
        return store.projects.first { $0.id == id }
    }

    private var compatibleProjects: [ProjectArchive] {
        store.projects.filter { $0.direction == direction }
    }

    private var selectedCustomer: CustomerProfile? {
        guard let selectedCustomerID else { return nil }
        return store.customers.first { $0.id == selectedCustomerID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button {
                    dismiss()
                } label: {
                    Text(localized(japanese: "閉じる", chinese: "关闭", english: "Close"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .padding(.horizontal, 22)
                        .frame(height: 50)
                        .background(Color.appPanel)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())

                Text(localized(japanese: "プロジェクト帳票", chinese: "项目表单", english: "Project Forms"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)

                if let activeProject {
                    projectSummaryCard(activeProject)

                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
                        ForEach(activeProject.direction.requiredTypes) { type in
                            let documents = activeProject.documents(for: type)
                            if documents.isEmpty {
                                ProjectFormPreviewThumbnail(
                                    document: nil,
                                    type: type,
                                    language: language,
                                    pdfLanguage: store.pdfLanguage,
                                    isCurrentDocument: false
                                ) {
                                    store.openProjectForm(project: activeProject, type: type)
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
                } else {
                    unassignedProjectCard
                    projectPickerSection
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 34)
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .onChange(of: activeProject?.id) { _ in
            projectName = activeProject?.name ?? ""
            isEditingProjectName = false
            selectedCustomerID = Self.matchedCustomerID(for: activeProject, in: store.customers)
            newCustomerName = ""
        }
    }

    private func projectSummaryCard(_ project: ProjectArchive) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 38, height: 38)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        if isEditingProjectName {
                            TextField(localizedProjectNameTitle, text: $projectName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.appInk)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 46)
                                .background(buttonAccent.opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(buttonAccent, lineWidth: 1.4))
                                .cornerRadius(10)
                                .submitLabel(.done)
                                .onSubmit {
                                    saveProjectName(project)
                                }
                        } else {
                            Text(project.name)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.appInk)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Button {
                            if isEditingProjectName {
                                saveProjectName(project)
                            } else {
                                projectName = project.name
                                isEditingProjectName = true
                            }
                        } label: {
                            Label(
                                isEditingProjectName ? localizedDoneTitle : localizedEditTitle,
                                systemImage: isEditingProjectName ? "checkmark.circle.fill" : "pencil.circle.fill"
                            )
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .foregroundColor(isEditingProjectName ? .white : buttonAccent)
                            .padding(.horizontal, 10)
                            .frame(minWidth: 76, minHeight: 42)
                            .background(isEditingProjectName ? buttonAccent : buttonAccent.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(buttonAccent.opacity(0.85), lineWidth: 1.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text(projectSubtitle(project))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
            }

            projectPartnerSection(project)

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
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDivider))
        .cornerRadius(12)
    }

    private func saveProjectName(_ project: ProjectArchive) {
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

    private func projectPartnerSection(_ project: ProjectArchive) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedPartnerPickerTitle)
                .font(.caption.weight(.bold))
                .foregroundColor(.appInk)

            Picker(localizedPartnerPickerTitle, selection: $selectedCustomerID) {
                Text(localizedNoSelectionTitle).tag(nil as CustomerProfile.ID?)
                ForEach(store.customers) { customer in
                    Text(customer.name).tag(Optional(customer.id))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(Color.appBackground)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDivider))
            .cornerRadius(10)
            .onChange(of: selectedCustomerID) { _ in
                store.updateProject(project: project, name: projectName.isEmpty ? project.name : projectName, direction: project.direction, customer: selectedCustomer)
            }

            HStack(spacing: 8) {
                TextField(localizedNewPartnerPlaceholder, text: $newCustomerName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Color.appBackground)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDivider))
                    .cornerRadius(10)
                    .submitLabel(.done)
                    .onSubmit {
                        createAndApplyCustomer(project)
                    }

                Button {
                    createAndApplyCustomer(project)
                } label: {
                    Label(localizedCreateTitle, systemImage: "plus.circle.fill")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 76, minHeight: 44)
                        .background(buttonAccent)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newCustomerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newCustomerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
        }
        .padding(12)
        .background(buttonAccent.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(buttonAccent.opacity(0.22)))
        .cornerRadius(12)
    }

    private func createAndApplyCustomer(_ project: ProjectArchive) {
        let cleanName = newCustomerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        store.saveCustomerProfile(name: cleanName, contact: "", phone: "", email: "", address: "")
        if let customer = store.customers.first(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
            selectedCustomerID = customer.id
            store.updateProject(project: project, name: projectName.isEmpty ? project.name : projectName, direction: project.direction, customer: customer)
        }
        newCustomerName = ""
    }

    private var unassignedProjectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 42, height: 42)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(japanese: "プロジェクト未指定", chinese: "未指定项目", english: "No Project Assigned"))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text(direction.localizedTitle(language))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
            }

            Text(localized(
                japanese: "既存プロジェクトを選択するか、現在の帳票から新しいプロジェクトを作成すると、関連帳票をここで確認できます。",
                chinese: "选择既有项目，或用当前表单建立新项目后，就可以在这里确认相关表单。",
                english: "Choose an existing project or create one from this form to review related forms here."
            ))
            .font(.caption.weight(.semibold))
            .foregroundColor(.appMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDivider))
        .cornerRadius(12)
    }

    private var projectPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                store.createProjectFromCurrent(direction: direction)
                selectedProjectID = store.current.projectId
            } label: {
                Label(
                    localized(japanese: "現在の帳票で新しいプロジェクトを作成", chinese: "用当前表单建立新项目", english: "Create New Project from This Form"),
                    systemImage: "folder.badge.plus"
                )
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(buttonAccent)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())

            if !compatibleProjects.isEmpty {
                Text(localized(japanese: "既存プロジェクト", chinese: "既有项目", english: "Existing Projects"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)

                VStack(spacing: 10) {
                    ForEach(compatibleProjects) { project in
                        Button {
                            store.assignCurrentDocument(to: project)
                            selectedProjectID = project.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(buttonAccent)
                                    .frame(width: 42, height: 42)
                                    .background(buttonAccent.opacity(0.12))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(project.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.appInk)
                                        .lineLimit(1)
                                    Text(projectSubtitle(project))
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.appMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.appMuted)
                            }
                            .padding(12)
                            .background(Color.appPanel)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDivider))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func projectSubtitle(_ project: ProjectArchive) -> String {
        let completed = "\(project.completedCount)/\(project.direction.requiredTypes.count)"
        let customer = project.customerName.isEmpty ? localized(japanese: "取引先未入力", chinese: "未填写客户/厂商", english: "No customer/vendor") : project.customerName
        return "\(project.direction.localizedTitle(language)) / \(completed) / \(customer)"
    }

    private var localizedProjectNameTitle: String {
        localized(japanese: "プロジェクト名", chinese: "项目名称", english: "Project Name")
    }

    private var localizedEditTitle: String {
        localized(japanese: "編集", chinese: "编辑", english: "Edit")
    }

    private var localizedDoneTitle: String {
        localized(japanese: "保存", chinese: "保存", english: "Save")
    }

    private var localizedPartnerPickerTitle: String {
        direction == .customer
            ? localized(japanese: "顧客会社", chinese: "客户公司", english: "Customer Company")
            : localized(japanese: "仕入先会社", chinese: "供应商公司", english: "Vendor Company")
    }

    private var localizedNoSelectionTitle: String {
        localized(japanese: "未選択", chinese: "不选择", english: "Not selected")
    }

    private var localizedNewPartnerPlaceholder: String {
        direction == .customer
            ? localized(japanese: "新しい顧客会社名", chinese: "新客户公司名", english: "New customer company")
            : localized(japanese: "新しい仕入先会社名", chinese: "新供应商公司名", english: "New vendor company")
    }

    private var localizedCreateTitle: String {
        localized(japanese: "作成", chinese: "建立", english: "Create")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }

    private static func matchedCustomerID(for project: ProjectArchive?, in customers: [CustomerProfile]) -> CustomerProfile.ID? {
        guard let project, !project.customerName.isEmpty else { return nil }
        return customers.first { customer in
            customer.name.caseInsensitiveCompare(project.customerName) == .orderedSame
        }?.id
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
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
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
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
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
                                    .lineLimit(1)
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
        case .simplifiedChinese, .traditionalChinese:
            return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) 个完成 / \(customer)"
        case .english, .korean, .nepali, .french, .vietnamese:
            return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) complete / \(customer)"
        }
    }

    private func localizedCountText(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件 - タップして選択"
        case .simplifiedChinese, .traditionalChinese: return "\(count) 个 - 点击选择"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(count) forms - tap to choose"
        }
    }

    private var localizedProjectNameTitle: String {
        localized(japanese: "プロジェクト名", chinese: "项目名称", english: "Project Name")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
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
