import Foundation
import Combine
import UniformTypeIdentifiers

enum GoogleDriveDocumentFileKind {
    case pdf
    case json
}

enum ProjectDocumentCopyMode: Equatable {
    case append
    case overwrite
}

final class DocumentStore: ObservableObject {
    @Published var current: BusinessDocument {
        didSet {
            if hasActiveDocument {
                persistDraft()
            }
        }
    }
    @Published private(set) var documents: [BusinessDocument]
    @Published private(set) var hasActiveDocument = false
    @Published private(set) var customers: [CustomerProfile]
    @Published private(set) var issuers: [IssuerProfile]
    @Published private(set) var products: [ProductProfile]
    @Published private(set) var textTemplates: [TextTemplate]
    @Published private(set) var defaultColorTemplateId: String {
        didSet {
            UserDefaults.standard.set(defaultColorTemplateId, forKey: defaultColorTemplateStorageKey)
        }
    }
    @Published private(set) var defaultIssuerProfileId: String? {
        didSet {
            if let defaultIssuerProfileId {
                UserDefaults.standard.set(defaultIssuerProfileId, forKey: defaultIssuerProfileStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultIssuerProfileStorageKey)
            }
        }
    }
    @Published var interfaceLanguageId: String {
        didSet {
            UserDefaults.standard.set(interfaceLanguageId, forKey: interfaceLanguageStorageKey)
        }
    }
    @Published var pdfLanguageId: String {
        didSet {
            UserDefaults.standard.set(pdfLanguageId, forKey: pdfLanguageStorageKey)
        }
    }

