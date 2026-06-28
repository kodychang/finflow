import AVFoundation
import SwiftUI
import PDFKit
import UIKit

struct PreviewScreen: View {
    let document: BusinessDocument
    @ObservedObject var purchaseService: PurchaseService
    let interfaceLanguage: AppLanguage
    let pdfLanguage: AppLanguage
    let onRequirePro: () -> Void
    var onClose: (() -> Void)? = nil
    var previewIntroKey: String? = nil
    var onPreviewIntroCompleted: ((String) -> Void)? = nil
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var sharePayload: SharePayload?
    @State private var exportError = ""
    @State private var isPDFProPromptPresented = false
    @State private var previewImages: [UIImage] = []
    @State private var previewScale: CGFloat = 1
    @State private var lastPreviewScale: CGFloat = 1
    @State private var previewOffset: CGSize = .zero
    @State private var lastPreviewOffset: CGSize = .zero
    @State private var previewResetID = 0
    @State private var previewTitleRevealProgress: CGFloat = 0
    @State private var stampedPreviewImage: UIImage?
    @State private var currentStampSettings: StampSettings?
    @State private var isStampVisible = true
    @State private var isStampEditorPresented = false

    var body: some View {
        Group {
            if document.type.isAttachmentRecord {
                orderRecordPreview
            } else {
                GeometryReader { proxy in
                    let isLandscape = proxy.size.width > proxy.size.height
                    let activePreviewIntroKey = isLandscape ? nil : previewIntroKey
                    ZStack(alignment: .top) {
                        pdfPreview(size: proxy.size)
                            .frame(width: proxy.size.width, height: proxy.size.height)

                        previewToolbar
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.trailing, isLandscape ? 178 : 0)
                            .opacity(activePreviewIntroKey == nil ? 1 : previewTitleRevealProgress)
                            .offset(y: activePreviewIntroKey == nil ? 0 : -72 * (1 - previewTitleRevealProgress))

                        if isLandscape {
                            previewStampBar(isLandscape: true)
                                .frame(width: 156)
                                .padding(.trailing, 16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                .opacity(activePreviewIntroKey == nil ? 1 : previewTitleRevealProgress)
                        } else {
                            previewStampBar(isLandscape: false)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 18)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .opacity(activePreviewIntroKey == nil ? 1 : previewTitleRevealProgress)
                                .offset(y: activePreviewIntroKey == nil ? 0 : 88 * (1 - previewTitleRevealProgress))
                        }

                        if let previewIntroKey = activePreviewIntroKey,
                           let introImage = stampedPreviewImage ?? previewImages.first {
                            PrinterPDFIntroOverlay(
                                introKey: previewIntroKey,
                                pageImage: introImage
                            ) { completedKey in
                                revealPreviewTitle()
                                onPreviewIntroCompleted?(completedKey)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .onAppear {
            if previewIntroKey != nil {
                previewTitleRevealProgress = 0
            }
            renderPreviewImage()
        }
        .onChange(of: document) { _ in
            renderPreviewImage()
        }
        .onChange(of: previewIntroKey) { newValue in
            previewTitleRevealProgress = newValue == nil ? 1 : 0
        }
        .onChange(of: pdfLanguage) { _ in
            renderPreviewImage()
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
        .confirmationDialog(pdfProPromptTitle, isPresented: $isPDFProPromptPresented, titleVisibility: .visible) {
            Button(pdfProPromptPurchaseTitle) {
                onRequirePro()
            }
            Button(localized(japanese: "キャンセル", chinese: "取消", english: "Cancel"), role: .cancel) {}
        } message: {
            Text(pdfProPromptMessage)
        }
        .sheet(isPresented: $isStampEditorPresented) {
            if #available(iOS 16.0, *), let image = stampBaseImage {
                StampEditorView(
                    baseImage: image,
                    initialStampImage: StampLibrary.defaultStampImage,
                    initialSettings: currentStampSettings ?? StampLibrary.defaultStampSettings,
                    language: interfaceLanguage
                ) { stampedImage, settings in
                    stampedPreviewImage = stampedImage
                    currentStampSettings = settings
                    isStampVisible = true
                    StampLibrary.saveDefaultStampSettings(settings)
                    resetPreviewZoom()
                }
            } else {
                Text(localized(japanese: "iOS 16 以上で印章編集を使用できます。", chinese: "iOS 16 以上可使用印章编辑。", english: "Stamp editing is available on iOS 16 or later."))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .padding()
            }
        }
    }

    private var orderRecordPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if onClose != nil {
                    AppBackButton(title: localized(japanese: "戻る", chinese: "返回", english: "Back")) {
                        onClose?()
                    }
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recordEyebrow)
                            .font(.caption.weight(.black))
                            .foregroundColor(.appMuted)
                            .textCase(.uppercase)
                        Text(document.number.isEmpty ? document.type.localizedTitle(interfaceLanguage) : document.number)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appInk)
                    }
                    Spacer()
                    if !document.relatedNumber.isEmpty {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(localized(japanese: "関連番号", chinese: "关联编号", english: "Reference No."))
                                .font(.caption.weight(.black))
                                .foregroundColor(.appMuted)
                            Text(document.relatedNumber)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appInk)
                        }
                    }
                }

