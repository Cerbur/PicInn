import SwiftUI
import CoreGraphics

// MARK: - 水印模板协议

protocol WatermarkTemplate {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    
    func render(
        context: CGContext,
        image cgImage: CGImage,
        metadata: PhotoMetadata,
        brand: String,
        renderWidth: CGFloat,
        scaleFactor: CGFloat,
        totalHeight: CGFloat
    ) async -> Void
}
