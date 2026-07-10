import AVKit
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let defaultDSAContactAddress = "3F,  3 - 11 - 2  Nezu, Bunkyou-ku, Tokyo, Japan."
private let shokoFormsAppGroupIdentifier = "group.com.shoko.forms"
private let shokoFormsExternalImportFolderName = "ExternalImports"

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
    @State private var pendingNewFormType: DocumentType?
    @State private var isLeaveFormConfirmationPresented = false
    @State private var isIpadEditorModalActive = false
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
    @State private var isDeleteFormVideoPresented = false
    @State private var pendingExternalAttachmentImport: ExternalAttachmentImport?
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
                        onOpenReminderDocument: navigateToEditorFromReminder,
                        onCreateStartRequested: requestCreateStartFromNavigation,
                        onOpenOnboardingGuide: openOnboardingGuide
                    )
                        .frame(width: AppFontMetrics.sidebarWidth)
                    iPadPrimaryContent
                        .frame(minWidth: 430, maxWidth: .infinity)
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
                .fullScreenCover(isPresented: iPadEditorPresentation) {
                    iPadEditorModalContent
                }
                .fullScreenCover(isPresented: iPadPreviewPresentation) {
                    iPadPreviewModalContent
                }
            } else {
                TabView(selection: compactTabSelection) {
                    SidebarView(
                        store: store,
                        purchaseService: purchaseService,
                        selectedSection: $selectedSection,
                        onOpenRecentProject: openRecentProject,
                        onPreviewDocument: navigateToPreviewFromList,
                        onOpenReminderDocument: navigateToEditorFromReminder,
                        onCreateStartRequested: requestCreateStartFromNavigation,
                        onOpenOnboardingGuide: openOnboardingGuide
                    )
                        .tabItem { Label(AppText.value(.home, interfaceLanguage), systemImage: "house") }
                        .tag(AppSection.menu)

                    createContent
                        .tabItem { Label(AppText.value(.create, interfaceLanguage), systemImage: "doc.text") }
                        .tag(AppSection.form)

                    scanFormContent
                        .tabItem { Label(localizedScanFormTitle, systemImage: "viewfinder") }
                        .tag(AppSection.scan)

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
                .fullScreenCover(isPresented: compactPreviewPresentation) {
                    iPadPreviewModalContent
                }
            }
        }
        .environment(\.appButtonAccent, buttonAccent)
        .environment(\.locale, Locale(identifier: interfaceLanguage.localeIdentifier))
        .dynamicTypeSize(AppFontMetrics.dynamicTypeSize)
        .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        .overlay {
            if isDeleteFormVideoPresented {
                DeleteFormConfirmationVideoView {
                    navigateToCreateStartAfterFormExit()
                    isDeleteFormVideoPresented = false
                }
                .zIndex(1000)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shokoFormsOpenFileURL)) { notification in
            processPendingOpenedFileURLs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shokoFormsOpenReminderDocument)) { _ in
            processPendingReminderDocuments()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            processPendingExternalAttachmentImportDirectories()
            processPendingReminderDocuments()
            Task {
                await checkForUpdateIfNoExternalImport()
            }
        }
        .onChange(of: selectedSection) { newSection in
            handleSectionChange(newSection)
        }
        .task {
            processPendingOpenedFileURLs()
            processPendingReminderDocuments()
            processPendingExternalAttachmentImportDirectories()
            await checkForUpdateIfNoExternalImport()
            if !isOnboardingCompleted, pendingExternalAttachmentImport == nil {
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
        .sheet(item: $pendingExternalAttachmentImport) { importRequest in
            ExternalAttachmentImportSheet(
                store: store,
                importRequest: importRequest,
                language: interfaceLanguage,
                onComplete: { document in
                    cleanupExternalAttachmentImport(importRequest)
                    store.select(document)
                    selectedSection = .form
                    pendingExternalAttachmentImport = nil
                },
                onCancel: {
                    cleanupExternalAttachmentImport(importRequest)
                    pendingExternalAttachmentImport = nil
                }
            )
        }
        .confirmationDialog(leaveFormTitle, isPresented: rootLeaveFormConfirmationPresentation, titleVisibility: .visible) {
            Button(leaveFormSaveTitle) {
                store.saveCurrent()
                registerPreviewIntroForSavedDocument(store.current)
                if let pendingNewFormType {
                    performStartNewForm(pendingNewFormType)
                } else if isCreateStartNavigationPending {
                    navigateToCreateStartAfterFormExit()
                } else {
                    navigateToPendingSection()
                }
            }
            Button(leaveFormDiscardTitle, role: .destructive) {
                if let pendingNewFormType {
                    store.discardCurrentChanges()
                    performStartNewForm(pendingNewFormType)
                } else if isCreateStartNavigationPending {
                    discardCurrentFormToCreateStartWithAnimation()
                } else {
                    store.discardCurrentChanges()
                    navigateToPendingSection()
                }
            }
            Button(leaveFormContinueTitle, role: .cancel) {
                cancelPendingLeaveFormAction()
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

    private var currentDocumentIsSaved: Bool {
        store.documents.contains { $0.id == store.current.id }
    }

    private var hasUnsavedSavedDocumentChanges: Bool {
        store.hasActiveDocument &&
            store.hasUnsavedCurrentChanges &&
            currentDocumentIsSaved
    }

    private var hasUnsavedNewDraft: Bool {
        store.hasActiveDocument &&
            store.hasUnsavedCurrentChanges &&
            !currentDocumentIsSaved
    }

    private var rootLeaveFormConfirmationPresentation: Binding<Bool> {
        Binding {
            isLeaveFormConfirmationPresented && !isIpadEditorModalActive
        } set: { isPresented in
            if !isPresented {
                isLeaveFormConfirmationPresented = false
            }
        }
    }

    private var iPadEditorLeaveFormConfirmationPresentation: Binding<Bool> {
        Binding {
            isLeaveFormConfirmationPresented && isIpadEditorModalActive
        } set: { isPresented in
            if !isPresented {
                isLeaveFormConfirmationPresented = false
            }
        }
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
        case .company, .files, .projects, .customers, .products, .templates, .stamp, .reports:
            return .data
        case .preview:
            return .form
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
            presentLeaveFormConfirmation()
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
                presentLeaveFormConfirmation()
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
            presentLeaveFormConfirmation()
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
                presentLeaveFormConfirmation()
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

    private func requestIpadEditorExit() {
        pendingNewFormType = nil
        pendingSectionAfterForm = nil
        isBackNavigationPending = false
        isCreateStartNavigationPending = false

        guard store.hasActiveDocument, store.hasUnsavedCurrentChanges else {
            navigateToCreateStartAfterFormExit()
            return
        }

        isCreateStartNavigationPending = true
        presentLeaveFormConfirmation()
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

    private func discardCurrentFormToCreateStartWithAnimation() {
        store.resetCurrentDocumentSelection()
        presentDeleteFormVideo()
    }

    private func presentDeleteFormVideo() {
        pendingSectionAfterForm = nil
        isBackNavigationPending = false
        isCreateStartNavigationPending = false
        shouldReturnToCreateStartOnFormBack = false
        isListPreviewNavigation = false
        isResolvingSectionChange = true
        selectedSection = .form
        confirmedSection = .form
        isResolvingSectionChange = false
        isDeleteFormVideoPresented = true
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
        if hasUnsavedSavedDocumentChanges {
            pendingNewFormType = type
            pendingSectionAfterForm = nil
            isBackNavigationPending = false
            isCreateStartNavigationPending = false
            presentLeaveFormConfirmation()
            return
        }

        if hasUnsavedNewDraft {
            store.resetCurrentDocumentSelection()
        }

        performStartNewForm(type)
    }

    private func presentLeaveFormConfirmation() {
        guard !isLeaveFormConfirmationPresented else {
            isLeaveFormConfirmationPresented = false
            DispatchQueue.main.async {
                isLeaveFormConfirmationPresented = true
            }
            return
        }
        isLeaveFormConfirmationPresented = true
    }

    private func cancelPendingLeaveFormAction() {
        pendingNewFormType = nil
        pendingSectionAfterForm = nil
        isBackNavigationPending = false
        isCreateStartNavigationPending = false
    }

    private func performStartNewForm(_ type: DocumentType) {
        pendingNewFormType = nil
        store.newDocument(type: type)
        isListPreviewNavigation = false
        isResolvingSectionChange = true
        if confirmedSection != .form {
            recordNavigationHistory(from: confirmedSection, to: .form)
        }
        selectedSection = .form
        confirmedSection = .form
        shouldReturnToCreateStartOnFormBack = true
        isResolvingSectionChange = false
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
                onReturnToCreateStart: discardCurrentFormToCreateStartWithAnimation,
                onDocumentDeleted: presentDeleteFormVideo,
                onDocumentSaved: navigateToPreviewAfterSave,
                onPreviewCurrent: navigateToPreviewFromEditor
            )
        } else {
            CreateFormStartScreen(language: interfaceLanguage, onSelect: startNewForm)
        }
    }

    @ViewBuilder
    private var iPadPrimaryContent: some View {
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
        } else if selectedSection == .scan {
            scanFormContent
        } else if selectedSection == .data {
            DataManagementHubScreen(
                store: store,
                selectedSection: $selectedSection,
                language: interfaceLanguage,
                onBack: navigateBackInApp
            )
        } else if selectedSection == .reports {
            ReportExportScreen(
                store: store,
                language: interfaceLanguage,
                onBack: navigateBackInApp,
                onPreviewDocument: navigateToPreviewFromList,
                onEditDocument: navigateToEditorFromReminder
            )
        } else if selectedSection == .company {
            CompanyManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
        } else if selectedSection == .files {
            FileManagementScreen(store: store, selectedSection: $selectedSection, onBack: navigateBackInApp, onPreviewDocument: navigateToPreviewFromList)
        } else if selectedSection == .projects {
            ProjectManagementScreen(store: store, purchaseService: purchaseService, selectedSection: $selectedSection, focusedProjectID: $focusedProjectID, onBack: navigateBackInApp)
        } else if selectedSection == .customers {
            CustomerManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
        } else if selectedSection == .products {
            ProductManagementScreen(store: store, onBack: navigateBackInApp, onAppliedToForm: navigateToFormAfterManagementApply)
        } else if selectedSection == .templates {
            TemplateManagementScreen(store: store, onBack: navigateBackInApp)
        } else if selectedSection == .stamp {
            StampManagementScreen(language: interfaceLanguage, onBack: navigateBackInApp)
        } else if selectedSection == .pro {
            ProSubscriptionScreen(purchaseService: purchaseService, language: interfaceLanguage, onBack: navigateBackInApp)
        } else if selectedSection == .preview, !store.hasActiveDocument {
            EmptyPDFPreviewScreen(language: interfaceLanguage) {
                selectedSection = .form
            }
        } else {
            iPadHomeDashboardScreen(
                store: store,
                language: interfaceLanguage,
                onSelectForm: startNewForm,
                onOpenDocument: { document in
                    store.select(document)
                    selectedSection = .form
                }
            )
        }
    }

    private var iPadEditorPresentation: Binding<Bool> {
        Binding {
            selectedSection == .form && store.hasActiveDocument
        } set: { isPresented in
            guard !isPresented, selectedSection == .form else { return }
            guard !isDeleteFormVideoPresented else { return }
            navigateBackInApp()
        }
    }

    private var iPadPreviewPresentation: Binding<Bool> {
        Binding {
            selectedSection == .preview && store.hasActiveDocument
        } set: { isPresented in
            guard !isPresented, selectedSection == .preview else { return }
            navigateBackInApp()
        }
    }

    private var compactPreviewPresentation: Binding<Bool> {
        Binding {
            selectedSection == .preview && store.hasActiveDocument
        } set: { isPresented in
            guard !isPresented, selectedSection == .preview else { return }
            navigateBackInApp()
        }
    }

    @ViewBuilder
    private var iPadEditorModalContent: some View {
        GeometryReader { proxy in
            let panelWidth = min(max(proxy.size.width - 220, 860), 1040)
            let panelHeight = min(max(proxy.size.height - 120, 760), 980)

            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                EditorScreen(
                    store: store,
                    purchaseService: purchaseService,
                    language: interfaceLanguage,
                    onRequirePro: showProPlanForLockedAction,
                    onBack: requestIpadEditorExit,
                    onReturnToCreateStart: discardCurrentFormToCreateStartWithAnimation,
                    onDocumentDeleted: presentDeleteFormVideo,
                    onDocumentSaved: navigateToPreviewAfterSave,
                    onPreviewCurrent: navigateToPreviewFromEditor
                )
                .frame(width: panelWidth, height: panelHeight)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color.black.opacity(0.24), radius: 34, x: 0, y: 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 36)
        }
        .background(Color.clear)
        .onAppear {
            isIpadEditorModalActive = true
        }
        .onDisappear {
            isIpadEditorModalActive = false
        }
        .confirmationDialog(leaveFormTitle, isPresented: iPadEditorLeaveFormConfirmationPresentation, titleVisibility: .visible) {
            Button(leaveFormSaveTitle) {
                store.saveCurrent()
                registerPreviewIntroForSavedDocument(store.current)
                if let pendingNewFormType {
                    performStartNewForm(pendingNewFormType)
                } else if isCreateStartNavigationPending {
                    navigateToCreateStartAfterFormExit()
                } else {
                    navigateToPendingSection()
                }
            }
            Button(leaveFormDiscardTitle, role: .destructive) {
                if let pendingNewFormType {
                    store.discardCurrentChanges()
                    performStartNewForm(pendingNewFormType)
                } else if isCreateStartNavigationPending {
                    discardCurrentFormToCreateStartWithAnimation()
                } else {
                    store.discardCurrentChanges()
                    navigateToPendingSection()
                }
            }
            Button(leaveFormContinueTitle, role: .cancel) {
                cancelPendingLeaveFormAction()
            }
        } message: {
            Text(leaveFormMessage)
        }
        .interactiveDismissDisabled(store.hasUnsavedCurrentChanges)
    }

    @ViewBuilder
    private var iPadPreviewModalContent: some View {
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
        .ignoresSafeArea(edges: .bottom)
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

    private var scanFormContent: some View {
        ScanFormScreen(store: store, language: interfaceLanguage, onBack: navigateBackInApp) { draft in
            createDocumentFromScan(draft)
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

    private func navigateToPreviewAfterSave(_ document: BusinessDocument) {
        registerPreviewIntroForSavedDocument(document)
        store.select(document)
        isListPreviewNavigation = false
        selectedSection = .preview
    }

    private func navigateToPreviewFromEditor(_ document: BusinessDocument) {
        registerPreviewIntroForSavedDocument(document)
        store.select(document)
        isListPreviewNavigation = false
        selectedSection = .preview
    }

    private func createDocumentFromScan(_ draft: ScanFormDraft) {
        store.newDocument(type: draft.documentType)
        store.current.projectDirection = draft.direction

        let partner = draft.text(for: .partner)
        let issuer = draft.text(for: .issuer)
        let project = draft.text(for: .project)
        let item = draft.text(for: .item)
        let content = draft.text(for: .content)
        let payment = draft.text(for: .payment)
        let note = draft.text(for: .note)
        let terms = draft.text(for: .terms)

        if !partner.isEmpty {
            let firstLine = partner.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? partner
            store.current.customerName = firstLine
            store.current.customerContact = partner
        }
        if !issuer.isEmpty {
            let firstLine = issuer.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? issuer
            store.current.issuerName = firstLine
            store.current.issuerContact = issuer
        }
        if !project.isEmpty {
            store.current.projectName = project.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines)
            store.current.documentMemo = [store.current.documentMemo, project].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
        if !item.isEmpty {
            store.current.lines = [LineItem(name: item.components(separatedBy: .newlines).first ?? item, quantity: 1, unitPrice: 0)]
        }
        if !content.isEmpty {
            store.current.notes = [store.current.notes, content].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
        if !payment.isEmpty {
            store.current.paymentDetails = payment
        }
        if !note.isEmpty {
            store.current.notes = [store.current.notes, note].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
        if !terms.isEmpty {
            store.current.documentMemo = [store.current.documentMemo, terms].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }

        isListPreviewNavigation = false
        selectedSection = .form
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

    private func navigateToEditorFromReminder(_ document: BusinessDocument) {
        store.select(document)
        isListPreviewNavigation = false
        selectedSection = .form
    }

    private func processPendingReminderDocuments() {
        for documentID in AppDelegate.consumePendingReminderDocumentIDs() {
            guard let document = store.documents.first(where: { $0.id == documentID }) else {
                continue
            }
            navigateToEditorFromReminder(document)
        }
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

    private func openOnboardingGuide() {
        isOnboardingGuidePresented = true
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
        case .reports:
            ReportExportScreen(
                store: store,
                language: interfaceLanguage,
                onBack: navigateBackInApp,
                onPreviewDocument: navigateToPreviewFromList,
                onEditDocument: navigateToEditorFromReminder
            )
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
            ProSubscriptionScreen(purchaseService: purchaseService, language: interfaceLanguage, onBack: navigateBackInApp)
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
        case .simplifiedChinese, .traditionalChinese: return "公司"
        case .english, .korean, .nepali, .french, .vietnamese: return "Company"
        }
    }

    private var templateTabTitle: String {
        switch interfaceLanguage {
        case .japanese: return "テンプレート"
        case .simplifiedChinese, .traditionalChinese: return "模板"
        case .english, .korean, .nepali, .french, .vietnamese: return "Templates"
        }
    }

    private var fileManagementTabTitle: String {
        switch interfaceLanguage {
        case .japanese: return "ファイル"
        case .simplifiedChinese, .traditionalChinese: return "文件"
        case .english, .korean, .nepali, .french, .vietnamese: return "Files"
        }
    }

    private var proTabTitle: String {
        switch interfaceLanguage {
        case .japanese: return "Pro"
        case .simplifiedChinese, .traditionalChinese: return "Pro"
        case .english, .korean, .nepali, .french, .vietnamese: return "Pro"
        }
    }

    private var localizedDataTitle: String {
        switch interfaceLanguage {
        case .japanese: return "データ管理"
        case .simplifiedChinese, .traditionalChinese: return "数据管理"
        case .english, .korean, .nepali, .french, .vietnamese: return "Data"
        }
    }

    private var localizedScanFormTitle: String {
        switch interfaceLanguage {
        case .japanese: return "スキャン帳票"
        case .simplifiedChinese, .traditionalChinese: return "扫描表单"
        case .english, .korean, .nepali, .french, .vietnamese: return "Scan Form"
        }
    }

    private var cancelTitle: String {
        switch interfaceLanguage {
        case .japanese: return "キャンセル"
        case .simplifiedChinese, .traditionalChinese: return "取消"
        case .english, .korean, .nepali, .french, .vietnamese: return "Cancel"
        }
    }

    private var leaveFormTitle: String {
        switch interfaceLanguage {
        case .japanese: return "編集中の帳票を保存しますか？"
        case .simplifiedChinese, .traditionalChinese: return "要保存正在编辑的表单吗？"
        case .english, .korean, .nepali, .french, .vietnamese: return "Save the form you are editing?"
        }
    }

    private var leaveFormMessage: String {
        switch interfaceLanguage {
        case .japanese: return "この帳票を離れる前に、保存するか、変更を破棄するか選択してください。"
        case .simplifiedChinese, .traditionalChinese: return "离开这个表单前，请选择保存、放弃更改，或继续编辑。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Before leaving this form, choose whether to save, discard changes, or keep editing."
        }
    }

    private var leaveFormSaveTitle: String {
        switch interfaceLanguage {
        case .japanese: return "保存して離れる"
        case .simplifiedChinese, .traditionalChinese: return "保存并离开"
        case .english, .korean, .nepali, .french, .vietnamese: return "Save and Leave"
        }
    }

    private var leaveFormDiscardTitle: String {
        switch interfaceLanguage {
        case .japanese: return "破棄して離れる"
        case .simplifiedChinese, .traditionalChinese: return "放弃并离开"
        case .english, .korean, .nepali, .french, .vietnamese: return "Discard and Leave"
        }
    }

    private var leaveFormContinueTitle: String {
        switch interfaceLanguage {
        case .japanese: return "編集を続ける"
        case .simplifiedChinese, .traditionalChinese: return "继续编辑"
        case .english, .korean, .nepali, .french, .vietnamese: return "Keep Editing"
        }
    }

    private var previewUnavailableTitle: String {
        switch interfaceLanguage {
        case .japanese: return "プレビューする帳票がありません"
        case .simplifiedChinese, .traditionalChinese: return "没有可预览的表单"
        case .english, .korean, .nepali, .french, .vietnamese: return "No form to preview"
        }
    }

    private var previewUnavailableMessage: String {
        switch interfaceLanguage {
        case .japanese: return "先に帳票を作成するか、プロジェクト一覧から既存の帳票を選択してください。"
        case .simplifiedChinese, .traditionalChinese: return "请先建立表单，或到项目列表里选择已有表单。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Create a form first, or choose an existing form from the project list."
        }
    }

    private var previewUnavailableCreateTitle: String {
        switch interfaceLanguage {
        case .japanese: return "帳票を作成"
        case .simplifiedChinese, .traditionalChinese: return "建立表单"
        case .english, .korean, .nepali, .french, .vietnamese: return "Create Form"
        }
    }

    private var previewUnavailableProjectTitle: String {
        switch interfaceLanguage {
        case .japanese: return "プロジェクト一覧へ"
        case .simplifiedChinese, .traditionalChinese: return "前往项目列表"
        case .english, .korean, .nepali, .french, .vietnamese: return "Go to Projects"
        }
    }

    private var openedBackupImportTitle: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップファイルを読み込む"
        case .simplifiedChinese, .traditionalChinese: return "导入备份文件"
        case .english, .korean, .nepali, .french, .vietnamese: return "Import Backup File"
        }
    }

    private var openedBackupMergeTitle: String {
        switch interfaceLanguage {
        case .japanese: return "既存データに結合"
        case .simplifiedChinese, .traditionalChinese: return "合并到现有数据"
        case .english, .korean, .nepali, .french, .vietnamese: return "Merge with Existing Data"
        }
    }

    private var openedBackupReplaceTitle: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップから新規作成"
        case .simplifiedChinese, .traditionalChinese: return "用备份重新建立"
        case .english, .korean, .nepali, .french, .vietnamese: return "Replace with Backup"
        }
    }

    private var openedBackupImportMessage: String {
        switch interfaceLanguage {
        case .japanese: return "外部バックアップファイルを検出しました。読み込み方法を選択してください。"
        case .simplifiedChinese, .traditionalChinese: return "检测到外部备份文件。请选择导入方式。"
        case .english, .korean, .nepali, .french, .vietnamese: return "An external backup file was detected. Choose how to import it."
        }
    }

    private var openedBackupStatusTitle: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップ読み込み"
        case .simplifiedChinese, .traditionalChinese: return "备份导入"
        case .english, .korean, .nepali, .french, .vietnamese: return "Backup Import"
        }
    }

    private func processPendingOpenedFileURLs() {
        AppDelegate.consumePendingOpenFileURLs().forEach { url in
            readOpenedFile(from: url)
        }
        processPendingExternalAttachmentImportDirectories()
    }

    private func checkForUpdateIfNoExternalImport() async {
        guard pendingExternalAttachmentImport == nil else { return }
        await appUpdateChecker.checkForUpdateIfNeeded(language: interfaceLanguage)
    }

    private func readOpenedFile(from url: URL) {
        if url.scheme == "shokoforms" {
            readExternalAttachmentImportRequest(from: url)
            return
        }
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == "shokoform" {
            importOpenedForm(from: url)
        } else if pathExtension == "shokobackup" || pathExtension == "json" {
            readOpenedBackup(from: url)
        } else if isExternalAttachmentFile(url) {
            pendingExternalAttachmentImport = ExternalAttachmentImport(urls: [url])
        } else {
            readOpenedBackup(from: url)
        }
    }

    private func readExternalAttachmentImportRequest(from url: URL) {
        guard url.host == "external-import",
              let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "token" })?
                .value,
              let directory = externalAttachmentImportDirectory(token: token)
        else {
            return
        }
        let urls = externalAttachmentImportURLs(in: directory)
        guard !urls.isEmpty else { return }
        isOnboardingGuidePresented = false
        pendingExternalAttachmentImport = ExternalAttachmentImport(urls: urls, sourceDirectory: directory)
    }

    private func processPendingExternalAttachmentImportDirectories() {
        guard pendingExternalAttachmentImport == nil,
              let directory = nextPendingExternalAttachmentImportDirectory()
        else {
            return
        }
        let urls = externalAttachmentImportURLs(in: directory)
        guard !urls.isEmpty else {
            try? FileManager.default.removeItem(at: directory)
            return
        }
        isOnboardingGuidePresented = false
        pendingExternalAttachmentImport = ExternalAttachmentImport(urls: urls, sourceDirectory: directory)
    }

    private func nextPendingExternalAttachmentImportDirectory() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: shokoFormsAppGroupIdentifier) else {
            return nil
        }
        let root = container.appendingPathComponent(shokoFormsExternalImportFolderName, isDirectory: true)
        let directories = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return directories
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }
            .first { !externalAttachmentImportURLs(in: $0).isEmpty }
    }

    private func externalAttachmentImportDirectory(token: String) -> URL? {
        guard token.range(of: #"^[A-Fa-f0-9-]{36}$"#, options: .regularExpression) != nil,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: shokoFormsAppGroupIdentifier)
        else {
            return nil
        }
        return container
            .appendingPathComponent(shokoFormsExternalImportFolderName, isDirectory: true)
            .appendingPathComponent(token, isDirectory: true)
    }

    private func externalAttachmentImportURLs(in directory: URL) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let supported = urls.filter(isExternalAttachmentFile).sorted { left, right in
            left.lastPathComponent.localizedStandardCompare(right.lastPathComponent) == .orderedAscending
        }
        if let pdf = supported.first(where: { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .pdf) == true }) {
            return [pdf]
        }
        return supported
    }

    private func cleanupExternalAttachmentImport(_ importRequest: ExternalAttachmentImport) {
        guard let sourceDirectory = importRequest.sourceDirectory else { return }
        try? FileManager.default.removeItem(at: sourceDirectory)
    }

    private func isExternalAttachmentFile(_ url: URL) -> Bool {
        let type = UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: .pdf) == true || type?.conforms(to: .image) == true
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
        case .simplifiedChinese, .traditionalChinese: return "无法读取备份文件。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Could not read the backup file."
        }
    }

    private var localizedOpenedBackupMergeComplete: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップ内容を既存データに結合しました。"
        case .simplifiedChinese, .traditionalChinese: return "已将备份内容合并到现有数据。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Backup content was merged with existing data."
        }
    }

    private var localizedOpenedBackupReplaceComplete: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップ内容から新しいデータを作成しました。"
        case .simplifiedChinese, .traditionalChinese: return "已用备份内容重新建立数据。"
        case .english, .korean, .nepali, .french, .vietnamese: return "New data was created from the backup."
        }
    }

    private var localizedOpenedBackupImportFailed: String {
        switch interfaceLanguage {
        case .japanese: return "バックアップファイルを読み込めませんでした。"
        case .simplifiedChinese, .traditionalChinese: return "无法导入备份文件。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Could not import the backup file."
        }
    }

    private var localizedOpenedFormImportComplete: String {
        switch interfaceLanguage {
        case .japanese: return "帳票ファイルを開きました。"
        case .simplifiedChinese, .traditionalChinese: return "已打开表单文件。"
        case .english, .korean, .nepali, .french, .vietnamese: return "The form file was opened."
        }
    }

    private var localizedOpenedFormImportFailed: String {
        switch interfaceLanguage {
        case .japanese: return "帳票ファイルを開けませんでした。"
        case .simplifiedChinese, .traditionalChinese: return "无法打开表单文件。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Could not open the form file."
        }
    }
}

