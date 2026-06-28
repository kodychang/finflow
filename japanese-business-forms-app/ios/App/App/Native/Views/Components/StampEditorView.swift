import PhotosUI
import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct StampEditorView: View {
    let baseImage: UIImage
    let initialStampImage: UIImage?
    let initialSettings: StampSettings?
    let language: AppLanguage
    let onComplete: (UIImage, StampSettings) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var selectedItem: PhotosPickerItem?
    @State private var stampImage: UIImage?
    @State private var options = StampImageProcessor.Options()
    @State private var center: CGPoint = .zero
    @State private var hasPlacedStamp = false
    @State private var stampScale: CGFloat = 1
    @State private var lastStampScale: CGFloat = 1
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var dragStartCenter: CGPoint?
    @State private var currentPageRect: CGRect = .zero
    @State private var didApplyInitialSettings = false
    @State private var statusText = ""

    private var processedStampImage: UIImage? {
        stampImage.map { StampImageProcessor.process($0, options: processingOptions) }
    }

    private var processingOptions: StampImageProcessor.Options {
        var sanitizedOptions = options
        sanitizedOptions.cropInsets = StampCropInsets()
        return sanitizedOptions
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let pageRect = fittedRect(imageSize: baseImage.size, containerSize: proxy.size)
                    ZStack(alignment: .topLeading) {
                        Color.appInputBackground.ignoresSafeArea()
                        Image(uiImage: baseImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: pageRect.width, height: pageRect.height)
                            .position(x: pageRect.midX, y: pageRect.midY)
                            .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)

                        if let processedStampImage {
                            stampLayer(image: processedStampImage, pageRect: pageRect)
                        }
                    }
                    .onAppear {
                        if stampImage == nil {
                            stampImage = initialStampImage
                        }
                        applyInitialSettingsIfNeeded(in: pageRect)
                        currentPageRect = pageRect
                        placeStampIfNeeded(in: pageRect)
                    }
                    .onChange(of: stampImage) { _ in
                        hasPlacedStamp = false
                        placeStampIfNeeded(in: pageRect)
                    }
                    .onChange(of: proxy.size) { _ in
                        currentPageRect = pageRect
                        applyInitialSettingsIfNeeded(in: pageRect)
                        placeStampIfNeeded(in: pageRect)
                    }
                }

                controls
            }
            .navigationTitle(localized(japanese: "印章編集", chinese: "印章编辑", english: "Stamp Editor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized(japanese: "キャンセル", chinese: "取消", english: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized(japanese: "印章を確定", chinese: "确定盖章", english: "Apply Stamp")) {
                        confirmStamp()
                    }
                    .disabled(stampImage == nil)
                }
            }
            .task(id: selectedItem) {
                await loadSelectedStamp()
            }
        }
    }

    private func stampLayer(image: UIImage, pageRect: CGRect) -> some View {
        let size = stampDisplaySize(pageRect: pageRect)
        return Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
            .opacity(options.opacity)
            .rotationEffect(rotation)
            .position(center)
            .gesture(stampDragGesture)
            .simultaneousGesture(stampMagnificationGesture)
            .simultaneousGesture(stampRotationGesture)
            .accessibilityLabel(localized(japanese: "印章レイヤー", chinese: "印章图层", english: "Stamp layer"))
    }

    private var controls: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(stampImage == nil ? localized(japanese: "写真から印章を選択", chinese: "从相册选择印章", english: "Choose Stamp from Photos") : localized(japanese: "印章画像を変更", chinese: "更换印章图片", english: "Change Stamp Image"), systemImage: "photo.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StampFilledButtonStyle(tint: buttonAccent))

                if stampImage != nil {
                    backgroundRemovalControls
                    Toggle(localized(japanese: "色を調整", chinese: "调整颜色", english: "Adjust Color"), isOn: $options.appliesTint)
                        .toggleStyle(SwitchToggleStyle(tint: buttonAccent))
                    if options.appliesTint {
                        ColorPicker(localized(japanese: "印章色", chinese: "印章颜色", english: "Stamp Color"), selection: tintBinding, supportsOpacity: false)
                    }
                    slider(title: localized(japanese: "サイズ", chinese: "大小", english: "Size"), value: stampScaleBinding, range: StampSettings.minimumScale...StampSettings.maximumScale)
                    rotationControls
                    slider(title: localized(japanese: "透明度", chinese: "透明度", english: "Opacity"), value: $options.opacity, range: 0.1...1)
                    slider(title: localized(japanese: "明るさ", chinese: "亮度", english: "Brightness"), value: $options.brightness, range: -0.35...0.35)
                    slider(title: localized(japanese: "コントラスト", chinese: "对比度", english: "Contrast"), value: $options.contrast, range: 0.4...2)
                }

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appMuted)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 390)
        .background(Color.appPanel)
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .top)
    }

    private var rotationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(localized(japanese: "角度を調整", chinese: "调整角度", english: "Adjust Angle"), systemImage: "rotate.right")
                    .font(.caption.weight(.black))
                    .foregroundColor(.appMuted)
                Spacer()
                Button {
                    rotation = .zero
                    lastRotation = .zero
                } label: {
                    Text(localized(japanese: "リセット", chinese: "重置", english: "Reset"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(buttonAccent)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(abs(rotation.degrees) < 0.01)
                .opacity(abs(rotation.degrees) >= 0.01 ? 1 : 0.45)
            }
            slider(title: localized(japanese: "角度", chinese: "角度", english: "Angle"), value: rotationBinding, range: -180...180)
        }
        .padding(12)
        .background(Color.appInputBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
    }

    private var backgroundRemovalControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $options.removesWhiteBackground) {
                Label(localized(japanese: "背景を透明にする", chinese: "去背并保留透明背景", english: "Remove Background"), systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appInk)
            }
            .toggleStyle(SwitchToggleStyle(tint: buttonAccent))

            if options.removesWhiteBackground {
                slider(
                    title: localized(japanese: "去背強度", chinese: "去背强度", english: "Removal Strength"),
                    value: $options.backgroundRemovalStrength,
                    range: 0...1
                )
                Text(localized(
                    japanese: "白い紙面や薄い影を透明化します。印章が欠ける場合は強度を下げてください。",
                    chinese: "将白纸背景和浅色阴影转为透明。印章边缘被削掉时请降低强度。",
                    english: "Turns white paper and light shadows transparent. Lower the strength if stamp edges disappear."
                ))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.appInputBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
    }

    private func slider(title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundColor(.appMuted)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundColor(.appMuted)
            }
            Slider(value: value, in: range)
                .tint(buttonAccent)
        }
    }

    private func localized(japanese: String, chinese: String, english: String) -> String {
        switch language {
        case .japanese: return japanese
        case .simplifiedChinese: return chinese
        case .english: return english
        case .korean: return KoreanGlossary.value(for: english)
        case .traditionalChinese: return chinese
        case .nepali, .french, .vietnamese: return english
        }
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: { Color(options.tintColor) },
            set: { options.tintColor = UIColor($0) }
        )
    }

    private var stampScaleBinding: Binding<CGFloat> {
        Binding(
            get: { stampScale },
            set: { value in
                stampScale = StampSettings.clampedScale(value)
                lastStampScale = stampScale
            }
        )
    }

    private var rotationBinding: Binding<CGFloat> {
        Binding(
            get: { CGFloat(rotation.degrees) },
            set: { value in
                let clampedValue = min(max(value, -180), 180)
                rotation = .degrees(Double(clampedValue))
                lastRotation = rotation
            }
        )
    }

    private var stampDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartCenter == nil {
                    dragStartCenter = center
                }
                let start = dragStartCenter ?? center
                center = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
            }
            .onEnded { _ in
                dragStartCenter = nil
            }
    }

    private var stampMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                stampScale = StampSettings.clampedScale(lastStampScale * value)
            }
            .onEnded { _ in
                lastStampScale = stampScale
            }
    }

    private var stampRotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                rotation = lastRotation + value
            }
            .onEnded { _ in
                lastRotation = rotation
            }
    }

    private func loadSelectedStamp() async {
        guard let selectedItem else { return }
        do {
            if let data = try await selectedItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    stampImage = image
                    StampLibrary.saveDefaultStamp(image)
                    statusText = "印章画像を読み込みました。"
                }
            }
        } catch {
            await MainActor.run {
                statusText = "印章画像を読み込めませんでした。"
            }
        }
    }

    private func confirmStamp() {
        guard let processedStampImage else { return }
        let pageRect = currentPageRect
        guard pageRect.width > 0, pageRect.height > 0 else { return }
        let displaySize = CGSize(width: pageRect.width, height: pageRect.height)
        let stampSize = stampDisplaySize(pageRect: pageRect)
        let centerInPage = CGPoint(x: center.x - pageRect.minX, y: center.y - pageRect.minY)
        let settings = currentSettings(pageRect: pageRect)
        let composed = StampComposer.compose(
            baseImage: baseImage,
            stampImage: processedStampImage,
            placement: StampComposer.Placement(
                pageDisplaySize: displaySize,
                stampDisplaySize: stampSize,
                centerInPage: centerInPage,
                rotation: CGFloat(rotation.radians),
                opacity: options.opacity
            )
        )
        onComplete(composed, settings)
        dismiss()
    }

    private func applyInitialSettingsIfNeeded(in pageRect: CGRect) {
        guard !didApplyInitialSettings, let initialSettings, pageRect.width > 0, pageRect.height > 0 else { return }
        options = initialSettings.options
        options.cropInsets = StampCropInsets()
        stampScale = StampSettings.clampedScale(initialSettings.scale)
        lastStampScale = stampScale
        rotation = Angle(radians: Double(initialSettings.rotation))
        lastRotation = rotation
        center = CGPoint(
            x: pageRect.minX + pageRect.width * min(max(initialSettings.normalizedCenterX, 0), 1),
            y: pageRect.minY + pageRect.height * min(max(initialSettings.normalizedCenterY, 0), 1)
        )
        hasPlacedStamp = true
        didApplyInitialSettings = true
    }

    private func currentSettings(pageRect: CGRect) -> StampSettings {
        let centerInPage = CGPoint(x: center.x - pageRect.minX, y: center.y - pageRect.minY)
        var settings = StampSettings(
            normalizedCenterX: min(max(centerInPage.x / max(1, pageRect.width), 0), 1),
            normalizedCenterY: min(max(centerInPage.y / max(1, pageRect.height), 0), 1),
            scale: StampSettings.clampedScale(stampScale),
            rotation: CGFloat(rotation.radians)
        )
        settings.options = processingOptions
        return settings
    }

    private func placeStampIfNeeded(in pageRect: CGRect) {
        guard !hasPlacedStamp, stampImage != nil, pageRect.width > 0, pageRect.height > 0 else { return }
        center = CGPoint(x: pageRect.midX, y: pageRect.midY)
        hasPlacedStamp = true
    }

    private func stampDisplaySize(pageRect: CGRect) -> CGSize {
        let base = min(pageRect.width, pageRect.height) * StampSettings.basePageRatio * StampSettings.clampedScale(stampScale)
        guard let stampImage = processedStampImage ?? stampImage else { return CGSize(width: base, height: base) }
        let aspect = max(0.1, stampImage.size.width / max(1, stampImage.size.height))
        if aspect >= 1 {
            return CGSize(width: base, height: base / aspect)
        }
        return CGSize(width: base * aspect, height: base)
    }

    private func fittedRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

private struct StampFilledButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(configuration.isPressed ? tint.opacity(0.78) : tint)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}
