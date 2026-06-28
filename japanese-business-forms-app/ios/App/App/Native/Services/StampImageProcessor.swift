import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum StampImageProcessor {
    struct Options {
        var opacity: CGFloat = 0.82
        var brightness: CGFloat = 0
        var contrast: CGFloat = 1
        var tintColor: UIColor = .red
        var appliesTint = false
        var removesWhiteBackground = true
        var backgroundRemovalStrength: CGFloat = 0.72
        var cropInsets = StampCropInsets()
    }

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func process(_ image: UIImage, options: Options) -> UIImage {
        guard var ciImage = CIImage(image: image) else { return image }
        ciImage = crop(ciImage, insets: options.cropInsets)

        if options.removesWhiteBackground || options.appliesTint {
            ciImage = applyColorCube(to: ciImage, options: options)
        }

        let controls = CIFilter.colorControls()
        controls.inputImage = ciImage
        controls.brightness = Float(options.brightness)
        controls.contrast = Float(options.contrast)
        controls.saturation = 1

        guard let output = controls.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func crop(_ image: CIImage, insets: StampCropInsets) -> CIImage {
        let extent = image.extent
        let left = min(max(insets.left, 0), 0.45)
        let right = min(max(insets.right, 0), 0.45)
        let top = min(max(insets.top, 0), 0.45)
        let bottom = min(max(insets.bottom, 0), 0.45)
        let cropRect = CGRect(
            x: extent.minX + extent.width * left,
            y: extent.minY + extent.height * bottom,
            width: extent.width * max(0.1, 1 - left - right),
            height: extent.height * max(0.1, 1 - top - bottom)
        )
        return image.cropped(to: cropRect)
    }

    private static func applyColorCube(to image: CIImage, options: Options) -> CIImage {
        let dimension = 32
        let cubeData = makeCubeData(dimension: dimension, options: options)
        let filter = CIFilter.colorCube()
        filter.inputImage = image
        filter.cubeDimension = Float(dimension)
        filter.cubeData = cubeData
        return filter.outputImage ?? image
    }

    private static func makeCubeData(dimension: Int, options: Options) -> Data {
        let color = CIColor(color: options.tintColor)
        var values = [Float]()
        values.reserveCapacity(dimension * dimension * dimension * 4)

        for blueIndex in 0..<dimension {
            let blue = Float(blueIndex) / Float(dimension - 1)
            for greenIndex in 0..<dimension {
                let green = Float(greenIndex) / Float(dimension - 1)
                for redIndex in 0..<dimension {
                    let red = Float(redIndex) / Float(dimension - 1)
                    let whiteness = min(red, min(green, blue))
                    let chroma = max(red, max(green, blue)) - min(red, min(green, blue))
                    let strength = Float(min(max(options.backgroundRemovalStrength, 0), 1))
                    let whiteThreshold = 0.9 - strength * 0.18
                    let softRange = 0.04 + (1 - strength) * 0.08
                    let neutralLimit = 0.22 - strength * 0.1
                    let whiteMask = smoothstep(edge0: whiteThreshold, edge1: whiteThreshold + softRange, value: whiteness)
                    let neutralMask = 1 - smoothstep(edge0: neutralLimit, edge1: neutralLimit + 0.12, value: chroma)
                    let alpha: Float = options.removesWhiteBackground ? max(0, min(1, 1 - whiteMask * neutralMask)) : 1

                    if options.appliesTint {
                        let luminance = max(0.18, 1 - (0.299 * red + 0.587 * green + 0.114 * blue))
                        values.append(Float(color.red) * luminance)
                        values.append(Float(color.green) * luminance)
                        values.append(Float(color.blue) * luminance)
                    } else {
                        values.append(red)
                        values.append(green)
                        values.append(blue)
                    }
                    values.append(alpha)
                }
            }
        }

        return values.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    private static func smoothstep(edge0: Float, edge1: Float, value: Float) -> Float {
        guard edge0 != edge1 else { return value < edge0 ? 0 : 1 }
        let t = max(0, min(1, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}

struct StampCropInsets {
    var top: CGFloat = 0
    var bottom: CGFloat = 0
    var left: CGFloat = 0
    var right: CGFloat = 0

    var hasCrop: Bool {
        top > 0 || bottom > 0 || left > 0 || right > 0
    }
}

enum StampLibrary {
    private static let stampDataKey = "native.shokoForms.defaultStampImage.v1"
    private static let stampSettingsKey = "native.shokoForms.defaultStampSettings.v1"
    private static let bundledStampDeletedKey = "native.shokoForms.bundledDefaultStampDeleted.v1"

    static var defaultStampImage: UIImage? {
        if let data = UserDefaults.standard.data(forKey: stampDataKey),
           let image = UIImage(data: data) {
            return image
        }
        guard !UserDefaults.standard.bool(forKey: bundledStampDeletedKey) else { return nil }
        return UIImage(named: "DefaultStamp")
    }

    static var defaultStampSettings: StampSettings? {
        guard let data = UserDefaults.standard.data(forKey: stampSettingsKey) else { return nil }
        return try? JSONDecoder().decode(StampSettings.self, from: data)
    }

    static func saveDefaultStamp(_ image: UIImage) {
        let data = image.pngData() ?? image.jpegData(compressionQuality: 0.95)
        UserDefaults.standard.set(data, forKey: stampDataKey)
        UserDefaults.standard.removeObject(forKey: bundledStampDeletedKey)
    }

    static func deleteDefaultStamp() {
        UserDefaults.standard.removeObject(forKey: stampDataKey)
        UserDefaults.standard.set(true, forKey: bundledStampDeletedKey)
    }

    static func saveDefaultStampSettings(_ settings: StampSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: stampSettingsKey)
    }

    static func deleteDefaultStampSettings() {
        UserDefaults.standard.removeObject(forKey: stampSettingsKey)
    }
}

struct StampSettings: Codable {
    static let basePageRatio: CGFloat = 0.24
    static let minimumPageRatio: CGFloat = 0.05
    static let maximumPageRatio: CGFloat = 0.25
    static let minimumScale: CGFloat = minimumPageRatio / basePageRatio
    static let maximumScale: CGFloat = maximumPageRatio / basePageRatio

    var normalizedCenterX: CGFloat = 0.5
    var normalizedCenterY: CGFloat = 0.5
    var scale: CGFloat = 1
    var rotation: CGFloat = 0
    var opacity: CGFloat = 0.82
    var brightness: CGFloat = 0
    var contrast: CGFloat = 1
    var appliesTint = false
    var removesWhiteBackground = true
    var backgroundRemovalStrength: CGFloat = 0.72
    var tintRed: CGFloat = 1
    var tintGreen: CGFloat = 0
    var tintBlue: CGFloat = 0
    var cropTop: CGFloat = 0
    var cropBottom: CGFloat = 0
    var cropLeft: CGFloat = 0
    var cropRight: CGFloat = 0

    init(
        normalizedCenterX: CGFloat = 0.5,
        normalizedCenterY: CGFloat = 0.5,
        scale: CGFloat = 1,
        rotation: CGFloat = 0,
        opacity: CGFloat = 0.82,
        brightness: CGFloat = 0,
        contrast: CGFloat = 1,
        appliesTint: Bool = false,
        removesWhiteBackground: Bool = true,
        backgroundRemovalStrength: CGFloat = 0.72,
        tintRed: CGFloat = 1,
        tintGreen: CGFloat = 0,
        tintBlue: CGFloat = 0,
        cropTop: CGFloat = 0,
        cropBottom: CGFloat = 0,
        cropLeft: CGFloat = 0,
        cropRight: CGFloat = 0
    ) {
        self.normalizedCenterX = normalizedCenterX
        self.normalizedCenterY = normalizedCenterY
        self.scale = Self.clampedScale(scale)
        self.rotation = rotation
        self.opacity = opacity
        self.brightness = brightness
        self.contrast = contrast
        self.appliesTint = appliesTint
        self.removesWhiteBackground = removesWhiteBackground
        self.backgroundRemovalStrength = backgroundRemovalStrength
        self.tintRed = tintRed
        self.tintGreen = tintGreen
        self.tintBlue = tintBlue
        self.cropTop = cropTop
        self.cropBottom = cropBottom
        self.cropLeft = cropLeft
        self.cropRight = cropRight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            normalizedCenterX: try container.decodeIfPresent(CGFloat.self, forKey: .normalizedCenterX) ?? 0.5,
            normalizedCenterY: try container.decodeIfPresent(CGFloat.self, forKey: .normalizedCenterY) ?? 0.5,
            scale: Self.clampedScale(try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1),
            rotation: try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0,
            opacity: try container.decodeIfPresent(CGFloat.self, forKey: .opacity) ?? 0.82,
            brightness: try container.decodeIfPresent(CGFloat.self, forKey: .brightness) ?? 0,
            contrast: try container.decodeIfPresent(CGFloat.self, forKey: .contrast) ?? 1,
            appliesTint: try container.decodeIfPresent(Bool.self, forKey: .appliesTint) ?? false,
            removesWhiteBackground: try container.decodeIfPresent(Bool.self, forKey: .removesWhiteBackground) ?? true,
            backgroundRemovalStrength: try container.decodeIfPresent(CGFloat.self, forKey: .backgroundRemovalStrength) ?? 0.72,
            tintRed: try container.decodeIfPresent(CGFloat.self, forKey: .tintRed) ?? 1,
            tintGreen: try container.decodeIfPresent(CGFloat.self, forKey: .tintGreen) ?? 0,
            tintBlue: try container.decodeIfPresent(CGFloat.self, forKey: .tintBlue) ?? 0,
            cropTop: try container.decodeIfPresent(CGFloat.self, forKey: .cropTop) ?? 0,
            cropBottom: try container.decodeIfPresent(CGFloat.self, forKey: .cropBottom) ?? 0,
            cropLeft: try container.decodeIfPresent(CGFloat.self, forKey: .cropLeft) ?? 0,
            cropRight: try container.decodeIfPresent(CGFloat.self, forKey: .cropRight) ?? 0
        )
    }

    var options: StampImageProcessor.Options {
        get {
            StampImageProcessor.Options(
                opacity: opacity,
                brightness: brightness,
                contrast: contrast,
                tintColor: UIColor(red: tintRed, green: tintGreen, blue: tintBlue, alpha: 1),
                appliesTint: appliesTint,
                removesWhiteBackground: removesWhiteBackground,
                backgroundRemovalStrength: backgroundRemovalStrength,
                cropInsets: StampCropInsets(top: cropTop, bottom: cropBottom, left: cropLeft, right: cropRight)
            )
        }
        set {
            opacity = newValue.opacity
            brightness = newValue.brightness
            contrast = newValue.contrast
            appliesTint = newValue.appliesTint
            removesWhiteBackground = newValue.removesWhiteBackground
            backgroundRemovalStrength = newValue.backgroundRemovalStrength
            var red: CGFloat = 1
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 1
            newValue.tintColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            tintRed = red
            tintGreen = green
            tintBlue = blue
            cropTop = newValue.cropInsets.top
            cropBottom = newValue.cropInsets.bottom
            cropLeft = newValue.cropInsets.left
            cropRight = newValue.cropInsets.right
        }
    }

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }
}
