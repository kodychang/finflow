import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import Vision

struct ScanFormDraft {
    let documentType: DocumentType
    let direction: ProjectDirection
    let regions: [ScanFormRegion]

    func text(for role: ScanFormRegionRole) -> String {
        regions
            .filter { $0.role == role }
            .map(\.recognizedText)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ScanFormRegion: Identifiable, Hashable {
    var id = UUID()
    var rect: CGRect
    var role: ScanFormRegionRole
    var recognizedText: String = ""
}

enum ScanFormRegionRole: String, CaseIterable, Identifiable {
    case partner
    case issuer
    case project
    case item
    case content
    case payment
    case note
    case terms

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .partner: return .appBlue
        case .issuer: return .teal
        case .project: return .appMint
        case .item: return .orange
        case .content: return .purple
        case .payment: return .red
        case .note: return .gray
        case .terms: return .brown
        }
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .partner: return Self.localized(language, japanese: "顧客・仕入先情報", chinese: "客户/厂商信息", english: "Customer/Vendor")
        case .issuer: return Self.localized(language, japanese: "自社情報", chinese: "自己的信息", english: "Issuer")
        case .project: return Self.localized(language, japanese: "案件", chinese: "项目", english: "Project")
        case .item: return Self.localized(language, japanese: "品目", chinese: "品项", english: "Item")
        case .content: return Self.localized(language, japanese: "本文・明細", chinese: "内容区域", english: "Content")
        case .payment: return Self.localized(language, japanese: "振込・支払情報", chinese: "汇款/付款信息", english: "Payment")
        case .note: return Self.localized(language, japanese: "備考", chinese: "备注", english: "Notes")
        case .terms: return Self.localized(language, japanese: "条件", chinese: "条件", english: "Terms")
        }
    }
}

private enum ScanOCRLanguageOption: String, CaseIterable, Identifiable {
    case japanese
    case korean
    case chinese
    case english

    var id: String { rawValue }

    var recognitionLanguages: [String] {
        switch self {
        case .japanese: return ["ja-JP"]
        case .korean: return ["ko-KR"]
        case .chinese: return ["zh-Hans", "zh-Hant"]
        case .english: return ["en-US"]
        }
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .japanese: return ScanFormRegionRole.localized(language, japanese: "日本語", chinese: "日语", english: "Japanese")
        case .korean: return ScanFormRegionRole.localized(language, japanese: "韓国語", chinese: "韩语", english: "Korean")
        case .chinese: return ScanFormRegionRole.localized(language, japanese: "中国語", chinese: "汉语", english: "Chinese")
        case .english: return ScanFormRegionRole.localized(language, japanese: "英語", chinese: "英文", english: "English")
        }
    }
}

struct ScanFormScreen: View {
    @ObservedObject var store: DocumentStore
    let language: AppLanguage
    let onBack: () -> Void
    let onCreateDraft: (ScanFormDraft) -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var isImagePickerPresented = false
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var direction: ProjectDirection = .customer
    @State private var selectedType: DocumentType = .invoice
    @State private var selectedRole: ScanFormRegionRole = .partner
    @State private var regions: [ScanFormRegion] = []
    @State private var activeRegionID: ScanFormRegion.ID?
    @State private var pendingRegion: ScanFormRegion?
    @State private var editingRegionID: ScanFormRegion.ID?
    @State private var errorMessage = ""
    @AppStorage("native.shokoForms.scanOCRLanguageOptions.v1") private var selectedOCRLanguageOptionsRaw = "english"

    private var availableTypes: [DocumentType] {
        DocumentType.allCases.filter { direction == .vendor ? $0.isVendorForm : !$0.isVendorForm }
    }

    private var hasScanWorkInProgress: Bool {
        selectedImage != nil || !regions.isEmpty || pendingRegion != nil || !errorMessage.isEmpty
    }

