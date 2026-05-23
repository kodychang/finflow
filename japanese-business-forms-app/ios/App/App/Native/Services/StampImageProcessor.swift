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
                    let isNearWhite = red > 0.82 && green > 0.82 && blue > 0.82 && abs(red - green) < 0.12 && abs(green - blue) < 0.12
                    let alpha: Float = options.removesWhiteBackground && isNearWhite ? 0 : 1

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

    static var defaultStampImage: UIImage? {
        guard let data = UserDefaults.standard.data(forKey: stampDataKey) else { return nil }
        return UIImage(data: data)
    }

    static var defaultStampSettings: StampSettings? {
        guard let data = UserDefaults.standard.data(forKey: stampSettingsKey) else { return nil }
        return try? JSONDecoder().decode(StampSettings.self, from: data)
    }

    static func saveDefaultStamp(_ image: UIImage) {
        let data = image.pngData() ?? image.jpegData(compressionQuality: 0.95)
        UserDefaults.standard.set(data, forKey: stampDataKey)
    }

    static func deleteDefaultStamp() {
        UserDefaults.standard.removeObject(forKey: stampDataKey)
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
    var normalizedCenterX: CGFloat = 0.5
    var normalizedCenterY: CGFloat = 0.5
    var scale: CGFloat = 1
    var rotation: CGFloat = 0
    var opacity: CGFloat = 0.82
    var brightness: CGFloat = 0
    var contrast: CGFloat = 1
    var appliesTint = false
    var removesWhiteBackground = true
    var tintRed: CGFloat = 1
    var tintGreen: CGFloat = 0
    var tintBlue: CGFloat = 0
    var cropTop: CGFloat = 0
    var cropBottom: CGFloat = 0
    var cropLeft: CGFloat = 0
    var cropRight: CGFloat = 0

    var options: StampImageProcessor.Options {
        get {
            StampImageProcessor.Options(
                opacity: opacity,
                brightness: brightness,
                contrast: contrast,
                tintColor: UIColor(red: tintRed, green: tintGreen, blue: tintBlue, alpha: 1),
                appliesTint: appliesTint,
                removesWhiteBackground: removesWhiteBackground,
                cropInsets: StampCropInsets(top: cropTop, bottom: cropBottom, left: cropLeft, right: cropRight)
            )
        }
        set {
            opacity = newValue.opacity
            brightness = newValue.brightness
            contrast = newValue.contrast
            appliesTint = newValue.appliesTint
            removesWhiteBackground = newValue.removesWhiteBackground
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
}
