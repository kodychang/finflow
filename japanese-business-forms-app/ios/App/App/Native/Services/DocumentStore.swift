import Foundation
import Combine

final class DocumentStore: ObservableObject {
    @Published var current: BusinessDocument
    @Published private(set) var documents: [BusinessDocument]

    private let storageKey = "native.shokoForms.documents.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        let loaded = Self.loadDocuments(key: storageKey, decoder: decoder)
        documents = loaded.sorted { $0.updatedAt > $1.updatedAt }
        current = loaded.first ?? BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: loaded))
    }

    func newDocument(type: DocumentType) {
        current = BusinessDocument.blank(type: type, number: Self.makeNumber(type: type, documents: documents))
    }

    func select(_ document: BusinessDocument) {
        current = document
    }

    func saveCurrent() {
        current.updatedAt = Date()
        if let index = documents.firstIndex(where: { $0.id == current.id }) {
            documents[index] = current
        } else {
            documents.insert(current, at: 0)
        }
        documents.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func delete(_ document: BusinessDocument) {
        documents.removeAll { $0.id == document.id }
        if current.id == document.id {
            current = documents.first ?? BusinessDocument.blank(type: .invoice, number: Self.makeNumber(type: .invoice, documents: documents))
        }
        persist()
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

    private func persist() {
        guard let data = try? encoder.encode(documents) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func loadDocuments(key: String, decoder: JSONDecoder) -> [BusinessDocument] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let documents = try? decoder.decode([BusinessDocument].self, from: data) else {
            return []
        }
        return documents
    }

    private static func makeNumber(type: DocumentType, documents: [BusinessDocument]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let date = formatter.string(from: Date())
        let count = documents.filter { $0.type == type && $0.number.contains(date) }.count + 1
        return "\(type.prefix)-\(date)-\(String(format: "%03d", count))"
    }
}