                orderRecordSection(title: recordAttachmentTitle) {
                    let attachments = document.orderAttachments ?? []
                    if attachments.isEmpty {
                            Text(localized(japanese: "添付ファイルはまだありません。", chinese: "还没有附件。", english: "No attachments yet."))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                    } else {
                        ForEach(attachments) { attachment in
                            OrderRecordAttachmentPreview(attachment: attachment, language: interfaceLanguage)
                        }
                    }
                }

                orderRecordSection(title: localized(japanese: "項目リスト", chinese: "品项列表", english: "Item List")) {
                    VStack(spacing: 8) {
                        ForEach(document.lines) { line in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(line.name.isEmpty ? localized(japanese: "品目未入力", chinese: "未填写品项", english: "No item name") : line.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.appInk)
                                    Text([line.model, line.specification].filter { !$0.isEmpty }.joined(separator: " / "))
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.appMuted)
                                }
                                Spacer()
                                Text(NumberFormatter.decimal.string(from: NSNumber(value: line.quantity)) ?? "\(line.quantity)")
                                    .font(.caption.weight(.black))
                                    .foregroundColor(.appMuted)
                            }
                            .padding(10)
                            .background(Color.appInputBackground)
                            .cornerRadius(8)
                        }
                    }
                }

                if document.type.isVendorForm {
                    orderRecordSection(title: paymentProofTitle) {
                        paymentProofSummary

                        let attachments = document.paymentProofAttachments ?? []
                        if attachments.isEmpty {
                            Text(localized(japanese: "支払証明はまだありません。", chinese: "还没有支付证明。", english: "No payment proof yet."))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appMuted)
                        } else {
                            ForEach(attachments) { attachment in
                                OrderRecordAttachmentPreview(attachment: attachment, language: interfaceLanguage)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var paymentProofSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            paymentProofValue(
                title: localized(japanese: "支払日時", chinese: "支付时间", english: "Payment Time"),
                value: document.paymentProofDate.map { AppFormatters.dateTime($0, language: interfaceLanguage) } ?? "-"
            )
            paymentProofValue(
                title: localized(japanese: "支払金額", chinese: "支付金额", english: "Payment Amount"),
                value: document.paymentProofAmount.map { AppFormatters.yen($0, language: interfaceLanguage) } ?? "-"
            )
        }
    }

    private func paymentProofValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundColor(.appMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appInputBackground)
        .cornerRadius(8)
    }

    private func orderRecordSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
    }

    private var previewToolbar: some View {
        HStack {
            if onClose != nil {
                AppBackButton(title: localized(japanese: "作成画面へ戻る", chinese: "返回创建页面", english: "Back to Create")) {
                    onClose?()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.value(.pdfPreview, interfaceLanguage))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                if !exportError.isEmpty {
                    Text(exportError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            Spacer()
            Button {
                exportSourceFile()
            } label: {
                Label(sourceShareButtonTitle, systemImage: "doc.badge.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(buttonAccent.opacity(0.12))
                    .foregroundColor(buttonAccent)
                    .cornerRadius(8)
            }
            .accessibilityLabel(Text(sourceShareButtonTitle))

            Button {
                if purchaseService.hasProAccess {
                    exportPDF()
                } else {
                    isPDFProPromptPresented = true
                }
            } label: {
                Label(shareButtonTitle, systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(buttonAccent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appPanel.opacity(0.94))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private func previewStampBar(isLandscape: Bool) -> some View {
        if isLandscape {
            VStack(spacing: 8) {
                previewStampButtons
            }
            .modifier(PreviewStampBarChrome())
        } else {
            HStack(spacing: 8) {
                previewStampButtons
            }
            .modifier(PreviewStampBarChrome())
        }
    }

    @ViewBuilder
    private var previewStampButtons: some View {
            Button {
                isStampEditorPresented = true
            } label: {
                Label(stampedPreviewImage == nil ? localized(japanese: "印章", chinese: "印章", english: "Stamp") : localized(japanese: "再設定", chinese: "重设", english: "Reset"), systemImage: "seal.fill")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel(stampedPreviewImage == nil ? localized(japanese: "印章設定", chinese: "印章设置", english: "Stamp Settings") : localized(japanese: "印章再設定", chinese: "重新设置印章", english: "Reset Stamp"))
            .buttonStyle(PreviewActionButtonStyle(tint: buttonAccent, filled: true))
            .disabled(stampBaseImage == nil)
            .opacity(stampBaseImage == nil ? 0.45 : 1)

            Button {
                isStampVisible.toggle()
            } label: {
                Label(stampVisibilityTitle, systemImage: isStampVisible ? "eye.slash.fill" : "eye.fill")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PreviewActionButtonStyle(tint: buttonAccent, filled: false))
            .disabled(stampedPreviewImage == nil)
            .opacity(stampedPreviewImage == nil ? 0.45 : 1)

            Button {
                exportStampedPNG()
            } label: {
                Label("PNG", systemImage: "photo")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PreviewActionButtonStyle(tint: buttonAccent, filled: false))
            .disabled(pngExportImage == nil)
            .opacity(pngExportImage == nil ? 0.45 : 1)
    }

    private var stampBaseImage: UIImage? {
        previewImages.first
    }

    private var visibleStampedPreviewImage: UIImage? {
        isStampVisible ? stampedPreviewImage : nil
    }

    private var pngExportImage: UIImage? {
        visibleStampedPreviewImage ?? previewImages.first
    }

    private var stampVisibilityTitle: String {
        isStampVisible
            ? localized(japanese: "印章を隠す", chinese: "隐藏印章", english: "Hide Stamp")
            : localized(japanese: "印章を表示", chinese: "显示印章", english: "Show Stamp")
    }

    private var pdfProPromptTitle: String {
        localized(japanese: "Pro機能です", chinese: "这是 Pro 功能", english: "Pro Feature")
    }

    private var pdfProPromptMessage: String {
        localized(
            japanese: "PDFプレビュー画面からの共有はPro機能です。ProにするとPDFを書き出して共有できます。",
            chinese: "从 PDF 预览画面分享属于 Pro 功能。升级 Pro 后，可以导出并分享 PDF。",
            english: "Sharing from PDF Preview is a Pro feature. Upgrade to Pro to export and share PDFs."
        )
    }

    private var shareButtonTitle: String {
        localized(japanese: "共有", chinese: "分享", english: "Share")
    }

    private var sourceShareButtonTitle: String {
        localized(japanese: "原本", chinese: "原始档", english: "Source")
    }

    private var pdfProPromptPurchaseTitle: String {
        localized(japanese: "購入へ進む", chinese: "前往购买", english: "Go to Purchase")
    }

    private func exportPDF() {
        do {
            exportError = ""
            if let stampedPreviewImage = visibleStampedPreviewImage {
                var images = previewImages
                if images.isEmpty {
                    images = [stampedPreviewImage]
                } else {
                    images[0] = stampedPreviewImage
                }
                sharePayload = SharePayload(url: try StampComposer.exportPDF(images))
            } else {
                sharePayload = SharePayload(url: try DocumentPDFExporter.export(document, language: pdfLanguage))
            }
        } catch {
            exportError = AppText.value(.pdfExportError, interfaceLanguage)
        }
    }

    private func exportSourceFile() {
        do {
            exportError = ""
            sharePayload = SharePayload(url: try PreviewSourceFileExporter.export(document))
        } catch {
            exportError = localized(japanese: "原本ファイルを書き出せませんでした。", chinese: "无法导出原始档。", english: "Could not export the source file.")
        }
    }

    private func pdfPreview(size: CGSize) -> some View {
        Group {
            if !previewImages.isEmpty {
                if let stampedPreviewImage = visibleStampedPreviewImage {
                    singlePagePreview(stampedPreviewImage, size: size)
                } else if previewImages.count == 1, let image = previewImages.first {
                    singlePagePreview(image, size: size)
                } else {
                    multipagePreview(size: size)
                }
            } else {
                ProgressView(AppText.value(.previewGenerating, interfaceLanguage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(Color.appPanel)
    }

    private func singlePagePreview(_ image: UIImage, size: CGSize) -> some View {
        let isLandscape = size.width > size.height
        return ZoomablePDFImageView(
            image: image,
            viewportSize: size,
            maximumZoomScale: maximumPreviewScale,
            topInset: isLandscape ? max(8, size.height * 0.025) : 110,
            leftInset: 8,
            bottomInset: isLandscape ? max(8, size.height * 0.025) : 132,
            rightInset: isLandscape ? 184 : 8,
            fitHeightRatio: isLandscape ? 0.95 : nil,
            resetID: previewResetID
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func multipagePreview(size: CGSize) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                ForEach(Array(previewImages.enumerated()), id: \.offset) { _, image in
                    pdfPage(image, availableWidth: size.width, scale: 1)
                        .padding(.vertical, 20)
                }
            }
            .padding(.top, 110)
            .padding(.bottom, 132)
            .frame(maxWidth: .infinity)
        }
        .simultaneousGesture(previewResetGesture)
    }

    private func pdfPage(_ image: UIImage, availableWidth: CGFloat, scale: CGFloat) -> some View {
        let pageWidth = max(1, (availableWidth - 16) * min(max(scale, 1), maximumPreviewScale))
        return Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: pageWidth)
            .background(Color.white)
            .accessibilityLabel(localized(japanese: "PDFプレビュー", chinese: "PDF 预览", english: "PDF preview"))
    }

    private func renderPreviewImage() {
        guard !document.type.isAttachmentRecord else {
            previewImages = []
            exportError = ""
            return
        }
        do {
            exportError = ""
            previewImages = try DocumentPDFExporter.previewImages(for: document, language: pdfLanguage, scale: UIScreen.main.scale)
            applyRememberedStamp()
            isStampVisible = true
            resetPreviewZoom()
        } catch {
            previewImages = []
            stampedPreviewImage = nil
            isStampVisible = true
            exportError = AppText.value(.previewError, interfaceLanguage)
        }
    }

    private func exportStampedPNG() {
        guard let exportImage = pngExportImage else { return }
        do {
            exportError = ""
            sharePayload = SharePayload(url: try StampComposer.exportPNG(exportImage))
        } catch {
            exportError = localized(japanese: "PNGを書き出せませんでした。", chinese: "无法导出 PNG。", english: "Could not export PNG.")
        }
    }

    private func resetStamp() {
        stampedPreviewImage = nil
        resetPreviewZoom()
    }

    private func applyRememberedStamp() {
        guard let baseImage = previewImages.first,
              let stampImage = StampLibrary.defaultStampImage,
              let settings = currentStampSettings ?? StampLibrary.defaultStampSettings else {
            stampedPreviewImage = nil
            currentStampSettings = nil
            return
        }
        stampedPreviewImage = renderStampedPreview(baseImage: baseImage, stampImage: stampImage, settings: settings)
        currentStampSettings = settings
    }

    private func renderStampedPreview(baseImage: UIImage, stampImage: UIImage, settings: StampSettings) -> UIImage {
        let options = settings.options
        let processedStampImage = StampImageProcessor.process(stampImage, options: options)
        let stampSize = stampDisplaySize(pageSize: baseImage.size, stampImage: processedStampImage, scale: settings.scale)
        return StampComposer.compose(
            baseImage: baseImage,
            stampImage: processedStampImage,
            placement: StampComposer.Placement(
                pageDisplaySize: baseImage.size,
                stampDisplaySize: stampSize,
                centerInPage: CGPoint(
                    x: baseImage.size.width * settings.normalizedCenterX,
                    y: baseImage.size.height * settings.normalizedCenterY
                ),
                rotation: settings.rotation,
                opacity: options.opacity
            )
        )
    }

    private func stampDisplaySize(pageSize: CGSize, stampImage: UIImage, scale: CGFloat) -> CGSize {
        let base = min(pageSize.width, pageSize.height) * StampSettings.basePageRatio * StampSettings.clampedScale(scale)
        let aspect = max(0.1, stampImage.size.width / max(1, stampImage.size.height))
        if aspect >= 1 {
            return CGSize(width: base, height: base / aspect)
        }
        return CGSize(width: base * aspect, height: base)
    }

    private var previewMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                previewScale = clampedPreviewScale(lastPreviewScale * value)
                if previewScale <= 1 {
                    previewOffset = .zero
                }
            }
            .onEnded { _ in
                lastPreviewScale = previewScale
                if previewScale <= 1 {
                    resetPreviewZoom()
                }
            }
    }

    private var previewDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard previewScale > 1 else { return }
                previewOffset = CGSize(
                    width: lastPreviewOffset.width + value.translation.width,
                    height: lastPreviewOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPreviewOffset = previewOffset
            }
    }

    private var previewResetGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    resetPreviewZoom()
                }
            }
    }

    private func resetPreviewZoom() {
        previewScale = 1
        lastPreviewScale = 1
        previewOffset = .zero
        lastPreviewOffset = .zero
        previewResetID += 1
    }

    private func revealPreviewTitle() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.86)) {
            previewTitleRevealProgress = 1
        }
    }

    private var recordEyebrow: String {
        switch (document.type, interfaceLanguage) {
        case (.customerOrder, .japanese): return "受注"
        case (.customerOrder, .simplifiedChinese), (.customerOrder, .traditionalChinese): return "受注"
        case (.customerOrder, .english), (.customerOrder, .korean), (.customerOrder, .nepali), (.customerOrder, .french), (.customerOrder, .vietnamese): return "Order received"
        case (.vendorEstimate, .japanese): return "仕入先見積記録"
        case (.vendorEstimate, .simplifiedChinese), (.vendorEstimate, .traditionalChinese): return "供应商报价记录"
        case (.vendorEstimate, .english), (.vendorEstimate, .korean), (.vendorEstimate, .nepali), (.vendorEstimate, .french), (.vendorEstimate, .vietnamese): return "Vendor quotation record"
        case (.vendorInvoice, .japanese): return "仕入先請求書記録"
        case (.vendorInvoice, .simplifiedChinese), (.vendorInvoice, .traditionalChinese): return "供应商请款书记录"
        case (.vendorInvoice, .english), (.vendorInvoice, .korean), (.vendorInvoice, .nepali), (.vendorInvoice, .french), (.vendorInvoice, .vietnamese): return "Vendor invoice record"
        case (.vendorReceipt, .japanese): return "仕入先領収書記録"
        case (.vendorReceipt, .simplifiedChinese), (.vendorReceipt, .traditionalChinese): return "供应商收据记录"
        case (.vendorReceipt, .english), (.vendorReceipt, .korean), (.vendorReceipt, .nepali), (.vendorReceipt, .french), (.vendorReceipt, .vietnamese): return "Vendor receipt record"
        case (.paymentNotice, .japanese): return "支払通知"
        case (.paymentNotice, .simplifiedChinese), (.paymentNotice, .traditionalChinese): return "付款通知"
        case (.paymentNotice, .english), (.paymentNotice, .korean), (.paymentNotice, .nepali), (.paymentNotice, .french), (.paymentNotice, .vietnamese): return "Payment notice"
        case (_, .japanese): return "帳票記録"
        case (_, .simplifiedChinese), (_, .traditionalChinese): return "表单记录"
        case (_, .english), (_, .korean), (_, .nepali), (_, .french), (_, .vietnamese): return "Document record"
        }
    }

    private var recordAttachmentTitle: String {
        switch (document.type, interfaceLanguage) {
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

    private var paymentProofTitle: String {
        localized(japanese: "支払証明", chinese: "支付证明", english: "Payment Proof")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch interfaceLanguage {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }

    private func clampedPreviewScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), maximumPreviewScale)
    }

    private var maximumPreviewScale: CGFloat { 2 }
}

private struct PreviewActionButtonStyle: ButtonStyle {
    let tint: Color
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(filled ? (configuration.isPressed ? tint.opacity(0.78) : tint) : Color.appInputBackground)
            .foregroundColor(filled ? .white : tint)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(filled ? Color.clear : Color.appDivider))
    }
}