enum AppSection: Hashable {
    case menu
    case form
    case scan
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
    case reports
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

    @AppStorage("native.shokoForms.createFormHiddenTypes.v1") private var hiddenTypeStorage = "[]"
    @State private var isVisibilitySettingsPresented = false
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let formButtonIconSize = AppFontMetrics.homeIconSize
    private let formButtonVerticalPadding = AppFontMetrics.homeVerticalPadding

    var body: some View {
        ManagementScroll(
            title: localizedTitle,
            subtitle: localizedSubtitle,
            actionTitle: localizedVisibilitySettingsTitle,
            actionSystemImage: "slider.horizontal.3",
            action: { isVisibilitySettingsPresented = true }
        ) {
            directionSection(direction: .customer)
            directionSection(direction: .vendor)
        }
        .sheet(isPresented: $isVisibilitySettingsPresented) {
            FormVisibilitySettingsSheet(hiddenTypeStorage: $hiddenTypeStorage, language: language)
        }
    }

    private func directionSection(direction: ProjectDirection) -> some View {
        SectionCard(title: createFormSectionTitle(for: direction), titleWeight: .regular) {
            VStack(alignment: .leading, spacing: 12) {
                Label(createFormSectionTitle(for: direction), systemImage: direction == .customer ? "person.crop.circle" : "shippingbox")
                    .font(AppFont.sectionTitle(.semibold))
                    .foregroundColor(.appMuted)

                let visibleTypes = visibleTypes(for: direction)
                if visibleTypes.isEmpty {
                    EmptyManagementText(text: localizedNoVisibleFormsText)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(visibleTypes) { type in
                            formTypeButton(type)
                        }
                    }
                }
            }
        }
    }

    private func visibleTypes(for direction: ProjectDirection) -> [DocumentType] {
        let hiddenTypes = decodedHiddenTypes
        return direction.requiredTypes.filter { !hiddenTypes.contains($0) }
    }

    private var decodedHiddenTypes: Set<DocumentType> {
        guard let data = hiddenTypeStorage.data(using: .utf8),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(rawValues.compactMap(DocumentType.init(rawValue:)))
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

                Text(createFormTitle(for: type))
                    .font(AppFont.cardTitle(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
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

    private var localizedVisibilitySettingsTitle: String {
        localized(japanese: "表示する帳票", chinese: "显示表单", english: "Visible Forms")
    }

    private var localizedNoVisibleFormsText: String {
        localized(
            japanese: "表示する帳票がありません。右上のボタンから表示する帳票を選択してください。",
            chinese: "目前没有显示的表单。请点右上角按钮选择要显示的表单。",
            english: "No forms are visible. Use the top-right button to choose forms to show."
        )
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }

    private func createFormSectionTitle(for direction: ProjectDirection) -> String {
        switch direction {
        case .customer:
            return localized(japanese: "顧客", chinese: "客户", english: "Customer")
        case .vendor:
            return localized(japanese: "取引先", chinese: "供应商", english: "Vendor")
        }
    }

    private func createFormTitle(for type: DocumentType) -> String {
        switch type {
        case .customerOrder:
            return localized(japanese: "受注ファイル", chinese: "受注文件", english: "Order File")
        case .vendorEstimate:
            return localized(japanese: "見積書ファイル", chinese: "报价单文件", english: "Quote File")
        case .vendorInvoice:
            return localized(japanese: "請求書ファイル", chinese: "请款书文件", english: "Invoice File")
        case .vendorReceipt:
            return localized(japanese: "領収書ファイル", chinese: "收据文件", english: "Receipt File")
        default:
            return type.localizedTitle(language)
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
        case .vendorInvoice: return "doc.richtext.fill"
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
        case .vendorInvoice: return Color(red: 0.349, green: 0.435, blue: 0.898)
        case .customerFiles: return Color(red: 0.431, green: 0.533, blue: 0.678)
        case .vendorEstimate: return Color(red: 0.145, green: 0.388, blue: 0.922)
        case .paymentNotice: return Color(red: 0.706, green: 0.325, blue: 0.035)
        }
    }
}

private struct iPadHomeDashboardScreen: View {
    @ObservedObject var store: DocumentStore
    let language: AppLanguage
    let onSelectForm: (DocumentType) -> Void
    let onOpenDocument: (BusinessDocument) -> Void

    @Environment(\.appButtonAccent) private var buttonAccent
    @AppStorage("native.shokoForms.createFormHiddenTypes.v1") private var hiddenTypeStorage = "[]"
    @State private var isVisibilitySettingsPresented = false
    @State private var heldPreviewDocument: BusinessDocument?
    @State private var heldPreviewImage: UIImage?
    @State private var heldPreviewFailed = false
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let iconSize = AppFontMetrics.homeIconSize
    private let verticalPadding = AppFontMetrics.homeVerticalPadding

    var body: some View {
        ManagementScroll(
            title: localized(japanese: "帳票を作成", chinese: "建立表单", english: "Create Form"),
            subtitle: localized(
                japanese: "右側で作成する帳票を選び、下のリストから最近の案件と帳票をすぐに開けます。",
                chinese: "在右侧选择要建立的表单，也可以从下方列表快速打开最近项目与文件。",
                english: "Choose a form to create, or open recent projects and files below."
            ),
            actionTitle: localized(japanese: "表示する帳票", chinese: "显示表单", english: "Visible Forms"),
            actionSystemImage: "slider.horizontal.3",
            action: { isVisibilitySettingsPresented = true }
        ) {
            formDirectionSection(direction: .customer)
            formDirectionSection(direction: .vendor)
            recentPreviewStripSection(
                title: localized(japanese: "顧客向け 最近の帳票", chinese: "客户最近表单", english: "Recent Customer Forms"),
                documents: recentDocuments(for: .customer)
            )
            recentPreviewStripSection(
                title: localized(japanese: "仕入先向け 最近の帳票", chinese: "厂商最近表单", english: "Recent Vendor Forms"),
                documents: recentDocuments(for: .vendor)
            )
        }
        .overlay {
            if let heldPreviewDocument {
                heldDocumentPreviewOverlay(document: heldPreviewDocument)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: heldPreviewDocument?.id)
        .sheet(isPresented: $isVisibilitySettingsPresented) {
            FormVisibilitySettingsSheet(hiddenTypeStorage: $hiddenTypeStorage, language: language)
        }
    }

    private func formDirectionSection(direction: ProjectDirection) -> some View {
        SectionCard(title: createFormSectionTitle(for: direction), titleWeight: .regular) {
            VStack(alignment: .leading, spacing: 12) {
                Label(createFormSectionTitle(for: direction), systemImage: direction == .customer ? "person.crop.circle" : "shippingbox")
                    .font(AppFont.sectionTitle(.semibold))
                    .foregroundColor(.appMuted)

                let visibleTypes = visibleTypes(for: direction)
                if visibleTypes.isEmpty {
                    EmptyManagementText(text: localized(
                        japanese: "表示する帳票がありません。右上のボタンから表示する帳票を選択してください。",
                        chinese: "目前没有显示的表单。请点右上角按钮选择要显示的表单。",
                        english: "No forms are visible. Use the top-right button to choose forms to show."
                    ))
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(visibleTypes) { type in
                            formTypeButton(type)
                        }
                    }
                }
            }
        }
    }

    private func recentPreviewStripSection(title: String, documents: [BusinessDocument]) -> some View {
        SectionCard(title: title, titleWeight: .regular) {
            if documents.isEmpty {
                EmptyManagementText(text: localized(japanese: "最近の帳票はありません。", chinese: "没有最近表单。", english: "No recent forms."))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(documents) { document in
                            iPadHomeDocumentPreviewCard(
                                document: document,
                                language: language,
                                onPreviewHold: { document, image in
                                    showHeldPreview(for: document, image: image)
                                },
                                onPreviewRelease: {
                                    hideHeldPreview()
                                }
                            ) {
                                onOpenDocument(document)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func formTypeButton(_ type: DocumentType) -> some View {
        Button {
            onSelectForm(type)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName(for: type))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor(for: type))
                    .frame(width: iconSize, height: iconSize)
                    .background(accentColor(for: type).opacity(0.12))
                    .clipShape(Circle())

                Text(type.localizedTitle(language))
                    .font(AppFont.cardTitle(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, minHeight: iconSize + verticalPadding * 2, alignment: .leading)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func recentDocuments(for direction: ProjectDirection) -> [BusinessDocument] {
        Array(store.documents.filter { direction.requiredTypes.contains($0.type) }.sorted { $0.updatedAt > $1.updatedAt }.prefix(10))
    }

    private func showHeldPreview(for document: BusinessDocument, image: UIImage?) {
        heldPreviewDocument = document
        heldPreviewFailed = false
        if let image {
            heldPreviewImage = image
        }

        do {
            heldPreviewImage = try DocumentPDFExporter.previewImage(for: document, language: language, scale: 2)
        } catch {
            if heldPreviewImage == nil {
                heldPreviewImage = nil
            }
            heldPreviewFailed = true
        }
    }

    private func hideHeldPreview() {
        heldPreviewDocument = nil
        heldPreviewImage = nil
        heldPreviewFailed = false
    }

    private func heldDocumentPreviewOverlay(document: BusinessDocument) -> some View {
        GeometryReader { proxy in
            let previewHeight = proxy.size.height * 0.7
            let previewWidth = min(proxy.size.width * 0.9, previewHeight / 1.414)
            ZStack {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()

                Group {
                    if let heldPreviewImage {
                        Image(uiImage: heldPreviewImage)
                            .resizable()
                            .scaledToFit()
                    } else if heldPreviewFailed {
                        VStack(spacing: 10) {
                            Image(systemName: iconName(for: document.type))
                                .font(.largeTitle.weight(.semibold))
                                .foregroundColor(accentColor(for: document.type))
                            Text(document.type.localizedTitle(language))
                                .font(AppFont.cardTitle(.semibold))
                                .foregroundColor(.appInk)
                        }
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: previewWidth, height: previewHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func visibleTypes(for direction: ProjectDirection) -> [DocumentType] {
        let hiddenTypes = decodedHiddenTypes
        return direction.requiredTypes.filter { !hiddenTypes.contains($0) }
    }

    private var decodedHiddenTypes: Set<DocumentType> {
        guard let data = hiddenTypeStorage.data(using: .utf8),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(rawValues.compactMap(DocumentType.init(rawValue:)))
    }

    private func createFormSectionTitle(for direction: ProjectDirection) -> String {
        switch direction {
        case .customer:
            return localized(japanese: "顧客", chinese: "客户", english: "Customer")
        case .vendor:
            return localized(japanese: "取引先", chinese: "供应商", english: "Vendor")
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        case .vendorInvoice: return "doc.richtext.fill"
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
        case .acceptance: return Color(red: 0.212, green: 0.702, blue: 0.816)
        case .customerFiles: return Color(red: 0.431, green: 0.533, blue: 0.678)
        case .vendorEstimate: return Color(red: 0.145, green: 0.388, blue: 0.922)
        case .vendorInvoice: return Color(red: 0.349, green: 0.435, blue: 0.898)
        case .vendorReceipt: return Color(red: 0.212, green: 0.702, blue: 0.816)
        case .paymentNotice: return Color(red: 0.431, green: 0.533, blue: 0.678)
        }
    }
}

private struct iPadHomeDocumentPreviewCard: View {
    let document: BusinessDocument
    let language: AppLanguage
    let onPreviewHold: (BusinessDocument, UIImage?) -> Void
    let onPreviewRelease: () -> Void
    let onOpen: () -> Void

    @State private var thumbnail: UIImage?
    @State private var didFail = false
    @State private var isPressingPreview = false
    @State private var didTriggerHoldPreview = false
    @State private var previewPressTask: Task<Void, Never>?
    private let width: CGFloat = 186
    private let height: CGFloat = 264

    var body: some View {
        Button(action: openIfNotPreviewHold) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Color.white
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(width: width, height: height)
                    } else if didFail {
                        VStack(spacing: 8) {
                            Image(systemName: iconName(for: document.type))
                                .font(.title3.weight(.semibold))
                                .foregroundColor(accentColor(for: document.type))
                            Text(document.type.localizedTitle(language))
                                .font(AppFont.small(.semibold))
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
                        Text(projectDisplayName)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        Text(createdDateText)
                            .font(.system(size: 16, weight: .semibold))
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
                        .frame(height: 64),
                        alignment: .bottom
                    )
                }
                .frame(width: width, height: height)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)

                Text(document.type.localizedTitle(language))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    beginPreviewPress()
                }
                .onEnded { _ in
                    endPreviewPress()
                }
        )
        .task(id: taskID) {
            loadThumbnail()
        }
        .onDisappear {
            endPreviewPress()
        }
    }

    private var taskID: String {
        "\(document.id.uuidString)-\(document.updatedAt.timeIntervalSince1970)-\(language.rawValue)"
    }

    private var projectDisplayName: String {
        let projectName = document.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !projectName.isEmpty {
            return projectName
        }

        let customerName = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customerName.isEmpty {
            return customerName
        }

        return document.type.localizedTitle(language)
    }

    private var createdDateText: String {
        AppFormatters.shortDate(document.issueDate)
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

    private func beginPreviewPress() {
        guard !isPressingPreview else { return }
        isPressingPreview = true
        didTriggerHoldPreview = false
        previewPressTask?.cancel()
        previewPressTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, isPressingPreview else { return }
            didTriggerHoldPreview = true
            onPreviewHold(document, thumbnail)
        }
    }

    private func endPreviewPress() {
        guard isPressingPreview || previewPressTask != nil else { return }
        isPressingPreview = false
        previewPressTask?.cancel()
        previewPressTask = nil
        onPreviewRelease()
        resetHoldPreviewFlagSoon()
    }

    private func openIfNotPreviewHold() {
        guard !didTriggerHoldPreview else {
            didTriggerHoldPreview = false
            return
        }
        onOpen()
    }

    private func resetHoldPreviewFlagSoon() {
        guard didTriggerHoldPreview else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            didTriggerHoldPreview = false
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
        case .vendorInvoice: return "doc.richtext.fill"
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
        case .acceptance: return Color(red: 0.212, green: 0.702, blue: 0.816)
        case .customerFiles: return Color(red: 0.431, green: 0.533, blue: 0.678)
        case .vendorEstimate: return Color(red: 0.145, green: 0.388, blue: 0.922)
        case .vendorInvoice: return Color(red: 0.349, green: 0.435, blue: 0.898)
        case .vendorReceipt: return Color(red: 0.212, green: 0.702, blue: 0.816)
        case .paymentNotice: return Color(red: 0.431, green: 0.533, blue: 0.678)
        }
    }
}

private struct DeleteFormConfirmationVideoView: View {
    let onComplete: () -> Void

    @State private var player: AVPlayer?
    @State private var didComplete = false
    @State private var overlayOpacity = 0.0
    @State private var overlayScale = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                FullScreenAspectFillPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .opacity(overlayOpacity)
        .scaleEffect(overlayScale, anchor: .center)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                overlayOpacity = 1.0
                overlayScale = 1.0
            }

            guard player == nil else {
                player?.play()
                return
            }
            guard let url = Bundle.main.url(forResource: "DeleteFormConfirmationVideo", withExtension: "mov") else {
                completeOnce()
                return
            }
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let currentItem = player?.currentItem,
                  let endedItem = notification.object as? AVPlayerItem,
                  endedItem === currentItem else { return }
            completeOnce()
        }
    }

    private func completeOnce() {
        guard !didComplete else { return }
        didComplete = true
        player?.pause()
        withAnimation(.easeOut(duration: 0.3)) {
            overlayOpacity = 0.0
            overlayScale = 0.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }
}

private struct FullScreenAspectFillPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerContainerView {
        let view = PlayerLayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerLayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspectFill
    }
}

private final class PlayerLayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private struct FormVisibilitySettingsSheet: View {
    @Binding var hiddenTypeStorage: String
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(localizedShowAllTitle) {
                        hiddenTypes = []
                    }
                    Button(localizedHideAllTitle) {
                        hiddenTypes = Set(allTypes)
                    }
                }

                visibilitySection(direction: .customer)
                visibilitySection(direction: .vendor)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedDoneTitle) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func visibilitySection(direction: ProjectDirection) -> some View {
        Section(header: Text(visibilitySectionTitle(for: direction))) {
            ForEach(direction.requiredTypes) { type in
                Toggle(isOn: visibilityBinding(for: type)) {
                    Label(visibilityTitle(for: type), systemImage: iconName(for: type))
                }
            }
        }
    }

    private func visibilityBinding(for type: DocumentType) -> Binding<Bool> {
        Binding(
            get: { !hiddenTypes.contains(type) },
            set: { isVisible in
                var updatedHiddenTypes = hiddenTypes
                if isVisible {
                    updatedHiddenTypes.remove(type)
                } else {
                    updatedHiddenTypes.insert(type)
                }
                hiddenTypes = updatedHiddenTypes
            }
        )
    }

    private var allTypes: [DocumentType] {
        ProjectDirection.customer.requiredTypes + ProjectDirection.vendor.requiredTypes
    }

    private var hiddenTypes: Set<DocumentType> {
        get {
            guard let data = hiddenTypeStorage.data(using: .utf8),
                  let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return Set(rawValues.compactMap(DocumentType.init(rawValue:)))
        }
        nonmutating set {
            let rawValues = newValue.map(\.rawValue).sorted()
            guard let data = try? JSONEncoder().encode(rawValues),
                  let encoded = String(data: data, encoding: .utf8) else {
                hiddenTypeStorage = "[]"
                return
            }
            hiddenTypeStorage = encoded
        }
    }

    private var localizedTitle: String {
        localized(japanese: "表示する帳票", chinese: "显示表单", english: "Visible Forms")
    }

    private var localizedShowAllTitle: String {
        localized(japanese: "すべて表示", chinese: "全部显示", english: "Show All")
    }

    private var localizedHideAllTitle: String {
        localized(japanese: "すべて非表示", chinese: "全部隐藏", english: "Hide All")
    }

    private var localizedDoneTitle: String {
        localized(japanese: "完了", chinese: "完成", english: "Done")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }

    private func visibilitySectionTitle(for direction: ProjectDirection) -> String {
        switch direction {
        case .customer:
            return localized(japanese: "顧客", chinese: "客户", english: "Customer")
        case .vendor:
            return localized(japanese: "取引先", chinese: "供应商", english: "Vendor")
        }
    }

    private func visibilityTitle(for type: DocumentType) -> String {
        switch type {
        case .customerOrder:
            return localized(japanese: "受注ファイル", chinese: "受注文件", english: "Order File")
        case .vendorEstimate:
            return localized(japanese: "見積書ファイル", chinese: "报价单文件", english: "Quote File")
        case .vendorInvoice:
            return localized(japanese: "請求書ファイル", chinese: "请款书文件", english: "Invoice File")
        case .vendorReceipt:
            return localized(japanese: "領収書ファイル", chinese: "收据文件", english: "Receipt File")
        default:
            return type.localizedTitle(language)
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
        case .vendorInvoice: return "doc.richtext.fill"
        case .vendorReceipt: return "checkmark.rectangle.stack.fill"
        case .paymentNotice: return "yensign.circle.fill"
        }
    }
}

private struct EmptyPDFPreviewScreen: View {
    let language: AppLanguage
    let onCreate: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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
            previewPageBackground

            Image("EmptyPDFPreviewBackground")
                .resizable()
                .scaledToFill()
                .opacity(backgroundImageOpacity)

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
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(primaryActionBackground)
                        .foregroundColor(primaryActionForeground)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 22)
        }
        .frame(width: pageWidth)
        .aspectRatio(0.707, contentMode: .fit)
        .clipped()
        .background(previewPageBackground)
        .cornerRadius(2)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appDivider))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var previewPageBackground: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private var backgroundImageOpacity: Double {
        colorScheme == .dark ? 0.66 : 0.42
    }

    private var primaryActionBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.appInk
    }

    private var primaryActionForeground: Color {
        colorScheme == .dark ? Color.white : Color.white
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
                    dataButton(title: localizedReportTitle, subtitle: localizedReportSubtitle, systemImage: "square.and.arrow.up.on.square", section: .reports)
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
    private var localizedReportTitle: String { localized(japanese: "レポート出力", chinese: "输出报告", english: "Export Reports") }
    private var localizedCompanySubtitle: String { localized(japanese: "自社情報、登録番号、連絡先", chinese: "公司信息、登记编号、联系人", english: "Company details and registration") }
    private var localizedFileSubtitle: String { localized(japanese: "保存済み帳票を取引先別に整理", chinese: "按客户/供应商整理已保存表单", english: "Browse saved forms by partner") }
    private var localizedProjectSubtitle: String { localized(japanese: "プロジェクト別の帳票進捗", chinese: "按项目管理表单进度", english: "Track forms by project") }
    private var localizedCustomerSubtitle: String { localized(japanese: "取引先・仕入先の候補", chinese: "客户/供应商候选资料", english: "Customer and vendor profiles") }
    private var localizedProductSubtitle: String { localized(japanese: "商品・項目の候補", chinese: "商品/品项候选资料", english: "Product and item profiles") }
    private var localizedTemplateSubtitle: String { localized(japanese: "振込、備考、条件文", chinese: "汇款、备注、条件文字", english: "Payment, notes, and terms") }
    private var localizedStampSubtitle: String { localized(japanese: "PDF押印用の初期印章", chinese: "PDF 盖章用默认印章", english: "Default stamp for PDF stamping") }
    private var localizedReportSubtitle: String { localized(japanese: "帳票、案件、取引先の集計設計", chinese: "表单、项目、客户的汇总设计", english: "Report designs for forms, projects, and partners") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private struct ReportExportScreen: View {
    @ObservedObject var store: DocumentStore
    let language: AppLanguage
    let onBack: () -> Void
    let onPreviewDocument: (BusinessDocument) -> Void
    let onEditDocument: (BusinessDocument) -> Void
    @State private var selectedReport: ReportDesign?
    @State private var selectedDataList: ReportDataListKind?
    @State private var completingTask: ReportDashboardTask?
    @State private var isCompleteConfirmationPresented = false
    @State private var sharePayload: SharePayload?
    @State private var exportError = ""
    @State private var isExportErrorPresented = false
    @AppStorage("native.shokoForms.completedReportTaskIDs.v1") private var completedTaskIDsRaw = ""

    private var reports: [ReportDesign] {
        ReportDesign.templates(language: language, store: store)
    }

    private var completedTaskIDs: Set<String> {
        Set(completedTaskIDsRaw.split(separator: ",").map(String.init))
    }

    private var dashboardTasks: [ReportDashboardTask] {
        store.documents
            .filter { !$0.type.isAttachmentRecord }
            .compactMap { ReportDashboardTask(document: $0, language: language) }
            .filter { !completedTaskIDs.contains($0.id) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var customerReceivableTotal: Double {
        dashboardTasks.filter { $0.kind == .receivable }.reduce(0) { $0 + $1.amount }
    }

    private var vendorPayableTotal: Double {
        dashboardTasks.filter { $0.kind == .payable }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ManagementScroll(title: localizedTitle, subtitle: localizedSubtitle, onBack: onBack) {
            SectionCard(title: localizedDashboardTitle, titleWeight: .regular) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        dashboardMetric(title: localizedReceivableMetric, value: currencyText(customerReceivableTotal), systemImage: "tray.and.arrow.down.fill", tint: .appBlue)
                        dashboardMetric(title: localizedPayableMetric, value: currencyText(vendorPayableTotal), systemImage: "creditcard.fill", tint: .appMint)
                    }
                    dashboardMetric(title: localizedPendingMetric, value: "\(dashboardTasks.count)", systemImage: "checklist", tint: .orange)
                }
            }

            SectionCard(title: localizedOverviewTitle, titleWeight: .regular) {
                VStack(spacing: 10) {
                    Button {
                        selectedDataList = .documents
                    } label: {
                        ReportDataSummaryRow(title: localizedFormsMetric, detail: localizedFormsDetail, value: "\(store.documents.count)", systemImage: "doc.text", csvTitle: localizedCSVActionTitle) {
                            exportCSV(.documents)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        selectedDataList = .projects
                    } label: {
                        ReportDataSummaryRow(title: localizedProjectsMetric, detail: localizedProjectsDetail, value: "\(store.projects.count)", systemImage: "folder", csvTitle: localizedCSVActionTitle) {
                            exportCSV(.projects)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        selectedDataList = .partners
                    } label: {
                        ReportDataSummaryRow(title: localizedPartnersMetric, detail: localizedPartnersDetail, value: "\(store.customers.count)", systemImage: "building.2", csvTitle: localizedCSVActionTitle) {
                            exportCSV(.partners)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        selectedDataList = .products
                    } label: {
                        ReportDataSummaryRow(title: localizedProductsMetric, detail: localizedProductsDetail, value: "\(store.products.count)", systemImage: "shippingbox", csvTitle: localizedCSVActionTitle) {
                            exportCSV(.products)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            SectionCard(title: localizedListTitle, titleWeight: .regular) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(localizedListHelp)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(reports) { report in
                        ReportDesignCard(report: report, language: language) {
                            selectedReport = report
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedReport) { report in
            ReportConfigurationSheet(store: store, report: report, language: language)
        }
        .sheet(item: $selectedDataList) { listKind in
            ReportDataListSheet(store: store, kind: listKind, language: language)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
        .alert(localizedExportErrorTitle, isPresented: $isExportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError)
        }
        .confirmationDialog(localizedCompleteConfirmTitle, isPresented: $isCompleteConfirmationPresented, titleVisibility: .visible) {
            Button(localizedCompleteActionTitle) {
                if let completingTask {
                    complete(completingTask)
                }
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(completingTask?.partner ?? "")
        }
    }

    private func dashboardMetric(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                Text(value)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func reportTaskRow(_ task: ReportDashboardTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: task.kind == .receivable ? "tray.and.arrow.down.fill" : "creditcard.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(task.kind == .receivable ? .appBlue : .appMint)
                    .frame(width: 36, height: 36)
                    .background((task.kind == .receivable ? Color.appBlue : Color.appMint).opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.partner)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                    Text("\(task.kind.localizedTitle(language)) / \(task.document.type.localizedTitle(language)) / \(AppFormatters.shortDate(task.dueDate))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                }
                Spacer()
                Text(currencyText(task.amount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button {
                    onPreviewDocument(task.document)
                } label: {
                    Label(localizedPreviewActionTitle, systemImage: "doc.richtext")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.appBlue)
                .background(Color.appBlue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    onEditDocument(task.document)
                } label: {
                    Label(localizedEditActionTitle, systemImage: "square.and.pencil")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.appInk)
                .background(Color.appInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    completingTask = task
                    isCompleteConfirmationPresented = true
                } label: {
                    Label(localizedCompleteActionTitle, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)
                .background(Color.appMint)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.appInputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func complete(_ task: ReportDashboardTask) {
        var ids = completedTaskIDs
        ids.insert(task.id)
        completedTaskIDsRaw = ids.sorted().joined(separator: ",")
        completingTask = nil
    }

    private func currencyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "JPY \(Int(value))"
    }

    private func exportCSV(_ kind: ReportDataListKind) {
        do {
            sharePayload = SharePayload(url: try ReportDataCSVExporter.export(kind: kind, store: store, language: language))
        } catch {
            exportError = localized(japanese: "CSVを書き出せませんでした。", chinese: "无法输出 CSV。", english: "Could not export CSV.")
            isExportErrorPresented = true
        }
    }

    private var localizedTitle: String { localized(japanese: "レポート出力", chinese: "输出报告", english: "Export Reports") }
    private var localizedSubtitle: String {
        localized(
            japanese: "Shoko Forms の業務データから作成できるレポート設計を確認します。",
            chinese: "查看可根据 Shoko Forms 业务数据设计的报告清单。",
            english: "Review report designs that can be generated from Shoko Forms business data."
        )
    }
    private var localizedOverviewTitle: String { localized(japanese: "現在のデータ", chinese: "当前数据", english: "Current Data") }
    private var localizedListTitle: String { localized(japanese: "設計できるレポート", chinese: "可设计的报告", english: "Report Designs") }
    private var localizedDashboardTitle: String { localized(japanese: "入出金ダッシュボード", chinese: "收付款仪表板", english: "Cashflow Dashboard") }
    private var localizedTaskListTitle: String { localized(japanese: "未処理タスク", chinese: "待处理任务", english: "Open Tasks") }
    private var localizedReceivableMetric: String { localized(japanese: "顧客からの未収", chinese: "客户待收款", english: "Customer Receivables") }
    private var localizedPayableMetric: String { localized(japanese: "仕入先への未払", chinese: "厂商待付款", english: "Vendor Payables") }
    private var localizedPendingMetric: String { localized(japanese: "待处理件数", chinese: "待处理件数", english: "Open Items") }
    private var localizedEmptyTaskText: String { localized(japanese: "未処理の入出金タスクはありません。", chinese: "目前没有待处理的收付款任务。", english: "No open cashflow tasks.") }
    private var localizedPreviewActionTitle: String { localized(japanese: "プレビュー", chinese: "预览", english: "Preview") }
    private var localizedEditActionTitle: String { localized(japanese: "編集", chinese: "修改", english: "Edit") }
    private var localizedCompleteActionTitle: String { localized(japanese: "完了", chinese: "完成", english: "Complete") }
    private var localizedCompleteConfirmTitle: String { localized(japanese: "完了にしますか？", chinese: "确认已经完成？", english: "Mark Complete?") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedCSVActionTitle: String { localized(japanese: "CSV", chinese: "CSV", english: "CSV") }
    private var localizedExportErrorTitle: String { localized(japanese: "出力エラー", chinese: "输出错误", english: "Export Error") }
    private var localizedListHelp: String {
        localized(
            japanese: "各レポートは期間、取引先、プロジェクト、帳票種類などで絞り込める想定です。CSV、PDF、表計算出力に拡張できます。",
            chinese: "每个报告都可按期间、客户/供应商、项目、表单类型等条件筛选，后续可扩展为 CSV、PDF 或表格输出。",
            english: "Each report can be filtered by period, partner, project, and form type, then expanded to CSV, PDF, or spreadsheet export."
        )
    }
    private var localizedFormsMetric: String { localized(japanese: "保存済み帳票", chinese: "已保存表单", english: "Saved Forms") }
    private var localizedProjectsMetric: String { localized(japanese: "プロジェクト", chinese: "项目", english: "Projects") }
    private var localizedPartnersMetric: String { localized(japanese: "取引先候補", chinese: "客户/供应商", english: "Partner Profiles") }
    private var localizedProductsMetric: String { localized(japanese: "商品候補", chinese: "商品", english: "Products") }
    private var localizedFormsDetail: String {
        localized(
            japanese: "請求書、領収書、見積書、仕入先請求書など。売上、入金、未収、支払レポートの主データです。",
            chinese: "请款书、收据、报价单、厂商请款书等，是收入、收款、未收与付款报告的主要资料。",
            english: "Invoices, receipts, quotes, and vendor invoices used by revenue, payment, receivable, and payable reports."
        )
    }
    private var localizedProjectsDetail: String {
        localized(
            japanese: "関連帳票を案件単位でまとめます。案件別収支、進捗、粗利の確認に使います。",
            chinese: "把相关表单按项目归组，用于项目收支、进度和毛利确认。",
            english: "Groups related forms by project for project income, cost, progress, and margin review."
        )
    }
    private var localizedPartnersDetail: String {
        localized(
            japanese: "顧客・仕入先の候補データ。取引先別の請求、入金、支払集計に使います。",
            chinese: "客户与厂商候选资料，用于按交易对象汇总请款、收款和付款。",
            english: "Customer and vendor candidates used for partner-based billing, payment, and collection summaries."
        )
    }
    private var localizedProductsDetail: String {
        localized(
            japanese: "帳票明細で使う商品・項目候補。カテゴリ別、商品別の集計に使います。",
            chinese: "表单明细使用的商品/品项候选资料，用于类别或商品别汇总。",
            english: "Product and item candidates used by category and product summaries."
        )
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private struct ReportDashboardTask: Identifiable {
    enum Kind {
        case receivable
        case payable

        func localizedTitle(_ language: AppLanguage) -> String {
            switch self {
            case .receivable:
                switch language {
                case .japanese: return "未収"
                case .simplifiedChinese, .traditionalChinese: return "待收款"
                case .english, .korean, .nepali, .french, .vietnamese: return "Receivable"
                }
            case .payable:
                switch language {
                case .japanese: return "未払"
                case .simplifiedChinese, .traditionalChinese: return "待付款"
                case .english, .korean, .nepali, .french, .vietnamese: return "Payable"
                }
            }
        }
    }

    let id: String
    let kind: Kind
    let document: BusinessDocument
    let partner: String
    let amount: Double
    let dueDate: Date

    init?(document: BusinessDocument, language: AppLanguage) {
        switch document.type {
        case .invoice:
            kind = .receivable
        case .purchaseOrder, .vendorInvoice, .paymentNotice:
            kind = .payable
        default:
            return nil
        }

        self.id = document.id.uuidString
        self.document = document
        self.partner = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? document.type.localizedTitle(language)
            : document.customerName
        self.amount = document.total
        self.dueDate = document.type.showsDueDate ? document.dueDate : document.transactionDate
    }
}

private struct ReportDesign: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let source: String
    let filters: [String]
    let columns: [String]
    let recordCount: Int

    static func templates(language: AppLanguage, store: DocumentStore) -> [ReportDesign] {
        let customerRevenueTypes: Set<DocumentType> = [.estimate, .customerOrder, .delivery, .invoice, .receipt]
        let vendorCostTypes: Set<DocumentType> = [.vendorEstimate, .purchaseOrder, .acceptance, .vendorInvoice, .vendorReceipt]

        return [
            ReportDesign(
                id: "customer-payment-history",
                title: localized(language, japanese: "顧客別入金・未収レポート", chinese: "客户别收款与未收报告", english: "Customer Payment and Receivables Report"),
                subtitle: localized(language, japanese: "指定期間と顧客を選び、請求済み・入金済み・未収の記録を確認します。", chinese: "选择某段时间和某一个客户，查看已请款、已收款、未收款纪录。", english: "Choose a period and customer to review invoiced, paid, and unpaid records."),
                systemImage: "person.crop.circle.badge.checkmark",
                source: localized(language, japanese: "請求書・領収書", chinese: "请款书与收据", english: "Invoices and receipts"),
                filters: customerPaymentFilters(language),
                columns: [
                    localized(language, japanese: "請求日", chinese: "请款日", english: "Invoice date"),
                    localized(language, japanese: "入金日", chinese: "收款日", english: "Payment date"),
                    localized(language, japanese: "取引先", chinese: "客户", english: "Customer"),
                    localized(language, japanese: "帳票番号", chinese: "表单编号", english: "Form number"),
                    localized(language, japanese: "請求額", chinese: "请款金额", english: "Invoice amount"),
                    localized(language, japanese: "入金状態", chinese: "收款状态", english: "Payment status")
                ],
                recordCount: store.documents.filter { $0.type == .invoice || $0.type == .receipt }.count
            ),
            ReportDesign(
                id: "all-customer-income",
                title: localized(language, japanese: "全顧客売上・入金集計", chinese: "全部客户收入与收款汇总", english: "All Customer Revenue and Payments"),
                subtitle: localized(language, japanese: "指定期間の全顧客について、売上、請求、入金、未収を顧客別・月別に集計します。", chinese: "汇总某段时间全部客户的收入、请款、收款和未收，可按客户或月份查看。", english: "Summarizes revenue, invoicing, payments, and receivables for all customers over a period."),
                systemImage: "chart.bar.xaxis",
                source: localized(language, japanese: "顧客向け帳票", chinese: "客户向表单", english: "Customer-facing forms"),
                filters: periodCategoryFilters(language) + [localized(language, japanese: "集計単位", chinese: "汇总单位", english: "Group by")],
                columns: [
                    localized(language, japanese: "取引先", chinese: "客户", english: "Customer"),
                    localized(language, japanese: "期間", chinese: "期间", english: "Period"),
                    localized(language, japanese: "売上額", chinese: "收入金额", english: "Revenue"),
                    localized(language, japanese: "請求額", chinese: "请款金额", english: "Billed"),
                    localized(language, japanese: "入金額", chinese: "收款金额", english: "Received"),
                    localized(language, japanese: "未収額", chinese: "未收金额", english: "Outstanding")
                ],
                recordCount: store.documents.filter { customerRevenueTypes.contains($0.type) }.count
            ),
            ReportDesign(
                id: "vendor-billing-payment",
                title: localized(language, japanese: "仕入先請求・支払レポート", chinese: "厂商请款与付款报告", english: "Vendor Billing and Payment Report"),
                subtitle: localized(language, japanese: "指定期間と仕入先を選び、仕入先からの請求、支払済み、未払を確認します。", chinese: "选择某段时间和某个厂商，查看厂商请款、已付款和未付款纪录。", english: "Choose a period and vendor to review vendor invoices, paid amounts, and unpaid payables."),
                systemImage: "building.2.crop.circle",
                source: localized(language, japanese: "仕入先請求書・領収書", chinese: "厂商请款书与收据", english: "Vendor invoices and receipts"),
                filters: vendorPaymentFilters(language),
                columns: [
                    localized(language, japanese: "請求日", chinese: "请款日", english: "Invoice date"),
                    localized(language, japanese: "支払日", chinese: "付款日", english: "Payment date"),
                    localized(language, japanese: "仕入先", chinese: "供应商", english: "Vendor"),
                    localized(language, japanese: "請求番号", chinese: "请款编号", english: "Invoice number"),
                    localized(language, japanese: "請求額", chinese: "请款金额", english: "Billed"),
                    localized(language, japanese: "支払状態", chinese: "付款状态", english: "Payment status")
                ],
                recordCount: store.documents.filter { $0.type == .vendorInvoice || $0.type == .vendorReceipt }.count
            ),
            ReportDesign(
                id: "all-vendor-payables",
                title: localized(language, japanese: "全仕入先請求・支払集計", chinese: "全部厂商请款与付款汇总", english: "All Vendor Billing and Payables"),
                subtitle: localized(language, japanese: "指定期間の全仕入先について、請求、支払、未払を仕入先別・月別に集計します。", chinese: "汇总某段时间全部厂商的请款、付款和未付款，可按厂商或月份查看。", english: "Summarizes vendor billing, payments, and unpaid payables for all vendors over a period."),
                systemImage: "chart.pie",
                source: localized(language, japanese: "仕入先向け帳票", chinese: "供应商向表单", english: "Vendor-facing forms"),
                filters: periodCategoryFilters(language) + [localized(language, japanese: "集計単位", chinese: "汇总单位", english: "Group by")],
                columns: [
                    localized(language, japanese: "仕入先", chinese: "供应商", english: "Vendor"),
                    localized(language, japanese: "期間", chinese: "期间", english: "Period"),
                    localized(language, japanese: "仕入額", chinese: "采购金额", english: "Purchase amount"),
                    localized(language, japanese: "請求額", chinese: "请款金额", english: "Billed"),
                    localized(language, japanese: "支払額", chinese: "付款金额", english: "Paid"),
                    localized(language, japanese: "未払額", chinese: "未付款金额", english: "Unpaid")
                ],
                recordCount: store.documents.filter { vendorCostTypes.contains($0.type) }.count
            ),
            ReportDesign(
                id: "category-cashflow",
                title: localized(language, japanese: "カテゴリ別入出金レポート", chinese: "类别别收入与支出报告", english: "Category Cashflow Report"),
                subtitle: localized(language, japanese: "帳票種類、商品カテゴリ、案件カテゴリなどの分類で、入金・支払の有無と金額を確認します。", chinese: "按表单类型、商品类别或项目类别，查看是否有收款/付款纪录和金额。", english: "Checks payment presence and amounts by form type, product category, or project category."),
                systemImage: "square.grid.2x2",
                source: localized(language, japanese: "帳票・明細・プロジェクト", chinese: "表单、明细与项目", english: "Forms, line items, and projects"),
                filters: periodCategoryFilters(language) + [
                    localized(language, japanese: "カテゴリ種類", chinese: "类别种类", english: "Category type"),
                    localized(language, japanese: "入出金状態", chinese: "收付款状态", english: "Cashflow status")
                ],
                columns: [
                    localized(language, japanese: "カテゴリ", chinese: "类别", english: "Category"),
                    localized(language, japanese: "件数", chinese: "件数", english: "Count"),
                    localized(language, japanese: "入金額", chinese: "收款金额", english: "Received"),
                    localized(language, japanese: "支払額", chinese: "付款金额", english: "Paid"),
                    localized(language, japanese: "差額", chinese: "差额", english: "Net amount")
                ],
                recordCount: store.documents.count
            ),
            ReportDesign(
                id: "unpaid-unreceived",
                title: localized(language, japanese: "未収・未払リスト", chinese: "未收与未付款列表", english: "Outstanding Receivables and Payables"),
                subtitle: localized(language, japanese: "期間内または期限超過の未収金、仕入先への未払金を一覧で確認します。", chinese: "列出某段时间内或已过期的未收款，以及对厂商的未付款。", english: "Lists unpaid customer receivables and unpaid vendor payables within or past a period."),
                systemImage: "exclamationmark.circle",
                source: localized(language, japanese: "請求書・仕入先請求書", chinese: "请款书与厂商请款书", english: "Customer and vendor invoices"),
                filters: [
                    localized(language, japanese: "期間", chinese: "期间", english: "Period"),
                    localized(language, japanese: "期限超過のみ", chinese: "只看逾期", english: "Overdue only"),
                    localized(language, japanese: "顧客/仕入先", chinese: "客户/厂商", english: "Customer/vendor"),
                    localized(language, japanese: "金額範囲", chinese: "金额范围", english: "Amount range"),
                    localized(language, japanese: "出力形式", chinese: "输出格式", english: "Export format")
                ],
                columns: [
                    localized(language, japanese: "区分", chinese: "区分", english: "Type"),
                    localized(language, japanese: "期限", chinese: "期限", english: "Due date"),
                    localized(language, japanese: "取引先", chinese: "客户/厂商", english: "Partner"),
                    localized(language, japanese: "帳票番号", chinese: "表单编号", english: "Form number"),
                    localized(language, japanese: "未決済額", chinese: "未结算金额", english: "Outstanding amount")
                ],
                recordCount: store.documents.filter { $0.type == .invoice || $0.type == .vendorInvoice }.count
            ),
            ReportDesign(
                id: "project-profit",
                title: localized(language, japanese: "案件別収支レポート", chinese: "项目别收支报告", english: "Project Income and Cost Report"),
                subtitle: localized(language, japanese: "案件ごとに顧客からの入金、仕入先への支払、粗利を比較します。", chinese: "按项目比较客户收入、厂商支出和毛利。", english: "Compares customer income, vendor costs, and gross margin by project."),
                systemImage: "folder.badge.gearshape",
                source: localized(language, japanese: "プロジェクト帳票", chinese: "项目表单", english: "Project forms"),
                filters: periodCategoryFilters(language) + [
                    localized(language, japanese: "案件", chinese: "项目", english: "Project"),
                    localized(language, japanese: "収支状態", chinese: "收支状态", english: "Profit status")
                ],
                columns: [
                    localized(language, japanese: "案件名", chinese: "项目名", english: "Project name"),
                    localized(language, japanese: "顧客入金", chinese: "客户收款", english: "Customer received"),
                    localized(language, japanese: "仕入支払", chinese: "厂商付款", english: "Vendor paid"),
                    localized(language, japanese: "未収・未払", chinese: "未收/未付", english: "Outstanding"),
                    localized(language, japanese: "粗利", chinese: "毛利", english: "Gross margin")
                ],
                recordCount: store.projects.count
            ),
            ReportDesign(
                id: "form-type-summary",
                title: localized(language, japanese: "帳票種類別集計", chinese: "表单类别汇总", english: "Form Type Summary"),
                subtitle: localized(language, japanese: "見積、請求、領収、仕入先請求など、帳票カテゴリごとの件数と金額を指定期間で確認します。", chinese: "按报价、请款、收据、厂商请款等表单类别，查看某段时间的件数和金额。", english: "Reviews counts and amounts by form category, such as quotes, invoices, receipts, and vendor invoices."),
                systemImage: "doc.on.doc",
                source: localized(language, japanese: "すべての帳票", chinese: "全部表单", english: "All forms"),
                filters: periodCategoryFilters(language) + [
                    localized(language, japanese: "帳票種類", chinese: "表单类型", english: "Form type"),
                    localized(language, japanese: "顧客/仕入先", chinese: "客户/厂商", english: "Customer/vendor")
                ],
                columns: [
                    localized(language, japanese: "帳票種類", chinese: "表单类型", english: "Form type"),
                    localized(language, japanese: "件数", chinese: "件数", english: "Count"),
                    localized(language, japanese: "税抜合計", chinese: "未税合计", english: "Subtotal"),
                    localized(language, japanese: "税込合計", chinese: "含税合计", english: "Total"),
                    localized(language, japanese: "決済状態", chinese: "结算状态", english: "Settlement status")
                ],
                recordCount: store.documents.count
            )
        ]
    }

    private static func customerPaymentFilters(_ language: AppLanguage) -> [String] {
        [
            localized(language, japanese: "期間", chinese: "期间", english: "Period"),
            localized(language, japanese: "顧客", chinese: "客户", english: "Customer"),
            localized(language, japanese: "帳票カテゴリ", chinese: "表单类别", english: "Form category"),
            localized(language, japanese: "入金状態", chinese: "收款状态", english: "Payment status"),
            localized(language, japanese: "出力形式", chinese: "输出格式", english: "Export format")
        ]
    }

    private static func vendorPaymentFilters(_ language: AppLanguage) -> [String] {
        [
            localized(language, japanese: "期間", chinese: "期间", english: "Period"),
            localized(language, japanese: "仕入先", chinese: "厂商", english: "Vendor"),
            localized(language, japanese: "帳票カテゴリ", chinese: "表单类别", english: "Form category"),
            localized(language, japanese: "支払状態", chinese: "付款状态", english: "Payment status"),
            localized(language, japanese: "出力形式", chinese: "输出格式", english: "Export format")
        ]
    }

    private static func periodCategoryFilters(_ language: AppLanguage) -> [String] {
        [
            localized(language, japanese: "期間", chinese: "期间", english: "Period"),
            localized(language, japanese: "顧客/仕入先", chinese: "客户/厂商", english: "Customer/vendor"),
            localized(language, japanese: "カテゴリ", chinese: "类别", english: "Category"),
            localized(language, japanese: "出力言語", chinese: "输出语言", english: "Output language"),
            localized(language, japanese: "出力形式", chinese: "输出格式", english: "Export format")
        ]
    }

    private static func localized(_ language: AppLanguage, japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private extension ReportDesign {
    var isVendorReport: Bool {
        id == "vendor-billing-payment" || id == "all-vendor-payables"
    }

    var supportsGrouping: Bool {
        id == "all-customer-income" ||
            id == "all-vendor-payables" ||
            id == "category-cashflow" ||
            id == "project-profit" ||
            id == "form-type-summary"
    }

    func matches(_ document: BusinessDocument) -> Bool {
        switch id {
        case "customer-payment-history":
            return document.type == .invoice || document.type == .receipt
        case "all-customer-income":
            return Set<DocumentType>([.estimate, .customerOrder, .delivery, .invoice, .receipt]).contains(document.type)
        case "vendor-billing-payment":
            return document.type == .vendorInvoice || document.type == .vendorReceipt
        case "all-vendor-payables":
            return Set<DocumentType>([.vendorEstimate, .purchaseOrder, .acceptance, .vendorInvoice, .vendorReceipt]).contains(document.type)
        case "category-cashflow", "form-type-summary":
            return true
        case "unpaid-unreceived":
            return document.type == .invoice || document.type == .vendorInvoice
        case "project-profit":
            return document.projectId != nil
        default:
            return true
        }
    }
}

private struct ReportMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
                .frame(width: 36, height: 36)
                .background(Color.appInputBackground)
                .clipShape(Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
            Spacer()
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

private struct ReportDataSummaryRow: View {
    let title: String
    let detail: String
    let value: String
    let systemImage: String
    let csvTitle: String
    let onExportCSV: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
                .frame(width: 36, height: 36)
                .background(Color.appInputBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    HStack(spacing: 8) {
                        Text(value)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appInk)
                            .lineLimit(1)
                        Button {
                            onExportCSV()
                        } label: {
                            Label(csvTitle, systemImage: "square.and.arrow.down")
                                .font(.caption.weight(.semibold))
                                .labelStyle(.iconOnly)
                                .foregroundColor(.appBlue)
                                .frame(width: 34, height: 34)
                                .background(Color.appBlue.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .accessibilityLabel(Text(csvTitle))
                    }
                }

                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

private enum ReportDataListKind: String, Identifiable {
    case documents
    case projects
    case partners
    case products

    var id: String { rawValue }
}

private struct ReportDataListSheet: View {
    @ObservedObject var store: DocumentStore
    let kind: ReportDataListKind
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: SharePayload?
    @State private var exportError = ""
    @State private var isExportErrorPresented = false

    var body: some View {
        NavigationView {
            ScrollView {
                SectionCard(title: localizedCountTitle, titleWeight: .regular) {
                    VStack(spacing: 10) {
                        content
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedDoneTitle) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        exportCSV()
                    } label: {
                        Label(localizedCSVTitle, systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
        .alert(localizedExportErrorTitle, isPresented: $isExportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .documents:
            if store.documents.isEmpty {
                EmptyManagementText(text: localizedEmptyText)
            } else {
                ForEach(store.documents.sorted { $0.updatedAt > $1.updatedAt }) { document in
                    ReportDataListRow(
                        systemImage: document.type.isVendorForm ? "building.2" : "doc.text",
                        title: documentTitle(document),
                        subtitle: documentSubtitle(document),
                        value: AppFormatters.yen(document.total, language: language)
                    )
                }
            }
        case .projects:
            if store.projects.isEmpty {
                EmptyManagementText(text: localizedEmptyText)
            } else {
                ForEach(store.projects) { project in
                    ReportDataListRow(
                        systemImage: "folder",
                        title: project.name,
                        subtitle: projectSubtitle(project),
                        value: "\(project.documents.count)"
                    )
                }
            }
        case .partners:
            if store.customers.isEmpty {
                EmptyManagementText(text: localizedEmptyText)
            } else {
                ForEach(store.customers.sorted { $0.updatedAt > $1.updatedAt }) { customer in
                    ReportDataListRow(
                        systemImage: "building.2",
                        title: customer.name,
                        subtitle: partnerSubtitle(customer),
                        value: AppFormatters.shortDate(customer.updatedAt)
                    )
                }
            }
        case .products:
            if store.products.isEmpty {
                EmptyManagementText(text: localizedEmptyText)
            } else {
                ForEach(store.products.sorted { $0.updatedAt > $1.updatedAt }) { product in
                    ReportDataListRow(
                        systemImage: "shippingbox",
                        title: product.name,
                        subtitle: productSubtitle(product),
                        value: AppFormatters.yen(product.unitPrice, language: language)
                    )
                }
            }
        }
    }

    private var localizedTitle: String {
        switch kind {
        case .documents: return localized(japanese: "保存済み帳票", chinese: "已保存表单", english: "Saved Forms")
        case .projects: return localized(japanese: "プロジェクト", chinese: "项目", english: "Projects")
        case .partners: return localized(japanese: "取引先候補", chinese: "客户/供应商", english: "Partner Profiles")
        case .products: return localized(japanese: "商品候補", chinese: "商品", english: "Products")
        }
    }

    private var localizedCountTitle: String {
        localized(japanese: "全部リスト（\(recordCount)件）", chinese: "全部列表（\(recordCount) 件）", english: "Full List (\(recordCount))")
    }

    private var localizedEmptyText: String {
        localized(japanese: "表示できるデータがありません。", chinese: "没有可显示的数据。", english: "No data to show.")
    }

    private var localizedDoneTitle: String {
        localized(japanese: "完了", chinese: "完成", english: "Done")
    }

    private var localizedCSVTitle: String {
        localized(japanese: "CSV", chinese: "CSV", english: "CSV")
    }

    private var localizedExportErrorTitle: String {
        localized(japanese: "出力エラー", chinese: "输出错误", english: "Export Error")
    }

    private var recordCount: Int {
        switch kind {
        case .documents: return store.documents.count
        case .projects: return store.projects.count
        case .partners: return store.customers.count
        case .products: return store.products.count
        }
    }

    private func documentTitle(_ document: BusinessDocument) -> String {
        let number = document.number.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = document.type.localizedTitle(language)
        return number.isEmpty ? type : "\(type) \(number)"
    }

    private func documentSubtitle(_ document: BusinessDocument) -> String {
        let partner = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerText = partner.isEmpty ? localized(japanese: "取引先未入力", chinese: "未填写客户/供应商", english: "No partner") : partner
        return "\(AppFormatters.shortDate(document.issueDate)) / \(partnerText)"
    }

    private func projectSubtitle(_ project: ProjectArchive) -> String {
        let partner = project.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerText = partner.isEmpty ? localized(japanese: "取引先未入力", chinese: "未填写客户/供应商", english: "No partner") : partner
        return "\(project.direction.localizedTitle(language)) / \(partnerText) / \(AppFormatters.shortDate(project.updatedAt))"
    }

    private func partnerSubtitle(_ customer: CustomerProfile) -> String {
        [customer.contact, customer.phone ?? "", customer.email ?? "", customer.address]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private func productSubtitle(_ product: ProductProfile) -> String {
        [product.model, product.specification]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private func exportCSV() {
        do {
            sharePayload = SharePayload(url: try ReportDataCSVExporter.export(kind: kind, store: store, language: language))
        } catch {
            exportError = localized(japanese: "CSVを書き出せませんでした。", chinese: "无法输出 CSV。", english: "Could not export CSV.")
            isExportErrorPresented = true
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private struct ReportDataListRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
                .frame(width: 36, height: 36)
                .background(Color.appInputBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "-" : title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

private enum ReportDataCSVExporter {
    static func export(kind: ReportDataListKind, store: DocumentStore, language: AppLanguage) throws -> URL {
        let rows = csvRows(kind: kind, store: store, language: language)
        let csv = rows.map { row in
            row.map(csvEscape).joined(separator: ",")
        }.joined(separator: "\n")
        let data = Data(("\u{FEFF}" + csv + "\n").utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: kind))
            .appendingPathExtension("csv")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func csvRows(kind: ReportDataListKind, store: DocumentStore, language: AppLanguage) -> [[String]] {
        switch kind {
        case .documents:
            return [
                ["type", "number", "partner", "issue_date", "transaction_date", "due_date", "project", "subtotal", "tax", "total", "updated_at"]
            ] + store.documents.sorted { $0.updatedAt > $1.updatedAt }.map { document in
                [
                    document.type.localizedTitle(language),
                    document.number,
                    document.customerName,
                    dateText(document.issueDate),
                    dateText(document.transactionDate),
                    dateText(document.dueDate),
                    document.projectName ?? "",
                    amountText(document.subtotal),
                    amountText(document.tax),
                    amountText(document.total),
                    dateText(document.updatedAt)
                ]
            }
        case .projects:
            return [
                ["project", "direction", "partner", "document_count", "total", "updated_at"]
            ] + store.projects.map { project in
                [
                    project.name,
                    project.direction.localizedTitle(language),
                    project.customerName,
                    "\(project.documents.count)",
                    amountText(project.documents.reduce(0) { $0 + $1.total }),
                    dateText(project.updatedAt)
                ]
            }
        case .partners:
            return [
                ["name", "contact", "phone", "email", "address", "updated_at"]
            ] + store.customers.sorted { $0.updatedAt > $1.updatedAt }.map { customer in
                [
                    customer.name,
                    customer.contact,
                    customer.phone ?? "",
                    customer.email ?? "",
                    customer.address,
                    dateText(customer.updatedAt)
                ]
            }
        case .products:
            return [
                ["name", "model", "specification", "unit_price", "updated_at"]
            ] + store.products.sorted { $0.updatedAt > $1.updatedAt }.map { product in
                [
                    product.name,
                    product.model,
                    product.specification,
                    amountText(product.unitPrice),
                    dateText(product.updatedAt)
                ]
            }
        }
    }

    private static func fileName(for kind: ReportDataListKind) -> String {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return "shoko-\(kind.rawValue)-\(stamp)"
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func amountText(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}

private struct ReportDesignCard: View {
    let report: ReportDesign
    let language: AppLanguage
    let onAdjustSettings: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: report.systemImage)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.appInk)
                            .frame(width: 44, height: 44)
                            .background(Color.appInputBackground)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 5) {
                            Text(report.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appInk)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(report.subtitle)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.appMuted)
                    }

                    HStack(spacing: 8) {
                        ReportPill(title: localizedSourceTitle, value: report.source)
                        ReportPill(title: localizedRecordTitle, value: "\(report.recordCount)")
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text(isExpanded ? localizedCollapseTitle : localizedExpandTitle))

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ReportTagGroup(title: localizedFilterTitle, values: report.filters)
                    ReportTagGroup(title: localizedColumnTitle, values: report.columns)

                    Button {
                        onAdjustSettings()
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Text(localizedOpenTitle)
                                .font(.caption.weight(.semibold))
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundColor(.appInk)
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(Text(localizedOpenTitle))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }

    private var localizedSourceTitle: String { localized(japanese: "資料源", chinese: "资料源", english: "Source") }
    private var localizedRecordTitle: String { localized(japanese: "対象件数", chinese: "对象件数", english: "Records") }
    private var localizedFilterTitle: String { localized(japanese: "可設定フィルター", chinese: "可设置筛选", english: "Configurable Filters") }
    private var localizedColumnTitle: String { localized(japanese: "出力項目", chinese: "输出项目", english: "Output Columns") }
    private var localizedOpenTitle: String { localized(japanese: "設定を調整", chinese: "调整设置", english: "Adjust Settings") }
    private var localizedExpandTitle: String { localized(japanese: "詳細を表示", chinese: "展开详细", english: "Show Details") }
    private var localizedCollapseTitle: String { localized(japanese: "詳細を閉じる", chinese: "收起详细", english: "Hide Details") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private struct ReportConfigurationSheet: View {
    @ObservedObject var store: DocumentStore
    let report: ReportDesign
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedPartner = ReportAllChoice
    @State private var selectedCategory = ReportAllChoice
    @State private var selectedStatus = ReportAllChoice
    @State private var selectedGroup = "partner"
    @State private var selectedOutputLanguage = ""
    @State private var selectedFormat = "csv"
    @State private var overdueOnly = false
    @State private var minAmount = ""
    @State private var maxAmount = ""
    @State private var statusMessage = ""
    @State private var sharePayload: SharePayload?

    private var partnerOptions: [ReportChoice] {
        [ReportChoice(id: ReportAllChoice, title: localizedAllPartnersTitle)] + partnerNames.map { ReportChoice(id: $0, title: $0) }
    }

    private var categoryOptions: [ReportChoice] {
        [ReportChoice(id: ReportAllChoice, title: localizedAllCategoriesTitle)] + DocumentType.allCases.map {
            ReportChoice(id: $0.rawValue, title: $0.localizedTitle(language))
        }
    }

    private var statusOptions: [ReportChoice] {
        [
            ReportChoice(id: ReportAllChoice, title: localizedAllStatusesTitle),
            ReportChoice(id: "billed", title: localized(japanese: "請求済み", chinese: "已请款", english: "Billed")),
            ReportChoice(id: "paid", title: report.isVendorReport ? localized(japanese: "支払済み", chinese: "已付款", english: "Paid") : localized(japanese: "入金済み", chinese: "已收款", english: "Received")),
            ReportChoice(id: "unpaid", title: report.isVendorReport ? localized(japanese: "未払", chinese: "未付款", english: "Unpaid") : localized(japanese: "未収", chinese: "未收款", english: "Unpaid")),
            ReportChoice(id: "overdue", title: localized(japanese: "期限超過", chinese: "逾期", english: "Overdue"))
        ]
    }

    private var groupOptions: [ReportChoice] {
        [
            ReportChoice(id: "partner", title: localized(japanese: "取引先別", chinese: "按客户/厂商", english: "By partner")),
            ReportChoice(id: "month", title: localized(japanese: "月別", chinese: "按月份", english: "By month")),
            ReportChoice(id: "category", title: localized(japanese: "カテゴリ別", chinese: "按类别", english: "By category")),
            ReportChoice(id: "project", title: localized(japanese: "案件別", chinese: "按项目", english: "By project"))
        ]
    }

    private var outputLanguageOptions: [ReportChoice] {
        AppLanguage.allCases.map { ReportChoice(id: $0.rawValue, title: $0.nativeTitle) }
    }

    private var formatOptions: [ReportChoice] {
        [
            ReportChoice(id: "csv", title: "CSV"),
            ReportChoice(id: "pdf", title: "PDF"),
            ReportChoice(id: "xlsx", title: localized(japanese: "表計算", chinese: "电子表格", english: "Spreadsheet"))
        ]
    }

    private var quickRangeOptions: [ReportChoice] {
        [
            ReportChoice(id: "last30", title: localized(japanese: "直近30日", chinese: "最近30天", english: "Last 30 Days")),
            ReportChoice(id: "thisMonth", title: localized(japanese: "今月", chinese: "本月", english: "This Month")),
            ReportChoice(id: "lastMonth", title: localized(japanese: "先月", chinese: "上月", english: "Last Month")),
            ReportChoice(id: "thisYear", title: localized(japanese: "今年", chinese: "今年", english: "This Year"))
        ]
    }

    private var partnerNames: [String] {
        let profileNames = store.customers.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        let documentNames = store.documents.map { $0.customerName.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set((profileNames + documentNames).filter { !$0.isEmpty })).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var matchingDocuments: [BusinessDocument] {
        let earlierDate = min(startDate, endDate)
        let laterDate = max(startDate, endDate)
        let start = Calendar.current.startOfDay(for: earlierDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: laterDate)) ?? laterDate
        return store.documents.filter { document in
            guard report.matches(document) else { return false }
            guard document.issueDate >= start && document.issueDate < end else { return false }
            if selectedPartner != ReportAllChoice,
               document.customerName.trimmingCharacters(in: .whitespacesAndNewlines) != selectedPartner {
                return false
            }
            if selectedCategory != ReportAllChoice,
               document.type.rawValue != selectedCategory {
                return false
            }
            if !matchesStatus(document) {
                return false
            }
            if overdueOnly, document.dueDate >= Date() {
                return false
            }
            if let minimum = Double(minAmount), document.total < minimum {
                return false
            }
            if let maximum = Double(maxAmount), document.total > maximum {
                return false
            }
            return true
        }
    }

    private var totalAmount: Double {
        matchingDocuments.reduce(0) { $0 + $1.total }
    }

    private var previewDocuments: [BusinessDocument] {
        Array(matchingDocuments.sorted { $0.issueDate > $1.issueDate }.prefix(5))
    }

    private var activeFilterChips: [String] {
        [
            localized(japanese: "\(AppFormatters.shortDate(startDate))〜\(AppFormatters.shortDate(endDate))", chinese: "\(AppFormatters.shortDate(startDate)) 至 \(AppFormatters.shortDate(endDate))", english: "\(AppFormatters.shortDate(startDate)) to \(AppFormatters.shortDate(endDate))"),
            title(for: selectedPartner, in: partnerOptions),
            title(for: selectedCategory, in: categoryOptions),
            title(for: selectedStatus, in: statusOptions),
            title(for: selectedFormat, in: formatOptions)
        ]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionCard(title: localizedReportScopeTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 12) {
                            reportHeader
                            ReportDateRangeEditor(
                                startDate: $startDate,
                                endDate: $endDate,
                                startTitle: localizedStartDateTitle,
                                endTitle: localizedEndDateTitle
                            )
                            ReportQuickRangeButtons(title: localizedQuickRangeTitle, choices: quickRangeOptions, onSelect: applyQuickRange)
                            ReportChoicePicker(title: localizedPartnerTitle, selection: $selectedPartner, choices: partnerOptions)
                            ReportChoicePicker(title: localizedCategoryTitle, selection: $selectedCategory, choices: categoryOptions)
                            ReportChoicePicker(title: localizedStatusTitle, selection: $selectedStatus, choices: statusOptions)
                            if report.supportsGrouping {
                                ReportChoicePicker(title: localizedGroupTitle, selection: $selectedGroup, choices: groupOptions)
                            }
                            Toggle(localizedOverdueOnlyTitle, isOn: $overdueOnly)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appInk)
                        }
                    }

                    SectionCard(title: localizedOutputTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 12) {
                            ReportChoicePicker(title: localizedOutputLanguageTitle, selection: $selectedOutputLanguage, choices: outputLanguageOptions)
                            ReportChoicePicker(title: localizedFormatTitle, selection: $selectedFormat, choices: formatOptions)
                            HStack(spacing: 10) {
                                ReportTextInput(title: localizedMinAmountTitle, text: $minAmount)
                                ReportTextInput(title: localizedMaxAmountTitle, text: $maxAmount)
                            }
                        }
                    }

                    SectionCard(title: localizedPreviewTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 12) {
                            ReportMetricRow(title: localizedMatchedRowsTitle, value: "\(matchingDocuments.count)", systemImage: "line.3.horizontal.decrease.circle")
                            ReportMetricRow(title: localizedMatchedAmountTitle, value: AppFormatters.yen(totalAmount, language: language), systemImage: "yensign.circle")
                            ReportTagGroup(title: localizedOutputColumnsTitle, values: report.columns)
                            ReportTagGroup(title: localizedActiveFiltersTitle, values: activeFilterChips)
                            if previewDocuments.isEmpty {
                                EmptyManagementText(text: localizedNoPreviewRowsText)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(previewDocuments) { document in
                                        ReportPreviewDocumentRow(document: document, language: language)
                                    }
                                }
                            }
                            if !statusMessage.isEmpty {
                                BackupStatusMessage(text: statusMessage)
                            }
                            HStack(spacing: 10) {
                                Button {
                                    resetSettings()
                                } label: {
                                    Label(localizedResetTitle, systemImage: "arrow.counterclockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(CompanyOutlineButtonStyle())

                                Button {
                                    exportReportFile()
                                } label: {
                                    Label(localizedExportTitle, systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(CompanyFilledButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localizedNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedDoneTitle) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
        .onAppear {
            if selectedOutputLanguage.isEmpty {
                selectedOutputLanguage = language.rawValue
            }
        }
    }

    private var reportHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: report.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
                .frame(width: 44, height: 44)
                .background(Color.appInputBackground)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(report.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(report.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func matchesStatus(_ document: BusinessDocument) -> Bool {
        switch selectedStatus {
        case ReportAllChoice:
            return true
        case "billed":
            return document.type == .invoice || document.type == .vendorInvoice
        case "paid":
            return document.type == .receipt || document.type == .vendorReceipt
        case "unpaid":
            return document.type == .invoice || document.type == .vendorInvoice
        case "overdue":
            return (document.type == .invoice || document.type == .vendorInvoice) && document.dueDate < Date()
        default:
            return true
        }
    }

    private func resetSettings() {
        startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        endDate = Date()
        selectedPartner = ReportAllChoice
        selectedCategory = ReportAllChoice
        selectedStatus = ReportAllChoice
        selectedGroup = "partner"
        selectedOutputLanguage = language.rawValue
        selectedFormat = "csv"
        overdueOnly = false
        minAmount = ""
        maxAmount = ""
        statusMessage = localized(japanese: "設定を初期値に戻しました。", chinese: "已恢复默认设置。", english: "Settings were reset.")
    }

    private func exportReportFile() {
        do {
            let url = try makeReportFileURL()
            sharePayload = SharePayload(url: url)
            statusMessage = localized(
                japanese: "\(matchingDocuments.count)件のレポートファイルを作成しました。",
                chinese: "已建立包含 \(matchingDocuments.count) 条记录的报告文件。",
                english: "Created a report file with \(matchingDocuments.count) records."
            )
        } catch {
            statusMessage = localized(
                japanese: "レポートファイルを作成できませんでした。",
                chinese: "无法建立报告文件。",
                english: "Could not create the report file."
            )
        }
    }

    private func makeReportFileURL() throws -> URL {
        switch selectedFormat {
        case "pdf":
            return try makePDFReportURL()
        case "xlsx":
            return try makeSpreadsheetReportURL()
        default:
            return try makeCSVReportURL()
        }
    }

    private func makeCSVReportURL() throws -> URL {
        let csv = reportRows.map { row in
            row.map(csvEscape).joined(separator: ",")
        }.joined(separator: "\n")
        let data = Data(("\u{FEFF}" + csv + "\n").utf8)
        let url = reportTemporaryURL(extension: "csv")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeSpreadsheetReportURL() throws -> URL {
        let rows = reportRows.map { row in
            "<tr>" + row.map { "<td>\(htmlEscape($0))</td>" }.joined() + "</tr>"
        }.joined(separator: "\n")
        let html = """
        <html>
        <head><meta charset="utf-8"></head>
        <body>
        <table border="1">
        \(rows)
        </table>
        </body>
        </html>
        """
        let url = reportTemporaryURL(extension: "xls")
        try Data(html.utf8).write(to: url, options: .atomic)
        return url
    }

    private func makePDFReportURL() throws -> URL {
        let url = reportTemporaryURL(extension: "pdf")
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let margin: CGFloat = 36
            var y: CGFloat = margin
            y = drawPDFText(report.title, x: margin, y: y, width: pageBounds.width - margin * 2, font: .boldSystemFont(ofSize: 18))
            y = drawPDFText(activeFilterChips.joined(separator: " / "), x: margin, y: y + 8, width: pageBounds.width - margin * 2, font: .systemFont(ofSize: 10), color: .darkGray)
            y += 10
            let headers = reportRows.first ?? []
            let rows = Array(reportRows.dropFirst())
            y = drawPDFRow(headers, x: margin, y: y, pageWidth: pageBounds.width - margin * 2, isHeader: true)
            for row in rows {
                if y > pageBounds.height - 70 {
                    context.beginPage()
                    y = margin
                    y = drawPDFRow(headers, x: margin, y: y, pageWidth: pageBounds.width - margin * 2, isHeader: true)
                }
                y = drawPDFRow(row, x: margin, y: y, pageWidth: pageBounds.width - margin * 2, isHeader: false)
            }
        }
        return url
    }

    private var reportRows: [[String]] {
        [reportHeaders] + matchingDocuments.sorted { $0.issueDate > $1.issueDate }.map { document in
            [
                AppFormatters.shortDate(document.issueDate),
                paymentDateText(for: document),
                document.customerName.trimmingCharacters(in: .whitespacesAndNewlines),
                document.type.localizedTitle(language),
                document.number,
                AppFormatters.yen(document.subtotal, language: language),
                AppFormatters.yen(document.tax, language: language),
                AppFormatters.yen(document.total, language: language),
                settlementStatusText(for: document)
            ]
        }
    }

    private var reportHeaders: [String] {
        [
            localized(japanese: "発行日", chinese: "发行日", english: "Issue Date"),
            report.isVendorReport ? localized(japanese: "支払日", chinese: "付款日", english: "Payment Date") : localized(japanese: "入金日", chinese: "收款日", english: "Payment Date"),
            localized(japanese: "取引先", chinese: "客户/厂商", english: "Partner"),
            localized(japanese: "帳票種類", chinese: "表单类型", english: "Form Type"),
            localized(japanese: "帳票番号", chinese: "表单编号", english: "Form Number"),
            localized(japanese: "税抜合計", chinese: "未税合计", english: "Subtotal"),
            localized(japanese: "税額", chinese: "税额", english: "Tax"),
            localized(japanese: "税込合計", chinese: "含税合计", english: "Total"),
            localized(japanese: "決済状態", chinese: "结算状态", english: "Settlement Status")
        ]
    }

    private func paymentDateText(for document: BusinessDocument) -> String {
        if document.type == .receipt || document.type == .vendorReceipt {
            return AppFormatters.shortDate(document.issueDate)
        }
        if let proofDate = document.paymentProofDate {
            return AppFormatters.shortDate(proofDate)
        }
        return ""
    }

    private func settlementStatusText(for document: BusinessDocument) -> String {
        if document.type == .receipt || document.type == .vendorReceipt {
            return report.isVendorReport ? localized(japanese: "支払済み", chinese: "已付款", english: "Paid") : localized(japanese: "入金済み", chinese: "已收款", english: "Received")
        }
        if document.type == .invoice || document.type == .vendorInvoice {
            if document.dueDate < Date() {
                return localized(japanese: "期限超過", chinese: "逾期", english: "Overdue")
            }
            return report.isVendorReport ? localized(japanese: "未払", chinese: "未付款", english: "Unpaid") : localized(japanese: "未収", chinese: "未收款", english: "Unpaid")
        }
        return localized(japanese: "対象", chinese: "对象", english: "Included")
    }

    private func reportTemporaryURL(extension fileExtension: String) -> URL {
        let name = sanitizedFileName(report.title)
        let stamp = Self.fileNameDateFormatter.string(from: Date())
        return FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(stamp).\(fileExtension)")
    }

    private func sanitizedFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "shoko-report" : cleaned
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    @discardableResult
    private func drawPDFText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: UIFont, color: UIColor = .black) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let rect = CGRect(x: x, y: y, width: width, height: 1000)
        let used = (text as NSString).boundingRect(with: rect.size, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
        (text as NSString).draw(with: CGRect(x: x, y: y, width: width, height: ceil(used.height)), options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
        return y + ceil(used.height)
    }

    @discardableResult
    private func drawPDFRow(_ row: [String], x: CGFloat, y: CGFloat, pageWidth: CGFloat, isHeader: Bool) -> CGFloat {
        let font = isHeader ? UIFont.boldSystemFont(ofSize: 8) : UIFont.systemFont(ofSize: 8)
        let columns = max(row.count, 1)
        let columnWidth = pageWidth / CGFloat(columns)
        let rowHeight: CGFloat = 28
        for (index, value) in row.enumerated() {
            let rect = CGRect(x: x + CGFloat(index) * columnWidth, y: y, width: columnWidth, height: rowHeight)
            UIColor(white: isHeader ? 0.92 : 1.0, alpha: 1).setFill()
            UIRectFill(rect)
            UIColor(white: 0.82, alpha: 1).setStroke()
            UIRectFrame(rect)
            let textRect = rect.insetBy(dx: 3, dy: 5)
            (value as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: [.font: font, .foregroundColor: UIColor.black], context: nil)
        }
        return y + rowHeight
    }

    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private func title(for id: String, in choices: [ReportChoice]) -> String {
        choices.first { $0.id == id }?.title ?? id
    }

    private func applyQuickRange(_ id: String) {
        let calendar = Calendar.current
        let now = Date()
        switch id {
        case "last30":
            startDate = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            endDate = now
        case "thisMonth":
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            endDate = now
        case "lastMonth":
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart
            startDate = lastMonthStart
            endDate = calendar.date(byAdding: .day, value: -1, to: thisMonthStart) ?? now
        case "thisYear":
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            endDate = now
        default:
            break
        }
        statusMessage = ""
    }

    private var localizedNavigationTitle: String { localized(japanese: "レポート設定", chinese: "报告设置", english: "Report Settings") }
    private var localizedDoneTitle: String { localized(japanese: "完了", chinese: "完成", english: "Done") }
    private var localizedReportScopeTitle: String { localized(japanese: "条件設定", chinese: "条件设置", english: "Filter Settings") }
    private var localizedStartDateTitle: String { localized(japanese: "開始日", chinese: "开始日", english: "Start Date") }
    private var localizedEndDateTitle: String { localized(japanese: "終了日", chinese: "结束日", english: "End Date") }
    private var localizedQuickRangeTitle: String { localized(japanese: "常用期間", chinese: "常用期间", english: "Quick Ranges") }
    private var localizedPartnerTitle: String { report.isVendorReport ? localized(japanese: "仕入先", chinese: "厂商", english: "Vendor") : localized(japanese: "顧客/仕入先", chinese: "客户/厂商", english: "Customer/Vendor") }
    private var localizedCategoryTitle: String { localized(japanese: "帳票カテゴリ", chinese: "表单类别", english: "Form Category") }
    private var localizedStatusTitle: String { report.isVendorReport ? localized(japanese: "支払状態", chinese: "付款状态", english: "Payment Status") : localized(japanese: "入金状態", chinese: "收款状态", english: "Payment Status") }
    private var localizedGroupTitle: String { localized(japanese: "集計単位", chinese: "汇总单位", english: "Group By") }
    private var localizedOverdueOnlyTitle: String { localized(japanese: "期限超過のみ", chinese: "只看逾期", english: "Overdue only") }
    private var localizedOutputTitle: String { localized(japanese: "出力設定", chinese: "输出设置", english: "Output Settings") }
    private var localizedOutputLanguageTitle: String { localized(japanese: "出力言語", chinese: "输出语言", english: "Output Language") }
    private var localizedFormatTitle: String { localized(japanese: "出力形式", chinese: "输出格式", english: "Export Format") }
    private var localizedMinAmountTitle: String { localized(japanese: "最小金額", chinese: "最小金额", english: "Min Amount") }
    private var localizedMaxAmountTitle: String { localized(japanese: "最大金額", chinese: "最大金额", english: "Max Amount") }
    private var localizedPreviewTitle: String { localized(japanese: "プレビュー", chinese: "预览", english: "Preview") }
    private var localizedMatchedRowsTitle: String { localized(japanese: "対象件数", chinese: "对象件数", english: "Matching Records") }
    private var localizedMatchedAmountTitle: String { localized(japanese: "対象金額", chinese: "对象金额", english: "Matching Amount") }
    private var localizedOutputColumnsTitle: String { localized(japanese: "出力項目", chinese: "输出项目", english: "Output Columns") }
    private var localizedActiveFiltersTitle: String { localized(japanese: "適用中の条件", chinese: "当前条件", english: "Active Filters") }
    private var localizedNoPreviewRowsText: String { localized(japanese: "この条件に一致する帳票はありません。期間、取引先、状態を変更してください。", chinese: "没有符合当前条件的表单。请调整期间、客户/厂商或状态。", english: "No forms match these filters. Adjust period, partner, or status.") }
    private var localizedResetTitle: String { localized(japanese: "リセット", chinese: "重置", english: "Reset") }
    private var localizedExportTitle: String { localized(japanese: "ファイル出力", chinese: "输出文件", english: "Export File") }
    private var localizedAllPartnersTitle: String { localized(japanese: "すべて", chinese: "全部", english: "All") }
    private var localizedAllCategoriesTitle: String { localized(japanese: "すべてのカテゴリ", chinese: "全部类别", english: "All Categories") }
    private var localizedAllStatusesTitle: String { localized(japanese: "すべての状態", chinese: "全部状态", english: "All Statuses") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private let ReportAllChoice = "__all__"

private struct ReportChoice: Identifiable {
    let id: String
    let title: String
}

private struct ReportDateRangeEditor: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let startTitle: String
    let endTitle: String

    var body: some View {
        VStack(spacing: 10) {
            DatePicker(startTitle, selection: $startDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
            DatePicker(endTitle, selection: $endDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.appInk)
    }
}

private struct ReportQuickRangeButtons: View {
    let title: String
    let choices: [ReportChoice]
    let onSelect: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 118), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(choices) { choice in
                    Button {
                        onSelect(choice.id)
                    } label: {
                        Text(choice.title)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompanyMiniButtonStyle())
                }
            }
        }
    }
}

private struct ReportPreviewDocumentRow: View {
    let document: BusinessDocument
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: document.type.isVendorForm ? "building.2" : "person.crop.square")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
                .frame(width: 34, height: 34)
                .background(Color.appInputBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(rowTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(rowSubtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(AppFormatters.yen(document.total, language: language))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider.opacity(0.8)))
        .cornerRadius(8)
    }

    private var rowTitle: String {
        let number = document.number.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = document.type.localizedTitle(language)
        return number.isEmpty ? type : "\(type) \(number)"
    }

    private var rowSubtitle: String {
        let partner = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerText = partner.isEmpty ? fallbackPartnerTitle : partner
        return "\(AppFormatters.shortDate(document.issueDate)) / \(partnerText)"
    }

    private var fallbackPartnerTitle: String {
        switch language {
        case .japanese: return "取引先未入力"
        case .simplifiedChinese, .traditionalChinese: return "未填写客户/厂商"
        case .english, .korean, .nepali, .french, .vietnamese: return "No partner"
        }
    }
}

private struct ReportChoicePicker: View {
    let title: String
    @Binding var selection: String
    let choices: [ReportChoice]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(choices) { choice in
                Text(choice.title).tag(choice.id)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.appInk)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 12)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

private struct ReportTextInput: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.appInputBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReportPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appMuted)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider.opacity(0.8)))
        .cornerRadius(8)
    }
}

private struct ReportTagGroup: View {
    let title: String
    let values: [String]
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 6, alignment: .leading)]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.appInputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider.opacity(0.8)))
                        .cornerRadius(8)
                }
            }
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
    @State private var isCloudUploadOverwriteConfirmationPresented = false
    @State private var isCloudBackupManagerPresented = false
    @State private var isCloudBackupImportOptionsPresented = false
    @State private var isDSASettingsPresented = false
    @State private var isDeveloperStoryPresented = false
    @State private var isPreservationGuidePresented = false
    @State private var isReminderSettingsPresented = false
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

            reminderSettingsSection

            SectionCard(title: AppText.value(.tableColor, language), titleWeight: .regular) {
                LazyVGrid(columns: colorTemplateColumns, alignment: .leading, spacing: 10) {
                    ForEach(DocumentColorTemplate.allCases) { template in
                        Button {
                            store.applyDefaultColorTemplate(template.rawValue)
                        } label: {
                            colorTemplateCircle(template)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel(Text(template.title))
                        .accessibilityAddTraits(store.defaultColorTemplateId == template.rawValue ? [.isSelected] : [])
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
        .sheet(isPresented: $isReminderSettingsPresented) {
            ReminderCenterSheet(store: store, language: language) { document in
                isReminderSettingsPresented = false
                store.select(document)
                selectedSection = .form
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
        .confirmationDialog(localizedCloudUploadOverwriteTitle, isPresented: $isCloudUploadOverwriteConfirmationPresented, titleVisibility: .visible) {
            Button(localizedCloudUploadOverwriteActionTitle, role: .destructive) {
                uploadCloudBackup()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedCloudUploadOverwriteMessage)
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

    private var reminderSettingsSection: some View {
        SectionCard(title: localizedReminderSettingsTitle, titleWeight: .regular) {
            Button {
                isReminderSettingsPresented = true
            } label: {
                LegalLinkButtonContent(
                    title: localizedReminderSettingsActionTitle,
                    systemImage: "bell.badge.fill",
                    trailingSystemImage: "chevron.right"
                )
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

                HStack(spacing: 6) {
                    Text(AppLanguage.from(selection.wrappedValue).nativeTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .lineLimit(1)

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

    private var colorTemplateColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 44), spacing: 12)]
    }

    private func colorTemplateCircle(_ template: DocumentColorTemplate) -> some View {
        let isSelected = store.defaultColorTemplateId == template.rawValue
        return Circle()
            .fill(template.swiftUIColor)
            .frame(width: 30, height: 30)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.appInk.opacity(0.82) : Color.appDivider, lineWidth: isSelected ? 2 : 1)
                    .frame(width: isSelected ? 40 : 34, height: isSelected ? 40 : 34)
            )
            .frame(width: 44, height: 44)
            .contentShape(Circle())
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
                                        requestCloudBackupUpload()
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

    private func requestCloudBackupUpload() {
        guard googleDriveCloudBackupFileID.isEmpty else {
            isCloudUploadOverwriteConfirmationPresented = true
            return
        }
        uploadCloudBackup()
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
    private var localizedReminderSettingsTitle: String { localized(japanese: "提醒設定", chinese: "提醒设置", english: "Reminder Settings") }
    private var localizedReminderSettingsActionTitle: String { localized(japanese: "支払・入帳提醒", chinese: "支付与到账提醒", english: "Payment and receipt reminders") }
    private var localizedProStatusText: String {
        switch language {
        case .japanese: return purchaseService.hasProAccess ? "有効" : "プレビュー共有、Google Driveバックアップ"
        case .simplifiedChinese, .traditionalChinese: return purchaseService.hasProAccess ? "已启用" : "预览分享与 Google Drive 备份"
        case .english, .korean, .nepali, .french, .vietnamese: return purchaseService.hasProAccess ? "Active" : "Preview sharing and Google Drive backup"
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
    private var localizedBackupImportModeMessage: String { localized(japanese: "結合では既存データを上書きしません。置き換えではこの端末の既存データがバックアップ内容で上書きされ、App からは復元できません。", chinese: "合并不会覆盖本机现有数据；替换会用备份内容覆盖本机既有资料，覆盖后无法从 App 内恢复。", english: "Merge will not overwrite existing local data. Replace overwrites this device's existing data with the backup and cannot be restored from the app.") }
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
            japanese: "保存済み帳票、削除履歴、編集中の下書き、会社・取引先・商品・テンプレート、印章をこの端末から削除します。作成済みのバックアップファイルや Google Drive 内のバックアップは削除しません。",
            chinese: "将从本机删除已保存表单、删除文件、编辑中的草稿、公司/客户/商品/模板与印章。已经导出的备份文件和 Google Drive 里的备份不会被删除。",
            english: "Deletes saved forms, Deleted Files, the current draft, company, customer, product, template, and stamp data from this device. Exported backup files and Google Drive backups are not deleted."
        )
    }
    private var localizedClearDataFirstConfirmTitle: String { localized(japanese: "App 資料を削除しますか？", chinese: "要清除 App 资料吗？", english: "Clear App Data?") }
    private var localizedClearDataFirstConfirmMessage: String {
        localized(
            japanese: "この操作はこの端末内の帳票、削除履歴、管理資料を削除し、Appを空白状態に戻します。バックアップが必要な場合は先に作成してください。",
            chinese: "此操作会删除本机内的表单、删除文件和管理资料，并将 App 还原为空白状态。如需保留，请先建立备份。",
            english: "This deletes forms, Deleted Files, and management data on this device, returning the app to a blank state. Create a backup first if you need to keep them."
        )
    }
    private var localizedClearDataContinueTitle: String { localized(japanese: "次へ", chinese: "继续", english: "Continue") }
    private var localizedClearDataFinalConfirmTitle: String { localized(japanese: "最終確認", chinese: "最终确认", english: "Final Confirmation") }
    private var localizedClearDataFinalConfirmMessage: String {
        localized(
            japanese: "削除後は削除履歴にも残らず、この端末から復元できません。バックアップがない場合、資料は失われます。本当に削除しますか？",
            chinese: "删除后不会保留在删除文件里，也无法从本机复原。如果没有备份，资料会永久遗失。确定要删除吗？",
            english: "After deletion, nothing remains in Deleted Files and this device cannot restore the data. Without a backup, the data will be lost. Are you sure?"
        )
    }
    private var localizedClearDataFinalActionTitle: String { localized(japanese: "完全に削除", chinese: "彻底删除", english: "Delete Permanently") }
    private var localizedClearDataCompleteStatus: String { localized(japanese: "この端末の App 資料と削除履歴を削除しました。バックアップは削除していません。", chinese: "已清除本机 App 资料和删除文件。备份没有被删除。", english: "App data and Deleted Files on this device were cleared. Backups were not deleted.") }
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
    private var localizedCloudSyncConfirmMessage: String { localized(japanese: "Google Drive のバックアップ一覧を読み込みます。後で置き換えを選ぶと、この端末の既存データは上書きされ、App からは復元できません。", chinese: "将读取 Google Drive 备份包列表。后续如果选择替换，本机现有资料会被覆盖，且无法从 App 内恢复。", english: "This will load Google Drive backup packages. If you choose Replace later, existing data on this device will be overwritten and cannot be restored from the app.") }
    private var localizedCloudSyncConfirmButtonTitle: String { localized(japanese: "一覧を表示", chinese: "查看备份包", english: "Show Packages") }
    private var localizedCloudUploadOverwriteTitle: String { localized(japanese: "Google Drive のバックアップを上書きしますか？", chinese: "要覆盖 Google Drive 备份吗？", english: "Overwrite Google Drive Backup?") }
    private var localizedCloudUploadOverwriteMessage: String { localized(japanese: "この端末の内容で既存の Google Drive バックアップファイルを上書きします。上書き後、古いバックアップは App から復元できません。", chinese: "将用本机目前内容覆盖既有 Google Drive 备份文件。覆盖后，旧备份无法从 App 内恢复。", english: "This will overwrite the existing Google Drive backup file with this device's current data. After overwriting, the old backup cannot be restored from the app.") }
    private var localizedCloudUploadOverwriteActionTitle: String { localized(japanese: "上書きしてアップロード", chinese: "覆盖并上传", english: "Overwrite and Upload") }
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
    private var localizedCloudImportModeMessage: String { localized(japanese: "Google Drive のバックアップを既存データに結合するか、この端末の内容を置き換えるか選択してください。置き換えは本機データを上書きし、App から復元できません。複数選択時は安全のため結合のみ実行します。", chinese: "请选择将 Google Drive 备份合并到本机，或用云端内容替换本机内容。替换会覆盖本机资料，且无法从 App 内恢复。选择多个备份包时，为避免覆盖，只会执行合并。", english: "Choose whether to merge the Google Drive backup or replace this device. Replace overwrites local data and cannot be restored from the app. Multiple selected packages are merged only.") }
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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

                OnboardingImageSlot(step: item, language: language)

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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private struct OnboardingImageSlot: View {
    let step: OnboardingStep
    let language: AppLanguage

    var body: some View {
        TutorialImageView(
            asset: step.imageAsset,
            title: step.imageTitle(language),
            caption: step.imageCaption(language),
            badge: step.imageBadge(language)
        )
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

    var imageAsset: TutorialImageAsset {
        switch self {
        case .start: return .onboardingStart
        case .company: return .onboardingCompany
        case .products: return .onboardingProducts
        case .customers: return .onboardingCustomers
        case .form: return .onboardingForm
        case .preview: return .onboardingPreview
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .start: return localized(language, japanese: "まず使い方を確認", chinese: "先学会基本用法", english: "Start with the Basics", korean: "먼저 사용 방법 확인")
        case .company: return localized(language, japanese: "会社情報を登録", chinese: "建立公司信息", english: "Create Company Information", korean: "회사 정보 등록")
        case .products: return localized(language, japanese: "商品情報を登録", chinese: "建立产品信息", english: "Create Product Information", korean: "상품 정보 등록")
        case .customers: return localized(language, japanese: "取引先情報を登録", chinese: "建立客户信息", english: "Create Customer Information", korean: "거래처 정보 등록")
        case .form: return localized(language, japanese: "帳票を作成", chinese: "建立表单", english: "Create a Form", korean: "양식 작성")
        case .preview: return localized(language, japanese: "プレビューを確認", chinese: "预览", english: "Preview", korean: "미리보기 확인")
        }
    }

    func body(_ language: AppLanguage) -> String {
        switch self {
        case .start:
            return localized(language, japanese: "このアプリは、会社・商品・取引先を候補として保存し、帳票作成とPDF確認までを端末内で進めます。", chinese: "这个 App 会先保存公司、产品与客户候选资料，再用这些资料建立表单并确认 PDF 预览。", english: "Save company, product, and customer profiles, then use them to create forms and preview PDFs on this device.", korean: "이 앱은 회사, 상품, 거래처 정보를 후보로 저장한 뒤, 양식 작성과 PDF 확인까지 기기 안에서 진행합니다.")
        case .company:
            return localized(language, japanese: "帳票に表示する自社名、登録番号、連絡先、住所を登録します。", chinese: "登记表单上显示的本公司名称、登记编号、联系人和地址。", english: "Register the issuer name, registration number, contact details, and address shown on forms.", korean: "양식에 표시할 자사명, 등록번호, 연락처와 주소를 등록합니다.")
        case .products:
            return localized(language, japanese: "よく使う商品や作業項目を保存すると、明細入力が速くなります。", chinese: "保存常用商品或作业项目后，建立明细会更快。", english: "Save frequently used products or work items to speed up line item entry.", korean: "자주 사용하는 상품이나 작업 항목을 저장하면 상세 항목 입력이 빨라집니다.")
        case .customers:
            return localized(language, japanese: "顧客や仕入先を保存しておくと、帳票作成時に候補から呼び出せます。", chinese: "预先保存客户或供应商后，建立表单时可直接从候选项带入。", english: "Save customers and vendors so they can be inserted while creating forms.", korean: "고객이나 공급업체를 저장해 두면 양식 작성 시 후보에서 바로 불러올 수 있습니다.")
        case .form:
            return localized(language, japanese: "見積、注文、納品、請求、領収など、用途に合わせて帳票を選んで入力します。", chinese: "依照用途选择报价、订单、交付、请款、收据等表单并输入内容。", english: "Choose the form type you need, such as estimate, order, delivery, invoice, or receipt.", korean: "견적, 주문, 납품, 청구, 영수 등 용도에 맞는 양식을 선택해 입력합니다.")
        case .preview:
            return localized(language, japanese: "保存した帳票はPDFとして確認できます。共有やGoogle DriveバックアップはPro機能です。", chinese: "保存后的表单可用 PDF 预览确认。分享与 Google Drive 备份属于 Pro 功能。", english: "Saved forms can be reviewed as PDFs. Sharing and Google Drive backup are Pro features.", korean: "저장한 양식은 PDF로 확인할 수 있습니다. 공유와 Google Drive 백업은 Pro 기능입니다.")
        }
    }

    func points(_ language: AppLanguage) -> [String] {
        switch self {
        case .start:
            return [
                localized(language, japanese: "下のボタンから各管理画面を開けます。", chinese: "可用下方按钮打开对应管理页面。", english: "Use the button below to open each related screen.", korean: "아래 버튼에서 각 관리 화면을 열 수 있습니다."),
                localized(language, japanese: "導入中でも右上からいつでも閉じられます。", chinese: "导览过程中可随时从右上角跳出。", english: "You can close the guide at any time.", korean: "도움말 중에도 오른쪽 위에서 언제든지 닫을 수 있습니다.")
            ]
        case .company:
            return [
                localized(language, japanese: "複数の会社情報を保存できます。", chinese: "可以保存多笔公司资料。", english: "You can save multiple company profiles.", korean: "여러 회사 정보를 저장할 수 있습니다."),
                localized(language, japanese: "既定の会社情報は新規帳票に反映されます。", chinese: "默认公司资料会带入新表单。", english: "The default company is applied to new forms.", korean: "기본 회사 정보는 새 양식에 자동 반영됩니다.")
            ]
        case .products:
            return [
                localized(language, japanese: "品名、型番、仕様、単価を保存します。", chinese: "保存品名、型号、规格和单价。", english: "Save item name, model, specification, and unit price.", korean: "품명, 모델, 사양, 단가를 저장합니다."),
                localized(language, japanese: "帳票明細へ候補から入力できます。", chinese: "建立表单明细时可从候选项输入。", english: "Insert saved products into form line items.", korean: "양식 상세 항목에 후보로 입력할 수 있습니다.")
            ]
        case .customers:
            return [
                localized(language, japanese: "顧客と仕入先の候補を同じ場所で管理します。", chinese: "客户与供应商候选资料在同一处管理。", english: "Manage customers and vendors in one place.", korean: "고객과 공급업체 후보를 한곳에서 관리합니다."),
                localized(language, japanese: "会社名、担当者、電話、メール、住所を保存します。", chinese: "保存公司名、负责人、电话、邮箱和地址。", english: "Save name, contact, phone, email, and address.", korean: "회사명, 담당자, 전화, 이메일, 주소를 저장합니다.")
            ]
        case .form:
            return [
                localized(language, japanese: "入力中の内容は保存して後から再利用できます。", chinese: "输入中的内容可保存并之后继续使用。", english: "Save forms and reuse them later.", korean: "입력 중인 내용은 저장해 나중에 다시 사용할 수 있습니다."),
                localized(language, japanese: "プロジェクトにまとめると関連帳票を追跡しやすくなります。", chinese: "放入项目后更容易追踪相关表单。", english: "Projects help track related forms together.", korean: "프로젝트로 묶으면 관련 양식을 추적하기 쉽습니다.")
            ]
        case .preview:
            return [
                localized(language, japanese: "保存済み帳票からPDFプレビューを開けます。", chinese: "可从已保存表单打开 PDF 预览。", english: "Open PDF preview from saved forms.", korean: "저장된 양식에서 PDF 미리보기를 열 수 있습니다."),
                localized(language, japanese: "テストデータを読み込むとすぐにプレビューを試せます。", chinese: "载入测试数据后可以马上试用预览。", english: "Load demo data to try preview immediately.", korean: "테스트 데이터를 불러오면 바로 미리보기를 시험할 수 있습니다.")
            ]
        }
    }

    func imageTitle(_ language: AppLanguage) -> String {
        switch self {
        case .start:
            return localized(language, japanese: "全体の流れを図で確認", chinese: "用附图预览整体流程", english: "Preview the Full Workflow", korean: "전체 흐름을 그림으로 확인")
        case .company:
            return localized(language, japanese: "会社情報登録の案内図", chinese: "公司资料附图", english: "Company Illustration", korean: "회사 정보 안내 그림")
        case .products:
            return localized(language, japanese: "商品登録の案内図", chinese: "产品资料附图", english: "Product Illustration", korean: "상품 등록 안내 그림")
        case .customers:
            return localized(language, japanese: "取引先登録の案内図", chinese: "客户资料附图", english: "Customer Illustration", korean: "거래처 등록 안내 그림")
        case .form:
            return localized(language, japanese: "帳票作成の案内図", chinese: "表单建立附图", english: "Form Creation Illustration", korean: "양식 작성 안내 그림")
        case .preview:
            return localized(language, japanese: "PDFプレビューの案内図", chinese: "PDF 预览附图", english: "PDF Preview Illustration", korean: "PDF 미리보기 안내 그림")
        }
    }

    func imageCaption(_ language: AppLanguage) -> String {
        switch self {
        case .start:
            return localized(language, japanese: "初回起動ガイドの流れを確認できます。", chinese: "这里显示首次启动导览附图。", english: "Shows the first-launch guide flow.", korean: "첫 실행 안내 흐름을 확인할 수 있습니다.")
        case .company:
            return localized(language, japanese: "自社情報の入力手順を図で確認します。", chinese: "用附图说明本公司资料输入步骤。", english: "Shows the issuer profile setup flow.", korean: "자사 정보 입력 절차를 그림으로 확인합니다.")
        case .products:
            return localized(language, japanese: "商品候補の追加手順を図で確認します。", chinese: "用附图说明产品候选资料新增步骤。", english: "Shows the product candidate setup flow.", korean: "상품 후보 추가 절차를 그림으로 확인합니다.")
        case .customers:
            return localized(language, japanese: "顧客・仕入先登録の手順を図で確認します。", chinese: "用附图说明客户与供应商登记步骤。", english: "Shows the customer and vendor setup flow.", korean: "고객 및 공급업체 등록 절차를 그림으로 확인합니다.")
        case .form:
            return localized(language, japanese: "帳票入力から保存までの手順を図で確認します。", chinese: "用附图说明表单输入到保存的步骤。", english: "Shows the form entry and save flow.", korean: "양식 입력부터 저장까지의 절차를 그림으로 확인합니다.")
        case .preview:
            return localized(language, japanese: "PDF確認と共有前チェックの手順を図で確認します。", chinese: "用附图说明 PDF 确认与分享前检查步骤。", english: "Shows the PDF review flow.", korean: "PDF 확인과 공유 전 점검 절차를 그림으로 확인합니다.")
        }
    }

    func imageBadge(_ language: AppLanguage) -> String {
        guard let index = Self.allCases.firstIndex(of: self) else {
            return localized(language, japanese: "図", chinese: "附图", english: "Image", korean: "그림")
        }
        let number = String(format: "%02d", index + 1)
        return localized(language, japanese: "図 \(number)", chinese: "附图 \(number)", english: "Image \(number)", korean: "그림 \(number)")
    }

    private func localized(_ language: AppLanguage, japanese: String, chinese: String, english: String, korean: String? = nil) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return korean ?? english
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        ProjectDirection.customer.requiredTypes.map { type in
            PreservationGuideItem(title: type.localizedTitle(language), body: formGuideBody(for: type))
        } + ProjectDirection.vendor.requiredTypes.map { type in
            PreservationGuideItem(title: type.localizedTitle(language), body: formGuideBody(for: type))
        }
    }

    private func formGuideBody(for type: DocumentType) -> String {
        switch type {
        case .estimate:
            return localized(japanese: "見積条件、明細、税率、有効期限を残し、後続の注文・請求と照合しやすくします。", chinese: "保存报价条件、明细、税率和有效期，便于和后续订单、请款内容核对。", english: "Keeps terms, line items, tax, and validity dates for comparison with later orders and invoices.")
        case .customerOrder:
            return localized(japanese: "受注内容、希望納期、関連見積番号を記録し、受注根拠を整理します。", chinese: "记录受注内容、希望交期和相关报价编号，用来整理受订单据依据。", english: "Records order received details, requested delivery dates, and related quote numbers.")
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
        case .vendorInvoice:
            return localized(japanese: "仕入先請求書の受領日、関連番号、添付資料を保存し、支払確認につなげます。", chinese: "保存供应商请款书的取得日期、关联编号和附件，便于后续付款确认。", english: "Stores vendor invoice dates, related numbers, and attachments for payment review.")
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
            japanese: "台湾出身の開発者 Kody Chang と NIIX からのメッセージ",
            chinese: "来自台湾的开发者 Kody Chang 与 NIIX 的开发者寄语",
            english: "A developer message from Kody Chang of Taiwan and NIIX"
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
            ),
            localized(
                japanese: "今回の更新では、プレビュー入口を編集画面に寄せ、入出金ダッシュボード、未処理タスク、スキャン帳票を追加しました。現場で迷う時間と、プレビューが空白に見える不安を減らすためです。",
                chinese: "这次更新把预览入口放到编辑表单旁边，新增收付款仪表板、待处理任务与扫描表单。原因是减少现场操作时的迷路，也降低预览看起来没有出纸的不安。",
                english: "This update moves preview into the editor, adds the cashflow dashboard, open tasks, and scan form. The reason is to reduce on-site navigation friction and make blank preview states less confusing."
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
            localized(japanese: "スキャンから編集できる帳票化を安定させる", chinese: "让扫描转换成可编辑表单更稳定", english: "More reliable scanned-to-editable forms"),
            localized(japanese: "帳票テンプレートと共有の改善", chinese: "改善表单模板与分享体验", english: "Better templates and sharing")
        ]
    }
    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
    @State private var quickPreviewProjectGroup: FileProjectGroup?
    @State private var editingProject: ProjectArchive?
    @State private var isSelectingDocuments = false
    @State private var selectedDocumentIDs: Set<BusinessDocument.ID> = []
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeletedHistoryPresented = false
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
            clearDocumentSelection()
        }
        .onChange(of: selectedDocumentType) { _ in
            clearDocumentSelection()
        }
        .sheet(item: $copyingDocument) { document in
            ProjectDocumentCopySheet(store: store, source: document) { copied in
                store.select(copied)
                selectedSection = .form
            }
        }
        .sheet(item: $editingProject) { project in
            ProjectSettingsSheet(store: store, project: project)
        }
        .sheet(item: $quickPreviewProjectGroup) { group in
            FileProjectQuickPreviewSheet(
                group: group,
                direction: direction,
                language: language,
                onOpenType: { type in
                    openProjectGroupType(group, type: type)
                },
                onOpenDocument: { document in
                    store.select(document)
                    selectedSection = .form
                },
                onCopyDocument: { document in
                    quickPreviewProjectGroup = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        copyingDocument = document
                    }
                },
                onSettings: {
                    guard let project = projectArchive(for: group.id) else { return }
                    quickPreviewProjectGroup = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        editingProject = project
                    }
                },
                onDelete: {
                    store.deleteDocuments(ids: Set(group.documents.map(\.id)))
                    quickPreviewProjectGroup = nil
                    if selectedProjectGroupID == group.id {
                        selectedProjectGroupID = nil
                        selectedDocumentType = nil
                    }
                }
            )
        }
        .sheet(isPresented: $isDeletedHistoryPresented) {
            DeletedDocumentHistorySheet(store: store, language: language)
        }
        .confirmationDialog(localizedDeleteSelectedTitle, isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button(localizedMoveToDeletedHistoryTitle, role: .destructive) {
                deleteSelectedDocuments()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedDeleteSelectedMessage)
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

            Spacer(minLength: 12)
            HStack(spacing: 8) {
                if level == .documents {
                    Button(isSelectingDocuments ? localizedDoneTitle : localizedSelectTitle) {
                        isSelectingDocuments.toggle()
                        if !isSelectingDocuments {
                            selectedDocumentIDs.removeAll()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(minWidth: 54, minHeight: 40)
                }

                if level == .partners {
                    Button {
                        store.pruneExpiredDeletedDocuments()
                        isDeletedHistoryPresented = true
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.appInk)
                            .frame(width: 44, height: 44)
                            .background(Color.appInputBackground)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text(localizedDeletedHistoryTitle))
                    directionMenu
                }
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
                        projectSelectionButton(group)
                    }
                }
            }
        }
    }

    private var documentTypeSection: some View {
        SectionCard(title: localizedReportTitle, titleWeight: .regular) {
            if typeGroups.isEmpty {
                EmptyManagementText(text: localizedNoTypeText)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localizedReportHelpText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(typeGroups) { group in
                        reportCategorySection(group)
                    }
                }
            }
        }
    }

    private var documentListSection: some View {
        SectionCard(title: selectedTypeGroup?.type.localizedTitle(language) ?? localizedDocumentListTitle, titleWeight: .regular) {
            if let selectedTypeGroup {
                VStack(alignment: .leading, spacing: 10) {
                    if isSelectingDocuments {
                        Text(localizedSelectionHelpText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Button {
                                toggleSelectAllDocuments(selectedTypeGroup.documents)
                            } label: {
                                Label(areAllDocumentsSelected(selectedTypeGroup.documents) ? localizedDeselectAllTitle : localizedSelectAllTitle, systemImage: areAllDocumentsSelected(selectedTypeGroup.documents) ? "checkmark.circle" : "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CompanyOutlineButtonStyle())

                            Button {
                                isDeleteConfirmationPresented = true
                            } label: {
                                Label(localizedDeleteTitle, systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CompanyFilledButtonStyle())
                            .disabled(selectedDocumentIDs.isEmpty)
                            .opacity(selectedDocumentIDs.isEmpty ? 0.45 : 1)
                        }
                    }
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
        let isSelected = selectedDocumentIDs.contains(document.id)
        return HStack(alignment: .center, spacing: 10) {
            if isSelectingDocuments {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(isSelected ? buttonAccent : .appMuted)
                    .frame(width: 32, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.number.isEmpty ? document.type.localizedTitle(language) : document.number)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                Text(documentSummary(document))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(2)
            }
            Spacer()

            if !isSelectingDocuments {
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
        }
        .padding(12)
        .background(isSelected ? buttonAccent.opacity(0.10) : Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? buttonAccent : Color.appDivider))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectingDocuments {
                toggleDocumentSelection(document)
            } else {
                openDocumentForEditing(document)
            }
        }
    }

    private func reportCategorySection(_ group: FileDocumentTypeGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Label(group.type.localizedTitle(language), systemImage: group.type.isAttachmentRecord ? "paperclip" : "doc.text")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    selectedDocumentType = group.type
                } label: {
                    Text(localizedOpenCategoryTitle)
                        .font(.caption.weight(.bold))
                        .foregroundColor(buttonAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(buttonAccent.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(spacing: 8) {
                ForEach(group.documents) { document in
                    reportDocumentRow(document)
                }
            }
        }
        .padding(12)
        .background(Color.appInputBackground.opacity(0.65))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func reportDocumentRow(_ document: BusinessDocument) -> some View {
        Button {
            openDocumentForEditing(document)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        reportTag(text: AppFormatters.shortDate(document.issueDate), color: buttonAccent)
                        reportTag(text: document.type.localizedSubtitle(language), color: .appMuted)
                        if let payment = paymentReportStatus(for: document) {
                            reportTag(text: payment.title, color: payment.color)
                        }
                    }
                    .lineLimit(1)

                    Text(reportDocumentTitle(document))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                        .lineLimit(1)

                    Text(reportKeyInfo(document))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(2)

                    if let warning = reportWarningText(document) {
                        Text(warning)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color(red: 0.80, green: 0.18, blue: 0.12))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(reportAmountText(document))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.appInk)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                    Button {
                        onPreviewDocument(document)
                    } label: {
                        Image(systemName: "eye")
                            .font(.caption.weight(.bold))
                            .foregroundColor(buttonAccent)
                            .frame(width: 32, height: 32)
                            .background(buttonAccent.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(localizedPreviewDocumentTitle)
                }
                .frame(width: 94, alignment: .trailing)
            }
            .padding(10)
            .background(Color.appBackground)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDivider))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func reportTag(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func openDocumentForEditing(_ document: BusinessDocument) {
        store.select(document)
        selectedSection = .form
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

    private func projectSelectionButton(_ group: FileProjectGroup) -> some View {
        fileSelectionButton(title: group.name, subtitle: localizedProjectSubtitle(group), systemImage: "folder") {
            selectedProjectGroupID = group.id
            selectedDocumentType = nil
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    quickPreviewProjectGroup = group
                }
        )
    }

    private func openProjectGroupType(_ group: FileProjectGroup, type: DocumentType) {
        if type == .customerOrder,
           let project = projectArchive(for: group.id),
           group.documents.filter({ $0.type == .customerOrder }).isEmpty {
            store.createAdditionalCustomerOrder(project: project)
            selectedSection = .form
            return
        }

        if let document = group.documents
            .filter({ $0.type == type })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first {
            store.select(document)
            selectedSection = .form
            return
        }

        if let project = projectArchive(for: group.id) {
            store.openProjectForm(project: project, type: type)
        } else {
            store.newDocument(type: type)
        }
        selectedSection = .form
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

    private func toggleDocumentSelection(_ document: BusinessDocument) {
        if selectedDocumentIDs.contains(document.id) {
            selectedDocumentIDs.remove(document.id)
        } else {
            selectedDocumentIDs.insert(document.id)
        }
    }

    private func areAllDocumentsSelected(_ documents: [BusinessDocument]) -> Bool {
        !documents.isEmpty && documents.allSatisfy { selectedDocumentIDs.contains($0.id) }
    }

    private func toggleSelectAllDocuments(_ documents: [BusinessDocument]) {
        let ids = Set(documents.map(\.id))
        if areAllDocumentsSelected(documents) {
            selectedDocumentIDs.subtract(ids)
        } else {
            selectedDocumentIDs.formUnion(ids)
        }
    }

    private func clearDocumentSelection() {
        isSelectingDocuments = false
        selectedDocumentIDs.removeAll()
    }

    private func deleteSelectedDocuments() {
        store.deleteDocuments(ids: selectedDocumentIDs)
        clearDocumentSelection()
        if selectedTypeGroup?.documents.isEmpty != false {
            selectedDocumentType = nil
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
        case .simplifiedChinese, .traditionalChinese: return "\(localizedCount(group.documentCount)) / \(projectCount) 个项目"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(localizedCount(group.documentCount)) / \(projectCount) projects"
        }
    }

    private func localizedProjectSubtitle(_ group: FileProjectGroup) -> String {
        let typeCount = Set(group.documents.map(\.type)).count
        switch language {
        case .japanese: return "\(localizedCount(group.documents.count)) / \(typeCount) 種類 / \(AppFormatters.shortDate(group.updatedAt))"
        case .simplifiedChinese, .traditionalChinese: return "\(localizedCount(group.documents.count)) / \(typeCount) 个类别 / \(AppFormatters.shortDate(group.updatedAt))"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(localizedCount(group.documents.count)) / \(typeCount) types / \(AppFormatters.shortDate(group.updatedAt))"
        }
    }

    private func localizedTypeSubtitle(_ group: FileDocumentTypeGroup) -> String {
        switch language {
        case .japanese: return "\(localizedCount(group.documents.count)) / 新しい順"
        case .simplifiedChinese, .traditionalChinese: return "\(localizedCount(group.documents.count)) / 新到旧"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(localizedCount(group.documents.count)) / newest first"
        }
    }

    private func localizedCount(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件"
        case .simplifiedChinese, .traditionalChinese: return "\(count) 笔"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(count) forms"
        }
    }

    private func reportDocumentTitle(_ document: BusinessDocument) -> String {
        let number = document.number.trimmingCharacters(in: .whitespacesAndNewlines)
        return number.isEmpty ? document.type.localizedTitle(language) : "\(document.type.localizedTitle(language)) \(number)"
    }

    private func reportAmountText(_ document: BusinessDocument) -> String {
        if document.type.isAttachmentRecord,
           document.total == 0,
           let proofAmount = document.paymentProofAmount,
           proofAmount > 0 {
            return AppFormatters.yen(proofAmount, language: language)
        }
        return AppFormatters.yen(document.total, language: language)
    }

    private func reportKeyInfo(_ document: BusinessDocument) -> String {
        let attachmentNames = reportAttachmentNames(document)
        let attachmentText = localizedAttachmentSummary(count: reportAttachmentCount(document), names: attachmentNames)
        let dateText = localizedReportDateText(document)
        let partner = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerText = partner.isEmpty ? localizedNoPartnerName : partner
        return "\(dateText) / \(partnerText) / \(attachmentText)"
    }

    private func localizedReportDateText(_ document: BusinessDocument) -> String {
        let issue = AppFormatters.shortDate(document.issueDate)
        let transaction = AppFormatters.shortDate(document.transactionDate)
        switch language {
        case .japanese: return "発行 \(issue) / 取引 \(transaction)"
        case .simplifiedChinese, .traditionalChinese: return "开具 \(issue) / 交易 \(transaction)"
        case .english, .korean, .nepali, .french, .vietnamese: return "Issued \(issue) / transaction \(transaction)"
        }
    }

    private func localizedAttachmentSummary(count: Int, names: [String]) -> String {
        let countText: String
        switch language {
        case .japanese: countText = "\(count) ファイル"
        case .simplifiedChinese, .traditionalChinese: countText = "\(count) 个文件"
        case .english, .korean, .nepali, .french, .vietnamese: countText = "\(count) files"
        }
        guard !names.isEmpty else { return countText }
        return "\(countText): \(names.prefix(2).joined(separator: ", "))"
    }

    private func reportAttachmentCount(_ document: BusinessDocument) -> Int {
        (document.orderAttachments?.count ?? 0) + (document.paymentProofAttachments?.count ?? 0)
    }

    private func reportAttachmentNames(_ document: BusinessDocument) -> [String] {
        ((document.orderAttachments ?? []) + (document.paymentProofAttachments ?? []))
            .map(\.filename)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func reportWarningText(_ document: BusinessDocument) -> String? {
        if document.type.isAttachmentRecord && reportAttachmentCount(document) == 0 {
            return localized(japanese: "警告: 添付ファイルがありません", chinese: "警告：没有上传附件", english: "Warning: no uploaded files")
        }
        if [.invoice, .vendorInvoice, .paymentNotice].contains(document.type),
           paymentReportStatus(for: document)?.isPaid == false {
            return localized(japanese: "未確認: 支払証明ファイルがありません", chinese: "未确认：没有支付证明文件", english: "Unconfirmed: no payment proof file")
        }
        return nil
    }

    private func paymentReportStatus(for document: BusinessDocument) -> (title: String, color: Color, isPaid: Bool)? {
        let needsPaymentStatus: Bool
        switch document.type {
        case .invoice, .vendorInvoice, .paymentNotice:
            needsPaymentStatus = true
        default:
            needsPaymentStatus = false
        }
        guard needsPaymentStatus else { return nil }

        let hasPaymentProof = !(document.paymentProofAttachments ?? []).isEmpty
        if hasPaymentProof {
            let paidTitle: String
            switch document.type {
            case .invoice:
                paidTitle = localized(japanese: "入金済", chinese: "客户已支付", english: "Customer Paid")
            case .vendorInvoice, .paymentNotice:
                paidTitle = localized(japanese: "支払済", chinese: "已支付", english: "Paid")
            default:
                paidTitle = localized(japanese: "支払済", chinese: "已支付", english: "Paid")
            }
            return (paidTitle, Color(red: 0.12, green: 0.56, blue: 0.30), true)
        }

        let unpaidTitle: String
        switch document.type {
        case .invoice:
            unpaidTitle = localized(japanese: "入金待ち", chinese: "等待客户支付", english: "Awaiting Customer")
        case .vendorInvoice, .paymentNotice:
            unpaidTitle = localized(japanese: "支払待ち", chinese: "待支付", english: "Awaiting Payment")
        default:
            unpaidTitle = localized(japanese: "未払い", chinese: "未支付", english: "Unpaid")
        }
        return (unpaidTitle, Color(red: 0.86, green: 0.33, blue: 0.24), false)
    }

    private func documentSummary(_ document: BusinessDocument) -> String {
        let date = AppFormatters.shortDate(document.updatedAt)
        let issueDate = AppFormatters.shortDate(document.issueDate)
        if document.type.isAttachmentRecord {
            let fileCount = (document.orderAttachments?.count ?? 0) + (document.paymentProofAttachments?.count ?? 0)
            switch language {
            case .japanese: return "\(date) 更新 / 発行 \(issueDate) / \(fileCount) ファイル"
            case .simplifiedChinese, .traditionalChinese: return "\(date) 更新 / 开具 \(issueDate) / \(fileCount) 个文件"
            case .english, .korean, .nepali, .french, .vietnamese: return "Updated \(date) / issued \(issueDate) / \(fileCount) files"
            }
        }
        switch language {
        case .japanese: return "\(date) 更新 / 発行 \(issueDate) / \(AppFormatters.yen(document.total, language: language))"
        case .simplifiedChinese, .traditionalChinese: return "\(date) 更新 / 开具 \(issueDate) / \(AppFormatters.yen(document.total, language: language))"
        case .english, .korean, .nepali, .french, .vietnamese: return "Updated \(date) / issued \(issueDate) / \(AppFormatters.yen(document.total, language: language))"
        }
    }

    private var localizedTitle: String { localized(japanese: "ファイル管理", chinese: "文件管理", english: "File Management") }
    private var localizedDirectionMenuTitle: String { localized(japanese: "顧客・仕入先を選択", chinese: "选择客户或供应商", english: "Choose customer or vendor") }
    private var localizedPartnerListTitle: String { direction == .customer ? localized(japanese: "顧客", chinese: "客户", english: "Customers") : localized(japanese: "仕入先", chinese: "供应商", english: "Vendors") }
    private var localizedProjectListTitle: String { localized(japanese: "プロジェクト", chinese: "项目", english: "Projects") }
    private var localizedTypeListTitle: String { localized(japanese: "帳票類別", chinese: "表单类别", english: "Form Types") }
    private var localizedReportTitle: String { localized(japanese: "プロジェクトレポート", chinese: "项目报告", english: "Project Report") }
    private var localizedReportHelpText: String {
        localized(
            japanese: "帳票類別ごとに新しい順で表示します。金額、支払状態、添付ファイル、重要な未確認情報を1行で確認できます。行をタップすると帳票編集へ移動します。",
            chinese: "依照表单类别分区，并按时间新到旧显示。每列集中显示金额、支付状态、附件与重要未确认信息。点击列表可直接进入表单。",
            english: "Grouped by form type and sorted newest first. Each row shows amount, payment status, attachments, and key warnings. Tap a row to open the form."
        )
    }
    private var localizedOpenCategoryTitle: String { localized(japanese: "一覧", chinese: "列表", english: "List") }
    private var localizedDocumentListTitle: String { localized(japanese: "帳票一覧", chinese: "表单列表", english: "Forms") }
    private var localizedEmptyText: String { localized(japanese: "この区分の帳票はまだありません。", chinese: "这个区分还没有表单。", english: "No forms in this category yet.") }
    private var localizedNoProjectsText: String { localized(japanese: "プロジェクトがありません。", chinese: "没有项目。", english: "No projects.") }
    private var localizedNoTypeText: String { localized(japanese: "帳票類別がありません。", chinese: "没有表单类别。", english: "No form types.") }
    private var localizedNoDocumentsText: String { localized(japanese: "帳票がありません。", chinese: "没有表单。", english: "No forms.") }
    private var localizedNoPartnerName: String { localized(japanese: "取引先未入力", chinese: "未填写客户/供应商", english: "No customer/vendor") }
    private var localizedUnassignedProjectTitle: String { localized(japanese: "プロジェクト未指定", chinese: "未指定项目", english: "No Project") }
    private var localizedBackTitle: String { localized(japanese: "戻る", chinese: "返回", english: "Back") }
    private var localizedSelectTitle: String { localized(japanese: "選択", chinese: "选择", english: "Select") }
    private var localizedDoneTitle: String { localized(japanese: "完了", chinese: "完成", english: "Done") }
    private var localizedSelectAllTitle: String { localized(japanese: "全選択", chinese: "全选", english: "Select All") }
    private var localizedDeselectAllTitle: String { localized(japanese: "全解除", chinese: "全部取消", english: "Deselect All") }
    private var localizedDeleteTitle: String { localized(japanese: "削除", chinese: "删除", english: "Delete") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedDeletedHistoryTitle: String { localized(japanese: "削除履歴", chinese: "删除文件", english: "Deleted Files") }
    private var localizedMoveToDeletedHistoryTitle: String { localized(japanese: "削除履歴へ移動", chinese: "移到删除文件", english: "Move to Deleted Files") }
    private var localizedSelectionHelpText: String {
        localized(
            japanese: "選択した帳票は削除履歴へ移動します。30日以内なら削除履歴から復元できます。",
            chinese: "选择的表单会移到删除文件。30 天内可在删除文件里恢复。",
            english: "Selected forms move to Deleted Files and can be restored within 30 days."
        )
    }
    private var localizedDeleteSelectedTitle: String { localized(japanese: "選択した帳票を削除しますか？", chinese: "要删除选择的表单吗？", english: "Delete selected forms?") }
    private var localizedDeleteSelectedMessage: String {
        localized(
            japanese: "削除後も30日間は削除履歴に残り、復元できます。設定画面のデータ消去を実行した場合は削除履歴も含めて完全に空になります。",
            chinese: "删除后会在删除文件保留 30 天，可恢复。如果从设置页面执行资料清除，删除文件也会一起清空，系统会回到完全空白状态。",
            english: "Deleted forms are kept for 30 days and can be restored. Clearing data from Settings also removes Deleted Files and returns the app to a blank state."
        )
    }
    private var localizedPreviewDocumentTitle: String { localized(japanese: "プレビュー", chinese: "预览", english: "Preview") }
    private var localizedEditDocumentTitle: String { localized(japanese: "編集", chinese: "编辑", english: "Edit") }
    private var localizedCopyDocumentTitle: String { localized(japanese: "プロジェクトへコピー", chinese: "复制到项目", english: "Copy to project") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private struct DeletedDocumentHistorySheet: View {
    @ObservedObject var store: DocumentStore
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var selectedRecordIDs: Set<DeletedDocumentRecord.ID> = []
    @State private var isRestoreConfirmationPresented = false
    @State private var isPermanentDeleteConfirmationPresented = false

    var body: some View {
        NavigationView {
            ScrollView {
                sheetContent
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedCloseTitle) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            store.pruneExpiredDeletedDocuments()
        }
        .confirmationDialog(localizedRestoreConfirmTitle, isPresented: $isRestoreConfirmationPresented, titleVisibility: .visible) {
            Button(localizedRestoreTitle) {
                store.restoreDeletedDocuments(ids: selectedRecordIDs)
                selectedRecordIDs.removeAll()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedRestoreConfirmMessage)
        }
        .confirmationDialog(localizedPermanentDeleteConfirmTitle, isPresented: $isPermanentDeleteConfirmationPresented, titleVisibility: .visible) {
            Button(localizedPermanentDeleteTitle, role: .destructive) {
                store.permanentlyDeleteDeletedDocuments(ids: selectedRecordIDs)
                selectedRecordIDs.removeAll()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedPermanentDeleteConfirmMessage)
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            historyHelpText
            historyContent
        }
        .padding(18)
    }

    private var historyHelpText: some View {
        Text(localizedHelpText)
            .font(.caption.weight(.semibold))
            .foregroundColor(.appMuted)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var historyContent: some View {
        if store.deletedDocuments.isEmpty {
            EmptyManagementText(text: localizedEmptyText)
        } else {
            historyActions
            deletedRecordList
        }
    }

    private var historyActions: some View {
        VStack(spacing: 10) {
            selectAllHistoryButton

            HStack(spacing: 10) {
                restoreHistoryButton
                permanentDeleteHistoryButton
            }
        }
    }

    private var selectAllHistoryButton: some View {
        Button {
            toggleSelectAll()
        } label: {
            Label(isAllSelected ? localizedDeselectAllTitle : localizedSelectAllTitle, systemImage: isAllSelected ? "checkmark.circle" : "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CompanyOutlineButtonStyle())
    }

    private var restoreHistoryButton: some View {
        Button {
            isRestoreConfirmationPresented = true
        } label: {
            Label(localizedRestoreTitle, systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CompanyFilledButtonStyle())
        .disabled(selectedRecordIDs.isEmpty)
        .opacity(selectedRecordIDs.isEmpty ? 0.45 : 1)
    }

    private var permanentDeleteHistoryButton: some View {
        Button {
            isPermanentDeleteConfirmationPresented = true
        } label: {
            Label(localizedPermanentDeleteShortTitle, systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CompanyOutlineButtonStyle())
        .disabled(selectedRecordIDs.isEmpty)
        .opacity(selectedRecordIDs.isEmpty ? 0.45 : 1)
    }

    private var deletedRecordList: some View {
        VStack(spacing: 10) {
            ForEach(store.deletedDocuments) { record in
                deletedRecordRow(record)
            }
        }
    }

    private var isAllSelected: Bool {
        !store.deletedDocuments.isEmpty && store.deletedDocuments.allSatisfy { selectedRecordIDs.contains($0.id) }
    }

    private func toggleSelectAll() {
        let ids = Set(store.deletedDocuments.map(\.id))
        if isAllSelected {
            selectedRecordIDs.removeAll()
        } else {
            selectedRecordIDs = ids
        }
    }

    private func toggleRecord(_ record: DeletedDocumentRecord) {
        if selectedRecordIDs.contains(record.id) {
            selectedRecordIDs.remove(record.id)
        } else {
            selectedRecordIDs.insert(record.id)
        }
    }

    private func deletedRecordRow(_ record: DeletedDocumentRecord) -> some View {
        let isSelected = selectedRecordIDs.contains(record.id)
        let document = record.document
        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundColor(isSelected ? buttonAccent : .appMuted)
                .frame(width: 32, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(document.number.isEmpty ? document.type.localizedTitle(language) : document.number)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                Text(deletedRecordSummary(record))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(isSelected ? buttonAccent.opacity(0.10) : Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? buttonAccent : Color.appDivider))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleRecord(record)
        }
    }

    private func deletedRecordSummary(_ record: DeletedDocumentRecord) -> String {
        let deletedAt = AppFormatters.shortDate(record.deletedAt)
        let expiresAt = AppFormatters.shortDate(record.expiresAt)
        switch language {
        case .japanese: return "\(record.document.type.localizedTitle(language)) / 削除 \(deletedAt) / 保留期限 \(expiresAt)"
        case .simplifiedChinese, .traditionalChinese: return "\(record.document.type.localizedTitle(language)) / 删除 \(deletedAt) / 保留到 \(expiresAt)"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(record.document.type.localizedTitle(language)) / deleted \(deletedAt) / kept until \(expiresAt)"
        }
    }

    private var localizedTitle: String { localized(japanese: "削除履歴", chinese: "删除文件", english: "Deleted Files") }
    private var localizedHelpText: String {
        localized(
            japanese: "通常の削除では帳票を30日間ここに保留します。復元すると元の帳票一覧に戻ります。ここで完全削除した帳票、または設定画面でデータ消去した内容は復元できません。",
            chinese: "一般删除的表单会在这里保留 30 天。恢复后会回到原本的表单列表。在这里永久删除的表单，或从设置页面清除的数据，都无法恢复。",
            english: "Regularly deleted forms stay here for 30 days. Restoring returns them to the form list. Permanently deleted forms, or content cleared from Settings, cannot be restored."
        )
    }
    private var localizedEmptyText: String { localized(japanese: "削除された帳票はありません。", chinese: "没有已删除的表单。", english: "No deleted forms.") }
    private var localizedSelectAllTitle: String { localized(japanese: "全選択", chinese: "全选", english: "Select All") }
    private var localizedDeselectAllTitle: String { localized(japanese: "全解除", chinese: "全部取消", english: "Deselect All") }
    private var localizedRestoreTitle: String { localized(japanese: "復元", chinese: "恢复", english: "Restore") }
    private var localizedPermanentDeleteShortTitle: String { localized(japanese: "完全削除", chinese: "永久删除", english: "Delete") }
    private var localizedPermanentDeleteTitle: String { localized(japanese: "完全に削除", chinese: "永久删除", english: "Permanently Delete") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedCloseTitle: String { localized(japanese: "閉じる", chinese: "关闭", english: "Close") }
    private var localizedRestoreConfirmTitle: String { localized(japanese: "選択した帳票を復元しますか？", chinese: "要恢复选择的表单吗？", english: "Restore selected forms?") }
    private var localizedRestoreConfirmMessage: String {
        localized(
            japanese: "復元した帳票は通常のファイル管理リストに戻ります。",
            chinese: "恢复后的表单会回到一般文件管理列表。",
            english: "Restored forms return to the normal file management list."
        )
    }
    private var localizedPermanentDeleteConfirmTitle: String { localized(japanese: "完全削除しますか？", chinese: "要永久删除吗？", english: "Permanently delete?") }
    private var localizedPermanentDeleteConfirmMessage: String {
        localized(
            japanese: "選択した帳票を削除履歴から完全に削除します。この操作は取り消せず、復元できません。",
            chinese: "选择的表单会从删除文件中永久删除。此操作无法取消，也无法恢复。",
            english: "Selected forms will be removed from Deleted Files. This cannot be undone or restored."
        )
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private struct ExternalAttachmentImport: Identifiable {
    let id = UUID()
    let urls: [URL]
    var sourceDirectory: URL? = nil
}

private struct ExternalAttachmentImportSheet: View {
    @ObservedObject var store: DocumentStore
    let importRequest: ExternalAttachmentImport
    let language: AppLanguage
    let onComplete: (BusinessDocument) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var direction: ProjectDirection = .customer
    @State private var projectMode: ExternalAttachmentProjectMode = .existing
    @State private var selectedCompanyName: String?
    @State private var selectedProjectID: ProjectArchive.ID?
    @State private var selectedType: DocumentType = .customerOrder
    @State private var statusText = ""

    private var allowedTypes: [DocumentType] {
        switch direction {
        case .customer: return [.customerOrder]
        case .vendor: return [.vendorEstimate, .vendorInvoice, .vendorReceipt]
        }
    }

    private var availableProjects: [ProjectArchive] {
        store.projects.filter { $0.direction == direction }
    }

    private var availableCompanyNames: [String] {
        var seen = Set<String>()
        return availableProjects.compactMap { project in
            let name = project.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return name
        }
    }

    private var selectedCompanyProjects: [ProjectArchive] {
        guard projectMode == .existing, let selectedCompanyName else { return [] }
        return availableProjects.filter {
            $0.customerName.trimmingCharacters(in: .whitespacesAndNewlines) == selectedCompanyName
        }
    }

    private var selectedProject: ProjectArchive? {
        guard projectMode == .existing, let selectedProjectID else { return nil }
        return selectedCompanyProjects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(localizedHelpText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    SectionCard(title: localizedFileTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(importRequest.urls, id: \.absoluteString) { url in
                                Label(url.lastPathComponent, systemImage: iconName(for: url))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.appInk)
                                    .lineLimit(2)
                            }
                        }
                    }

                    SectionCard(title: localizedProjectTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker(localizedDirectionTitle, selection: $direction) {
                                ForEach(ProjectDirection.allCases) { item in
                                    Text(item.localizedTitle(language)).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)

                            Picker(localizedProjectModeTitle, selection: $projectMode) {
                                Text(localizedExistingProjectTitle).tag(ExternalAttachmentProjectMode.existing)
                                Text(localizedNewProjectTitle).tag(ExternalAttachmentProjectMode.new)
                            }
                            .pickerStyle(.segmented)

                            if projectMode == .existing {
                                if availableProjects.isEmpty {
                                    Text(localizedNoProjectText)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.appMuted)
                                } else {
                                    Picker(localizedCompanyPickerTitle, selection: $selectedCompanyName) {
                                        Text(localizedChooseCompanyTitle).tag(nil as String?)
                                        ForEach(availableCompanyNames, id: \.self) { companyName in
                                            Text(companyDisplayName(companyName)).tag(Optional(companyName))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.appInputBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))

                                    if selectedCompanyName == nil {
                                        Text(localizedChooseCompanyHelpText)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.appMuted)
                                    } else if selectedCompanyProjects.isEmpty {
                                        Text(localizedNoProjectForCompanyText)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.appMuted)
                                    } else {
                                        VStack(alignment: .leading, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(localizedCompanyProjectListTitle)
                                                    .font(.caption.weight(.bold))
                                                    .foregroundColor(.appInk)
                                                Text(localizedCompanyProjectListHelpText)
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundColor(.appMuted)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }

                                            VStack(spacing: 10) {
                                                ForEach(selectedCompanyProjects) { project in
                                                    Button {
                                                        selectedProjectID = project.id
                                                    } label: {
                                                        HStack(spacing: 10) {
                                                            Image(systemName: selectedProjectID == project.id ? "checkmark.circle.fill" : "circle")
                                                                .foregroundColor(selectedProjectID == project.id ? buttonAccent : .appMuted)
                                                            VStack(alignment: .leading, spacing: 3) {
                                                                Text(project.name)
                                                                    .font(.subheadline.weight(.semibold))
                                                                    .foregroundColor(.appInk)
                                                                    .lineLimit(1)
                                                                Text(projectSummary(project))
                                                                    .font(.caption.weight(.semibold))
                                                                    .foregroundColor(.appMuted)
                                                                    .lineLimit(1)
                                                            }
                                                            Spacer()
                                                        }
                                                        .padding(12)
                                                        .background(selectedProjectID == project.id ? buttonAccent.opacity(0.10) : Color.appInputBackground)
                                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedProjectID == project.id ? buttonAccent : Color.appDivider))
                                                        .cornerRadius(8)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                        .padding(.top, 10)
                                    }
                                }
                            }
                        }
                    }

                    SectionCard(title: localizedFormTitle, titleWeight: .regular) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizedFormHelpText)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.appMuted)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(allowedTypes) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: selectedType == type ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedType == type ? buttonAccent : .appMuted)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(type.localizedTitle(language))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.appInk)
                                            Text(type.localizedSubtitle(language))
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.appMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(selectedType == type ? buttonAccent.opacity(0.10) : Color.appInputBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedType == type ? buttonAccent : Color.appDivider))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(12)
                        .background(buttonAccent.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appDivider))
                        .cornerRadius(10)
                    }

                    if !statusText.isEmpty {
                        Text(statusText)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                    }

                    ManagementPrimaryButton(title: localizedImportTitle, systemImage: "paperclip") {
                        importFiles()
                    }
                    .disabled(projectMode == .existing && selectedProject == nil)
                    .opacity(projectMode == .existing && selectedProject == nil ? 0.45 : 1)
                }
                .padding(18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(localizedTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedCancelTitle) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            selectedType = allowedTypes.first ?? .customerOrder
            resetExistingProjectSelection()
        }
        .onChange(of: direction) { _ in
            selectedType = allowedTypes.first ?? .customerOrder
            resetExistingProjectSelection()
        }
        .onChange(of: projectMode) { _ in
            if projectMode == .existing {
                resetExistingProjectSelection()
            } else {
                selectedCompanyName = nil
                selectedProjectID = nil
            }
        }
        .onChange(of: selectedCompanyName) { _ in
            selectedProjectID = selectedCompanyProjects.first?.id
        }
    }

    private func resetExistingProjectSelection() {
        projectMode = availableProjects.isEmpty ? .new : .existing
        selectedCompanyName = nil
        selectedProjectID = nil
    }

    private func importFiles() {
        let project = projectMode == .existing ? selectedProject : nil
        let count = store.importExternalAttachments(from: importRequest.urls, into: project, direction: direction, type: selectedType)
        guard count > 0 else {
            statusText = localizedImportFailedText
            return
        }
        onComplete(store.current)
        dismiss()
    }

    private func iconName(for url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true ? "doc.richtext" : "photo"
    }

    private func companyDisplayName(_ name: String) -> String {
        name.isEmpty ? localizedNoCompanyTitle : name
    }

    private func projectSummary(_ project: ProjectArchive) -> String {
        "\(project.completedCount)/\(project.direction.requiredTypes.count) / \(AppFormatters.shortDate(project.updatedAt))"
    }

    private var localizedTitle: String { localized(japanese: "ファイルを帳票へ取り込む", chinese: "导入文件到表单", english: "Import Files to Form") }
    private var localizedHelpText: String {
        localized(
            japanese: "PDFは1件、写真は複数件を取り込めます。既存プロジェクトまたは新規プロジェクトを選び、ファイル添付に対応した帳票を選択してください。",
            chinese: "PDF 每次只导入 1 个，照片可多张导入。请选择现有项目或建立新项目，再选择支持文件上传的表单。",
            english: "One PDF or multiple photos can be imported. Choose an existing or new project, then select an upload-enabled form."
        )
    }
    private var localizedFileTitle: String { localized(japanese: "取り込むファイル", chinese: "要导入的文件", english: "Files to Import") }
    private var localizedProjectTitle: String { localized(japanese: "プロジェクト", chinese: "项目", english: "Project") }
    private var localizedDirectionTitle: String { localized(japanese: "帳票カテゴリ", chinese: "表单类别", english: "Form Category") }
    private var localizedProjectModeTitle: String { localized(japanese: "プロジェクト", chinese: "项目", english: "Project") }
    private var localizedExistingProjectTitle: String { localized(japanese: "既存プロジェクト", chinese: "现有项目", english: "Existing Project") }
    private var localizedNewProjectTitle: String { localized(japanese: "新規プロジェクト", chinese: "新项目", english: "New Project") }
    private var localizedNoProjectText: String { localized(japanese: "既存プロジェクトがありません。新規プロジェクトを選択してください。", chinese: "没有现有项目。请选择新项目。", english: "No existing projects. Choose New Project.") }
    private var localizedCompanyPickerTitle: String { direction == .customer ? localized(japanese: "顧客会社", chinese: "客户公司", english: "Customer Company") : localized(japanese: "仕入先会社", chinese: "供应商公司", english: "Vendor Company") }
    private var localizedChooseCompanyTitle: String { localized(japanese: "会社を選択", chinese: "选择公司", english: "Choose Company") }
    private var localizedChooseCompanyHelpText: String { localized(japanese: "会社を選択すると、その会社のプロジェクト一覧が表示されます。", chinese: "选择公司后，会显示该公司下面的项目列表。", english: "Choose a company to show its project list.") }
    private var localizedCompanyProjectListTitle: String { localized(japanese: "この会社のプロジェクト", chinese: "这家公司的项目", english: "Projects for This Company") }
    private var localizedCompanyProjectListHelpText: String { localized(japanese: "先に添付先のプロジェクトを選択してください。", chinese: "请先选择要附加文件的项目。", english: "Choose the project that should receive the imported file.") }
    private var localizedNoProjectForCompanyText: String { localized(japanese: "この会社のプロジェクトがありません。", chinese: "这家公司没有项目。", english: "No projects for this company.") }
    private var localizedNoCompanyTitle: String { localized(japanese: "会社未入力", chinese: "未填写公司", english: "No company") }
    private var localizedFormTitle: String { localized(japanese: "ファイル対応帳票", chinese: "支持上传的表单", english: "Upload-Enabled Forms") }
    private var localizedFormHelpText: String { localized(japanese: "選んだプロジェクト内で、今回のファイルを入れる帳票種類を選択します。", chinese: "在已选项目中，选择这次文件要导入的表单类型。", english: "Choose the form type inside the selected project for this file.") }
    private var localizedImportTitle: String { localized(japanese: "この帳票へ取り込む", chinese: "导入到这个表单", english: "Import to This Form") }
    private var localizedCancelTitle: String { localized(japanese: "キャンセル", chinese: "取消", english: "Cancel") }
    private var localizedImportFailedText: String { localized(japanese: "ファイルを読み込めませんでした。", chinese: "无法读取文件。", english: "Could not read the files.") }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private enum ExternalAttachmentProjectMode: String {
    case existing
    case new
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

private struct FileProjectQuickPreviewSheet: View {
    let group: FileProjectGroup
    let direction: ProjectDirection
    let language: AppLanguage
    let onOpenType: (DocumentType) -> Void
    let onOpenDocument: (BusinessDocument) -> Void
    let onCopyDocument: (BusinessDocument) -> Void
    let onSettings: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var isDeleteConfirmationPresented = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var completedTypeCount: Int {
        direction.requiredTypes.filter { type in
            group.documents.contains { $0.type == type }
        }.count
    }

    var body: some View {
        ZStack {
            Color.appBackground.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(direction.requiredTypes) { type in
                            quickTypeCard(type)
                        }
                    }
                }
                .padding(22)
                .background(Color.appPanel)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appDivider))
                .cornerRadius(18)
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
            }
        }
        .confirmationDialog(localizedDeleteTitle, isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button(localizedDeleteTitle, role: .destructive) {
                onDelete()
                dismiss()
            }
            Button(localizedCancelTitle, role: .cancel) {}
        } message: {
            Text(localizedDeleteMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: direction == .customer ? "person.crop.square.filled.and.at.rectangle" : "building.2.crop.circle")
                .font(.title3.weight(.semibold))
                .foregroundColor(buttonAccent)
                .frame(width: 60, height: 60)
                .background(buttonAccent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(2)
                Text(progressText)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(group.id == FileProjectGroup.unassignedID)
            .opacity(group.id == FileProjectGroup.unassignedID ? 0.35 : 1)
            .accessibilityLabel(localizedSettingsTitle)

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Image(systemName: "trash")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(localizedDeleteTitle)
        }
    }

    private func quickTypeCard(_ type: DocumentType) -> some View {
        let documents = group.documents
            .filter { $0.type == type }
            .sorted { $0.updatedAt > $1.updatedAt }
        let document = documents.first

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(type.localizedTitle(language))
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(2)

                Spacer(minLength: 6)

                if let document {
                    Button {
                        onCopyDocument(document)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(localizedCopyTitle)
                } else if type == .customerOrder || group.id != FileProjectGroup.unassignedID {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(buttonAccent)
                        .opacity(0.75)
                }
            }

            Text(documentNumberText(document))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(document == nil ? .appMuted : .appInk)
                .lineLimit(1)

            if documents.count > 1 {
                Text(countText(documents.count))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(document == nil ? Color.appInputBackground.opacity(0.55) : Color.appInputBackground)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(document == nil ? Color.appDivider.opacity(0.65) : Color.appDivider))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if let document {
                onOpenDocument(document)
            } else {
                onOpenType(type)
            }
            dismiss()
        }
    }

    private var progressText: String {
        switch language {
        case .japanese:
            return "\(direction.localizedTitle(language)) / \(completedTypeCount)/\(direction.requiredTypes.count) 件完了"
        case .simplifiedChinese, .traditionalChinese:
            return "\(direction.localizedTitle(language)) / \(completedTypeCount)/\(direction.requiredTypes.count) 个完成"
        case .english, .korean, .nepali, .french, .vietnamese:
            return "\(direction.localizedTitle(language)) / \(completedTypeCount)/\(direction.requiredTypes.count) complete"
        }
    }

    private func documentNumberText(_ document: BusinessDocument?) -> String {
        guard let document else { return localizedNotCreatedText }
        return document.number.isEmpty ? document.type.localizedTitle(language) : document.number
    }

    private func countText(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件"
        case .simplifiedChinese, .traditionalChinese: return "\(count) 笔"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(count) forms"
        }
    }

    private var localizedNotCreatedText: String {
        switch language {
        case .japanese: return "未作成"
        case .simplifiedChinese, .traditionalChinese: return "未创建"
        case .english, .korean, .nepali, .french, .vietnamese: return "Not created"
        }
    }

    private var localizedSettingsTitle: String {
        switch language {
        case .japanese: return "プロジェクト設定"
        case .simplifiedChinese, .traditionalChinese: return "项目设置"
        case .english, .korean, .nepali, .french, .vietnamese: return "Project settings"
        }
    }

    private var localizedCopyTitle: String {
        switch language {
        case .japanese: return "コピー"
        case .simplifiedChinese, .traditionalChinese: return "复制"
        case .english, .korean, .nepali, .french, .vietnamese: return "Copy"
        }
    }

    private var localizedDeleteTitle: String {
        switch language {
        case .japanese: return "削除"
        case .simplifiedChinese, .traditionalChinese: return "删除"
        case .english, .korean, .nepali, .french, .vietnamese: return "Delete"
        }
    }

    private var localizedCancelTitle: String {
        switch language {
        case .japanese: return "キャンセル"
        case .simplifiedChinese, .traditionalChinese: return "取消"
        case .english, .korean, .nepali, .french, .vietnamese: return "Cancel"
        }
    }

    private var localizedDeleteMessage: String {
        switch language {
        case .japanese: return "このプロジェクト内の帳票を削除履歴へ移動します。30日以内なら削除履歴から復元できます。"
        case .simplifiedChinese, .traditionalChinese: return "这个项目里的表单会移到删除文件。30 天内可在删除文件里恢复。"
        case .english, .korean, .nepali, .french, .vietnamese: return "The forms in this project move to Deleted Files and can be restored within 30 days."
        }
    }
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
        return store.makeProjectArchive(direction: sourceDirection, customerName: cleanCustomerName)
    }

    private func projectSubtitle(_ project: ProjectArchive, hasExisting: Bool) -> String {
        let status = hasExisting ? localizedHasExistingText : localizedNoExistingText
        switch language {
        case .japanese: return "\(project.direction.localizedTitle(language)) / \(status)"
        case .simplifiedChinese, .traditionalChinese: return "\(project.direction.localizedTitle(language)) / \(status)"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(project.direction.localizedTitle(language)) / \(status)"
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
        case .simplifiedChinese, .traditionalChinese:
            return "将覆盖 \(projectName) 里现有的 \(typeName)。此操作无法撤销。"
        case .english, .korean, .nepali, .french, .vietnamese:
            return "This will overwrite the existing \(typeName) in \(projectName). This cannot be undone."
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
    @State private var expandedProjectIDs: Set<ProjectArchive.ID> = []
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
                                    ProjectArchiveRow(project: project, language: language, isExpanded: expandedProjectIDs.contains(project.id), isHighlighted: highlightedProjectID == project.id) { type in
                                        store.openProjectForm(project: project, type: type)
                                        selectedSection = .form
                                    } onToggleExpanded: {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                            if expandedProjectIDs.contains(project.id) {
                                                expandedProjectIDs.remove(project.id)
                                            } else {
                                                expandedProjectIDs.insert(project.id)
                                            }
                                        }
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
        expandedProjectIDs.insert(focusedProjectID)

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
        case .simplifiedChinese, .traditionalChinese: return "文件与项目管理"
        case .english, .korean, .nepali, .french, .vietnamese: return "Files and Projects"
        }
    }

    private var localizedProjectManagementSubtitle: String {
        switch language {
        case .japanese: return "顧客書類をプロジェクトとしてまとめ、必要な帳票の進捗を確認します。"
        case .simplifiedChinese, .traditionalChinese: return "将客户文件按项目汇总，并确认所需表单的进度。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Group customer documents by project and track required forms."
        }
    }

    private var localizedFreePlanTitle: String {
        switch language {
        case .japanese: return "無料版"
        case .simplifiedChinese, .traditionalChinese: return "免费版"
        case .english, .korean, .nepali, .french, .vietnamese: return "Free Plan"
        }
    }

    private var localizedFreePlanMessage: String {
        switch language {
        case .japanese: return "無料版でもプロジェクト作成と帳票管理を利用できます。ProではPDFプレビュー共有とGoogle Driveバックアップも利用できます。"
        case .simplifiedChinese, .traditionalChinese: return "免费版也可使用项目创建与表单管理。Pro 可继续使用 PDF 预览分享与 Google Drive 备份。"
        case .english, .korean, .nepali, .french, .vietnamese: return "The free plan can create projects and manage forms. Pro adds PDF preview sharing and Google Drive backup."
        }
    }

    private var localizedUpgradeTitle: String {
        switch language {
        case .japanese: return "Proで共有・バックアップを使う"
        case .simplifiedChinese, .traditionalChinese: return "升级 Pro 使用分享与备份"
        case .english, .korean, .nepali, .french, .vietnamese: return "Use Sharing and Backup with Pro"
        }
    }

    private var localizedAddTitle: String {
        switch language {
        case .japanese: return "追加"
        case .simplifiedChinese, .traditionalChinese: return "新增"
        case .english, .korean, .nepali, .french, .vietnamese: return "Add"
        }
    }

    private var localizedProjectListTitle: String {
        switch language {
        case .japanese: return "プロジェクト一覧"
        case .simplifiedChinese, .traditionalChinese: return "项目列表"
        case .english, .korean, .nepali, .french, .vietnamese: return "Projects"
        }
    }

    private var localizedEmptyProjectsText: String {
        switch language {
        case .japanese: return "保存済みのプロジェクトはありません。右上の追加ボタンからプロジェクトを作成してください。"
        case .simplifiedChinese, .traditionalChinese: return "没有已保存项目。请通过右上角的新增按钮建立项目。"
        case .english, .korean, .nepali, .french, .vietnamese: return "No saved projects. Use the add button to create one."
        }
    }

    private var localizedProjectCategoryTitle: String {
        switch language {
        case .japanese: return "プロジェクト分類"
        case .simplifiedChinese, .traditionalChinese: return "项目分类"
        case .english, .korean, .nepali, .french, .vietnamese: return "Project Category"
        }
    }

    private var localizedCompanySearchPlaceholder: String {
        switch language {
        case .japanese: return "会社名で検索"
        case .simplifiedChinese, .traditionalChinese: return "按公司名搜索"
        case .english, .korean, .nepali, .french, .vietnamese: return "Search by company"
        }
    }

    private var localizedNoMatchingProjectsText: String {
        switch language {
        case .japanese: return "条件に一致するプロジェクトはありません。"
        case .simplifiedChinese, .traditionalChinese: return "没有符合条件的项目。"
        case .english, .korean, .nepali, .french, .vietnamese: return "No projects match the filters."
        }
    }

    private var localizedDeleteProjectTitle: String {
        switch language {
        case .japanese: return "プロジェクトを削除しますか？"
        case .simplifiedChinese, .traditionalChinese: return "要删除项目吗？"
        case .english, .korean, .nepali, .french, .vietnamese: return "Delete this project?"
        }
    }

    private var localizedDeleteTitle: String {
        switch language {
        case .japanese: return "削除"
        case .simplifiedChinese, .traditionalChinese: return "删除"
        case .english, .korean, .nepali, .french, .vietnamese: return "Delete"
        }
    }

    private var localizedCancelTitle: String {
        switch language {
        case .japanese: return "キャンセル"
        case .simplifiedChinese, .traditionalChinese: return "取消"
        case .english, .korean, .nepali, .french, .vietnamese: return "Cancel"
        }
    }

    private var localizedDeleteProjectMessage: String {
        switch language {
        case .japanese: return "プロジェクト内の帳票をすべて削除履歴へ移動します。30日以内なら削除履歴から復元できます。"
        case .simplifiedChinese, .traditionalChinese: return "项目内的所有表单都会移到删除文件。30 天内可在删除文件里恢复。"
        case .english, .korean, .nepali, .french, .vietnamese: return "All forms in this project move to Deleted Files and can be restored within 30 days."
        }
    }

    private var localizedNewProjectTitle: String {
        switch language {
        case .japanese: return "新規プロジェクト"
        case .simplifiedChinese, .traditionalChinese: return "新项目"
        case .english, .korean, .nepali, .french, .vietnamese: return "New Project"
        }
    }

    private var localizedPartnerPickerTitle: String {
        switch language {
        case .japanese: return "取引先・仕入先"
        case .simplifiedChinese, .traditionalChinese: return "客户/供应商"
        case .english, .korean, .nepali, .french, .vietnamese: return "Customer or Vendor"
        }
    }

    private var localizedNoSelectionTitle: String {
        switch language {
        case .japanese: return "未選択"
        case .simplifiedChinese, .traditionalChinese: return "未选择"
        case .english, .korean, .nepali, .french, .vietnamese: return "Not selected"
        }
    }

    private var localizedCreateProjectTitle: String {
        switch language {
        case .japanese: return "プロジェクトを作成"
        case .simplifiedChinese, .traditionalChinese: return "建立项目"
        case .english, .korean, .nepali, .french, .vietnamese: return "Create Project"
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
            case .simplifiedChinese, .traditionalChinese: return "全部"
            case .english, .korean, .nepali, .french, .vietnamese: return "All"
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
                                .lineLimit(1)
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        case .vendorInvoice: return "doc.richtext.fill"
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
    let isExpanded: Bool
    var isHighlighted = false
    let onOpenForm: (DocumentType) -> Void
    let onToggleExpanded: () -> Void
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
                Button(action: onToggleExpanded) {
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
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(projectProgressText)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.appMuted)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 24, height: 38)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
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

            if isExpanded {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
        case .simplifiedChinese, .traditionalChinese: return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) 个完成"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(project.direction.localizedTitle(language)) / \(project.completedCount)/\(project.direction.requiredTypes.count) complete"
        }
    }

    private var localizedNotCreatedText: String {
        switch language {
        case .japanese: return "未作成"
        case .simplifiedChinese, .traditionalChinese: return "未创建"
        case .english, .korean, .nepali, .french, .vietnamese: return "Not created"
        }
    }

    private var localizedAddOrderRecordText: String {
        switch language {
        case .japanese: return "受注を追加"
        case .simplifiedChinese, .traditionalChinese: return "新增受注"
        case .english, .korean, .nepali, .french, .vietnamese: return "Add order received"
        }
    }

    private var localizedTapToCreateText: String {
        switch language {
        case .japanese: return "タップして作成"
        case .simplifiedChinese, .traditionalChinese: return "点击创建"
        case .english, .korean, .nepali, .french, .vietnamese: return "Tap to create"
        }
    }

    private var localizedCopyDocumentText: String {
        switch language {
        case .japanese: return "プロジェクトへコピー"
        case .simplifiedChinese, .traditionalChinese: return "复制到项目"
        case .english, .korean, .nepali, .french, .vietnamese: return "Copy to project"
        }
    }

    private func localizedCountText(_ count: Int) -> String {
        switch language {
        case .japanese: return "\(count) 件"
        case .simplifiedChinese, .traditionalChinese: return "\(count) 个"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(count)"
        }
    }

    private func orderRecordSummary(_ record: BusinessDocument) -> String {
        let attachmentCount = record.orderAttachments?.count ?? 0
        switch language {
        case .japanese:
            return "\(attachmentCount) ファイル / \(record.lines.count) 項目\(record.relatedNumber.isEmpty ? "" : " / \(record.relatedNumber)")"
        case .simplifiedChinese, .traditionalChinese:
            return "\(attachmentCount) 个文件 / \(record.lines.count) 个品项\(record.relatedNumber.isEmpty ? "" : " / \(record.relatedNumber)")"
        case .english, .korean, .nepali, .french, .vietnamese:
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private enum CustomerProfileRiskAction {
    case update
    case delete(CustomerProfile)
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
    @State private var pendingRiskAction: CustomerProfileRiskAction?
    @State private var isRiskConfirmationPresented = false
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
                                requestDeleteCustomer(customer)
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
        .confirmationDialog(localizedRiskConfirmTitle, isPresented: $isRiskConfirmationPresented, titleVisibility: .visible) {
            switch pendingRiskAction {
            case .update:
                Button(localizedCreateNewDataTitle) {
                    performCustomerSave(asNewRecord: true)
                }
                Button(localizedUpdateExistingDataTitle, role: .destructive) {
                    performCustomerSave(asNewRecord: false)
                }
                Button(localizedCancelTitle, role: .cancel) {
                    pendingRiskAction = nil
                }
            case .delete(let customer):
                Button(localizedDeleteExistingDataTitle, role: .destructive) {
                    store.deleteCustomer(customer)
                    pendingRiskAction = nil
                }
                Button(localizedCancelTitle, role: .cancel) {
                    pendingRiskAction = nil
                }
            case nil:
                Button(localizedCancelTitle, role: .cancel) {}
            }
        } message: {
            Text(localizedRiskConfirmMessage)
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
                requestSaveCustomerForm()
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

    private func requestSaveCustomerForm() {
        if let editingCustomerID,
           let customer = store.customers.first(where: { $0.id == editingCustomerID }),
           store.savedDocumentUsageCount(for: customer) > 0 {
            pendingRiskAction = .update
            isRiskConfirmationPresented = true
            return
        }
        performCustomerSave(asNewRecord: false)
    }

    private func performCustomerSave(asNewRecord: Bool) {
        if let editingCustomerID {
            if asNewRecord {
                store.saveCustomerProfile(name: customerName, contact: customerContact, phone: customerPhone, email: customerEmail, address: customerAddress)
            } else {
                store.updateCustomerProfile(id: editingCustomerID, name: customerName, contact: customerContact, phone: customerPhone, email: customerEmail, address: customerAddress)
            }
        } else {
            store.saveCustomerProfile(name: customerName, contact: customerContact, phone: customerPhone, email: customerEmail, address: customerAddress)
        }
        pendingRiskAction = nil
        clearCustomerForm()
        isCustomerEditorPresented = false
    }

    private func requestDeleteCustomer(_ customer: CustomerProfile) {
        guard store.savedDocumentUsageCount(for: customer) > 0 else {
            store.deleteCustomer(customer)
            return
        }
        pendingRiskAction = .delete(customer)
        isRiskConfirmationPresented = true
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
    private var localizedRiskConfirmTitle: String { localized(japanese: "保存済み帳票で使用中です", chinese: "此资料已被已保存表单使用", english: "Used by Saved Forms") }
    private var localizedCreateNewDataTitle: String { localized(japanese: "新しいデータとして作成", chinese: "建立全新的资料", english: "Create New Data") }
    private var localizedUpdateExistingDataTitle: String { localized(japanese: "既存データを更新", chinese: "更新现有资料", english: "Update Existing Data") }
    private var localizedDeleteExistingDataTitle: String { localized(japanese: "候補データを削除", chinese: "删除候选资料", english: "Delete Candidate Data") }

    private var localizedRiskConfirmMessage: String {
        let count: Int
        switch pendingRiskAction {
        case .update:
            if let editingCustomerID,
               let customer = store.customers.first(where: { $0.id == editingCustomerID }) {
                count = store.savedDocumentUsageCount(for: customer)
            } else {
                count = 0
            }
        case .delete(let customer):
            count = store.savedDocumentUsageCount(for: customer)
        case nil:
            count = 0
        }
        return localized(
            japanese: "\(count)件の保存済み帳票でこの取引先候補が使われています。データ管理から編集しても、完成済み帳票の内容は自動で書き換えられません。履歴を分ける場合は新しいデータとして作成してください。",
            chinese: "目前有 \(count) 份已保存表单使用这笔客户/供应商资料。从数据管理修改候选资料，不会自动回头改写已完成表单内容。为了保留历史，建议建立全新的资料。",
            english: "\(count) saved forms use this customer/vendor candidate. Editing it from Data Management does not automatically rewrite completed forms. Create new data to preserve history."
        )
    }

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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        case .simplifiedChinese, .traditionalChinese: return "\(kind.localizedTitle(language))列表"
        case .english, .korean, .nepali, .french, .vietnamese: return "\(kind.localizedTitle(language)) Templates"
        }
    }

    private func localizedEmptyTemplateText(_ kind: TextTemplateKind) -> String {
        switch language {
        case .japanese: return "\(kind.localizedTitle(language))のテンプレートはありません。"
        case .simplifiedChinese, .traditionalChinese: return "没有\(kind.localizedTitle(language))模板。"
        case .english, .korean, .nepali, .french, .vietnamese: return "No \(kind.localizedTitle(language).lowercased()) templates."
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

private enum ProductProfileRiskAction {
    case update
    case delete(ProductProfile)
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
    @State private var pendingRiskAction: ProductProfileRiskAction?
    @State private var isRiskConfirmationPresented = false
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
                                requestDeleteProduct(product)
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
        .confirmationDialog(localizedRiskConfirmTitle, isPresented: $isRiskConfirmationPresented, titleVisibility: .visible) {
            switch pendingRiskAction {
            case .update:
                Button(localizedCreateNewDataTitle) {
                    performProductSave(asNewRecord: true)
                }
                Button(localizedUpdateExistingDataTitle, role: .destructive) {
                    performProductSave(asNewRecord: false)
                }
                Button(localizedCancelTitle, role: .cancel) {
                    pendingRiskAction = nil
                }
            case .delete(let product):
                Button(localizedDeleteExistingDataTitle, role: .destructive) {
                    store.deleteProduct(product)
                    pendingRiskAction = nil
                }
                Button(localizedCancelTitle, role: .cancel) {
                    pendingRiskAction = nil
                }
            case nil:
                Button(localizedCancelTitle, role: .cancel) {}
            }
        } message: {
            Text(localizedRiskConfirmMessage)
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
                requestSaveProductForm()
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

    private func requestSaveProductForm() {
        if let editingProductID,
           let product = store.products.first(where: { $0.id == editingProductID }),
           store.savedDocumentUsageCount(for: product) > 0 {
            pendingRiskAction = .update
            isRiskConfirmationPresented = true
            return
        }
        performProductSave(asNewRecord: false)
    }

    private func performProductSave(asNewRecord: Bool) {
        if let editingProductID {
            if asNewRecord {
                store.saveProductProfile(name: productName, model: productModel, specification: productSpecification, unitPrice: productUnitPrice)
            } else {
                store.updateProductProfile(id: editingProductID, name: productName, model: productModel, specification: productSpecification, unitPrice: productUnitPrice)
            }
        } else {
            store.saveProductProfile(name: productName, model: productModel, specification: productSpecification, unitPrice: productUnitPrice)
        }
        pendingRiskAction = nil
        clearProductForm()
        isProductEditorPresented = false
    }

    private func requestDeleteProduct(_ product: ProductProfile) {
        guard store.savedDocumentUsageCount(for: product) > 0 else {
            store.deleteProduct(product)
            return
        }
        pendingRiskAction = .delete(product)
        isRiskConfirmationPresented = true
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
    private var localizedRiskConfirmTitle: String { localized(japanese: "保存済み帳票で使用中です", chinese: "此品项已被已保存表单使用", english: "Used by Saved Forms") }
    private var localizedCreateNewDataTitle: String { localized(japanese: "新しいデータとして作成", chinese: "建立全新的资料", english: "Create New Data") }
    private var localizedUpdateExistingDataTitle: String { localized(japanese: "既存データを更新", chinese: "更新现有资料", english: "Update Existing Data") }
    private var localizedDeleteExistingDataTitle: String { localized(japanese: "候補データを削除", chinese: "删除候选资料", english: "Delete Candidate Data") }

    private var localizedRiskConfirmMessage: String {
        let count: Int
        switch pendingRiskAction {
        case .update:
            if let editingProductID,
               let product = store.products.first(where: { $0.id == editingProductID }) {
                count = store.savedDocumentUsageCount(for: product)
            } else {
                count = 0
            }
        case .delete(let product):
            count = store.savedDocumentUsageCount(for: product)
        case nil:
            count = 0
        }
        return localized(
            japanese: "\(count)件の保存済み帳票でこの商品・項目候補が使われています。データ管理から編集しても、完成済み帳票の明細は自動で書き換えられません。履歴を分ける場合は新しいデータとして作成してください。",
            chinese: "目前有 \(count) 份已保存表单使用这个商品/品项资料。从数据管理修改候选资料，不会自动回头改写已完成表单明细。为了保留历史，建议建立全新的资料。",
            english: "\(count) saved forms use this item candidate. Editing it from Data Management does not automatically rewrite completed form line items. Create new data to preserve history."
        )
    }

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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        }
    }
}

struct CompanyFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appButtonAccent) private var buttonAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.cardTitle(.semibold))
            .lineLimit(1)
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
            .font(AppFont.cardTitle(.semibold))
            .lineLimit(1)
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
            .font(AppFont.secondary(.semibold))
            .lineLimit(1)
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
                    .font(AppFont.cardTitle(.semibold))
                    .foregroundColor(.appInk)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFont.secondary(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let applyTitle = applyTitle {
                Button(applyTitle, action: onApply)
                    .font(AppFont.secondary(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(buttonAccent.opacity(0.12))
                    .foregroundColor(buttonAccent)
                    .cornerRadius(7)
            }
            if let editTitle = editTitle {
                Button(editTitle, action: onEdit)
                    .font(AppFont.secondary(.semibold))
                    .lineLimit(1)
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
                .font(AppFont.cardTitle(.semibold))
                .lineLimit(1)
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
                .font(AppFont.cardTitle(.semibold))
                .lineLimit(1)
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
                    .font(AppFont.cardTitle(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                if !value.isEmpty {
                    Text(value)
                        .font(AppFont.secondary(.semibold))
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
                    .font(AppFont.cardTitle(.semibold))
                    .lineLimit(2)
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
                .font(AppFont.secondary(.semibold))
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
            .font(AppFont.secondary(.semibold))
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
            .font(AppFont.cardTitle(.semibold))
            .foregroundColor(.white)
            .lineLimit(2)
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
            .font(AppFont.cardTitle(.semibold))
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
#if DEBUG
        return
#else
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
#endif
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
        case .traditionalChinese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .nepali, .french, .vietnamese: return AppInlineLocalization.value(english: english, chinese: chinese, language: language)
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
