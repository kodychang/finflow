import Foundation
import PDFKit
import UIKit

enum DocumentPDFExporter {
    private static let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private static let pageInset: CGFloat = 42

    static func export(_ document: BusinessDocument) throws -> URL {
        let bounds = pageBounds
        let contentRect = bounds.insetBy(dx: pageInset, dy: pageInset)
        let contentHeight = measuredContentHeight(for: document, in: contentRect)
        let pageCount = min(2, max(1, Int(ceil(contentHeight / bounds.height))))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: document))
            .appendingPathExtension("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        try renderer.writePDF(to: url) { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.clip(to: bounds)
                cgContext.translateBy(x: 0, y: -bounds.height * CGFloat(pageIndex))
                draw(document, in: contentRect)
                cgContext.restoreGState()
                drawPageNumber(pageIndex: pageIndex, pageCount: pageCount, in: bounds)
            }
        }

        return url
    }

    static func previewImage(for document: BusinessDocument, scale: CGFloat = UIScreen.main.scale) throws -> UIImage {
        guard let image = try previewImages(for: document, scale: scale).first else {
            throw ExportError.pdfPageUnavailable
        }
        return image
    }

    static func previewImages(for document: BusinessDocument, scale: CGFloat = UIScreen.main.scale) throws -> [UIImage] {
        let pdfURL = try export(document)
        return try renderPageImages(from: pdfURL, scale: scale)
    }

    static func exportPreviewPNG(_ document: BusinessDocument, scale: CGFloat = UIScreen.main.scale) throws -> URL {
        let image = try previewImage(for: document, scale: scale)
        guard let data = image.pngData() else {
            throw ExportError.pngEncodingFailed
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: document))
            .appendingPathExtension("png")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func renderPageImages(from pdfURL: URL, scale: CGFloat) throws -> [UIImage] {
        guard let document = PDFDocument(url: pdfURL), document.pageCount > 0 else {
            throw ExportError.pdfPageUnavailable
        }

        return try (0..<min(2, document.pageCount)).map { index in
            guard let page = document.page(at: index) else {
                throw ExportError.pdfPageUnavailable
            }

            let pageRect = page.bounds(for: .mediaBox)
            let format = UIGraphicsImageRendererFormat()
            format.scale = max(scale, 2)
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)

            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: pageRect.size))
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: pageRect.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
        }
    }

    enum ExportError: Error {
        case pdfPageUnavailable
        case pngEncodingFailed
    }

    private static func fileName(for document: BusinessDocument) -> String {
        let base = [document.number, document.type.title]
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }

    private static func measuredContentHeight(for document: BusinessDocument, in rect: CGRect) -> CGFloat {
        let lineCount = max(document.lines.count, 1)
        let notesHeight = measuredTextHeight(document.notes.isEmpty ? "-" : document.notes, width: 280, font: UIFont.systemFont(ofSize: 10.5), minimum: 34)
        let paymentHeight = measuredTextHeight(document.paymentDetails.isEmpty ? "-" : document.paymentDetails, width: 280, font: UIFont.systemFont(ofSize: 10.5), minimum: 28)
        let memoText = document.documentMemo.isEmpty ? defaultCondition(for: document.type) : document.documentMemo
        let memoHeight = measuredTextHeight(memoText, width: 280, font: UIFont.systemFont(ofSize: 10.5), minimum: 34)
        let summaryHeight = max(178, 22 + notesHeight + 30 + paymentHeight + 38 + memoHeight)
        let tableStartY = rect.minY + 424
        return tableStartY + 26 + CGFloat(lineCount) * 40 + 20 + summaryHeight + pageInset
    }

    private static func measuredTextHeight(_ text: String, width: CGFloat, font: UIFont, minimum: CGFloat) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return max(minimum, ceil(rect.height) + 4)
    }

    private static func draw(_ document: BusinessDocument, in rect: CGRect) {
        let template = document.colorTemplate
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: UIColor.black,
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.black,
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10.5),
            .foregroundColor: UIColor.black,
        ]
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10.5, weight: .bold),
            .foregroundColor: UIColor.black,
        ]
        let smallBoldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.black,
        ]
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium),
            .foregroundColor: UIColor.black,
        ]

        var y = rect.minY
        if let logoData = document.issuerLogoData,
           let logoImage = UIImage(data: logoData) {
            let logoScale = CGFloat(min(max(document.issuerLogoScale ?? 1.0, 0.5), 1.8))
            let logoRect = CGRect(x: rect.minX, y: y, width: 92 * logoScale, height: 38 * logoScale)
            drawImage(logoImage, in: logoRect)
            drawGradientBar(CGRect(x: logoRect.maxX + 20, y: y + 14, width: 250, height: 8), color: template.accent)
            y += max(38 * logoScale, 38) + 20
        }

        drawText(document.type.title, at: CGPoint(x: rect.minX, y: y), width: 240, height: 30, attributes: titleAttributes)
        drawText(document.type.subtitle, at: CGPoint(x: rect.minX, y: y + 31), width: 240, height: 18, attributes: subtitleAttributes)
        drawText(openingSentence(for: document.type), at: CGPoint(x: rect.minX, y: y + 52), width: 280, height: 18, attributes: bodyAttributes)

        let metaX = rect.maxX - 172
        let metaValueX = rect.maxX - 82
        [
            ("番号", document.number),
            ("発行日", pdfDate(document.issueDate)),
            ("取引年月日", pdfDate(document.transactionDate)),
            ("支払期限", pdfDate(document.dueDate)),
            ("関連番号", document.relatedNumber.isEmpty ? "関連番号なし" : document.relatedNumber),
        ].enumerated().forEach { index, item in
            let rowY = y + CGFloat(index * 16)
            drawText(item.0, at: CGPoint(x: metaX, y: rowY), width: 72, height: 15, attributes: bodyAttributes)
            drawRightText(item.1.isEmpty ? "-" : item.1, in: CGRect(x: metaValueX, y: rowY, width: 82, height: 15), attributes: bodyAttributes)
        }

        y += 88
        drawLine(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.maxX, y: y), color: template.accent, lineWidth: 1.6)
        y += 34

        let customerName = document.customerName.isEmpty ? "取引先名" : document.customerName
        drawText("\(customerName) \(document.honorific)", at: CGPoint(x: rect.minX, y: y), width: 250, height: 22, attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        drawLine(from: CGPoint(x: rect.minX, y: y + 24), to: CGPoint(x: rect.minX + 78, y: y + 24), color: template.accent, lineWidth: 0.8)
        drawText(document.customerAddress, at: CGPoint(x: rect.minX, y: y + 38), width: 230, height: 42, attributes: bodyAttributes)
        drawText(document.customerContact, at: CGPoint(x: rect.minX, y: y + 84), width: 230, height: 18, attributes: bodyAttributes)

        let issuerX = rect.maxX - 220
        if !document.issuerRegistration.isEmpty {
            let badge = CGRect(x: issuerX, y: y, width: 74, height: 20)
            UIColor(red: 0.925, green: 0.985, blue: 0.980, alpha: 1).setFill()
            UIBezierPath(rect: badge).fill()
            template.softLine.setStroke()
            UIBezierPath(rect: badge).stroke()
            drawText("適格請求書対応", at: CGPoint(x: badge.minX + 6, y: badge.minY + 4), width: 64, height: 12, attributes: smallBoldAttributes)
            drawText("登録番号: \(document.issuerRegistration)", at: CGPoint(x: issuerX, y: y + 28), width: 210, height: 16, attributes: bodyAttributes)
        }
        drawText(document.issuerName.isEmpty ? "自社名" : document.issuerName, at: CGPoint(x: issuerX, y: y + 58), width: 220, height: 18, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        drawMultiline(document.issuerAddress, in: CGRect(x: issuerX, y: y + 78, width: 220, height: 36), attributes: bodyAttributes)
        drawText([document.issuerContact, document.issuerPhone, document.issuerEmail].filter { !$0.isEmpty }.joined(separator: " / "), at: CGPoint(x: issuerX, y: y + 122), width: 220, height: 18, attributes: bodyAttributes)

        y += 170
        let amountBox = CGRect(x: rect.minX, y: y, width: rect.width, height: 82)
        drawFilledBox(amountBox, fill: template.totalBackground, stroke: template.accent)
        drawLine(from: CGPoint(x: amountBox.minX, y: amountBox.midY), to: CGPoint(x: amountBox.maxX, y: amountBox.midY), color: template.accent, lineWidth: 0.8)
        drawText(document.type.totalLabel, at: CGPoint(x: amountBox.minX + 10, y: amountBox.minY + 16), width: 160, height: 16, attributes: boldAttributes)
        drawRightText(AppFormatters.yen(document.total), in: CGRect(x: amountBox.maxX - 150, y: amountBox.minY + 12, width: 140, height: 24), attributes: totalAttributes)
        drawText("振込先 / 支払期限", at: CGPoint(x: amountBox.minX + 10, y: amountBox.minY + 56), width: 160, height: 16, attributes: boldAttributes)
        drawRightText(document.paymentDetails.isEmpty ? "-" : document.paymentDetails, in: CGRect(x: amountBox.maxX - 220, y: amountBox.minY + 48, width: 210, height: 16), attributes: bodyAttributes)
        drawRightText("支払期限: \(pdfDate(document.dueDate))", in: CGRect(x: amountBox.maxX - 220, y: amountBox.minY + 64, width: 210, height: 16), attributes: bodyAttributes)

        y += 106
        let widths: [CGFloat] = [150, 145, 50, 76, 90]
        let headers = ["品目", "型番 / 仕様", "数量", "単価", "金額"]
        drawTableHeader(headers, y: y, x: rect.minX, widths: widths, attributes: boldAttributes, fill: template.tableHead)
        y += 26
        for line in document.lines {
            drawInvoiceTableRow([
                line.name.isEmpty ? "-" : line.name,
                [line.model, line.specification].filter { !$0.isEmpty }.joined(separator: " / "),
                String(format: "%.2g", line.quantity),
                AppFormatters.yen(line.unitPrice),
                AppFormatters.yen(line.amount),
            ], y: y, x: rect.minX, widths: widths, attributes: bodyAttributes, stroke: template.softLine)
            y += 40
        }

        y += 20
        let memoX = rect.minX
        drawText("備考", at: CGPoint(x: memoX, y: y), width: 160, height: 18, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        let notesHeight = measuredTextHeight(document.notes.isEmpty ? "-" : document.notes, width: 280, font: UIFont.systemFont(ofSize: 10.5), minimum: 34)
        drawMultiline(document.notes.isEmpty ? "-" : document.notes, in: CGRect(x: memoX, y: y + 22, width: 280, height: notesHeight), attributes: bodyAttributes)
        let paymentY = y + 32 + notesHeight
        drawText("振込先", at: CGPoint(x: memoX, y: paymentY), width: 160, height: 18, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        let paymentHeight = measuredTextHeight(document.paymentDetails.isEmpty ? "-" : document.paymentDetails, width: 280, font: UIFont.systemFont(ofSize: 10.5), minimum: 28)
        drawMultiline(document.paymentDetails.isEmpty ? "-" : document.paymentDetails, in: CGRect(x: memoX, y: paymentY + 22, width: 280, height: paymentHeight), attributes: bodyAttributes)
        let memoY = paymentY + 32 + paymentHeight
        drawText(document.type == .invoice ? "請求条件" : "条件", at: CGPoint(x: memoX, y: memoY), width: 160, height: 18, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        let memoText = document.documentMemo.isEmpty ? defaultCondition(for: document.type) : document.documentMemo
        let memoHeight = measuredTextHeight(memoText, width: 280, font: UIFont.systemFont(ofSize: 10.5), minimum: 34)
        drawMultiline(memoText, in: CGRect(x: memoX, y: memoY + 22, width: 280, height: memoHeight), attributes: bodyAttributes)

        let totalX = rect.maxX - 190
        drawTotalLine("小計", AppFormatters.yen(document.subtotal), x: totalX, y: y, width: 190, attributes: bodyAttributes)
        drawTotalLine("\(String(format: "%.0f", document.taxRate))%対象", AppFormatters.yen(document.subtotal), x: totalX, y: y + 22, width: 190, attributes: bodyAttributes)
        drawTotalLine("消費税 \(String(format: "%.0f", document.taxRate))%", AppFormatters.yen(document.tax), x: totalX, y: y + 44, width: 190, attributes: bodyAttributes)
        drawLine(from: CGPoint(x: totalX, y: y + 68), to: CGPoint(x: totalX + 190, y: y + 68), color: template.accent, lineWidth: 1.6)
        drawText("合計", at: CGPoint(x: totalX, y: y + 84), width: 70, height: 24, attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        drawRightText(AppFormatters.yen(document.total), in: CGRect(x: totalX + 72, y: y + 80, width: 118, height: 30), attributes: totalAttributes)
    }

    private static func drawPageNumber(pageIndex: Int, pageCount: Int, in bounds: CGRect) {
        guard pageCount > 1 else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.black,
        ]
        let text = "\(pageIndex + 1)/\(pageCount)"
        let rect = CGRect(x: 0, y: bounds.maxY - 28, width: bounds.width, height: 12)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var merged = attributes
        merged[.paragraphStyle] = paragraph
        (text as NSString).draw(in: rect, withAttributes: merged)
    }

    private static func drawText(_ text: String, at point: CGPoint, width: CGFloat, height: CGFloat = 44, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(in: CGRect(x: point.x, y: point.y, width: width, height: height), withAttributes: attributes)
    }

    private static func drawRightText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        var merged = attributes
        merged[.paragraphStyle] = paragraph
        (text as NSString).draw(in: rect, withAttributes: merged)
    }

    private static func drawMultiline(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private static func drawLine(from start: CGPoint, to end: CGPoint, color: UIColor = UIColor.black.withAlphaComponent(0.28), lineWidth: CGFloat = 1) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        color.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func drawFilledBox(_ rect: CGRect, fill: UIColor, stroke: UIColor) {
        fill.setFill()
        UIBezierPath(rect: rect).fill()
        stroke.setStroke()
        let path = UIBezierPath(rect: rect)
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawTableRule(from origin: CGPoint, width: CGFloat, color: UIColor, lineWidth: CGFloat) {
        drawLine(from: origin, to: CGPoint(x: origin.x + width, y: origin.y), color: color, lineWidth: lineWidth)
    }

    private static func drawTableHeader(_ values: [String], y: CGFloat, x: CGFloat, widths: [CGFloat], attributes: [NSAttributedString.Key: Any], fill: UIColor) {
        var currentX = x
        for (index, value) in values.enumerated() {
            let cell = CGRect(x: currentX, y: y, width: widths[index], height: 26)
            fill.setFill()
            UIBezierPath(rect: cell).fill()
            (value as NSString).draw(in: cell.insetBy(dx: 6, dy: 7), withAttributes: attributes)
            currentX += widths[index]
        }
    }

    private static func drawInvoiceTableRow(_ values: [String], y: CGFloat, x: CGFloat, widths: [CGFloat], attributes: [NSAttributedString.Key: Any], stroke: UIColor) {
        var currentX = x
        for (index, value) in values.enumerated() {
            let cell = CGRect(x: currentX, y: y, width: widths[index], height: 40)
            let textRect = cell.insetBy(dx: 6, dy: 9)
            if index >= 2 {
                drawRightText(value.isEmpty ? "-" : value, in: textRect, attributes: attributes)
            } else {
                drawMultiline(value.isEmpty ? "-" : value, in: textRect, attributes: attributes)
            }
            currentX += widths[index]
        }
        drawLine(from: CGPoint(x: x, y: y + 40), to: CGPoint(x: x + widths.reduce(0, +), y: y + 40), color: stroke, lineWidth: 0.8)
    }

    private static func drawTotalLine(_ label: String, _ value: String, x: CGFloat, y: CGFloat, width: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        drawText(label, at: CGPoint(x: x, y: y), width: width * 0.45, height: 16, attributes: attributes)
        drawRightText(value, in: CGRect(x: x + width * 0.45, y: y, width: width * 0.55, height: 16), attributes: attributes)
    }

    private static func drawImage(_ image: UIImage, in rect: CGRect) {
        let fitted = aspectFitRect(imageSize: image.size, in: rect)
        image.draw(in: fitted)
    }

    private static func aspectFitRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: rect.minX,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func drawGradientBar(_ rect: CGRect, color: UIColor) {
        guard let context = UIGraphicsGetCurrentContext(),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                  color.cgColor,
                  color.withAlphaComponent(0).cgColor,
              ] as CFArray, locations: [0, 1]) else { return }
        context.saveGState()
        context.addRect(rect)
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.midY), end: CGPoint(x: rect.maxX, y: rect.midY), options: [])
        context.restoreGState()
    }

    private static func pdfDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private static func openingSentence(for type: DocumentType) -> String {
        switch type {
        case .invoice:
            return "下記の通り、ご請求申し上げます。"
        case .estimate:
            return "下記の通り、お見積り申し上げます。"
        case .delivery:
            return "下記の通り、納品いたします。"
        case .receipt:
            return "下記の金額を領収いたしました。"
        case .acceptance:
            return "下記の通り、受領いたしました。"
        case .purchaseOrder:
            return "下記の通り、発注いたします。"
        case .customerOrder:
            return "下記の通り、客先注文内容を記録します。"
        case .customerFiles:
            return "下記の通り、顧客書類を管理します。"
        }
    }

    private static func defaultCondition(for type: DocumentType) -> String {
        switch type {
        case .invoice:
            return "振込先、支払期限、請求条件を確認してください。"
        case .estimate:
            return "見積条件、納入予定、税率・合計金額を確認してください。"
        default:
            return "内容、期限、条件を確認してください。"
        }
    }
}
