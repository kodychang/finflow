import SwiftUI
import UIKit

struct SidebarView: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var purchaseService: PurchaseService
    @Binding var selectedSection: AppSection
    var onOpenRecentProject: ((ProjectArchive) -> Void)? = nil
    var onPreviewDocument: ((BusinessDocument) -> Void)? = nil
    var onCreateStartRequested: (() -> Void)? = nil
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var isSelectingRecentDocuments = false
    @State private var selectedRecentDocumentIDs: Set<BusinessDocument.ID> = []
    @State private var isDeleteConfirmationPresented = false
    @State private var isPreviewActionDialogPresented = false
    @State private var isServiceSupportPresented = false
    @State private var pendingProjectDocumentType: DocumentType?
    @State private var pendingPreviewDocument: BusinessDocument?
    @State private var pendingDeleteDocument: BusinessDocument?
    private var language: AppLanguage { store.interfaceLanguage }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let homeButtonIconSize: CGFloat = 44
    private let homeButtonVerticalPadding: CGFloat = 8
    private var visibleRecentDocuments: [BusinessDocument] {
        Array(store.documents.prefix(12))
    }
    private var visibleRecentProjects: [ProjectArchive] {
        Array(store.projects.prefix(3))
    }
    private let previewCardWidth: CGFloat = 118
    private let previewCardHeight: CGFloat = 168

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        Text(AppText.value(.documents, language))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appInk)
                        Spacer()
                        Button {
                            isServiceSupportPresented = true
                        } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundColor(buttonAccent)
                                .frame(width: 44, height: 44)
                                .background(buttonAccent.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(ServiceSupportContent.localized(.buttonAccessibilityLabel, language))
                    }

                    recentProjectsSection
                }

                recentPreviewSection(direction: .customer)
                recentPreviewSection(direction: .vendor)

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading(AppText.value(.management, language), actionTitle: nil)
                    managementButton(title: AppText.value(.accountManagement, language), subtitle: localizedManagementSubtitle(.account), systemImage: "person.crop.circle", section: .account)
                    managementButton(title: localizedCompanyTitle, subtitle: localizedManagementSubtitle(.company), systemImage: "building.columns", section: .company)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .background(Color.appSidebar.edgesIgnoringSafeArea(.all))
        .confirmationDialog(deleteConfirmationTitle, isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button(localized(japanese: "削除", chinese: "删除", english: "Delete"), role: .destructive) {
                confirmDelete()
            }
            Button(localized(japanese: "キャンセル", chinese: "取消", english: "Cancel"), role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .confirmationDialog(previewActionTitle, isPresented: $isPreviewActionDialogPresented, titleVisibility: .visible) {
            Button(localized(japanese: "PDFプレビュー", chinese: "PDF 预览", english: "PDF Preview")) {
                openPendingPreviewDocument()
            }
            Button(localized(japanese: "削除", chinese: "删除", english: "Delete"), role: .destructive) {
                let document = pendingPreviewDocument
                pendingPreviewDocument = nil
                pendingDeleteDocument = document
                DispatchQueue.main.async {
                    isDeleteConfirmationPresented = document != nil
                }
            }
            Button(localized(japanese: "キャンセル", chinese: "取消", english: "Cancel"), role: .cancel) {
                pendingPreviewDocument = nil
            }
        }
        .sheet(isPresented: $isServiceSupportPresented) {
            ServiceSupportScreen(language: language)
        }
        .sheet(item: $pendingProjectDocumentType) { documentType in
            ProjectSelectionSheet(
                store: store,
                documentType: documentType,
                language: language,
                onSelectProject: { project in
                    store.openProjectForm(project: project, type: documentType)
                    pendingProjectDocumentType = nil
                    selectedSection = .form
                },
                onCreateProject: {
                    store.createProject(direction: projectDirection(for: documentType), customer: nil, initialType: documentType)
                    selectedSection = .form
                    pendingProjectDocumentType = nil
                }
            )
        }
    }

    private var canCreateProject: Bool { true }

    private var deleteConfirmationTitle: String {
        if pendingDeleteDocument != nil {
            return localized(
                japanese: "この帳票を削除しますか？",
                chinese: "要删除这个表单吗？",
                english: "Delete this form?"
            )
        }
        return localized(
            japanese: "選択した帳票を削除しますか？",
            chinese: "要删除选中的表单吗？",
            english: "Delete selected forms?"
        )
    }

    private var deleteConfirmationMessage: String {
        if let pendingDeleteDocument {
            let title = pendingDeleteDocument.type.localizedTitle(language)
            switch language {
            case .japanese: return "\(title) を削除します。この操作は取り消せません。"
            case .simplifiedChinese: return "将删除 \(title)。此操作无法撤销。"
            case .english: return "\(title) will be deleted. This cannot be undone."
            }
        }
        switch language {
        case .japanese: return "\(selectedRecentDocumentIDs.count) 件の帳票を削除します。この操作は取り消せません。"
        case .simplifiedChinese: return "将删除 \(selectedRecentDocumentIDs.count) 个表单。此操作无法撤销。"
        case .english: return "\(selectedRecentDocumentIDs.count) forms will be deleted. This cannot be undone."
        }
    }

    private var previewActionTitle: String {
        pendingPreviewDocument?.type.localizedTitle(language) ?? localized(japanese: "帳票操作", chinese: "表单操作", english: "Form Actions")
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        }
    }

    private var recentDocumentsHeader: some View {
        HStack(spacing: 8) {
            Text(AppText.value(.recentDocuments, language))
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
            Spacer()
            if !visibleRecentDocuments.isEmpty {
                Button {
                    toggleRecentSelectionMode()
                } label: {
                    Text(isSelectingRecentDocuments ? localized(japanese: "完了", chinese: "完成", english: "Done") : localized(japanese: "選択", chinese: "选择", english: "Select"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(buttonAccent)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var recentProjectsHeader: some View {
        HStack(spacing: 8) {
            Text(recentProjectsTitle)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
            Spacer()
            if !visibleRecentProjects.isEmpty {
                Button {
                    selectedSection = .projects
                } label: {
                    Text(recentProjectsMoreTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(buttonAccent)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            recentProjectsHeader

            if visibleRecentProjects.isEmpty {
                Text(recentProjectsEmptyText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.appSidebarCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            } else {
                ForEach(visibleRecentProjects) { project in
                    recentProjectButton(project)
                }
            }
        }
    }

    private var recentProjectsTitle: String {
        switch language {
        case .japanese: return "最近のプロジェクト"
        case .simplifiedChinese: return "最近项目"
        case .english: return "Recent Projects"
        }
    }

    private var recentProjectsMoreTitle: String {
        switch language {
        case .japanese: return "もっと見る"
        case .simplifiedChinese: return "更多"
        case .english: return "More"
        }
    }

    private var recentProjectsEmptyText: String {
        switch language {
        case .japanese: return "保存済みのプロジェクトはありません。"
        case .simplifiedChinese: return "没有已保存项目。"
        case .english: return "No saved projects."
        }
    }

    private var recentSelectionActions: some View {
        HStack(spacing: 8) {
            Button {
                toggleSelectAllRecentDocuments()
            } label: {
                Label(isAllVisibleRecentDocumentsSelected ? localized(japanese: "全解除", chinese: "全部取消", english: "Deselect All") : localized(japanese: "全選択", chinese: "全选", english: "Select All"), systemImage: isAllVisibleRecentDocumentsSelected ? "checkmark.circle" : "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RecentSelectionActionStyle(tint: buttonAccent))

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Label(localized(japanese: "削除", chinese: "删除", english: "Delete"), systemImage: "trash")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RecentSelectionActionStyle(tint: .red))
            .disabled(selectedRecentDocumentIDs.isEmpty)
            .opacity(selectedRecentDocumentIDs.isEmpty ? 0.45 : 1)
        }
    }

    private var isAllVisibleRecentDocumentsSelected: Bool {
        !visibleRecentDocuments.isEmpty && visibleRecentDocuments.allSatisfy { selectedRecentDocumentIDs.contains($0.id) }
    }

    private func recentDocumentButton(_ document: BusinessDocument) -> some View {
        let isSelected = selectedRecentDocumentIDs.contains(document.id)
        return Button {
            if isSelectingRecentDocuments {
                toggleRecentDocumentSelection(document)
            } else {
                store.select(document)
                selectedSection = .form
            }
        } label: {
            HStack(spacing: 10) {
                if isSelectingRecentDocuments {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(isSelected ? buttonAccent : .appMuted)
                        .frame(width: homeButtonIconSize, height: homeButtonIconSize)
                }
                Text("\(document.type.localizedTitle(language)) \(document.number)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, homeButtonVerticalPadding)
            .frame(minHeight: homeButtonIconSize + homeButtonVerticalPadding * 2)
            .background(isSelected ? buttonAccent.opacity(0.12) : Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? buttonAccent : Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func recentProjectButton(_ project: ProjectArchive) -> some View {
        Button {
            if let onOpenRecentProject {
                onOpenRecentProject(project)
            } else {
                selectedSection = .projects
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: project.direction == .customer ? "folder.fill" : "building.2.crop.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: homeButtonIconSize, height: homeButtonIconSize)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())
                Text(project.name)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, homeButtonVerticalPadding)
            .frame(minHeight: homeButtonIconSize + homeButtonVerticalPadding * 2)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleRecentSelectionMode() {
        isSelectingRecentDocuments.toggle()
        if !isSelectingRecentDocuments {
            selectedRecentDocumentIDs.removeAll()
        }
    }

    private func toggleRecentDocumentSelection(_ document: BusinessDocument) {
        if selectedRecentDocumentIDs.contains(document.id) {
            selectedRecentDocumentIDs.remove(document.id)
        } else {
            selectedRecentDocumentIDs.insert(document.id)
        }
    }

    private func toggleSelectAllRecentDocuments() {
        let visibleIDs = Set(visibleRecentDocuments.map(\.id))
        if isAllVisibleRecentDocumentsSelected {
            selectedRecentDocumentIDs.subtract(visibleIDs)
        } else {
            selectedRecentDocumentIDs.formUnion(visibleIDs)
        }
    }

    private func deleteSelectedRecentDocuments() {
        store.deleteDocuments(ids: selectedRecentDocumentIDs)
        selectedRecentDocumentIDs.removeAll()
        isSelectingRecentDocuments = false
    }

    private func confirmDelete() {
        if let pendingDeleteDocument {
            store.delete(pendingDeleteDocument)
            self.pendingDeleteDocument = nil
            pendingPreviewDocument = nil
        } else {
            deleteSelectedRecentDocuments()
        }
    }

    private func openPendingPreviewDocument() {
        guard let document = pendingPreviewDocument else { return }
        if let onPreviewDocument {
            onPreviewDocument(document)
        } else {
            store.select(document)
            selectedSection = .preview
        }
        pendingPreviewDocument = nil
    }

    private func recentPreviewSection(direction: ProjectDirection) -> some View {
        let documents = visiblePreviewDocuments(for: direction)

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeading(direction.localizedTitle(language), actionTitle: nil)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(documents) { document in
                        recentPreviewCard(document)
                    }

                    createPreviewCard(direction: direction)
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func visiblePreviewDocuments(for direction: ProjectDirection) -> [BusinessDocument] {
        Array(
            store.documents
                .filter { direction.requiredTypes.contains($0.type) }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(10)
        )
    }

    private func recentPreviewCard(_ document: BusinessDocument) -> some View {
        SidebarDocumentPreviewCard(
            document: document,
            language: language,
            width: previewCardWidth,
            height: previewCardHeight,
            isCurrentSavedDocument: isCurrentSavedDocument(document)
        )
        .contentShape(Rectangle())
        .gesture(
            ExclusiveGesture(
                LongPressGesture(minimumDuration: 0.45),
                TapGesture()
            )
            .onEnded { value in
                switch value {
                case .first:
                    pendingPreviewDocument = document
                    isPreviewActionDialogPresented = true
                case .second:
                    store.select(document)
                    selectedSection = .form
                }
            }
        )
    }

    private func isCurrentSavedDocument(_ document: BusinessDocument) -> Bool {
        store.hasActiveDocument &&
            store.current.id == document.id &&
            store.documents.contains { $0.id == document.id }
    }

    private func createPreviewCard(direction: ProjectDirection) -> some View {
        Button {
            if let onCreateStartRequested {
                onCreateStartRequested()
            } else {
                store.resetCurrentDocumentSelection()
                selectedSection = .form
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(buttonAccent)
                    .frame(width: 44, height: 44)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())

                Text(createCardTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)

                Text(direction.localizedTitle(language))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: previewCardWidth, height: previewCardHeight)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var createCardTitle: String {
        switch language {
        case .japanese: return "作成"
        case .simplifiedChinese: return "创建"
        case .english: return "Create"
        }
    }

    private func documentTypeSection(_ title: String, types: [DocumentType]) -> some View {
        Group {
            if !types.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading(title, actionTitle: nil)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(types) { type in
                            documentTypeButton(type)
                        }
                    }
                }
            }
        }
    }

    private func documentTypeButton(_ type: DocumentType) -> some View {
        Button {
            if type == .customerFiles {
                selectedSection = .projects
            } else {
                pendingProjectDocumentType = type
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName(for: type))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accentColor(for: type))
                    .frame(width: homeButtonIconSize, height: homeButtonIconSize)
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
            .padding(.vertical, homeButtonVerticalPadding)
            .frame(maxWidth: .infinity, minHeight: homeButtonIconSize + homeButtonVerticalPadding * 2, alignment: .leading)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.current.type == type ? buttonAccent : Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func projectDirection(for type: DocumentType) -> ProjectDirection {
        ProjectDirection.customer.requiredTypes.contains(type) ? .customer : .vendor
    }

    private func sectionHeading(_ text: String, actionTitle: String?) -> some View {
        HStack {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
            Spacer()
            if let actionTitle {
                Text(actionTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(buttonAccent)
            }
        }
    }

    private func managementButton(title: String, subtitle: String, systemImage: String, section: AppSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(selectedSection == section ? .white : buttonAccent)
                    .frame(width: homeButtonIconSize, height: homeButtonIconSize)
                    .background(selectedSection == section ? buttonAccent : buttonAccent.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, homeButtonVerticalPadding)
            .frame(minHeight: homeButtonIconSize + homeButtonVerticalPadding * 2)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedSection == section ? buttonAccent : Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func localizedManagementSubtitle(_ section: AppSection) -> String {
        switch (section, language) {
        case (.account, .japanese): return "表示、配色、バックアップ"
        case (.account, .simplifiedChinese): return "显示、配色与备份"
        case (.account, .english): return "Display, color, and backups"
        case (.company, .japanese): return "\(store.issuers.count) 件の自社情報"
        case (.company, .simplifiedChinese): return "\(store.issuers.count) 个公司资料"
        case (.company, .english): return "\(store.issuers.count) company profiles"
        case (.files, .japanese): return "\(store.documents.count) 件の帳票"
        case (.files, .simplifiedChinese): return "\(store.documents.count) 个表单"
        case (.files, .english): return "\(store.documents.count) forms"
        case (.projects, .japanese): return "\(store.projects.count) 件のプロジェクト"
        case (.projects, .simplifiedChinese): return "\(store.projects.count) 个项目"
        case (.projects, .english): return "\(store.projects.count) projects"
        case (.customers, .japanese): return "\(store.customers.count) 件の取引先"
        case (.customers, .simplifiedChinese): return "\(store.customers.count) 个客户/供应商"
        case (.customers, .english): return "\(store.customers.count) customers/vendors"
        case (.products, .japanese): return "\(store.products.count) 件の商品"
        case (.products, .simplifiedChinese): return "\(store.products.count) 个商品"
        case (.products, .english): return "\(store.products.count) products"
        case (.templates, .japanese): return "\(store.textTemplates.count) 件のテンプレート"
        case (.templates, .simplifiedChinese): return "\(store.textTemplates.count) 个模板"
        case (.templates, .english): return "\(store.textTemplates.count) templates"
        case (.pro, .japanese): return purchaseService.hasProAccess ? "有効" : "共有・バックアップ"
        case (.pro, .simplifiedChinese): return purchaseService.hasProAccess ? "已启用" : "分享与备份"
        case (.pro, .english): return purchaseService.hasProAccess ? "Active" : "Sharing and backup"
        default: return ""
        }
    }

    private var localizedFileManagementTitle: String {
        switch language {
        case .japanese: return "ファイル管理"
        case .simplifiedChinese: return "文件管理"
        case .english: return "File Management"
        }
    }

    private var localizedCompanyTitle: String {
        switch language {
        case .japanese: return "会社設定"
        case .simplifiedChinese: return "公司设置"
        case .english: return "Company"
        }
    }

    private var localizedTemplateTitle: String {
        switch language {
        case .japanese: return "振込・備考テンプレート"
        case .simplifiedChinese: return "汇款与备注模板"
        case .english: return "Payment and Note Templates"
        }
    }

    private var unassignedCustomerText: String {
        switch language {
        case .japanese: return "取引先未入力"
        case .simplifiedChinese: return "未填写交易对象"
        case .english: return "No partner"
        }
    }

    private func iconName(for type: DocumentType) -> String {
        switch type {
        case .estimate:
            return "doc.plaintext.fill"
        case .customerOrder:
            return "person.text.rectangle.fill"
        case .purchaseOrder:
            return "cart.fill"
        case .delivery:
            return "shippingbox.fill"
        case .invoice:
            return "doc.text.fill"
        case .receipt:
            return "checkmark.seal.fill"
        case .acceptance:
            return "tray.full.fill"
        case .customerFiles:
            return "folder.fill"
        case .vendorEstimate:
            return "doc.text.magnifyingglass"
        case .vendorReceipt:
            return "checkmark.rectangle.stack.fill"
        case .paymentNotice:
            return "yensign.circle.fill"
        }
    }

    private func accentColor(for type: DocumentType) -> Color {
        switch type {
        case .estimate:
            return Color(red: 0.929, green: 0.286, blue: 0.510)
        case .customerOrder:
            return .appMint
        case .purchaseOrder:
            return Color(red: 0.565, green: 0.435, blue: 0.898)
        case .delivery:
            return Color(red: 0.922, green: 0.553, blue: 0.196)
        case .invoice:
            return .appAccent
        case .receipt:
            return .appBlue
        case .acceptance:
            return Color(red: 0.212, green: 0.702, blue: 0.816)
        case .customerFiles:
            return Color(red: 0.431, green: 0.533, blue: 0.678)
        case .vendorEstimate:
            return Color(red: 0.145, green: 0.388, blue: 0.922)
        case .vendorReceipt:
            return Color(red: 0.212, green: 0.702, blue: 0.816)
        case .paymentNotice:
            return Color(red: 0.706, green: 0.325, blue: 0.035)
        }
    }
}

private struct ServiceSupportScreen: View {
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var searchQuery = ""

    private var content: ServiceSupportContent {
        ServiceSupportContent(language: language)
    }

    private var cleanSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredFaqCategories: [ServiceSupportContent.Category] {
        guard !cleanSearchQuery.isEmpty else { return content.faqCategories }
        return content.faqCategories.compactMap { category in
            let items = category.items.filter { matches(category.title, $0.title, $0.body) }
            if items.isEmpty && matches(category.title) {
                return category
            }
            return items.isEmpty ? nil : ServiceSupportContent.Category(title: category.title, items: items)
        }
    }

    private var filteredTutorials: [ServiceSupportContent.Item] {
        guard !cleanSearchQuery.isEmpty else { return content.tutorials }
        return content.tutorials.filter { matches($0.title, $0.body) }
    }

    private var filteredTechnicalIssues: [ServiceSupportContent.Item] {
        guard !cleanSearchQuery.isEmpty else { return content.technicalIssues }
        return content.technicalIssues.filter { matches($0.title, $0.body) }
    }

    private var filteredWorkplaceScenarios: [ServiceSupportContent.Item] {
        guard !cleanSearchQuery.isEmpty else { return content.workplaceScenarios }
        return content.workplaceScenarios.filter { matches($0.title, $0.body) }
    }

    private var isTutorialVideoVisible: Bool {
        cleanSearchQuery.isEmpty || matches(content.tutorialVideoTitle, content.tutorialVideoBody, content.openTutorialVideoTitle, "YouTube")
    }

    private var hasSearchResults: Bool {
        !filteredFaqCategories.isEmpty || !filteredTutorials.isEmpty || !filteredTechnicalIssues.isEmpty || !filteredWorkplaceScenarios.isEmpty || isTutorialVideoVisible
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    searchField
                    supportSummary
                    if cleanSearchQuery.isEmpty || hasSearchResults {
                        if isTutorialVideoVisible {
                            tutorialVideoSection
                        }
                        if cleanSearchQuery.isEmpty || !filteredWorkplaceScenarios.isEmpty {
                            workplaceScenarioSection
                        }
                        if cleanSearchQuery.isEmpty || !filteredFaqCategories.isEmpty {
                            faqSection
                        }
                        if cleanSearchQuery.isEmpty || !filteredTutorials.isEmpty {
                            tutorialSection
                        }
                        if cleanSearchQuery.isEmpty || !filteredTechnicalIssues.isEmpty {
                            technicalSupportSection
                        }
                    } else {
                        EmptyManagementText(text: content.noSearchResultsText)
                    }
                    refundSection
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(content.closeTitle) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(content.title, systemImage: "lifepreserver.fill")
                .font(.title3.weight(.black))
                .foregroundColor(.appInk)
            Text(content.subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
            TextField("", text: $searchQuery, prompt: .inputPrompt(content.searchPlaceholder))
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.appInk)
            Spacer()
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
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
    }

    private var supportSummary: some View {
        ServiceSupportCard(title: content.afterSalesTitle, systemImage: "building.2.crop.circle") {
            VStack(alignment: .leading, spacing: 10) {
                ServiceInfoRow(title: content.companyLabel, value: "NIIX株式会社")
                ServiceInfoRow(title: content.emailLabel, value: "service@niix.jp")
                ServiceInfoRow(title: content.websiteLabel, value: "https://niix.jp")
                Text(content.afterSalesBody)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: URL(string: "https://niix.jp")!) {
                    Label(content.openWebsiteTitle, systemImage: "safari.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(buttonAccent)
                }
            }
        }
    }

    private var tutorialVideoSection: some View {
        ServiceSupportCard(title: content.tutorialVideoTitle, systemImage: "play.rectangle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text(content.tutorialVideoBody)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: URL(string: "https://youtu.be/BflAHTcUtSY")!) {
                    Label(content.openTutorialVideoTitle, systemImage: "arrow.up.right.square.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(buttonAccent)
                }
            }
        }
    }

    private var workplaceScenarioSection: some View {
        ServiceSupportCard(title: content.workplaceScenarioTitle, systemImage: "briefcase.fill") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredWorkplaceScenarios) { scenario in
                    ServiceBulletBlock(item: scenario)
                }
            }
        }
    }

    private var faqSection: some View {
        ServiceSupportCard(title: content.faqTitle, systemImage: "questionmark.bubble.fill") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(filteredFaqCategories) { category in
                    ServiceCategoryBlock(category: category)
                }
            }
        }
    }

    private var tutorialSection: some View {
        ServiceSupportCard(title: content.tutorialTitle, systemImage: "list.bullet.rectangle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredTutorials) { tutorial in
                    ServiceBulletBlock(item: tutorial)
                }
            }
        }
    }

    private var refundSection: some View {
        ServiceSupportCard(title: content.refundTitle, systemImage: "arrow.uturn.backward.circle.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text(content.refundBody)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: URL(string: "https://reportaproblem.apple.com")!) {
                    Label(content.openRefundTitle, systemImage: "arrow.up.right.square.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(buttonAccent)
                }
            }
        }
    }

    private var technicalSupportSection: some View {
        ServiceSupportCard(title: content.technicalSupportTitle, systemImage: "wrench.and.screwdriver.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text(content.technicalSupportBody)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(content.ticketInfo)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appInk)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredTechnicalIssues) { issue in
                        ServiceBulletBlock(item: issue)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func matches(_ values: String...) -> Bool {
        values.joined(separator: " ").localizedCaseInsensitiveContains(cleanSearchQuery)
    }
}

private struct ProjectSelectionSheet: View {
    @ObservedObject var store: DocumentStore
    let documentType: DocumentType
    let language: AppLanguage
    let onSelectProject: (ProjectArchive) -> Void
    let onCreateProject: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent

    private var direction: ProjectDirection {
        ProjectDirection.customer.requiredTypes.contains(documentType) ? .customer : .vendor
    }

    private var selectableProjects: [ProjectArchive] {
        store.projects.filter { project in
            project.direction == direction && project.document(for: documentType) == nil
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(documentType.localizedTitle(language))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appInk)
                        Text(selectionMessage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appMuted)
                    }

                    SectionCard(title: recentProjectTitle, titleWeight: .regular) {
                        if selectableProjects.isEmpty {
                            EmptyManagementText(text: noSelectableProjectText)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(selectableProjects) { project in
                                    Button {
                                        onSelectProject(project)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "folder.fill")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(buttonAccent)
                                                .frame(width: 44, height: 44)
                                                .background(buttonAccent.opacity(0.12))
                                                .clipShape(Circle())
                                            Text(project.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.appInk)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.appMuted)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .frame(minHeight: 60)
                                        .background(Color.appInputBackground)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    ManagementPrimaryButton(title: createProjectTitle, systemImage: "folder.badge.plus") {
                        onCreateProject()
                    }
                }
                .padding(18)
            }
            .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            .navigationTitle(sheetTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var sheetTitle: String {
        switch language {
        case .japanese: return "プロジェクトを選択"
        case .simplifiedChinese: return "选择项目"
        case .english: return "Select Project"
        }
    }

    private var selectionMessage: String {
        switch language {
        case .japanese: return "この帳票が未作成の最近5件のプロジェクトから選ぶか、新しいプロジェクトを作成してください。"
        case .simplifiedChinese: return "请选择最近 5 个尚未创建该表单的项目，或建立一个新项目。"
        case .english: return "Choose from the 5 most recent projects without this form, or create a new project."
        }
    }

    private var recentProjectTitle: String {
        switch language {
        case .japanese: return "選択できる最近のプロジェクト"
        case .simplifiedChinese: return "可选择的最近项目"
        case .english: return "Available Recent Projects"
        }
    }

    private var noSelectableProjectText: String {
        switch language {
        case .japanese: return "この帳票を追加できる最近のプロジェクトはありません。新しいプロジェクトを作成してください。"
        case .simplifiedChinese: return "最近项目中没有可加入该表单的项目。请建立新项目。"
        case .english: return "No recent project can accept this form. Create a new project."
        }
    }

    private var createProjectTitle: String {
        switch language {
        case .japanese: return "新しいプロジェクトを作成"
        case .simplifiedChinese: return "建立新项目"
        case .english: return "Create New Project"
        }
    }

    private var cancelTitle: String {
        switch language {
        case .japanese: return "キャンセル"
        case .simplifiedChinese: return "取消"
        case .english: return "Cancel"
        }
    }

    private var unassignedCustomerText: String {
        switch language {
        case .japanese: return "取引先未入力"
        case .simplifiedChinese: return "未填写交易对象"
        case .english: return "No partner"
        }
    }
}

private struct ServiceSupportCard<Content: View>: View {
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
    }
}

private struct ServiceInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.appMuted)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

private struct ServiceCategoryBlock: View {
    let category: ServiceSupportContent.Category

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
            ForEach(category.items) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text(item.body)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.appMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 12)
                .padding(.vertical, 2)
                .overlay(Rectangle().fill(Color.appDivider).frame(width: 2), alignment: .leading)
            }
        }
    }
}

private struct ServiceBulletBlock: View {
    let item: ServiceSupportContent.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appInk)
            Text(item.body)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

private struct ServiceSupportContent {
    struct Category: Identifiable {
        let title: String
        let items: [Item]

        var id: String { title }
    }

    struct Item: Identifiable {
        let title: String
        let body: String

        var id: String { title }
    }

    enum TextKey {
        case buttonAccessibilityLabel
    }

    let language: AppLanguage

    static func localized(_ key: TextKey, _ language: AppLanguage) -> String {
        switch (key, language) {
        case (.buttonAccessibilityLabel, .japanese): return "サービス専用ページを開く"
        case (.buttonAccessibilityLabel, .simplifiedChinese): return "打开服务专区"
        case (.buttonAccessibilityLabel, .english): return "Open service center"
        }
    }

    var title: String {
        switch language {
        case .japanese: return "サービス専用ページ"
        case .simplifiedChinese: return "服务专区"
        case .english: return "Service Center"
        }
    }

    var subtitle: String {
        switch language {
        case .japanese: return "よくある質問、操作ガイド、返金、技術サポートを確認できます。"
        case .simplifiedChinese: return "查看常见问题、操作流程教程、退款机制、服务与技术支持。"
        case .english: return "Find FAQs, workflow tutorials, refunds, service, and technical support."
        }
    }

    var searchPlaceholder: String {
        switch language {
        case .japanese: return "FAQ、技術問題、操作方法を検索"
        case .simplifiedChinese: return "搜索常见问题、技术问题、操作教程"
        case .english: return "Search FAQs, technical issues, tutorials"
        }
    }

    var noSearchResultsText: String {
        switch language {
        case .japanese: return "一致するサポート項目はありません。"
        case .simplifiedChinese: return "没有符合条件的客服内容。"
        case .english: return "No matching support items."
        }
    }

    var closeTitle: String {
        switch language {
        case .japanese: return "閉じる"
        case .simplifiedChinese: return "关闭"
        case .english: return "Close"
        }
    }

    var afterSalesTitle: String {
        switch language {
        case .japanese: return "アフターサービス基本情報"
        case .simplifiedChinese: return "售后服务基本信息"
        case .english: return "After-Sales Service"
        }
    }

    var companyLabel: String {
        switch language {
        case .japanese: return "会社"
        case .simplifiedChinese: return "公司"
        case .english: return "Company"
        }
    }

    var emailLabel: String {
        switch language {
        case .japanese: return "メール"
        case .simplifiedChinese: return "邮箱"
        case .english: return "Email"
        }
    }

    var websiteLabel: String {
        switch language {
        case .japanese: return "サイト"
        case .simplifiedChinese: return "网站"
        case .english: return "Website"
        }
    }

    var afterSalesBody: String {
        switch language {
        case .japanese: return "帳票作成、保存、PDF出力、Google Drive同期、購入後のお問い合わせをサポートします。ご連絡時は、アプリ名、端末、iOSバージョン、発生した画面、直前の操作、業務上急いでいる書類の種類を添えてください。"
        case .simplifiedChinese: return "我们支持表单创建、保存、PDF 输出、Google Drive 同步与购买后的咨询。联系时请附上 App 名称、设备、iOS 版本、发生问题的画面、问题前的操作，以及业务上急需处理的文件类型。"
        case .english: return "We support form creation, saving, PDF export, Google Drive sync, and post-purchase questions. When contacting us, include the app name, device, iOS version, affected screen, previous operation, and the document type that is urgent for your work."
        }
    }

    var openWebsiteTitle: String {
        switch language {
        case .japanese: return "サポートサイトを開く"
        case .simplifiedChinese: return "打开支持网站"
        case .english: return "Open Support Website"
        }
    }

    var tutorialVideoTitle: String {
        switch language {
        case .japanese: return "動画チュートリアル"
        case .simplifiedChinese: return "视频教程"
        case .english: return "Video Tutorial"
        }
    }

    var tutorialVideoBody: String {
        switch language {
        case .japanese: return "基本操作や帳票作成の流れをYouTube動画で確認できます。下のリンクからYouTubeを開いて視聴してください。"
        case .simplifiedChinese: return "可通过 YouTube 视频确认基本操作与表单创建流程。请点击下方链接打开 YouTube 观看。"
        case .english: return "Watch the basic workflow and form creation flow on YouTube. Open the link below to view the tutorial."
        }
    }

    var openTutorialVideoTitle: String {
        switch language {
        case .japanese: return "YouTubeで開く"
        case .simplifiedChinese: return "在 YouTube 打开"
        case .english: return "Open on YouTube"
        }
    }

    var workplaceScenarioTitle: String {
        switch language {
        case .japanese: return "業務でよくある利用シーン"
        case .simplifiedChinese: return "工作中常见使用场景"
        case .english: return "Common Work Scenarios"
        }
    }

    var workplaceScenarios: [Item] {
        switch language {
        case .japanese:
            return [
                Item(title: "1. 月末の請求処理を短時間で終えたい", body: "取引先、商品、振込先テンプレートを先に登録しておくと、請求書作成時は候補を選び、数量と日付を確認するだけで作業を進めやすくなります。PDFプレビューで宛名、登録番号、税率、振込先を確認してから共有してください。"),
                Item(title: "2. 外出先や通勤中に見積を直したい", body: "端末内に保存された帳票はオフラインでも編集できます。PDFプレビュー画面からの共有とGoogle DriveバックアップはPro機能のため、無料版では保存まで行い、Pro有効後に共有・バックアップしてください。"),
                Item(title: "3. 上司に確認してから顧客へ送りたい", body: "プレビュー画面でPDFの内容を確認できます。共有シートから社内チャットやメールへ送る操作はPro機能です。正式送付前はファイル名、金額、支払期限、備考、印章位置を見直してください。"),
                Item(title: "4. 顧客からの注文を案件単位で残したい", body: "客先注文記録を作成し、プロジェクトへ紐づけると、見積、注文、納品、請求、領収までの流れを同じ案件で追いやすくなります。後日問い合わせが来た時も、プロジェクトから該当帳票を探せます。"),
                Item(title: "5. 仕入先への発注と顧客向け請求を分けたい", body: "顧客向け帳票と仕入先向け帳票はプロジェクト種別で分けて管理します。発注書、仕入先見積記録、支払通知書などは仕入先側の流れとして保存し、顧客へ送る帳票と混在しないようにしてください。"),
                Item(title: "6. インボイス登録番号を毎回入力したくない", body: "会社設定で自社名、登録番号、連絡先、住所を保存しておくと、帳票作成時に発行者候補として再利用できます。登録番号はPDFに出るため、初回登録後に一度プレビューで表示を確認してください。"),
                Item(title: "7. 取引先名の表記ゆれを減らしたい", body: "取引先管理に正式名称、担当者、電話、メール、住所を登録しておくと、入力時の候補から選べます。株式会社の前後、部署名、敬称の違いで検索に出ない場合は会社名の一部だけで探してください。"),
                Item(title: "8. 商品名、型番、単価の入力ミスを減らしたい", body: "商品・項目管理に品名、仕様、型番、単価を登録しておくと、明細入力で再利用できます。キャンペーン価格や月ごとに単価が変わる商品は、保存済み単価を選んだ後に帳票上で調整してください。"),
                Item(title: "9. 備考、支払条件、振込先を標準化したい", body: "テンプレート管理でよく使う備考、支払条件、振込先文面を保存できます。請求書や見積書を作るたびに同じ文章を入力し直す必要がなくなり、担当者ごとの文言差も抑えられます。"),
                Item(title: "10. 印章画像をPDFに載せたい", body: "印章編集では写真から印章画像を選び、色、サイズ、位置、回転、余白を調整できます。背景が残る場合はしきい値や余白を調整し、最後にPDF全体で押印位置が宛名や金額に重なっていないか確認してください。"),
                Item(title: "11. Google Driveでバックアップしたい", body: "Google DriveバックアップはPro機能です。Pro有効後、設定・アカウント管理からGoogle Driveへログインし、バックアップをアップロードできます。バックアップは月別フォルダに保存されます。"),
                Item(title: "12. 新しいiPhoneへ移行したい", body: "旧端末でローカルバックアップを作成するか、ProではGoogle Driveバックアップを作成し、新端末で読み込みます。既存データを残したい場合は結合を選んでください。"),
                Item(title: "13. 無料版とProの違いを知りたい", body: "無料版でも帳票作成、保存、プロジェクト管理、会社・取引先・商品・テンプレート管理を利用できます。ProではPDFプレビュー画面の共有とGoogle Driveバックアップを含むすべての機能を利用できます。"),
                Item(title: "14. 検索しても書類が見つからない", body: "帳票番号、取引先名、商品名の一部で検索してください。プロジェクト内にある帳票はプロジェクト画面から探す方が早い場合があります。表記ゆれがある時は短いキーワードで再検索してください。"),
                Item(title: "15. 税率や金額が不安", body: "数量、単価、税率、小数入力、値引き相当の記載を確認してください。税務判断そのものはアプリでは代行できないため、会社の経理ルールや税理士の指示に合わせて入力してください。"),
                Item(title: "16. PDFの見た目を整えたい", body: "会社名や住所が長い場合は改行を入れると読みやすくなります。帳票配色は設定で変更できます。正式送付前にプレビューで文字切れ、改行、印章、ロゴ、明細行の収まりを確認してください。"),
                Item(title: "17. 社内で担当者が変わった", body: "会社設定や取引先管理の担当者情報を更新すると、以後の入力候補に反映されます。既に保存済みの帳票は過去時点の記録として残るため、必要な帳票だけ開いて更新してください。"),
                Item(title: "18. 先方から再送を頼まれた", body: "最近の帳票、検索、またはプロジェクトから対象書類を開き、PDFを再生成して共有します。再送前に金額、発行日、支払期限、ファイル内容が最新か確認してください。"),
                Item(title: "19. 添付先アプリにPDFを渡せない", body: "共有先アプリ側のログイン状態、通信、ファイル権限を確認してください。共有シートが不安定な場合は一度PDF保存を行い、Filesやメールアプリから添付する方法も試してください。"),
                Item(title: "20. 問題を早く解決したい", body: "サポート連絡時は、どの帳票で、どのボタンを押した後に、どんな表示になったかを時系列で書いてください。スクリーンショット、端末名、iOSバージョン、再現頻度があると確認が速くなります。")
            ]
        case .simplifiedChinese:
            return [
                Item(title: "1. 月末请款想更快完成", body: "先登记交易对象、商品和汇款模板，创建发票时就可以选择候选内容，再确认数量和日期。发送前请在 PDF 预览中检查抬头、登记编号、税率和汇款信息。"),
                Item(title: "2. 通勤或外出时想修改报价", body: "保存在设备内的表单可以离线编辑。PDF 预览画面的分享与 Google Drive 备份属于 Pro 功能；免费版可先保存，启用 Pro 后再分享或备份。"),
                Item(title: "3. 想先给上司确认再发客户", body: "可在预览画面确认 PDF 内容。从分享面板发送到公司邮件或聊天工具属于 Pro 功能。正式发送前请确认文件名、金额、付款期限、备注和印章位置。"),
                Item(title: "4. 想按案件保存客户订单", body: "创建客户订单记录并关联项目后，可按同一案件追踪报价、订单、送货、发票和收据。之后客户询问时，可以从项目中快速找到对应表单。"),
                Item(title: "5. 想区分客户文件和供应商文件", body: "客户向表单与供应商向表单按项目类型区分。采购订单、厂商报价记录、支付通知书等请放在供应商流程中，避免与发送给客户的文件混在一起。"),
                Item(title: "6. 不想每次输入发票登记编号", body: "在公司设置中保存公司名、登记编号、联系人和地址后，创建表单时可作为开具方候选重复使用。登记编号会显示在 PDF 上，首次保存后请预览确认。"),
                Item(title: "7. 想减少客户名称写法不一致", body: "在客户管理中保存正式名称、联系人、电话、邮箱和地址。搜索不到时，请只输入公司名的一部分，避免株式会社前后位置、部门名或敬称造成的差异。"),
                Item(title: "8. 想减少商品名、型号、单价错误", body: "在商品与品项管理中保存品名、规格、型号和单价，明细输入时即可复用。活动价格或每月变动价格，可选择候选后在当前表单内调整。"),
                Item(title: "9. 想统一备注、付款条件和汇款文字", body: "可在模板管理中保存常用备注、付款条件和汇款账户文字。之后创建报价单或发票时直接选择，减少重复输入和不同担当之间的文案差异。"),
                Item(title: "10. 想把印章放到 PDF 上", body: "印章编辑可从照片选择印章图片，并调整颜色、大小、位置、旋转和边距。如果背景残留，请调整阈值或裁剪边距，最后确认印章没有盖住金额和抬头。"),
                Item(title: "11. 想用 Google Drive 备份", body: "Google Drive 备份属于 Pro 功能。启用 Pro 后，可在设置与账户管理中登录 Google Drive 并上传备份。备份会按月份保存到文件夹。"),
                Item(title: "12. 想迁移到新 iPhone", body: "可在旧设备创建本地备份；启用 Pro 后也可创建 Google Drive 备份，再在新设备导入。想保留新设备现有资料时请选择合并。"),
                Item(title: "13. 想知道免费版和 Pro 差异", body: "免费版也可使用表单创建、保存、项目管理、公司/客户/商品/模板管理。Pro 可使用包含 PDF 预览画面分享与 Google Drive 备份在内的全部功能。"),
                Item(title: "14. 搜索不到文件", body: "请用表单编号、交易对象或商品名的一部分搜索。属于项目内的表单，有时从项目画面查找更快。名称写法不一致时，请缩短关键词重新搜索。"),
                Item(title: "15. 担心税率和金额", body: "请确认数量、单价、税率、小数输入和折扣相关备注。税务判断本身不能由 App 代替，请按照公司的财务规则或税理士指示输入。"),
                Item(title: "16. 想调整 PDF 可读性", body: "公司名或地址很长时建议手动换行。可在设置中切换表单配色。正式发送前请预览确认文字截断、换行、印章、Logo 和明细行显示。"),
                Item(title: "17. 公司内部担当变更", body: "更新公司设置或客户管理中的担当信息后，之后的输入候选会反映新内容。已保存表单作为过去记录保留，需要更新时请只打开对应表单修改。"),
                Item(title: "18. 客户要求重新发送", body: "从最近表单、搜索或项目中打开目标文件，重新生成 PDF 并分享。再发送前请确认金额、发行日、付款期限和文件内容是否为最新。"),
                Item(title: "19. PDF 无法传给其他 App", body: "请确认分享目标 App 的登录状态、网络和文件权限。分享面板不稳定时，可先保存 PDF，再从 Files 或邮件 App 附加文件。"),
                Item(title: "20. 想更快解决问题", body: "联系客服时，请按时间顺序写明哪个表单、按下哪个按钮后、出现了什么画面。附上截图、设备名称、iOS 版本和复现频率，可加快确认。")
            ]
        case .english:
            return [
                Item(title: "1. Finish month-end invoicing faster", body: "Register partners, products, and payment templates first. When creating invoices, choose suggestions, confirm quantities and dates, then check recipient, registration number, tax, and payment details in PDF preview."),
                Item(title: "2. Edit a quote while commuting", body: "Forms saved on device can be edited offline. Sharing from PDF Preview and Google Drive backup are Pro features, so save first on the free plan and share or back up after Pro is active."),
                Item(title: "3. Send internally before sending to a customer", body: "Check the PDF in Preview. Sending it through the share sheet to company mail or chat is a Pro feature. Before formal delivery, check file name, amount, due date, notes, and stamp placement."),
                Item(title: "4. Keep customer orders by project", body: "Create a customer order record and link it to a project. Quotes, orders, delivery notes, invoices, and receipts can then be checked from the same project."),
                Item(title: "5. Separate customer and vendor flows", body: "Customer-facing and vendor-facing forms are organized by project direction. Keep purchase orders, vendor quote records, and payment notices in the vendor flow."),
                Item(title: "6. Avoid retyping invoice registration numbers", body: "Save company name, registration number, contact, and address in Company settings. Reuse them as issuer suggestions and confirm the registration number once in PDF preview."),
                Item(title: "7. Reduce partner name variation", body: "Save formal partner names, contacts, phone, email, and address in partner management. If suggestions do not appear, search with only part of the company name."),
                Item(title: "8. Reduce product and price entry mistakes", body: "Save product name, specification, model, and unit price in product management. For campaign or monthly prices, select the saved product and adjust the current form."),
                Item(title: "9. Standardize notes and payment terms", body: "Save frequent notes, terms, and bank transfer text in Template Management. This reduces repeated typing and keeps wording consistent between staff members."),
                Item(title: "10. Place a stamp on the PDF", body: "In Stamp Editor, choose an image from Photos and adjust color, size, position, rotation, and crop. Confirm the stamp does not overlap amounts or recipient details."),
                Item(title: "11. Back up with Google Drive", body: "Google Drive backup is a Pro feature. After Pro is active, sign in to Google Drive from Settings and Account, then upload backups. Backups are stored by month."),
                Item(title: "12. Move to a new iPhone", body: "Create a local backup on the old device, or use Google Drive backup with Pro, then import it on the new device. Use merge to keep existing data."),
                Item(title: "13. Understand Free and Pro", body: "The free plan includes form creation, saving, projects, company, partner, product, and template management. Pro unlocks every feature, including sharing from PDF Preview and Google Drive backup."),
                Item(title: "14. Find a missing document", body: "Search by part of the form number, partner name, or product name. For project documents, opening the project first can be faster than global search."),
                Item(title: "15. Check tax and amount concerns", body: "Confirm quantity, unit price, tax rate, decimals, and discount notes. The app does not replace accounting judgment, so follow your company's accounting rules."),
                Item(title: "16. Improve PDF readability", body: "Add line breaks for long company names or addresses. Change form colors in Settings, and preview text wrapping, stamp, logo, and line item layout before sending."),
                Item(title: "17. Update an internal staff contact", body: "Update staff details in Company or partner management. Existing saved forms remain as past records, so update only the forms that need a new contact."),
                Item(title: "18. Resend a file to a customer", body: "Open the target document from Recent Forms, Search, or Projects, regenerate the PDF, and share it again. Confirm amount, issue date, due date, and content before resending."),
                Item(title: "19. PDF cannot be passed to another app", body: "Check the destination app login, network, and file permissions. If the share sheet is unstable, save the PDF first and attach it from Files or Mail."),
                Item(title: "20. Resolve a problem faster", body: "When contacting support, describe the form, button, resulting screen, and sequence of events. Screenshots, device model, iOS version, and reproduction frequency help investigation.")
            ]
        }
    }

    var faqTitle: String {
        switch language {
        case .japanese: return "よくある質問"
        case .simplifiedChinese: return "常见问题"
        case .english: return "Frequently Asked Questions"
        }
    }

    var faqCategories: [Category] {
        switch language {
        case .japanese:
            return [
                Category(title: "1. 対応帳票", items: [Item(title: "どの帳票を作成できますか？", body: "見積書、客先注文記録、納品書、請求書、領収書、プロジェクト管理、発注書、受領書に対応しています。")]),
                Category(title: "2. 言語", items: [Item(title: "画面と言語を切り替えられますか？", body: "設定・アカウント管理で操作画面の言語とPDF帳票の言語を日本語、英語、中国語から選べます。")]),
                Category(title: "3. 自社情報", items: [Item(title: "自社情報は保存できますか？", body: "会社名、登録番号、担当者、電話、メール、住所を保存し、帳票へ再利用できます。")]),
                Category(title: "4. 取引先", items: [Item(title: "取引先情報は再利用できますか？", body: "顧客や仕入先を保存して、次回以降の帳票入力時に候補として使えます。")]),
                Category(title: "5. 商品", items: [Item(title: "商品や単価を登録できますか？", body: "商品名、型番、仕様、単価を保存し、明細入力へ反映できます。")]),
                Category(title: "6. プロジェクト", items: [Item(title: "プロジェクト管理は何に使いますか？", body: "プロジェクト管理でプロジェクトを作成し、必要な帳票をプロジェクト単位でまとめて進捗確認できます。")]),
                Category(title: "7. 保存", items: [Item(title: "作成中の帳票は保存されますか？", body: "入力内容はアプリ内に保存され、最近のプロジェクトや各管理画面から再度開けます。")]),
                Category(title: "8. PDF", items: [Item(title: "PDFにできますか？", body: "確認画面でPDFプレビューを確認し、PDF保存や共有ができます。")]),
                Category(title: "9. 共有", items: [Item(title: "取引先へ送付できますか？", body: "iOSの共有機能からメール、メッセージ、クラウド保存先などへ送付できます。")]),
                Category(title: "10. バックアップ", items: [Item(title: "データをバックアップできますか？", body: "設定・アカウント管理からローカルバックアップを書き出し、保管や移行に使えます。")]),
                Category(title: "11. 復元", items: [Item(title: "バックアップを復元できますか？", body: "バックアップファイルを読み込み、既存データへ結合するか、新しい内容として導入できます。")]),
                Category(title: "12. テンプレート", items: [Item(title: "備考や振込文をテンプレート化できますか？", body: "テンプレート管理でよく使う文面を保存し、帳票入力に利用できます。")]),
                Category(title: "13. 税率", items: [Item(title: "消費税の入力はできますか？", body: "明細や帳票設定に合わせて税率、金額、備考を入力して管理できます。")]),
                Category(title: "14. 色", items: [Item(title: "帳票の配色を変えられますか？", body: "設定で帳票配色を選び、必要に応じてボタン色も帳票配色へ合わせられます。")]),
                Category(title: "15. ダークモード", items: [Item(title: "ダークモードに対応していますか？", body: "設定・アカウント管理の外観設定からダークモードを切り替えられます。")]),
                Category(title: "16. オフライン", items: [Item(title: "オフラインでも使えますか？", body: "基本的な帳票作成と保存は端末内で行えます。外部共有やリンク表示には通信が必要です。")]),
                Category(title: "17. 機種変更", items: [Item(title: "新しい端末へ移行できますか？", body: "旧端末でバックアップを書き出し、新端末で読み込むことで移行できます。")]),
                Category(title: "18. 購入管理", items: [Item(title: "購入履歴はどこで確認しますか？", body: "App StoreのApple ID購入履歴で確認・管理してください。")]),
                Category(title: "19. 返金", items: [Item(title: "返金はどこへ申請しますか？", body: "Appleの返金申請ページから対象購入を選択し、理由を入力して申請します。")]),
                Category(title: "20. サポート連絡", items: [Item(title: "問い合わせには何を書けばよいですか？", body: "会社名、連絡先、端末名、iOSバージョン、発生日時、再現手順をお知らせください。")])
            ]
        case .simplifiedChinese:
            return [
                Category(title: "1. 支持表单", items: [Item(title: "可以创建哪些表单？", body: "支持报价单、客户订单记录、送货单、发票、收据、项目管理、采购订单、收货确认单。")]),
                Category(title: "2. 语言", items: [Item(title: "界面和 PDF 语言可以切换吗？", body: "可在设置与账户管理中选择日语、英语、中文作为界面语言和 PDF 语言。")]),
                Category(title: "3. 本公司信息", items: [Item(title: "可以保存本公司信息吗？", body: "可以保存公司名、登记编号、联系人、电话、邮箱和地址，并重复用于表单。")]),
                Category(title: "4. 交易对象", items: [Item(title: "客户或供应商信息可以复用吗？", body: "可以保存客户和供应商，在之后填写表单时作为候选使用。")]),
                Category(title: "5. 商品", items: [Item(title: "商品和单价可以登记吗？", body: "可以保存商品名、型号、规格和单价，并用于明细输入。")]),
                Category(title: "6. 项目", items: [Item(title: "项目管理用于什么？", body: "可在项目管理中建立项目，把所需表单按项目汇总并确认进度。")]),
                Category(title: "7. 保存", items: [Item(title: "正在创建的表单会保存吗？", body: "输入内容会保存在 App 内，可从最近项目或管理画面再次打开。")]),
                Category(title: "8. PDF", items: [Item(title: "可以导出 PDF 吗？", body: "可在预览画面确认 PDF，并保存或分享 PDF。")]),
                Category(title: "9. 分享", items: [Item(title: "可以发给客户或供应商吗？", body: "可通过 iOS 分享功能发送到邮件、信息或云端保存位置。")]),
                Category(title: "10. 备份", items: [Item(title: "可以备份数据吗？", body: "可在设置与账户管理中导出本地备份，用于保存或转移。")]),
                Category(title: "11. 恢复", items: [Item(title: "可以恢复备份吗？", body: "导入备份文件时，可选择与现有内容合并或作为全新内容导入。")]),
                Category(title: "12. 模板", items: [Item(title: "备注或汇款说明可以做成模板吗？", body: "可在模板管理中保存常用文字，并在表单填写时使用。")]),
                Category(title: "13. 税率", items: [Item(title: "可以输入消费税吗？", body: "可按明细和表单设置输入税率、金额和备注。")]),
                Category(title: "14. 配色", items: [Item(title: "表单颜色可以修改吗？", body: "可在设置中选择表单配色，也可让按钮颜色与表单配色保持一致。")]),
                Category(title: "15. 深色模式", items: [Item(title: "支持深色模式吗？", body: "可在设置与账户管理的外观设置中切换深色模式。")]),
                Category(title: "16. 离线使用", items: [Item(title: "没有网络也能使用吗？", body: "基本表单创建与保存可在设备内完成，外部分享和链接访问需要网络。")]),
                Category(title: "17. 更换设备", items: [Item(title: "可以迁移到新设备吗？", body: "在旧设备导出备份，在新设备导入备份即可迁移。")]),
                Category(title: "18. 购买管理", items: [Item(title: "在哪里查看购买记录？", body: "请在 App Store 的 Apple ID 购买记录中确认和管理。")]),
                Category(title: "19. 退款", items: [Item(title: "退款在哪里申请？", body: "请在 Apple 退款申请页面选择购买项目，填写原因后提交。")]),
                Category(title: "20. 联系客服", items: [Item(title: "联系客服需要提供什么？", body: "请提供公司名、联系方式、设备名称、iOS 版本、发生时间和复现步骤。")])
            ]
        case .english:
            return [
                Category(title: "1. Supported Forms", items: [Item(title: "Which forms can I create?", body: "Quote, customer order record, delivery note, invoice, receipt, project documents, purchase order, and acceptance receipt are supported.")]),
                Category(title: "2. Language", items: [Item(title: "Can I switch interface and PDF language?", body: "Choose Japanese, English, or Chinese for the interface and PDF language in Settings and Account.")]),
                Category(title: "3. Company Details", items: [Item(title: "Can I save company details?", body: "Save company name, registration number, contact, phone, email, and address for reuse.")]),
                Category(title: "4. Partners", items: [Item(title: "Can customer and vendor details be reused?", body: "Save customers and vendors, then reuse them as suggestions when filling forms.")]),
                Category(title: "5. Products", items: [Item(title: "Can I register products and prices?", body: "Save product name, model, specification, and unit price for line items.")]),
                Category(title: "6. Projects", items: [Item(title: "What is project management for?", body: "Create projects in Project Documents, collect required forms, and track completion.")]),
                Category(title: "7. Saving", items: [Item(title: "Are forms saved while I work?", body: "Form data is saved in the app and can be reopened from recent projects or management screens.")]),
                Category(title: "8. PDF", items: [Item(title: "Can I export PDF files?", body: "Review the PDF preview, then save or share the PDF.")]),
                Category(title: "9. Sharing", items: [Item(title: "Can I send forms to partners?", body: "Use the iOS share sheet to send PDF files by mail, messages, or cloud destinations.")]),
                Category(title: "10. Backup", items: [Item(title: "Can I back up data?", body: "Export a local backup from Settings and Account for storage or migration.")]),
                Category(title: "11. Restore", items: [Item(title: "Can I restore a backup?", body: "Import a backup file and choose whether to merge it or create fresh content from it.")]),
                Category(title: "12. Templates", items: [Item(title: "Can I save note or bank transfer templates?", body: "Save frequent text in Template Management and reuse it while filling forms.")]),
                Category(title: "13. Tax", items: [Item(title: "Can I enter consumption tax?", body: "Enter tax rates, amounts, and notes according to your line items and form setup.")]),
                Category(title: "14. Colors", items: [Item(title: "Can I change form colors?", body: "Choose a form color template and optionally match button colors to the template.")]),
                Category(title: "15. Dark Mode", items: [Item(title: "Is dark mode supported?", body: "Toggle dark mode from Appearance in Settings and Account.")]),
                Category(title: "16. Offline Use", items: [Item(title: "Can I use the app offline?", body: "Basic form creation and saving work on device. Sharing and external links require network access.")]),
                Category(title: "17. Device Migration", items: [Item(title: "Can I move data to a new device?", body: "Export a backup on the old device and import it on the new device.")]),
                Category(title: "18. Purchase Management", items: [Item(title: "Where do I check purchases?", body: "Check and manage purchases in your Apple ID purchase history in the App Store.")]),
                Category(title: "19. Refunds", items: [Item(title: "Where do I request a refund?", body: "Use Apple's refund request page, choose the purchase, enter a reason, and submit.")]),
                Category(title: "20. Contact Support", items: [Item(title: "What should I include when contacting support?", body: "Include company name, contact details, device model, iOS version, time of issue, and reproduction steps.")])
            ]
        }
    }

    var tutorialTitle: String {
        switch language {
        case .japanese: return "操作フローガイド"
        case .simplifiedChinese: return "操作流程教程"
        case .english: return "Workflow Tutorials"
        }
    }

    var tutorials: [Item] {
        switch language {
        case .japanese:
            return [
                Item(title: "1. 初期設定", body: "設定・アカウント管理で表示言語、PDF言語、帳票配色を設定し、会社設定で自社情報を登録します。"),
                Item(title: "2. 帳票作成", body: "ホームから帳票種類を選び、基本情報、取引先、明細、備考を入力して保存します。"),
                Item(title: "3. プロジェクト管理", body: "プロジェクト管理ではプロジェクトを作成し、必要な帳票をプロジェクト単位でそろえて進捗を確認します。"),
                Item(title: "4. PDF保存と共有", body: "確認画面でPDFプレビューを確認し、PDF保存または共有から取引先へ送付します。"),
                Item(title: "5. 自社情報の登録", body: "会社設定で自社情報を入力し、保存済みアカウントとして登録します。"),
                Item(title: "6. 取引先の登録", body: "取引先管理で顧客または仕入先の名称、担当者、住所、連絡先を保存します。"),
                Item(title: "7. 商品の登録", body: "商品・項目管理で品目名、仕様、型番、単価を登録します。"),
                Item(title: "8. 見積書作成", body: "見積書を選択し、宛先、明細、条件、備考を入力して保存します。"),
                Item(title: "9. 客先注文記録作成", body: "客先注文記録を開き、顧客から受けた注文内容をプロジェクトに紐づけます。"),
                Item(title: "10. 納品書作成", body: "納品する品目と数量を入力し、納品日や備考を確認します。"),
                Item(title: "11. 請求書作成", body: "請求先、支払条件、明細、振込先備考を入力して請求書を保存します。"),
                Item(title: "12. 領収書作成", body: "入金内容、金額、発行日を確認して領収書を作成します。"),
                Item(title: "13. 発注書作成", body: "仕入先向けに品目、数量、納期、条件を入力して発注書を作成します。"),
                Item(title: "14. 受領書作成", body: "受け取った品目や数量を確認し、受領内容を記録します。"),
                Item(title: "15. 既存帳票の検索", body: "ホーム上部の検索欄に帳票番号、取引先名、商品名を入力して探します。"),
                Item(title: "16. 最近のプロジェクトを開く", body: "ホームの最近のプロジェクトから対象プロジェクトを選び、プロジェクト内の帳票へ移動します。"),
                Item(title: "17. テンプレート利用", body: "テンプレート管理で保存した文面を備考や振込案内に反映します。"),
                Item(title: "18. バックアップ作成", body: "設定・アカウント管理からすべての内容をバックアップして共有します。"),
                Item(title: "19. バックアップ導入", body: "バックアップファイルを選択し、既存データへ結合するか、新しい内容として導入します。"),
                Item(title: "20. サポートへ連絡", body: "サービス専用ページのメールアドレスまたはサポートサイトから問い合わせます。")
            ]
        case .simplifiedChinese:
            return [
                Item(title: "1. 初始设置", body: "在设置与账户管理中设置显示语言、PDF 语言和表单配色，并在公司设置中登记本公司信息。"),
                Item(title: "2. 创建表单", body: "从首页选择表单类型，填写基本信息、交易对象、明细和备注后保存。"),
                Item(title: "3. 项目管理", body: "在项目管理中创建项目，把所需表单按项目整理并确认完成进度。"),
                Item(title: "4. PDF 保存与分享", body: "在预览画面确认 PDF，使用保存 PDF 或分享功能发送给客户或供应商。"),
                Item(title: "5. 登记本公司信息", body: "在公司设置中输入本公司信息，并保存为已登记账户。"),
                Item(title: "6. 登记交易对象", body: "在客户管理中保存客户或供应商的名称、联系人、地址和联系方式。"),
                Item(title: "7. 登记商品", body: "在商品与品项管理中登记品名、规格、型号和单价。"),
                Item(title: "8. 创建报价单", body: "选择报价单，填写收件方、明细、条件和备注后保存。"),
                Item(title: "9. 创建客户订单记录", body: "打开客户订单记录，将客户订单内容关联到项目。"),
                Item(title: "10. 创建送货单", body: "输入交付的品项和数量，并确认交付日期与备注。"),
                Item(title: "11. 创建发票", body: "填写收款方、付款条件、明细和汇款备注后保存发票。"),
                Item(title: "12. 创建收据", body: "确认收款内容、金额和发行日期后创建收据。"),
                Item(title: "13. 创建采购订单", body: "面向供应商输入品项、数量、交期和条件后创建采购订单。"),
                Item(title: "14. 创建收货确认单", body: "确认收到的品项和数量，并记录收货内容。"),
                Item(title: "15. 搜索已有表单", body: "在首页上方搜索框输入表单编号、交易对象或商品名进行查找。"),
                Item(title: "16. 打开最近项目", body: "从首页的最近项目选择目标项目，并进入项目内表单。"),
                Item(title: "17. 使用模板", body: "把模板管理中保存的文字用于备注或汇款说明。"),
                Item(title: "18. 创建备份", body: "在设置与账户管理中导出完整内容备份并分享。"),
                Item(title: "19. 导入备份", body: "选择备份文件，并以合并或全新内容方式导入。"),
                Item(title: "20. 联系客服", body: "通过服务专区中的邮箱或支持网站联系我们。")
            ]
        case .english:
            return [
                Item(title: "1. Initial Setup", body: "Set interface language, PDF language, and form colors in Settings and Account, then register company details in Company."),
                Item(title: "2. Create a Form", body: "Choose a form type from Home, fill in basic info, partner, line items, and notes, then save."),
                Item(title: "3. Project Management", body: "Create projects in Project Documents, collect required forms by project, and check completion progress."),
                Item(title: "4. Save and Share PDF", body: "Review the PDF preview, then save or share the PDF with customers or vendors."),
                Item(title: "5. Register Company Details", body: "Enter company details in Company settings and save them as a registered account."),
                Item(title: "6. Register Partners", body: "Save customer or vendor names, contacts, addresses, and contact details in partner management."),
                Item(title: "7. Register Products", body: "Register item name, specification, model, and unit price in product management."),
                Item(title: "8. Create a Quote", body: "Select Quote, fill recipient, line items, conditions, and notes, then save."),
                Item(title: "9. Create a Customer Order Record", body: "Open Customer Order Record and link the received order details to a project."),
                Item(title: "10. Create a Delivery Note", body: "Enter delivered items and quantities, then confirm delivery date and notes."),
                Item(title: "11. Create an Invoice", body: "Fill billing recipient, payment terms, line items, and transfer notes, then save."),
                Item(title: "12. Create a Receipt", body: "Confirm payment details, amount, and issue date, then create the receipt."),
                Item(title: "13. Create a Purchase Order", body: "Enter items, quantities, delivery timing, and conditions for the vendor."),
                Item(title: "14. Create an Acceptance Receipt", body: "Confirm received items and quantities, then record acceptance details."),
                Item(title: "15. Search Existing Forms", body: "Use the search field on Home to find form numbers, partners, or products."),
                Item(title: "16. Open Recent Projects", body: "Choose a recent project on Home to open forms inside that project."),
                Item(title: "17. Use Templates", body: "Apply saved template text to notes or bank transfer instructions."),
                Item(title: "18. Create a Backup", body: "Export and share a complete backup from Settings and Account."),
                Item(title: "19. Import a Backup", body: "Choose a backup file and import it by merging or replacing content."),
                Item(title: "20. Contact Support", body: "Contact us from the email address or support website shown in Service Center.")
            ]
        }
    }

    var technicalIssues: [Item] {
        switch language {
        case .japanese:
            return [
                Item(title: "1. アプリが起動しない", body: "iOSを再起動し、空き容量と最新バージョンを確認してから再度起動してください。"),
                Item(title: "2. 画面が固まる", body: "アプリを終了して再起動し、同じ操作で再現するか確認してください。"),
                Item(title: "3. 入力内容が反映されない", body: "該当欄を閉じて再入力し、保存操作後に一覧へ戻って確認してください。"),
                Item(title: "4. PDFプレビューが出ない", body: "帳票の必須情報と明細を確認し、再度確認画面を開いてください。"),
                Item(title: "5. PDF保存に失敗する", body: "端末容量、ファイル権限、共有先の状態を確認して再試行してください。"),
                Item(title: "6. 共有シートが開かない", body: "iOS共有先アプリの状態を確認し、アプリ再起動後に再度共有してください。"),
                Item(title: "7. 検索結果が出ない", body: "表記ゆれを避け、帳票番号、会社名、商品名の一部だけで検索してください。"),
                Item(title: "8. 言語が切り替わらない", body: "設定変更後に画面を切り替えるか、アプリを再起動して反映を確認してください。"),
                Item(title: "9. ダークモード表示が崩れる", body: "外観設定を切り替え、再現画面のスクリーンショットを添えてご連絡ください。"),
                Item(title: "10. 金額計算が合わない", body: "数量、単価、税率、小数入力、割引や備考欄の入力内容を確認してください。"),
                Item(title: "11. 取引先候補が出ない", body: "取引先管理に保存済みか確認し、名称の一部で再検索してください。"),
                Item(title: "12. 商品候補が出ない", body: "商品・項目管理に保存済みか確認し、品名や型番の一部で検索してください。"),
                Item(title: "13. プロジェクトに帳票を追加できない", body: "プロジェクト種別と帳票種別が一致しているか、既に同じ帳票が作成済みか確認してください。"),
                Item(title: "14. バックアップを書き出せない", body: "共有先と端末容量を確認し、別の保存先を選んでください。"),
                Item(title: "15. バックアップを読み込めない", body: "ファイル形式がアプリのバックアップか確認し、破損していないファイルを選んでください。"),
                Item(title: "16. App Store購入が反映されない", body: "同じApple IDでサインインし、App Storeの購入履歴を確認してください。"),
                Item(title: "17. 返金リンクが開かない", body: "ブラウザ通信を確認し、https://reportaproblem.apple.com を直接開いてください。"),
                Item(title: "18. 文字が切れる", body: "iOSの文字サイズ設定を確認し、長い会社名や備考は改行して入力してください。"),
                Item(title: "19. データが消えたように見える", body: "検索条件、プロジェクトフィルタ、バックアップ導入方式を確認してください。"),
                Item(title: "20. 問題を報告したい", body: "再現手順、端末名、iOSバージョン、画面写真を service@niix.jp へ送付してください。")
            ]
        case .simplifiedChinese:
            return [
                Item(title: "1. App 无法启动", body: "请重启 iOS，确认存储空间和 App 版本后再次打开。"),
                Item(title: "2. 画面卡住", body: "关闭 App 后重新启动，并确认相同操作是否仍会复现。"),
                Item(title: "3. 输入内容没有反映", body: "关闭该输入栏后重新输入，保存后返回列表确认。"),
                Item(title: "4. PDF 预览不显示", body: "确认表单必填信息和明细内容后，重新打开预览画面。"),
                Item(title: "5. PDF 保存失败", body: "确认设备容量、文件权限和分享目的地状态后重试。"),
                Item(title: "6. 分享面板打不开", body: "确认 iOS 分享目标 App 状态，重启本 App 后再次分享。"),
                Item(title: "7. 搜索没有结果", body: "请减少关键词，只输入表单编号、公司名或商品名的一部分。"),
                Item(title: "8. 语言没有切换", body: "设置后切换画面，或重启 App 后确认显示。"),
                Item(title: "9. 深色模式显示异常", body: "切换外观设置，并将复现画面截图发送给客服。"),
                Item(title: "10. 金额计算不一致", body: "请确认数量、单价、税率、小数、折扣或备注输入内容。"),
                Item(title: "11. 客户候选不显示", body: "确认客户管理中已保存，并用名称的一部分重新搜索。"),
                Item(title: "12. 商品候选不显示", body: "确认商品与品项管理中已保存，并用品名或型号的一部分搜索。"),
                Item(title: "13. 项目无法追加表单", body: "确认项目类型和表单类型是否一致，以及是否已经创建相同表单。"),
                Item(title: "14. 无法导出备份", body: "确认分享目的地和设备容量，尝试选择其他保存位置。"),
                Item(title: "15. 无法读取备份", body: "确认文件是本 App 的备份格式，并选择未损坏的文件。"),
                Item(title: "16. App Store 购买未反映", body: "请使用相同 Apple ID 登录，并确认 App Store 购买记录。"),
                Item(title: "17. 退款链接打不开", body: "确认网络连接，或直接打开 https://reportaproblem.apple.com。"),
                Item(title: "18. 文字被截断", body: "确认 iOS 字体大小设置，较长公司名或备注请换行输入。"),
                Item(title: "19. 数据看起来消失", body: "请确认搜索条件、项目筛选和备份导入方式。"),
                Item(title: "20. 我要报告问题", body: "请把复现步骤、设备名称、iOS 版本和截图发送到 service@niix.jp。")
            ]
        case .english:
            return [
                Item(title: "1. App Does Not Launch", body: "Restart iOS, check free storage and app version, then open the app again."),
                Item(title: "2. Screen Freezes", body: "Quit and relaunch the app, then check whether the same operation reproduces it."),
                Item(title: "3. Input Is Not Reflected", body: "Leave the field, enter the value again, save, and return to the list to confirm."),
                Item(title: "4. PDF Preview Does Not Appear", body: "Check required form details and line items, then reopen the preview screen."),
                Item(title: "5. PDF Save Fails", body: "Check device storage, file permission, and the destination app, then retry."),
                Item(title: "6. Share Sheet Does Not Open", body: "Check the target iOS share app, restart this app, and try sharing again."),
                Item(title: "7. Search Has No Results", body: "Use shorter keywords such as part of the form number, company name, or product name."),
                Item(title: "8. Language Does Not Switch", body: "After changing settings, switch screens or restart the app to confirm."),
                Item(title: "9. Dark Mode Looks Wrong", body: "Toggle appearance settings and send a screenshot of the reproduced screen."),
                Item(title: "10. Amount Calculation Differs", body: "Check quantity, unit price, tax rate, decimals, discounts, and note entries."),
                Item(title: "11. Partner Suggestions Missing", body: "Confirm the partner is saved, then search with part of the name."),
                Item(title: "12. Product Suggestions Missing", body: "Confirm the item is saved, then search with part of the name or model."),
                Item(title: "13. Cannot Add Form to Project", body: "Check that project direction matches the form type and the form is not already created."),
                Item(title: "14. Backup Export Fails", body: "Check share destination and device storage, then choose another destination."),
                Item(title: "15. Backup Import Fails", body: "Confirm the file is an app backup and is not damaged."),
                Item(title: "16. App Store Purchase Not Reflected", body: "Sign in with the same Apple ID and check App Store purchase history."),
                Item(title: "17. Refund Link Does Not Open", body: "Check network access or open https://reportaproblem.apple.com directly."),
                Item(title: "18. Text Is Cut Off", body: "Check iOS text size settings and add line breaks to long company names or notes."),
                Item(title: "19. Data Seems Missing", body: "Check search terms, project filters, and backup import mode."),
                Item(title: "20. Report a Problem", body: "Send reproduction steps, device model, iOS version, and screenshots to service@niix.jp.")
            ]
        }
    }

    var refundTitle: String {
        switch language {
        case .japanese: return "返金について"
        case .simplifiedChinese: return "退款机制"
        case .english: return "Refunds"
        }
    }

    var refundBody: String {
        switch language {
        case .japanese: return "App Storeで購入したアプリやアプリ内課金の返金は、Appleの返金申請手続きに従います。返金可否、審査、処理時期はAppleが判断します。"
        case .simplifiedChinese: return "通过 App Store 购买的 App 或 App 内购买，退款按 Apple App Store 的退款机制处理。是否批准、审核和处理时间由 Apple 决定。"
        case .english: return "Refunds for App Store purchases and in-app purchases follow Apple's App Store refund process. Apple determines eligibility, review, and processing timing."
        }
    }

    var openRefundTitle: String {
        switch language {
        case .japanese: return "Apple返金申請を開く"
        case .simplifiedChinese: return "打开 Apple 退款申请"
        case .english: return "Open Apple Refund Request"
        }
    }

    var technicalSupportTitle: String {
        switch language {
        case .japanese: return "サービス・技術サポート"
        case .simplifiedChinese: return "服务与技术支持"
        case .english: return "Service and Technical Support"
        }
    }

    var technicalSupportBody: String {
        switch language {
        case .japanese: return "操作方法、表示不具合、データ保存、PDF出力、バックアップに関する技術的な問題をサポートします。"
        case .simplifiedChinese: return "我们提供操作方法、显示异常、数据保存、PDF 输出、备份相关的技术支持。"
        case .english: return "We support questions about usage, display issues, data saving, PDF export, and backup."
        }
    }

    var ticketInfo: String {
        switch language {
        case .japanese: return "お問い合わせ時は、会社名、連絡先、端末名、iOSバージョン、発生日時、問題の再現手順をお知らせください。"
        case .simplifiedChinese: return "联系售后服务时，请提供公司名、联系方式、设备名称、iOS 版本、发生时间与问题复现步骤。"
        case .english: return "When contacting support, include company name, contact details, device model, iOS version, time of issue, and reproduction steps."
        }
    }
}

private struct RecentSelectionActionStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.10))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.28)))
    }
}

