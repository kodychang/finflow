import Foundation
import Combine

final class DocumentStore: ObservableObject {
    @Published var current: BusinessDocument {
        didSet {
            persistDraft()
        }
    }
    @Published private(set) var documents: [BusinessDocument]
    @Published private(set) var customers: [CustomerProfile]
    @Published private(set) var issuers: [IssuerProfile]
    @Published private(set) var products: [ProductProfile]
    @Published private(set) var defaultColorTemplateId: String {
        didSet {
            UserDefaults.standard.set(defaultColorTemplateId, forKey: defaultColorTemplateStorageKey)
        }
    }

    private let storageKey = "native.shokoForms.documents.v1"
    private let customersStorageKey = "native.shokoForms.customers.v1"
    private let issuersStorageKey = "native.shokoForms.issuers.v1"
    private let productsStorageKey = "native.shokoForms.products.v1"
    private let draftStorageKey = "native.shokoForms.currentDraft.v1"
    private let defaultColorTemplateStorageKey = "native.shokoForms.defaultColorTemplate.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeISO8601Date(decoder)
        }
        let loaded = Self.loadDocuments(key: storageKey, decoder: decoder)
        documents = loaded.sorted { $0.updatedAt > $1.updatedAt }
        current = Self.loadDraft(key: draftStorageKey, decoder: decoder) ??
            loaded.first ??
            BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: loaded))
        let hasSavedProfiles = UserDefaults.standard.object(forKey: customersStorageKey) != nil ||
            UserDefaults.standard.object(forKey: issuersStorageKey) != nil ||
            UserDefaults.standard.object(forKey: productsStorageKey) != nil
        customers = Self.loadProfiles(key: customersStorageKey, decoder: decoder)
        issuers = Self.loadProfiles(key: issuersStorageKey, decoder: decoder)
        products = Self.loadProfiles(key: productsStorageKey, decoder: decoder)
        defaultColorTemplateId = UserDefaults.standard.string(forKey: defaultColorTemplateStorageKey) ?? current.colorTemplate.rawValue
        if !hasSavedProfiles {
            seedProfiles(from: loaded)
        }
    }

    func newDocument(type: DocumentType) {
        var document = BusinessDocument.blank(type: type, number: Self.makeNumber(type: type, documents: documents))
        document.colorTemplateId = defaultColorTemplateId
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

    func createProject(direction: ProjectDirection, customer: CustomerProfile?) {
        let projectId = UUID()
        let type = direction.firstType
        var document = BusinessDocument.blank(type: type, number: Self.makeNumber(type: type, documents: documents))
        document.colorTemplateId = defaultColorTemplateId
        document.projectId = projectId
        document.projectDirection = direction
        if let customer {
            document.customerName = customer.name
            document.customerContact = customer.contact
            document.customerAddress = customer.address
        }
        let cleanName = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        document.projectName = cleanName.isEmpty ? "\(direction.title) \(AppFormatters.shortDate(Date()))" : "\(AppFormatters.shortDate(Date())) \(cleanName)"
        current = document
        saveCurrent()
    }

    func openProjectForm(project: ProjectArchive, type: DocumentType) {
        if let existing = project.document(for: type) {
            current = existing
            return
        }
        let source = project.documents.first
        var document = BusinessDocument.blank(type: type, number: Self.makeNumber(type: type, documents: documents))
        document.colorTemplateId = source?.colorTemplateId ?? defaultColorTemplateId
        document.projectId = project.id
        document.projectName = project.name
        document.projectDirection = project.direction
        document.customerName = source?.customerName ?? project.customerName
        document.customerContact = source?.customerContact ?? ""
        document.customerAddress = source?.customerAddress ?? ""
        document.issuerName = source?.issuerName ?? document.issuerName
        document.issuerRegistration = source?.issuerRegistration ?? document.issuerRegistration
        document.issuerAddress = source?.issuerAddress ?? document.issuerAddress
        document.issuerContact = source?.issuerContact ?? document.issuerContact
        document.issuerPhone = source?.issuerPhone ?? document.issuerPhone
        document.issuerEmail = source?.issuerEmail ?? document.issuerEmail
        document.issuerLogoData = source?.issuerLogoData
        document.issuerLogoScale = source?.issuerLogoScale
        document.lines = source?.lines.map { line in
            LineItem(name: line.name, model: line.model, specification: line.specification, quantity: line.quantity, unitPrice: line.unitPrice)
        } ?? document.lines
        current = document
        saveCurrent()
    }

    func select(_ document: BusinessDocument) {
        current = document
    }

    func saveCurrent() {
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

    func saveDraft() {
        persistDraft()
    }

    func discardDraft() {
        clearDraft()
        if let firstDocument = documents.first {
            current = firstDocument
        } else {
            var document = BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: documents))
            document.colorTemplateId = defaultColorTemplateId
            current = document
        }
    }

    func backupFileURL() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "shoko-forms-backup-\(formatter.string(from: Date())).shokobackup"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try backupData().write(to: url, options: .atomic)
        return url
    }

    func backupData() throws -> Data {
        let backup = LocalBackup(
            exportedAt: Date(),
            documents: documents,
            customers: customers,
            issuers: issuers,
            products: products,
            draft: current
        )
        return try encoder.encode(backup)
    }

    func importBackupData(_ data: Data, mode: BackupImportMode) throws {
        let backup = try decoder.decode(LocalBackup.self, from: data)
        switch mode {
        case .replace:
            documents = backup.documents.sorted { $0.updatedAt > $1.updatedAt }
            customers = backup.customers.sorted { $0.updatedAt > $1.updatedAt }
            issuers = backup.issuers.sorted { $0.updatedAt > $1.updatedAt }
            products = backup.products.sorted { $0.updatedAt > $1.updatedAt }
            current = backup.draft ?? documents.first ?? newFallbackDocument()
            defaultColorTemplateId = current.colorTemplate.rawValue
        case .merge:
            let hadDocuments = !documents.isEmpty
            mergeDocuments(backup.documents)
            mergeCustomers(backup.customers)
            mergeIssuers(backup.issuers)
            mergeProducts(backup.products)
            if !hadDocuments, let draft = backup.draft {
                current = draft
            }
        }
        documents.sort { $0.updatedAt > $1.updatedAt }
        sortProfiles()
        persist()
        persistDraft()
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

    func apply(_ customer: CustomerProfile) {
        current.customerName = customer.name
        current.customerContact = customer.contact
        current.customerAddress = customer.address
    }

    func apply(_ issuer: IssuerProfile) {
        current.issuerName = issuer.name
        current.issuerRegistration = issuer.registration
        current.issuerContact = issuer.contact
        current.issuerPhone = issuer.phone
        current.issuerEmail = issuer.email
        current.issuerAddress = issuer.address
        current.issuerLogoData = issuer.logoData
        current.issuerLogoScale = issuer.logoScale
    }

    func apply(_ product: ProductProfile) {
        if current.lines.isEmpty {
            current.lines.append(LineItem())
        }
        current.lines[0].name = product.name
        current.lines[0].model = product.model
        current.lines[0].specification = product.specification
        current.lines[0].unitPrice = product.unitPrice
    }

    func rememberCustomerFromCurrent() {
        upsertCustomer(name: current.customerName, contact: current.customerContact, address: current.customerAddress)
    }

    func rememberIssuerFromCurrent() {
        upsertIssuer(
            name: current.issuerName,
            registration: current.issuerRegistration,
            contact: current.issuerContact,
            phone: current.issuerPhone,
            email: current.issuerEmail,
            address: current.issuerAddress,
            logoData: current.issuerLogoData,
            logoScale: current.issuerLogoScale
        )
    }

    func rememberProduct(_ line: LineItem) {
        upsertProduct(name: line.name, model: line.model, specification: line.specification, unitPrice: line.unitPrice)
    }

    func saveCustomerProfile(name: String, contact: String, address: String) {
        upsertCustomer(name: name, contact: contact, address: address)
    }

    func updateCustomerProfile(id: CustomerProfile.ID, name: String, contact: String, address: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = customers.firstIndex(where: { $0.id == id }) {
            customers[index].name = cleanName
            customers[index].contact = contact
            customers[index].address = address
            customers[index].updatedAt = Date()
        } else {
            customers.insert(CustomerProfile(id: id, name: cleanName, contact: contact, address: address), at: 0)
        }
        sortProfiles()
        persistProfiles()
    }

    func saveIssuerProfile(name: String, registration: String, contact: String, phone: String, email: String, address: String, logoData: Data?, logoScale: Double?) {
        upsertIssuer(
            name: name,
            registration: registration,
            contact: contact,
            phone: phone,
            email: email,
            address: address,
            logoData: logoData,
            logoScale: logoScale
        )
    }

    func updateIssuerProfile(id: IssuerProfile.ID, name: String, registration: String, contact: String, phone: String, email: String, address: String, logoData: Data?, logoScale: Double?) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = issuers.firstIndex(where: { $0.id == id }) {
            issuers[index].name = cleanName
            issuers[index].registration = registration
            issuers[index].contact = contact
            issuers[index].phone = phone
            issuers[index].email = email
            issuers[index].address = address
            issuers[index].logoData = logoData
            issuers[index].logoScale = logoScale
            issuers[index].updatedAt = Date()
        } else {
            issuers.insert(IssuerProfile(id: id, name: cleanName, registration: registration, contact: contact, phone: phone, email: email, address: address, logoData: logoData, logoScale: logoScale), at: 0)
        }
        sortProfiles()
        persistProfiles()
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
        persistProfiles()
    }

    func deleteProduct(_ product: ProductProfile) {
        products.removeAll { $0.id == product.id }
        persistProfiles()
    }

    func delete(_ document: BusinessDocument) {
        documents.removeAll { $0.id == document.id }
        if current.id == document.id {
            current = documents.first ?? newFallbackDocument()
        }
        persist()
    }

    func deleteDocuments(ids: Set<BusinessDocument.ID>) {
        guard !ids.isEmpty else { return }
        documents.removeAll { ids.contains($0.id) }
        if ids.contains(current.id) {
            current = documents.first ?? newFallbackDocument()
        }
        persist()
    }

    private func newFallbackDocument() -> BusinessDocument {
        var document = BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: documents))
        document.colorTemplateId = defaultColorTemplateId
        return document
    }

    func deleteProject(_ project: ProjectArchive) {
        deleteDocuments(ids: Set(project.documents.map(\.id)))
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

    private func persist() {
        guard let data = try? encoder.encode(documents) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        persistProfiles()
    }

    private func persistDraft() {
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

    private func seedProfiles(from documents: [BusinessDocument]) {
        documents.forEach { captureProfiles(from: $0, shouldPersist: false) }
        sortProfiles()
        persistProfiles()
    }

    private func captureProfiles(from document: BusinessDocument, shouldPersist: Bool = true) {
        upsertCustomer(name: document.customerName, contact: document.customerContact, address: document.customerAddress, shouldPersist: false)
        upsertIssuer(
            name: document.issuerName,
            registration: document.issuerRegistration,
            contact: document.issuerContact,
            phone: document.issuerPhone,
            email: document.issuerEmail,
            address: document.issuerAddress,
            logoData: document.issuerLogoData,
            logoScale: document.issuerLogoScale,
            shouldPersist: false
        )
        document.lines.forEach {
            upsertProduct(name: $0.name, model: $0.model, specification: $0.specification, unitPrice: $0.unitPrice, shouldPersist: false)
        }
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
    }

    private func upsertCustomer(name: String, contact: String, address: String, shouldPersist: Bool = true) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = customers.firstIndex(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
            customers[index].contact = contact
            customers[index].address = address
            customers[index].updatedAt = Date()
        } else {
            customers.insert(CustomerProfile(name: cleanName, contact: contact, address: address), at: 0)
        }
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
    }

    private func upsertIssuer(
        name: String,
        registration: String,
        contact: String,
        phone: String,
        email: String,
        address: String,
        logoData: Data?,
        logoScale: Double?,
        shouldPersist: Bool = true
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        if let index = issuers.firstIndex(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
            issuers[index].registration = registration
            issuers[index].contact = contact
            issuers[index].phone = phone
            issuers[index].email = email
            issuers[index].address = address
            issuers[index].logoData = logoData
            issuers[index].logoScale = logoScale
            issuers[index].updatedAt = Date()
        } else {
            issuers.insert(IssuerProfile(name: cleanName, registration: registration, contact: contact, phone: phone, email: email, address: address, logoData: logoData, logoScale: logoScale), at: 0)
        }
        sortProfiles()
        if shouldPersist {
            persistProfiles()
        }
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

    private func sortProfiles() {
        customers.sort { $0.updatedAt > $1.updatedAt }
        issuers.sort { $0.updatedAt > $1.updatedAt }
        products.sort { $0.updatedAt > $1.updatedAt }
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

    private func filtered<T>(_ values: [T], query: String, text: (T) -> String) -> [T] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty {
            return Array(values.prefix(6))
        }
        return Array(values.filter { text($0).localizedCaseInsensitiveContains(cleanQuery) }.prefix(6))
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
}
