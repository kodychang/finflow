import SwiftUI

struct PreviewScreen: View {
    let document: BusinessDocument
    @State private var sharePayload: SharePayload?
    @State private var exportError = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PDF Preview")
                            .font(.caption.weight(.black))
                            .foregroundColor(.appMuted)
                        if !exportError.isEmpty {
                            Text(exportError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    Spacer()
                    Button {
                        exportPDF()
                    } label: {
                        Label("PDF保存", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.black))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.appAccent)
                            .foregroundColor(.appInk)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: 720)

                VStack(alignment: .leading, spacing: 18) {
                    documentHeader
                    parties
                    totalBanner
                    lineTable
                    notesAndTotals
                }
                .padding(28)
                .frame(maxWidth: 720, alignment: .topLeading)
                .background(Color(red: 1.0, green: 0.996, blue: 0.968))
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.12), radius: 22, x: 0, y: 12)
            }
            .padding(24)
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
    }

    private func exportPDF() {
        do {
            exportError = ""
            sharePayload = SharePayload(url: try DocumentPDFExporter.export(document))
        } catch {
            exportError = "PDFを書き出せませんでした。"
        }
    }

    private var documentHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.type.title)
                    .font(.system(size: 32, weight: .black, design: .serif))
                Text(document.type.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
                Text("下記の通り、ご案内申し上げます。")
                    .font(.caption)
                    .padding(.top, 6)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                meta("番号", document.number)
                meta("発行日", AppFormatters.date.string(from: document.issueDate))
                meta("取引日", AppFormatters.date.string(from: document.transactionDate))
                meta("期限", AppFormatters.date.string(from: document.dueDate))
            }
            .font(.caption)
        }
    }

    private var parties: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(document.customerName.isEmpty ? "取引先名" : document.customerName) \(document.honorific)")
                    .font(.headline.weight(.black))
                Text(document.customerAddress)
                Text(document.customerContact)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if !document.issuerRegistration.isEmpty {
                    Text("登録番号: \(document.issuerRegistration)")
                        .font(.caption.weight(.semibold))
                }
                Text(document.issuerName.isEmpty ? "自社名" : document.issuerName)
                    .font(.headline.weight(.black))
                Text(document.issuerAddress)
                Text([document.issuerContact, document.issuerPhone, document.issuerEmail].filter { !$0.isEmpty }.joined(separator: " / "))
                    .font(.caption)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 18)
    }

    private var totalBanner: some View {
        HStack {
            Text(document.type.totalLabel)
                .font(.headline.weight(.black))
            Spacer()
            Text(AppFormatters.yen(document.total))
                .font(.title.weight(.black))
        }
        .padding(16)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInk.opacity(0.55)))
    }

    private var lineTable: some View {
        VStack(spacing: 0) {
            HStack {
                tableHeader("品目", width: nil)
                tableHeader("型番 / 仕様", width: nil)
                tableHeader("数量", width: 58)
                tableHeader("単価", width: 92)
                tableHeader("金額", width: 104)
            }
            ForEach(document.lines) { line in
                HStack(alignment: .top) {
                    tableCell(line.name, width: nil)
                    tableCell([line.model, line.specification].filter { !$0.isEmpty }.joined(separator: " / "), width: nil)
                    tableCell(String(format: "%.2g", line.quantity), width: 58, alignment: .trailing)
                    tableCell(AppFormatters.yen(line.unitPrice), width: 92, alignment: .trailing)
                    tableCell(AppFormatters.yen(line.amount), width: 104, alignment: .trailing)
                }
                .background(Color.white.opacity(0.72))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInk.opacity(0.35)))
    }

    private var notesAndTotals: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                memoBlock("備考", document.notes)
                memoBlock("振込先 / 確認状況", document.paymentDetails)
                memoBlock("帳票別メモ", document.documentMemo)
            }
            Spacer()
            VStack(spacing: 0) {
                totalRow("小計", document.subtotal)
                totalRow("消費税 \(String(format: "%.1g", document.taxRate))%", document.tax)
                totalRow("合計", document.total, emphasized: true)
            }
            .frame(width: 220)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInk.opacity(0.35)))
        }
    }

    private func meta(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.appMuted)
            Text(value.isEmpty ? "-" : value).fontWeight(.bold)
        }
    }

    private func tableHeader(_ text: String, width: CGFloat?) -> some View {
        Group {
            if let width = width {
                Text(text)
                    .font(.caption.weight(.black))
                    .frame(width: width, alignment: .leading)
            } else {
                Text(text)
                    .font(.caption.weight(.black))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(Color.appInk.opacity(0.08))
    }

    private func tableCell(_ text: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Group {
            if let width = width {
                Text(text.isEmpty ? "-" : text)
                    .font(.caption)
                    .frame(width: width, alignment: alignment)
            } else {
                Text(text.isEmpty ? "-" : text)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: alignment)
            }
        }
        .padding(8)
    }

    private func memoBlock(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.black))
            Text(value.isEmpty ? "-" : value)
                .font(.caption)
                .foregroundColor(.appInk.opacity(0.78))
        }
    }

    private func totalRow(_ title: String, _ value: Double, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(AppFormatters.yen(value))
        }
        .font(emphasized ? .headline.weight(.black) : .caption.weight(.bold))
        .padding(10)
        .background(emphasized ? Color.appAccent.opacity(0.5) : Color.white)
    }
}
