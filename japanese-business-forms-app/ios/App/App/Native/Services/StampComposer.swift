import UIKit

enum StampComposer {
    struct Placement {
        var pageDisplaySize: CGSize
        var stampDisplaySize: CGSize
        var centerInPage: CGPoint
        var rotation: CGFloat
        var opacity: CGFloat
    }

    static func compose(baseImage: UIImage, stampImage: UIImage, placement: Placement) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        return renderer.image { context in
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))

            let xScale = baseImage.size.width / max(1, placement.pageDisplaySize.width)
            let yScale = baseImage.size.height / max(1, placement.pageDisplaySize.height)
            let targetSize = CGSize(
                width: placement.stampDisplaySize.width * xScale,
                height: placement.stampDisplaySize.height * yScale
            )
            let center = CGPoint(
                x: placement.centerInPage.x * xScale,
                y: placement.centerInPage.y * yScale
            )

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.rotate(by: placement.rotation)
            stampImage.draw(
                in: CGRect(x: -targetSize.width / 2, y: -targetSize.height / 2, width: targetSize.width, height: targetSize.height),
                blendMode: .normal,
                alpha: placement.opacity
            )
            cgContext.restoreGState()
        }
    }

    static func exportPNG(_ image: UIImage) throws -> URL {
        guard let data = image.pngData() else { throw StampComposerError.exportFailed }
        return try write(data: data, extension: "png")
    }

    static func exportJPEG(_ image: UIImage, quality: CGFloat = 0.92) throws -> URL {
        guard let data = image.jpegData(compressionQuality: quality) else { throw StampComposerError.exportFailed }
        return try write(data: data, extension: "jpg")
    }

    static func exportPDF(_ image: UIImage) throws -> URL {
        try exportPDF([image])
    }

    static func exportPDF(_ images: [UIImage]) throws -> URL {
        guard let firstImage = images.first else { throw StampComposerError.exportFailed }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("stamped-preview-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        let bounds = CGRect(origin: .zero, size: firstImage.size)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        try renderer.writePDF(to: url) { context in
            for image in images {
                context.beginPage()
                UIColor.white.setFill()
                context.fill(bounds)
                image.draw(in: fittedRect(imageSize: image.size, pageSize: bounds.size))
            }
        }

        return url
    }

    private static func write(data: Data, extension fileExtension: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("stamped-preview-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func fittedRect(imageSize: CGSize, pageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, pageSize.width > 0, pageSize.height > 0 else {
            return CGRect(origin: .zero, size: pageSize)
        }
        let scale = min(pageSize.width / imageSize.width, pageSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (pageSize.width - size.width) / 2,
            y: (pageSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

enum StampComposerError: Error {
    case exportFailed
}
