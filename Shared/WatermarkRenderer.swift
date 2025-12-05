import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct WatermarkRenderer {
    @MainActor
    static func render(
        image: PlatformImage,
        metadata: PhotoMetadata,
        brand: String,
        originalMetadata: [AnyHashable: Any]
    ) async -> Data? {
        let content = WatermarkView(platformImage: image, metadata: metadata, brand: brand)
        let renderer = ImageRenderer(content: content)

        #if os(iOS) || os(tvOS)
        renderer.scale = UIScreen.main.scale
        #endif

        if let cgImage = renderer.cgImage {
            let data = NSMutableData()
            let uti = UTType.jpeg.identifier as CFString
            guard let destination = CGImageDestinationCreateWithData(data, uti, 1, nil) else {
                return nil
            }

            var combinedMetadata = originalMetadata
            combinedMetadata[kCGImagePropertyOrientation as String] = combinedMetadata[kCGImagePropertyOrientation as String] ?? 1

            CGImageDestinationAddImage(destination, cgImage, combinedMetadata as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return data as Data
        }

        #if os(iOS) || os(tvOS)
        return renderer.uiImage?.jpegData(compressionQuality: 0.95)
        #else
        guard let bitmap = renderer.nsImage?.cgImageSafe else { return nil }
        let data = NSMutableData()
        let uti = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, uti, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, bitmap, originalMetadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
        #endif
    }
}

struct WatermarkView: View {
    let platformImage: PlatformImage
    let metadata: PhotoMetadata
    let brand: String
    var containerWidth: CGFloat? = nil
    
    private var imageAspectRatio: CGFloat {
        platformImage.aspectRatio
    }
    
    private var availableImageWidth: CGFloat {
        if let containerWidth = containerWidth {
            // 减去左右 padding (32 * 2) 和图片的 horizontal padding (12 * 2)
            return max(200, containerWidth - 88)
        }
        return 600
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(brand.isEmpty ? metadata.cameraBrandLabel : brand)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .kerning(1.2)

            Image(platformImage: platformImage)
                .resizable()
                .aspectRatio(imageAspectRatio, contentMode: .fit)
                .frame(maxWidth: availableImageWidth)
                .padding(.horizontal, 12)

            HStack(spacing: 16) {
                LabelView(title: "FL", value: metadata.focalLength)
                LabelView(title: "Aperture", value: metadata.aperture)
                LabelView(title: "Shutter", value: metadata.shutterSpeed)
                LabelView(title: "ISO", value: metadata.iso.replacingOccurrences(of: "ISO", with: "ISO"))
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
}

private struct LabelView: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.black)
        }
    }
}

