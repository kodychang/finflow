import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let defaultDSAContactAddress = "3F,  3 - 11 - 2  Nezu, Bunkyou-ku, Tokyo, Japan."

struct ShokoFormsRootView: View {
    private static let initialSection: AppSection = ProcessInfo.processInfo.arguments.contains("--app-review-pro-screenshot") ? .pro : .menu

    @StateObject private var store = DocumentStore()
    @StateObject private var purchaseService = PurchaseService()
    @StateObject private var appUpdateChecker = AppUpdateChecker()
    @State private var selectedSection: AppSection = initialSection
    @State private var confirmedSection: AppSection = initialSection
    @State private var pendingSectionAfterForm: AppSection?
    @State private var navigationHistory: [AppSection] = []
    @State private var isBackNavigationPending = false
    @State private var shouldReturnToCreateStartOnFormBack = false
    @State private var isCreateStartNavigationPending = false
    @State private var isLeaveFormConfirmationPresented = false
    @State private var isResolvingSectionChange = false
    @AppStorage("shokoFormsDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("shokoFormsSyncButtonColorWithTableTemplate") private var syncButtonColorWithTableTemplate = false
    @AppStorage("shokoFormsPDFPreviewPrinterAnimationEnabled") private var isPDFPreviewPrinterAnimationEnabled = true
    @State private var openedBackupData: Data?
    @State private var isOpenedBackupDialogPresented = false
    @State private var openedBackupStatus = ""
    @State private var isOpenedBackupStatusPresented = false
    @State private var isPreviewUnavailablePresented = false
    @State private var isOnboardingGuidePresented = false
    @State private var pendingPreviewIntroKeys: Set<String> = []
    @State private var isListPreviewNavigation = false
    @State private var focusedProjectID: ProjectArchive.ID?
    @AppStorage("native.shokoForms.onboardingCompleted.v1") private var isOnboardingCompleted = false
    private var interfaceLanguage: AppLanguage { store.interfaceLanguage }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                HStack(spacing: 0) {
                    SidebarView(
                        store: store,
                        purchaseService: purchaseService,
                        selectedSection: $selectedSection,
                        onOpenRecentProject: openRecentProject,
                        onPreviewDocument: navigateToPreviewFromList,
                        onCreateStartRequested: requestCreateStartFromNavigation
                    )
                        .frame(width: 304)
                    if selectedSection == .account {
                        AccountManagementScreen(
                            store: store,
                            purchaseService: purchaseService,
                            selectedSection: $selectedSection,
                            isDarkModeEnabled: $isDarkModeEnabled,
                            syncButtonColorWithTableTemplate: $syncButtonColorWithTableTemplate,
                            isPDFPreviewPrinterAnimationEnabled: $isPDFPreviewPrinterAnimationEnabled,
                            isOnboardingGuidePresented: $isOnboardingGuidePresented,
                            language: interfaceLanguage
                        )
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .data {
                        DataManagementHubScreen(
                            store: store,
                            selectedSection: $selectedSection,
                            language: interfaceLanguage,
                            onBack: navigateBackInApp
                        )
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .company {
                        CompanyManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .files {
                        FileManagementScreen(store: store, selectedSection: $selectedSection, onBack: navigateBackInApp, onPreviewDocument: navigateToPreviewFromList)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .projects {
                        ProjectManagementScreen(store: store, purchaseService: purchaseService, selectedSection: $selectedSection, focusedProjectID: $focusedProjectID, onBack: navigateBackInApp)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .customers {
                        CustomerManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .products {
                        ProductManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .templates {
                        TemplateManagementScreen(store: store, onBack: navigateBackInApp)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .stamp {
                        StampManagementScreen(language: interfaceLanguage, onBack: navigateBackInApp)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if selectedSection == .pro {
                        ProSubscriptionScreen(purchaseService: purchaseService, language: interfaceLanguage)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else if !store.hasActiveDocument {
                        CreateFormStartScreen(language: interfaceLanguage, onSelect: startNewForm)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    } else {
                        EditorScreen(
                            store: store,
                            purchaseService: purchaseService,
                            language: interfaceLanguage,
                            onRequirePro: showProPlanForLockedAction,
                            onBack: navigateBackInApp,
                            onReturnToCreateStart: navigateToCreateStartAfterFormExit,
                            onDocumentSaved: registerPreviewIntroForSavedDocument
                        )
                            .frame(minWidth: 430, maxWidth: .infinity)
                        PreviewScreen(
                            document: store.current,
                            purchaseService: purchaseService,
                            interfaceLanguage: interfaceLanguage,
                            pdfLanguage: store.pdfLanguage,
                            onRequirePro: showProPlanForLockedAction
                        )
                            .frame(minWidth: 430, maxWidth: .infinity)
                    }
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            } else {
                TabView(selection: compactTabSelection) {
                    SidebarView(
                        store: store,
                        purchaseService: purchaseService,
                        selectedSection: $selectedSection,
                        onOpenRecentProject: openRecentProject,
                        onPreviewDocument: navigateToPreviewFromList,
                        onCreateStartRequested: requestCreateStartFromNavigation
                    )
                        .tabItem { Label(AppText.value(.home, interfaceLanguage), systemImage: "house") }
                        .tag(AppSection.menu)

                    createContent
                        .tabItem { Label(AppText.value(.create, interfaceLanguage), systemImage: "doc.text") }
                        .tag(AppSection.form)

                    compactPreviewContent
                    .tabItem { Label(AppText.value(.preview, interfaceLanguage), systemImage: "doc.richtext") }
                    .tag(AppSection.preview)

                    compactDataContent
                        .tabItem { Label(localizedDataTitle, systemImage: "externaldrive") }
                        .tag(AppSection.data)

                    compactAccountContent
                        .tabItem { Label(AppText.value(.settings, interfaceLanguage), systemImage: "person.crop.circle") }
                        .tag(AppSection.account)
                }
                .accentColor(buttonAccent)
                .background {
                    CompactTabSelectionObserver { selectedIndex, wasAlreadySelected in
                        if selectedIndex == 1, wasAlreadySelected {
                            requestCreateStartFromNavigation()
                        }
                    }
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            }
        }
        .environment(\.appButtonAccent, buttonAccent)
        .environment(\.locale, Locale(identifier: interfaceLanguage.localeIdentifier))
        .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        .onOpenURL { url in
            readOpenedFile(from: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .shokoFormsOpenFileURL)) { notification in
            guard let url = notification.object as? URL else { return }
            readOpenedFile(from: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await appUpdateChecker.checkForUpdateIfNeeded(language: interfaceLanguage)
            }
        }
        .onChange(of: selectedSection) { newSection in
            handleSectionChange(newSection)
        }
        .task {
            await appUpdateChecker.checkForUpdateIfNeeded(language: interfaceLanguage)
            if !isOnboardingCompleted {
                isOnboardingGuidePresented = true
            }
        }
        .sheet(isPresented: $isOnboardingGuidePresented) {
            OnboardingGuideSheet(
                store: store,
                language: interfaceLanguage,
                onSelectSection: navigateFromOnboarding,
                onFinish: {
                    isOnboardingCompleted = true
                }
            )
        }
        .confirmationDialog(leaveFormTitle, isPresented: $isLeaveFormConfirmationPresented, titleVisibility: .visible) {
            Button(leaveFormSaveTitle) {
                store.saveCurrent()
                registerPreviewIntroForSavedDocument(store.current)
                if isCreateStartNavigationPending {
                    navigateToCreateStartAfterFormExit()
                } else {
                    navigateToPendingSection()
                }
            }
            Button(leaveFormDiscardTitle, role: .destructive) {
                if isCreateStartNavigationPending {
                    navigateToCreateStartAfterFormExit()
                } else {
                    store.discardCurrentChanges()
                    navigateToPendingSection()
                }
            }
            Button(leaveFormContinueTitle, role: .cancel) {
                pendingSectionAfterForm = nil
                isBackNavigationPending = false
                isCreateStartNavigationPending = false
            }
        } message: {
            Text(leaveFormMessage)
        }
        .confirmationDialog(previewUnavailableTitle, isPresented: $isPreviewUnavailablePresented, titleVisibility: .visible) {
            Button(previewUnavailableCreateTitle) {
                selectedSection = .form
            }
            Button(previewUnavailableProjectTitle) {
                selectedSection = .projects
            }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(previewUnavailableMessage)
        }
        .confirmationDialog(openedBackupImportTitle, isPresented: $isOpenedBackupDialogPresented, titleVisibility: .visible) {
            Button(openedBackupMergeTitle) {
                importOpenedBackup(mode: .merge)
            }
            Button(openedBackupReplaceTitle, role: .destructive) {
                importOpenedBackup(mode: .replace)
            }
            Button(cancelTitle, role: .cancel) {
                openedBackupData = nil
            }
        } message: {
            Text(openedBackupImportMessage)
        }
        .alert(openedBackupStatusTitle, isPresented: $isOpenedBackupStatusPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(openedBackupStatus)
        }
        .alert(appUpdateChecker.alertTitle, isPresented: $appUpdateChecker.isUpdateAlertPresented) {
            Button(appUpdateChecker.updateButtonTitle) {
                appUpdateChecker.openAppStore()
            }
            Button(appUpdateChecker.dismissButtonTitle, role: .cancel) {}
        } message: {
            Text(appUpdateChecker.alertMessage)
        }
    }

    private var buttonAccent: Color {
        syncButtonColorWithTableTemplate ? store.current.colorTemplate.swiftUIColor : .appAccent
    }

    private var canOpenPreview: Bool {
        store.hasActiveDocument || !store.documents.isEmpty
    }

    private var compactTabSelection: Binding<AppSection> {
        Binding {
            compactRootSection(for: selectedSection)
        } set: { newSection in
            selectedSection = newSection
        }
    }

    private func compactRootSection(for section: AppSection) -> AppSection {
        switch section {
        case .company, .files, .projects, .customers, .products, .templates, .stamp:
            return .data
        case .pro:
            return .account
        default:
            return section
        }
    }

    private func handleSectionChange(_ newSection: AppSection) {
        guard !isResolvingSectionChange else { return }
        guard newSection != confirmedSection else { return }
        if newSection != .preview {
            isListPreviewNavigation = false
        }

        if confirmedSection == .form,
           newSection != .form,
           store.hasActiveDocument,
           store.hasUnsavedCurrentChanges {
            pendingSectionAfterForm = newSection
            isResolvingSectionChange = true
            selectedSection = .form
            isResolvingSectionChange = false
            isLeaveFormConfirmationPresented = true
            return
        }

        recordNavigationHistory(from: confirmedSection, to: newSection)
        confirmedSection = newSection
        if newSection != .form {
            shouldReturnToCreateStartOnFormBack = false
        }
    }

    private func navigateToPendingSection() {
        let destination = pendingSectionAfterForm ?? confirmedSection
        pendingSectionAfterForm = nil
        if isBackNavigationPending {
            popHistoryDestination(destination)
            isBackNavigationPending = false
        }
        if destination != .preview {
            isListPreviewNavigation = false
        }
        if destination != .form {
            shouldReturnToCreateStartOnFormBack = false
        }
        isResolvingSectionChange = true
        selectedSection = destination
        confirmedSection = destination
        isResolvingSectionChange = false
    }

    private func navigateBackInApp() {
        if confirmedSection == .form,
           shouldReturnToCreateStartOnFormBack {
            if store.hasActiveDocument,
               store.hasUnsavedCurrentChanges {
                pendingSectionAfterForm = nil
                isBackNavigationPending = false
                isCreateStartNavigationPending = true
                isLeaveFormConfirmationPresented = true
                return
            }

            navigateToCreateStartAfterFormExit()
            return
        }

        let destination = navigationHistory.last ?? .menu
        guard destination != confirmedSection else {
            popHistoryDestination(destination)
            return
        }

        if confirmedSection == .form,
           destination != .form,
           store.hasActiveDocument,
           store.hasUnsavedCurrentChanges {
            pendingSectionAfterForm = destination
            isBackNavigationPending = true
            isLeaveFormConfirmationPresented = true
            return
        }

        popHistoryDestination(destination)
        if destination != .preview {
            isListPreviewNavigation = false
        }
        isResolvingSectionChange = true
        selectedSection = destination
        confirmedSection = destination
        isResolvingSectionChange = false
    }

    private func requestCreateStartFromNavigation() {
        if store.hasActiveDocument {
            if store.hasUnsavedCurrentChanges {
                pendingSectionAfterForm = nil
                isBackNavigationPending = false
                isCreateStartNavigationPending = true
                isLeaveFormConfirmationPresented = true
            } else {
                navigateToCreateStartAfterFormExit()
            }
            return
        }

        pendingSectionAfterForm = nil
        isBackNavigationPending = false
        isCreateStartNavigationPending = false
        shouldReturnToCreateStartOnFormBack = false
        isListPreviewNavigation = false
        isResolvingSectionChange = true
        selectedSection = .form
        confirmedSection = .form
        isResolvingSectionChange = false
    }

    private func navigateToCreateStartAfterFormExit() {
        pendingSectionAfterForm = nil
        isBackNavigationPending = false
        isCreateStartNavigationPending = false
        shouldReturnToCreateStartOnFormBack = false
        isListPreviewNavigation = false
        store.resetCurrentDocumentSelection()
        isResolvingSectionChange = true
        selectedSection = .form
        confirmedSection = .form
        isResolvingSectionChange = false
    }

    private func recordNavigationHistory(from source: AppSection, to destination: AppSection) {
        guard source != destination else { return }
        if navigationHistory.last == source { return }
        navigationHistory.append(source)
        if navigationHistory.count > 30 {
            navigationHistory.removeFirst(navigationHistory.count - 30)
        }
    }

    private func popHistoryDestination(_ destination: AppSection) {
        if navigationHistory.last == destination {
            navigationHistory.removeLast()
        }
    }

    private func startNewForm(_ type: DocumentType) {
        store.newDocument(type: type)
        shouldReturnToCreateStartOnFormBack = true
    }

    private func navigateToFormAfterManagementApply() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            isResolvingSectionChange = true
            recordNavigationHistory(from: confirmedSection, to: .form)
            selectedSection = .form
            confirmedSection = .form
            shouldReturnToCreateStartOnFormBack = false
            isResolvingSectionChange = false
        }
    }

    @ViewBuilder
    private var createContent: some View {
        if store.hasActiveDocument {
            EditorScreen(
                store: store,
                purchaseService: purchaseService,
                language: interfaceLanguage,
                onRequirePro: showProPlanForLockedAction,
                onBack: navigateBackInApp,
                onReturnToCreateStart: navigateToCreateStartAfterFormExit,
                onDocumentSaved: registerPreviewIntroForSavedDocument
            )
        } else {
            CreateFormStartScreen(language: interfaceLanguage, onSelect: startNewForm)
        }
    }

    @ViewBuilder
    private var compactPreviewContent: some View {
        if store.hasActiveDocument {
            let introKey = previewIntroKey(for: store.current)
            PreviewScreen(
                document: store.current,
                purchaseService: purchaseService,
                interfaceLanguage: interfaceLanguage,
                pdfLanguage: store.pdfLanguage,
                onRequirePro: showProPlanForLockedAction,
                onClose: {
                    navigateBackInApp()
                },
                previewIntroKey: isPDFPreviewPrinterAnimationEnabled && !isListPreviewNavigation && selectedSection == .preview && pendingPreviewIntroKeys.contains(introKey) ? introKey : nil,
                onPreviewIntroCompleted: { completedKey in
                    pendingPreviewIntroKeys.remove(completedKey)
                }
            )
        } else {
            EmptyPDFPreviewScreen(language: interfaceLanguage) {
                selectedSection = .form
            }
        }
    }

    private func previewIntroKey(for document: BusinessDocument) -> String {
        "\(document.id.uuidString)-\(document.updatedAt.timeIntervalSinceReferenceDate)-\(store.pdfLanguage.rawValue)"
    }

    private func registerPreviewIntroForSavedDocument(_ document: BusinessDocument) {
        guard isPDFPreviewPrinterAnimationEnabled,
              !document.type.isAttachmentRecord else { return }
        pendingPreviewIntroKeys.insert(previewIntroKey(for: document))
    }

    private func openRecentProject(_ project: ProjectArchive) {
        focusedProjectID = project.id
        selectedSection = .projects
    }

    private func navigateToPreviewFromList(_ document: BusinessDocument) {
        store.select(document)
        isListPreviewNavigation = true
        selectedSection = .preview
    }

    private func showProPlanForLockedAction() {
        pendingSectionAfterForm = nil
        isBackNavigationPending = false
        shouldReturnToCreateStartOnFormBack = false
        isListPreviewNavigation = false
        isLeaveFormConfirmationPresented = false
        isResolvingSectionChange = true
        recordNavigationHistory(from: confirmedSection, to: .pro)
        selectedSection = .pro
        confirmedSection = .pro
        isResolvingSectionChange = false
    }

    private func navigateFromOnboarding(_ section: AppSection) {
        if section == .preview,
           !store.hasActiveDocument,
           let document = store.documents.first {
            store.select(document)
        }
        isListPreviewNavigation = section == .preview
        isResolvingSectionChange = true
        selectedSection = section
        confirmedSection = section
        isResolvingSectionChange = false
    }

    @ViewBuilder
    private var compactDataContent: some View {
        switch selectedSection {
        case .company:
            CompanyManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
        case .files:
            FileManagementScreen(store: store, selectedSection: $selectedSection, onBack: navigateBackInApp, onPreviewDocument: navigateToPreviewFromList)
        case .projects:
            ProjectManagementScreen(store: store, purchaseService: purchaseService, selectedSection: $selectedSection, focusedProjectID: $focusedProjectID, onBack: navigateBackInApp)
        case .customers:
            CustomerManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
        case .products:
            ProductManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
        case .templates:
            TemplateManagementScreen(store: store, onBack: navigateBackInApp)
        case .stamp:
            StampManagementScreen(language: interfaceLanguage, onBack: navigateBackInApp)
        default:
            DataManagementHubScreen(
                store: store,
                selectedSection: $selectedSection,
                language: interfaceLanguage,
                onBack: navigateBackInApp
            )
        }
    }

    @ViewBuilder
    private var compactAccountContent: some View {
        if selectedSection == .pro {
            ProSubscriptionScreen(purchaseService: purchaseService, language: interfaceLanguage)
        } else {
            AccountManagementScreen(
                store: store,
                purchaseService: purchaseService,
                selectedSection: $selectedSection,
                isDarkModeEnabled: $isDarkModeEnabled,
                syncButtonColorWithTableTemplate: $syncButtonColorWithTableTemplate,
                isPDFPreviewPrinterAnimationEnabled: $isPDFPreviewPrinterAnimationEnabled,
                isOnboardingGuidePresented: $isOnboardingGuidePresented,
                language: interfaceLanguage
            )
        }
    }

    private var companyTabTitle: String {
        switch interfaceLanguage {
        case .japanese: return "会社"
        case .simplifiedChinese: return "公司"
        case .english: return "Company"
        }
    }

    private var templateTabTitle: String {
        switch interfaceLanguage {
        case .japanese: return "テンプレート"
        case .simplifiedChinese: return "模板"
        case .english: return "Templates"
        }
    }

    private var fileManagementTabTitle: String {
        switch interfaceLanguage {
        case .japanese: return "ファイル"
        case .simplifiedChinese: return "文件"
        case .english: return "Files"
        }
    }

    private var proTabTitle: String {
        switch interfaceLanguage {
        case .japanese: return "Pro"
        case .simplifiedChinese: return "Pro"
        case .english: return "Pro"
        }
    }

    private var localizedDataTitle: String {
        switch interfaceLanguage {
        case .japanese: return "データ管理"
        case .simplifiedChinese: return "数据管理"
        case .english: return "Data"
        }
    }

    private var cancelTitle: String {
        switch interfaceLanguage {
        case .japanese: return "キャンセル"
        case .simplifiedChinese: return "取消"
        case .english: return "Cancel"
        }
    }

    private var leaveFormTitle: String {
        switch interfaceLanguage {
        case .japanese: return "編集中の帳票を保存しますか？"
        case .simplifiedChinese: return "要保存正在编辑的表单吗？"
        case .english: return "Save the form you are editing?"
        }
    }

    private var leaveFormMessage: String {
        switch interfaceLanguage {
        case .japanese: return "この帳票を離れる前に、保存するか、変更を破棄するか選択してください。"
        case .simplifiedChinese: return "离开这个表单前，请选择保存、放弃更改，或继续编辑。"
        case .english: return "Before leaving this form, choose whether to save, discard changes, or keep editing."
        }
    }

    private var leaveFormSaveTitle: String {
        switch interfaceLanguage {
        case .japanese: return "保存して離れる"
        case .simplifiedChinese: return "保存并离开"
        case .english: return "Save and Leave"
        }
    }

    private var leaveFormDiscardTitle: String {
        switch interfaceLanguage {
        case .japanese: return "破棄して離れる"
        case .simplifiedChinese: return "放弃并离开"
        case .english: return "Discard and Leave"
        }
    }

    private var leaveFormContinueTitle: String {
        switch interfaceLanguage {
        case .japanese: return "編集を続ける"
        case .simplifiedChinese: return "继续编辑"
        case .english: return "Keep Editing"
        }
    }

    private var previewUnavailableTitle: String {
        switch interfaceLanguage {
        case .japanese: return "プレビューする帳票がありません"
        case .simplifiedChinese: return "没有可预览的表单"
        case .english: return "No form to preview"
        }
    }

    private var previewUnavailableMessage: String {
        switch interfaceLanguage {
        case .japanese: return "先に帳票を作成するか、プロジェクト一覧から既存の帳票を選択してください。"
        case .simplifiedChinese: return "请先建立表单，或到项目列表里选择已有表单。"
        case .english: return "Create a form first, or choose an existing form from the project list."
        }
    }

    private var previewUnavailableCreateTitle: String {
        switch interfaceLanguage {
        case .japanese: return "帳票を作成"
        case .simplifiedChinese: return "建立表单"
        case .english: return "Create Form"
        }
    }

    private var previewUnavailableProjectTitle: String {
        switch interfaceLanguage {
        case .japanese: return "プロジェクト一覧へ"
        case .simplifiedChinese: return "前往项目列表"
        case .english: return "Go to Projects"
        }
    }

    private var openedBackupImportTitle: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップファイルを読み込む"
        case .simplifiedChinese: return "导入备份文件"
        case .english: return "Import Backup File"
        }
    }

    private var openedBackupMergeTitle: String {
        switch interfaceLanguage {
        case .japanese: return "既存データに結合"
        case .simplifiedChinese: return "合并到现有数据"
        case .english: return "Merge with Existing Data"
        }
    }

    private var openedBackupReplaceTitle: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップから新規作成"
        case .simplifiedChinese: return "用备份重新建立"
        case .english: return "Replace with Backup"
        }
    }

    private var openedBackupImportMessage: String {
        switch interfaceLanguage {
        case .japanese: return "外部バックアップファイルを検出しました。読み込み方法を選択してください。"
        case .simplifiedChinese: return "检测到外部备份文件。请选择导入方式。"
        case .english: return "An external backup file was detected. Choose how to import it."
        }
    }

    private var openedBackupStatusTitle: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップ読み込み"
        case .simplifiedChinese: return "备份导入"
        case .english: return "Backup Import"
        }
    }

    private func readOpenedFile(from url: URL) {
        if url.pathExtension.lowercased() == "shokoform" {
            importOpenedForm(from: url)
        } else {
            readOpenedBackup(from: url)
        }
    }

    private func importOpenedForm(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            try store.importSharedFormData(data)
            selectedSection = .form
            openedBackupStatus = localizedOpenedFormImportComplete
        } catch {
            openedBackupStatus = localizedOpenedFormImportFailed
        }
        isOpenedBackupStatusPresented = true
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
            openedBackupStatus = localizedOpenedBackupReadFailed
            isOpenedBackupStatusPresented = true
        }
    }

    private func importOpenedBackup(mode: BackupImportMode) {
        guard let openedBackupData else { return }
        do {
            try store.importBackupData(openedBackupData, mode: mode)
            openedBackupStatus = mode == .merge ? localizedOpenedBackupMergeComplete : localizedOpenedBackupReplaceComplete
        } catch {
            openedBackupStatus = localizedOpenedBackupImportFailed
        }
        self.openedBackupData = nil
        isOpenedBackupStatusPresented = true
    }

    private var localizedOpenedBackupReadFailed: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップファイルを読み込めませんでした。"
        case .simplifiedChinese: return "无法读取备份文件。"
        case .english: return "Could not read the backup file."
        }
    }

    private var localizedOpenedBackupMergeComplete: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップ内容を既存データに結合しました。"
        case .simplifiedChinese: return "已将备份内容合并到现有数据。"
        case .english: return "Backup content was merged with existing data."
        }
    }

    private var localizedOpenedBackupReplaceComplete: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップ内容から新しいデータを作成しました。"
        case .simplifiedChinese: return "已用备份内容重新建立数据。"
        case .english: return "New data was created from the backup."
        }
    }

    private var localizedOpenedBackupImportFailed: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップファイルを読み込めませんでした。"
        case .simplifiedChinese: return "无法导入备份文件。"
        case .english: return "Could not import the backup file."
        }
    }

    private var localizedOpenedFormImportComplete: String {
        switch interfaceLanguage {
        case .japanese: return "帳票ファイルを開きました。"
        case .simplifiedChinese: return "已打开表单文件。"
        case .english: return "The form file was opened."
        }
    }

    private var localizedOpenedFormImportFailed: String {
        switch interfaceLanguage {
        case .japanese: return "帳票ファイルを開けませんでした。"
        case .simplifiedChinese: return "无法打开表单文件。"
        case .english: return "Could not open the form file."
        }
    }
}

