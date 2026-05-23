import Foundation
import PDFKit
import UIKit

enum DocumentPDFExporter {
    private static let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private static let pageInset: CGFloat = 42
    private static let fontScale: CGFloat = 0.9

    static func export(_ document: BusinessDocument, language: AppLanguage = .japanese) throws -> URL {
        let bounds = pageBounds
        let contentRect = bounds.insetBy(dx: pageInset, dy: pageInset)
        let contentHeight = measuredContentHeight(for: document, in: contentRect, language: language)
        let pageCount = min(2, max(1, Int(ceil(contentHeight / bounds.height))))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: document))
            .appendingPathExtension("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        try renderer.writePDF(to: url) { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                UIColor.white.setFill()
                UIBezierPath(rect: bounds).fill()
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.clip(to: bounds)
                cgContext.translateBy(x: 0, y: -bounds.height * CGFloat(pageIndex))
                draw(document, in: contentRect, language: language)
                cgContext.restoreGState()
                drawPageNumber(pageIndex: pageIndex, pageCount: pageCount, in: bounds)
            }
        }

        return url
    }

    static func previewImage(for document: BusinessDocument, language: AppLanguage = .japanese, scale: CGFloat = UIScreen.main.scale) throws -> UIImage {
        guard let image = try previewImages(for: document, language: language, scale: scale).first else {
            throw ExportError.pdfPageUnavailable
        }
        return image
    }

    static func previewImages(for document: BusinessDocument, language: AppLanguage = .japanese, scale: CGFloat = UIScreen.main.scale) throws -> [UIImage] {
        let pdfURL = try export(document, language: language)
        return try renderPageImages(from: pdfURL, scale: scale)
    }

    static func exportPreviewPNG(_ document: BusinessDocument, language: AppLanguage = .japanese, scale: CGFloat = UIScreen.main.scale) throws -> URL {
        let image = try previewImage(for: document, language: language, scale: scale)
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

    private static func measuredContentHeight(for document: BusinessDocument, in rect: CGRect, language: AppLanguage) -> CGFloat {
        let lineCount = max(document.lines.count, 1)
        let notesHeight = measuredTextHeight(document.notes.isEmpty ? "-" : document.notes, width: 280, font: pdfFont(10.5), minimum: 30)
        let paymentHeight = measuredTextHeight(document.paymentDetails.isEmpty ? "-" : document.paymentDetails, width: 280, font: pdfFont(10.5), minimum: 24)
        let memoText = document.documentMemo.isEmpty ? defaultCondition(for: document.type, language: language) : document.documentMemo
        let memoHeight = measuredTextHeight(memoText, width: 280, font: pdfFont(10.5), minimum: 30)
        let paymentProofHeight = document.type.isVendorForm
            ? 32 + measuredTextHeight(paymentProofText(for: document, language: language), width: 280, font: pdfFont(10.5), minimum: 24)
            : 0
        let summaryHeight = max(170, 82 + notesHeight + paymentHeight + memoHeight + paymentProofHeight)
        let tableStartY = rect.minY + 84 + 17 + companyInfoHeight(for: document) + 14 + 64 + 18
        return tableStartY + 23 + CGFloat(lineCount) * 34 + 10 + summaryHeight + pageInset
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

    private static func measuredOptionalTextHeight(_ text: String, width: CGFloat, font: UIFont, minimum: CGFloat) -> CGFloat {
        text.isEmpty ? 0 : measuredTextHeight(text, width: width, font: font, minimum: minimum)
    }

    private static func companyInfoHeight(for document: BusinessDocument) -> CGFloat {
        let bodyFont = pdfFont(10.5)
        let customerLines = companyContactLines(
            contact: document.customerContact,
            phone: document.customerPhone ?? "",
            email: document.customerEmail ?? ""
        ).joined(separator: "\n")
        let customerAddressHeight = measuredOptionalTextHeight(document.customerAddress, width: 230, font: bodyFont, minimum: 28)
        let customerContactHeight = measuredOptionalTextHeight(customerLines, width: 230, font: bodyFont, minimum: 12)
        let customerBottom = max(26, 32 + customerAddressHeight + (customerContactHeight > 0 ? 4 + customerContactHeight : 0))

        let issuerLines = companyContactLines(
            contact: document.issuerContact,
            phone: document.issuerPhone,
            email: document.issuerEmail
        ).joined(separator: "\n")
        let issuerNameY: CGFloat = document.issuerRegistration.isEmpty ? 0 : 38
        let issuerAddressHeight = measuredOptionalTextHeight(document.issuerAddress, width: 220, font: bodyFont, minimum: 28)
        let issuerContactHeight = measuredOptionalTextHeight(issuerLines, width: 220, font: bodyFont, minimum: 12)
        let issuerBottom = max(
            document.issuerRegistration.isEmpty ? 18 : 40,
            issuerNameY + 18 + issuerAddressHeight + (issuerContactHeight > 0 ? 4 + issuerContactHeight : 0)
        )

        return max(customerBottom, issuerBottom)
    }

    private static func draw(_ document: BusinessDocument, in rect: CGRect, language: AppLanguage) {
        let template = document.colorTemplate
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: pdfFont(18, weight: .medium),
            .foregroundColor: UIColor.black,
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: pdfFont(12, weight: .regular),
            .foregroundColor: UIColor.black,
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: pdfFont(10.5),
            .foregroundColor: UIColor.black,
        ]
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: pdfFont(10.5, weight: .bold),
            .foregroundColor: UIColor.black,
        ]
        let smallBoldAttributes: [NSAttributedString.Key: Any] = [
            .font: pdfFont(9, weight: .bold),
            .foregroundColor: UIColor.black,
        ]
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 18 * fontScale, weight: .medium),
            .foregroundColor: UIColor.black,
        ]

        var y = rect.minY
        drawText(document.type.localizedTitle(language), at: CGPoint(x: rect.minX, y: y), width: 240, height: 30, attributes: titleAttributes)
        drawText(document.type.localizedSubtitle(language), at: CGPoint(x: rect.minX, y: y + 31), width: 240, height: 18, attributes: subtitleAttributes)
        drawText(openingSentence(for: document.type, language: language), at: CGPoint(x: rect.minX, y: y + 52), width: 280, height: 18, attributes: bodyAttributes)

        let metaX = rect.maxX - 214
        let metaValueX = rect.maxX - 150
        let metaValueWidth: CGFloat = 150
        [
            (pdfLabel(.number, language), document.number),
            (pdfLabel(.issueDate, language), pdfDate(document.issueDate, language: language)),
            (pdfLabel(.transactionDate, language), pdfDate(document.transactionDate, language: language)),
            (pdfLabel(.dueDate, language), pdfDate(document.dueDate, language: language)),
            (pdfLabel(.relatedNumber, language), document.relatedNumber.isEmpty ? pdfLabel(.noRelatedNumber, language) : document.relatedNumber),
        ].enumerated().forEach { index, item in
            let rowY = y + CGFloat(index * 16)
            drawText(item.0, at: CGPoint(x: metaX, y: rowY), width: 60, height: 15, attributes: bodyAttributes)
            let valueRect = CGRect(x: metaValueX, y: rowY, width: metaValueWidth, height: 15)
            if index == 0 {
                drawRightTextToFit(item.1.isEmpty ? "-" : item.1, in: valueRect, attributes: bodyAttributes, minimumScale: 0.72)
            } else {
                drawRightText(item.1.isEmpty ? "-" : item.1, in: valueRect, attributes: bodyAttributes)
            }
        }

        y += 84
        drawLine(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.maxX, y: y), color: template.accent, lineWidth: 1.6)
        y += 17

        let customerName = document.customerName.isEmpty ? pdfLabel(.customerName, language) : document.customerName
        drawText("\(customerName) \(document.honorific)", at: CGPoint(x: rect.minX, y: y), width: 250, height: 22, attributes: [
            .font: pdfFont(14, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        drawLine(from: CGPoint(x: rect.minX, y: y + 24), to: CGPoint(x: rect.minX + 78, y: y + 24), color: template.accent, lineWidth: 0.8)
        let customerAddressHeight = measuredOptionalTextHeight(document.customerAddress, width: 230, font: pdfFont(10.5), minimum: 28)
        drawMultiline(document.customerAddress, in: CGRect(x: rect.minX, y: y + 32, width: 230, height: customerAddressHeight), attributes: bodyAttributes)
        let customerLines = companyContactLines(
            contact: document.customerContact,
            phone: document.customerPhone ?? "",
            email: document.customerEmail ?? ""
        )
        let customerContactText = customerLines.joined(separator: "\n")
        let customerContactHeight = measuredOptionalTextHeight(customerContactText, width: 230, font: pdfFont(10.5), minimum: 12)
        let customerContactY = y + 32 + customerAddressHeight + (customerContactHeight > 0 ? 4 : 0)
        drawMultiline(customerContactText, in: CGRect(x: rect.minX, y: customerContactY, width: 230, height: customerContactHeight), attributes: bodyAttributes)
        let customerBottom = max(y + 26, customerContactY + customerContactHeight)

        let issuerX = rect.maxX - 220
        let issuerNameY = document.issuerRegistration.isEmpty ? y : y + 38
        if !document.issuerRegistration.isEmpty {
            let badge = CGRect(x: issuerX, y: y, width: 74, height: 20)
            UIColor(red: 0.925, green: 0.985, blue: 0.980, alpha: 1).setFill()
            UIBezierPath(rect: badge).fill()
            template.softLine.setStroke()
            UIBezierPath(rect: badge).stroke()
            drawText(pdfLabel(.qualifiedInvoice, language), at: CGPoint(x: badge.minX + 6, y: badge.minY + 4), width: 64, height: 12, attributes: smallBoldAttributes)
            drawText("\(pdfLabel(.registrationNumber, language)): \(document.issuerRegistration)", at: CGPoint(x: issuerX, y: y + 24), width: 210, height: 16, attributes: bodyAttributes)
        }
        drawText(document.issuerName.isEmpty ? pdfLabel(.issuerName, language) : document.issuerName, at: CGPoint(x: issuerX, y: issuerNameY), width: 220, height: 18, attributes: [
            .font: pdfFont(12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        let issuerAddressHeight = measuredOptionalTextHeight(document.issuerAddress, width: 220, font: pdfFont(10.5), minimum: 28)
        drawMultiline(document.issuerAddress, in: CGRect(x: issuerX, y: issuerNameY + 18, width: 220, height: issuerAddressHeight), attributes: bodyAttributes)
        let issuerLines = companyContactLines(
            contact: document.issuerContact,
            phone: document.issuerPhone,
            email: document.issuerEmail
        )
        let issuerContactText = issuerLines.joined(separator: "\n")
        let issuerContactHeight = measuredOptionalTextHeight(issuerContactText, width: 220, font: pdfFont(10.5), minimum: 12)
        let issuerContactY = issuerNameY + 18 + issuerAddressHeight + (issuerContactHeight > 0 ? 4 : 0)
        drawMultiline(issuerContactText, in: CGRect(x: issuerX, y: issuerContactY, width: 220, height: issuerContactHeight), attributes: bodyAttributes)
        let issuerBottom = max(document.issuerRegistration.isEmpty ? issuerNameY + 18 : y + 40, issuerContactY + issuerContactHeight)

        y = max(customerBottom, issuerBottom) + 14
        let amountBox = CGRect(x: rect.minX, y: y, width: rect.width, height: 64)
        drawFilledBox(amountBox, fill: template.totalBackground, stroke: template.accent)
        drawLine(from: CGPoint(x: amountBox.minX, y: amountBox.midY), to: CGPoint(x: amountBox.maxX, y: amountBox.midY), color: template.accent, lineWidth: 0.8)
        drawText(document.type.localizedTotalLabel(language), at: CGPoint(x: amountBox.minX + 10, y: amountBox.minY + 7), width: 160, height: 13, attributes: boldAttributes)
        drawRightText(AppFormatters.yen(document.total, language: language), in: CGRect(x: amountBox.maxX - 150, y: amountBox.minY + 5, width: 140, height: 22), attributes: totalAttributes)
        drawText(pdfLabel(.paymentAndDueDate, language), at: CGPoint(x: amountBox.minX + 10, y: amountBox.minY + 42), width: 160, height: 13, attributes: boldAttributes)
        drawRightTextToFit(
            singleLinePaymentText(document.paymentDetails),
            in: CGRect(x: amountBox.minX + 176, y: amountBox.minY + 34, width: amountBox.width - 186, height: 12),
            attributes: bodyAttributes,
            minimumScale: 0.58
        )
        drawRightText("\(pdfLabel(.dueDate, language)): \(pdfDate(document.dueDate, language: language))", in: CGRect(x: amountBox.maxX - 220, y: amountBox.minY + 48, width: 210, height: 12), attributes: bodyAttributes)

        y = amountBox.maxY + 18
        let widths: [CGFloat] = [150, 145, 50, 76, 90]
        let headers = [pdfLabel(.item, language), pdfLabel(.modelSpec, language), pdfLabel(.quantity, language), pdfLabel(.unitPrice, language), pdfLabel(.amount, language)]
        drawTableHeader(headers, y: y, x: rect.minX, widths: widths, attributes: boldAttributes, fill: template.tableHead)
        y += 23
        for line in document.lines {
            drawInvoiceTableRow([
                line.name.isEmpty ? "-" : line.name,
                [line.model, line.specification].filter { !$0.isEmpty }.joined(separator: " / "),
                quantityText(line.quantity),
                AppFormatters.yen(line.unitPrice, language: language),
                AppFormatters.yen(line.amount, language: language),
            ], y: y, x: rect.minX, widths: widths, attributes: bodyAttributes, stroke: template.softLine)
            y += 34
        }

        y += 10
        let memoX = rect.minX
        drawText(pdfLabel(.notes, language), at: CGPoint(x: memoX, y: y), width: 160, height: 18, attributes: [
            .font: pdfFont(12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        let notesHeight = measuredTextHeight(document.notes.isEmpty ? "-" : document.notes, width: 280, font: pdfFont(10.5), minimum: 30)
        drawMultiline(document.notes.isEmpty ? "-" : document.notes, in: CGRect(x: memoX, y: y + 18, width: 280, height: notesHeight), attributes: bodyAttributes)
        let paymentY = y + 18 + notesHeight + 14
        drawText(pdfLabel(.paymentDetails, language), at: CGPoint(x: memoX, y: paymentY), width: 160, height: 18, attributes: [
            .font: pdfFont(12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        let paymentHeight = measuredTextHeight(document.paymentDetails.isEmpty ? "-" : document.paymentDetails, width: 280, font: pdfFont(10.5), minimum: 24)
        drawMultiline(document.paymentDetails.isEmpty ? "-" : document.paymentDetails, in: CGRect(x: memoX, y: paymentY + 18, width: 280, height: paymentHeight), attributes: bodyAttributes)
        let memoY = paymentY + 18 + paymentHeight + 14
        drawText(document.type == .invoice ? pdfLabel(.invoiceTerms, language) : pdfLabel(.terms, language), at: CGPoint(x: memoX, y: memoY), width: 160, height: 18, attributes: [
            .font: pdfFont(12, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        let memoText = document.documentMemo.isEmpty ? defaultCondition(for: document.type, language: language) : document.documentMemo
        let memoHeight = measuredTextHeight(memoText, width: 280, font: pdfFont(10.5), minimum: 30)
        drawMultiline(memoText, in: CGRect(x: memoX, y: memoY + 18, width: 280, height: memoHeight), attributes: bodyAttributes)

        if document.type.isVendorForm {
            let proofY = memoY + 18 + memoHeight + 14
            drawText(pdfLabel(.paymentProof, language), at: CGPoint(x: memoX, y: proofY), width: 160, height: 18, attributes: [
                .font: pdfFont(12, weight: .medium),
                .foregroundColor: UIColor.black,
            ])
            let proofText = paymentProofText(for: document, language: language)
            let proofHeight = measuredTextHeight(proofText, width: 280, font: pdfFont(10.5), minimum: 24)
            drawMultiline(proofText, in: CGRect(x: memoX, y: proofY + 18, width: 280, height: proofHeight), attributes: bodyAttributes)
        }

        let totalX = rect.maxX - 190
        drawTotalLine(pdfLabel(.subtotal, language), AppFormatters.yen(document.subtotal, language: language), x: totalX, y: y, width: 190, attributes: bodyAttributes)
        drawTotalLine("\(pdfLabel(.tax, language)) \(String(format: "%.0f", document.taxRate))%", AppFormatters.yen(document.tax, language: language), x: totalX, y: y + 18, width: 190, attributes: bodyAttributes)
        drawLine(from: CGPoint(x: totalX, y: y + 38), to: CGPoint(x: totalX + 190, y: y + 38), color: template.accent, lineWidth: 1.6)
        drawText(pdfLabel(.total, language), at: CGPoint(x: totalX, y: y + 52), width: 70, height: 22, attributes: [
            .font: pdfFont(16, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        drawRightText(AppFormatters.yen(document.total, language: language), in: CGRect(x: totalX + 72, y: y + 49, width: 118, height: 27), attributes: totalAttributes)
    }

    private static func quantityText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func pdfFont(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size * fontScale, weight: weight)
    }

    private static func companyContactLines(contact: String, phone: String, email: String) -> [String] {
        [
            contact,
            phone.isEmpty ? "" : "TEL: \(phone)",
            email.isEmpty ? "" : "Email: \(email)",
        ].filter { !$0.isEmpty }
    }

    private static func singleLinePaymentText(_ text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? "-" : lines.joined(separator: "  ")
    }

    private static func paymentProofText(for document: BusinessDocument, language: AppLanguage) -> String {
        var lines: [String] = []
        if let paymentProofDate = document.paymentProofDate {
            lines.append("\(pdfLabel(.paymentProofDate, language)): \(pdfDateTime(paymentProofDate, language: language))")
        }
        if let paymentProofAmount = document.paymentProofAmount {
            lines.append("\(pdfLabel(.paymentProofAmount, language)): \(AppFormatters.yen(paymentProofAmount, language: language))")
        }
        let attachments = document.paymentProofAttachments ?? []
        if !attachments.isEmpty {
            let filenames = attachments.map(\.filename).filter { !$0.isEmpty }.joined(separator: ", ")
            lines.append("\(pdfLabel(.paymentProofFiles, language)): \(filenames.isEmpty ? "\(attachments.count)" : filenames)")
        }
        return lines.isEmpty ? "-" : lines.joined(separator: "\n")
    }

    private static func drawPageNumber(pageIndex: Int, pageCount: Int, in bounds: CGRect) {
        guard pageCount > 1 else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: pdfFont(9, weight: .semibold),
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

    private static func drawRightTextToFit(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any], minimumScale: CGFloat) {
        guard let font = attributes[.font] as? UIFont else {
            drawRightText(text, in: rect, attributes: attributes)
            return
        }

        let measuredWidth = (text as NSString).size(withAttributes: attributes).width
        let scale = measuredWidth > rect.width ? max(minimumScale, rect.width / measuredWidth) : 1
        let scaledFont = font.withSize(font.pointSize * scale)
        var scaledAttributes = attributes
        scaledAttributes[.font] = scaledFont
        drawRightText(text, in: rect, attributes: scaledAttributes)
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
            let cell = CGRect(x: currentX, y: y, width: widths[index], height: 23)
            fill.setFill()
            UIBezierPath(rect: cell).fill()
            (value as NSString).draw(in: cell.insetBy(dx: 6, dy: 6), withAttributes: attributes)
            currentX += widths[index]
        }
    }

    private static func drawInvoiceTableRow(_ values: [String], y: CGFloat, x: CGFloat, widths: [CGFloat], attributes: [NSAttributedString.Key: Any], stroke: UIColor) {
        var currentX = x
        for (index, value) in values.enumerated() {
            let cell = CGRect(x: currentX, y: y, width: widths[index], height: 34)
            let textRect = cell.insetBy(dx: 6, dy: 7)
            if index >= 2 {
                drawRightText(value.isEmpty ? "-" : value, in: textRect, attributes: attributes)
            } else {
                drawMultiline(value.isEmpty ? "-" : value, in: textRect, attributes: attributes)
            }
            currentX += widths[index]
        }
        drawLine(from: CGPoint(x: x, y: y + 34), to: CGPoint(x: x + widths.reduce(0, +), y: y + 34), color: stroke, lineWidth: 0.8)
    }

    private static func drawTotalLine(_ label: String, _ value: String, x: CGFloat, y: CGFloat, width: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        drawText(label, at: CGPoint(x: x, y: y), width: width * 0.45, height: 16, attributes: attributes)
        drawRightText(value, in: CGRect(x: x + width * 0.45, y: y, width: width * 0.55, height: 16), attributes: attributes)
    }

    private static func pdfDate(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        switch language {
        case .japanese:
            formatter.dateFormat = "yyyy/MM/dd"
        case .simplifiedChinese:
            formatter.dateFormat = "yyyy年M月d日"
        case .english:
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }

    private static func pdfDateTime(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func openingSentence(for type: DocumentType, language: AppLanguage) -> String {
        switch (type, language) {
        case (.invoice, .japanese): return "下記の通り、ご請求申し上げます。"
        case (.invoice, .simplifiedChinese): return "现按以下内容向贵司请款。"
        case (.invoice, .english): return "Please find the invoice details below."
        case (.estimate, .japanese): return "下記の通り、お見積り申し上げます。"
        case (.estimate, .simplifiedChinese): return "现按以下内容报价。"
        case (.estimate, .english): return "Please find the quote details below."
        case (.delivery, .japanese): return "下記の通り、納品いたします。"
        case (.delivery, .simplifiedChinese): return "现按以下内容送货。"
        case (.delivery, .english): return "The following items are delivered."
        case (.receipt, .japanese): return "下記の金額を領収いたしました。"
        case (.receipt, .simplifiedChinese): return "已收到以下款项。"
        case (.receipt, .english): return "Payment has been received as detailed below."
        case (.acceptance, .japanese): return "下記の通り、受領いたしました。"
        case (.acceptance, .simplifiedChinese): return "已按以下内容收货。"
        case (.acceptance, .english): return "The following items have been accepted."
        case (.purchaseOrder, .japanese): return "下記の通り、発注いたします。"
        case (.purchaseOrder, .simplifiedChinese): return "现按以下内容下单采购。"
        case (.purchaseOrder, .english): return "Please process the purchase order below."
        case (.customerOrder, .japanese): return "下記の通り、客先注文内容を記録します。"
        case (.customerOrder, .simplifiedChinese): return "客户订单内容记录如下。"
        case (.customerOrder, .english): return "Customer order details are recorded below."
        case (.customerFiles, .japanese): return "下記の通り、顧客書類を管理します。"
        case (.customerFiles, .simplifiedChinese): return "客户文件管理内容如下。"
        case (.customerFiles, .english): return "Project document details are listed below."
        case (.vendorEstimate, .japanese): return "下記の通り、仕入先見積内容を記録します。"
        case (.vendorEstimate, .simplifiedChinese): return "厂商报价内容记录如下。"
        case (.vendorEstimate, .english): return "Vendor quotation details are recorded below."
        case (.vendorReceipt, .japanese): return "下記の通り、仕入先領収書内容を記録します。"
        case (.vendorReceipt, .simplifiedChinese): return "厂商收据内容记录如下。"
        case (.vendorReceipt, .english): return "Vendor receipt details are recorded below."
        case (.paymentNotice, .japanese): return "下記の通り、支払通知内容を記録します。"
        case (.paymentNotice, .simplifiedChinese): return "支付告知通知内容记录如下。"
        case (.paymentNotice, .english): return "Payment notice details are recorded below."
        }
    }

    private static func defaultCondition(for type: DocumentType, language: AppLanguage) -> String {
        switch (type, language) {
        case (.invoice, .japanese): return "振込先、支払期限、請求条件を確認してください。"
        case (.invoice, .simplifiedChinese): return "请确认收款账户、付款期限和付款条件。"
        case (.invoice, .english): return "Please confirm payment details, due date, and invoice terms."
        case (.estimate, .japanese): return "見積条件、納入予定、税率・合計金額を確認してください。"
        case (.estimate, .simplifiedChinese): return "请确认报价条件、交付计划、税率和合计金额。"
        case (.estimate, .english): return "Please confirm quote terms, delivery schedule, tax rate, and total."
        case (_, .japanese): return "内容、期限、条件を確認してください。"
        case (_, .simplifiedChinese): return "请确认内容、期限和条件。"
        case (_, .english): return "Please confirm the details, deadlines, and terms."
        }
    }

    private static func pdfLabel(_ key: PDFLabel, _ language: AppLanguage) -> String {
        switch (key, language) {
        case (.number, .japanese): return "番号"
        case (.number, .simplifiedChinese): return "编号"
        case (.number, .english): return "No."
        case (.issueDate, .japanese): return "発行日"
        case (.issueDate, .simplifiedChinese): return "开具日期"
        case (.issueDate, .english): return "Issue Date"
        case (.transactionDate, .japanese): return "取引年月日"
        case (.transactionDate, .simplifiedChinese): return "交易日期"
        case (.transactionDate, .english): return "Transaction Date"
        case (.dueDate, .japanese): return "支払期限"
        case (.dueDate, .simplifiedChinese): return "付款期限"
        case (.dueDate, .english): return "Due Date"
        case (.relatedNumber, .japanese): return "関連番号"
        case (.relatedNumber, .simplifiedChinese): return "关联编号"
        case (.relatedNumber, .english): return "Reference No."
        case (.noRelatedNumber, .japanese): return "関連番号なし"
        case (.noRelatedNumber, .simplifiedChinese): return "无关联编号"
        case (.noRelatedNumber, .english): return "No reference"
        case (.customerName, .japanese): return "取引先名"
        case (.customerName, .simplifiedChinese): return "客户名称"
        case (.customerName, .english): return "Customer Name"
        case (.issuerName, .japanese): return "自社名"
        case (.issuerName, .simplifiedChinese): return "本公司名称"
        case (.issuerName, .english): return "Issuer Name"
        case (.qualifiedInvoice, .japanese): return "適格請求書対応"
        case (.qualifiedInvoice, .simplifiedChinese): return "合规发票"
        case (.qualifiedInvoice, .english): return "Qualified Invoice"
        case (.registrationNumber, .japanese): return "登録番号"
        case (.registrationNumber, .simplifiedChinese): return "登记编号"
        case (.registrationNumber, .english): return "Registration No."
        case (.paymentAndDueDate, .japanese): return "振込先 / 支払期限"
        case (.paymentAndDueDate, .simplifiedChinese): return "收款账户 / 付款期限"
        case (.paymentAndDueDate, .english): return "Payment / Due Date"
        case (.item, .japanese): return "品目"
        case (.item, .simplifiedChinese): return "项目"
        case (.item, .english): return "Item"
        case (.modelSpec, .japanese): return "型番 / 仕様"
        case (.modelSpec, .simplifiedChinese): return "型号 / 规格"
        case (.modelSpec, .english): return "Model / Specs"
        case (.quantity, .japanese): return "数量"
        case (.quantity, .simplifiedChinese): return "数量"
        case (.quantity, .english): return "Qty"
        case (.unitPrice, .japanese): return "単価"
        case (.unitPrice, .simplifiedChinese): return "单价"
        case (.unitPrice, .english): return "Unit Price"
        case (.amount, .japanese): return "金額"
        case (.amount, .simplifiedChinese): return "金额"
        case (.amount, .english): return "Amount"
        case (.notes, .japanese): return "備考"
        case (.notes, .simplifiedChinese): return "备注"
        case (.notes, .english): return "Notes"
        case (.paymentDetails, .japanese): return "振込先"
        case (.paymentDetails, .simplifiedChinese): return "收款账户"
        case (.paymentDetails, .english): return "Payment Details"
        case (.paymentProof, .japanese): return "支払証明"
        case (.paymentProof, .simplifiedChinese): return "支付证明"
        case (.paymentProof, .english): return "Payment Proof"
        case (.paymentProofDate, .japanese): return "支払日時"
        case (.paymentProofDate, .simplifiedChinese): return "支付时间"
        case (.paymentProofDate, .english): return "Payment Time"
        case (.paymentProofAmount, .japanese): return "支払金額"
        case (.paymentProofAmount, .simplifiedChinese): return "支付金额"
        case (.paymentProofAmount, .english): return "Payment Amount"
        case (.paymentProofFiles, .japanese): return "添付ファイル"
        case (.paymentProofFiles, .simplifiedChinese): return "附件"
        case (.paymentProofFiles, .english): return "Files"
        case (.invoiceTerms, .japanese): return "請求条件"
        case (.invoiceTerms, .simplifiedChinese): return "付款条件"
        case (.invoiceTerms, .english): return "Invoice Terms"
        case (.terms, .japanese): return "条件"
        case (.terms, .simplifiedChinese): return "条件"
        case (.terms, .english): return "Terms"
        case (.subtotal, .japanese): return "小計"
        case (.subtotal, .simplifiedChinese): return "小计"
        case (.subtotal, .english): return "Subtotal"
        case (.tax, .japanese): return "消費税"
        case (.tax, .simplifiedChinese): return "消费税"
        case (.tax, .english): return "Tax"
        case (.total, .japanese): return "合計"
        case (.total, .simplifiedChinese): return "合计"
        case (.total, .english): return "Total"
        }
    }

    private enum PDFLabel {
        case number, issueDate, transactionDate, dueDate, relatedNumber, noRelatedNumber
        case customerName, issuerName, qualifiedInvoice, registrationNumber, paymentAndDueDate
        case item, modelSpec, quantity, unitPrice, amount
        case notes, paymentDetails, paymentProof, paymentProofDate, paymentProofAmount, paymentProofFiles
        case invoiceTerms, terms, subtotal, tax, total
    }
}
