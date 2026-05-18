import Foundation
import UIKit

enum DocumentPDFExporter {
    static func export(_ document: BusinessDocument) throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: document))
            .appendingPathExtension("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            draw(document, in: bounds.insetBy(dx: 42, dy: 42))
        }

        return url
    }

    private static func fileName(for document: BusinessDocument) -> String {
        let base = [document.number, document.type.title]
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }

    private static func draw(_ document: BusinessDocument, in rect: CGRect) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .black),
            .foregroundColor: UIColor.black,
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.darkGray,
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black,
        ]
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.black,
        ]

        var y = rect.minY
        drawText(document.type.title, at: CGPoint(x: rect.minX, y: y), width: 260, attributes: titleAttributes)
        drawText(document.type.subtitle, at: CGPoint(x: rect.minX, y: y + 34), width: 260, attributes: subtitleAttributes)

        let metaX = rect.maxX - 170
        [
            ("番号", document.number),
            ("発行日", AppFormatters.date.string(from: document.issueDate)),
            ("取引日", AppFormatters.date.string(from: document.transactionDate)),
            ("期限", AppFormatters.date.string(from: document.dueDate)),
        ].enumerated().forEach { index, item in
            drawText("\(item.0): \(item.1.isEmpty ? "-" : item.1)", at: CGPoint(x: metaX, y: y + CGFloat(index * 16)), width: 170, attributes: bodyAttributes)
        }

        y += 86
        drawLine(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.maxX, y: y))
        y += 26

        drawText("\(document.customerName.isEmpty ? "取引先名" : document.customerName) \(document.honorific)", at: CGPoint(x: rect.minX, y: y), width: 230, attributes: boldAttributes)
        drawText(document.customerAddress, at: CGPoint(x: rect.minX, y: y + 18), width: 230, attributes: bodyAttributes)
        drawText(document.customerContact, at: CGPoint(x: rect.minX, y: y + 36), width: 230, attributes: bodyAttributes)

        drawText(document.issuerName.isEmpty ? "自社名" : document.issuerName, at: CGPoint(x: metaX, y: y), width: 170, attributes: boldAttributes)
        drawText(document.issuerAddress, at: CGPoint(x: metaX, y: y + 18), width: 170, attributes: bodyAttributes)
        drawText([document.issuerContact, document.issuerPhone, document.issuerEmail].filter { !$0.isEmpty }.joined(separator: " / "), at: CGPoint(x: metaX, y: y + 36), width: 170, attributes: bodyAttributes)

        y += 92
        drawBox(CGRect(x: rect.minX, y: y, width: rect.width, height: 48))
        drawText(document.type.totalLabel, at: CGPoint(x: rect.minX + 12, y: y + 15), width: 160, attributes: boldAttributes)
        drawText(AppFormatters.yen(document.total), at: CGPoint(x: rect.maxX - 180, y: y + 10), width: 166, attributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .black),
            .foregroundColor: UIColor.black,
        ])

        y += 72
        let widths: [CGFloat] = [144, 142, 52, 78, 92]
        let headers = ["品目", "型番 / 仕様", "数量", "単価", "金額"]
        drawTableRow(headers, y: y, x: rect.minX, widths: widths, attributes: boldAttributes, shaded: true)
        y += 28
        for line in document.lines.prefix(12) {
            drawTableRow([
                line.name.isEmpty ? "-" : line.name,
                [line.model, line.specification].filter { !$0.isEmpty }.joined(separator: " / "),
                String(format: "%.2g", line.quantity),
                AppFormatters.yen(line.unitPrice),
                AppFormatters.yen(line.amount),
            ], y: y, x: rect.minX, widths: widths, attributes: bodyAttributes)
            y += 28
        }

        y += 24
        drawText("備考", at: CGPoint(x: rect.minX, y: y), width: 220, attributes: boldAttributes)
        drawText(document.notes.isEmpty ? "-" : document.notes, at: CGPoint(x: rect.minX, y: y + 16), width: 300, attributes: bodyAttributes)
        drawText("小計  \(AppFormatters.yen(document.subtotal))", at: CGPoint(x: metaX, y: y), width: 170, attributes: boldAttributes)
        drawText("消費税  \(AppFormatters.yen(document.tax))", at: CGPoint(x: metaX, y: y + 18), width: 170, attributes: boldAttributes)
        drawText("合計  \(AppFormatters.yen(document.total))", at: CGPoint(x: metaX, y: y + 40), width: 170, attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .black),
            .foregroundColor: UIColor.black,
        ])
    }

    private static func drawText(_ text: String, at point: CGPoint, width: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(in: CGRect(x: point.x, y: point.y, width: width, height: 44), withAttributes: attributes)
    }

    private static func drawLine(from start: CGPoint, to end: CGPoint) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        UIColor.black.withAlphaComponent(0.28).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawBox(_ rect: CGRect) {
        UIColor.black.withAlphaComponent(0.55).setStroke()
        UIBezierPath(rect: rect).stroke()
    }

    private static func drawTableRow(_ values: [String], y: CGFloat, x: CGFloat, widths: [CGFloat], attributes: [NSAttributedString.Key: Any], shaded: Bool = false) {
        var currentX = x
        for (index, value) in values.enumerated() {
            let cell = CGRect(x: currentX, y: y, width: widths[index], height: 28)
            if shaded {
                UIColor.black.withAlphaComponent(0.06).setFill()
                UIBezierPath(rect: cell).fill()
            }
            UIColor.black.withAlphaComponent(0.25).setStroke()
            UIBezierPath(rect: cell).stroke()
            (value as NSString).draw(in: cell.insetBy(dx: 5, dy: 7), withAttributes: attributes)
            currentX += widths[index]
        }
    }
}