private struct PreviewStampBarChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(Color.appPanel.opacity(0.96))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

private struct ZoomablePDFImageView: UIViewRepresentable {
    let image: UIImage
    let viewportSize: CGSize
    let maximumZoomScale: CGFloat
    let topInset: CGFloat
    let leftInset: CGFloat
    let bottomInset: CGFloat
    let rightInset: CGFloat
    let fitHeightRatio: CGFloat?
    let resetID: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = UIColor(Color.appPanel)
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = maximumZoomScale

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        scrollView.addSubview(imageView)

        context.coordinator.imageView = imageView
        let pageSize = pageSize
        context.coordinator.widthConstraint = imageView.widthAnchor.constraint(equalToConstant: pageSize.width)
        context.coordinator.heightConstraint = imageView.heightAnchor.constraint(equalToConstant: pageSize.height)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            context.coordinator.widthConstraint!,
            context.coordinator.heightConstraint!
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let shouldResetZoom = context.coordinator.image !== image ||
            context.coordinator.resetID != resetID ||
            context.coordinator.viewportSize != viewportSize
        context.coordinator.image = image
        context.coordinator.resetID = resetID
        context.coordinator.viewportSize = viewportSize
        context.coordinator.imageView?.image = image
        context.coordinator.maximumZoomScale = maximumZoomScale

