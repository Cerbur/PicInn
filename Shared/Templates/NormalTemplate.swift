import SwiftUI
import CoreGraphics

// MARK: - 标准模板（品牌在上，参数在下）

struct NormalTemplate: WatermarkTemplate {
    let id: String = "normal"
    let name: String = "标准"
    let description: String = "品牌在上，参数在下"
    
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
        
        // 计算所有尺寸
        let imagePadding = 24 * scaleFactor
        let containerPadding = 64 * scaleFactor
        let topPadding = 32 * scaleFactor
        let bottomPadding = 32 * scaleFactor
        let brandHeight = 50 * scaleFactor
        let paramsHeight = 30 * scaleFactor
        let spacing = 24 * scaleFactor
        
        let imageWidth = renderWidth - containerPadding - (imagePadding * 2)
        let imageHeight = imageWidth / imageAspectRatio
        
        // 1. 绘制品牌标签（顶部）
        let brandCenterYFromTop = topPadding + brandHeight / 2
        let brandText = brand.isEmpty ? metadata.cameraBrandLabel : brand
        let brandFontSize = 26 * scaleFactor
        
        WatermarkRenderer.drawText(
            context: context,
            text: brandText,
            fontSize: brandFontSize,
            weight: .black,
            at: CGPoint(x: renderWidth / 2, y: brandCenterYFromTop),
            alignment: .center,
            contextHeight: totalHeight
        )
        
        // 2. 绘制原图（品牌下方）
        let imageBottomY = bottomPadding + paramsHeight + spacing
        let imageRect = CGRect(
            x: containerPadding / 2 + imagePadding,
            y: imageBottomY,
            width: imageWidth,
            height: imageHeight
        )
        context.draw(cgImage, in: imageRect)
        
        // 3. 绘制参数信息（底部）
        let paramsCenterYFromTop = totalHeight - (bottomPadding + paramsHeight / 2)
        let paramsFontSize = 14 * scaleFactor
        let paramsSpacing = 16 * scaleFactor
        let params: [(label: String, value: String)] = [
            ("FL", metadata.focalLength),
            ("Aperture", metadata.aperture),
            ("Shutter", metadata.shutterSpeed),
            ("ISO", metadata.iso.replacingOccurrences(of: "ISO", with: ""))
        ]
        
        // 计算总宽度
        var totalWidth: CGFloat = 0
        for param in params {
            let labelSize = WatermarkRenderer.measureText(param.label, fontSize: paramsFontSize)
            let valueSize = WatermarkRenderer.measureText(param.value, fontSize: paramsFontSize)
            totalWidth += labelSize.width + (4 * scaleFactor) + valueSize.width
        }
        totalWidth += CGFloat(params.count - 1) * paramsSpacing
        
        var currentX = (renderWidth - totalWidth) / 2
        
        for (index, param) in params.enumerated() {
            let labelSize = WatermarkRenderer.measureText(param.label, fontSize: paramsFontSize)
            WatermarkRenderer.drawText(
                context: context,
                text: param.label,
                fontSize: paramsFontSize,
                weight: .medium,
                at: CGPoint(x: currentX + labelSize.width / 2, y: paramsCenterYFromTop),
                alignment: .center,
                contextHeight: totalHeight,
                color: CGColor(gray: 0.5, alpha: 1)
            )
            currentX += labelSize.width + (4 * scaleFactor)
            
            let valueSize = WatermarkRenderer.measureText(param.value, fontSize: paramsFontSize)
            WatermarkRenderer.drawText(
                context: context,
                text: param.value,
                fontSize: paramsFontSize,
                weight: .medium,
                at: CGPoint(x: currentX + valueSize.width / 2, y: paramsCenterYFromTop),
                alignment: .center,
                contextHeight: totalHeight,
                color: CGColor(gray: 0, alpha: 1)
            )
            currentX += valueSize.width
            
            if index < params.count - 1 {
                currentX += paramsSpacing
            }
        }
    }
}