private struct SidebarDocumentPreviewCard: View {
    let document: BusinessDocument
    let language: AppLanguage
    let width: CGFloat
    let height: CGFloat
    let isCurrentSavedDocument: Bool

    @State private var thumbnail: UIImage?
    @State private var didFail = false

    var body: some View {
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
                    Text(AppFormatters.shortDate(document.issueDate))
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                    Text(projectDisplayName)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(.appInk)
                .multilineTextAlignment(.leading)
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

                if isCurrentSavedDocument {
                    currentEditingIndicator
                }
            }
            .frame(width: width, height: height)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)

            Text(document.type.localizedTitle(language))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: width, alignment: .leading)
        }
        .task(id: taskID) {
            loadThumbnail()
        }
    }

    private var currentEditingIndicator: some View {
        VStack {
            HStack {
                Circle()
                    .fill(Color.appBlue)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: Color.appBlue.opacity(0.22), radius: 3, x: 0, y: 1)
                    .accessibilityLabel(localized(japanese: "編集中", chinese: "正在编辑", english: "Editing"))
                Spacer()
            }
            Spacer()
        }
        .padding(8)
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
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

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        do {
            thumbnail = try DocumentPDFExporter.previewImage(for: document, language: language, scale: 1)
            didFail = false
        } catch {
            didFail = true
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