enum AppSection: Hashable {
    case menu
    case form
    case preview
    case account
    case data
    case company
    case files
    case projects
    case customers
    case products
    case templates
    case stamp
    case pro
    case developerStory
}

private struct CompactTabSelectionObserver: UIViewControllerRepresentable {
    let onSelect: (Int, Bool) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            context.coordinator.attach(from: controller)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onSelect = onSelect
        DispatchQueue.main.async {
            context.coordinator.attach(from: uiViewController)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject {
        var onSelect: (Int, Bool) -> Void
        weak var tabBarController: UITabBarController?
        weak var tapRecognizer: UITapGestureRecognizer?
        private var selectedIndexBeforeTap: Int?

        init(onSelect: @escaping (Int, Bool) -> Void) {
            self.onSelect = onSelect
        }

        func attach(from controller: UIViewController) {
            guard let tabBarController = controller.parentTabBarController else { return }
            guard self.tabBarController !== tabBarController else { return }
            self.tabBarController = tabBarController
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTabBarTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            tabBarController.tabBar.addGestureRecognizer(recognizer)
            tapRecognizer = recognizer
        }

        @objc private func handleTabBarTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let tabBarController,
                  let itemCount = tabBarController.tabBar.items?.count,
                  itemCount > 0 else { return }

            let location = recognizer.location(in: tabBarController.tabBar)
            let itemWidth = tabBarController.tabBar.bounds.width / CGFloat(itemCount)
            guard itemWidth > 0 else { return }
            let index = min(max(Int(location.x / itemWidth), 0), itemCount - 1)
            onSelect(index, selectedIndexBeforeTap == index)
            selectedIndexBeforeTap = nil
        }
    }
}

extension CompactTabSelectionObserver.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        selectedIndexBeforeTap = tabBarController?.selectedIndex
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private extension UIViewController {
    var parentTabBarController: UITabBarController? {
        if let tabBarController {
            return tabBarController
        }
        return parent?.parentTabBarController
    }
}

private struct CreateFormStartScreen: View {
    let language: AppLanguage
    let onSelect: (DocumentType) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let formButtonIconSize: CGFloat = 44
    private let formButtonVerticalPadding: CGFloat = 8

    var body: some View {
        ManagementScroll(title: localizedTitle, subtitle: localizedSubtitle) {
            directionSection(direction: .customer)
            directionSection(direction: .vendor)
        }
    }

    private func directionSection(direction: ProjectDirection) -> some View {
        SectionCard(title: direction.localizedTitle(language), titleWeight: .regular) {
            VStack(alignment: .leading, spacing: 12) {
                Label(direction.localizedSubtitle(language), systemImage: direction == .customer ? "person.crop.circle" : "shippingbox")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(direction.requiredTypes) { type in
                        formTypeButton(type)
                    }
                }
            }
        }
    }

    private func formTypeButton(_ type: DocumentType) -> some View {
        Button {
            onSelect(type)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName(for: type))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor(for: type))
                    .frame(width: formButtonIconSize, height: formButtonIconSize)
                    .background(accentColor(for: type).opacity(0.12))
                    .clipShape(Circle())

                Text(type.localizedTitle(language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, formButtonVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: formButtonIconSize + formButtonVerticalPadding * 2, alignment: .leading)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var localizedTitle: String {
        localized(japanese: "帳票を作成", chinese: "建立表单", english: "Create Form")
    }

    private var localizedSubtitle: String {
        localized(
            japanese: "作成する帳票が未選択です。顧客向けまたは仕入先向けを選び、作成する帳票を選択してください。",
            chinese: "目前没有选取要建立的表单。请选择客户表单或厂商表单，然后选择要建立的表单。",
            english: "No form is selected. Choose a customer or vendor form, then select the form to create."
        )
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }

    private func iconName(for type: DocumentType) -> String {
        switch type {
        case .estimate: return "doc.plaintext.fill"
        case .customerOrder: return "person.text.rectangle.fill"
        case .purchaseOrder: return "cart.fill"
        case .delivery: return "shippingbox.fill"
        case .invoice: return "doc.text.fill"
        case .receipt: return "checkmark.seal.fill"
        case .acceptance: return "tray.full.fill"
        case .customerFiles: return "folder.fill"
        case .vendorEstimate: return "doc.text.magnifyingglass"
        case .vendorReceipt: return "checkmark.rectangle.stack.fill"
        case .paymentNotice: return "yensign.circle.fill"
        }
    }

    private func accentColor(for type: DocumentType) -> Color {
        switch type {
        case .estimate: return Color(red: 0.929, green: 0.286, blue: 0.510)
        case .customerOrder: return .appMint
        case .purchaseOrder: return Color(red: 0.565, green: 0.435, blue: 0.898)
        case .delivery: return Color(red: 0.922, green: 0.553, blue: 0.196)
        case .invoice: return .appAccent
        case .receipt: return .appBlue
        case .acceptance, .vendorReceipt: return Color(red: 0.212, green: 0.702, blue: 0.816)
        case .customerFiles: return Color(red: 0.431, green: 0.533, blue: 0.678)
        case .vendorEstimate: return Color(red: 0.145, green: 0.388, blue: 0.922)
        case .paymentNotice: return Color(red: 0.706, green: 0.325, blue: 0.035)
        }
    }
}