    private let storageKey = "native.shokoForms.documents.v1"
    private let customersStorageKey = "native.shokoForms.customers.v1"
    private let issuersStorageKey = "native.shokoForms.issuers.v1"
    private let productsStorageKey = "native.shokoForms.products.v1"
    private let textTemplatesStorageKey = "native.shokoForms.textTemplates.v1"
    private let draftStorageKey = "native.shokoForms.currentDraft.v1"
    private let defaultColorTemplateStorageKey = "native.shokoForms.defaultColorTemplate.v1"
    private let defaultIssuerProfileStorageKey = "native.shokoForms.defaultIssuerProfile.v1"
    private let interfaceLanguageStorageKey = "native.shokoForms.interfaceLanguage.v1"
    private let pdfLanguageStorageKey = "native.shokoForms.pdfLanguage.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeISO8601Date(decoder)
        }
        let loaded = Self.loadDocuments(key: storageKey, decoder: decoder)
        documents = loaded.sorted { $0.updatedAt > $1.updatedAt }
        let initialCurrent =
            loaded.first ??
            BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: loaded))
        current = initialCurrent
        let hasSavedProfiles = UserDefaults.standard.object(forKey: customersStorageKey) != nil ||
            UserDefaults.standard.object(forKey: issuersStorageKey) != nil ||
            UserDefaults.standard.object(forKey: productsStorageKey) != nil
        customers = Self.loadProfiles(key: customersStorageKey, decoder: decoder)
        issuers = Self.loadProfiles(key: issuersStorageKey, decoder: decoder)
        products = Self.loadProfiles(key: productsStorageKey, decoder: decoder)
        textTemplates = Self.loadProfiles(key: textTemplatesStorageKey, decoder: decoder)
        defaultColorTemplateId = UserDefaults.standard.string(forKey: defaultColorTemplateStorageKey) ?? initialCurrent.colorTemplate.rawValue
        defaultIssuerProfileId = UserDefaults.standard.string(forKey: defaultIssuerProfileStorageKey)
        interfaceLanguageId = UserDefaults.standard.string(forKey: interfaceLanguageStorageKey) ?? AppLanguage.japanese.rawValue
        pdfLanguageId = UserDefaults.standard.string(forKey: pdfLanguageStorageKey) ?? AppLanguage.japanese.rawValue
        clearDraft()
        if loaded.isEmpty {
            applyDefaultIssuer(to: &current)
        }
        if !hasSavedProfiles {
            seedProfiles(from: loaded)
        } else if textTemplates.isEmpty {
            seedTextTemplates(from: loaded)
        }
    }

    var interfaceLanguage: AppLanguage {
        get { AppLanguage.from(interfaceLanguageId) }
        set { interfaceLanguageId = newValue.rawValue }
    }

    var pdfLanguage: AppLanguage {
        get { AppLanguage.from(pdfLanguageId) }
        set { pdfLanguageId = newValue.rawValue }
    }

    var defaultIssuerProfile: IssuerProfile? {
        if let defaultIssuerProfileId,
           let id = UUID(uuidString: defaultIssuerProfileId),
           let issuer = issuers.first(where: { $0.id == id }) {
            return issuer
        }
        return issuers.first
    }

    func newDocument(type: DocumentType) {
        var document = BusinessDocument.blank(type: type, number: Self.makeNumber(type: type, documents: documents))
        document.colorTemplateId = defaultColorTemplateId
        applyDefaultIssuer(to: &document)
        hasActiveDocument = true
        current = document
    }

    func applyDefaultColorTemplate(_ templateId: String) {
        let template = DocumentColorTemplate(rawValue: templateId) ?? .monochrome
        defaultColorTemplateId = template.rawValue
        current.colorTemplateId = template.rawValue
    }

    var projects: [ProjectArchive] {
        let grouped = Dictionary(grouping: documents.filter { $0.projectId != nil }) { document in
            document.projectId ?? document.id
        }

        return grouped.map { projectId, projectDocuments in
            let sorted = projectDocuments.sorted { $0.updatedAt > $1.updatedAt }
            let primary = sorted.first ?? BusinessDocument()
            let direction = primary.projectDirection ?? .customer
            let projectName = primary.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let customerName = primary.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
            return ProjectArchive(
                id: projectId,
                name: projectName?.isEmpty == false ? projectName ?? "" : customerName.isEmpty ? "Project \(projectId.uuidString.prefix(8))" : "\(AppFormatters.shortDate(primary.updatedAt)) \(customerName)",
                direction: direction,
                customerName: customerName,
                updatedAt: sorted.map(\.updatedAt).max() ?? primary.updatedAt,
                documents: sorted
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    var relatedDocumentCandidatesForCurrentProject: [BusinessDocument] {
        guard let projectId = current.projectId else { return [] }

        return documents
            .filter { document in
                document.projectId == projectId &&
                    document.id != current.id &&
                    !document.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { lhs, rhs in
                if lhs.type == rhs.type {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.type.localizedTitle(interfaceLanguage) < rhs.type.localizedTitle(interfaceLanguage)
            }
    }

    func createProject(direction: ProjectDirection, customer: CustomerProfile?, initialType: DocumentType? = nil) {
        let projectId = UUID()
        let type = initialType.flatMap { direction.requiredTypes.contains($0) ? $0 : nil } ?? direction.firstType
        var document = BusinessDocument.blank(type: type, number: Self.makeNumber(type: type, documents: documents))
        document.colorTemplateId = defaultColorTemplateId
        applyDefaultIssuer(to: &document)
        document.projectId = projectId
        document.projectDirection = direction
        if let customer {
            document.customerName = customer.name
            document.customerContact = customer.contact
            document.customerPhone = customer.phone
            document.customerEmail = customer.email
            document.customerAddress = customer.address
        }
        let cleanName = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        document.projectName = cleanName.isEmpty ? "\(direction.title) \(AppFormatters.shortDate(Date()))" : "\(AppFormatters.shortDate(Date())) \(cleanName)"
        hasActiveDocument = true
        current = document
        saveCurrent()
    }

    func makeProjectArchive(direction: ProjectDirection, customer: CustomerProfile?) -> ProjectArchive {
        let projectId = UUID()
        let customerName = customer?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let projectName = customerName.isEmpty ? "\(direction.title) \(AppFormatters.shortDate(Date()))" : "\(AppFormatters.shortDate(Date())) \(customerName)"
        return ProjectArchive(
            id: projectId,
            name: projectName,
            direction: direction,
            customerName: customerName,
            updatedAt: Date(),
            documents: []
        )
    }

    func createProjectFromCurrent(direction: ProjectDirection) {
        let projectId = UUID()
        current.projectId = projectId
        current.projectDirection = direction
        let cleanName = current.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        current.projectName = cleanName.isEmpty ? "\(direction.title) \(AppFormatters.shortDate(Date()))" : "\(AppFormatters.shortDate(Date())) \(cleanName)"
        saveCurrent()
    }

    func assignCurrentDocument(to project: ProjectArchive) {
        current.projectId = project.id
        current.projectName = project.name
        current.projectDirection = project.direction
        if current.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let source = sourceDocument(for: project)
            current.customerName = source?.customerName ?? project.customerName
            current.customerContact = source?.customerContact ?? ""
            current.customerPhone = source?.customerPhone
            current.customerEmail = source?.customerEmail
            current.customerAddress = source?.customerAddress ?? ""
        }
        saveCurrent()
    }

    func assignDocument(_ document: BusinessDocument, to project: ProjectArchive) {
        hasActiveDocument = true
        current = document
        assignCurrentDocument(to: project)
    }

    func openProjectForm(project: ProjectArchive, type: DocumentType) {
        if let existing = project.document(for: type) {
            hasActiveDocument = true
            current = existing
            return
        }
        var document = BusinessDocument.blank(type: type, number: Self.makeNumber(type: type, documents: documents))
        applyDefaultIssuer(to: &document)
        let source = sourceDocument(for: project)
        applyProjectContext(from: source, project: project, to: &document)
        hasActiveDocument = true
        current = document
        saveCurrent()
    }

    func createAdditionalCustomerOrder(project: ProjectArchive) {
        let source = sourceDocument(for: project)
        let estimate = sourceDocument(for: project, preferredTypes: [.estimate])
        var document = BusinessDocument.blank(type: .customerOrder, number: Self.makeNumber(type: .customerOrder, documents: documents))
        applyDefaultIssuer(to: &document)
        applyProjectContext(from: source, project: project, to: &document)
        document.relatedNumber = estimate?.number ?? source?.relatedNumber ?? ""
        document.orderAttachments = []
        hasActiveDocument = true
        current = document
        saveCurrent()
    }

    @discardableResult
    func copyDocument(_ source: BusinessDocument, to project: ProjectArchive, mode: ProjectDocumentCopyMode) -> BusinessDocument {
        let existing = project.document(for: source.type)
        let shouldOverwrite = mode == .overwrite && existing != nil
        var document = source

        if shouldOverwrite, let existing {
            document.id = existing.id
            document.number = existing.number
        } else {
            document.id = UUID()
            document.number = Self.makeNumber(type: source.type, documents: documents)
        }

        let projectSource = sourceDocument(for: project)
        document.projectId = project.id
        document.projectName = project.name
        document.projectDirection = project.direction
        document.customerName = projectSource?.customerName ?? project.customerName
        document.customerContact = projectSource?.customerContact ?? ""
        document.customerPhone = projectSource?.customerPhone
        document.customerEmail = projectSource?.customerEmail
        document.customerAddress = projectSource?.customerAddress ?? ""
        document.googleDrivePDFFileID = nil
        document.googleDriveJSONFileID = nil
        document.updatedAt = Date()

        captureProfiles(from: document)
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
        } else {
            documents.insert(document, at: 0)
        }
        documents.sort { $0.updatedAt > $1.updatedAt }
        hasActiveDocument = true
        current = document
        persist()
        clearDraft()
        return document
    }

    func updateProject(project: ProjectArchive, name: String, direction: ProjectDirection, customer: CustomerProfile?) {
        let cleanProjectName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = cleanProjectName.isEmpty
            ? (customer.map { "\(AppFormatters.shortDate(project.updatedAt)) \($0.name)" } ?? "\(direction.title) \(AppFormatters.shortDate(project.updatedAt))")
            : cleanProjectName

        for index in documents.indices where documents[index].projectId == project.id {
            documents[index].projectDirection = direction
            documents[index].projectName = projectName
            documents[index].updatedAt = Date()
            if let customer {
                documents[index].customerName = customer.name
                documents[index].customerContact = customer.contact
                documents[index].customerPhone = customer.phone
                documents[index].customerEmail = customer.email
                documents[index].customerAddress = customer.address
            } else {
                documents[index].customerName = ""
                documents[index].customerContact = ""
                documents[index].customerPhone = nil
                documents[index].customerEmail = nil
                documents[index].customerAddress = ""
            }
        }

        if current.projectId == project.id {
            current.projectDirection = direction
            current.projectName = projectName
            current.updatedAt = Date()
            if let customer {
                current.customerName = customer.name
                current.customerContact = customer.contact
                current.customerPhone = customer.phone
                current.customerEmail = customer.email
                current.customerAddress = customer.address
            } else {
                current.customerName = ""
                current.customerContact = ""
                current.customerPhone = nil
                current.customerEmail = nil
                current.customerAddress = ""
            }
        }

        documents.sort { $0.updatedAt > $1.updatedAt }
        persist()
        persistDraft()
    }

    func renameProject(project: ProjectArchive, name: String) {
        let cleanProjectName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = cleanProjectName.isEmpty ? project.name : cleanProjectName

        for index in documents.indices where documents[index].projectId == project.id {
            documents[index].projectName = projectName
            documents[index].updatedAt = Date()
        }

        if current.projectId == project.id {
            current.projectName = projectName
            current.updatedAt = Date()
        }

        documents.sort { $0.updatedAt > $1.updatedAt }
        persist()
        persistDraft()
    }

    func select(_ document: BusinessDocument) {
        hasActiveDocument = true
        current = document
    }

    func saveCurrent() {
        hasActiveDocument = true
        current.updatedAt = Date()
        captureProfiles(from: current)
        if let index = documents.firstIndex(where: { $0.id == current.id }) {
            documents[index] = current
        } else {
            documents.insert(current, at: 0)
        }
        documents.sort { $0.updatedAt > $1.updatedAt }
        persist()
        clearDraft()
    }

    func updateRelatedNumber(for documentID: BusinessDocument.ID, relatedNumber: String) {
        let cleanRelatedNumber = relatedNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = documents.firstIndex(where: { $0.id == documentID }) {
            documents[index].relatedNumber = cleanRelatedNumber
            documents[index].updatedAt = Date()
            if current.id == documentID {
                current.relatedNumber = cleanRelatedNumber
                current.updatedAt = documents[index].updatedAt
            }
            documents.sort { $0.updatedAt > $1.updatedAt }
            persist()
            persistDraft()
        } else if current.id == documentID {
            current.relatedNumber = cleanRelatedNumber
            current.updatedAt = Date()
            persistDraft()
        }
    }

    @discardableResult
    func duplicateCurrentDocument() -> BusinessDocument {
        saveCurrent()
        return duplicateDocument(current)
    }

    @discardableResult
    func duplicateDocument(_ source: BusinessDocument) -> BusinessDocument {
        var document = source
        document.id = UUID()
        document.number = Self.makeNumber(type: document.type, documents: documents)
        document.googleDrivePDFFileID = nil
        document.googleDriveJSONFileID = nil
        document.updatedAt = Date()

        captureProfiles(from: document)
        documents.insert(document, at: 0)
        documents.sort { $0.updatedAt > $1.updatedAt }
        hasActiveDocument = true
        current = document
        persist()
        clearDraft()
        return document
    }

    var hasUnsavedCurrentChanges: Bool {
        guard hasActiveDocument else { return false }
        guard let saved = documents.first(where: { $0.id == current.id }) else {
            return true
        }
        return saved != current
    }

    func saveDraft() {
        persistDraft()
    }

    func discardCurrentChanges() {
        clearDraft()
        if let saved = documents.first(where: { $0.id == current.id }) {
            hasActiveDocument = true
            current = saved
        } else if let firstDocument = documents.first {
            hasActiveDocument = true
            current = firstDocument
        } else {
            var document = BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: documents))
            document.colorTemplateId = defaultColorTemplateId
            applyDefaultIssuer(to: &document)
            hasActiveDocument = false
            current = document
        }
    }

    func discardDraft() {
        clearDraft()
        if let firstDocument = documents.first {
            hasActiveDocument = true
            current = firstDocument
        } else {
            var document = BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: documents))
            document.colorTemplateId = defaultColorTemplateId
            applyDefaultIssuer(to: &document)
            hasActiveDocument = false
            current = document
        }
    }

    func resetCurrentDocumentSelection() {
        clearDraft()
        hasActiveDocument = false
        current = documents.first ?? newFallbackDocument()
    }

    func backupFileURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(backupFileName())
        try backupData().write(to: url, options: .atomic)
        return url
    }

    func sharedFormFileURL(for document: BusinessDocument) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(sharedFormFileName(for: document))
        try sharedFormData(for: document).write(to: url, options: .atomic)
        return url
    }

    func backupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "shoko-forms-backup-\(formatter.string(from: Date())).shokobackup"
    }

    func sharedFormFileName(for document: BusinessDocument) -> String {
        let title = document.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? document.type.title
            : "\(document.number)-\(document.type.title)"
        return "\(Self.sanitizedFileBaseName(title, fallback: "shoko-form")).shokoform"
    }

    func backupData() throws -> Data {
        let backup = LocalBackup(
            exportedAt: Date(),
            documents: documents,
            customers: customers,
            issuers: issuers,
            products: products,
            draft: hasActiveDocument ? current : nil,
            textTemplates: textTemplates
        )
        return try encoder.encode(backup)
    }

    func sharedFormData(for document: BusinessDocument) throws -> Data {
        let file = SharedFormFile(exportedAt: Date(), document: document)
        return try encoder.encode(file)
    }

    func updateGoogleDriveFileID(_ fileID: String, kind: GoogleDriveDocumentFileKind, for documentID: UUID) {
        if current.id == documentID {
            switch kind {
            case .pdf:
                current.googleDrivePDFFileID = fileID
            case .json:
                current.googleDriveJSONFileID = fileID
            }
        }

        if let index = documents.firstIndex(where: { $0.id == documentID }) {
            switch kind {
            case .pdf:
                documents[index].googleDrivePDFFileID = fileID
            case .json:
                documents[index].googleDriveJSONFileID = fileID
            }
            persist()
        } else {
            persistDraft()
        }
    }

    func importBackupData(_ data: Data, mode: BackupImportMode) throws {
        let backup = try decoder.decode(LocalBackup.self, from: data)
        switch mode {
        case .replace:
            documents = backup.documents.sorted { $0.updatedAt > $1.updatedAt }
            customers = backup.customers.sorted { $0.updatedAt > $1.updatedAt }
            issuers = backup.issuers.sorted { $0.updatedAt > $1.updatedAt }
            products = backup.products.sorted { $0.updatedAt > $1.updatedAt }
            textTemplates = (backup.textTemplates ?? []).sorted { $0.updatedAt > $1.updatedAt }
            hasActiveDocument = backup.draft != nil
            current = backup.draft ?? documents.first ?? newFallbackDocument()
            defaultColorTemplateId = current.colorTemplate.rawValue
        case .merge:
            let hadDocuments = !documents.isEmpty
            mergeDocuments(backup.documents)
            mergeCustomers(backup.customers)
            mergeIssuers(backup.issuers)
            mergeProducts(backup.products)
            mergeTextTemplates(backup.textTemplates ?? [])
            if !hadDocuments, let draft = backup.draft {
                hasActiveDocument = true
                current = draft
            }
        }
        documents.sort { $0.updatedAt > $1.updatedAt }
        sortProfiles()
        persist()
        persistDraft()
    }

    func importBundledDemoData() throws {
        guard let url = Bundle.main.url(forResource: "shoko-forms-demo-100", withExtension: "shokobackup") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        try importBackupData(data, mode: .merge)
    }

    func importSharedFormData(_ data: Data) throws {
        let document: BusinessDocument
        if let sharedForm = try? decoder.decode(SharedFormFile.self, from: data) {
            document = sharedForm.document
        } else {
            document = try decoder.decode(BusinessDocument.self, from: data)
        }

        hasActiveDocument = true
        current = document
        saveCurrent()
    }

    func customerSuggestions(for query: String) -> [CustomerProfile] {
        filtered(customers, query: query) { $0.name }
    }

    func issuerSuggestions(for query: String) -> [IssuerProfile] {
        filtered(issuers, query: query) { $0.name }
    }

    func productSuggestions(for query: String) -> [ProductProfile] {
        filtered(products, query: query) { "\($0.name) \($0.model) \($0.specification)" }
    }

    func templates(kind: TextTemplateKind) -> [TextTemplate] {
        textTemplates.filter { $0.kind == kind }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func apply(_ customer: CustomerProfile) {
        ensureActiveDocumentForManagementApply()
        current.customerName = customer.name
        current.customerContact = customer.contact
        current.customerPhone = customer.phone
        current.customerEmail = customer.email
        current.customerAddress = customer.address
        current.updatedAt = Date()
        persistDraft()
    }

    func apply(_ issuer: IssuerProfile) {
        ensureActiveDocumentForManagementApply()
        current.issuerName = issuer.name
        current.issuerRegistration = issuer.registration
        current.issuerContact = issuer.contact
        current.issuerPhone = issuer.phone
        current.issuerEmail = issuer.email
        current.issuerAddress = issuer.address
        current.issuerLogoData = issuer.logoData
        current.issuerLogoScale = issuer.logoScale
        current.updatedAt = Date()
        persistDraft()
    }

    func useDefaultIssuer(_ issuer: IssuerProfile) {
        defaultIssuerProfileId = issuer.id.uuidString
        apply(issuer)
    }

    func apply(_ product: ProductProfile) {
        ensureActiveDocumentForManagementApply()
        if current.lines.isEmpty {
            current.lines.append(LineItem())
        }
        let emptyLineIndex = current.lines.firstIndex { line in
            line.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                line.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                line.specification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                line.unitPrice == 0
        }
        let targetIndex = emptyLineIndex ?? current.lines.endIndex
        let line = LineItem(
            name: product.name,
            model: product.model,
            specification: product.specification,
            quantity: 1,
            unitPrice: product.unitPrice
        )
        if targetIndex == current.lines.endIndex {
            current.lines.append(line)
        } else {
            current.lines[targetIndex] = line
        }
        current.updatedAt = Date()
        persistDraft()
    }

    func rememberCustomerFromCurrent() {
        upsertCustomer(
            name: current.customerName,
            contact: current.customerContact,
            phone: current.customerPhone ?? "",
            email: current.customerEmail ?? "",
            address: current.customerAddress
        )
    }

    func rememberIssuerFromCurrent() {
        upsertIssuer(
            name: current.issuerName,
            registration: current.issuerRegistration,
            contact: current.issuerContact,
            phone: current.issuerPhone,
            email: current.issuerEmail,
            address: current.issuerAddress
        )
    }

    func rememberProduct(_ line: LineItem) {
        upsertProduct(name: line.name, model: line.model, specification: line.specification, unitPrice: line.unitPrice)
    }

    func rememberTextTemplate(kind: TextTemplateKind, content: String) {
        upsertTextTemplate(kind: kind, title: Self.templateTitle(from: content), content: content)
    }

    func saveCustomerProfile(name: String, contact: String, phone: String, email: String, address: String) {
        upsertCustomer(name: name, contact: contact, phone: phone, email: email, address: address)
    }

    func updateCustomerProfile(id: CustomerProfile.ID, name: String, contact: String, phone: String, email: String, address: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = customers.firstIndex(where: { $0.id == id }) {
            customers[index].name = cleanName
            customers[index].contact = contact
            customers[index].phone = phone
            customers[index].email = email
            customers[index].address = address
            customers[index].updatedAt = Date()
        } else {
            customers.insert(CustomerProfile(id: id, name: cleanName, contact: contact, phone: phone, email: email, address: address), at: 0)
        }
        sortProfiles()
        persistProfiles()
    }

    @discardableResult
    func saveIssuerProfile(name: String, registration: String, contact: String, phone: String, email: String, address: String) -> IssuerProfile? {
        upsertIssuer(
            name: name,
            registration: registration,
            contact: contact,
            phone: phone,
            email: email,
            address: address
        )
    }

    @discardableResult
    func updateIssuerProfile(id: IssuerProfile.ID, name: String, registration: String, contact: String, phone: String, email: String, address: String) -> IssuerProfile? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let savedID: IssuerProfile.ID
        if let index = issuers.firstIndex(where: { $0.id == id }) {
            issuers[index].name = cleanName
            issuers[index].registration = registration
            issuers[index].contact = contact
            issuers[index].phone = phone
            issuers[index].email = email
            issuers[index].address = address
            issuers[index].updatedAt = Date()
            savedID = issuers[index].id
        } else {
            let issuer = IssuerProfile(id: id, name: cleanName, registration: registration, contact: contact, phone: phone, email: email, address: address)
            issuers.insert(issuer, at: 0)
            savedID = issuer.id
        }
        sortProfiles()
        persistProfiles()
        return issuers.first { $0.id == savedID }
    }

    func saveProductProfile(name: String, model: String, specification: String, unitPrice: Double) {
        upsertProduct(name: name, model: model, specification: specification, unitPrice: unitPrice)
    }

    func updateProductProfile(id: ProductProfile.ID, name: String, model: String, specification: String, unitPrice: Double) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = products.firstIndex(where: { $0.id == id }) {
            products[index].name = cleanName
            products[index].model = model
            products[index].specification = specification
            products[index].unitPrice = unitPrice
            products[index].updatedAt = Date()
        } else {
            products.insert(ProductProfile(id: id, name: cleanName, model: model, specification: specification, unitPrice: unitPrice), at: 0)
        }
        sortProfiles()
        persistProfiles()
    }

    func deleteCustomer(_ customer: CustomerProfile) {
        customers.removeAll { $0.id == customer.id }
        persistProfiles()
    }

    func deleteIssuer(_ issuer: IssuerProfile) {
        issuers.removeAll { $0.id == issuer.id }
        if defaultIssuerProfileId == issuer.id.uuidString {
            defaultIssuerProfileId = issuers.first?.id.uuidString
        }
        persistProfiles()
    }

    func deleteProduct(_ product: ProductProfile) {
        products.removeAll { $0.id == product.id }
        persistProfiles()
    }

    func saveTextTemplate(kind: TextTemplateKind, title: String, content: String) {
        upsertTextTemplate(kind: kind, title: title, content: content)
    }

    func updateTextTemplate(id: TextTemplate.ID, kind: TextTemplateKind, title: String, content: String) {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = textTemplates.firstIndex(where: { $0.id == id }) {
            textTemplates[index].kind = kind
            textTemplates[index].title = cleanTitle.isEmpty ? Self.templateTitle(from: cleanContent) : cleanTitle
            textTemplates[index].content = cleanContent
            textTemplates[index].updatedAt = Date()
        } else {
            textTemplates.insert(TextTemplate(id: id, kind: kind, title: cleanTitle.isEmpty ? Self.templateTitle(from: cleanContent) : cleanTitle, content: cleanContent), at: 0)
        }
        sortProfiles()
        persistProfiles()
    }

    func deleteTextTemplate(_ template: TextTemplate) {
        textTemplates.removeAll { $0.id == template.id }
        persistProfiles()
    }

    func delete(_ document: BusinessDocument) {
        documents.removeAll { $0.id == document.id }
        if current.id == document.id {
            hasActiveDocument = false
            current = documents.first ?? newFallbackDocument()
        }
        clearDraft()
        persist()
    }

    func deleteDocuments(ids: Set<BusinessDocument.ID>) {
        guard !ids.isEmpty else { return }
        documents.removeAll { ids.contains($0.id) }
        if ids.contains(current.id) {
            hasActiveDocument = false
            current = documents.first ?? newFallbackDocument()
        }
        clearDraft()
        persist()
    }

    private func newFallbackDocument() -> BusinessDocument {
        var document = BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: documents))
        document.colorTemplateId = defaultColorTemplateId
        applyDefaultIssuer(to: &document)
        return document
    }

    func deleteProject(_ project: ProjectArchive) {
        deleteDocuments(ids: Set(project.documents.map(\.id)))
    }

    func clearLocalBusinessData() {
        documents = []
        customers = []
        issuers = []
        products = []
        textTemplates = []
        hasActiveDocument = false
        current = BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: []))
        defaultColorTemplateId = current.colorTemplate.rawValue
        defaultIssuerProfileId = nil

        [
            storageKey,
            customersStorageKey,
            issuersStorageKey,
            productsStorageKey,
            textTemplatesStorageKey,
            draftStorageKey,
            defaultColorTemplateStorageKey,
            defaultIssuerProfileStorageKey
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }

        StampLibrary.deleteDefaultStamp()
        StampLibrary.deleteDefaultStampSettings()
    }

    func addLine() {
        current.lines.append(LineItem())
    }

    func removeLines(at offsets: IndexSet) {
        current.lines.remove(atOffsets: offsets)
        if current.lines.isEmpty {
            current.lines.append(LineItem())
        }
    }

    func removeLine(id: LineItem.ID) {
        current.lines.removeAll { $0.id == id }
        if current.lines.isEmpty {
            current.lines.append(LineItem())
        }
    }

    @discardableResult
    func addOrderAttachments(from urls: [URL]) -> Int {
        let attachments = makeAttachments(from: urls)
        guard !attachments.isEmpty else { return 0 }
        if current.orderAttachments == nil {
            current.orderAttachments = []
        }
        current.orderAttachments?.append(contentsOf: attachments)
        current.updatedAt = Date()
        persistDraft()
        return attachments.count
    }

    func removeOrderAttachment(id: OrderAttachment.ID) {
        current.orderAttachments?.removeAll { $0.id == id }
        current.updatedAt = Date()
        persistDraft()
    }

    @discardableResult
    func addPaymentProofAttachments(from urls: [URL]) -> Int {
        let attachments = makeAttachments(from: urls)
        guard !attachments.isEmpty else { return 0 }
        if current.paymentProofDate == nil {
            current.paymentProofDate = Date()
        }
        if current.paymentProofAmount == nil {
            current.paymentProofAmount = current.total
        }
        if current.paymentProofAttachments == nil {
            current.paymentProofAttachments = []
        }
        current.paymentProofAttachments?.append(contentsOf: attachments)
        current.updatedAt = Date()
        persistDraft()
        return attachments.count
    }

    @discardableResult
    func addPaymentProofImageAttachments(_ images: [Data]) -> Int {
        let attachments = images.enumerated().map { index, data in
            OrderAttachment(
                filename: "payment-proof-\(Self.attachmentTimestamp())-\(index + 1).jpg",
                contentType: "image/jpeg",
                data: data,
                uploadedAt: Date()
            )
        }
        guard !attachments.isEmpty else { return 0 }
        if current.paymentProofDate == nil {
            current.paymentProofDate = Date()
        }
        if current.paymentProofAmount == nil {
            current.paymentProofAmount = current.total
        }
        if current.paymentProofAttachments == nil {
            current.paymentProofAttachments = []
        }
        current.paymentProofAttachments?.append(contentsOf: attachments)
        current.updatedAt = Date()
        persistDraft()
        return attachments.count
    }

    func removePaymentProofAttachment(id: OrderAttachment.ID) {
        current.paymentProofAttachments?.removeAll { $0.id == id }
        current.updatedAt = Date()
        persistDraft()
    }

    private func makeAttachments(from urls: [URL]) -> [OrderAttachment] {
        urls.compactMap { url -> OrderAttachment? in
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard let data = try? Data(contentsOf: url) else { return nil }
            let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            return OrderAttachment(filename: url.lastPathComponent, contentType: type, data: data, uploadedAt: Date())
        }
    }

    private func ensureActiveDocumentForManagementApply() {
        guard !hasActiveDocument else { return }
        if documents.contains(where: { $0.id == current.id }) || !documents.isEmpty {
            hasActiveDocument = true
            return
        }
        var document = BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: documents))
        document.colorTemplateId = defaultColorTemplateId
        applyDefaultIssuer(to: &document)
        hasActiveDocument = true
        current = document
    }

    private static func attachmentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func sourceDocument(for project: ProjectArchive, preferredTypes: [DocumentType] = []) -> BusinessDocument? {
        var candidates = project.documents
        let currentBelongsToProject = current.projectId == project.id
        if current.projectId == project.id,
           !candidates.contains(where: { $0.id == current.id }) {
            candidates.insert(current, at: 0)
        } else if let index = candidates.firstIndex(where: { $0.id == current.id }) {
            candidates[index] = current
        }

        for type in preferredTypes {
            if let document = candidates
                .filter({ $0.type == type })
                .sorted(by: projectSourceSort)
                .first {
                return document
            }
        }

        if preferredTypes.isEmpty && currentBelongsToProject {
            return current
        }

        return candidates.sorted(by: projectSourceSort).first
    }

    private func projectSourceSort(_ lhs: BusinessDocument, _ rhs: BusinessDocument) -> Bool {
        if lhs.updatedAt == rhs.updatedAt {
            return lhs.issueDate > rhs.issueDate
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    private func applyProjectContext(from source: BusinessDocument?, project: ProjectArchive, to document: inout BusinessDocument) {
        document.colorTemplateId = source?.colorTemplateId ?? defaultColorTemplateId
        document.projectId = project.id
        document.projectName = source?.projectName ?? project.name
        document.projectDirection = source?.projectDirection ?? project.direction

        document.customerName = source?.customerName ?? project.customerName
        document.customerContact = source?.customerContact ?? ""
        document.customerPhone = source?.customerPhone
        document.customerEmail = source?.customerEmail
        document.customerAddress = source?.customerAddress ?? ""

        document.issuerName = source?.issuerName ?? document.issuerName
        document.issuerRegistration = source?.issuerRegistration ?? document.issuerRegistration
        document.issuerAddress = source?.issuerAddress ?? document.issuerAddress
        document.issuerContact = source?.issuerContact ?? document.issuerContact
        document.issuerPhone = source?.issuerPhone ?? document.issuerPhone
        document.issuerEmail = source?.issuerEmail ?? document.issuerEmail
        document.issuerLogoData = source?.issuerLogoData
        document.issuerLogoScale = source?.issuerLogoScale

        if let source, !source.lines.isEmpty {
            document.lines = source.lines.map { line in
                LineItem(
                    name: line.name,
                    model: line.model,
                    specification: line.specification,
                    quantity: line.quantity,
                    unitPrice: line.unitPrice
                )
            }
        }
    }

    private func persist() {
        guard let data = try? encoder.encode(documents) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        persistProfiles()
    }

    private func persistDraft() {
        guard hasActiveDocument else {
            clearDraft()
            return
        }
        guard let data = try? encoder.encode(current) else { return }
        UserDefaults.standard.set(data, forKey: draftStorageKey)
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftStorageKey)
    }

    private func persistProfiles() {
        if let data = try? encoder.encode(customers) {
            UserDefaults.standard.set(data, forKey: customersStorageKey)
        }
        if let data = try? encoder.encode(issuers) {
            UserDefaults.standard.set(data, forKey: issuersStorageKey)
        }
        if let data = try? encoder.encode(products) {
            UserDefaults.standard.set(data, forKey: productsStorageKey)
        }
        if let data = try? encoder.encode(textTemplates) {
            UserDefaults.standard.set(data, forKey: textTemplatesStorageKey)
        }
    }

    private static func loadDocuments(key: String, decoder: JSONDecoder) -> [BusinessDocument] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let documents = try? decoder.decode([BusinessDocument].self, from: data) else {
            return []
        }
        return documents
    }

    private static func loadProfiles<T: Decodable>(key: String, decoder: JSONDecoder) -> [T] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profiles = try? decoder.decode([T].self, from: data) else {
            return []
        }
        return profiles
    }

    private static func loadDraft(key: String, decoder: JSONDecoder) -> BusinessDocument? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(BusinessDocument.self, from: data)
    }

    private static func makeNumber(type: DocumentType, documents: [BusinessDocument]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let date = formatter.string(from: Date())
        let count = documents.filter { $0.type == type && $0.number.contains(date) }.count + 1
        return "\(type.prefix)-\(date)-\(String(format: "%03d", count))"
    }

    private static func archiveYear(for document: BusinessDocument) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: document.issueDate)
    }

    private static func archiveCustomerName(for document: BusinessDocument) -> String {
        let customer = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return customer.isEmpty ? "取引先未入力" : customer
    }

    private static func archiveProjectCode(for documents: [BusinessDocument]) -> String {
        let candidates = documents
            .map(\.number)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()
        guard let number = candidates.first else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            return formatter.string(from: Date())
        }
        let parts = number.split(separator: "-")
        if parts.count >= 3 {
            return parts.dropFirst().joined(separator: "-")
        }
        return number
    }

    private static func archiveFileBase(for document: BusinessDocument, duplicateTypeCount: Int) -> String {
        if duplicateTypeCount > 1 {
            return archiveSafeName("\(document.type.rawValue)-\(archiveProjectCode(for: [document]))")
        }
        return archiveSafeName(document.type.rawValue)
    }

    private static func archiveAttachmentName(_ attachment: OrderAttachment, index: Int, fileBase: String, kind: String = "evidence") -> String {
        let fallbackExtension = attachment.isPDF ? "pdf" : attachment.isImage ? "jpg" : "bin"
        let cleanOriginal = archiveSafeName(attachment.filename)
        if !cleanOriginal.isEmpty {
            return "\(fileBase)-\(kind)-\(index + 1)-\(cleanOriginal)"
        }
        return "\(fileBase)-\(kind)-\(index + 1).\(fallbackExtension)"
    }

    private static func archiveSafeName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "untitled" }
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
        let scalars = trimmed.unicodeScalars.map { scalar in
            invalid.contains(scalar) ? "-" : Character(scalar)
        }
        let cleaned = String(scalars).replacingOccurrences(of: "--", with: "-")
        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    }

    private static func archiveDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func archiveProjectMetadata(for documents: [BusinessDocument]) -> [String: Any] {
        let primary = documents.first ?? BusinessDocument()
        return [
            "app": "Shoko Forms",
            "schema_version": 1,
            "project_id": (primary.projectId ?? primary.id).uuidString,
            "project_name": primary.projectName ?? archiveProjectCode(for: documents),
            "project_code": archiveProjectCode(for: documents),
            "customer": archiveCustomerName(for: primary),
            "direction": primary.projectDirection?.rawValue ?? "",
            "document_count": documents.count,
            "updated_at": archiveDate(documents.map(\.updatedAt).max() ?? Date()),
        ]
    }

    private static func archiveDocumentMetadata(for document: BusinessDocument) -> [String: Any] {
        [
            "app": "Shoko Forms",
            "schema_version": 1,
            "document_id": document.id.uuidString,
            "project_id": document.projectId?.uuidString ?? "",
            "document_type": document.type.rawValue,
            "document_title": document.type.localizedTitle(.japanese),
            "number": document.number,
            "invoice_number": document.type == .invoice ? document.number : "",
            "customer": document.customerName,
            "customer_contact": document.customerContact,
            "customer_phone": document.customerPhone ?? "",
            "customer_email": document.customerEmail ?? "",
            "issuer": document.issuerName,
            "issuer_registration": document.issuerRegistration,
            "issue_date": archiveDate(document.issueDate),
            "transaction_date": archiveDate(document.transactionDate),
            "due_date": archiveDate(document.dueDate),
            "related_number": document.relatedNumber,
            "subtotal": document.subtotal,
            "tax_rate": document.taxRate,
            "tax": document.tax,
            "amount": document.total,
            "notes": document.notes,
            "payment_details": document.paymentDetails,
            "document_memo": document.documentMemo,
            "attachments_count": document.orderAttachments?.count ?? 0,
            "payment_proof_date": document.paymentProofDate.map(archiveDate) ?? "",
            "payment_proof_amount": document.paymentProofAmount ?? 0,
            "payment_proof_attachments_count": document.paymentProofAttachments?.count ?? 0,
            "payment_proof_attachments": (document.paymentProofAttachments ?? []).enumerated().map { index, attachment in
                [
                    "index": index + 1,
                    "filename": attachment.filename,
                    "content_type": attachment.contentType,
                    "file_size": attachment.data.count,
                    "uploaded_at": archiveDate(attachment.uploadedAt),
                ] as [String: Any]
            },
            "updated_at": archiveDate(document.updatedAt),
            "lines": document.lines.map { line in
                [
                    "name": line.name,
                    "model": line.model,
                    "specification": line.specification,
                    "quantity": line.quantity,
                    "unit_price": line.unitPrice,
                    "amount": line.amount,
                ] as [String: Any]
            },
        ]
    }

    private static func archiveOCRPlaceholder(for document: BusinessDocument) -> [String: Any] {
        [
            "schema_version": 1,
            "document_id": document.id.uuidString,
            "document_number": document.number,
            "ocr_status": "pending",
            "text": "",
            "created_at": archiveDate(Date()),
        ]
    }

    private static func writeJSONObject(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private static func replaceFile(at destinationURL: URL, with sourceURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func seedProfiles(from documents: [BusinessDocument]) {
        documents.forEach { captureProfiles(from: $0, shouldPersist: false) }
        sortProfiles()
        persistProfiles()
    }

    private func seedTextTemplates(from documents: [BusinessDocument]) {
        documents.forEach { document in
            upsertTextTemplate(kind: .note, title: Self.templateTitle(from: document.notes), content: document.notes, shouldPersist: false)
            upsertTextTemplate(kind: .payment, title: Self.templateTitle(from: document.paymentDetails), content: document.paymentDetails, shouldPersist: false)
            upsertTextTemplate(kind: .condition, title: Self.templateTitle(from: document.documentMemo), content: document.documentMemo, shouldPersist: false)
        }
        sortProfiles()
        persistProfiles()
    }

    private func captureProfiles(from document: BusinessDocument, shouldPersist: Bool = true) {
        upsertCustomer(
            name: document.customerName,
            contact: document.customerContact,
            phone: document.customerPhone ?? "",
            email: document.customerEmail ?? "",
            address: document.customerAddress,
            shouldPersist: false
        )
        upsertIssuer(
            name: document.issuerName,
            registration: document.issuerRegistration,
            contact: document.issuerContact,
            phone: document.issuerPhone,
            email: document.issuerEmail,
            address: document.issuerAddress,
            shouldPersist: false
        )
        document.lines.forEach {
            upsertProduct(name: $0.name, model: $0.model, specification: $0.specification, unitPrice: $0.unitPrice, shouldPersist: false)
        }
        upsertTextTemplate(kind: .note, title: Self.templateTitle(from: document.notes), content: document.notes, shouldPersist: false)
        upsertTextTemplate(kind: .payment, title: Self.templateTitle(from: document.paymentDetails), content: document.paymentDetails, shouldPersist: false)
        upsertTextTemplate(kind: .condition, title: Self.templateTitle(from: document.documentMemo), content: document.documentMemo, shouldPersist: false)
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
    }

    private func upsertCustomer(name: String, contact: String, phone: String, email: String, address: String, shouldPersist: Bool = true) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = customers.firstIndex(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
            customers[index].contact = contact
            customers[index].phone = phone
            customers[index].email = email
            customers[index].address = address
            customers[index].updatedAt = Date()
        } else {
            customers.insert(CustomerProfile(name: cleanName, contact: contact, phone: phone, email: email, address: address), at: 0)
        }
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
    }

    @discardableResult
    private func upsertIssuer(
        name: String,
        registration: String,
        contact: String,
        phone: String,
        email: String,
        address: String,
        shouldPersist: Bool = true
    ) -> IssuerProfile? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let savedID: IssuerProfile.ID
        if let index = issuers.firstIndex(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
            issuers[index].registration = registration
            issuers[index].contact = contact
            issuers[index].phone = phone
            issuers[index].email = email
            issuers[index].address = address
            issuers[index].updatedAt = Date()
            savedID = issuers[index].id
        } else {
            let issuer = IssuerProfile(name: cleanName, registration: registration, contact: contact, phone: phone, email: email, address: address)
            issuers.insert(issuer, at: 0)
            savedID = issuer.id
        }
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
        return issuers.first { $0.id == savedID }
    }

    private func applyDefaultIssuer(to document: inout BusinessDocument) {
        guard let issuer = defaultIssuerProfile else { return }
        document.issuerName = issuer.name
        document.issuerRegistration = issuer.registration
        document.issuerContact = issuer.contact
        document.issuerPhone = issuer.phone
        document.issuerEmail = issuer.email
        document.issuerAddress = issuer.address
        document.issuerLogoData = issuer.logoData
        document.issuerLogoScale = issuer.logoScale
    }

    private func upsertProduct(name: String, model: String, specification: String, unitPrice: Double, shouldPersist: Bool = true) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = products.firstIndex(where: { product in
            product.name.caseInsensitiveCompare(cleanName) == .orderedSame &&
            product.model.caseInsensitiveCompare(model) == .orderedSame
        }) {
            products[index].specification = specification
            products[index].unitPrice = unitPrice
            products[index].updatedAt = Date()
        } else {
            products.insert(ProductProfile(name: cleanName, model: model, specification: specification, unitPrice: unitPrice), at: 0)
        }
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
    }

    private func upsertTextTemplate(kind: TextTemplateKind, title: String, content: String, shouldPersist: Bool = true) {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = textTemplates.firstIndex(where: { template in
            template.kind == kind && template.content.caseInsensitiveCompare(cleanContent) == .orderedSame
        }) {
            textTemplates[index].title = cleanTitle.isEmpty ? Self.templateTitle(from: cleanContent) : cleanTitle
            textTemplates[index].updatedAt = Date()
        } else {
            textTemplates.insert(TextTemplate(kind: kind, title: cleanTitle.isEmpty ? Self.templateTitle(from: cleanContent) : cleanTitle, content: cleanContent), at: 0)
        }
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
    }

    private func sortProfiles() {
        customers.sort { $0.updatedAt > $1.updatedAt }
        issuers.sort { $0.updatedAt > $1.updatedAt }
        products.sort { $0.updatedAt > $1.updatedAt }
        textTemplates.sort { $0.updatedAt > $1.updatedAt }
    }

    private func mergeDocuments(_ incoming: [BusinessDocument]) {
        let existingIds = Set(documents.map(\.id))
        documents.append(contentsOf: incoming.filter { !existingIds.contains($0.id) })
    }

    private func mergeCustomers(_ incoming: [CustomerProfile]) {
        let names = Set(customers.map { $0.name.lowercased() })
        customers.append(contentsOf: incoming.filter { !names.contains($0.name.lowercased()) })
    }

    private func mergeIssuers(_ incoming: [IssuerProfile]) {
        let names = Set(issuers.map { $0.name.lowercased() })
        issuers.append(contentsOf: incoming.filter { !names.contains($0.name.lowercased()) })
    }

    private func mergeProducts(_ incoming: [ProductProfile]) {
        let keys = Set(products.map { "\($0.name.lowercased())|\($0.model.lowercased())" })
        products.append(contentsOf: incoming.filter { !keys.contains("\($0.name.lowercased())|\($0.model.lowercased())") })
    }

    private func mergeTextTemplates(_ incoming: [TextTemplate]) {
        let keys = Set(textTemplates.map { "\($0.kind.rawValue)|\($0.content.lowercased())" })
        textTemplates.append(contentsOf: incoming.filter { !keys.contains("\($0.kind.rawValue)|\($0.content.lowercased())") })
    }

    private static func templateTitle(from content: String) -> String {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty else { return "" }
        let firstLine = cleanContent.components(separatedBy: .newlines).first ?? cleanContent
        return String(firstLine.prefix(24))
    }

    private static func sanitizedFileBaseName(_ value: String, fallback: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return sanitized.isEmpty ? fallback : sanitized
    }

    private func filtered<T>(_ values: [T], query: String, text: (T) -> String) -> [T] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty {
            return values
        }
        return values.filter { text($0).localizedCaseInsensitiveContains(cleanQuery) }
    }

    private static func decodeISO8601Date(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter = ISO8601DateFormatter()
        if let date = fractionalFormatter.date(from: value) ?? formatter.date(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
    }
}

enum BackupImportMode {
    case merge
    case replace
}

private struct LocalBackup: Codable {
    var version = 1
    var exportedAt: Date
    var documents: [BusinessDocument]
    var customers: [CustomerProfile]
    var issuers: [IssuerProfile]
    var products: [ProductProfile]
    var draft: BusinessDocument?
    var textTemplates: [TextTemplate]?
}

private struct SharedFormFile: Codable {
    var version = 1
    var exportedAt: Date
    var document: BusinessDocument
}
