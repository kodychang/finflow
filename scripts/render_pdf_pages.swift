import AppKit
import PDFKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
  fputs("usage: render_pdf_pages.swift <input.pdf> <output_dir> [max_pages]\n", stderr)
  exit(1)
}

let inputPath = args[1]
let outputDir = args[2]
let maxPages = args.count >= 4 ? (Int(args[3]) ?? 6) : 6

let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputDir, isDirectory: true)

guard let document = PDFDocument(url: inputURL) else {
  fputs("failed to open pdf\n", stderr)
  exit(2)
}

try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let pageCount = min(document.pageCount, maxPages)
var outputs: [[String: Any]] = []

for index in 0..<pageCount {
  guard let page = document.page(at: index) else { continue }
  let mediaBox = page.bounds(for: .mediaBox)
  let scale: CGFloat = 2.0
  let width = max(Int(mediaBox.width * scale), 1)
  let height = max(Int(mediaBox.height * scale), 1)

  guard let bitmap = NSBitmapImageRep(
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
    continue
  }

  bitmap.size = NSSize(width: mediaBox.width, height: mediaBox.height)
  NSGraphicsContext.saveGraphicsState()
  if let context = NSGraphicsContext(bitmapImageRep: bitmap) {
    NSGraphicsContext.current = context
    NSColor.white.set()
    context.cgContext.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    context.cgContext.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context.cgContext)
    context.flushGraphics()
  }
  NSGraphicsContext.restoreGraphicsState()

  let fileName = String(format: "page-%03d.png", index + 1)
  let fileURL = outputURL.appendingPathComponent(fileName)
  if let data = bitmap.representation(using: .png, properties: [:]) {
    try? data.write(to: fileURL)
    outputs.append([
      "page": index + 1,
      "path": fileURL.path,
    ])
  }
}

if let json = try? JSONSerialization.data(withJSONObject: outputs, options: []),
   let text = String(data: json, encoding: .utf8) {
  print(text)
} else {
  print("[]")
}
