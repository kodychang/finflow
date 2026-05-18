import SwiftUI

struct PreviewScreen: View {
    let document: BusinessDocument
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var sharePayload: SharePayload?
    @State private var exportError = ""
    @State private var previewImages: [UIImage] = []
    @State private var previewScale: CGFloat = 1
    @State private var lastPreviewScale: CGFloat = 1
    @State private var previewOffset: CGSize = .zero
    @State private var lastPreviewOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                pdfPreview(size: proxy.size)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                previewToolbar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .onAppear(perform: renderPreviewImage)
        .onChange(of: document) { _ in
            renderPreviewImage()
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
    }

    private var previewToolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PDF Preview")
                    .font(.caption.weight(.semibold))
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
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(buttonAccent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appPanel.opacity(0.94))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
    }

    private func exportPDF() {
        do {
            exportError = ""
            sharePayload = SharePayload(url: try DocumentPDFExporter.export(document))
        } catch {
            exportError = "PDFを書き出せませんでした。"
        }
    }

    private func pdfPreview(size: CGSize) -> some View {
        Group {
            if !previewImages.isEmpty {
                if previewImages.count == 1, let image = previewImages.first {
                    singlePagePreview(image, size: size)
                } else {
                    multipagePreview(size: size)
                }
            } else {
                ProgressView("PNGプレビュー生成中")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(Color.appPanel)
    }

    private func singlePagePreview(_ image: UIImage, size: CGSize) -> some View {
        ZStack {
            pdfPage(image, availableWidth: size.width)
                .padding(.top, 110)
                .padding(.horizontal, 16)
                .padding(.bottom, 132)
                .scaleEffect(previewScale)
                .offset(previewOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(previewMagnificationGesture)
        .simultaneousGesture(previewDragGesture)
        .simultaneousGesture(previewResetGesture)
    }

    private func multipagePreview(size: CGSize) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                ForEach(Array(previewImages.enumerated()), id: \.offset) { _, image in
                    pdfPage(image, availableWidth: size.width)
                        .padding(.vertical, 20)
                }
            }
            .padding(.top, 110)
            .padding(.bottom, 132)
            .frame(maxWidth: .infinity)
        }
        .simultaneousGesture(previewResetGesture)
    }

    private func pdfPage(_ image: UIImage, availableWidth: CGFloat) -> some View {
        let pageWidth = max(1, availableWidth - 32)
        return Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: pageWidth)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 5)
            .accessibilityLabel("PDFプレビュー")
    }

    private func renderPreviewImage() {
        do {
            exportError = ""
            previewImages = try DocumentPDFExporter.previewImages(for: document, scale: UIScreen.main.scale)
            resetPreviewZoom()
        } catch {
            previewImages = []
            exportError = "PNGプレビューを生成できませんでした。"
        }
    }

    private var previewMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                previewScale = clampedPreviewScale(lastPreviewScale * value)
                if previewScale <= 1 {
                    previewOffset = .zero
                }
            }
            .onEnded { _ in
                lastPreviewScale = previewScale
                if previewScale <= 1 {
                    resetPreviewZoom()
                }
            }
    }

    private var previewDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard previewScale > 1 else { return }
                previewOffset = CGSize(
                    width: lastPreviewOffset.width + value.translation.width,
                    height: lastPreviewOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPreviewOffset = previewOffset
            }
    }

    private var previewResetGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    resetPreviewZoom()
                }
            }
    }

    private func resetPreviewZoom() {
        previewScale = 1
        lastPreviewScale = 1
        previewOffset = .zero
        lastPreviewOffset = .zero
    }

    private func clampedPreviewScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 4)
    }
}