        let pageSize = pageSize
        context.coordinator.widthConstraint?.constant = pageSize.width
        context.coordinator.heightConstraint?.constant = pageSize.height

        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.contentInset = contentInset(for: pageSize)
        scrollView.scrollIndicatorInsets = scrollView.contentInset

        if shouldResetZoom || scrollView.zoomScale < 1 {
            scrollView.setZoomScale(1, animated: false)
            scrollView.setContentOffset(CGPoint(x: -scrollView.contentInset.left, y: -scrollView.contentInset.top), animated: false)
        }
    }

    private var pageSize: CGSize {
        let aspect = pageAspect
        let availableWidth = max(1, viewportSize.width - leftInset - rightInset)
        let width: CGFloat
        if let fitHeightRatio {
            let targetHeight = max(1, viewportSize.height * min(max(fitHeightRatio, 0.1), 1))
            width = min(availableWidth, targetHeight / aspect)
        } else {
            width = availableWidth
        }
        return CGSize(width: width, height: width * aspect)
    }

    private var pageAspect: CGFloat {
        max(0.1, image.size.height / max(1, image.size.width))
    }

    private func contentInset(for pageSize: CGSize) -> UIEdgeInsets {
        let horizontalArea = max(1, viewportSize.width - leftInset - rightInset)
        let extraHorizontalSpace = max(0, horizontalArea - pageSize.width)
        return UIEdgeInsets(
            top: topInset,
            left: leftInset + extraHorizontalSpace / 2,
            bottom: bottomInset,
            right: rightInset + extraHorizontalSpace / 2
        )
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        var image: UIImage?
        var maximumZoomScale: CGFloat = 2
        var resetID = 0
        var viewportSize: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > 1 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = recognizer.location(in: imageView)
                let targetZoom = maximumZoomScale
                let width = scrollView.bounds.width / targetZoom
                let height = scrollView.bounds.height / targetZoom
                let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}

