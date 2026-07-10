import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceDir = root.appendingPathComponent("app-store-assets/ja-JP/screenshots/ipad-13-real")
let outputDir = root.appendingPathComponent("app-store-assets/ja-JP/screenshots/ipad-13")
let realHandIPadURL = root.appendingPathComponent("app-store-assets/source-assets/lorin-both-hand-ipad-unsplash.jpg")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let width = 2064
let height = 2752

struct Shot {
    let source: String
    let output: String
    let badge: String
    let title: String
    let subtitle: String
    let accent: NSColor
    let cropOffset: CGFloat
}

let shots: [Shot] = [
    Shot(
        source: "01-home-editor-preview.png",
        output: "01-ipad-document-editor-preview.png",
        badge: "iPad対応",
        title: "入力・一覧・PDFを\n広い画面でまとめて確認。",
        subtitle: "請求書や納品書を作成しながら、右側でPDFプレビューまで見渡せます。",
        accent: NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.29, alpha: 1),
        cropOffset: 0
    ),
    Shot(
        source: "02-project-management.png",
        output: "02-ipad-project-management.png",
        badge: "案件管理",
        title: "プロジェクトごとに\n必要な帳票を整理。",
        subtitle: "顧客向け・仕入先向けの書類進捗を一覧で把握できます。",
        accent: NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.88, alpha: 1),
        cropOffset: 0
    ),
    Shot(
        source: "03-pdf-preview.png",
        output: "03-ipad-pdf-preview.png",
        badge: "PDFプレビュー",
        title: "日本の帳票PDFを\n大きく、読みやすく。",
        subtitle: "発行前に金額・税率・明細・宛先をしっかり確認できます。",
        accent: NSColor(calibratedRed: 0.02, green: 0.52, blue: 0.48, alpha: 1),
        cropOffset: 0
    ),
    Shot(
        source: "04-settings.png",
        output: "04-ipad-settings.png",
        badge: "設定とバックアップ",
        title: "言語・配色・バックアップも\nひと目で管理。",
        subtitle: "PDF言語、帳票配色、Google Driveバックアップをわかりやすく設定できます。",
        accent: NSColor(calibratedRed: 0.69, green: 0.22, blue: 0.78, alpha: 1),
        cropOffset: 0
    )
]

func rectFromTop(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(height) - y - h, width: w, height: h)
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: NSFont, color: NSColor, lineSpacing: CGFloat = 6) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    paragraph.alignment = .left
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    attributed.draw(with: rectFromTop(x: x, y: y, w: width, h: 260), options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func fillRounded(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRounded(_ rect: NSRect, radius: CGFloat, color: NSColor, width: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    color.setStroke()
    path.stroke()
}

func fillOval(_ rect: NSRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func drawHandBehindDevice(device: NSRect, side: CGFloat) {
    let skin = NSColor(calibratedRed: 0.88, green: 0.63, blue: 0.47, alpha: 1)
    let skinLight = NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.61, alpha: 1)
    let shadow = NSColor(calibratedRed: 0.50, green: 0.27, blue: 0.18, alpha: 0.24)
    let isLeft = side < 0
    let palmX = isLeft ? device.minX - 150 : device.maxX - 70
    let palmY = device.minY + 520

    let palm = NSRect(x: palmX, y: palmY, width: 220, height: 390)
    NSGradient(colors: [skinLight, skin])!.draw(in: NSBezierPath(roundedRect: palm, xRadius: 96, yRadius: 96), angle: isLeft ? 10 : 170)

    for i in 0..<4 {
        let y = device.minY + 760 + CGFloat(i) * 120
        let x = isLeft ? device.minX - 86 : device.maxX - 16
        let finger = NSRect(x: x, y: y, width: 128, height: 72)
        NSGradient(colors: [skinLight, skin])!.draw(in: NSBezierPath(roundedRect: finger, xRadius: 36, yRadius: 36), angle: 0)
        fillOval(NSRect(x: isLeft ? x + 78 : x + 8, y: y + 12, width: 36, height: 36), color: NSColor.white.withAlphaComponent(0.12))
        strokeRounded(finger.insetBy(dx: 2, dy: 2), radius: 34, color: shadow, width: 1.6)
    }

    let wrist = NSRect(x: isLeft ? device.minX - 220 : device.maxX - 18, y: device.minY + 170, width: 250, height: 380)
    NSGradient(colors: [skin, skinLight])!.draw(in: NSBezierPath(roundedRect: wrist, xRadius: 80, yRadius: 80), angle: isLeft ? 40 : 140)
}

func drawThumbOverDevice(device: NSRect, side: CGFloat) {
    let skin = NSColor(calibratedRed: 0.86, green: 0.59, blue: 0.43, alpha: 1)
    let skinLight = NSColor(calibratedRed: 0.97, green: 0.76, blue: 0.59, alpha: 1)
    let isLeft = side < 0
    let x = isLeft ? device.minX - 8 : device.maxX - 124
    let y = device.minY + 560
    let thumb = NSRect(x: x, y: y, width: 138, height: 330)
    let path = NSBezierPath(roundedRect: thumb, xRadius: 64, yRadius: 64)
    NSGradient(colors: [skinLight, skin])!.draw(in: path, angle: isLeft ? 0 : 180)
    fillOval(NSRect(x: isLeft ? x + 78 : x + 20, y: y + 250, width: 42, height: 52), color: NSColor.white.withAlphaComponent(0.16))
}

func drawIPadMockup(appImage: NSImage, in device: NSRect, cropOffset: CGFloat) {
    drawHandBehindDevice(device: device, side: -1)
    drawHandBehindDevice(device: device, side: 1)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 46
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    fillRounded(device, radius: 72, color: NSColor(calibratedWhite: 0.93, alpha: 1))
    NSShadow().set()

    strokeRounded(device, radius: 72, color: NSColor(calibratedWhite: 0.55, alpha: 0.45), width: 3)
    strokeRounded(device.insetBy(dx: 8, dy: 8), radius: 64, color: .white.withAlphaComponent(0.86), width: 4)

    let screen = device.insetBy(dx: 54, dy: 62)
    fillRounded(screen, radius: 42, color: .white)

    let clip = NSBezierPath(roundedRect: screen, xRadius: 42, yRadius: 42)
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    let sourceW = appImage.size.width
    let sourceH = appImage.size.height
    let drawW = screen.width
    let drawH = drawW * sourceH / sourceW
    let drawRect = NSRect(x: screen.minX, y: screen.maxY - drawH + cropOffset, width: drawW, height: drawH)
    appImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    let glass = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.18),
        NSColor.white.withAlphaComponent(0.02)
    ])!
    glass.draw(in: NSBezierPath(roundedRect: screen, xRadius: 42, yRadius: 42), angle: 62)

    fillOval(NSRect(x: device.midX - 11, y: device.maxY - 37, width: 22, height: 22), color: NSColor(calibratedWhite: 0.18, alpha: 0.55))
    drawThumbOverDevice(device: device, side: -1)
    drawThumbOverDevice(device: device, side: 1)
}

