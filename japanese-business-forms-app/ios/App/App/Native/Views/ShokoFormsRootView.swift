import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShokoFormsRootView: View {
    @StateObject private var store = DocumentStore()
    @State private var selectedSection: AppSection = .menu
    @AppStorage("shokoFormsDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("shokoFormsSyncButtonColorWithTableTemplate") private var syncButtonColorWithTableTemplate = false
    @State private var openedBackupData: Data?
    @State private var isOpenedBackupDialogPresented = false
    @State private var openedBackupStatus = ""
    @State private var isOpenedBackupStatusPresented = false

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                HStack(spacing: 0) {
                    SidebarView(store: store, selectedSection: $selectedSection)
                        .frame(width: 304)
                    if selectedSection == .account {
                        AccountManagementScreen(
                            store: store,
                            isDarkModeEnabled: $isDarkModeEnabled,
                            syncButtonColorWithTableTemplate: $syncButtonColorWithTableTemplate
                        )
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .projects {
                        ProjectManagementScreen(store: store, selectedSection: $selectedSection)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .customers {
                        CustomerManagementScreen(store: store)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .products {
                        ProductManagementScreen(store: store)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else {
                        EditorScreen(store: store)
                            .frame(minWidth: 430, maxWidth: .infinity)
                        PreviewScreen(document: store.current)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    }
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            } else {
                TabView(selection: $selectedSection) {
                    SidebarView(store: store, selectedSection: $selectedSection)
                        .tabItem { Label("ホーム", systemImage: "house") }
                        .tag(AppSection.menu)
                    EditorScreen(store: store)
                        .tabItem { Label("作成", systemImage: "doc.text") }
                        .tag(AppSection.form)
                    PreviewScreen(document: store.current)
                        .tabItem { Label("確認", systemImage: "doc.richtext") }
                        .tag(AppSection.preview)
                    AccountManagementScreen(
                        store: store,
                        isDarkModeEnabled: $isDarkModeEnabled,
                        syncButtonColorWithTableTemplate: $syncButtonColorWithTableTemplate
                    )
                        .tabItem { Label("設定", systemImage: "person.crop.circle") }
                        .tag(AppSection.account)
                    ProjectManagementScreen(store: store, selectedSection: $selectedSection)
                        .tabItem { Label("專案", systemImage: "folder") }
                        .tag(AppSection.projects)
                    CustomerManagementScreen(store: store)
                        .tabItem { Label("廠商", systemImage: "building.2") }
                        .tag(AppSection.customers)
                    ProductManagementScreen(store: store)
                        .tabItem { Label("商品", systemImage: "shippingbox") }
                        .tag(AppSection.products)
                }
                .accentColor(buttonAccent)
            }
        }
        .environment(\.appButtonAccent, buttonAccent)
        .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        .onOpenURL { url in
            readOpenedBackup(from: url)
        }
        .confirmationDialog("備份檔案を導入", isPresented: $isOpenedBackupDialogPresented, titleVisibility: .visible) {
            Button("融合舊有內容") {
                importOpenedBackup(mode: .merge)
            }
            Button("從備份建立全新內容", role: .destructive) {
                importOpenedBackup(mode: .replace)
            }
            Button("キャンセル", role: .cancel) {
                openedBackupData = nil
            }
        } message: {
            Text("外部備份檔を検出しました。導入方式を選択してください。")
        }
        .alert("備份導入", isPresented: $isOpenedBackupStatusPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(openedBackupStatus)
        }
    }

    private var buttonAccent: Color {
        syncButtonColorWithTableTemplate ? store.current.colorTemplate.swiftUIColor : .appAccent
    }

    private func readOpenedBackup(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            openedBackupData = try Data(contentsOf: url)
            selectedSection = .account
            isOpenedBackupDialogPresented = true
        } catch {
            openedBackupStatus = "備份檔案を読み込めませんでした。"
            isOpenedBackupStatusPresented = true
        }
    }

    private func importOpenedBackup(mode: BackupImportMode) {
        guard let openedBackupData else { return }
        do {
            try store.importBackupData(openedBackupData, mode: mode)
            openedBackupStatus = mode == .merge ? "備份內容を融合しました。" : "備份內容から全新內容を建立しました。"
        } catch {
            openedBackupStatus = "備份檔案を導入できませんでした。"
        }
        self.openedBackupData = nil
        isOpenedBackupStatusPresented = true
    }
}

enum AppSection: Hashable {
    case menu
    case form
    case preview
    case account
    case projects
    case customers
    case products
}

struct AccountManagementScreen: View {
    @ObservedObject var store: DocumentStore
    @Binding var isDarkModeEnabled: Bool
    @Binding var syncButtonColorWithTableTemplate: Bool
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var issuerName = ""
    @State private var issuerRegistration = ""
    @State private var issuerContact = ""
    @State private var issuerPhone = ""
    @State private var issuerEmail = ""
    @State private var issuerAddress = ""
    @State private var issuerLogoData: Data?
    @State private var issuerLogoScale = 1.0
    @State private var issuerLogoStatus = ""
    @State private var editingIssuerID: IssuerProfile.ID?
    @State private var isBackupImporterPresented = false
    @State private var isBackupImportOptionsPresented = false
    @State private var backupSharePayload: SharePayload?
    @State private var pendingBackupData: Data?
    @State private var backupStatus = ""

    var body: some View {
        ManagementScroll(title: "設定・アカウント管理", subtitle: "自社情報を保存し、入力時の候補として再利用します。") {
            SectionCard(title: "外觀") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $isDarkModeEnabled) {
                        Label("夜間模式", systemImage: isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: buttonAccent))
                    .padding(.vertical, 4)

                    Toggle(isOn: $syncButtonColorWithTableTemplate) {
                        Label("按鈕顏色同步表格配色", systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: buttonAccent))
                    .padding(.vertical, 4)
                }
            }

            SectionCard(title: "帳票配色") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("表格配色", selection: colorTemplateBinding) {
                        ForEach(DocumentColorTemplate.allCases) { template in
                            Text(template.title).tag(template.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .pillFormInput()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                        ForEach(DocumentColorTemplate.allCases) { template in
                            Button {
                                store.applyDefaultColorTemplate(template.rawValue)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(template.swiftUIColor)
                                        .frame(height: 18)
                                    Text(template.title)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.appInk)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appInputBackground)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.defaultColorTemplateId == template.rawValue ? buttonAccent : Color.appDivider))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }

            SectionCard(title: "本地備份") {
                VStack(alignment: .leading, spacing: 12) {
                    ManagementPrimaryButton(title: "完整內容を備份して共有", systemImage: "square.and.arrow.up") {
                        exportBackup()
                    }
                    ManagementPrimaryButton(title: "備份檔案を導入", systemImage: "tray.and.arrow.down.fill") {
                        isBackupImporterPresented = true
                    }
                    ManagementPrimaryButton(title: "目前草稿を破棄", systemImage: "doc.badge.minus") {
                        store.discardDraft()
                        backupStatus = "草稿を破棄しました。"
                    }
                    if !backupStatus.isEmpty {
                        Text(backupStatus)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                    }
                }
            }

            companyInformationSection
        }
        .fileImporter(
            isPresented: $isBackupImporterPresented,
            allowedContentTypes: [.data, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result,
               let url = urls.first {
                readBackupData(from: url)
            }
        }
        .confirmationDialog("備份導入方式", isPresented: $isBackupImportOptionsPresented, titleVisibility: .visible) {
            Button("融合舊有內容") {
                importPendingBackup(mode: .merge)
            }
            Button("從備份建立全新內容", role: .destructive) {
                importPendingBackup(mode: .replace)
            }
            Button("キャンセル", role: .cancel) {
                pendingBackupData = nil
            }
        } message: {
            Text("融合不會覆蓋本機既有資料；全新內容會以備份檔重新建立。")
        }
        .sheet(item: $backupSharePayload) { payload in
            ShareSheet(url: payload.url)
        }
    }

    private var companyInformationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CompanySettingsHeader(
                title: "会社情報",
                subtitle: editingIssuerID == nil ? "帳票に使う自社情報を登録します。" : "保存済みアカウントを編集中です。",
                isEditing: editingIssuerID != nil
            )

            currentIssuerCard
            issuerEditorCard
            savedIssuerProfilesCard
        }
    }

    private var colorTemplateBinding: Binding<String> {
        Binding(
            get: { store.defaultColorTemplateId },
            set: { store.applyDefaultColorTemplate($0) }
        )
    }

    private var currentIssuerCard: some View {
        CompanySettingsPanel(title: "現在の帳票情報", systemImage: "building.2.crop.circle") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    currentIssuerLogoPreview
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.current.issuerName.isEmpty ? "自社名未入力" : store.current.issuerName)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.appInk)
                            .lineLimit(2)
                        CompanyInfoLine(systemImage: "number", text: store.current.issuerRegistration)
                        CompanyInfoLine(systemImage: "phone", text: store.current.issuerPhone)
                        CompanyInfoLine(systemImage: "envelope", text: store.current.issuerEmail)
                    }
                    Spacer(minLength: 0)
                }

                if !store.current.issuerAddress.isEmpty {
                    CompanyInfoLine(systemImage: "mappin.and.ellipse", text: store.current.issuerAddress)
                }

                HStack(spacing: 10) {
                    Button {
                        store.rememberIssuerFromCurrent()
                    } label: {
                        Label("現在情報を保存", systemImage: "tray.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyFilledButtonStyle())

                    Button {
                        loadCurrentIssuerIntoForm()
                    } label: {
                        Label("編集へ反映", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyOutlineButtonStyle())
                }

            }
        }
    }

    @ViewBuilder
    private var currentIssuerLogoPreview: some View {
        if let logoData = store.current.issuerLogoData {
            ManagementLogoThumbnail(data: logoData, scale: store.current.issuerLogoScale)
                .frame(width: 76, height: 54)
        } else {
            CompanyLogoPlaceholder(systemImage: "photo", title: "Logo", subtitle: "未設定")
                .frame(width: 76, height: 54)
        }
    }

    private var issuerEditorCard: some View {
        CompanySettingsPanel(
            title: editingIssuerID == nil ? "会社情報を新增" : "会社情報を編集",
            systemImage: editingIssuerID == nil ? "plus.circle" : "pencil.circle"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                logoEditor

                VStack(spacing: 12) {
                    FormField(title: "会社名") {
                        TextField("", text: $issuerName, prompt: .inputPrompt("会社名"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    HStack(alignment: .top, spacing: 12) {
                        FormField(title: "登録番号") {
                            TextField("", text: $issuerRegistration, prompt: .inputPrompt("T1234567890123"))
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                        FormField(title: "連絡人") {
                            TextField("", text: $issuerContact, prompt: .inputPrompt("担当者"))
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        FormField(title: "電話") {
                            TextField("", text: $issuerPhone, prompt: .inputPrompt("電話"))
                                .keyboardType(.phonePad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                        FormField(title: "メール") {
                            TextField("", text: $issuerEmail, prompt: .inputPrompt("メール"))
                                .keyboardType(.emailAddress)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    }
                    FormField(title: "住所") {
                        MultilineTextInput(text: $issuerAddress)
                            .multilineFormInput(minHeight: 92)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        saveIssuerForm()
                    } label: {
                        Label(editingIssuerID == nil ? "保存" : "更新", systemImage: editingIssuerID == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyFilledButtonStyle())
                    .disabled(!isIssuerFormValid)
                    .opacity(isIssuerFormValid ? 1 : 0.45)

                    if editingIssuerID != nil {
                        Button {
                            clearIssuerForm()
                        } label: {
                            Label("キャンセル", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CompanyOutlineButtonStyle())
                    }
                }
            }
        }
    }

    private var logoEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appInputBackground)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appDivider)

                    if let issuerLogoData,
                       let image = UIImage(data: issuerLogoData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                            .scaleEffect(CGFloat(issuerLogoScale), anchor: .center)
                            .accessibilityLabel("選択済みLogo")
                    } else {
                        CompanyLogoPlaceholder(systemImage: "photo", title: "Logo", subtitle: "未設定")
                            .padding(8)
                    }
                }
                .frame(width: 128, height: 88)
                .clipped()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Logo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                }
            }

            if !issuerLogoStatus.isEmpty {
                Text(issuerLogoStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
            }
        }
        .padding(12)
        .background(Color.appAccentSoft.opacity(0.42))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }

    private var savedIssuerProfilesCard: some View {
        CompanySettingsPanel(title: "保存済みアカウント", systemImage: "person.crop.circle.badge.checkmark") {
            if store.issuers.isEmpty {
                EmptyManagementText(text: "保存済みの自社情報はありません。")
            } else {
                VStack(spacing: 10) {
                    ForEach(store.issuers) { issuer in
                        CompanyProfileRow(issuer: issuer) {
                            store.apply(issuer)
                        } onEdit: {
                            editIssuer(issuer)
                        } onDelete: {
                            store.deleteIssuer(issuer)
                        }
                    }
                }
            }
        }
    }

    private var isIssuerFormValid: Bool {
        !issuerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func clearIssuerForm() {
        issuerName = ""
        issuerRegistration = ""
        issuerContact = ""
        issuerPhone = ""
        issuerEmail = ""
        issuerAddress = ""
        issuerLogoData = nil
        issuerLogoScale = 1.0
        issuerLogoStatus = ""
        editingIssuerID = nil
    }

    private func loadCurrentIssuerIntoForm() {
        editingIssuerID = nil
        issuerName = store.current.issuerName
        issuerRegistration = store.current.issuerRegistration
        issuerContact = store.current.issuerContact
        issuerPhone = store.current.issuerPhone
        issuerEmail = store.current.issuerEmail
        issuerAddress = store.current.issuerAddress
        issuerLogoData = store.current.issuerLogoData
        issuerLogoScale = normalizedLogoScale(store.current.issuerLogoScale)
        issuerLogoStatus = store.current.issuerLogoData == nil ? "" : "現在のLogoを編集フォームに読み込みました。"
    }

    private func saveIssuerForm() {
        let savedLogoScale = issuerLogoData == nil ? nil : issuerLogoScale
        if let editingIssuerID {
            store.updateIssuerProfile(
                id: editingIssuerID,
                name: issuerName,
                registration: issuerRegistration,
                contact: issuerContact,
                phone: issuerPhone,
                email: issuerEmail,
                address: issuerAddress,
                logoData: issuerLogoData,
                logoScale: savedLogoScale
            )
        } else {
            store.saveIssuerProfile(
                name: issuerName,
                registration: issuerRegistration,
                contact: issuerContact,
                phone: issuerPhone,
                email: issuerEmail,
                address: issuerAddress,
                logoData: issuerLogoData,
                logoScale: savedLogoScale
            )
        }
        store.apply(IssuerProfile(
            id: editingIssuerID ?? UUID(),
            name: issuerName,
            registration: issuerRegistration,
            contact: issuerContact,
            phone: issuerPhone,
            email: issuerEmail,
            address: issuerAddress,
            logoData: issuerLogoData,
            logoScale: savedLogoScale
        ))
        clearIssuerForm()
    }

    private func editIssuer(_ issuer: IssuerProfile) {
        editingIssuerID = issuer.id
        issuerName = issuer.name
        issuerRegistration = issuer.registration
        issuerContact = issuer.contact
        issuerPhone = issuer.phone
        issuerEmail = issuer.email
        issuerAddress = issuer.address
        issuerLogoData = issuer.logoData
        issuerLogoScale = normalizedLogoScale(issuer.logoScale)
        issuerLogoStatus = issuer.logoData == nil ? "" : "保存済みLogoを読み込みました。"
    }

    private func normalizedLogoScale(_ value: Double?) -> Double {
        min(max(value ?? 1.0, 0.5), 1.8)
    }

    private func exportBackup() {
        do {
            backupSharePayload = SharePayload(url: try store.backupFileURL())
            backupStatus = "備份檔案を作成しました。"
        } catch {
            backupStatus = "備份檔案を作成できませんでした。"
        }
    }

    private func readBackupData(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            pendingBackupData = try Data(contentsOf: url)
            isBackupImportOptionsPresented = true
        } catch {
            backupStatus = "備份檔案を読み込めませんでした。"
        }
    }

    private func importPendingBackup(mode: BackupImportMode) {
        guard let pendingBackupData else { return }
        do {
            try store.importBackupData(pendingBackupData, mode: mode)
            backupStatus = mode == .merge ? "備份內容を融合しました。" : "備份內容から全新內容を建立しました。"
        } catch {
            backupStatus = "備份檔案を導入できませんでした。"
        }
        self.pendingBackupData = nil
    }

}

struct ProjectManagementScreen: View {
    @ObservedObject var store: DocumentStore
    @Binding var selectedSection: AppSection
    @State private var direction: ProjectDirection = .customer
    @State private var selectedCustomerID: CustomerProfile.ID?
    @State private var isDeleteConfirmationPresented = false
    @State private var pendingDeleteProject: ProjectArchive?

    private var selectedCustomer: CustomerProfile? {
        guard let selectedCustomerID else { return nil }
        return store.customers.first { $0.id == selectedCustomerID }
    }

    var body: some View {
        ManagementScroll(title: "文件與專案管理", subtitle: "顧客書類は專案管理として扱い、分類に合わせて必要な帳票をまとめます。") {
            SectionCard(title: "新規專案") {
                VStack(spacing: 14) {
                    Picker("專案分類", selection: $direction) {
                        ForEach(ProjectDirection.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(direction.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("取引先・廠商", selection: $selectedCustomerID) {
                        Text("未選択").tag(nil as CustomerProfile.ID?)
                        ForEach(store.customers) { customer in
                            Text(customer.name).tag(Optional(customer.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.appInputBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))

                    ManagementPrimaryButton(title: "專案を作成", systemImage: "folder.badge.plus") {
                        store.createProject(direction: direction, customer: selectedCustomer)
                        selectedSection = .form
                    }
                }
            }

            SectionCard(title: "專案一覧") {
                if store.projects.isEmpty {
                    EmptyManagementText(text: "保存済みの專案はありません。給客戶または給廠商を選んで專案を作成してください。")
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.projects) { project in
                            ProjectArchiveRow(project: project) { type in
                                store.openProjectForm(project: project, type: type)
                                selectedSection = .form
                            } onDelete: {
                                pendingDeleteProject = project
                                isDeleteConfirmationPresented = true
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("專案を削除しますか？", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                if let pendingDeleteProject {
                    store.deleteProject(pendingDeleteProject)
                }
                pendingDeleteProject = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingDeleteProject = nil
            }
        } message: {
            Text("專案内の帳票をすべて削除します。この操作は取り消せません。")
        }
    }
}

private struct ProjectArchiveRow: View {
    let project: ProjectArchive
    let onOpenForm: (DocumentType) -> Void
    let onDelete: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: project.direction == .customer ? "person.crop.square.filled.and.at.rectangle" : "building.2.crop.circle")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 38, height: 38)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text("\(project.direction.title) / \(project.completedCount)/\(project.direction.requiredTypes.count) 件完了")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 34, height: 34)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(project.direction.requiredTypes) { type in
                    let document = project.document(for: type)
                    Button {
                        onOpenForm(type)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.title)
                                .font(.caption.weight(.black))
                                .foregroundColor(document == nil ? .appMuted : .appInk)
                            Text(document?.number ?? "未作成")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(document == nil ? buttonAccent : .appMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(document == nil ? buttonAccent.opacity(0.12) : Color.appInputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(document == nil ? buttonAccent.opacity(0.35) : Color.appDivider))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(14)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

struct CustomerManagementScreen: View {
    @ObservedObject var store: DocumentStore
    @State private var customerName = ""
    @State private var customerContact = ""
    @State private var customerAddress = ""
    @State private var editingCustomerID: CustomerProfile.ID?

    var body: some View {
        ManagementScroll(title: "顧客・廠商管理", subtitle: "会社名を入力すると、ここに保存された取引先・廠商候補が表示されます。") {
            SectionCard(title: editingCustomerID == nil ? "顧客・廠商情報を新增" : "顧客・廠商情報を編集") {
                VStack(spacing: 14) {
                    FormField(title: "会社名 / 氏名") {
                        TextField("", text: $customerName, prompt: .inputPrompt("株式会社サンプル"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    FormField(title: "担当者") {
                        TextField("", text: $customerContact, prompt: .inputPrompt("経理部 山田"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    FormField(title: "住所") {
                        MultilineTextInput(text: $customerAddress)
                            .multilineFormInput(minHeight: 86)
                    }
                    ManagementPrimaryButton(title: editingCustomerID == nil ? "顧客・廠商情報を保存" : "顧客・廠商情報を更新", systemImage: editingCustomerID == nil ? "plus.circle.fill" : "checkmark.circle.fill") {
                        saveCustomerForm()
                    }
                    .disabled(customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    if editingCustomerID != nil {
                        ManagementSecondaryButton(title: "編集をキャンセル", systemImage: "xmark.circle") {
                            clearCustomerForm()
                        }
                    }
                }
            }

            SectionCard(title: "取引先・廠商一覧") {
                if store.customers.isEmpty {
                    EmptyManagementText(text: "保存済みの取引先・廠商はありません。")
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.customers) { customer in
                            ManagementRecordRow(
                                title: customer.name,
                                subtitle: [customer.contact, customer.address].filter { !$0.isEmpty }.joined(separator: " / "),
                                applyTitle: "使用",
                                editTitle: "編集"
                            ) {
                                store.apply(customer)
                            } onEdit: {
                                editCustomer(customer)
                            } onDelete: {
                                store.deleteCustomer(customer)
                            }
                        }
                    }
                }
            }
        }
    }

    private func clearCustomerForm() {
        customerName = ""
        customerContact = ""
        customerAddress = ""
        editingCustomerID = nil
    }

    private func saveCustomerForm() {
        if let editingCustomerID {
            store.updateCustomerProfile(id: editingCustomerID, name: customerName, contact: customerContact, address: customerAddress)
        } else {
            store.saveCustomerProfile(name: customerName, contact: customerContact, address: customerAddress)
        }
        clearCustomerForm()
    }

    private func editCustomer(_ customer: CustomerProfile) {
        editingCustomerID = customer.id
        customerName = customer.name
        customerContact = customer.contact
        customerAddress = customer.address
    }
}

struct ProductManagementScreen: View {
    @ObservedObject var store: DocumentStore
    @State private var productName = ""
    @State private var productModel = ""
    @State private var productSpecification = ""
    @State private var productUnitPrice: Double = 0
    @State private var editingProductID: ProductProfile.ID?

    var body: some View {
        ManagementScroll(title: "商品・項目管理", subtitle: "品目入力時に使う商品名、型番、仕様、単価の候補です。") {
            SectionCard(title: editingProductID == nil ? "項目信息を新增" : "項目信息を編集") {
                VStack(spacing: 14) {
                    FormField(title: "品目 / 項目名") {
                        TextField("", text: $productName, prompt: .inputPrompt("品目"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    FormField(title: "仕様") {
                        TextField("", text: $productSpecification, prompt: .inputPrompt("仕様"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    HStack(alignment: .top, spacing: 18) {
                        FormField(title: "型番") {
                            TextField("", text: $productModel, prompt: .inputPrompt("型番"))
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                        FormField(title: "単価") {
                            TextField("", value: $productUnitPrice, formatter: NumberFormatter.decimal, prompt: .inputPrompt("単価"))
                                .keyboardType(.numberPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    }
                    ManagementPrimaryButton(title: editingProductID == nil ? "項目情報を保存" : "項目情報を更新", systemImage: editingProductID == nil ? "plus.circle.fill" : "checkmark.circle.fill") {
                        saveProductForm()
                    }
                    .disabled(productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    if editingProductID != nil {
                        ManagementSecondaryButton(title: "編集をキャンセル", systemImage: "xmark.circle") {
                            clearProductForm()
                        }
                    }
                }
            }

            SectionCard(title: "商品・項目一覧") {
                if store.products.isEmpty {
                    EmptyManagementText(text: "保存済みの商品・項目はありません。")
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.products) { product in
                            ManagementRecordRow(
                                title: product.name,
                                subtitle: [product.model, product.specification, AppFormatters.yen(product.unitPrice)].filter { !$0.isEmpty }.joined(separator: " / "),
                                applyTitle: "使用",
                                editTitle: "編集"
                            ) {
                                store.apply(product)
                            } onEdit: {
                                editProduct(product)
                            } onDelete: {
                                store.deleteProduct(product)
                            }
                        }
                    }
                }
            }
        }
    }

    private func clearProductForm() {
        productName = ""
        productModel = ""
        productSpecification = ""
        productUnitPrice = 0
        editingProductID = nil
    }

    private func saveProductForm() {
        if let editingProductID {
            store.updateProductProfile(id: editingProductID, name: productName, model: productModel, specification: productSpecification, unitPrice: productUnitPrice)
        } else {
            store.saveProductProfile(name: productName, model: productModel, specification: productSpecification, unitPrice: productUnitPrice)
        }
        clearProductForm()
    }

    private func editProduct(_ product: ProductProfile) {
        editingProductID = product.id
        productName = product.name
        productModel = product.model
        productSpecification = product.specification
        productUnitPrice = product.unitPrice
    }
}

struct ManagementScroll<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
                content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .dismissKeyboardOnTap()
    }
}

struct ManagementValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.appMuted)
                .frame(width: 82, alignment: .leading)
            Text(value.isEmpty ? "未入力" : value)
                .font(.body.weight(.semibold))
                .foregroundColor(.appInk)
            Spacer()
        }
        .padding(.vertical, 6)
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
    }
}

struct CompanySettingsHeader: View {
    let title: String
    let subtitle: String
    let isEditing: Bool
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundColor(.appInk)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
            }
            Spacer()
            Label(isEditing ? "編集中" : "新增", systemImage: isEditing ? "pencil" : "plus")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isEditing ? buttonAccent.opacity(0.12) : Color.appInputBackground)
                .foregroundColor(isEditing ? buttonAccent : .appMuted)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isEditing ? buttonAccent.opacity(0.35) : Color.appDivider))
        }
    }
}

struct CompanySettingsPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

struct CompanyInfoLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        if !text.isEmpty {
            Label(text, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .lineLimit(2)
        }
    }
}

struct CompanyLogoPlaceholder: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundColor(.appMuted)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CompanyProfileRow: View {
    let issuer: IssuerProfile
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let logoData = issuer.logoData {
                    ManagementLogoThumbnail(data: logoData, scale: issuer.logoScale)
                } else {
                    CompanyLogoPlaceholder(systemImage: "photo", title: "Logo", subtitle: "未設定")
                        .frame(width: 58, height: 42)
                        .background(Color.appInputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appDivider))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(issuer.name.isEmpty ? "名称未入力" : issuer.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(2)
                    Text([issuer.registration, issuer.phone, issuer.email].filter { !$0.isEmpty }.joined(separator: " / "))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(2)
                    if issuer.logoData != nil {
                        Text("Logo \(Int((issuer.logoScale ?? 1.0) * 100))%")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundColor(buttonAccent)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(action: onApply) {
                    Label("使用", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CompanyMiniButtonStyle())

                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CompanyMiniButtonStyle(tint: .appInk))

                Button(role: .destructive, action: onDelete) {
                    Label("削除", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CompanyMiniButtonStyle(tint: .red))
            }
        }
        .padding(12)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

struct CompanyFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appButtonAccent) private var buttonAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(buttonAccent.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct CompanyOutlineButtonStyle: ButtonStyle {
    var tint: Color = .appInk
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appButtonAccent) private var buttonAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? buttonAccent.opacity(0.12) : Color.appInputBackground)
            .foregroundColor(isEnabled ? tint : .appMuted)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .cornerRadius(8)
    }
}

struct CompanyMiniButtonStyle: ButtonStyle {
    var tint: Color? = nil
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appButtonAccent) private var buttonAccent

    private var effectiveTint: Color {
        tint ?? buttonAccent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(effectiveTint.opacity(configuration.isPressed ? 0.18 : 0.10))
            .foregroundColor(isEnabled ? effectiveTint : .appMuted)
            .cornerRadius(7)
    }
}

struct ManagementRecordRow: View {
    let title: String
    let subtitle: String
    let applyTitle: String?
    let editTitle: String?
    var logoData: Data? = nil
    var logoScale: Double? = nil
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let logoData {
                ManagementLogoThumbnail(data: logoData, scale: logoScale)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let applyTitle = applyTitle {
                Button(applyTitle, action: onApply)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(buttonAccent.opacity(0.12))
                    .foregroundColor(buttonAccent)
                    .cornerRadius(7)
            }
            if let editTitle = editTitle {
                Button(editTitle, action: onEdit)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.appInputBackground)
                    .foregroundColor(.appInk)
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appDivider))
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.vertical, 12)
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
    }
}

struct ManagementLogoThumbnail: View {
    let data: Data
    var scale: Double?

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            } else {
                Image(systemName: "photo")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appMuted)
            }
        }
        .frame(width: 56 * normalizedScale, height: 34 * normalizedScale)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appDivider))
        .cornerRadius(6)
        .accessibilityLabel("Logoプレビュー")
    }

    private var normalizedScale: CGFloat {
        CGFloat(min(max(scale ?? 1.0, 0.5), 1.8))
    }
}

struct ManagementSecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
        }
        .foregroundColor(.appInk)
    }
}

struct ManagementPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(buttonAccent)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }
}

struct EmptyManagementText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.appMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}
