import SwiftUI
import CoreGraphics

// MARK: - 叠框模板（窄边框 + 同行信息）

struct FusionTemplate: WatermarkTemplate {
    let id: String = "fusion"
    let name: String = "叠框"
    let description: String = "边框 + 同行信息"
    
    func render(
        context: CGContext,
        image cgImage: CGImage,
        metadata: PhotoMetadata,
        brand: String,
        renderWidth: CGFloat,
        scaleFactor: CGFloat,
        totalHeight: CGFloat
    ) async {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let imageAspectRatio = imageSize.width / imageSize.height
        
        let imagePadding = 24 * scaleFactor
        let containerPadding = 64 * scaleFactor
        let bottomPadding = 32 * scaleFactor
        let brandHeight = 50 * scaleFactor
        let paramsHeight = 30 * scaleFactor
        let spacing = 24 * scaleFactor
        let borderThickness = spacing
        let bottomBandHeight = brandHeight + spacing + paramsHeight
        
        let imageWidth = renderWidth - containerPadding - (imagePadding * 2)
        let imageHeight = imageWidth / imageAspectRatio
        
        let photoRect = CGRect(
            x: containerPadding / 2 + imagePadding,
            y: bottomPadding + bottomBandHeight,
            width: imageWidth,
            height: imageHeight
        )
        
        let borderLeftX = photoRect.minX - borderThickness
        let borderWidth = photoRect.width + (borderThickness * 2)
        let borderColor = CGColor(gray: 0.93, alpha: 1)
        
        // Bottom band for brand + metadata
        let bottomBandRect = CGRect(
            x: borderLeftX,
            y: bottomPadding,
            width: borderWidth,
            height: bottomBandHeight
        )
        context.setFillColor(borderColor)
        context.fill(bottomBandRect)
        
        // Left / right / top narrow borders
        let leftBorderRect = CGRect(x: borderLeftX, y: photoRect.minY, width: borderThickness, height: photoRect.height)
        let rightBorderRect = CGRect(x: photoRect.maxX, y: photoRect.minY, width: borderThickness, height: photoRect.height)
        let topBorderRect = CGRect(x: borderLeftX, y: photoRect.maxY, width: borderWidth, height: borderThickness)
        context.fill(leftBorderRect)
        context.fill(rightBorderRect)
        context.fill(topBorderRect)
        
        // Draw original image
        context.draw(cgImage, in: photoRect)
        
        // Text content inside bottom band
        let brandText = brand.isEmpty ? metadata.cameraBrandLabel : brand
        let brandFontSize = 24 * scaleFactor
        let metadataFontSize = 15 * scaleFactor
        let textCenterYFromTop = totalHeight - (bottomPadding + bottomBandHeight / 2)
        let imageLeftX = photoRect.minX
        let imageRightX = photoRect.maxX
        
        WatermarkRenderer.drawText(
            context: context,
            text: brandText,
            fontSize: brandFontSize,
            weight: .black,
            at: CGPoint(x: imageLeftX, y: textCenterYFromTop),
            alignment: .leading,
            contextHeight: totalHeight
        )
        
        let metadataLine = makeMetadataLine(from: metadata)
        if !metadataLine.isEmpty {
            WatermarkRenderer.drawText(
                context: context,
                text: metadataLine,
                fontSize: metadataFontSize,
                weight: .medium,
                at: CGPoint(x: imageRightX, y: textCenterYFromTop),
                alignment: .trailing,
                contextHeight: totalHeight,
                color: CGColor(gray: 0.25, alpha: 1)
            )
        }
    }
    
    private func makeMetadataLine(from metadata: PhotoMetadata) -> String {
        var parts: [String] = []
        if metadata.focalLength != "-" {
            parts.append("FL \(metadata.focalLength)")
        }
        if metadata.aperture != "-" {
            parts.append(metadata.aperture)
        }
        if metadata.shutterSpeed != "-" {
            parts.append(metadata.shutterSpeed)
        }
        if metadata.iso != "-" {
            parts.append(metadata.iso)
        }
        return parts.joined(separator: " · ")
    }
}