private struct OrderRecordAttachmentPreview: View {
    let attachment: OrderAttachment
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: attachment.isPDF ? "doc.richtext.fill" : "photo.fill")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appAccent)
                    .frame(width: 34, height: 34)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(2)
                    Text("\(attachment.isPDF ? "PDF" : localized(japanese: "画像", chinese: "图片", english: "Image")) / \(attachment.fileSizeText)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
            }

            Group {
                if attachment.isImage, let image = UIImage(data: attachment.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else if attachment.isPDF {
                    OrderRecordPDFPreview(data: attachment.data)
                } else {
                    Text(localized(japanese: "プレビューできないファイル形式です", chinese: "无法预览此文件格式", english: "This file format cannot be previewed."))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: attachment.isPDF ? 360 : 240)
            .background(Color.appInputBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
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

private struct OrderRecordPDFPreview: UIViewRepresentable {
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

private struct PrinterPDFIntroOverlay: View {
    let introKey: String
    let pageImage: UIImage
    let onComplete: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var printerOffsetY: CGFloat = 260
    @State private var pageProgress: CGFloat = 0
    @State private var pageCenterProgress: CGFloat = 0
    @State private var pageOpacity: CGFloat = 0
    @State private var overlayOpacity: CGFloat = 1
    @State private var overlayExitProgress: CGFloat = 0
    @State private var printerExitProgress: CGFloat = 0
    @State private var pageWobbleX: CGFloat = 0
    @State private var pageWobbleRotation: Double = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var didComplete = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let printerWidth = max(size.width * 1.36, 520)
            let printerHeight = printerWidth * 297 / 601
            let pageWidth = Self.finalPreviewPageWidth(in: size)
            let pageHeight = Self.finalPreviewPageHeight(for: pageImage, width: pageWidth)
            let printerBottomY = size.height + printerOffsetY
            let printerCenterY = printerBottomY - printerHeight / 2
            let pageStartY = size.height + pageHeight / 2
            let pageEndY = Self.finalPreviewPageTopInset + pageHeight / 2
            let printedPageCenterY = pageStartY + (pageEndY - pageStartY) * pageProgress
            let settledPageCenterY = size.height / 2
            let pageCenterY = printedPageCenterY + (settledPageCenterY - printedPageCenterY) * pageCenterProgress
            let pageScale = 1 - 0.05 * pageCenterProgress
            let printerExitOffsetY = (printerHeight + 24) * printerExitProgress
            let animationBackground = colorScheme == .dark ? Color.black : Color.white
            let pageShadow = colorScheme == .dark ? Color.black.opacity(0.42) : Color.black.opacity(0.12)

            ZStack {
                animationBackground
                    .ignoresSafeArea()
                    .opacity(1 - overlayExitProgress)

                printerIntroImage(named: "PDFPreviewPrinterIntro", width: printerWidth)
                    .position(x: size.width / 2, y: printerCenterY)
                    .offset(y: printerExitOffsetY)

                Image(uiImage: pageImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: pageWidth, height: pageHeight)
                    .background(Color.white)
                    .shadow(color: pageShadow, radius: 18, x: 0, y: 8)
                    .scaleEffect(pageScale)
                    .rotationEffect(.degrees(pageWobbleRotation))
                    .offset(x: pageWobbleX)
                    .position(x: size.width / 2, y: pageCenterY)
                    .opacity(pageOpacity * (1 - overlayExitProgress))

                printerIntroImage(named: "PDFPreviewPrinterIntroTop", width: printerWidth)
                    .position(x: size.width / 2, y: printerCenterY)
                    .offset(y: printerExitOffsetY)
            }
            .frame(width: size.width, height: size.height)
        }
        .opacity(overlayOpacity)
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .task(id: introKey) {
            await runAnimation()
        }
        .onDisappear {
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }

    private func printerIntroImage(named name: String, width: CGFloat) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
    }

    @MainActor
    private func runAnimation() async {
        didComplete = false
        overlayOpacity = 1
        overlayExitProgress = 0
        printerExitProgress = 0
        printerOffsetY = 260
        pageProgress = 0
        pageCenterProgress = 0
        pageOpacity = 0
        pageWobbleX = 0
        pageWobbleRotation = 0

        guard !reduceMotion else {
            overlayOpacity = 0
            completeIfNeeded()
            return
        }

        playPrinterSound()
        withAnimation(.spring(response: 1.0, dampingFraction: 0.88)) {
            printerOffsetY = 0
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.18)) {
            pageOpacity = 1
        }
        await runPagePrintFeed(duration: 6.0)
        guard !Task.isCancelled else { return }
        pageWobbleX = 0
        pageWobbleRotation = 0

        audioPlayer?.stop()
        audioPlayer = nil
        withAnimation(.spring(response: 1.0, dampingFraction: 0.9)) {
            pageCenterProgress = 1
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 1.0, dampingFraction: 0.82)) {
            overlayExitProgress = 1
        }
        withAnimation(.easeIn(duration: 0.1)) {
            printerExitProgress = 1
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled else { return }
        overlayOpacity = 0
        completeIfNeeded()
    }

    @MainActor
    private func runPagePrintFeed(duration: TimeInterval) async {
        let feedSteps: [(progress: CGFloat, advance: TimeInterval, pause: TimeInterval)] = [
            (0.07, 0.18, 0.10),
            (0.13, 0.15, 0.06),
            (0.20, 0.22, 0.12),
            (0.28, 0.18, 0.08),
            (0.35, 0.26, 0.14),
            (0.44, 0.20, 0.06),
            (0.52, 0.28, 0.12),
            (0.61, 0.22, 0.08),
            (0.70, 0.30, 0.14),
            (0.78, 0.20, 0.06),
            (0.86, 0.26, 0.10),
            (0.93, 0.22, 0.08),
            (1.00, 0.28, 0.00)
        ]
        let xOffsets: [CGFloat] = [-1.4, 1.0, -0.8, 1.3, -1.1, 0.7]
        let rotations: [Double] = [-0.18, 0.14, -0.1, 0.16, -0.12, 0.08]
        let activeDuration = feedSteps.reduce(0) { $0 + $1.advance + $1.pause }
        let timeScale = duration / activeDuration

        for (index, step) in feedSteps.enumerated() {
            guard !Task.isCancelled else { return }
            let advanceDuration = step.advance * timeScale
            withAnimation(.easeInOut(duration: advanceDuration)) {
                pageProgress = step.progress
                pageWobbleX = xOffsets[index % xOffsets.count]
                pageWobbleRotation = rotations[index % rotations.count]
            }
            try? await Task.sleep(nanoseconds: UInt64(advanceDuration * 1_000_000_000))

            guard !Task.isCancelled else { return }
            let pauseDuration = step.pause * timeScale
            if pauseDuration > 0 {
                withAnimation(.easeOut(duration: min(0.08, pauseDuration))) {
                    pageWobbleX = 0
                    pageWobbleRotation = 0
                }
                try? await Task.sleep(nanoseconds: UInt64(pauseDuration * 1_000_000_000))
            }
        }

        withAnimation(.easeOut(duration: 0.12)) {
            pageWobbleX = 0
            pageWobbleRotation = 0
        }
    }

    private func playPrinterSound() {
        guard let sound = NSDataAsset(name: "PDFPreviewPrinterSound") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            let player = try AVAudioPlayer(data: sound.data)
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            audioPlayer = nil
        }
    }

    private func completeIfNeeded() {
        guard !didComplete else { return }
        didComplete = true
        onComplete(introKey)
    }

    private static let finalPreviewPageTopInset: CGFloat = 110

    private static func finalPreviewPageWidth(in viewportSize: CGSize) -> CGFloat {
        max(1, viewportSize.width - 16)
    }

    private static func finalPreviewPageHeight(for image: UIImage, width: CGFloat) -> CGFloat {
        let aspect = max(0.1, image.size.height / max(1, image.size.width))
        return width * aspect
    }
}

private enum PreviewSourceFileExporter {
    static func export(_ document: BusinessDocument) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: document))
        let file = PreviewSharedFormFile(exportedAt: Date(), document: document)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: url, options: .atomic)
        return url
    }

    private static func fileName(for document: BusinessDocument) -> String {
        let title = document.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? document.type.title
            : "\(document.number)-\(document.type.title)"
        return "\(sanitizedFileBaseName(title, fallback: "shoko-form")).shokoform"
    }

    private static func sanitizedFileBaseName(_ value: String, fallback: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = value
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }
}

private struct PreviewSharedFormFile: Codable {
    var version = 1
    var exportedAt: Date
    var document: BusinessDocument
}