func drawRealHandIPadPhoto(appImage: NSImage, cropOffset: CGFloat) throws {
    guard let photo = NSImage(contentsOf: realHandIPadURL) else {
        throw NSError(domain: "Screenshot", code: 5, userInfo: [NSLocalizedDescriptionKey: "Missing \(realHandIPadURL.path)"])
    }

    let photoRect = rectFromTop(x: -190, y: 650, w: 2400, h: 1350)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 42
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    photo.draw(in: photoRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSShadow().set()

    let scaleX = photoRect.width / photo.size.width
    let scaleY = photoRect.height / photo.size.height
    let screen = NSRect(
        x: photoRect.minX + 930 * scaleX,
        y: photoRect.maxY - (250 + 1408) * scaleY,
        width: 2010 * scaleX,
        height: 1408 * scaleY
    )

    let screenClip = NSBezierPath(roundedRect: screen, xRadius: 18, yRadius: 18)
    NSGraphicsContext.saveGraphicsState()
    screenClip.addClip()
    fillRounded(screen, radius: 18, color: .white)
    let drawW = screen.width
    let drawH = drawW * appImage.size.height / appImage.size.width
    let drawRect = NSRect(x: screen.minX, y: screen.maxY - drawH + cropOffset, width: drawW, height: drawH)
    appImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)

    let glass = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.12),
        NSColor.white.withAlphaComponent(0.01)
    ])!
    glass.draw(in: screenClip, angle: 55)
    NSGraphicsContext.restoreGraphicsState()
}

func makeImage(for shot: Shot) throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "Screenshot", code: 1)
    }

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "Screenshot", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.interpolationQuality = .high

    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1),
        NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.99, alpha: 1)
    ])!
    bg.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)

    let glowRect = rectFromTop(x: 980, y: -130, w: 900, h: 560)
    let glow = NSGradient(colors: [
        shot.accent.withAlphaComponent(0.24),
        shot.accent.withAlphaComponent(0.02)
    ])!
    glow.draw(in: NSBezierPath(ovalIn: glowRect), angle: 0)

    let badgeWidth: CGFloat = shot.badge.count > 6 ? 430 : 310
    fillRounded(rectFromTop(x: 96, y: 94, w: badgeWidth, h: 76), radius: 38, color: shot.accent)
    drawText(shot.badge, x: 132, y: 112, width: badgeWidth - 64, font: .systemFont(ofSize: 30, weight: .bold), color: .white, lineSpacing: 0)

    drawText(shot.title, x: 96, y: 214, width: 1180, font: .systemFont(ofSize: 88, weight: .heavy), color: NSColor(calibratedWhite: 0.08, alpha: 1), lineSpacing: 12)
    drawText(shot.subtitle, x: 100, y: 432, width: 1520, font: .systemFont(ofSize: 39, weight: .semibold), color: NSColor(calibratedWhite: 0.36, alpha: 1), lineSpacing: 8)

    let sourceURL = sourceDir.appendingPathComponent(shot.source)
    guard let appImage = NSImage(contentsOf: sourceURL) else {
        throw NSError(domain: "Screenshot", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing \(sourceURL.path)"])
    }

    try drawRealHandIPadPhoto(appImage: appImage, cropOffset: shot.cropOffset)

    let calloutRect = rectFromTop(x: 126, y: 2508, w: 1040, h: 96)
    fillRounded(calloutRect, radius: 28, color: shot.accent.withAlphaComponent(0.13))
    fillRounded(rectFromTop(x: 154, y: 2530, w: 52, h: 52), radius: 26, color: shot.accent)
    drawText("SHOKOで日本の帳票作成をスムーズに", x: 230, y: 2526, width: 880, font: .systemFont(ofSize: 30, weight: .bold), color: NSColor(calibratedWhite: 0.18, alpha: 1), lineSpacing: 0)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for shot in shots {
    let rep = try makeImage(for: shot)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Screenshot", code: 4)
    }
    let out = outputDir.appendingPathComponent(shot.output)
    try data.write(to: out)
    print(out.path)
}