private struct EmptyPDFPreviewScreen: View {
    let language: AppLanguage
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(AppText.value(.pdfPreview, language))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appPanel.opacity(0.94))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        blankPDFPage(width: proxy.size.width)
                            .padding(.top, 24)
                            .padding(.bottom, 110)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
    }

    private func blankPDFPage(width: CGFloat) -> some View {
        let pageWidth = max(220, min(width - 32, 430))
        return ZStack {
            Color.white

            Image("EmptyPDFPreviewBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.42)

            VStack(spacing: 16) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.appInk)

                VStack(spacing: 8) {
                    Text(localizedTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .multilineTextAlignment(.center)
                    Text(localizedMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)

                Button {
                    onCreate()
                } label: {
                    Label(localizedButtonTitle, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Color.appInk)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 22)
        }
        .frame(width: pageWidth)
        .aspectRatio(0.707, contentMode: .fit)
        .clipped()
        .background(Color.white)
        .cornerRadius(2)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appDivider))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var localizedTitle: String {
        localized(japanese: "プレビューする帳票がありません", chinese: "没有可预览的表单", english: "No Form to Preview")
    }

    private var localizedMessage: String {
        localized(
            japanese: "PDFプレビューを表示するには、先に帳票を作成するか、保存済みの帳票を選択してください。",
            chinese: "要显示 PDF 预览，请先建立表单，或从已保存的表单中选择一个。",
            english: "Create a form first, or choose a saved form before opening PDF preview."
        )
    }

    private var localizedButtonTitle: String {
        localized(japanese: "帳票を作成", chinese: "建立表单", english: "Create Form")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct DataManagementHubScreen: View {
    @ObservedObject var store: DocumentStore
    @Binding var selectedSection: AppSection
    let language: AppLanguage
    let onBack: () -> Void

    var body: some View {
        ManagementScroll(
            title: localizedTitle,
            subtitle: localizedSubtitle,
            onBack: onBack
        ) {
            SectionCard(title: localizedSectionTitle, titleWeight: .regular) {
                VStack(spacing: 10) {
                    dataButton(title: localizedCompanyTitle, subtitle: localizedCompanySubtitle, systemImage: "building.columns", section: .company)
                    dataButton(title: localizedFileTitle, subtitle: localizedFileSubtitle, systemImage: "archivebox", section: .files)
                    dataButton(title: AppText.value(.projects, language), subtitle: localizedProjectSubtitle, systemImage: "folder", section: .projects)
                    dataButton(title: AppText.value(.customers, language), subtitle: localizedCustomerSubtitle, systemImage: "building.2", section: .customers)
                    dataButton(title: AppText.value(.products, language), subtitle: localizedProductSubtitle, systemImage: "shippingbox", section: .products)
                    dataButton(title: localizedTemplateTitle, subtitle: localizedTemplateSubtitle, systemImage: "text.badge.plus", section: .templates)
                    dataButton(title: localizedStampTitle, subtitle: localizedStampSubtitle, systemImage: "seal", section: .stamp)
                }
            }
        }
    }

    private func dataButton(title: String, subtitle: String, systemImage: String, section: AppSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .frame(width: 44, height: 44)
                    .background(Color.appInputBackground)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(subtitle)
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var localizedTitle: String { localized(japanese: "データ管理", chinese: "数据管理", english: "Data Management") }
    private var localizedSubtitle: String { localized(japanese: "会社、ファイル、プロジェクト、取引先、商品、テンプレートを管理します。", chinese: "管理公司、文件、项目、客户、商品与模板。", english: "Manage company, files, projects, customers, products, and templates.") }
    private var localizedSectionTitle: String { localized(japanese: "管理メニュー", chinese: "管理菜单", english: "Management Menu") }
    private var localizedCompanyTitle: String { localized(japanese: "会社", chinese: "公司", english: "Company") }
    private var localizedFileTitle: String { localized(japanese: "ファイル管理", chinese: "文件管理", english: "File Management") }
    private var localizedTemplateTitle: String { localized(japanese: "テンプレート", chinese: "模板", english: "Templates") }
    private var localizedStampTitle: String { localized(japanese: "印章管理", chinese: "印章管理", english: "Stamp Management") }
    private var localizedCompanySubtitle: String { localized(japanese: "自社情報、登録番号、連絡先", chinese: "公司信息、登记编号、联系人", english: "Company details and registration") }
    private var localizedFileSubtitle: String { localized(japanese: "保存済み帳票を取引先別に整理", chinese: "按客户/供应商整理已保存表单", english: "Browse saved forms by partner") }
    private var localizedProjectSubtitle: String { localized(japanese: "プロジェクト別の帳票進捗", chinese: "按项目管理表单进度", english: "Track forms by project") }
    private var localizedCustomerSubtitle: String { localized(japanese: "取引先・仕入先の候補", chinese: "客户/供应商候选资料", english: "Customer and vendor profiles") }
    private var localizedProductSubtitle: String { localized(japanese: "商品・項目の候補", chinese: "商品/品项候选资料", english: "Product and item profiles") }
    private var localizedTemplateSubtitle: String { localized(japanese: "振込、備考、条件文", chinese: "汇款、备注、条件文字", english: "Payment, notes, and terms") }
    private var localizedStampSubtitle: String { localized(japanese: "PDF押印用の初期印章", chinese: "PDF 盖章用默认印章", english: "Default stamp for PDF stamping") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct StampManagementScreen: View {
    let language: AppLanguage
    let onBack: () -> Void

    var body: some View {
        ManagementScroll(title: localizedTitle, subtitle: localizedSubtitle, onBack: onBack) {
            if #available(iOS 16.0, *) {
                StampManagementSection(language: language)
            } else {
                SectionCard(title: localizedTitle, titleWeight: .regular) {
                    EmptyManagementText(text: localizedUnavailableText)
                }
            }
        }
    }

    private var localizedTitle: String {
        localized(japanese: "印章管理", chinese: "印章管理", english: "Stamp Management")
    }

    private var localizedSubtitle: String {
        localized(
            japanese: "PDF押印で使うデフォルト印章を管理します。",
            chinese: "管理 PDF 盖章时使用的默认印章。",
            english: "Manage the default stamp used for PDF stamping."
        )
    }

    private var localizedUnavailableText: String {
        localized(japanese: "印章管理は iOS 16 以上で使用できます。", chinese: "印章管理可在 iOS 16 及以上使用。", english: "Stamp management is available on iOS 16 and later.")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

struct AccountManagementScreen: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchaseService: PurchaseService
    @Binding var selectedSection: AppSection
    @Binding var isDarkModeEnabled: Bool
    @Binding var syncButtonColorWithTableTemplate: Bool
    @Binding var isPDFPreviewPrinterAnimationEnabled: Bool
    @Binding var isOnboardingGuidePresented: Bool
    let language: AppLanguage
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var isBackupImporterPresented = false
    @State private var isBackupImportOptionsPresented = false
    @State private var backupSharePayload: SharePayload?
    @State private var pendingBackupData: Data?
    @State private var pendingCloudBackupData: Data?
    @State private var pendingCloudBackupDataItems: [Data] = []
    @State private var cloudBackupPackages: [GoogleDriveCloudBackupFile] = []
    @State private var selectedCloudBackupFileIDs: Set<String> = []
    @State private var isCloudSyncConfirmationPresented = false
    @State private var isCloudBackupManagerPresented = false
    @State private var isCloudBackupImportOptionsPresented = false
    @State private var isDSASettingsPresented = false
    @State private var isDeveloperStoryPresented = false
    @State private var isPreservationGuidePresented = false
    @State private var isClearDataFirstConfirmationPresented = false
    @State private var isClearDataFinalConfirmationPresented = false
    @State private var backupStatus = ""
    @State private var googleDriveStatus = ""
    @State private var googleDriveTransferStatus = ""
    @State private var clearDataStatus = ""
    @State private var isGoogleDriveBusy = false
    @StateObject private var googleDriveSyncService = GoogleDriveSyncService()
    @AppStorage("native.shokoForms.googleDriveCloudBackupFileId.v1") private var googleDriveCloudBackupFileID = ""
    @AppStorage("native.shokoForms.googleDriveCloudLastSync.v1") private var googleDriveCloudLastSync = ""
    @AppStorage("native.shokoForms.dsaInfoVisible.v1") private var dsaInfoVisible = true
    @AppStorage("native.shokoForms.dsaTraderStatus.v1") private var dsaTraderStatus = "trader"
    @AppStorage("native.shokoForms.dsaLegalName.v1") private var dsaLegalName = "NIIX株式会社"
    @AppStorage("native.shokoForms.dsaContactEmail.v1") private var dsaContactEmail = "service@niix.jp"
    @AppStorage("native.shokoForms.dsaContactAddress.v1") private var dsaContactAddress = defaultDSAContactAddress
    @AppStorage("native.shokoForms.dsaPrivacyPolicyURL.v1") private var dsaPrivacyPolicyURL = "https://niix.jp/shokopolicy"
    @AppStorage("native.shokoForms.dsaSupportURL.v1") private var dsaSupportURL = "https://niix.jp"

    var body: some View {
        ManagementScroll(title: AppText.value(.accountManagement, language), subtitle: AppText.value(.accountManagementSubtitle, language)) {
            subscriptionSection
            languageSection

            SectionCard(title: AppText.value(.appearance, language), titleWeight: .regular) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $isDarkModeEnabled) {
                        Label(AppText.value(.darkMode, language), systemImage: isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: buttonAccent))
                    .padding(.vertical, 4)

                    Toggle(isOn: $syncButtonColorWithTableTemplate) {
                        Label(AppText.value(.syncButtonColor, language), systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: buttonAccent))
                    .padding(.vertical, 4)

                    Toggle(isOn: $isPDFPreviewPrinterAnimationEnabled) {
                        Label(localizedPrinterAnimationTitle, systemImage: "printer.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: buttonAccent))
                    .padding(.vertical, 4)
                }
            }

            SectionCard(title: AppText.value(.tableColor, language), titleWeight: .regular) {
                VStack(alignment: .leading, spacing: 14) {
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

            googleDriveSyncSection

            localBackupSection

            legalLinksSection
            clearLocalDataSection

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
        .confirmationDialog(localizedBackupImportModeTitle, isPresented: $isBackupImportOptionsPresented, titleVisibility: .visible) {
            Button(localizedMergeBackupTitle) {
                importPendingBackup(mode: .merge)
            }
            Button(localizedReplaceBackupTitle, role: .destructive) {
                importPendingBackup(mode: .replace)
            }
            Button(localizedCancelTitle, role: .cancel) {
                pendingBackupData = nil
            }
        } message: {
            Text(localizedBackupImportModeMessage)
        }
        .sheet(item: $backupSharePayload) { payload in
            ShareSheet(url: payload.url)
        }
        .sheet(isPresented: $isDSASettingsPresented) {
            DSASettingsScreen(
                language: language,
                dsaInfoVisible: $dsaInfoVisible,
                dsaTraderStatus: $dsaTraderStatus,
                dsaLegalName: $dsaLegalName,
                dsaContactEmail: $dsaContactEmail,
                dsaContactAddress: $dsaContactAddress,
                dsaPrivacyPolicyURL: $dsaPrivacyPolicyURL,
                dsaSupportURL: $dsaSupportURL
            )
        }
        .sheet(isPresented: $isPreservationGuidePresented) {
            ElectronicBookkeepingGuideSheet(language: language) {
                isOnboardingGuidePresented = true
            }
        }
        .sheet(isPresented: $isDeveloperStoryPresented) {
            DeveloperStoryReviewScreen(language: language) {
                isDeveloperStoryPresented = false
            }
        }
        .confirmationDialog(localizedCloudSyncConfirmTitle, isPresented: $isCloudSyncConfirmationPresented, titleVisibility: .visible) {
            Button(localizedCloudSyncConfirmButtonTitle, role: .destructive) {
                loadCloudBackupsForSelection()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedCloudSyncConfirmMessage)
        }
        .sheet(isPresented: $isCloudBackupManagerPresented) {
            CloudBackupPackageSelectionSheet(
                title: localizedCloudBackupManagerTitle,
                subtitle: localizedCloudBackupManagerSubtitle,
                emptyText: localizedCloudBackupManagerEmptyText,
                storageWarningText: localizedCloudStorageWarningText,
                deleteHelpText: localizedCloudDeleteHelpText,
                syncTitle: localizedCloudSyncSelectedTitle,
                refreshTitle: localizedCloudRefreshBackupsTitle,
                cancelTitle: localizedCancelTitle,
                files: cloudBackupPackages,
                selectedFileIDs: $selectedCloudBackupFileIDs,
                dateText: cloudBackupDateText,
                sizeText: cloudBackupSizeText,
                onRefresh: loadCloudBackupsForSelection,
                onSync: downloadSelectedCloudBackups
            )
        }
        .confirmationDialog(localizedCloudImportModeTitle, isPresented: $isCloudBackupImportOptionsPresented, titleVisibility: .visible) {
            Button(localizedMergeBackupTitle) {
                importPendingCloudBackup(mode: .merge)
            }
            if pendingCloudBackupDataItems.count <= 1 {
                Button(localizedReplaceBackupTitle, role: .destructive) {
                    importPendingCloudBackup(mode: .replace)
                }
            }
            Button(localizedCancelTitle, role: .cancel) {
                pendingCloudBackupData = nil
                pendingCloudBackupDataItems = []
            }
        } message: {
            Text(localizedCloudImportModeMessage)
        }
        .confirmationDialog(localizedClearDataFirstConfirmTitle, isPresented: $isClearDataFirstConfirmationPresented, titleVisibility: .visible) {
            Button(localizedClearDataContinueTitle, role: .destructive) {
                DispatchQueue.main.async {
                    isClearDataFinalConfirmationPresented = true
                }
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedClearDataFirstConfirmMessage)
        }
        .confirmationDialog(localizedClearDataFinalConfirmTitle, isPresented: $isClearDataFinalConfirmationPresented, titleVisibility: .visible) {
            Button(localizedClearDataFinalActionTitle, role: .destructive) {
                clearLocalBusinessData()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedClearDataFinalConfirmMessage)
        }
        .task {
            await googleDriveSyncService.restorePreviousSignIn()
        }
    }

    private var languageSection: some View {
        SectionCard(title: AppText.value(.languageSettings, language), titleWeight: .regular) {
            HStack(spacing: 12) {
                languageDropdown(
                    title: AppText.value(.interfaceLanguage, language),
                    selection: interfaceLanguageBinding
                )
                languageDropdown(
                    title: AppText.value(.pdfLanguage, language),
                    selection: pdfLanguageBinding
                )
            }
        }
    }

    private var subscriptionSection: some View {
        SectionCard(title: localizedSubscriptionTitle, titleWeight: .regular) {
            Button {
                selectedSection = .pro
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .frame(width: 44, height: 44)
                        .background(buttonAccent.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedProTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                            .lineLimit(1)
                        Text(localizedProStatusText)
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
                .background(Color.appInputBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var preservationNoticeSection: some View {
        Button {
            isPreservationGuidePresented = true
        } label: {
            LegalLinkButtonContent(
                title: localizedPreservationNoticeHeadline,
                systemImage: "checkmark.shield.fill",
                trailingSystemImage: "chevron.right"
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var appReviewPromotionSection: some View {
        Button {
            isDeveloperStoryPresented = true
        } label: {
            LegalLinkButtonContent(
                title: localizedReviewPromotionTitle,
                systemImage: "star.bubble.fill",
                trailingSystemImage: "chevron.right"
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var privacyPolicySection: some View {
        Link(destination: URL(string: "https://niix.jp/shokopolicy")!) {
            LegalLinkButtonContent(
                title: localizedPrivacyPolicyTitle,
                systemImage: "lock.shield.fill",
                trailingSystemImage: "arrow.up.right"
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var legalLinksSection: some View {
        VStack(spacing: 8) {
            privacyPolicySection
            preservationNoticeSection
            appReviewPromotionSection
            Button {
                isDSASettingsPresented = true
            } label: {
                LegalLinkButtonContent(
                    title: localizedDSATitle,
                    systemImage: "checkmark.shield.fill",
                    trailingSystemImage: "chevron.right"
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 4)
    }

    private var clearLocalDataSection: some View {
        SectionCard(title: localizedClearDataSectionTitle, titleWeight: .regular) {
            VStack(alignment: .leading, spacing: 10) {
                Text(localizedClearDataWarningText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    isClearDataFirstConfirmationPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                        Text(localizedClearDataActionTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold))
                            .opacity(0.85)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())

                if !clearDataStatus.isEmpty {
                    BackupStatusMessage(text: clearDataStatus)
                }
            }
        }
        .padding(.top, 8)
    }

    private var dsaComplianceSection: some View {
        SectionCard(title: localizedDSATitle, titleWeight: .regular) {
            Button {
                isDSASettingsPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .frame(width: 44, height: 44)
                        .background(buttonAccent.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedSelectedDSATraderStatus)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                            .lineLimit(1)
                        Text(dsaInfoVisible ? dsaSummaryText : localizedDSAHiddenSummaryText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
                .padding(12)
                .background(Color.appInputBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func languageDropdown(title: String, selection: Binding<String>) -> some View {
        Menu {
            ForEach(AppLanguage.allCases) { option in
                Button {
                    selection.wrappedValue = option.rawValue
                } label: {
                    Text(option.nativeTitle)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    Text(AppLanguage.from(selection.wrappedValue).nativeTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(buttonAccent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
    }

    private var interfaceLanguageBinding: Binding<String> {
        Binding(
            get: { store.interfaceLanguageId },
            set: { store.interfaceLanguageId = $0 }
        )
    }

    private var pdfLanguageBinding: Binding<String> {
        Binding(
            get: { store.pdfLanguageId },
            set: { store.pdfLanguageId = $0 }
        )
    }

    private var colorTemplateBinding: Binding<String> {
        Binding(
            get: { store.defaultColorTemplateId },
            set: { store.applyDefaultColorTemplate($0) }
        )
    }

    private var googleDriveSyncSection: some View {
        SectionCard(title: localizedCloudBackupTitle) {
            VStack(alignment: .leading, spacing: 0) {
                Image("GoogleDriveSyncBanner")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 124)
                    .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: googleDriveSyncService.isSignedIn ? "checkmark.circle.fill" : "icloud")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(buttonAccent)
                            .frame(width: 42, height: 42)
                            .background(buttonAccent.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizedCloudBackupTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appInk)
                                .lineLimit(1)
                            Text(googleDriveAccountStatusTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appMuted)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if googleDriveSyncService.isSignedIn {
                            Text(localizedCloudSignedInStatus)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(buttonAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(buttonAccent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    if googleDriveSyncService.isSignedIn {
                        VStack(alignment: .leading, spacing: 8) {
                            if !googleDriveAccountStatusDetail.isEmpty {
                                googleDriveInfoLine(
                                    title: googleDriveAccountStatusDetail,
                                    systemImage: "person.crop.circle.fill"
                                )
                            }
                            if !googleDriveCloudLastSync.isEmpty {
                                googleDriveInfoLine(
                                    title: "\(localizedCloudLastSyncTitle) \(googleDriveCloudLastSync)",
                                    systemImage: "clock.arrow.circlepath"
                                )
                            }
                        }
                    }

                    if googleDriveSyncService.isSignedIn {
                        HStack(spacing: 10) {
                            googleDriveActionButton(
                                title: localizedCloudUploadTitle,
                                systemImage: "icloud.and.arrow.up.fill",
                                isProminent: true,
                                action: {
                                    if purchaseService.hasProAccess {
                                        uploadCloudBackup()
                                    } else {
                                        showProForGoogleDrive()
                                    }
                                }
                            )
                            googleDriveActionButton(
                                title: localizedCloudDownloadTitle,
                                systemImage: "icloud.and.arrow.down.fill",
                                isProminent: false
                            ) {
                                if purchaseService.hasProAccess {
                                    isCloudSyncConfirmationPresented = true
                                } else {
                                    showProForGoogleDrive()
                                }
                            }
                        }
                        .disabled(isGoogleDriveBusy)
                        .opacity(isGoogleDriveBusy ? 0.5 : 1)

                        Button {
                            googleDriveSyncService.signOut()
                            googleDriveStatus = localizedCloudSignedOutCompleteStatus
                        } label: {
                            Label(localizedCloudSignOutTitle, systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .disabled(isGoogleDriveBusy)
                        .foregroundColor(.appMuted)
                    } else {
                        googleDriveActionButton(
                            title: purchaseService.hasProAccess ? localizedCloudSignInTitle : localizedCloudProUpgradeTitle,
                            systemImage: "person.crop.circle.badge.checkmark",
                            isProminent: true,
                            action: {
                                if purchaseService.hasProAccess {
                                    signInToGoogleDrive()
                                } else {
                                    showProForGoogleDrive()
                                }
                            }
                        )
                        .disabled(isGoogleDriveBusy || (purchaseService.hasProAccess && !googleDriveSyncService.isConfigured))
                        .opacity(isGoogleDriveBusy || (purchaseService.hasProAccess && !googleDriveSyncService.isConfigured) ? 0.5 : 1)
                    }

                    if isGoogleDriveBusy {
                        BackupProgressRow(title: googleDriveTransferStatus.isEmpty ? localizedCloudSyncingStatus : googleDriveTransferStatus)
                    }

                    if !googleDriveStatus.isEmpty {
                        BackupStatusMessage(text: googleDriveStatus)
                    }
                }
                .padding(14)
            }
            .background(Color.appInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        }
    }

    private var localBackupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "externaldrive")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(width: 28, height: 28)
                    .background(Color.appInputBackground)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedBackupTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text(localizedLocalBackupSubtitle)
                        .font(.caption2.weight(.regular))
                        .foregroundColor(.appMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                LocalBackupActionButton(title: localizedExportBackupTitle, systemImage: "square.and.arrow.up") {
                    exportBackup()
                }
                LocalBackupActionButton(title: localizedImportBackupTitle, systemImage: "tray.and.arrow.down") {
                    isBackupImporterPresented = true
                }
            }

            if !backupStatus.isEmpty {
                BackupStatusMessage(text: backupStatus)
            }
        }
        .padding(12)
        .background(Color.appPanel.opacity(0.72))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.75)))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func googleDriveInfoLine(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .frame(width: 18)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func googleDriveActionButton(
        title: String,
        systemImage: String,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 10)
                .background(isProminent ? buttonAccent : buttonAccent.opacity(0.1))
                .foregroundColor(isProminent ? .white : buttonAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var googleDriveAccountStatusTitle: String {
        if !googleDriveSyncService.isConfigured {
            return localizedCloudNotConfiguredStatus
        }
        return googleDriveSyncService.isSignedIn ? localizedCloudSignedInStatus : localizedCloudSignedOutStatus
    }

    private var googleDriveAccountStatusDetail: String {
        guard googleDriveSyncService.isSignedIn else { return "" }
        return googleDriveSyncService.accountEmail
    }

    private func exportBackup() {
        do {
            backupSharePayload = SharePayload(url: try store.backupFileURL())
            backupStatus = localizedBackupCreatedStatus
        } catch {
            backupStatus = localizedBackupCreateFailedStatus
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
            backupStatus = localizedBackupReadFailedStatus
        }
    }

    private func importPendingBackup(mode: BackupImportMode) {
        guard let pendingBackupData else { return }
        do {
            try store.importBackupData(pendingBackupData, mode: mode)
            backupStatus = mode == .merge ? localizedBackupMergeCompleteStatus : localizedBackupReplaceCompleteStatus
        } catch {
            backupStatus = localizedBackupImportFailedStatus
        }
        self.pendingBackupData = nil
    }

    private func signInToGoogleDrive() {
        guard purchaseService.hasProAccess else {
            showProForGoogleDrive()
            return
        }
        guard !isGoogleDriveBusy else { return }
        isGoogleDriveBusy = true
        googleDriveStatus = ""
        Task {
            defer { isGoogleDriveBusy = false }
            do {
                try await googleDriveSyncService.signIn()
                googleDriveStatus = localizedCloudSignedInCompleteStatus
            } catch {
                googleDriveStatus = googleDriveErrorMessage(error)
            }
        }
    }

    private func uploadCloudBackup() {
        guard purchaseService.hasProAccess else {
            showProForGoogleDrive()
            return
        }
        guard !isGoogleDriveBusy else { return }
        isGoogleDriveBusy = true
        googleDriveStatus = ""
        googleDriveTransferStatus = localizedCloudSyncingStatus
        Task {
            defer {
                isGoogleDriveBusy = false
                googleDriveTransferStatus = ""
            }
            do {
                store.saveCurrent()
                let data = try store.backupData()
                googleDriveTransferStatus = localizedCloudUploadingStatus
                let file = try await googleDriveSyncService.uploadAppBackup(
                    data: data,
                    existingFileID: googleDriveCloudBackupFileID.isEmpty ? nil : googleDriveCloudBackupFileID
                )
                googleDriveCloudBackupFileID = file.fileId
                googleDriveCloudLastSync = formattedCloudSyncDate()
                googleDriveStatus = "\(localizedCloudUploadCompleteStatus) \(localizedCloudMonthlyFolderStatus)"
            } catch {
                googleDriveStatus = googleDriveErrorMessage(error)
            }
        }
    }

    private func loadCloudBackupsForSelection() {
        guard purchaseService.hasProAccess else {
            showProForGoogleDrive()
            return
        }
        guard !isGoogleDriveBusy else { return }
        isGoogleDriveBusy = true
        googleDriveStatus = ""
        googleDriveTransferStatus = localizedCloudLoadingPackagesStatus
        Task {
            defer {
                isGoogleDriveBusy = false
                googleDriveTransferStatus = ""
            }
            do {
                cloudBackupPackages = try await googleDriveSyncService.listAppBackups()
                selectedCloudBackupFileIDs = Set(cloudBackupPackages.prefix(1).map(\.fileId))
                isCloudBackupManagerPresented = true
            } catch {
                googleDriveStatus = googleDriveErrorMessage(error)
            }
        }
    }

    private func downloadSelectedCloudBackups() {
        guard purchaseService.hasProAccess else {
            showProForGoogleDrive()
            return
        }
        guard !isGoogleDriveBusy else { return }
        let selectedFiles = cloudBackupPackages.filter { selectedCloudBackupFileIDs.contains($0.fileId) }
        guard !selectedFiles.isEmpty else {
            googleDriveStatus = localizedCloudNoSelectionStatus
            return
        }

        isGoogleDriveBusy = true
        googleDriveStatus = ""
        googleDriveTransferStatus = localizedCloudDownloadProgressStatus(current: 0, total: selectedFiles.count)
        isCloudBackupManagerPresented = false
        Task {
            defer {
                isGoogleDriveBusy = false
                googleDriveTransferStatus = ""
            }
            do {
                var downloadedItems: [Data] = []
                for (index, file) in selectedFiles.enumerated() {
                    googleDriveTransferStatus = localizedCloudDownloadProgressStatus(current: index + 1, total: selectedFiles.count)
                    let result = try await googleDriveSyncService.downloadAppBackup(fileID: file.fileId)
                    googleDriveCloudBackupFileID = result.file.fileId
                    downloadedItems.append(result.data)
                }
                pendingCloudBackupDataItems = downloadedItems
                pendingCloudBackupData = downloadedItems.first
                googleDriveStatus = localizedCloudDownloadReadyStatus(downloadedItems.count)
                isCloudBackupImportOptionsPresented = true
            } catch {
                googleDriveStatus = googleDriveErrorMessage(error)
            }
        }
    }

    private func importPendingCloudBackup(mode: BackupImportMode) {
        guard purchaseService.hasProAccess else {
            showProForGoogleDrive()
            return
        }
        let dataItems = pendingCloudBackupDataItems.isEmpty ? pendingCloudBackupData.map { [$0] } ?? [] : pendingCloudBackupDataItems
        guard !dataItems.isEmpty else { return }
        do {
            let effectiveMode: BackupImportMode = dataItems.count > 1 ? .merge : mode
            for (index, data) in dataItems.enumerated() {
                try store.importBackupData(data, mode: index == 0 ? effectiveMode : .merge)
            }
            googleDriveCloudLastSync = formattedCloudSyncDate()
            googleDriveStatus = dataItems.count > 1
                ? localizedCloudMultipleMergeCompleteStatus(dataItems.count)
                : mode == .merge ? localizedCloudMergeCompleteStatus : localizedCloudReplaceCompleteStatus
        } catch {
            googleDriveStatus = googleDriveStorageErrorMessage(error)
        }
        self.pendingCloudBackupData = nil
        self.pendingCloudBackupDataItems = []
    }

    private func showProForGoogleDrive() {
        googleDriveStatus = localizedCloudProRequiredStatus
        selectedSection = .pro
    }

    private func clearLocalBusinessData() {
        store.clearLocalBusinessData()
        backupStatus = ""
        googleDriveTransferStatus = ""
        clearDataStatus = localizedClearDataCompleteStatus
    }

    private func googleDriveErrorMessage(_ error: Error) -> String {
        guard let syncError = error as? GoogleDriveSyncError else {
            return localizedCloudUnknownErrorStatus
        }
        switch syncError {
        case .missingGoogleConfiguration:
            return localizedCloudNotConfiguredStatus
        case .presentingViewControllerUnavailable:
            return localizedCloudPresentationErrorStatus
        case .authorizationCancelled:
            return localizedCloudAuthorizationCancelledStatus
        case .authorizationFailed(let message):
            return "\(localizedCloudAuthorizationFailedStatus): \(message)"
        case .tokenExpired:
            googleDriveSyncService.signOut()
            return localizedCloudTokenExpiredStatus
        case .cloudBackupNotFound:
            return localizedCloudBackupNotFoundStatus
        case .invalidDriveResponse:
            return localizedCloudInvalidResponseStatus
        case .networkUnavailable:
            return localizedCloudNetworkFailedStatus
        case .driveAPIUnavailable(let projectID):
            return localizedCloudDriveAPIUnavailableStatus(projectID)
        case .server(let statusCode, let message):
            return "\(localizedCloudServerFailedStatus) (\(statusCode)): \(message)"
        }
    }

    private func formattedCloudSyncDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    private func cloudBackupDateText(_ file: GoogleDriveCloudBackupFile) -> String {
        guard let modifiedTime = file.modifiedTime else { return "" }
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: modifiedTime) else { return modifiedTime }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func cloudBackupSizeText(_ file: GoogleDriveCloudBackupFile) -> String {
        guard let size = file.size else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func googleDriveStorageErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            return localizedCloudAppStorageWarningText
        }
        return localizedBackupImportFailedStatus
    }

    private var localizedStampTitle: String {
        localized(japanese: "印章管理", chinese: "印章管理", english: "Stamp Management")
    }

    private var localizedStampUnavailableText: String {
        localized(japanese: "印章管理は iOS 16 以上で使用できます。", chinese: "印章管理可在 iOS 16 及以上使用。", english: "Stamp management is available on iOS 16 and later.")
    }

    private var localizedSubscriptionTitle: String { localized(japanese: "契約・Pro", chinese: "订阅与 Pro", english: "Subscription and Pro") }
    private var localizedProTitle: String { localized(japanese: "Pro 管理", chinese: "Pro 管理", english: "Manage Pro") }
    private var localizedProStatusText: String {
        switch language {
        case .japanese: return purchaseService.hasProAccess ? "有効" : "プレビュー共有、Google Driveバックアップ"
        case .simplifiedChinese: return purchaseService.hasProAccess ? "已启用" : "预览分享与 Google Drive 备份"
        case .english: return purchaseService.hasProAccess ? "Active" : "Preview sharing and Google Drive backup"
        }
    }
    private var localizedPreservationNoticeTitle: String { localized(japanese: "帳票保存サポート", chinese: "表单保存支持", english: "Form Preservation Support") }
    private var localizedPreservationNoticeHeadline: String {
        localized(
            japanese: "電子帳簿等保存制度に対応しやすい帳票整理",
            chinese: "便于配合电子帐簿等保存制度的表单整理",
            english: "Organize forms for electronic bookkeeping preservation workflows"
        )
    }
    private var localizedPreservationNoticeBody: String {
        localized(
            japanese: "作成・保存は端末内で利用できます。PDFプレビュー共有とGoogle DriveバックアップはProで利用できます。",
            chinese: "创建与保存可在本机完成。PDF 预览分享与 Google Drive 备份可在 Pro 中使用。",
            english: "Create and save on device. PDF preview sharing and Google Drive backup are available with Pro."
        )
    }
    private var localizedReviewPromotionTitle: String {
        localized(japanese: "開発者からのお願い", chinese: "开发者的一点请求", english: "A Note from the Developer")
    }
    private var localizedReviewPromotionSubtitle: String {
        localized(
            japanese: "台湾出身の Kody Chang が開発しています。よろしければ App Store で評価をお願いします。",
            chinese: "由来自台湾的 Kody Chang 开发。喜欢的话，欢迎到 App Store 给我们评价。",
            english: "Built by Kody Chang from Taiwan. If you like the app, please leave an App Store review."
        )
    }

    private var localizedBackupTitle: String { localized(japanese: "ローカルバックアップ", chinese: "本机备份", english: "Local Backup") }
    private var localizedLocalBackupSubtitle: String {
        localized(
            japanese: "ファイルで書き出し・読み込みを行う補助機能です。通常は上の Google Drive を使用してください。",
            chinese: "以文件导出、导入的辅助功能。通常请优先使用上方的 Google Drive。",
            english: "A secondary file export and import option. Use Google Drive above for normal backup."
        )
    }
    private var localizedPrinterAnimationTitle: String { localized(japanese: "PDFプレビューの印刷アニメーション", chinese: "PDF 预览打印机动画", english: "PDF Preview Printer Animation") }
    private var localizedPrivacyPolicyTitle: String { localized(japanese: "プライバシーポリシー", chinese: "隐私政策", english: "Privacy Policy") }
    private var localizedPrivacyPolicyLinkTitle: String { localized(japanese: "プライバシーポリシーを開く", chinese: "打开隐私政策", english: "Open Privacy Policy") }
    private var localizedDSATitle: String { localized(japanese: "DSA 対応情報", chinese: "DSA 合规信息", english: "DSA Compliance Information") }
    private var localizedDSAVisibleTitle: String { localized(japanese: "設定内に DSA 情報を表示", chinese: "在设置中显示 DSA 信息", english: "Show DSA information in Settings") }
    private var localizedDSATraderStatusTitle: String { localized(japanese: "事業者区分", chinese: "经营者状态", english: "Trader Status") }
    private var localizedDSATraderOptionTitle: String { localized(japanese: "Trader", chinese: "Trader / 经营者", english: "Trader") }
    private var localizedDSAHiddenSummaryText: String { localized(japanese: "DSA 情報は非表示です。", chinese: "DSA 信息目前隐藏。", english: "DSA information is hidden.") }
    private var dsaSummaryText: String {
        let name = dsaLegalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = dsaContactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && !email.isEmpty {
            return "\(name) / \(email)"
        }
        if !name.isEmpty {
            return name
        }
        if !email.isEmpty {
            return email
        }
        return localizedDSAHelpText
    }
    private var localizedSelectedDSATraderStatus: String {
        localizedDSATraderOptionTitle
    }
    private var localizedDSAHelpText: String {
        localized(
            japanese: "EU の Digital Services Act に関連する連絡先情報を App 内で表示・管理します。App Store Connect の DSA 申告内容も別途確認してください。",
            chinese: "在 App 内显示和管理与欧盟 Digital Services Act 相关的联系信息。App Store Connect 的 DSA 申报内容仍需另外确认。",
            english: "Display and manage contact information related to the EU Digital Services Act. Also verify the separate DSA declaration in App Store Connect."
        )
    }
    private var localizedDSALegalNameTitle: String { localized(japanese: "事業者名", chinese: "经营者名称", english: "Legal Name") }
    private var localizedDSAEmailTitle: String { localized(japanese: "連絡先メール", chinese: "联系邮箱", english: "Contact Email") }
    private var localizedDSAAddressTitle: String { localized(japanese: "連絡先住所", chinese: "联系地址", english: "Contact Address") }
    private var localizedDSASupportURLTitle: String { localized(japanese: "サポート URL", chinese: "支持 URL", english: "Support URL") }
    private var localizedExportBackupTitle: String { localized(japanese: "すべての内容をバックアップして共有", chinese: "备份并分享全部内容", english: "Back Up and Share All Content") }
    private var localizedImportBackupTitle: String { localized(japanese: "バックアップファイルを読み込む", chinese: "导入备份文件", english: "Import Backup File") }
    private var localizedBackupImportModeTitle: String { localized(japanese: "バックアップの読み込み方法", chinese: "备份导入方式", english: "Backup Import Method") }
    private var localizedMergeBackupTitle: String { localized(japanese: "既存データに結合", chinese: "合并到现有数据", english: "Merge with Existing Data") }
    private var localizedReplaceBackupTitle: String { localized(japanese: "バックアップから新規作成", chinese: "用备份重新建立", english: "Replace with Backup") }
    private var localizedBackupImportModeMessage: String { localized(japanese: "結合では既存データを上書きしません。新規作成ではバックアップファイルの内容からデータを作成します。", chinese: "合并不会覆盖本机现有数据；重新建立会使用备份文件内容创建数据。", english: "Merge will not overwrite existing local data. Replace creates data from the backup file.") }
    private var localizedBackupCreatedStatus: String { localized(japanese: "バックアップファイルを作成しました。", chinese: "已创建备份文件。", english: "Backup file created.") }
    private var localizedBackupCreateFailedStatus: String { localized(japanese: "バックアップファイルを作成できませんでした。", chinese: "无法创建备份文件。", english: "Could not create the backup file.") }
    private var localizedBackupReadFailedStatus: String { localized(japanese: "バックアップファイルを読み込めませんでした。", chinese: "无法读取备份文件。", english: "Could not read the backup file.") }
    private var localizedBackupMergeCompleteStatus: String { localized(japanese: "バックアップ内容を既存データに結合しました。", chinese: "已将备份内容合并到现有数据。", english: "Backup content was merged with existing data.") }
    private var localizedBackupReplaceCompleteStatus: String { localized(japanese: "バックアップ内容から新しいデータを作成しました。", chinese: "已用备份内容重新建立数据。", english: "New data was created from the backup.") }
    private var localizedBackupImportFailedStatus: String { localized(japanese: "バックアップファイルを読み込めませんでした。", chinese: "无法导入备份文件。", english: "Could not import the backup file.") }
    private var localizedCancelTitle: String {
        localized(japanese: "キャンセル", chinese: "取消", english: "Cancel")
    }
    private var localizedClearDataSectionTitle: String { localized(japanese: "データ削除", chinese: "资料清除", english: "Clear Data") }
    private var localizedClearDataActionTitle: String { localized(japanese: "この端末の App 資料を削除", chinese: "清除本机 App 资料", english: "Clear This Device's App Data") }
    private var localizedClearDataWarningText: String {
        localized(
            japanese: "保存済み帳票、編集中の下書き、会社・取引先・商品・テンプレート、印章をこの端末から削除します。作成済みのバックアップファイルや Google Drive 内のバックアップは削除しません。",
            chinese: "将从本机删除已保存表单、编辑中的草稿、公司/客户/商品/模板与印章。已经导出的备份文件和 Google Drive 里的备份不会被删除。",
            english: "Deletes saved forms, the current draft, company, customer, product, template, and stamp data from this device. Exported backup files and Google Drive backups are not deleted."
        )
    }
    private var localizedClearDataFirstConfirmTitle: String { localized(japanese: "App 資料を削除しますか？", chinese: "要清除 App 资料吗？", english: "Clear App Data?") }
    private var localizedClearDataFirstConfirmMessage: String {
        localized(
            japanese: "この操作はこの端末内の帳票と管理資料を削除します。バックアップが必要な場合は先に作成してください。",
            chinese: "此操作会删除本机内的表单和管理资料。如需保留，请先建立备份。",
            english: "This deletes forms and management data on this device. Create a backup first if you need to keep them."
        )
    }
    private var localizedClearDataContinueTitle: String { localized(japanese: "次へ", chinese: "继续", english: "Continue") }
    private var localizedClearDataFinalConfirmTitle: String { localized(japanese: "最終確認", chinese: "最终确认", english: "Final Confirmation") }
    private var localizedClearDataFinalConfirmMessage: String {
        localized(
            japanese: "削除後はこの端末から復元できません。バックアップがない場合、資料は失われます。本当に削除しますか？",
            chinese: "删除后无法从本机复原。如果没有备份，资料会永久遗失。确定要删除吗？",
            english: "After deletion, this device cannot restore the data. Without a backup, the data will be lost. Are you sure?"
        )
    }
    private var localizedClearDataFinalActionTitle: String { localized(japanese: "完全に削除", chinese: "彻底删除", english: "Delete Permanently") }
    private var localizedClearDataCompleteStatus: String { localized(japanese: "この端末の App 資料を削除しました。バックアップは削除していません。", chinese: "已清除本机 App 资料。备份没有被删除。", english: "App data on this device was cleared. Backups were not deleted.") }
    private var localizedCloudBackupTitle: String { localized(japanese: "Google Drive バックアップ", chinese: "Google Drive 云备份", english: "Google Drive Backup") }
    private var localizedCloudProUpgradeTitle: String { localized(japanese: "ProでGoogle Driveバックアップを使う", chinese: "升级 Pro 使用 Google Drive 备份", english: "Use Google Drive Backup with Pro") }
    private var localizedCloudSignInTitle: String { localized(japanese: "Google Drive にログイン", chinese: "登录 Google Drive", english: "Sign In to Google Drive") }
    private var localizedCloudSignOutTitle: String { localized(japanese: "ログアウト", chinese: "退出登录", english: "Sign Out") }
    private var localizedCloudUploadTitle: String { localized(japanese: "この端末の内容をアップロード", chinese: "上传本机内容", english: "Upload This Device") }
    private var localizedCloudDownloadTitle: String { localized(japanese: "Google Drive から同期", chinese: "从 Google Drive 同步", english: "Sync from Google Drive") }
    private var localizedCloudLastSyncTitle: String { localized(japanese: "最終同期", chinese: "上次同步", english: "Last sync") }
    private var localizedCloudSyncingStatus: String { localized(japanese: "同期中", chinese: "同步中", english: "Syncing") }
    private var localizedCloudUploadingStatus: String { localized(japanese: "Google Drive にアップロード中", chinese: "正在上传到 Google Drive", english: "Uploading to Google Drive") }
    private var localizedCloudLoadingPackagesStatus: String { localized(japanese: "同期パックを読み込み中", chinese: "正在读取同步备份包", english: "Loading backup packages") }
    private var localizedCloudMonthlyFolderStatus: String { localized(japanese: "月別フォルダに保存しました。", chinese: "已保存到按月份区分的文件夹。", english: "Saved in a monthly folder.") }
    private var localizedCloudSyncConfirmTitle: String { localized(japanese: "Google Drive と同期しますか？", chinese: "确定要从 Google Drive 同步吗？", english: "Sync from Google Drive?") }
    private var localizedCloudSyncConfirmMessage: String { localized(japanese: "Google Drive のバックアップ一覧を読み込みます。選択した同期パックを取り込めます。置き換えを選ぶと、この端末の既存データが上書きされる可能性があります。", chinese: "将读取 Google Drive 备份包列表。你可以选择要同步的备份包；如果后续选择替换，本机现有资料可能会被覆盖。", english: "This will load the Google Drive backup package list. You can choose which packages to sync; choosing Replace later may overwrite existing data on this device.") }
    private var localizedCloudSyncConfirmButtonTitle: String { localized(japanese: "一覧を表示", chinese: "查看备份包", english: "Show Packages") }
    private var localizedCloudBackupManagerTitle: String { localized(japanese: "同期パックを選択", chinese: "选择同步备份包", english: "Choose Backup Packages") }
    private var localizedCloudBackupManagerSubtitle: String { localized(japanese: "バックアップは Google Drive 内で月別フォルダに保存されます。複数選択した場合は既存データに結合します。", chinese: "备份会按月份保存在 Google Drive。选择多个时会合并到现有数据。", english: "Backups are saved by month in Google Drive. Multiple selected packages are merged into existing data.") }
    private var localizedCloudBackupManagerEmptyText: String { localized(japanese: "Google Drive に同期パックがありません。まずこの端末からアップロードしてください。", chinese: "Google Drive 中没有同步备份包。请先从本机上传。", english: "No backup packages were found in Google Drive. Upload from this device first.") }
    private var localizedCloudStorageWarningText: String { localized(japanese: "大きなバックアップを複数取り込むと、この端末の空き容量や App の保存容量が不足し、App が不安定になる場合があります。不要なファイルは Google Drive アプリで管理してください。", chinese: "一次同步多个大型备份包时，如果手机容量或 App 可用保存空间不足，App 可能会不稳定或崩溃。不要的备份请到 Google Drive App 管理。", english: "Syncing multiple large packages can make the app unstable if device storage or app storage is low. Manage unwanted backups in the Google Drive app.") }
    private var localizedCloudAppStorageWarningText: String { localized(japanese: "端末または App の保存容量が不足している可能性があります。不要なバックアップや添付ファイルを整理してから再試行してください。", chinese: "手机或 App 的保存空间可能不足。请先清理不需要的备份或附件后再试。", english: "Device or app storage may be low. Clear unneeded backups or attachments, then try again.") }
    private var localizedCloudDeleteHelpText: String { localized(japanese: "削除はこの App では行いません。不要な同期パックは Google Drive アプリで削除してください。", chinese: "本 App 不提供删除功能；不需要的同步包请到 Google Drive App 删除。", english: "Deletion is not supported in this app. Delete unwanted packages in the Google Drive app.") }
    private var localizedCloudSyncSelectedTitle: String { localized(japanese: "選択した同期パックを取り込む", chinese: "同步选中的备份包", english: "Sync Selected Packages") }
    private var localizedCloudRefreshBackupsTitle: String { localized(japanese: "再読み込み", chinese: "刷新", english: "Refresh") }
    private var localizedCloudNoSelectionStatus: String { localized(japanese: "同期パックを選択してください。", chinese: "请选择至少一个同步备份包。", english: "Select at least one backup package.") }
    private var localizedCloudImportModeTitle: String { localized(japanese: "Google Drive から同期", chinese: "从 Google Drive 同步", english: "Sync from Google Drive") }
    private var localizedCloudImportModeMessage: String { localized(japanese: "Google Drive のバックアップを既存データに結合するか、この端末の内容を置き換えるか選択してください。複数選択時は安全のため結合のみ実行します。", chinese: "请选择将 Google Drive 备份合并到本机，或用云端内容替换本机内容。选择多个备份包时，为避免覆盖，只会执行合并。", english: "Choose whether to merge the Google Drive backup or replace this device. Multiple selected packages are merged only.") }
    private var localizedCloudSignedInStatus: String { localized(japanese: "ログイン済み", chinese: "已登录", english: "Signed in") }
    private var localizedCloudSignedOutStatus: String { localized(japanese: "未ログイン", chinese: "未登录", english: "Signed out") }
    private var localizedCloudSignedInCompleteStatus: String { localized(japanese: "Google Drive にログインしました。", chinese: "已登录 Google Drive。", english: "Signed in to Google Drive.") }
    private var localizedCloudSignedOutCompleteStatus: String { localized(japanese: "Google Drive からログアウトしました。", chinese: "已退出 Google Drive。", english: "Signed out of Google Drive.") }
    private var localizedCloudUploadCompleteStatus: String { localized(japanese: "Google Drive にバックアップしました。", chinese: "已备份到 Google Drive。", english: "Backed up to Google Drive.") }
    private var localizedCloudMergeCompleteStatus: String { localized(japanese: "Google Drive の内容を既存データに結合しました。", chinese: "已将 Google Drive 内容合并到本机。", english: "Google Drive content was merged into this device.") }
    private var localizedCloudReplaceCompleteStatus: String { localized(japanese: "Google Drive の内容でこの端末を更新しました。", chinese: "已用 Google Drive 内容更新本机。", english: "This device was updated from Google Drive.") }
    private var localizedCloudNotConfiguredStatus: String { localized(japanese: "Google Drive の設定がありません。", chinese: "缺少 Google Drive 配置。", english: "Google Drive is not configured.") }
    private var localizedCloudPresentationErrorStatus: String { localized(japanese: "ログイン画面を表示できませんでした。", chinese: "无法显示登录界面。", english: "Could not present the sign-in screen.") }
    private var localizedCloudAuthorizationCancelledStatus: String { localized(japanese: "Google Drive の認証をキャンセルしました。", chinese: "已取消 Google Drive 授权。", english: "Google Drive authorization was cancelled.") }
    private var localizedCloudAuthorizationFailedStatus: String { localized(japanese: "Google Drive の認証に失敗しました", chinese: "Google Drive 授权失败", english: "Google Drive authorization failed") }
    private var localizedCloudTokenExpiredStatus: String { localized(japanese: "ログインの有効期限が切れました。もう一度ログインしてください。", chinese: "登录已过期，请重新登录。", english: "The sign-in expired. Please sign in again.") }
    private var localizedCloudBackupNotFoundStatus: String { localized(japanese: "Google Drive にバックアップがありません。", chinese: "Google Drive 中没有备份。", english: "No Google Drive backup was found.") }
    private var localizedCloudInvalidResponseStatus: String { localized(japanese: "Google Drive の応答を読み込めませんでした。", chinese: "无法读取 Google Drive 响应。", english: "Could not read the Google Drive response.") }
    private var localizedCloudNetworkFailedStatus: String { localized(japanese: "ネットワークに接続できませんでした。", chinese: "网络连接失败。", english: "The network request failed.") }
    private var localizedCloudServerFailedStatus: String { localized(japanese: "Google Drive リクエストに失敗しました", chinese: "Google Drive 请求失败", english: "Google Drive request failed") }
    private var localizedCloudUnknownErrorStatus: String { localized(japanese: "Google Drive バックアップに失敗しました。", chinese: "Google Drive 备份失败。", english: "Google Drive backup failed.") }
    private var localizedCloudProRequiredStatus: String { localized(japanese: "Google DriveバックアップはPro機能です。Proにすると利用できます。", chinese: "Google Drive 备份属于 Pro 功能。升级 Pro 后即可使用。", english: "Google Drive backup is a Pro feature. Upgrade to Pro to use it.") }

    private func localizedCloudDownloadProgressStatus(current: Int, total: Int) -> String {
        localized(
            japanese: "Google Drive からダウンロード中 \(current)/\(total)",
            chinese: "正在从 Google Drive 下载 \(current)/\(total)",
            english: "Downloading from Google Drive \(current)/\(total)"
        )
    }

    private func localizedCloudDownloadReadyStatus(_ count: Int) -> String {
        localized(
            japanese: "\(count) 件の同期パックをダウンロードしました。読み込み方法を選択してください。",
            chinese: "已下载 \(count) 个同步备份包。请选择导入方式。",
            english: "\(count) backup packages downloaded. Choose how to import them."
        )
    }

    private func localizedCloudMultipleMergeCompleteStatus(_ count: Int) -> String {
        localized(
            japanese: "\(count) 件の同期パックを既存データに結合しました。",
            chinese: "已将 \(count) 个同步备份包合并到本机。",
            english: "\(count) backup packages were merged into this device."
        )
    }

    private func localizedCloudDriveAPIUnavailableStatus(_ projectID: String?) -> String {
        let projectText = projectID.map { " Project: \($0)." } ?? ""
        return localized(
            japanese: "Google Cloud Console で Google Drive API を有効にしてください。\(projectText) 有効化後、数分待って再試行してください。",
            chinese: "请在 Google Cloud Console 启用 Google Drive API。\(projectText) 启用后等待几分钟再重试。",
            english: "Enable Google Drive API in Google Cloud Console.\(projectText) Wait a few minutes after enabling it, then try again."
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

private struct OnboardingGuideSheet: View {
    @ObservedObject var store: DocumentStore
    let language: AppLanguage
    let onSelectSection: (AppSection) -> Void
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var step: OnboardingStep = .start
    @State private var isDemoImportConfirmationPresented = false
    @State private var importStatus = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    ForEach(OnboardingStep.allCases) { item in
                        onboardingPage(for: item)
                            .tag(item)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

                VStack(spacing: 10) {
                    if !importStatus.isEmpty {
                        BackupStatusMessage(text: importStatus)
                    }

                    Button {
                        isDemoImportConfirmationPresented = true
                    } label: {
                        Label(localizedLoadDemoTitle, systemImage: "tray.and.arrow.down.fill")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(buttonAccent.opacity(0.12))
                            .foregroundColor(buttonAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())

                    HStack(spacing: 10) {
                        Button {
                            moveBackward()
                        } label: {
                            Label(localizedBackTitle, systemImage: "chevron.left")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(step == .start)
                        .opacity(step == .start ? 0.45 : 1)

                        Button {
                            moveForwardOrFinish()
                        } label: {
                            Label(step == .preview ? localizedFinishTitle : localizedNextTitle, systemImage: step == .preview ? "checkmark" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .background(buttonAccent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(16)
                .background(Color.appPanel)
                .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .top)
            }
            .navigationTitle(localizedNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedCloseTitle) {
                        finishAndDismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .confirmationDialog(localizedDemoConfirmTitle, isPresented: $isDemoImportConfirmationPresented, titleVisibility: .visible) {
            Button(localizedLoadDemoTitle) {
                loadDemoData()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedDemoConfirmMessage)
        }
        .onDisappear {
            onFinish()
        }
    }

    private func onboardingPage(for item: OnboardingStep) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 72, height: 72)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title(language))
                        .font(.title2.weight(.bold))
                        .foregroundColor(.appInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.body(language))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(item.points(language), id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(buttonAccent)
                                .padding(.top, 2)
                            Text(point)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appInputBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                .cornerRadius(8)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .topLeading)
            .padding(20)
        }
        .background(Color.appBackground)
    }

    private func moveBackward() {
        guard let index = OnboardingStep.allCases.firstIndex(of: step), index > 0 else { return }
        step = OnboardingStep.allCases[index - 1]
    }

    private func moveForwardOrFinish() {
        guard let index = OnboardingStep.allCases.firstIndex(of: step) else { return }
        if index == OnboardingStep.allCases.count - 1 {
            finishAndDismiss()
        } else {
            step = OnboardingStep.allCases[index + 1]
        }
    }

    private func finishAndDismiss() {
        onFinish()
        dismiss()
    }

    private func loadDemoData() {
        do {
            try store.importBundledDemoData()
            importStatus = localizedDemoLoadedStatus
        } catch {
            importStatus = localizedDemoFailedStatus
        }
    }

    private var localizedNavigationTitle: String { localized(japanese: "初回ガイド", chinese: "首次导览", english: "First Guide") }
    private var localizedLoadDemoTitle: String { localized(japanese: "テスト用デモデータを読み込む", chinese: "载入测试虚拟数据", english: "Load Demo Test Data") }
    private var localizedBackTitle: String { localized(japanese: "戻る", chinese: "上一步", english: "Back") }
    private var localizedNextTitle: String { localized(japanese: "次へ", chinese: "下一步", english: "Next") }
    private var localizedFinishTitle: String { localized(japanese: "完了", chinese: "完成", english: "Finish") }
    private var localizedCloseTitle: String { localized(japanese: "閉じる", chinese: "跳出", english: "Close") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedDemoConfirmTitle: String { localized(japanese: "デモデータを読み込みますか？", chinese: "要载入测试虚拟数据吗？", english: "Load Demo Test Data?") }
    private var localizedDemoConfirmMessage: String {
        localized(
            japanese: "テスト用の会社、商品、取引先、帳票を追加します。読み込み後もこのガイドを続けられます。不要になったデータは設定の「データ削除」からこの端末のApp資料を削除できます。",
            chinese: "会加入测试用的公司、产品、客户和表单。载入后会继续停留在当前导览页。之后可在设置里的「资料清除」删除本机 App 资料并还原。",
            english: "This adds demo companies, products, customers, and forms. You can continue this guide from the current page. Later, clear this device's app data from Settings > Clear Data."
        )
    }
    private var localizedDemoLoadedStatus: String { localized(japanese: "デモデータを読み込みました。ガイドを続けられます。", chinese: "已载入测试虚拟数据。可以继续当前导览。", english: "Demo data loaded. You can continue the guide.") }
    private var localizedDemoFailedStatus: String { localized(japanese: "デモデータを読み込めませんでした。", chinese: "无法载入测试虚拟数据。", english: "Could not load demo data.") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private enum OnboardingStep: String, CaseIterable, Identifiable {
    case start
    case company
    case products
    case customers
    case form
    case preview

    var id: String { rawValue }

    var section: AppSection {
        switch self {
        case .start: return .menu
        case .company: return .company
        case .products: return .products
        case .customers: return .customers
        case .form: return .form
        case .preview: return .preview
        }
    }

    var systemImage: String {
        switch self {
        case .start: return "hand.tap.fill"
        case .company: return "building.columns.fill"
        case .products: return "shippingbox.fill"
        case .customers: return "building.2.fill"
        case .form: return "doc.text.fill"
        case .preview: return "doc.richtext.fill"
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .start: return localized(language, japanese: "まず使い方を確認", chinese: "先学会基本用法", english: "Start with the Basics")
        case .company: return localized(language, japanese: "会社情報を登録", chinese: "建立公司信息", english: "Create Company Information")
        case .products: return localized(language, japanese: "商品情報を登録", chinese: "建立产品信息", english: "Create Product Information")
        case .customers: return localized(language, japanese: "取引先情報を登録", chinese: "建立客户信息", english: "Create Customer Information")
        case .form: return localized(language, japanese: "帳票を作成", chinese: "建立表单", english: "Create a Form")
        case .preview: return localized(language, japanese: "プレビューを確認", chinese: "预览", english: "Preview")
        }
    }

    func body(_ language: AppLanguage) -> String {
        switch self {
        case .start:
            return localized(language, japanese: "このアプリは、会社・商品・取引先を候補として保存し、帳票作成とPDF確認までを端末内で進めます。", chinese: "这个 App 会先保存公司、产品与客户候选资料，再用这些资料建立表单并确认 PDF 预览。", english: "Save company, product, and customer profiles, then use them to create forms and preview PDFs on this device.")
        case .company:
            return localized(language, japanese: "帳票に表示する自社名、登録番号、連絡先、住所を登録します。", chinese: "登记表单上显示的本公司名称、登记编号、联系人和地址。", english: "Register the issuer name, registration number, contact details, and address shown on forms.")
        case .products:
            return localized(language, japanese: "よく使う商品や作業項目を保存すると、明細入力が速くなります。", chinese: "保存常用商品或作业项目后，建立明细会更快。", english: "Save frequently used products or work items to speed up line item entry.")
        case .customers:
            return localized(language, japanese: "顧客や仕入先を保存しておくと、帳票作成時に候補から呼び出せます。", chinese: "预先保存客户或供应商后，建立表单时可直接从候选项带入。", english: "Save customers and vendors so they can be inserted while creating forms.")
        case .form:
            return localized(language, japanese: "見積、注文、納品、請求、領収など、用途に合わせて帳票を選んで入力します。", chinese: "依照用途选择报价、订单、交付、请款、收据等表单并输入内容。", english: "Choose the form type you need, such as estimate, order, delivery, invoice, or receipt.")
        case .preview:
            return localized(language, japanese: "保存した帳票はPDFとして確認できます。共有やGoogle DriveバックアップはPro機能です。", chinese: "保存后的表单可用 PDF 预览确认。分享与 Google Drive 备份属于 Pro 功能。", english: "Saved forms can be reviewed as PDFs. Sharing and Google Drive backup are Pro features.")
        }
    }

    func points(_ language: AppLanguage) -> [String] {
        switch self {
        case .start:
            return [
                localized(language, japanese: "下のボタンから各管理画面を開けます。", chinese: "可用下方按钮打开对应管理页面。", english: "Use the button below to open each related screen."),
                localized(language, japanese: "導入中でも右上からいつでも閉じられます。", chinese: "导览过程中可随时从右上角跳出。", english: "You can close the guide at any time.")
            ]
        case .company:
            return [
                localized(language, japanese: "複数の会社情報を保存できます。", chinese: "可以保存多笔公司资料。", english: "You can save multiple company profiles."),
                localized(language, japanese: "既定の会社情報は新規帳票に反映されます。", chinese: "默认公司资料会带入新表单。", english: "The default company is applied to new forms.")
            ]
        case .products:
            return [
                localized(language, japanese: "品名、型番、仕様、単価を保存します。", chinese: "保存品名、型号、规格和单价。", english: "Save item name, model, specification, and unit price."),
                localized(language, japanese: "帳票明細へ候補から入力できます。", chinese: "建立表单明细时可从候选项输入。", english: "Insert saved products into form line items.")
            ]
        case .customers:
            return [
                localized(language, japanese: "顧客と仕入先の候補を同じ場所で管理します。", chinese: "客户与供应商候选资料在同一处管理。", english: "Manage customers and vendors in one place."),
                localized(language, japanese: "会社名、担当者、電話、メール、住所を保存します。", chinese: "保存公司名、负责人、电话、邮箱和地址。", english: "Save name, contact, phone, email, and address.")
            ]
        case .form:
            return [
                localized(language, japanese: "入力中の内容は保存して後から再利用できます。", chinese: "输入中的内容可保存并之后继续使用。", english: "Save forms and reuse them later."),
                localized(language, japanese: "プロジェクトにまとめると関連帳票を追跡しやすくなります。", chinese: "放入项目后更容易追踪相关表单。", english: "Projects help track related forms together.")
            ]
        case .preview:
            return [
                localized(language, japanese: "保存済み帳票からPDFプレビューを開けます。", chinese: "可从已保存表单打开 PDF 预览。", english: "Open PDF preview from saved forms."),
                localized(language, japanese: "テストデータを読み込むとすぐにプレビューを試せます。", chinese: "载入测试数据后可以马上试用预览。", english: "Load demo data to try preview immediately.")
            ]
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

private struct ElectronicBookkeepingGuideSheet: View {
    let language: AppLanguage
    let onStartOnboarding: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        NavigationView {
            ManagementScroll(title: localizedTitle, subtitle: localizedSubtitle) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onStartOnboarding()
                    }
                } label: {
                    Label(localizedStartOnboardingTitle, systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(buttonAccent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())

                SectionCard(title: localizedCommonTitle, titleWeight: .regular) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(commonItems) { item in
                            PreservationGuidePointRow(item: item)
                        }
                    }
                }

                SectionCard(title: localizedFormTitle, titleWeight: .regular) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(formItems) { item in
                            PreservationGuideFormRow(item: item)
                        }
                    }
                }

                SectionCard(title: localizedNoticeTitle, titleWeight: .regular) {
                    Text(localizedNoticeBody)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appInputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedCloseTitle) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var commonItems: [PreservationGuideItem] {
        [
            PreservationGuideItem(
                title: localized(japanese: "入力項目の整理", chinese: "输入项目整理", english: "Structured Entry"),
                body: localized(
                    japanese: "取引先、日付、番号、金額、税率、備考、支払条件を帳票ごとに分けて保存し、後から確認しやすい形にします。",
                    chinese: "按表单保存交易对象、日期、编号、金额、税率、备注和付款条件，方便之后检索和确认。",
                    english: "Stores partner, date, number, amount, tax, notes, and payment terms by form for later review."
                )
            ),
            PreservationGuideItem(
                title: localized(japanese: "PDF 出力と共有", chinese: "PDF 输出与共享", english: "PDF Export and Sharing"),
                body: localized(
                    japanese: "保存した内容をPDFとして確認できます。プレビュー画面からの共有とGoogle DriveバックアップはProで利用できます。",
                    chinese: "可将已保存内容作为 PDF 确认。从预览画面分享与 Google Drive 备份可在 Pro 中使用。",
                    english: "Review saved entries as PDFs. Sharing from Preview and Google Drive backup are available with Pro."
                )
            ),
            PreservationGuideItem(
                title: localized(japanese: "プロジェクト単位の追跡", chinese: "按项目追踪", english: "Project Tracking"),
                body: localized(
                    japanese: "見積、注文、納品、請求、領収などを同じプロジェクトにまとめ、取引の流れを追いやすくします。",
                    chinese: "可把报价、订单、交付、请款、收据等放在同一项目下，便于追踪交易流程。",
                    english: "Groups quotes, orders, delivery notes, invoices, and receipts in one project workflow."
                )
            )
        ]
    }

    private var formItems: [PreservationGuideItem] {
        DocumentType.allCases.map { type in
            PreservationGuideItem(title: type.localizedTitle(language), body: formGuideBody(for: type))
        }
    }

    private func formGuideBody(for type: DocumentType) -> String {
        switch type {
        case .estimate:
            return localized(japanese: "見積条件、明細、税率、有効期限を残し、後続の注文・請求と照合しやすくします。", chinese: "保存报价条件、明细、税率和有效期，便于和后续订单、请款内容核对。", english: "Keeps terms, line items, tax, and validity dates for comparison with later orders and invoices.")
        case .customerOrder:
            return localized(japanese: "顧客から受けた注文内容、希望納期、関連見積番号を記録し、受注根拠を整理します。", chinese: "记录客户订单内容、希望交期和相关报价编号，用来整理受订单据依据。", english: "Records customer order details, requested delivery dates, and related quote numbers.")
        case .purchaseOrder:
            return localized(japanese: "仕入先への発注内容、数量、納期、条件を保存し、受領・支払確認につなげます。", chinese: "保存向供应商采购的内容、数量、交期和条件，便于后续收货和付款确认。", english: "Stores supplier order details, quantities, delivery dates, and terms for receipt and payment checks.")
        case .delivery:
            return localized(japanese: "納品日、品目、数量、相手先を残し、請求対象となる納品実績を確認できます。", chinese: "保存交付日期、品项、数量和对方信息，用于确认可请款的交付记录。", english: "Keeps delivery date, items, quantities, and partner details as invoice support.")
        case .invoice:
            return localized(japanese: "請求番号、明細、消費税、合計、支払条件を保存し、適格請求書の確認資料として使いやすくします。", chinese: "保存请款编号、明细、消费税、合计和付款条件，便于作为适格发票相关确认资料。", english: "Stores invoice number, line items, tax, totals, and payment terms for invoice review.")
        case .receipt:
            return localized(japanese: "入金日、領収金額、相手先、対象取引を残し、入金確認資料として整理します。", chinese: "保存入账日期、收款金额、对方和对应交易，用于整理收款确认资料。", english: "Records payment date, received amount, partner, and related transaction.")
        case .acceptance:
            return localized(japanese: "受領した品目、数量、受領日を保存し、納品・発注内容との照合に使えます。", chinese: "保存收货品项、数量和收货日期，便于与交付或采购内容核对。", english: "Keeps received items, quantities, and dates for matching against delivery or purchase orders.")
        case .customerFiles:
            return localized(japanese: "顧客ごとの関連ファイルや帳票をまとめ、同じ取引の資料を分散させず管理します。", chinese: "集中管理每个客户相关文件和表单，避免同一交易资料分散。", english: "Collects customer-related files and forms so transaction records stay together.")
        case .vendorEstimate:
            return localized(japanese: "仕入先見積の内容、受領日、添付資料を残し、発注判断の根拠を保存します。", chinese: "保存供应商报价内容、取得日期和附件资料，用作采购判断依据。", english: "Stores vendor quote content, receipt date, and attachments as purchase decision support.")
        case .vendorReceipt:
            return localized(japanese: "仕入先から受けた領収内容、支払証憑、関連資料をまとめて保存します。", chinese: "保存供应商收据内容、付款凭证和相关资料。", english: "Keeps vendor receipt details, payment evidence, and related documents together.")
        case .paymentNotice:
            return localized(japanese: "支払予定・支払通知の内容を残し、請求書や領収書との突合に使えます。", chinese: "保存付款预定或付款通知内容，便于和发票、收据核对。", english: "Records payment notices for matching with invoices and receipts.")
        }
    }

    private var localizedTitle: String {
        localized(japanese: "電子帳簿等保存制度への対応説明", chinese: "电子帐簿等保存制度说明", english: "Electronic Bookkeeping Guide")
    }

    private var localizedSubtitle: String {
        localized(
            japanese: "各帳票でどの情報を残し、保存・プレビュー・Pro共有にどうつながるかを確認できます。",
            chinese: "说明每个表单保留哪些信息，以及如何用于保存、预览和 Pro 分享。",
            english: "See what each form preserves and how it supports saving, previewing, and Pro sharing."
        )
    }

    private var localizedCommonTitle: String { localized(japanese: "共通してできること", chinese: "共同支持内容", english: "What the App Supports") }
    private var localizedFormTitle: String { localized(japanese: "帳票別の対応", chinese: "各表单对应点", english: "By Form Type") }
    private var localizedNoticeTitle: String { localized(japanese: "確認事項", chinese: "确认事项", english: "Notes") }
    private var localizedCloseTitle: String { localized(japanese: "閉じる", chinese: "关闭", english: "Close") }
    private var localizedStartOnboardingTitle: String { localized(japanese: "初回ガイドを開く", chinese: "开启导览", english: "Start Guide") }

    private var localizedNoticeBody: String {
        localized(
            japanese: "電子帳簿等保存制度では、可視性・検索性・真実性などの運用要件が求められる場合があります。本アプリは帳票作成、端末内保存、PDFプレビューを補助し、Proではプレビュー共有とGoogle Driveバックアップも利用できます。タイムスタンプ、訂正削除履歴、社内規程、税務判断が必要な場合は税理士または所轄税務署に確認してください。",
            chinese: "电子帐簿等保存制度可能要求可视性、检索性、真实性等运营条件。本 App 辅助表单创建、本机保存与 PDF 预览；Pro 可使用预览分享与 Google Drive 备份。如需时间戳、修订/删除记录、公司内部规程或税务判断，请向税理士或主管税务署确认。",
            english: "Electronic bookkeeping rules may require visibility, searchability, authenticity, and operational procedures. This app helps create forms, save on device, and preview PDFs; Pro adds preview sharing and Google Drive backup. Confirm timestamping, edit/delete history, internal policies, and tax decisions with an accountant or tax office."
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

private struct PreservationGuideItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private struct PreservationGuidePointRow: View {
    let item: PreservationGuideItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
            Text(item.body)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PreservationGuideFormRow: View {
    let item: PreservationGuideItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.caption.weight(.bold))
                .foregroundColor(.appInk)
            Text(item.body)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DeveloperStoryReviewScreen: View {
    let language: AppLanguage
    let onClose: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var isOpeningReview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                heroSection
                reviewRequestCard
                storyCard
                nextVersionCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                Text(localizedSubtitle)
                    .font(.footnote.weight(.regular))
                    .foregroundColor(.appMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.appInk)
                    .frame(width: 42, height: 42)
                    .background(Color.appInputBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.appDivider.opacity(0.7)))
            }
            .accessibilityLabel(localizedCloseTitle)
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroSection: some View {
        Image("DeveloperPortrait")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.7)))
            .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.7)))
    }

    private var reviewRequestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedMessageTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(localizedMessageBody)
                .font(.subheadline.weight(.regular))
                .foregroundColor(.appInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    await openAppStoreReview()
                }
            } label: {
                HStack(spacing: 8) {
                    if isOpeningReview {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "star.bubble.fill")
                    }
                    Text(localizedReviewButtonTitle)
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(buttonAccent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isOpeningReview)
        }
        .padding(16)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.75)))
    }

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedDeveloperTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)

            Text(localizedDeveloperEyebrow)
                .font(.caption.weight(.semibold))
                .foregroundColor(buttonAccent)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(localizedSimpleStoryItems, id: \.self) { item in
                    Label {
                        Text(item)
                            .font(.subheadline.weight(.regular))
                            .foregroundColor(.appInk)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(buttonAccent)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.75)))
    }

    private var nextVersionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedNextVersionTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)

            Text(localizedNextVersionBody)
                .font(.footnote.weight(.regular))
                .foregroundColor(.appMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(localizedNextVersionItems, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(buttonAccent)
                        Text(item)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(buttonAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.75)))
    }

    @MainActor
    private func openAppStoreReview() async {
        guard !isOpeningReview else { return }
        isOpeningReview = true
        defer { isOpeningReview = false }

        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            requestAppStoreReview()
            return
        }

        do {
            let result = try await fetchAppStoreReviewTarget(bundleID: bundleID)
            if let trackID = result.trackId,
               let reviewURL = URL(string: "itms-apps://itunes.apple.com/app/id\(trackID)?action=write-review") {
                await UIApplication.shared.open(reviewURL)
            } else if let appStoreURL = URL(string: result.trackViewUrl) {
                await UIApplication.shared.open(appStoreURL)
            } else {
                requestAppStoreReview()
            }
        } catch {
            requestAppStoreReview()
        }
    }

    private func fetchAppStoreReviewTarget(bundleID: String) async throws -> AppStoreLookupResult {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "JP")
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
        guard let result = response.results.first else {
            throw URLError(.cannotParseResponse)
        }
        return result
    }

    private func requestAppStoreReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    private var localizedTitle: String { localized(japanese: "レビューと開発者紹介", chinese: "评价与开发者介绍", english: "Review and Developer") }
    private var localizedSubtitle: String {
        localized(
            japanese: "Kody Chang と NIIX がこのアプリを作った理由をご紹介します。",
            chinese: "介绍 Kody Chang 与 NIIX 为什么开发这款 App。",
            english: "The story of why Kody Chang and NIIX built this app."
        )
    }
    private var localizedMessageTitle: String { localized(japanese: "よろしければ評価をお願いします", chinese: "如果你愿意，欢迎给我们评价", english: "Your Review Helps") }
    private var localizedMessageBody: String {
        localized(
            japanese: "このアプリを気に入っていただけた場合、または改善してほしい点がある場合は、App Store で評価やコメントをいただけると大きな励みになります。現場で使いやすい帳票アプリにするため、一つひとつのご意見を大切にしています。",
            chinese: "如果你喜欢我们开发的 App，或有任何希望改进的地方，欢迎到 App Store 给我们评价或留下意见。你的每一条反馈都会帮助我们把这款表单工具做得更适合实际工作现场。",
            english: "If you like this app, or if you have suggestions for improvement, an App Store review would mean a lot. Every comment helps us make this form tool better for real work."
        )
    }
    private var localizedReviewButtonTitle: String { localized(japanese: "App Storeで評価する", chinese: "到 App Store 写评论", english: "Review on the App Store") }
    private var localizedDeveloperTitle: String { localized(japanese: "開発の背景", chinese: "开发背后的故事", english: "Behind the Development") }
    private var localizedDeveloperEyebrow: String {
        localized(
            japanese: "台湾出身の開発者 Kody Chang と NIIX より",
            chinese: "来自台湾的开发者 Kody Chang 与 NIIX",
            english: "From Kody Chang of Taiwan and NIIX"
        )
    }
    private var localizedCloseTitle: String { localized(japanese: "閉じる", chinese: "关闭", english: "Close") }
    private var localizedSimpleStoryItems: [String] {
        [
            localized(
                japanese: "この App は、見積書、請求書、領収書、現場写真、PDF が分散してしまう日々の困りごとから生まれました。",
                chinese: "这款 App 来自实际工作里的小麻烦：报价单、请款书、收据、现场照片、PDF 经常分散在不同地方。",
                english: "This app started from everyday friction: quotes, invoices, receipts, site photos, and PDFs scattered across different places."
            ),
            localized(
                japanese: "大きな業務システムではなく、忙しい日でも迷わず使える帳票ツールを目指しています。",
                chinese: "我们不是想做复杂的大系统，而是想做一个忙碌时也能顺手完成工作的表单工具。",
                english: "The goal is not a large business system, but a form tool that stays easy to use on a busy day."
            ),
            localized(
                japanese: "App Store のレビューは、次に直す場所や追加する機能を決める大切な参考になります。",
                chinese: "App Store 的评价会帮助我们决定下一版该修哪里、增加什么功能。",
                english: "App Store reviews help decide what to fix and what to improve next."
            )
        ]
    }
    private var localizedNextVersionTitle: String {
        localized(japanese: "次のバージョンで育てたいこと", chinese: "下一版想继续改进", english: "What We Want to Improve Next")
    }
    private var localizedNextVersionBody: String {
        localized(
            japanese: "いただいたレビューは、開発メモではなく実際の優先順位として扱います。",
            chinese: "收到的评价不会只是开发笔记，而会成为真实的改进优先级。",
            english: "Reviews are treated as real product priorities, not just development notes."
        )
    }
    private var localizedNextVersionItems: [String] {
        [
            localized(japanese: "写真と PDF の整理をもっと速く", chinese: "让照片与 PDF 整理更快", english: "Faster photo and PDF organization"),
            localized(japanese: "現場入力をさらに迷わない形に", chinese: "让现场输入更不容易迷路", english: "Clearer on-site input flows"),
            localized(japanese: "帳票テンプレートと共有の改善", chinese: "改善表单模板与分享体验", english: "Better templates and sharing")
        ]
    }
    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct DSASettingsScreen: View {
    let language: AppLanguage
    @Binding var dsaInfoVisible: Bool
    @Binding var dsaTraderStatus: String
    @Binding var dsaLegalName: String
    @Binding var dsaContactEmail: String
    @Binding var dsaContactAddress: String
    @Binding var dsaPrivacyPolicyURL: String
    @Binding var dsaSupportURL: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        NavigationView {
            ManagementScroll(title: localizedTitle, subtitle: localizedSubtitle) {
                SectionCard(title: localizedPreviewTitle, titleWeight: .regular) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(spacing: 0) {
                            BackupStatusRow(title: localizedTraderStatusTitle, value: localizedSelectedTraderStatus, systemImage: "person.text.rectangle", tint: buttonAccent)
                            BackupStatusRow(title: localizedLegalNameTitle, value: dsaLegalName, systemImage: "building.2.fill", tint: buttonAccent)
                            BackupStatusRow(title: localizedEmailTitle, value: dsaContactEmail, systemImage: "envelope.fill", tint: buttonAccent)
                            BackupStatusRow(title: localizedAddressTitle, value: effectiveDSAContactAddress, systemImage: "mappin.and.ellipse", tint: buttonAccent)
                        }
                        .background(Color.appInputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        FormField(title: localizedPrivacyPolicyTitle) {
                            linkValue(dsaPrivacyPolicyURL, placeholder: "https://niix.jp/shokopolicy", systemImage: "lock.shield.fill")
                        }
                        FormField(title: localizedSupportURLTitle) {
                            linkValue(dsaSupportURL, placeholder: "https://niix.jp", systemImage: "safari.fill")
                        }
                    }
                }
            }
            .navigationTitle(localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                dsaInfoVisible = true
                dsaTraderStatus = "trader"
                if dsaContactAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    dsaContactAddress = defaultDSAContactAddress
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedDoneTitle) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var localizedTitle: String { localized(japanese: "DSA 対応情報", chinese: "DSA 合规信息", english: "DSA Compliance Information") }
    private var localizedSubtitle: String {
        localized(
            japanese: "EU の Digital Services Act に関連する App 内表示情報を管理します。",
            chinese: "管理与欧盟 Digital Services Act 相关的 App 内显示信息。",
            english: "Manage in-app information related to the EU Digital Services Act."
        )
    }
    private var localizedTraderStatusTitle: String { localized(japanese: "事業者区分", chinese: "经营者状态", english: "Trader Status") }
    private var localizedTraderOptionTitle: String { localized(japanese: "Trader", chinese: "Trader / 经营者", english: "Trader") }
    private var localizedSelectedTraderStatus: String {
        localizedTraderOptionTitle
    }
    private var localizedContactTitle: String { localized(japanese: "連絡先情報", chinese: "联系信息", english: "Contact Information") }
    private var localizedLegalNameTitle: String { localized(japanese: "事業者名", chinese: "经营者名称", english: "Legal Name") }
    private var localizedEmailTitle: String { localized(japanese: "連絡先メール", chinese: "联系邮箱", english: "Contact Email") }
    private var localizedAddressTitle: String { localized(japanese: "連絡先住所", chinese: "联系地址", english: "Contact Address") }
    private var localizedPrivacyPolicyTitle: String { localized(japanese: "プライバシーポリシー", chinese: "隐私政策", english: "Privacy Policy") }
    private var localizedSupportURLTitle: String { localized(japanese: "サポート URL", chinese: "支持 URL", english: "Support URL") }
    private var localizedPreviewTitle: String { localizedContactTitle }
    private var localizedDoneTitle: String { localized(japanese: "完了", chinese: "完成", english: "Done") }
    private var effectiveDSAContactAddress: String {
        let trimmedAddress = dsaContactAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedAddress.isEmpty ? defaultDSAContactAddress : dsaContactAddress
    }

    @ViewBuilder
    private func linkValue(_ value: String, placeholder: String, systemImage: String) -> some View {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText = trimmedValue.isEmpty ? placeholder : trimmedValue
        if let url = URL(string: displayText), !displayText.isEmpty {
            Link(destination: url) {
                linkValueLabel(displayText, systemImage: systemImage, isEnabled: true)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            linkValueLabel(displayText, systemImage: systemImage, isEnabled: false)
        }
    }

    private func linkValueLabel(_ value: String, systemImage: String, isEnabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isEnabled ? buttonAccent : .appMuted)
            Text(value)
                .font(.body.weight(.regular))
                .foregroundColor(isEnabled ? buttonAccent : .appMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
            Spacer(minLength: 8)
            if isEnabled {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(buttonAccent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct LegalLinkButtonContent: View {
    let title: String
    let systemImage: String
    let trailingSystemImage: String
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(buttonAccent)
                .frame(width: 26, height: 26)
                .background(buttonAccent.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)

            Spacer(minLength: 8)

            Image(systemName: trailingSystemImage)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appMuted)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

struct CloudBackupPackageSelectionSheet: View {
    let title: String
    let subtitle: String
    let emptyText: String
    let storageWarningText: String
    let deleteHelpText: String
    let syncTitle: String
    let refreshTitle: String
    let cancelTitle: String
    let files: [GoogleDriveCloudBackupFile]
    @Binding var selectedFileIDs: Set<String>
    let dateText: (GoogleDriveCloudBackupFile) -> String
    let sizeText: (GoogleDriveCloudBackupFile) -> String
    let onRefresh: () -> Void
    let onSync: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)

                BackupStatusMessage(text: storageWarningText)
                BackupStatusMessage(text: deleteHelpText)

                if files.isEmpty {
                    EmptyManagementText(text: emptyText)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(files) { file in
                                CloudBackupPackageRow(
                                    file: file,
                                    isSelected: selectedFileIDs.contains(file.fileId),
                                    dateText: dateText(file),
                                    sizeText: sizeText(file)
                                ) {
                                    toggle(file)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button(action: onSync) {
                    Label(syncTitle, systemImage: "icloud.and.arrow.down.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(selectedFileIDs.isEmpty ? Color.appMuted.opacity(0.35) : buttonAccent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(selectedFileIDs.isEmpty)
            }
            .padding(18)
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(refreshTitle) {
                        onRefresh()
                    }
                }
            }
        }
    }

    private func toggle(_ file: GoogleDriveCloudBackupFile) {
        if selectedFileIDs.contains(file.fileId) {
            selectedFileIDs.remove(file.fileId)
        } else {
            selectedFileIDs.insert(file.fileId)
        }
    }
}

private struct CloudBackupPackageRow: View {
    let file: GoogleDriveCloudBackupFile
    let isSelected: Bool
    let dateText: String
    let sizeText: String
    let action: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(isSelected ? buttonAccent : .appMuted)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    HStack(spacing: 8) {
                        if !dateText.isEmpty {
                            Label(dateText, systemImage: "calendar")
                        }
                        if !sizeText.isEmpty {
                            Label(sizeText, systemImage: "externaldrive")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(isSelected ? buttonAccent.opacity(0.10) : Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isSelected ? buttonAccent : Color.appDivider))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompanyManagementScreen: View {
    @ObservedObject var store: DocumentStore
    let onBack: () -> Void
    var onAppliedToForm: (() -> Void)? = nil
    @State private var issuerName = ""
    @State private var issuerRegistration = ""
    @State private var issuerContact = ""
    @State private var issuerPhone = ""
    @State private var issuerEmail = ""
    @State private var issuerAddress = ""
    @State private var editingIssuerID: IssuerProfile.ID?
    @State private var isIssuerEditorPresented = false
    @State private var applyToastText = ""
    @State private var isApplyToastVisible = false
    @State private var applyToastID = UUID()
    private var language: AppLanguage { store.interfaceLanguage }

    var body: some View {
        ManagementScroll(
            title: localizedTitle,
            subtitle: localizedSubtitle,
            onBack: onBack,
            actionTitle: localizedAddTitle,
            actionSystemImage: "plus",
            action: presentNewIssuer
        ) {
            SectionCard(title: localizedListTitle, titleWeight: .regular) {
                if store.issuers.isEmpty {
                    EmptyManagementText(text: localizedEmptyText)
                } else {
                    VStack(spacing: 14) {
                        ForEach(store.issuers) { issuer in
                            CompanyProfileRow(issuer: issuer, language: language) {
                                applyIssuer(issuer)
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
        .overlay(alignment: .bottom) {
            if isApplyToastVisible {
                ManagementApplyToast(text: applyToastText)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 92)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isIssuerEditorPresented) {
            NavigationView {
                ScrollView {
                    issuerEditorForm
                        .padding(18)
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
                .navigationTitle(editingIssuerID == nil ? localizedNewNavigationTitle : localizedEditNavigationTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizedCancelTitle) {
                            dismissIssuerEditor()
                        }
                    }
                }
            }
        }
    }

    private var issuerEditorForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 12) {
                FormField(title: localizedCompanyNameTitle) {
                    TextField("", text: $issuerName, prompt: .inputPrompt(localizedCompanyNameTitle))
                        .textFieldStyle(PlainTextFieldStyle())
                        .flatFormInput()
                }
                HStack(alignment: .top, spacing: 12) {
                    FormField(title: localizedRegistrationTitle) {
                        TextField("", text: $issuerRegistration, prompt: .inputPrompt("T1234567890123"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    FormField(title: localizedContactTitle) {
                        TextField("", text: $issuerContact, prompt: .inputPrompt(localizedContactPlaceholder))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    FormField(title: localizedPhoneTitle) {
                        TextField("", text: $issuerPhone, prompt: .inputPrompt(localizedPhoneTitle))
                            .keyboardType(.phonePad)
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    FormField(title: localizedEmailTitle) {
                        TextField("", text: $issuerEmail, prompt: .inputPrompt(localizedEmailTitle))
                            .keyboardType(.emailAddress)
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                }
                FormField(title: localizedAddressTitle) {
                    MultilineTextInput(text: $issuerAddress)
                        .multilineFormInput(minHeight: 92)
                }
            }

            ManagementPrimaryButton(title: editingIssuerID == nil ? localizedSaveTitle : localizedUpdateTitle, systemImage: editingIssuerID == nil ? "plus.circle.fill" : "checkmark.circle.fill") {
                saveIssuerForm()
            }
            .disabled(!isIssuerFormValid)
            .opacity(isIssuerFormValid ? 1 : 0.45)
        }
    }

    private var isIssuerFormValid: Bool {
        !issuerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func presentNewIssuer() {
        resetIssuerFormFields()
        isIssuerEditorPresented = true
    }

    private func applyIssuer(_ issuer: IssuerProfile) {
        store.useDefaultIssuer(issuer)
        showApplyToast(for: issuer.name)
        onAppliedToForm?()
    }

    private func showApplyToast(for name: String) {
        let toastID = UUID()
        applyToastID = toastID
        applyToastText = localizedAppliedMessage(name: name)
        withAnimation(.easeOut(duration: 0.16)) {
            isApplyToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard applyToastID == toastID else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                isApplyToastVisible = false
            }
        }
    }

    private func dismissIssuerEditor() {
        resetIssuerFormFields()
        isIssuerEditorPresented = false
    }

    private func resetIssuerFormFields() {
        issuerName = ""
        issuerRegistration = ""
        issuerContact = ""
        issuerPhone = ""
        issuerEmail = ""
        issuerAddress = ""
        editingIssuerID = nil
    }

    private func saveIssuerForm() {
        let savedIssuer: IssuerProfile?
        if let editingIssuerID {
            savedIssuer = store.updateIssuerProfile(
                id: editingIssuerID,
                name: issuerName,
                registration: issuerRegistration,
                contact: issuerContact,
                phone: issuerPhone,
                email: issuerEmail,
                address: issuerAddress
            )
        } else {
            savedIssuer = store.saveIssuerProfile(
                name: issuerName,
                registration: issuerRegistration,
                contact: issuerContact,
                phone: issuerPhone,
                email: issuerEmail,
                address: issuerAddress
            )
        }
        let issuer = savedIssuer ?? IssuerProfile(
            id: editingIssuerID ?? UUID(),
            name: issuerName,
            registration: issuerRegistration,
            contact: issuerContact,
            phone: issuerPhone,
            email: issuerEmail,
            address: issuerAddress
        )
        store.useDefaultIssuer(issuer)
        dismissIssuerEditor()
    }

    private func editIssuer(_ issuer: IssuerProfile) {
        editingIssuerID = issuer.id
        issuerName = issuer.name
        issuerRegistration = issuer.registration
        issuerContact = issuer.contact
        issuerPhone = issuer.phone
        issuerEmail = issuer.email
        issuerAddress = issuer.address
        isIssuerEditorPresented = true
    }

    private var localizedTitle: String { localized(japanese: "会社設定", chinese: "公司设置", english: "Company Settings") }
    private var localizedSubtitle: String { localized(japanese: "帳票に使う自社情報を保存し、必要な会社情報を選択します。", chinese: "保存表单使用的本公司信息，并选择需要使用的公司资料。", english: "Save company profiles used on forms and choose the company information to apply.") }
    private var localizedAddTitle: String { localized(japanese: "追加", chinese: "新增", english: "Add") }
    private var localizedListTitle: String { localized(japanese: "会社情報一覧", chinese: "公司资料列表", english: "Company Profiles") }
    private var localizedEmptyText: String { localized(japanese: "保存済みの自社情報はありません。右上の追加ボタンから登録してください。", chinese: "没有已保存的公司资料。请通过右上角的新增按钮登记。", english: "No saved company profiles. Use the add button to register one.") }
    private var localizedNewNavigationTitle: String { localized(japanese: "会社情報を追加", chinese: "新增公司资料", english: "Add Company Profile") }
    private var localizedEditNavigationTitle: String { localized(japanese: "会社情報を編集", chinese: "编辑公司资料", english: "Edit Company Profile") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedCompanyNameTitle: String { localized(japanese: "会社名", chinese: "公司名", english: "Company Name") }
    private var localizedRegistrationTitle: String { localized(japanese: "登録番号", chinese: "登记编号", english: "Registration Number") }
    private var localizedContactTitle: String { localized(japanese: "担当者", chinese: "联系人", english: "Contact") }
    private var localizedContactPlaceholder: String { localized(japanese: "担当者", chinese: "联系人", english: "Contact") }
    private var localizedPhoneTitle: String { localized(japanese: "電話", chinese: "电话", english: "Phone") }
    private var localizedEmailTitle: String { localized(japanese: "メール", chinese: "邮箱", english: "Email") }
    private var localizedAddressTitle: String { localized(japanese: "住所", chinese: "地址", english: "Address") }
    private var localizedSaveTitle: String { localized(japanese: "保存", chinese: "保存", english: "Save") }
    private var localizedUpdateTitle: String { localized(japanese: "更新", chinese: "更新", english: "Update") }

    private func localizedAppliedMessage(name: String) -> String {
        localized(
            japanese: "「\(name)」を帳票に追加しました。",
            chinese: "已将「\(name)」加入表单中。",
            english: "Added \"\(name)\" to the form."
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

struct FileManagementScreen: View {
    @ObservedObject var store: DocumentStore
    @Binding var selectedSection: AppSection
    let onBack: () -> Void
    let onPreviewDocument: (BusinessDocument) -> Void
    @State private var direction: ProjectDirection = .customer
    @State private var selectedPartnerName: String?
    @State private var selectedProjectGroupID: String?
    @State private var selectedDocumentType: DocumentType?
    @State private var copyingDocument: BusinessDocument?
    @Environment(\.appButtonAccent) private var buttonAccent
    private var language: AppLanguage { store.interfaceLanguage }

    private var partnerGroups: [FilePartnerGroup] {
        let documents = store.documents
            .filter { direction.requiredTypes.contains($0.type) }
            .sorted { $0.updatedAt > $1.updatedAt }
        let grouped = Dictionary(grouping: documents) { partnerName(for: $0) }

        return grouped.map { name, documents in
            let sortedDocuments = documents.sorted { $0.updatedAt > $1.updatedAt }
            return FilePartnerGroup(name: name, documentCount: sortedDocuments.count, updatedAt: sortedDocuments.first?.updatedAt ?? .distantPast, documents: sortedDocuments)
        }
        .sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private var selectedPartner: FilePartnerGroup? {
        guard let selectedPartnerName else { return nil }
        return partnerGroups.first { $0.name == selectedPartnerName }
    }

    private var projectGroups: [FileProjectGroup] {
        guard let selectedPartner else { return [] }
        let grouped = Dictionary(grouping: selectedPartner.documents) { $0.projectId?.uuidString ?? FileProjectGroup.unassignedID }

        return grouped.map { id, documents in
            let sortedDocuments = documents.sorted { $0.updatedAt > $1.updatedAt }
            return FileProjectGroup(
                id: id,
                name: projectArchive(for: id)?.name ?? projectName(from: sortedDocuments),
                updatedAt: sortedDocuments.first?.updatedAt ?? .distantPast,
                documents: sortedDocuments
            )
        }
        .sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private var selectedProjectGroup: FileProjectGroup? {
        guard let selectedProjectGroupID else { return nil }
        return projectGroups.first { $0.id == selectedProjectGroupID }
    }

    private var typeGroups: [FileDocumentTypeGroup] {
        guard let selectedProjectGroup else { return [] }
        return direction.requiredTypes.compactMap { type in
            let documents = selectedProjectGroup.documents.filter { $0.type == type }.sorted { $0.updatedAt > $1.updatedAt }
            return documents.isEmpty ? nil : FileDocumentTypeGroup(type: type, documents: documents)
        }
    }

    private var selectedTypeGroup: FileDocumentTypeGroup? {
        guard let selectedDocumentType else { return nil }
        return typeGroups.first { $0.type == selectedDocumentType }
    }

    private var level: FileManagementLevel {
        if selectedDocumentType != nil { return .documents }
        if selectedProjectGroupID != nil { return .types }
        if selectedPartnerName != nil { return .projects }
        return .partners
    }

    var body: some View {
        VStack(spacing: 0) {
            fileNavigationBar

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fileContent
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .dismissKeyboardOnTap()
        .onChange(of: direction) { _ in
            selectedPartnerName = nil
            selectedProjectGroupID = nil
            selectedDocumentType = nil
        }
        .sheet(item: $copyingDocument) { document in
            ProjectDocumentCopySheet(store: store, source: document) { copied in
                store.select(copied)
                selectedSection = .form
            }
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        switch level {
        case .partners:
            partnerListSection
        case .projects:
            projectListSection
        case .types:
            documentTypeSection
        case .documents:
            documentListSection
        }
    }

    private var fileNavigationBar: some View {
        HStack(alignment: .center, spacing: 12) {
            AppBackButton(title: localizedBackTitle, action: level == .partners ? onBack : navigateBack)

            Text(navigationTitle)
                .font(.title3.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 12)
            if level == .partners {
                directionMenu
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .center)
        .background(Color.appBackground)
    }

    private var directionMenu: some View {
        Menu {
            Button {
                direction = .customer
            } label: {
                Label(ProjectDirection.customer.localizedTitle(language), systemImage: direction == .customer ? "checkmark" : "person.crop.square")
            }
            Button {
                direction = .vendor
            } label: {
                Label(ProjectDirection.vendor.localizedTitle(language), systemImage: direction == .vendor ? "checkmark" : "building.2")
            }
        } label: {
            Image(systemName: direction == .customer ? "person.crop.square" : "building.2")
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
                .frame(width: 44, height: 44)
                .background(Color.appInputBackground)
                .clipShape(Circle())
        }
        .accessibilityLabel(Text(localizedDirectionMenuTitle))
    }

    private var partnerListSection: some View {
        SectionCard(title: localizedPartnerListTitle, titleWeight: .regular) {
            if partnerGroups.isEmpty {
                EmptyManagementText(text: localizedEmptyText)
            } else {
                VStack(spacing: 10) {
                    ForEach(partnerGroups) { group in
                        fileSelectionButton(title: group.name, subtitle: localizedPartnerSubtitle(group), systemImage: direction == .customer ? "person.crop.square" : "building.2") {
                            selectedPartnerName = group.name
                            selectedProjectGroupID = nil
                            selectedDocumentType = nil
                        }
                    }
                }
            }
        }
    }

    private var projectListSection: some View {
        SectionCard(title: localizedProjectListTitle, titleWeight: .regular) {
            if projectGroups.isEmpty {
                EmptyManagementText(text: localizedNoProjectsText)
            } else {
                VStack(spacing: 10) {
                    ForEach(projectGroups) { group in
                        fileSelectionButton(title: group.name, subtitle: localizedProjectSubtitle(group), systemImage: "folder") {
                            selectedProjectGroupID = group.id
                            selectedDocumentType = nil
                        }
                    }
                }
            }
        }
    }

    private var documentTypeSection: some View {
        SectionCard(title: localizedTypeListTitle, titleWeight: .regular) {
            if typeGroups.isEmpty {
                EmptyManagementText(text: localizedNoTypeText)
            } else {
                VStack(spacing: 10) {
                    ForEach(typeGroups) { group in
                        fileSelectionButton(title: group.type.localizedTitle(language), subtitle: localizedTypeSubtitle(group), systemImage: group.type.isAttachmentRecord ? "paperclip" : "doc.text") {
                            selectedDocumentType = group.type
                        }
                    }
                }
            }
        }
    }

    private var documentListSection: some View {
        SectionCard(title: selectedTypeGroup?.type.localizedTitle(language) ?? localizedDocumentListTitle, titleWeight: .regular) {
            if let selectedTypeGroup {
                VStack(spacing: 10) {
                    ForEach(selectedTypeGroup.documents) { document in
                        documentRow(document)
                    }
                }
            } else {
                EmptyManagementText(text: localizedNoDocumentsText)
            }
        }
    }

    private func documentRow(_ document: BusinessDocument) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.number.isEmpty ? document.type.localizedTitle(language) : document.number)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(documentSummary(document))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(2)
            }
            Spacer()

            Button {
                onPreviewDocument(document)
            } label: {
                Image(systemName: "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 40, height: 40)
                    .background(buttonAccent.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(localizedPreviewDocumentTitle)

            Button {
                store.select(document)
                selectedSection = .form
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 40, height: 40)
                    .background(buttonAccent.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(localizedEditDocumentTitle)

            Button {
                copyingDocument = document
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 40, height: 40)
                    .background(buttonAccent.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(localizedCopyDocumentTitle)
        }
        .padding(12)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }

    private func fileSelectionButton(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 44, height: 44)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(2)
                    Text(subtitle)
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
            .background(Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func navigateBack() {
        switch level {
        case .documents:
            selectedDocumentType = nil
        case .types:
            selectedProjectGroupID = nil
        case .projects:
            selectedPartnerName = nil
        case .partners:
            break
        }
    }

    private var navigationTitle: String {
        switch level {
        case .partners:
            return localizedTitle
        case .projects:
            return selectedPartner?.name ?? localizedProjectListTitle
        case .types:
            return selectedProjectGroup?.name ?? localizedTypeListTitle
        case .documents:
            return selectedTypeGroup?.type.localizedTitle(language) ?? localizedDocumentListTitle
        }
    }

    private func projectArchive(for id: String) -> ProjectArchive? {
        guard id != FileProjectGroup.unassignedID,
              let uuid = UUID(uuidString: id) else { return nil }
        return store.projects.first { $0.id == uuid }
    }

    private func projectName(from documents: [BusinessDocument]) -> String {
        documents.lazy.compactMap { $0.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? localizedUnassignedProjectTitle
    }

    private func partnerName(for document: BusinessDocument) -> String {
        let name = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? localizedNoPartnerName : name
    }

    private func localizedPartnerSubtitle(_ group: FilePartnerGroup) -> String {
        let projectCount = Set(group.documents.map { $0.projectId?.uuidString ?? FileProjectGroup.unassignedID }).count
        switch language {
        case .japanese: return "\(localizedCount(group.documentCount)) / \(projectCount) プロジェクト"
        case .simplifiedChinese: return "\(localizedCount(group.documentCount)) / \(projectCount) 个项目"
        case .english: return "\(localizedCount(group.documentCount)) / \(projectCount) projects"
        }
    }

    private func localizedProjectSubtitle(_ group: FileProjectGroup) -> String {
        let typeCount = Set(group.documents.map(\.type)).count
        switch language {
        case .japanese: return "\(localizedCount(group.documents.count)) / \(typeCount) 種類 / \(AppFormatters.shortDate(group.updatedAt))"
        case .simplifiedChinese: return "\(localizedCount(group.documents.count)) / \(typeCount) 个类别 / \(AppFormatters.shortDate(group.updatedAt))"
        case .english: return "\(localizedCount(group.documents.count)) / \(typeCount) types / \(AppFormatters.shortDate(group.updatedAt))"
        }
    }

    private func localizedTypeSubtitle(_ group: FileDocumentTypeGroup) -> String {
        switch language {
        case .japanese: return "\(localizedCount(group.documents.count)) / 新しい順"
        case .simplifiedChinese: return "\(localizedCount(group.documents.count)) / 新到旧"
        case .english: return "\(localizedCount(group.documents.count)) / newest first"
        }
    }

    private func localizedCount(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件"
        case .simplifiedChinese: return "\(count) 笔"
        case .english: return "\(count) forms"
        }
    }

    private func documentSummary(_ document: BusinessDocument) -> String {
        let date = AppFormatters.shortDate(document.updatedAt)
        let issueDate = AppFormatters.shortDate(document.issueDate)
        if document.type.isAttachmentRecord {
            let fileCount = (document.orderAttachments?.count ?? 0) + (document.paymentProofAttachments?.count ?? 0)
            switch language {
            case .japanese: return "\(date) 更新 / 発行 \(issueDate) / \(fileCount) ファイル"
            case .simplifiedChinese: return "\(date) 更新 / 开具 \(issueDate) / \(fileCount) 个文件"
            case .english: return "Updated \(date) / issued \(issueDate) / \(fileCount) files"
            }
        }
        switch language {
        case .japanese: return "\(date) 更新 / 発行 \(issueDate) / \(AppFormatters.yen(document.total, language: language))"
        case .simplifiedChinese: return "\(date) 更新 / 开具 \(issueDate) / \(AppFormatters.yen(document.total, language: language))"
        case .english: return "Updated \(date) / issued \(issueDate) / \(AppFormatters.yen(document.total, language: language))"
        }
    }

    private var localizedTitle: String { localized(japanese: "ファイル管理", chinese: "文件管理", english: "File Management") }
    private var localizedDirectionMenuTitle: String { localized(japanese: "顧客・仕入先を選択", chinese: "选择客户或供应商", english: "Choose customer or vendor") }
    private var localizedPartnerListTitle: String { direction == .customer ? localized(japanese: "顧客", chinese: "客户", english: "Customers") : localized(japanese: "仕入先", chinese: "供应商", english: "Vendors") }
    private var localizedProjectListTitle: String { localized(japanese: "プロジェクト", chinese: "项目", english: "Projects") }
    private var localizedTypeListTitle: String { localized(japanese: "帳票類別", chinese: "表单类别", english: "Form Types") }
    private var localizedDocumentListTitle: String { localized(japanese: "帳票一覧", chinese: "表单列表", english: "Forms") }
    private var localizedEmptyText: String { localized(japanese: "この区分の帳票はまだありません。", chinese: "这个区分还没有表单。", english: "No forms in this category yet.") }
    private var localizedNoProjectsText: String { localized(japanese: "プロジェクトがありません。", chinese: "没有项目。", english: "No projects.") }
    private var localizedNoTypeText: String { localized(japanese: "帳票類別がありません。", chinese: "没有表单类别。", english: "No form types.") }
    private var localizedNoDocumentsText: String { localized(japanese: "帳票がありません。", chinese: "没有表单。", english: "No forms.") }
    private var localizedNoPartnerName: String { localized(japanese: "取引先未入力", chinese: "未填写客户/供应商", english: "No customer/vendor") }
    private var localizedUnassignedProjectTitle: String { localized(japanese: "プロジェクト未指定", chinese: "未指定项目", english: "No Project") }
    private var localizedBackTitle: String { localized(japanese: "戻る", chinese: "返回", english: "Back") }
    private var localizedPreviewDocumentTitle: String { localized(japanese: "プレビュー", chinese: "预览", english: "Preview") }
    private var localizedEditDocumentTitle: String { localized(japanese: "編集", chinese: "编辑", english: "Edit") }
    private var localizedCopyDocumentTitle: String { localized(japanese: "プロジェクトへコピー", chinese: "复制到项目", english: "Copy to project") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private enum FileManagementLevel {
    case partners
    case projects
    case types
    case documents
}

private struct FilePartnerGroup: Identifiable {
    var id: String { name }
    let name: String
    let documentCount: Int
    let updatedAt: Date
    let documents: [BusinessDocument]
}

private struct FileProjectGroup: Identifiable {
    static let unassignedID = "unassigned"
    let id: String
    let name: String
    let updatedAt: Date
    let documents: [BusinessDocument]
}

private struct FileDocumentTypeGroup: Identifiable {
    var id: String { type.rawValue }
    let type: DocumentType
    let documents: [BusinessDocument]
}

struct ProjectDocumentCopySheet: View {
    @ObservedObject var store: DocumentStore
    let source: BusinessDocument
    let onComplete: (BusinessDocument) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var pendingOverwriteProject: ProjectArchive?
    private var language: AppLanguage { store.interfaceLanguage }

    private var targetProjects: [ProjectArchive] {
        store.projects
            .filter { $0.direction.requiredTypes.contains(source.type) && $0.id != source.projectId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var sourceDirection: ProjectDirection {
        ProjectDirection.customer.requiredTypes.contains(source.type) ? .customer : .vendor
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionCard(title: localizedSourceTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(source.type.localizedTitle(language))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appInk)
                                .lineLimit(1)
                            Text(source.number.isEmpty ? localizedNoNumberText : source.number)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionCard(title: localizedTargetTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 10) {
                            if targetProjects.isEmpty {
                                EmptyManagementText(text: localizedNoTargetText)
                            } else {
                                ForEach(targetProjects) { project in
                                    targetProjectRow(project)
                                }
                            }

                            Button {
                                createProjectAndCopy()
                            } label: {
                                Label(localizedCreateProjectTitle, systemImage: "folder.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CompanyMiniButtonStyle())
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedCancelTitle) {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            localizedOverwriteConfirmTitle,
            isPresented: Binding(
                get: { pendingOverwriteProject != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingOverwriteProject = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(localizedOverwriteTitle, role: .destructive) {
                if let project = pendingOverwriteProject {
                    performCopy(to: project, mode: .overwrite)
                }
                pendingOverwriteProject = nil
            }
            Button(localizedCancelTitle, role: .cancel) {
                pendingOverwriteProject = nil
            }
        } message: {
            Text(localizedOverwriteConfirmMessage)
        }
    }

    private func targetProjectRow(_ project: ProjectArchive) -> some View {
        let hasExisting = project.document(for: source.type) != nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: project.direction == .customer ? "person.crop.square" : "building.2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 44, height: 44)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(projectSubtitle(project, hasExisting: hasExisting))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                }
                Spacer()
            }

            if hasExisting {
                HStack(spacing: 8) {
                    Button {
                        pendingOverwriteProject = project
                    } label: {
                        Label(localizedOverwriteTitle, systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyMiniButtonStyle(tint: .red))

                    Button {
                        performCopy(to: project, mode: .append)
                    } label: {
                        Label(localizedAppendTitle, systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyMiniButtonStyle())
                }
            } else {
                Button {
                    performCopy(to: project, mode: .append)
                } label: {
                    Label(localizedCopyHereTitle, systemImage: "plus.square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CompanyMiniButtonStyle())
            }
        }
        .padding(12)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(hasExisting ? buttonAccent.opacity(0.35) : Color.appDivider))
        .cornerRadius(8)
    }

    private func performCopy(to project: ProjectArchive, mode: ProjectDocumentCopyMode) {
        let copied = store.copyDocument(source, to: project, mode: mode)
        onComplete(copied)
        dismiss()
    }

    private func createProjectAndCopy() {
        let project = newProjectFromSource()
        performCopy(to: project, mode: .append)
    }

    private func newProjectFromSource() -> ProjectArchive {
        let cleanCustomerName = source.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = cleanCustomerName.isEmpty ? "\(sourceDirection.title) \(AppFormatters.shortDate(Date()))" : "\(AppFormatters.shortDate(Date())) \(cleanCustomerName)"
        return ProjectArchive(
            id: UUID(),
            name: projectName,
            direction: sourceDirection,
            customerName: cleanCustomerName,
            updatedAt: Date(),
            documents: []
        )
    }

    private func projectSubtitle(_ project: ProjectArchive, hasExisting: Bool) -> String {
        let status = hasExisting ? localizedHasExistingText : localizedNoExistingText
        switch language {
        case .japanese: return "\(project.direction.localizedTitle(language)) / \(status)"
        case .simplifiedChinese: return "\(project.direction.localizedTitle(language)) / \(status)"
        case .english: return "\(project.direction.localizedTitle(language)) / \(status)"
        }
    }

    private var localizedTitle: String { localized(japanese: "プロジェクトへコピー", chinese: "复制到项目", english: "Copy to Project") }
    private var localizedSourceTitle: String { localized(japanese: "コピー元", chinese: "复制来源", english: "Source") }
    private var localizedTargetTitle: String { localized(japanese: "コピー先プロジェクト", chinese: "复制到哪个项目", english: "Target Project") }
    private var localizedNoNumberText: String { localized(japanese: "番号未入力", chinese: "未填写编号", english: "No number") }
    private var localizedNoTargetText: String { localized(japanese: "コピーできる他のプロジェクトがありません。新しいプロジェクトを作成できます。", chinese: "没有可复制到的其他项目。可以建立新项目。", english: "No other compatible project is available. You can create a new project.") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedOverwriteTitle: String { localized(japanese: "上書き", chinese: "覆盖", english: "Overwrite") }
    private var localizedAppendTitle: String { localized(japanese: "追加", chinese: "增加", english: "Add") }
    private var localizedCopyHereTitle: String { localized(japanese: "ここへコピー", chinese: "复制到这里", english: "Copy Here") }
    private var localizedCreateProjectTitle: String { localized(japanese: "新しいプロジェクトを作成してコピー", chinese: "建立新项目并复制", english: "Create Project and Copy") }
    private var localizedHasExistingText: String { localized(japanese: "同じ帳票あり", chinese: "已有同类表单", english: "Same form exists") }
    private var localizedNoExistingText: String { localized(japanese: "同じ帳票なし", chinese: "没有同类表单", english: "No same form") }
    private var localizedOverwriteConfirmTitle: String {
        localized(japanese: "この帳票を上書きしますか？", chinese: "要覆盖这个表单吗？", english: "Overwrite this form?")
    }
    private var localizedOverwriteConfirmMessage: String {
        let projectName = pendingOverwriteProject?.name ?? ""
        let typeName = source.type.localizedTitle(language)
        switch language {
        case .japanese:
            return "\(projectName) の既存の \(typeName) を上書きします。この操作は取り消せません。"
        case .simplifiedChinese:
            return "将覆盖 \(projectName) 里现有的 \(typeName)。此操作无法撤销。"
        case .english:
            return "This will overwrite the existing \(typeName) in \(projectName). This cannot be undone."
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

@available(iOS 16.0, *)
private struct StampManagementSection: View {
    let language: AppLanguage
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var selectedItem: PhotosPickerItem?
    @State private var stampImage = StampLibrary.defaultStampImage
    @State private var statusText = ""

    var body: some View {
        SectionCard(title: localizedStampTitle, titleWeight: .regular) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Color.appInputBackground
                        if let stampImage {
                            Image(uiImage: StampImageProcessor.process(stampImage, options: StampImageProcessor.Options()))
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        } else {
                            Image(systemName: "seal")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.appMuted)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(stampImage == nil ? localizedStampMissingText : localizedStampSavedText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appInk)
                        Text(localizedStampDescription)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(localizedUploadTitle, systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyFilledButtonStyle())

                    Button {
                        StampLibrary.deleteDefaultStamp()
                        StampLibrary.deleteDefaultStampSettings()
                        stampImage = nil
                        statusText = localizedStampDeletedStatus
                    } label: {
                        Label(localizedDeleteTitle, systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyOutlineButtonStyle())
                    .disabled(stampImage == nil)
                    .opacity(stampImage == nil ? 0.45 : 1)
                }

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
            }
        }
        .task(id: selectedItem) {
            await loadSelectedStamp()
        }
    }

    private func loadSelectedStamp() async {
        guard let selectedItem else { return }
        do {
            if let data = try await selectedItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    StampLibrary.saveDefaultStamp(image)
                    stampImage = image
                    statusText = localizedStampSavedStatus
                }
            }
        } catch {
            await MainActor.run {
                statusText = localizedStampLoadFailedStatus
            }
        }
    }

    private var localizedStampTitle: String { localized(japanese: "印章管理", chinese: "印章管理", english: "Stamp Management") }
    private var localizedStampMissingText: String { localized(japanese: "デフォルト印章未設定", chinese: "未设置默认印章", english: "Default stamp not set") }
    private var localizedStampSavedText: String { localized(japanese: "デフォルト印章を保存済み", chinese: "已保存默认印章", english: "Default stamp saved") }
    private var localizedStampDescription: String { localized(japanese: "PDFプレビューの押印画面で初期画像として使用します。", chinese: "将在 PDF 预览的盖章画面中作为初始图片使用。", english: "Used as the initial image on the PDF preview stamp screen.") }
    private var localizedUploadTitle: String { localized(japanese: "写真からアップロード", chinese: "从相册上传", english: "Upload from Photos") }
    private var localizedDeleteTitle: String { localized(japanese: "削除", chinese: "删除", english: "Delete") }
    private var localizedStampDeletedStatus: String { localized(japanese: "印章を削除しました。", chinese: "已删除印章。", english: "Stamp deleted.") }
    private var localizedStampSavedStatus: String { localized(japanese: "印章を保存しました。", chinese: "已保存印章。", english: "Stamp saved.") }
    private var localizedStampLoadFailedStatus: String { localized(japanese: "印章を読み込めませんでした。", chinese: "无法读取印章。", english: "Could not load the stamp.") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

struct ProjectManagementScreen: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchaseService: PurchaseService
    @Binding var selectedSection: AppSection
    @Binding var focusedProjectID: ProjectArchive.ID?
    let onBack: () -> Void
    @State private var direction: ProjectDirection = .customer
    @State private var projectFilter: ProjectDirectionFilter = .all
    @State private var companyFilter = ""
    @State private var selectedCustomerID: CustomerProfile.ID?
    @State private var isDeleteConfirmationPresented = false
    @State private var pendingDeleteProject: ProjectArchive?
    @State private var editingProject: ProjectArchive?
    @State private var copyingDocument: BusinessDocument?
    @State private var pendingCreatedProject: ProjectArchive?
    @State private var isProjectCreatorPresented = false
    @State private var highlightedProjectID: ProjectArchive.ID?
    private var language: AppLanguage { store.interfaceLanguage }

    private var selectedCustomer: CustomerProfile? {
        guard let selectedCustomerID else { return nil }
        return store.customers.first { $0.id == selectedCustomerID }
    }

    private var filteredProjects: [ProjectArchive] {
        let cleanCompanyFilter = companyFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.projects.filter { project in
            let matchesDirection = projectFilter.direction.map { project.direction == $0 } ?? true
            let matchesCompany = cleanCompanyFilter.isEmpty ||
                project.customerName.localizedCaseInsensitiveContains(cleanCompanyFilter) ||
                project.name.localizedCaseInsensitiveContains(cleanCompanyFilter)
            return matchesDirection && matchesCompany
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ManagementScroll(
                title: localizedProjectManagementTitle,
                subtitle: localizedProjectManagementSubtitle,
                onBack: onBack,
                actionTitle: localizedAddTitle,
                actionSystemImage: "plus",
                action: {
                    isProjectCreatorPresented = true
                }
            ) {
                SectionCard(title: localizedProjectListTitle, titleWeight: .regular) {
                    if store.projects.isEmpty {
                        EmptyManagementText(text: localizedEmptyProjectsText)
                    } else {
                        VStack(spacing: 14) {
                            Picker(localizedProjectCategoryTitle, selection: $projectFilter) {
                                ForEach(ProjectDirectionFilter.allCases) { filter in
                                    Text(filter.localizedTitle(language)).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.appMuted)
                                TextField("", text: $companyFilter, prompt: .inputPrompt(localizedCompanySearchPlaceholder))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(.appInk)
                                if !companyFilter.isEmpty {
                                    Button {
                                        companyFilter = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.appMuted)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color.appInputBackground)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))

                            if filteredProjects.isEmpty {
                                EmptyManagementText(text: localizedNoMatchingProjectsText)
                            } else {
                                ForEach(filteredProjects) { project in
                                    ProjectArchiveRow(project: project, language: language, isHighlighted: highlightedProjectID == project.id) { type in
                                        store.openProjectForm(project: project, type: type)
                                        selectedSection = .form
                                    } onOpenOrderRecord: { document in
                                        store.select(document)
                                        selectedSection = .form
                                    } onNewOrderRecord: {
                                        store.createAdditionalCustomerOrder(project: project)
                                        selectedSection = .form
                                    } onCopyDocument: { document in
                                        copyingDocument = document
                                    } onSettings: {
                                        editingProject = project
                                    } onDelete: {
                                        pendingDeleteProject = project
                                        isDeleteConfirmationPresented = true
                                    }
                                    .id(project.id)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                focusProjectIfNeeded(using: scrollProxy)
            }
            .onChange(of: focusedProjectID) { _ in
                focusProjectIfNeeded(using: scrollProxy)
            }
        }
        .confirmationDialog(localizedDeleteProjectTitle, isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button(localizedDeleteTitle, role: .destructive) {
                if let pendingDeleteProject {
                    store.deleteProject(pendingDeleteProject)
                }
                pendingDeleteProject = nil
            }
            Button(localizedCancelTitle, role: .cancel) {
                pendingDeleteProject = nil
            }
        } message: {
            Text(localizedDeleteProjectMessage)
        }
        .sheet(item: $editingProject) { project in
            ProjectSettingsSheet(store: store, project: project)
        }
        .sheet(item: $copyingDocument) { document in
            ProjectDocumentCopySheet(store: store, source: document) { copied in
                store.select(copied)
                selectedSection = .form
            }
        }
        .sheet(item: $pendingCreatedProject) { project in
            ProjectPostCreateSheet(store: store, project: project, language: language) { type in
                store.openProjectForm(project: project, type: type)
                pendingCreatedProject = nil
                selectedSection = .form
            } onAssignDocument: { document in
                store.assignDocument(document, to: project)
                pendingCreatedProject = nil
                selectedSection = .form
            }
        }
        .sheet(isPresented: $isProjectCreatorPresented) {
            NavigationView {
                ScrollView {
                    projectCreatorForm
                        .padding(18)
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
                .navigationTitle(localizedNewProjectTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizedCancelTitle) {
                            isProjectCreatorPresented = false
                        }
                    }
                }
            }
        }
    }

    private var projectCreatorForm: some View {
        VStack(spacing: 14) {
            Picker(localizedProjectCategoryTitle, selection: $direction) {
                ForEach(ProjectDirection.allCases) { value in
                    Text(value.localizedTitle(language)).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Text(direction.localizedSubtitle(language))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(localizedPartnerPickerTitle, selection: $selectedCustomerID) {
                Text(localizedNoSelectionTitle).tag(nil as CustomerProfile.ID?)
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

            ManagementPrimaryButton(title: localizedCreateProjectTitle, systemImage: "folder.badge.plus") {
                pendingCreatedProject = store.makeProjectArchive(direction: direction, customer: selectedCustomer)
                isProjectCreatorPresented = false
            }
        }
    }

    private var canCreateProject: Bool { true }

    private func focusProjectIfNeeded(using scrollProxy: ScrollViewProxy) {
        guard let focusedProjectID,
              store.projects.contains(where: { $0.id == focusedProjectID }) else { return }

        projectFilter = .all
        companyFilter = ""
        highlightedProjectID = focusedProjectID

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                scrollProxy.scrollTo(focusedProjectID, anchor: .center)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if highlightedProjectID == focusedProjectID {
                withAnimation(.easeOut(duration: 0.35)) {
                    highlightedProjectID = nil
                }
            }
        }
    }

    private var localizedProjectManagementTitle: String {
        switch language {
        case .japanese: return "プロジェクト管理"
        case .simplifiedChinese: return "文件与项目管理"
        case .english: return "Files and Projects"
        }
    }

    private var localizedProjectManagementSubtitle: String {
        switch language {
        case .japanese: return "顧客書類をプロジェクトとしてまとめ、必要な帳票の進捗を確認します。"
        case .simplifiedChinese: return "将客户文件按项目汇总，并确认所需表单的进度。"
        case .english: return "Group customer documents by project and track required forms."
        }
    }

    private var localizedFreePlanTitle: String {
        switch language {
        case .japanese: return "無料版"
        case .simplifiedChinese: return "免费版"
        case .english: return "Free Plan"
        }
    }

    private var localizedFreePlanMessage: String {
        switch language {
        case .japanese: return "無料版でもプロジェクト作成と帳票管理を利用できます。ProではPDFプレビュー共有とGoogle Driveバックアップも利用できます。"
        case .simplifiedChinese: return "免费版也可使用项目创建与表单管理。Pro 可继续使用 PDF 预览分享与 Google Drive 备份。"
        case .english: return "The free plan can create projects and manage forms. Pro adds PDF preview sharing and Google Drive backup."
        }
    }

    private var localizedUpgradeTitle: String {
        switch language {
        case .japanese: return "Proで共有・バックアップを使う"
        case .simplifiedChinese: return "升级 Pro 使用分享与备份"
        case .english: return "Use Sharing and Backup with Pro"
        }
    }

    private var localizedAddTitle: String {
        switch language {
        case .japanese: return "追加"
        case .simplifiedChinese: return "新增"
        case .english: return "Add"
        }
    }

    private var localizedProjectListTitle: String {
        switch language {
        case .japanese: return "プロジェクト一覧"
        case .simplifiedChinese: return "项目列表"
        case .english: return "Projects"
        }
    }

    private var localizedEmptyProjectsText: String {
        switch language {
        case .japanese: return "保存済みのプロジェクトはありません。右上の追加ボタンからプロジェクトを作成してください。"
        case .simplifiedChinese: return "没有已保存项目。请通过右上角的新增按钮建立项目。"
        case .english: return "No saved projects. Use the add button to create one."
        }
    }

    private var localizedProjectCategoryTitle: String {
        switch language {
        case .japanese: return "プロジェクト分類"
        case .simplifiedChinese: return "项目分类"
        case .english: return "Project Category"
        }
    }

    private var localizedCompanySearchPlaceholder: String {
        switch language {
        case .japanese: return "会社名で検索"
        case .simplifiedChinese: return "按公司名搜索"
        case .english: return "Search by company"
        }
    }

    private var localizedNoMatchingProjectsText: String {
        switch language {
        case .japanese: return "条件に一致するプロジェクトはありません。"
        case .simplifiedChinese: return "没有符合条件的项目。"
        case .english: return "No projects match the filters."
        }
    }

    private var localizedDeleteProjectTitle: String {
        switch language {
        case .japanese: return "プロジェクトを削除しますか？"
        case .simplifiedChinese: return "要删除项目吗？"
        case .english: return "Delete this project?"
        }
    }

    private var localizedDeleteTitle: String {
        switch language {
        case .japanese: return "削除"
        case .simplifiedChinese: return "删除"
        case .english: return "Delete"
        }
    }

    private var localizedCancelTitle: String {
        switch language {
        case .japanese: return "キャンセル"
        case .simplifiedChinese: return "取消"
        case .english: return "Cancel"
        }
    }

    private var localizedDeleteProjectMessage: String {
        switch language {
        case .japanese: return "プロジェクト内の帳票をすべて削除します。この操作は取り消せません。"
        case .simplifiedChinese: return "项目内的所有表单都会被删除。此操作无法撤销。"
        case .english: return "All forms in this project will be deleted. This cannot be undone."
        }
    }

    private var localizedNewProjectTitle: String {
        switch language {
        case .japanese: return "新規プロジェクト"
        case .simplifiedChinese: return "新项目"
        case .english: return "New Project"
        }
    }

    private var localizedPartnerPickerTitle: String {
        switch language {
        case .japanese: return "取引先・仕入先"
        case .simplifiedChinese: return "客户/供应商"
        case .english: return "Customer or Vendor"
        }
    }

    private var localizedNoSelectionTitle: String {
        switch language {
        case .japanese: return "未選択"
        case .simplifiedChinese: return "未选择"
        case .english: return "Not selected"
        }
    }

    private var localizedCreateProjectTitle: String {
        switch language {
        case .japanese: return "プロジェクトを作成"
        case .simplifiedChinese: return "建立项目"
        case .english: return "Create Project"
        }
    }
}

private enum ProjectDirectionFilter: String, CaseIterable, Identifiable {
    case all
    case customer
    case vendor

    var id: String { rawValue }

    var title: String {
        localizedTitle(.japanese)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .all:
            switch language {
            case .japanese: return "すべて"
            case .simplifiedChinese: return "全部"
            case .english: return "All"
            }
        case .customer: return ProjectDirection.customer.localizedTitle(language)
        case .vendor: return ProjectDirection.vendor.localizedTitle(language)
        }
    }

    var direction: ProjectDirection? {
        switch self {
        case .all: return nil
        case .customer: return .customer
        case .vendor: return .vendor
        }
    }
}

private struct ProjectPostCreateSheet: View {
    @ObservedObject var store: DocumentStore
    let project: ProjectArchive
    let language: AppLanguage
    let onCreateForm: (DocumentType) -> Void
    let onAssignDocument: (BusinessDocument) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    private let previewGridColumns = [
        GridItem(.flexible(), spacing: 10, alignment: .top),
        GridItem(.flexible(), spacing: 10, alignment: .top),
        GridItem(.flexible(), spacing: 10, alignment: .top),
    ]

    private var availableDocuments: [BusinessDocument] {
        store.documents
            .filter { document in
                document.projectId == nil &&
                    project.direction.requiredTypes.contains(document.type)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionCard(title: localizedProjectTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.appInk)
                                .lineLimit(2)
                            Text(project.direction.localizedSubtitle(language))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appMuted)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.appInputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                        .cornerRadius(8)
                    }

                    SectionCard(title: localizedCreateFormTitle, titleWeight: .regular) {
                        LazyVGrid(columns: previewGridColumns, alignment: .leading, spacing: 12) {
                            ForEach(project.direction.requiredTypes) { type in
                                ProjectPostCreateTypeCard(type: type, language: language, accent: buttonAccent) {
                                    onCreateForm(type)
                                    dismiss()
                                }
                            }
                        }
                    }

                    SectionCard(title: localizedAssignExistingTitle, titleWeight: .regular) {
                        if availableDocuments.isEmpty {
                            EmptyManagementText(text: localizedNoExistingText)
                        } else {
                            LazyVGrid(columns: previewGridColumns, alignment: .leading, spacing: 12) {
                                ForEach(availableDocuments) { document in
                                    ProjectPostCreateDocumentPreviewCard(document: document, language: language) {
                                        onAssignDocument(document)
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedCancelTitle) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var localizedTitle: String {
        localized(japanese: "帳票を選択", chinese: "选择表单", english: "Choose Form")
    }

    private var localizedProjectTitle: String {
        localized(japanese: "作成したプロジェクト", chinese: "已建立的项目", english: "Created Project")
    }

    private var localizedCreateFormTitle: String {
        localized(japanese: "新しい帳票を作成", chinese: "建立新的表单", english: "Create a New Form")
    }

    private var localizedAssignExistingTitle: String {
        localized(japanese: "未所属の帳票を追加", chinese: "选取未纳入项目的表单", english: "Add an Unassigned Form")
    }

    private var localizedNoExistingText: String {
        localized(japanese: "追加できる未所属の帳票はありません。", chinese: "没有可加入项目的未归属表单。", english: "No unassigned forms can be added.")
    }

    private var localizedCancelTitle: String {
        localized(japanese: "キャンセル", chinese: "取消", english: "Cancel")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

private struct ProjectPostCreateTypeCard: View {
    let type: DocumentType
    let language: AppLanguage
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Color.white

                    VStack(alignment: .leading, spacing: 6) {
                        previewLine(width: 0.66)
                        previewLine(width: 0.90)
                        previewLine(width: 0.52)
                        HStack(spacing: 4) {
                            previewCell
                            previewCell
                            previewCell
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)

                    Image(systemName: iconName(for: type))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(accent)
                        .frame(width: 42, height: 42)
                        .background(accent.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Spacer()
                        Text(type.localizedSubtitle(language))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.appMuted)
                            .lineLimit(1)
                    }
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
                .aspectRatio(0.70, contentMode: .fit)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)

                Text(type.localizedTitle(language))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func previewLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.appDivider)
            .frame(height: 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 70 * (1 - width))
    }

    private var previewCell: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(accent.opacity(0.22))
            .frame(height: 14)
    }

    private func iconName(for type: DocumentType) -> String {
        switch type {
        case .estimate: return "doc.plaintext.fill"
        case .customerOrder: return "person.text.rectangle.fill"
        case .purchaseOrder: return "cart.fill"
        case .delivery: return "shippingbox.fill"
        case .invoice: return "doc.text.fill"
        case .receipt: return "checkmark.seal.fill"
        case .acceptance: return "tray.full.fill"
        case .customerFiles: return "folder.fill"
        case .vendorEstimate: return "doc.text.magnifyingglass"
        case .vendorReceipt: return "checkmark.rectangle.stack.fill"
        case .paymentNotice: return "yensign.circle.fill"
        }
    }
}

private struct ProjectPostCreateDocumentPreviewCard: View {
    let document: BusinessDocument
    let language: AppLanguage
    let action: () -> Void

    @State private var thumbnail: UIImage?
    @State private var didFail = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Color.white

                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if didFail {
                        VStack(spacing: 8) {
                            Image(systemName: document.type.isAttachmentRecord ? "paperclip" : "doc.text.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.appAccent)
                            Text(document.type.localizedTitle(language))
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.appInk)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding(10)
                    } else {
                        ProgressView()
                            .scaleEffect(0.75)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Spacer()
                        Text(AppFormatters.shortDate(document.updatedAt))
                            .font(.system(size: 8, weight: .semibold))
                            .lineLimit(1)
                        Text(document.number.isEmpty ? document.type.localizedTitle(language) : document.number)
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
                .aspectRatio(0.70, contentMode: .fit)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)

                Text(document.type.localizedTitle(language))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task(id: taskID) {
            loadThumbnail()
        }
    }

    private var taskID: String {
        "\(document.id.uuidString)-\(document.updatedAt.timeIntervalSince1970)-\(language.rawValue)"
    }

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        do {
            thumbnail = try DocumentPDFExporter.previewImage(for: document, language: language, scale: 1)
            didFail = false
        } catch {
            didFail = true
        }
    }
}

private struct ProjectArchiveRow: View {
    let project: ProjectArchive
    let language: AppLanguage
    var isHighlighted = false
    let onOpenForm: (DocumentType) -> Void
    let onOpenOrderRecord: (BusinessDocument) -> Void
    let onNewOrderRecord: () -> Void
    let onCopyDocument: (BusinessDocument) -> Void
    let onSettings: () -> Void
    let onDelete: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    private let documentGridColumns = [
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top),
    ]

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
                    Text(projectProgressText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .frame(width: 44, height: 44)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                }
            }

            LazyVGrid(columns: documentGridColumns, alignment: .leading, spacing: 8) {
                ForEach(project.direction.requiredTypes) { type in
                    if type == .customerOrder {
                        customerOrderProjectCard
                    } else {
                        let document = project.document(for: type)
                        HStack(alignment: .center, spacing: 6) {
                            Button {
                                onOpenForm(type)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.localizedTitle(language))
                                        .font(.caption.weight(.black))
                                        .foregroundColor(document == nil ? .appMuted : .appInk)
                                    Text(document?.number ?? localizedNotCreatedText)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(document == nil ? buttonAccent : .appMuted)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())

                            if let document {
                                Button {
                                    onCopyDocument(document)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(buttonAccent)
                                        .frame(width: 44, height: 44)
                                        .background(buttonAccent.opacity(0.10))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel(localizedCopyDocumentText)
                            }
                        }
                        .padding(10)
                        .background(document == nil ? buttonAccent.opacity(0.12) : Color.appInputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(document == nil ? buttonAccent.opacity(0.35) : Color.appDivider))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .background(isHighlighted ? buttonAccent.opacity(0.08) : Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isHighlighted ? buttonAccent : Color.appDivider, lineWidth: isHighlighted ? 2 : 1))
        .cornerRadius(8)
    }

    private var customerOrderProjectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(DocumentType.customerOrder.localizedTitle(language))
                        .font(.caption.weight(.black))
                        .foregroundColor(project.customerOrderRecords.isEmpty ? .appMuted : .appInk)
                    Text(project.customerOrderRecords.isEmpty ? localizedNotCreatedText : localizedCountText(project.customerOrderRecords.count))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(project.customerOrderRecords.isEmpty ? buttonAccent : .appMuted)
                }
                Spacer()
                Button(action: onNewOrderRecord) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(localizedAddOrderRecordText)
            }

            if project.customerOrderRecords.isEmpty {
                Button(action: onNewOrderRecord) {
                    Text(localizedTapToCreateText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                VStack(spacing: 6) {
                    ForEach(project.customerOrderRecords) { record in
                        HStack(alignment: .center, spacing: 6) {
                            Button {
                                onOpenOrderRecord(record)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.number)
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.appInk)
                                        .lineLimit(1)
                                    Text(orderRecordSummary(record))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.appMuted)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button {
                                onCopyDocument(record)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(buttonAccent)
                                    .frame(width: 44, height: 44)
                                    .background(buttonAccent.opacity(0.10))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel(localizedCopyDocumentText)
                        }
                        .padding(8)
                        .background(Color.appPanel)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appDivider))
                        .cornerRadius(7)
                    }
                }
            }
        }
        .padding(10)
        .background(project.customerOrderRecords.isEmpty ? buttonAccent.opacity(0.12) : Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(project.customerOrderRecords.isEmpty ? buttonAccent.opacity(0.35) : Color.appDivider))
        .cornerRadius(8)
    }

    private var projectProgressText: String {
        switch language {
        case .japanese: return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) 件完了"
        case .simplifiedChinese: return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) 个完成"
        case .english: return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) complete"
        }
    }

    private var localizedNotCreatedText: String {
        switch language {
        case .japanese: return "未作成"
        case .simplifiedChinese: return "未创建"
        case .english: return "Not created"
        }
    }

    private var localizedAddOrderRecordText: String {
        switch language {
        case .japanese: return "注文記録を追加"
        case .simplifiedChinese: return "新增订单记录"
        case .english: return "Add order record"
        }
    }

    private var localizedTapToCreateText: String {
        switch language {
        case .japanese: return "タップして作成"
        case .simplifiedChinese: return "点击创建"
        case .english: return "Tap to create"
        }
    }

    private var localizedCopyDocumentText: String {
        switch language {
        case .japanese: return "プロジェクトへコピー"
        case .simplifiedChinese: return "复制到项目"
        case .english: return "Copy to project"
        }
    }

    private func localizedCountText(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件"
        case .simplifiedChinese: return "\(count) 个"
        case .english: return "\(count)"
        }
    }

    private func orderRecordSummary(_ record: BusinessDocument) -> String {
        let attachmentCount = record.orderAttachments?.count ?? 0
        switch language {
        case .japanese:
            return "\(attachmentCount) ファイル / \(record.lines.count) 項目\(record.relatedNumber.isEmpty ? "" : " / \(record.relatedNumber)")"
        case .simplifiedChinese:
            return "\(attachmentCount) 个文件 / \(record.lines.count) 个品项\(record.relatedNumber.isEmpty ? "" : " / \(record.relatedNumber)")"
        case .english:
            return "\(attachmentCount) files / \(record.lines.count) items\(record.relatedNumber.isEmpty ? "" : " / \(record.relatedNumber)")"
        }
    }
}

private struct ProjectSettingsSheet: View {
    @ObservedObject var store: DocumentStore
    let project: ProjectArchive
    @Environment(\.dismiss) private var dismiss
    @State private var projectName: String
    @State private var direction: ProjectDirection
    @State private var selectedCustomerID: CustomerProfile.ID?
    @State private var isDirectionChangeConfirmationPresented = false
    private var language: AppLanguage { store.interfaceLanguage }

    init(store: DocumentStore, project: ProjectArchive) {
        self.store = store
        self.project = project
        _projectName = State(initialValue: project.name)
        _direction = State(initialValue: project.direction)
        let matchedCustomer = store.customers.first { customer in
            !project.customerName.isEmpty && customer.name.caseInsensitiveCompare(project.customerName) == .orderedSame
        }
        _selectedCustomerID = State(initialValue: matchedCustomer?.id)
    }

    private var selectedCustomer: CustomerProfile? {
        guard let selectedCustomerID else { return nil }
        return store.customers.first { $0.id == selectedCustomerID }
    }

    private var directionWillChangeForms: Bool {
        direction != project.direction
    }

    var body: some View {
        NavigationView {
            Form {
                Section(localizedProjectNameTitle) {
                    TextField(localizedProjectNameTitle, text: $projectName)
                }

                Section(localizedProjectCategoryTitle) {
                    Picker(localizedProjectCategoryTitle, selection: $direction) {
                        ForEach(ProjectDirection.allCases) { value in
                            VStack(alignment: .leading) {
                                Text(value.localizedTitle(language))
                                Text(value.localizedSubtitle(language))
                            }
                            .tag(value)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section(localizedPartnerSectionTitle) {
                    Picker(localizedPartnerPickerTitle, selection: $selectedCustomerID) {
                        Text(localizedNoSelectionTitle).tag(nil as CustomerProfile.ID?)
                        ForEach(store.customers) { customer in
                            Text(customer.name).tag(Optional(customer.id))
                        }
                    }
                }

                if directionWillChangeForms {
                    Section {
                        Label(localizedDirectionChangeWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle(localizedNavigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedCancelTitle) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedSaveTitle) {
                        save()
                    }
                }
            }
            .confirmationDialog(localizedDirectionChangeTitle, isPresented: $isDirectionChangeConfirmationPresented, titleVisibility: .visible) {
                Button(localizedSaveChangeTitle, role: .destructive) {
                    applyChanges()
                }
                Button(localizedCancelTitle, role: .cancel) {}
            } message: {
                Text(localizedDirectionChangeMessage)
            }
        }
    }

    private func save() {
        if directionWillChangeForms {
            isDirectionChangeConfirmationPresented = true
        } else {
            applyChanges()
        }
    }

    private func applyChanges() {
        store.updateProject(project: project, name: projectName, direction: direction, customer: selectedCustomer)
        dismiss()
    }

    private var localizedProjectNameTitle: String { localized(japanese: "プロジェクト名", chinese: "项目名称", english: "Project Name") }
    private var localizedProjectCategoryTitle: String { localized(japanese: "プロジェクト分類", chinese: "项目分类", english: "Project Category") }
    private var localizedPartnerSectionTitle: String { localized(japanese: "取引先・仕入先", chinese: "客户/供应商", english: "Customer or Vendor") }
    private var localizedPartnerPickerTitle: String { localized(japanese: "取引先・仕入先", chinese: "客户/供应商", english: "Customer or Vendor") }
    private var localizedNoSelectionTitle: String { localized(japanese: "未選択", chinese: "未选择", english: "Not selected") }
    private var localizedNavigationTitle: String { localized(japanese: "プロジェクト設定", chinese: "项目设置", english: "Project Settings") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedSaveTitle: String { localized(japanese: "保存", chinese: "保存", english: "Save") }
    private var localizedDirectionChangeTitle: String { localized(japanese: "帳票構成が変わります", chinese: "表单结构将变更", english: "Form Set Will Change") }
    private var localizedSaveChangeTitle: String { localized(japanese: "変更して保存", chinese: "变更并保存", english: "Save Changes") }

    private var localizedDirectionChangeWarning: String {
        localized(
            japanese: "プロジェクト分類を変更すると、必要帳票は「\(direction.localizedSubtitle(language))」に切り替わります。既存帳票は削除しませんが、このプロジェクト一覧で表示される必要帳票が変わります。",
            chinese: "变更项目分类后，所需表单将切换为「\(direction.localizedSubtitle(language))」。现有表单不会被删除，但项目列表中显示的所需表单会改变。",
            english: "After changing the project category, required forms switch to \"\(direction.localizedSubtitle(language))\". Existing forms are not deleted, but the required forms shown in this project list will change."
        )
    }

    private var localizedDirectionChangeMessage: String {
        localized(
            japanese: "プロジェクト分類を変更すると、プロジェクト内で必要とされる帳票が「\(direction.localizedSubtitle(language))」に変わります。続行しますか？",
            chinese: "变更项目分类后，项目内所需表单将变为「\(direction.localizedSubtitle(language))」。要继续吗？",
            english: "Changing the project category changes the required forms to \"\(direction.localizedSubtitle(language))\". Continue?"
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

struct CustomerManagementScreen: View {
    @ObservedObject var store: DocumentStore
    let onBack: () -> Void
    var onAppliedToForm: (() -> Void)? = nil
    @State private var customerName = ""
    @State private var customerContact = ""
    @State private var customerPhone = ""
    @State private var customerEmail = ""
    @State private var customerAddress = ""
    @State private var editingCustomerID: CustomerProfile.ID?
    @State private var isCustomerEditorPresented = false
    @State private var applyToastText = ""
    @State private var isApplyToastVisible = false
    @State private var applyToastID = UUID()
    private var language: AppLanguage { store.interfaceLanguage }

    var body: some View {
        ManagementScroll(
            title: localizedTitle,
            subtitle: localizedSubtitle,
            onBack: onBack,
            actionTitle: localizedAddTitle,
            actionSystemImage: "plus",
            action: presentNewCustomer
        ) {
            SectionCard(title: localizedListTitle, titleWeight: .regular) {
                if store.customers.isEmpty {
                    EmptyManagementText(text: localizedEmptyText)
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.customers) { customer in
                            ManagementRecordRow(
                                title: customer.name,
                                subtitle: [customer.contact, customer.phone ?? "", customer.email ?? "", customer.address].filter { !$0.isEmpty }.joined(separator: " / "),
                                applyTitle: localizedApplyTitle,
                                editTitle: localizedEditTitle
                            ) {
                                applyCustomer(customer)
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
        .overlay(alignment: .bottom) {
            if isApplyToastVisible {
                ManagementApplyToast(text: applyToastText)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 92)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isCustomerEditorPresented) {
            NavigationView {
                ScrollView {
                    customerEditorForm
                        .padding(18)
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
                .navigationTitle(editingCustomerID == nil ? localizedNewNavigationTitle : localizedEditNavigationTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizedCancelTitle) {
                            dismissCustomerEditor()
                        }
                    }
                }
            }
        }
    }

    private var customerEditorForm: some View {
        VStack(spacing: 14) {
            FormField(title: localizedNameTitle) {
                TextField("", text: $customerName, prompt: .inputPrompt(localizedNamePlaceholder))
                    .textFieldStyle(PlainTextFieldStyle())
                    .flatFormInput()
            }
            FormField(title: localizedContactTitle) {
                TextField("", text: $customerContact, prompt: .inputPrompt(localizedContactPlaceholder))
                    .textFieldStyle(PlainTextFieldStyle())
                    .flatFormInput()
            }
            HStack(spacing: 12) {
                FormField(title: localizedPhoneTitle) {
                    TextField("", text: $customerPhone, prompt: .inputPrompt(localizedPhoneTitle))
                        .keyboardType(.phonePad)
                        .textFieldStyle(PlainTextFieldStyle())
                        .flatFormInput()
                }
                FormField(title: localizedEmailTitle) {
                    TextField("", text: $customerEmail, prompt: .inputPrompt(localizedEmailTitle))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(PlainTextFieldStyle())
                        .flatFormInput()
                }
            }
            FormField(title: localizedAddressTitle) {
                MultilineTextInput(text: $customerAddress)
                    .multilineFormInput(minHeight: 86)
            }
            ManagementPrimaryButton(title: editingCustomerID == nil ? localizedSaveCustomerTitle : localizedUpdateCustomerTitle, systemImage: editingCustomerID == nil ? "plus.circle.fill" : "checkmark.circle.fill") {
                saveCustomerForm()
            }
            .disabled(customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
    }

    private func clearCustomerForm() {
        customerName = ""
        customerContact = ""
        customerPhone = ""
        customerEmail = ""
        customerAddress = ""
        editingCustomerID = nil
    }

    private func presentNewCustomer() {
        clearCustomerForm()
        isCustomerEditorPresented = true
    }

    private func applyCustomer(_ customer: CustomerProfile) {
        store.apply(customer)
        showApplyToast(for: customer.name)
        onAppliedToForm?()
    }

    private func showApplyToast(for name: String) {
        let toastID = UUID()
        applyToastID = toastID
        applyToastText = localizedAppliedMessage(name: name)
        withAnimation(.easeOut(duration: 0.16)) {
            isApplyToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard applyToastID == toastID else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                isApplyToastVisible = false
            }
        }
    }

    private func dismissCustomerEditor() {
        clearCustomerForm()
        isCustomerEditorPresented = false
    }

    private func saveCustomerForm() {
        if let editingCustomerID {
            store.updateCustomerProfile(id: editingCustomerID, name: customerName, contact: customerContact, phone: customerPhone, email: customerEmail, address: customerAddress)
        } else {
            store.saveCustomerProfile(name: customerName, contact: customerContact, phone: customerPhone, email: customerEmail, address: customerAddress)
        }
        clearCustomerForm()
        isCustomerEditorPresented = false
    }

    private func editCustomer(_ customer: CustomerProfile) {
        editingCustomerID = customer.id
        customerName = customer.name
        customerContact = customer.contact
        customerPhone = customer.phone ?? ""
        customerEmail = customer.email ?? ""
        customerAddress = customer.address
        isCustomerEditorPresented = true
    }

    private var localizedTitle: String { localized(japanese: "取引先・仕入先管理", chinese: "客户/供应商管理", english: "Customer and Vendor Management") }
    private var localizedSubtitle: String { localized(japanese: "会社名を入力すると、ここに保存された取引先・仕入先候補が表示されます。", chinese: "输入公司名时，会显示这里保存的客户/供应商候选项。", english: "Saved customers and vendors appear as suggestions when entering company names.") }
    private var localizedAddTitle: String { localized(japanese: "追加", chinese: "新增", english: "Add") }
    private var localizedListTitle: String { localized(japanese: "取引先・仕入先一覧", chinese: "客户/供应商列表", english: "Customers and Vendors") }
    private var localizedEmptyText: String { localized(japanese: "保存済みの取引先・仕入先はありません。右上の追加ボタンから登録してください。", chinese: "没有已保存的客户/供应商。请通过右上角的新增按钮登记。", english: "No saved customers or vendors. Use the add button to register one.") }
    private var localizedApplyTitle: String { localized(japanese: "使用", chinese: "使用", english: "Use") }
    private var localizedEditTitle: String { localized(japanese: "編集", chinese: "编辑", english: "Edit") }
    private var localizedNewNavigationTitle: String { localized(japanese: "取引先・仕入先情報を追加", chinese: "新增客户/供应商资料", english: "Add Customer or Vendor") }
    private var localizedEditNavigationTitle: String { localized(japanese: "取引先・仕入先情報を編集", chinese: "编辑客户/供应商资料", english: "Edit Customer or Vendor") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedNameTitle: String { localized(japanese: "会社名 / 氏名", chinese: "公司名 / 姓名", english: "Company / Name") }
    private var localizedNamePlaceholder: String { localized(japanese: "株式会社サンプル", chinese: "示例有限公司", english: "Sample Co., Ltd.") }
    private var localizedContactTitle: String { localized(japanese: "担当者", chinese: "联系人", english: "Contact") }
    private var localizedContactPlaceholder: String { localized(japanese: "経理部 山田", chinese: "财务部 张三", english: "Accounting Team") }
    private var localizedPhoneTitle: String { localized(japanese: "電話", chinese: "电话", english: "Phone") }
    private var localizedEmailTitle: String { localized(japanese: "メール", chinese: "邮箱", english: "Email") }
    private var localizedAddressTitle: String { localized(japanese: "住所", chinese: "地址", english: "Address") }
    private var localizedSaveCustomerTitle: String { localized(japanese: "取引先・仕入先情報を保存", chinese: "保存客户/供应商资料", english: "Save Customer or Vendor") }
    private var localizedUpdateCustomerTitle: String { localized(japanese: "取引先・仕入先情報を更新", chinese: "更新客户/供应商资料", english: "Update Customer or Vendor") }

    private func localizedAppliedMessage(name: String) -> String {
        localized(
            japanese: "「\(name)」を帳票に追加しました。",
            chinese: "已将「\(name)」加入表单。",
            english: "Added \"\(name)\" to the form."
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

struct TemplateManagementScreen: View {
    @ObservedObject var store: DocumentStore
    let onBack: () -> Void
    @State private var selectedKind: TextTemplateKind = .payment
    @State private var templateTitle = ""
    @State private var templateContent = ""
    @State private var editingTemplateID: TextTemplate.ID?
    @State private var isTemplateEditorPresented = false
    private var language: AppLanguage { store.interfaceLanguage }

    var body: some View {
        ManagementScroll(
            title: localizedTitle,
            subtitle: localizedSubtitle,
            onBack: onBack,
            actionTitle: localizedAddTitle,
            actionSystemImage: "plus",
            action: presentNewTemplate
        ) {
            ForEach(TextTemplateKind.allCases) { kind in
                SectionCard(title: localizedTemplateListTitle(kind), titleWeight: .regular) {
                    let templates = store.templates(kind: kind)
                    if templates.isEmpty {
                        EmptyManagementText(text: localizedEmptyTemplateText(kind))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(templates) { template in
                                ManagementRecordRow(
                                    title: template.title.isEmpty ? String(template.content.prefix(24)) : template.title,
                                    subtitle: template.content,
                                    applyTitle: nil,
                                    editTitle: localizedEditTitle
                                ) {
                                } onEdit: {
                                    editTemplate(template)
                                } onDelete: {
                                    store.deleteTextTemplate(template)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isTemplateEditorPresented) {
            NavigationView {
                ScrollView {
                    templateEditorForm
                        .padding(18)
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
                .navigationTitle(editingTemplateID == nil ? localizedNewNavigationTitle : localizedEditNavigationTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizedCancelTitle) {
                            dismissTemplateEditor()
                        }
                    }
                }
            }
        }
    }

    private var templateEditorForm: some View {
        VStack(spacing: 14) {
            Picker(localizedCategoryTitle, selection: $selectedKind) {
                ForEach(TextTemplateKind.allCases) { kind in
                    Label(kind.localizedTitle(language), systemImage: kind.systemImage).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            FormField(title: localizedTemplateNameTitle) {
                TextField("", text: $templateTitle, prompt: .inputPrompt(localizedTemplateNamePlaceholder))
                    .textFieldStyle(PlainTextFieldStyle())
                    .flatFormInput()
            }
            FormField(title: localizedTemplateContentTitle) {
                MultilineTextInput(text: $templateContent)
                    .multilineFormInput(minHeight: 110)
            }
            ManagementPrimaryButton(title: editingTemplateID == nil ? localizedSaveTemplateTitle : localizedUpdateTemplateTitle, systemImage: editingTemplateID == nil ? "plus.circle.fill" : "checkmark.circle.fill") {
                saveTemplateForm()
            }
            .disabled(templateContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(templateContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
    }

    private func clearTemplateForm() {
        templateTitle = ""
        templateContent = ""
        editingTemplateID = nil
    }

    private func presentNewTemplate() {
        clearTemplateForm()
        isTemplateEditorPresented = true
    }

    private func dismissTemplateEditor() {
        clearTemplateForm()
        isTemplateEditorPresented = false
    }

    private func saveTemplateForm() {
        if let editingTemplateID {
            store.updateTextTemplate(id: editingTemplateID, kind: selectedKind, title: templateTitle, content: templateContent)
        } else {
            store.saveTextTemplate(kind: selectedKind, title: templateTitle, content: templateContent)
        }
        clearTemplateForm()
        isTemplateEditorPresented = false
    }

    private func editTemplate(_ template: TextTemplate) {
        selectedKind = template.kind
        templateTitle = template.title
        templateContent = template.content
        editingTemplateID = template.id
        isTemplateEditorPresented = true
    }

    private var localizedTitle: String { localized(japanese: "振込・備考テンプレート", chinese: "汇款与备注模板", english: "Payment and Note Templates") }
    private var localizedSubtitle: String { localized(japanese: "振込口座、備考、条件を保存し、帳票入力時に呼び出せます。", chinese: "保存汇款账户、备注与条件，并可在表单输入时调用。", english: "Save payment accounts, notes, and terms for reuse while editing forms.") }
    private var localizedAddTitle: String { localized(japanese: "追加", chinese: "新增", english: "Add") }
    private var localizedEditTitle: String { localized(japanese: "編集", chinese: "编辑", english: "Edit") }
    private var localizedNewNavigationTitle: String { localized(japanese: "テンプレートを追加", chinese: "新增模板", english: "Add Template") }
    private var localizedEditNavigationTitle: String { localized(japanese: "テンプレートを編集", chinese: "编辑模板", english: "Edit Template") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedCategoryTitle: String { localized(japanese: "分類", chinese: "分类", english: "Category") }
    private var localizedTemplateNameTitle: String { localized(japanese: "テンプレート名", chinese: "模板名称", english: "Template Name") }
    private var localizedTemplateNamePlaceholder: String { localized(japanese: "例: 三井住友銀行 / 標準備考", chinese: "例: 三井住友银行 / 标准备注", english: "Example: Bank Account / Standard Notes") }
    private var localizedTemplateContentTitle: String { localized(japanese: "内容", chinese: "内容", english: "Content") }
    private var localizedSaveTemplateTitle: String { localized(japanese: "テンプレートを保存", chinese: "保存模板", english: "Save Template") }
    private var localizedUpdateTemplateTitle: String { localized(japanese: "テンプレートを更新", chinese: "更新模板", english: "Update Template") }

    private func localizedTemplateListTitle(_ kind: TextTemplateKind) -> String {
        switch language {
        case .japanese: return "\(kind.localizedTitle(language))一覧"
        case .simplifiedChinese: return "\(kind.localizedTitle(language))列表"
        case .english: return "\(kind.localizedTitle(language)) Templates"
        }
    }

    private func localizedEmptyTemplateText(_ kind: TextTemplateKind) -> String {
        switch language {
        case .japanese: return "\(kind.localizedTitle(language))のテンプレートはありません。"
        case .simplifiedChinese: return "没有\(kind.localizedTitle(language))模板。"
        case .english: return "No \(kind.localizedTitle(language).lowercased()) templates."
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

struct ProductManagementScreen: View {
    @ObservedObject var store: DocumentStore
    let onBack: () -> Void
    var onAppliedToForm: (() -> Void)? = nil
    @State private var productName = ""
    @State private var productModel = ""
    @State private var productSpecification = ""
    @State private var productUnitPrice: Double = 0
    @State private var editingProductID: ProductProfile.ID?
    @State private var isProductEditorPresented = false
    @State private var applyToastText = ""
    @State private var isApplyToastVisible = false
    @State private var applyToastID = UUID()
    private var language: AppLanguage { store.interfaceLanguage }

    var body: some View {
        ManagementScroll(
            title: localizedTitle,
            subtitle: localizedSubtitle,
            onBack: onBack,
            actionTitle: localizedAddTitle,
            actionSystemImage: "plus",
            action: presentNewProduct
        ) {
            SectionCard(title: localizedListTitle, titleWeight: .regular) {
                if store.products.isEmpty {
                    EmptyManagementText(text: localizedEmptyText)
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.products) { product in
                            ManagementRecordRow(
                                title: product.name,
                                subtitle: [product.model, product.specification, AppFormatters.yen(product.unitPrice)].filter { !$0.isEmpty }.joined(separator: " / "),
                                applyTitle: localizedApplyTitle,
                                editTitle: localizedEditTitle
                            ) {
                                applyProduct(product)
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
        .overlay(alignment: .bottom) {
            if isApplyToastVisible {
                ManagementApplyToast(text: applyToastText)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 92)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isProductEditorPresented) {
            NavigationView {
                ScrollView {
                    productEditorForm
                        .padding(18)
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
                .navigationTitle(editingProductID == nil ? localizedNewNavigationTitle : localizedEditNavigationTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizedCancelTitle) {
                            dismissProductEditor()
                        }
                    }
                }
            }
        }
    }

    private var productEditorForm: some View {
        VStack(spacing: 14) {
            FormField(title: localizedProductNameTitle) {
                TextField("", text: $productName, prompt: .inputPrompt(localizedProductNamePlaceholder))
                    .textFieldStyle(PlainTextFieldStyle())
                    .flatFormInput()
            }
            FormField(title: localizedSpecificationTitle) {
                TextField("", text: $productSpecification, prompt: .inputPrompt(localizedSpecificationTitle))
                    .textFieldStyle(PlainTextFieldStyle())
                    .flatFormInput()
            }
            HStack(alignment: .top, spacing: 18) {
                FormField(title: localizedModelTitle) {
                    TextField("", text: $productModel, prompt: .inputPrompt(localizedModelTitle))
                        .textFieldStyle(PlainTextFieldStyle())
                        .flatFormInput()
                }
                FormField(title: localizedUnitPriceTitle) {
                    TextField("", value: $productUnitPrice, formatter: NumberFormatter.decimal, prompt: .inputPrompt(localizedUnitPriceTitle))
                        .keyboardType(.numberPad)
                        .textFieldStyle(PlainTextFieldStyle())
                        .flatFormInput()
                }
            }
            ManagementPrimaryButton(title: editingProductID == nil ? localizedSaveProductTitle : localizedUpdateProductTitle, systemImage: editingProductID == nil ? "plus.circle.fill" : "checkmark.circle.fill") {
                saveProductForm()
            }
            .disabled(productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
    }

    private func clearProductForm() {
        productName = ""
        productModel = ""
        productSpecification = ""
        productUnitPrice = 0
        editingProductID = nil
    }

    private func presentNewProduct() {
        clearProductForm()
        isProductEditorPresented = true
    }

    private func applyProduct(_ product: ProductProfile) {
        store.apply(product)
        showApplyToast(for: product.name)
        onAppliedToForm?()
    }

    private func showApplyToast(for name: String) {
        let toastID = UUID()
        applyToastID = toastID
        applyToastText = localizedAppliedMessage(name: name)
        withAnimation(.easeOut(duration: 0.16)) {
            isApplyToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard applyToastID == toastID else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                isApplyToastVisible = false
            }
        }
    }

    private func dismissProductEditor() {
        clearProductForm()
        isProductEditorPresented = false
    }

    private func saveProductForm() {
        if let editingProductID {
            store.updateProductProfile(id: editingProductID, name: productName, model: productModel, specification: productSpecification, unitPrice: productUnitPrice)
        } else {
            store.saveProductProfile(name: productName, model: productModel, specification: productSpecification, unitPrice: productUnitPrice)
        }
        clearProductForm()
        isProductEditorPresented = false
    }

    private func editProduct(_ product: ProductProfile) {
        editingProductID = product.id
        productName = product.name
        productModel = product.model
        productSpecification = product.specification
        productUnitPrice = product.unitPrice
        isProductEditorPresented = true
    }

    private var localizedTitle: String { localized(japanese: "商品・項目管理", chinese: "商品/品项管理", english: "Product and Item Management") }
    private var localizedSubtitle: String { localized(japanese: "品目入力時に使う商品名、型番、仕様、単価の候補です。", chinese: "保存输入品项时使用的商品名、型号、规格与单价候选项。", english: "Save product names, models, specifications, and unit prices for line item entry.") }
    private var localizedAddTitle: String { localized(japanese: "追加", chinese: "新增", english: "Add") }
    private var localizedListTitle: String { localized(japanese: "商品・項目一覧", chinese: "商品/品项列表", english: "Products and Items") }
    private var localizedEmptyText: String { localized(japanese: "保存済みの商品・項目はありません。右上の追加ボタンから登録してください。", chinese: "没有已保存的商品/品项。请通过右上角的新增按钮登记。", english: "No saved products or items. Use the add button to register one.") }
    private var localizedApplyTitle: String { localized(japanese: "使用", chinese: "使用", english: "Use") }
    private var localizedEditTitle: String { localized(japanese: "編集", chinese: "编辑", english: "Edit") }
    private var localizedNewNavigationTitle: String { localized(japanese: "項目情報を追加", chinese: "新增品项信息", english: "Add Item Information") }
    private var localizedEditNavigationTitle: String { localized(japanese: "項目情報を編集", chinese: "编辑品项信息", english: "Edit Item Information") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedProductNameTitle: String { localized(japanese: "品目 / 項目名", chinese: "品项 / 品项名", english: "Item Name") }
    private var localizedProductNamePlaceholder: String { localized(japanese: "品目", chinese: "品目", english: "Item") }
    private var localizedSpecificationTitle: String { localized(japanese: "仕様", chinese: "规格", english: "Specification") }
    private var localizedModelTitle: String { localized(japanese: "型番", chinese: "型号", english: "Model") }
    private var localizedUnitPriceTitle: String { localized(japanese: "単価", chinese: "单价", english: "Unit Price") }
    private var localizedSaveProductTitle: String { localized(japanese: "項目情報を保存", chinese: "保存品项信息", english: "Save Item Information") }
    private var localizedUpdateProductTitle: String { localized(japanese: "項目情報を更新", chinese: "更新品项信息", english: "Update Item Information") }

    private func localizedAppliedMessage(name: String) -> String {
        localized(
            japanese: "「\(name)」を帳票に追加しました。",
            chinese: "已将「\(name)」加入表单中。",
            english: "Added \"\(name)\" to the form."
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

struct ManagementScroll<Content: View>: View {
    let title: String
    let subtitle: String
    var onBack: (() -> Void)? = nil
    var actionTitle: String? = nil
    var actionSystemImage: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: Content
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 12) {
                    if let onBack {
                        AppBackButton(title: localizedBackTitle, action: onBack)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appInk)
                    }
                    Spacer()
                    if let actionTitle, let actionSystemImage, let action {
                        Button(action: action) {
                            Label(actionTitle, systemImage: actionSystemImage)
                                .labelStyle(.iconOnly)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 31, height: 31)
                                .background(buttonAccent)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(actionTitle)
                    }
                }
                content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .dismissKeyboardOnTap()
    }

    private var localizedBackTitle: String {
        "戻る"
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
    let isEditorPresented: Bool
    let action: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    private var actionTitle: String {
        if isEditing { return "編集中" }
        return isEditorPresented ? "閉じる" : "新增"
    }

    private var actionIcon: String {
        if isEditing { return "pencil" }
        return isEditorPresented ? "xmark" : "plus"
    }

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
            Button(action: action) {
                Label(actionTitle, systemImage: actionIcon)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background((isEditing || isEditorPresented) ? buttonAccent.opacity(0.12) : Color.appInputBackground)
                    .foregroundColor((isEditing || isEditorPresented) ? buttonAccent : .appMuted)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke((isEditing || isEditorPresented) ? buttonAccent.opacity(0.35) : Color.appDivider))
            }
            .buttonStyle(PlainButtonStyle())
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

struct CompanyProfileRow: View {
    let issuer: IssuerProfile
    let language: AppLanguage
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(issuer.name.isEmpty ? localizedNameMissingText : issuer.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(2)
                    Text([issuer.registration, issuer.phone, issuer.email].filter { !$0.isEmpty }.joined(separator: " / "))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(action: onApply) {
                    Label(localizedApplyTitle, systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CompanyMiniButtonStyle())

                Button(action: onEdit) {
                    Label(localizedEditTitle, systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CompanyMiniButtonStyle(tint: .appInk))

                Button(role: .destructive, action: onDelete) {
                    Label(localizedDeleteTitle, systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CompanyMiniButtonStyle(tint: .red))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }

    private var localizedNameMissingText: String { localized(japanese: "名称未入力", chinese: "未填写名称", english: "No name") }
    private var localizedApplyTitle: String { localized(japanese: "使用", chinese: "使用", english: "Use") }
    private var localizedEditTitle: String { localized(japanese: "編集", chinese: "编辑", english: "Edit") }
    private var localizedDeleteTitle: String { localized(japanese: "削除", chinese: "删除", english: "Delete") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }
}

struct CompanyFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appButtonAccent) private var buttonAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .frame(height: 44)
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
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .frame(height: 44)
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
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .frame(height: 44)
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
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(buttonAccent.opacity(0.12))
                    .foregroundColor(buttonAccent)
                    .cornerRadius(7)
            }
            if let editTitle = editTitle {
                Button(editTitle, action: onEdit)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(Color.appInputBackground)
                    .foregroundColor(.appInk)
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appDivider))
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 12)
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
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

struct BackupStatusRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if !value.isEmpty {
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
    }
}

struct BackupActionRow: View {
    let title: String
    let systemImage: String
    var isProminent = false
    let action: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(iconBackgroundColor)
                    .clipShape(Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.65)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(borderColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var foregroundColor: Color {
        guard isEnabled else { return .appMuted }
        return isProminent ? .white : .appInk
    }

    private var backgroundColor: Color {
        isProminent ? buttonAccent : Color.appInputBackground
    }

    private var borderColor: Color {
        isProminent ? Color.clear : Color.appDivider
    }

    private var iconBackgroundColor: Color {
        isProminent ? Color.white.opacity(0.18) : buttonAccent.opacity(0.12)
    }
}

struct LocalBackupActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(isEnabled ? buttonAccent : .appMuted)
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 8)
            .background(Color.appInputBackground.opacity(0.72))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider.opacity(0.78)))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text(title))
    }
}

struct BackupProgressRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct BackupStatusMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.appMuted)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ManagementApplyToast: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appInk.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

struct EmptyManagementText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.appMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}

@MainActor
final class AppUpdateChecker: ObservableObject {
    @Published var isUpdateAlertPresented = false
    @Published private(set) var latestVersion = ""
    private var appStoreURL: URL?
    private var isChecking = false
    private var language: AppLanguage = .japanese

    private let promptedDateKey = "native.shokoForms.appUpdateLastPromptDate.v1"

    var alertTitle: String {
        localized(
            japanese: "新しいバージョンがあります",
            chinese: "发现新版本",
            english: "Update Available"
        )
    }

    var alertMessage: String {
        let versionText = latestVersion.isEmpty ? "" : " \(latestVersion)"
        return localized(
            japanese: "App Storeで新しいバージョン\(versionText)を利用できます。更新して最新の機能と修正を反映してください。",
            chinese: "App Store 已有新版本\(versionText)。请前往更新，以获得最新功能和修正。",
            english: "A new version\(versionText) is available on the App Store. Update to get the latest features and fixes."
        )
    }

    var updateButtonTitle: String {
        localized(japanese: "アップデートへ", chinese: "前往更新", english: "Update")
    }

    var dismissButtonTitle: String {
        localized(japanese: "閉じる", chinese: "关闭", english: "Close")
    }

    func checkForUpdateIfNeeded(language: AppLanguage) async {
        self.language = language
        guard !isChecking, !hasPromptedToday else { return }
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let update = try await fetchLatestVersion(bundleID: bundleID)
            guard isNewerVersion(update.version, than: currentVersion) else { return }
            latestVersion = update.version
            appStoreURL = update.url
            markPromptedToday()
            isUpdateAlertPresented = true
        } catch {
            return
        }
    }

    func openAppStore() {
        guard let appStoreURL else { return }
        UIApplication.shared.open(appStoreURL)
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private var hasPromptedToday: Bool {
        UserDefaults.standard.string(forKey: promptedDateKey) == todayKey
    }

    private func markPromptedToday() {
        UserDefaults.standard.set(todayKey, forKey: promptedDateKey)
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func fetchLatestVersion(bundleID: String) async throws -> AppStoreVersionInfo {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "JP")
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
        guard let result = response.results.first,
              let appStoreURL = URL(string: result.trackViewUrl) else {
            throw URLError(.cannotParseResponse)
        }
        return AppStoreVersionInfo(version: result.version, url: appStoreURL)
    }

    private func isNewerVersion(_ storeVersion: String, than installedVersion: String) -> Bool {
        let storeParts = numericVersionParts(storeVersion)
        let installedParts = numericVersionParts(installedVersion)
        let maxCount = max(storeParts.count, installedParts.count)

        for index in 0..<maxCount {
            let storeValue = index < storeParts.count ? storeParts[index] : 0
            let installedValue = index < installedParts.count ? installedParts[index] : 0
            if storeValue > installedValue { return true }
            if storeValue < installedValue { return false }
        }
        return false
    }

    private func numericVersionParts(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { part in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
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

private struct AppStoreVersionInfo {
    let version: String
    let url: URL
}

private struct AppStoreLookupResponse: Decodable {
    let results: [AppStoreLookupResult]
}

private struct AppStoreLookupResult: Decodable {
    let trackId: Int?
    let version: String
    let trackViewUrl: String
}