    private var availableRoles: [ScanFormRegionRole] {
        var roles: [ScanFormRegionRole] = [.partner, .issuer]
        if selectedType.showsLinePrices {
            roles.append(.item)
        }
        if selectedType.showsPaymentDetails || selectedType.isVendorForm {
            roles.append(.payment)
        }
        roles.append(contentsOf: [.note, .terms])
        if selectedType == .customerFiles {
            roles.insert(.project, at: min(2, roles.count))
            roles.insert(.content, at: min(3, roles.count))
        }
        return roles
    }

    private var selectedOCROptions: Set<ScanOCRLanguageOption> {
        let values = selectedOCRLanguageOptionsRaw
            .split(separator: ",")
            .compactMap { ScanOCRLanguageOption(rawValue: String($0)) }
        let set = Set(values)
        return set.isEmpty ? [.english] : set
    }

    private var selectedOCRRecognitionLanguages: [String] {
        var languages: [String] = []
        for option in ScanOCRLanguageOption.allCases where selectedOCROptions.contains(option) {
            for language in option.recognitionLanguages where !languages.contains(language) {
                languages.append(language)
            }
        }
        return languages.isEmpty ? ["en-US"] : languages
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if selectedImage == nil && regions.isEmpty {
                        emptyScanGuide
                        setupCard
                    } else {
                        setupCard
                        imageCard
                        regionCard
                        createButton
                    }
                }
                .padding(18)
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $isImagePickerPresented) {
            ScanImagePicker { data in
                loadImage(data)
            }
        }
        .sheet(item: $pendingRegion) { region in
            ScanRegionConfirmationSheet(
                image: selectedImage,
                region: region,
                roles: availableRoles,
                language: language,
                recognitionLanguages: selectedOCRRecognitionLanguages,
                onSave: saveConfirmedRegion,
                onReselect: {
                    pendingRegion = nil
                    editingRegionID = nil
                }
            )
        }
        .onChange(of: direction) { _ in
            if !availableTypes.contains(selectedType) {
                selectedType = availableTypes.first ?? .invoice
            }
            normalizeSelectedRole()
        }
        .onChange(of: selectedType) { _ in
            normalizeSelectedRole()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: handleBack) {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 38, height: 38)
                    .foregroundColor(.appInk)
                    .background(Color.appInputBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(localizedTitle)
                    .font(AppFont.pageTitle(.semibold))
                    .foregroundColor(.appInk)
                Text(localizedSubtitle)
                    .font(AppFont.small(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.appPanel)
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
    }

    private var emptyScanGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 54, height: 54)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized(japanese: "画像から編集できる帳票を作成", chinese: "从图片建立可编辑表单", english: "Create an editable form from an image"))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.appInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(localized(japanese: "紙の帳票やスクリーンショットを読み込み、必要な範囲だけを指定して OCR 文字を表單欄位に整理します。", chinese: "上传纸本表单或截图，只框选需要的区域，把 OCR 文字整理到表单栏位。", english: "Import a paper form or screenshot, select only the useful areas, and organize OCR text into form fields."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                guideRow(number: "1", title: localized(japanese: "画像を選ぶ", chinese: "选择图片", english: "Choose an image"), detail: localized(japanese: "明るく、文字が傾きすぎていない画像を選択します。", chinese: "建议选择明亮、文字不要过度倾斜的图片。", english: "Use a bright image where text is not heavily tilted."))
                guideRow(number: "2", title: localized(japanese: "必要な範囲をドラッグ", chinese: "拖曳需要的区域", english: "Drag the needed area"), detail: localized(japanese: "範囲ごとに確認画面で文字を分析し、必要なら修正します。", chinese: "每个区域会进入确认画面分析文字，也可以手动修改。", english: "Each region opens a confirmation step where OCR text can be edited."))
                guideRow(number: "3", title: localized(japanese: "内容の所属を指定", chinese: "指定内容归属", english: "Assign the field type"), detail: localized(japanese: "顧客、自社、品目、備考、振込、条件など、帳票に必要な項目に分けます。", chinese: "可分配到客户、自己、品项、备注、汇款、条件等对应内容。", english: "Assign text to partner, issuer, items, notes, payment, terms, and other available fields."))
            }

            Text(localized(japanese: "注意: OCR は読み取り補助です。保存前に金額、会社名、条件を必ず確認してください。", chinese: "注意：OCR 是辅助读取。保存前请务必确认金额、公司名与条件内容。", english: "Note: OCR is an assistive step. Confirm amounts, company names, and terms before saving."))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(16)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
    }

    private func guideRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(buttonAccent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized(japanese: "基本設定", chinese: "基本设置", english: "Setup"))
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)

            Picker(localized(japanese: "对象", chinese: "对象", english: "Partner type"), selection: $direction) {
                ForEach(ProjectDirection.allCases) { value in
                    Text(value.localizedTitle(language)).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Picker(localized(japanese: "帳票", chinese: "表单", english: "Form"), selection: $selectedType) {
                ForEach(availableTypes) { type in
                    Text(type.localizedTitle(language)).tag(type)
                }
            }
            .pickerStyle(.menu)

            ocrLanguageSelection

            Button {
                isImagePickerPresented = true
            } label: {
                Label(localized(japanese: "画像を選択", chinese: "选择图片", english: "Choose Image"), systemImage: "photo")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(buttonAccent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
    }

    private var ocrLanguageSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized(japanese: "OCR 読み取り言語", chinese: "OCR 读取语言", english: "OCR Languages"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(ScanOCRLanguageOption.allCases) { option in
                    Button {
                        toggleOCROption(option)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedOCROptions.contains(option) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedOCROptions.contains(option) ? buttonAccent : .appMuted)
                            Text(option.localizedTitle(language))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appInk)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 36)
                        .background(selectedOCROptions.contains(option) ? buttonAccent.opacity(0.10) : Color.appInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Text(localized(japanese: "複数選択できます。英語は初期選択です。", chinese: "可以多选。英文为默认选择。", english: "Multiple languages can be selected. English is selected by default."))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
        }
    }

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized(japanese: "画像プレビュー", chinese: "图片预览", english: "Image Preview"))
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)

            if let selectedImage {
                ScanRegionCanvas(
                    image: selectedImage,
                    regions: $regions,
                    selectedRole: selectedRole,
                    activeRegionID: $activeRegionID,
                    onRegionSelected: beginRegionConfirmation
                )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(selectedImage.size.width / max(selectedImage.size.height, 1), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundColor(buttonAccent)
                    Text(localized(japanese: "画像を選択して、帳票上をドラッグして範囲を作成します。", chinese: "选择图片后，在表单图片上拖曳建立区域。", english: "Choose an image, then drag on the form to create regions."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
    }

    private var regionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized(japanese: "区域指定", chinese: "区域指定", english: "Regions"))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Spacer()
            }

            Picker(localized(japanese: "区域の内容", chinese: "区域内容", english: "Region content"), selection: $selectedRole) {
                ForEach(availableRoles) { role in
                    Text(role.localizedTitle(language)).tag(role)
                }
            }
            .pickerStyle(.menu)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
            }

            if regions.isEmpty {
                Text(localized(japanese: "まだ区域がありません。画像上をドラッグしてください。", chinese: "还没有区域。请在图片上拖曳框选。", english: "No regions yet. Drag on the image to select one."))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(regions) { region in
                        regionRow(region)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
    }

    private func regionRow(_ region: ScanFormRegion) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(region.role.color)
                .frame(width: 14, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(region.role.localizedTitle(language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text(region.recognizedText.isEmpty ? localized(japanese: "未识别", chinese: "未识别", english: "Not recognized") : region.recognizedText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                edit(region)
            } label: {
                Image(systemName: "square.and.pencil")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(region.role.color)
            Button {
                regions.removeAll { $0.id == region.id }
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.red)
        }
        .padding(10)
        .background(region.id == activeRegionID ? region.role.color.opacity(0.12) : Color.appInputBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(region.id == activeRegionID ? region.role.color.opacity(0.75) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var createButton: some View {
        Button {
            onCreateDraft(ScanFormDraft(documentType: selectedType, direction: direction, regions: regions))
        } label: {
            Label(localized(japanese: "編集表单を作成", chinese: "建立编辑表单", english: "Create Editable Form"), systemImage: "square.and.pencil")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(canCreate ? buttonAccent : Color.appMuted.opacity(0.28))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canCreate)
    }

    private var canCreate: Bool {
        selectedImage != nil && !regions.isEmpty
    }

    private func loadImage(_ data: Data?) {
        errorMessage = ""
        guard let data, let image = UIImage(data: data) else {
            errorMessage = localized(japanese: "画像を読み込めませんでした。", chinese: "无法读取图片。", english: "Could not load the image.")
            return
        }
        selectedImageData = data
        selectedImage = image
        regions = []
        activeRegionID = nil
    }

    private func toggleOCROption(_ option: ScanOCRLanguageOption) {
        var options = selectedOCROptions
        if options.contains(option) {
            options.remove(option)
        } else {
            options.insert(option)
        }
        if options.isEmpty {
            options.insert(.english)
        }
        selectedOCRLanguageOptionsRaw = ScanOCRLanguageOption.allCases
            .filter { options.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    private func handleBack() {
        if hasScanWorkInProgress {
            resetScanWorkspace()
        } else {
            onBack()
        }
    }

    private func resetScanWorkspace() {
        selectedImageData = nil
        selectedImage = nil
        regions = []
        activeRegionID = nil
        pendingRegion = nil
        editingRegionID = nil
        errorMessage = ""
        selectedRole = availableRoles.first ?? .partner
    }

    private func normalizeSelectedRole() {
        if !availableRoles.contains(selectedRole) {
            selectedRole = availableRoles.first ?? .partner
        }
    }

    private func beginRegionConfirmation(_ rect: CGRect) {
        editingRegionID = nil
        pendingRegion = ScanFormRegion(rect: rect, role: selectedRole)
    }

    private func edit(_ region: ScanFormRegion) {
        editingRegionID = region.id
        activeRegionID = region.id
        pendingRegion = region
    }

    private func saveConfirmedRegion(_ region: ScanFormRegion) {
        if let editingRegionID,
           let index = regions.firstIndex(where: { $0.id == editingRegionID }) {
            regions[index] = region
        } else {
            regions.append(region)
        }
        activeRegionID = region.id
        pendingRegion = nil
        editingRegionID = nil
    }

    private var localizedTitle: String { localized(japanese: "スキャン帳票", chinese: "扫描表单", english: "Scan Form") }
    private var localizedSubtitle: String {
        localized(
            japanese: "画像から範囲を指定して文字を読み取り、編集できる帳票に変換します。",
            chinese: "从图片指定区域并读取文字，转换成可编辑的表单。",
            english: "Select regions from an image and convert text into an editable form."
        )
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        ScanFormRegionRole.localized(language, japanese: japanese, chinese: chinese, english: english)
    }
}

private struct ScanRegionCanvas: View {
    let image: UIImage
    @Binding var regions: [ScanFormRegion]
    let selectedRole: ScanFormRegionRole
    @Binding var activeRegionID: ScanFormRegion.ID?
    let onRegionSelected: (CGRect) -> Void
    @State private var draftRect: CGRect?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(Color.appInputBackground)

                ForEach(regions) { region in
                    regionRect(region.rect, in: proxy.size)
                        .stroke(region.role.color, lineWidth: region.id == activeRegionID ? 3 : 2)
                        .background(regionRect(region.rect, in: proxy.size).fill(region.role.color.opacity(0.18)))
                        .overlay(regionRect(region.rect, in: proxy.size).stroke(Color.white.opacity(region.id == activeRegionID ? 0.85 : 0.35), lineWidth: 1))
                        .onTapGesture {
                            activeRegionID = region.id
                        }
                }

                if let draftRect {
                    regionRect(draftRect, in: proxy.size)
                        .stroke(selectedRole.color, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .background(regionRect(draftRect, in: proxy.size).fill(selectedRole.color.opacity(0.14)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        draftRect = normalizedRect(from: value.startLocation, to: value.location, size: proxy.size)
                    }
                    .onEnded { value in
                        let rect = normalizedRect(from: value.startLocation, to: value.location, size: proxy.size)
                        draftRect = nil
                        guard rect.width > 0.025, rect.height > 0.025 else { return }
                        onRegionSelected(rect)
                    }
            )
        }
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint, size: CGSize) -> CGRect {
        let minX = max(0, min(start.x, end.x) / max(size.width, 1))
        let minY = max(0, min(start.y, end.y) / max(size.height, 1))
        let maxX = min(1, max(start.x, end.x) / max(size.width, 1))
        let maxY = min(1, max(start.y, end.y) / max(size.height, 1))
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func regionRect(_ rect: CGRect, in size: CGSize) -> Path {
        Path(CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height))
    }
}

private struct ScanRegionConfirmationSheet: View {
    let image: UIImage?
    let region: ScanFormRegion
    let roles: [ScanFormRegionRole]
    let language: AppLanguage
    let recognitionLanguages: [String]
    let onSave: (ScanFormRegion) -> Void
    let onReselect: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var role: ScanFormRegionRole
    @State private var recognizedText: String
    @State private var isRecognizing = false
    @State private var errorMessage = ""
    @State private var previewScale: CGFloat = 1
    @State private var previewOffset: CGSize = .zero

    init(
        image: UIImage?,
        region: ScanFormRegion,
        roles: [ScanFormRegionRole],
        language: AppLanguage,
        recognitionLanguages: [String],
        onSave: @escaping (ScanFormRegion) -> Void,
        onReselect: @escaping () -> Void
    ) {
        self.image = image
        self.region = region
        self.roles = roles
        self.language = language
        self.recognitionLanguages = recognitionLanguages
        self.onSave = onSave
        self.onReselect = onReselect
        _role = State(initialValue: roles.contains(region.role) ? region.role : (roles.first ?? .partner))
        _recognizedText = State(initialValue: region.recognizedText)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localized(japanese: "選択した区域が正しいか確認してください。", chinese: "请确认选取的区域是否正确。", english: "Confirm the selected region."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)

                    previewCard
                    roleCard
                    textCard
                }
                .padding(18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localized(japanese: "区域确认", chinese: "区域确认", english: "Confirm Region"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "重選択", chinese: "重选区域", english: "Reselect")) {
                        onReselect()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized(japanese: "保存", chinese: "保存", english: "Save")) {
                        var updated = region
                        updated.role = role
                        updated.recognizedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recognizeSelectedRegion()
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(localized(japanese: "選択区域", chinese: "选取区域", english: "Selected Region"))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Spacer()
                Button {
                    zoomPreview()
                } label: {
                    Label(localized(japanese: "拡大", chinese: "放大", english: "Zoom"), systemImage: "plus.magnifyingglass")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(role.color)
                Button {
                    resetPreviewZoom()
                } label: {
                    Label(localized(japanese: "原寸", chinese: "原本大小", english: "Reset"), systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.appMuted)
            }

            if let croppedImage {
                ZoomableScanRegionPreview(
                    image: croppedImage,
                    tint: role.color,
                    scale: $previewScale,
                    offset: $previewOffset
                )
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 280)
            } else {
                Text(localized(japanese: "区域画像を表示できません。", chinese: "无法显示区域图片。", english: "Could not show the selected image region."))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Color.appInputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
    }

    private var roleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized(japanese: "所属内容", chinese: "所属内容", english: "Field Type"))
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)

            Picker(localized(japanese: "所属内容", chinese: "所属内容", english: "Field Type"), selection: $role) {
                ForEach(roles) { role in
                    HStack {
                        Text(role.localizedTitle(language))
                    }
                    .tag(role)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(role.color)
                    .frame(width: 18, height: 18)
                Text(role.localizedTitle(language))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
            }
        }
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
    }

    private var textCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localized(japanese: "OCR文字", chinese: "OCR 文字", english: "OCR Text"))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Spacer()
                if isRecognizing {
                    ProgressView()
                } else {
                    Button {
                        recognizeSelectedRegion()
                    } label: {
                        Label(localized(japanese: "再分析", chinese: "重新分析", english: "Analyze Again"), systemImage: "text.viewfinder")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(role.color)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
            }

            TextEditor(text: $recognizedText)
                .font(.subheadline)
                .foregroundColor(.appInk)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        }
        .padding(14)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
    }

    private var croppedImage: UIImage? {
        image?.cropped(toNormalizedRect: region.rect)
    }

    private func recognizeSelectedRegion() {
        guard let croppedImage else {
            errorMessage = localized(japanese: "区域画像を読み取れません。重選択してください。", chinese: "无法读取区域图片。请重选区域。", english: "Could not read the region. Reselect it.")
            return
        }
        isRecognizing = true
        errorMessage = ""
        ScanFormTextRecognizer.recognize(image: croppedImage, recognitionLanguages: recognitionLanguages) { result in
            isRecognizing = false
            switch result {
            case .success(let text):
                recognizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            case .failure:
                errorMessage = localized(japanese: "OCRに失敗しました。文字を手入力するか、区域を重選択してください。", chinese: "OCR 失败。可以手动编辑文字，或重选区域。", english: "OCR failed. Edit the text manually or reselect the region.")
            }
        }
    }

    private func zoomPreview() {
        withAnimation(.easeInOut(duration: 0.18)) {
            previewScale = min(previewScale + 0.75, 4)
        }
    }

    private func resetPreviewZoom() {
        withAnimation(.easeInOut(duration: 0.18)) {
            previewScale = 1
            previewOffset = .zero
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        ScanFormRegionRole.localized(language, japanese: japanese, chinese: chinese, english: english)
    }
}

private struct ZoomableScanRegionPreview: View {
    let image: UIImage
    let tint: Color
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @State private var dragStartOffset: CGSize = .zero
    @State private var magnificationStartScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .gesture(dragGesture(in: proxy.size).simultaneously(with: magnificationGesture()))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint, lineWidth: 2))
                .clipped()
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else {
                    offset = .zero
                    return
                }
                offset = clampedOffset(
                    CGSize(
                        width: dragStartOffset.width + value.translation.width,
                        height: dragStartOffset.height + value.translation.height
                    ),
                    in: size
                )
            }
            .onEnded { _ in
                dragStartOffset = offset
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(magnificationStartScale * value, 1), 4)
                if scale == 1 {
                    offset = .zero
                    dragStartOffset = .zero
                }
            }
            .onEnded { _ in
                magnificationStartScale = scale
                if scale == 1 {
                    offset = .zero
                    dragStartOffset = .zero
                }
            }
    }

    private func clampedOffset(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let maxX = max(0, size.width * (scale - 1) / 2)
        let maxY = max(0, size.height * (scale - 1) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}

private enum ScanFormTextRecognizer {
    static func recognize(image: UIImage, recognitionLanguages: [String], completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ScanFormOCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let text = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            DispatchQueue.main.async { completion(.success(text)) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages.isEmpty ? ["en-US"] : recognitionLanguages

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

}

private enum ScanFormOCRError: Error {
    case invalidImage
}

private struct ScanImagePicker: UIViewControllerRepresentable {
    let onSelect: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, dismiss: dismiss)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (Data?) -> Void
        let dismiss: DismissAction

        init(onSelect: @escaping (Data?) -> Void, dismiss: DismissAction) {
            self.onSelect = onSelect
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onSelect(nil)
                dismiss()
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                DispatchQueue.main.async {
                    self.onSelect(data)
                    self.dismiss()
                }
            }
        }
    }
}

private extension UIImage {
    func cropped(toNormalizedRect rect: CGRect) -> UIImage? {
        guard let cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let crop = CGRect(
            x: rect.minX * width,
            y: rect.minY * height,
            width: rect.width * width,
            height: rect.height * height
        ).integral
        guard crop.width > 2, crop.height > 2, let cropped = cgImage.cropping(to: crop) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

private extension ScanFormRegionRole {
    static func localized(_ language: AppLanguage, japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese, .traditionalChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return english
        }
    }
}
