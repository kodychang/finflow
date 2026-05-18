import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: DocumentStore
    @Binding var selectedSection: AppSection
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var searchQuery = ""
    @State private var isSelectingRecentDocuments = false
    @State private var selectedRecentDocumentIDs: Set<BusinessDocument.ID> = []
    @State private var isDeleteConfirmationPresented = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private var cleanSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var visibleRecentDocuments: [BusinessDocument] {
        Array(filteredDocuments.prefix(12))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        Text("帳票")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.appInk)
                        Spacer()
                        Button {
                            store.saveCurrent()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.body.weight(.semibold))
                                .foregroundColor(buttonAccent)
                                .frame(width: 36, height: 36)
                                .background(buttonAccent.opacity(0.12))
                                .clipShape(Circle())
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                        TextField("", text: $searchQuery, prompt: .inputPrompt("帳票、顧客・廠商、商品を検索"))
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
                    .frame(height: 40)
                    .background(Color.appInputBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                }

                if !cleanSearchQuery.isEmpty {
                    searchResults
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading("よく使う帳票", actionTitle: nil)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredDocumentTypes) { type in
                            Button {
                                if type == .customerFiles {
                                    selectedSection = .projects
                                } else {
                                    store.newDocument(type: type)
                                    selectedSection = .form
                                }
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    Image(systemName: iconName(for: type))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(accentColor(for: type))
                                        .frame(width: 34, height: 34)
                                        .background(accentColor(for: type).opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(type.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.appInk)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.82)
                                        Text(type.subtitle)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(.appMuted)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.appSidebarCard)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.current.type == type ? buttonAccent : Color.appDivider))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading("管理", actionTitle: nil)
                    managementButton(title: "設定・アカウント", subtitle: "自社情報と保存設定", systemImage: "person.crop.circle", section: .account)
                    managementButton(title: "文件與專案管理", subtitle: "\(store.projects.count) 件の專案", systemImage: "folder", section: .projects)
                    managementButton(title: "顧客・廠商管理", subtitle: "\(store.customers.count) 件の取引先・廠商", systemImage: "building.2", section: .customers)
                    managementButton(title: "商品・項目管理", subtitle: "\(store.products.count) 件の商品", systemImage: "shippingbox", section: .products)
                }

                VStack(alignment: .leading, spacing: 10) {
                    recentDocumentsHeader

                    if visibleRecentDocuments.isEmpty {
                        Text("保存済みなし")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.appSidebarCard)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                    } else {
                        if isSelectingRecentDocuments {
                            recentSelectionActions
                        }
                        ForEach(visibleRecentDocuments) { document in
                            recentDocumentButton(document)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .background(Color.appSidebar.edgesIgnoringSafeArea(.all))
        .confirmationDialog("選択した帳票を削除しますか？", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                deleteSelectedRecentDocuments()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(selectedRecentDocumentIDs.count) 件の帳票を削除します。この操作は取り消せません。")
        }
    }

    private var filteredDocumentTypes: [DocumentType] {
        guard !cleanSearchQuery.isEmpty else { return DocumentType.allCases }
        return DocumentType.allCases.filter { matches("\($0.title) \($0.subtitle)", query: cleanSearchQuery) }
    }

    private var filteredDocuments: [BusinessDocument] {
        guard !cleanSearchQuery.isEmpty else { return store.documents }
        return store.documents.filter { document in
            matches("\(document.type.title) \(document.type.subtitle) \(document.number) \(document.customerName)", query: cleanSearchQuery)
        }
    }

    private var filteredCustomers: [CustomerProfile] {
        guard !cleanSearchQuery.isEmpty else { return [] }
        return store.customers.filter { matches("\($0.name) \($0.contact) \($0.address)", query: cleanSearchQuery) }
    }

    private var filteredProducts: [ProductProfile] {
        guard !cleanSearchQuery.isEmpty else { return [] }
        return store.products.filter { matches("\($0.name) \($0.model) \($0.specification)", query: cleanSearchQuery) }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("搜尋結果", actionTitle: nil)
            if filteredDocumentTypes.isEmpty && filteredDocuments.isEmpty && filteredCustomers.isEmpty && filteredProducts.isEmpty {
                Text("一致する内容はありません。")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.appSidebarCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
            } else {
                ForEach(filteredDocumentTypes.prefix(4)) { type in
                    searchResultButton(
                        title: type.title,
                        subtitle: type.subtitle,
                        systemImage: iconName(for: type),
                        color: accentColor(for: type)
                    ) {
                        if type == .customerFiles {
                            selectedSection = .projects
                        } else {
                            store.newDocument(type: type)
                            selectedSection = .form
                        }
                    }
                }
                ForEach(filteredDocuments.prefix(4)) { document in
                    searchResultButton(
                        title: "\(document.type.title) \(document.number)",
                        subtitle: document.customerName.isEmpty ? "取引先未入力" : document.customerName,
                        systemImage: "doc.text",
                        color: buttonAccent
                    ) {
                        store.select(document)
                        selectedSection = .form
                    }
                }
                ForEach(filteredCustomers.prefix(4)) { customer in
                    searchResultButton(
                        title: customer.name,
                        subtitle: [customer.contact, customer.address].filter { !$0.isEmpty }.joined(separator: " / "),
                        systemImage: "building.2",
                        color: .appBlue
                    ) {
                        store.apply(customer)
                        selectedSection = .form
                    }
                }
                ForEach(filteredProducts.prefix(4)) { product in
                    searchResultButton(
                        title: product.name,
                        subtitle: [product.model, product.specification, AppFormatters.yen(product.unitPrice)].filter { !$0.isEmpty }.joined(separator: " / "),
                        systemImage: "shippingbox",
                        color: .appMint
                    ) {
                        store.apply(product)
                        selectedSection = .form
                    }
                }
            }
        }
    }

    private var recentDocumentsHeader: some View {
        HStack(spacing: 8) {
            Text("最近の帳票")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appInk)
            Spacer()
            if !visibleRecentDocuments.isEmpty {
                Button {
                    toggleRecentSelectionMode()
                } label: {
                    Text(isSelectingRecentDocuments ? "完了" : "選択")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(buttonAccent)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var recentSelectionActions: some View {
        HStack(spacing: 8) {
            Button {
                toggleSelectAllRecentDocuments()
            } label: {
                Label(isAllVisibleRecentDocumentsSelected ? "全解除" : "全選択", systemImage: isAllVisibleRecentDocumentsSelected ? "checkmark.circle" : "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RecentSelectionActionStyle(tint: buttonAccent))

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Label("削除", systemImage: "trash")
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
                        .frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(document.type.title) \(document.number)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text(document.customerName.isEmpty ? "取引先未入力" : document.customerName)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(isSelected ? buttonAccent.opacity(0.12) : Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? buttonAccent : Color.appDivider))
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

    private func searchResultButton(title: String, subtitle: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
            }
            .padding(12)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func matches(_ value: String, query: String) -> Bool {
        value.localizedCaseInsensitiveContains(query)
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
                    .frame(width: 30, height: 30)
                    .background(selectedSection == section ? buttonAccent : buttonAccent.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appInk)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.appSidebarCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedSection == section ? buttonAccent : Color.appDivider))
        }
        .buttonStyle(PlainButtonStyle())
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
        }
    }
}

private struct RecentSelectionActionStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.10))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.28)))
    }
}
