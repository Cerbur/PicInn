import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import CoreText

#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif

struct WatermarkRenderer {
    @MainActor
    static func render(
        image: PlatformImage,
        metadata: PhotoMetadata,
        brand: String,
        originalMetadata: [AnyHashable: Any]
    ) async -> Data? {
        guard let cgImage = image.cgImageSafe else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let imageAspectRatio = imageSize.width / imageSize.height
        
        // 使用原始图片的宽度作为渲染宽度
        let renderWidth = CGFloat(cgImage.width)
        
        // 计算图片在渲染宽度下的实际尺寸（保持宽高比）
        let imagePadding: CGFloat = 24 // 图片左右 padding
        let containerPadding: CGFloat = 64 // 整体左右 padding
        let imageWidth = renderWidth - containerPadding - (imagePadding * 2)
        let imageHeight = imageWidth / imageAspectRatio
        
        // 计算顶部和底部水印区域的高度
        let topPadding: CGFloat = 32
        let bottomPadding: CGFloat = 32
        let brandHeight: CGFloat = 50
        let paramsHeight: CGFloat = 30
        let spacing: CGFloat = 24
        
        let totalHeight = topPadding + brandHeight + spacing + imageHeight + spacing + paramsHeight + bottomPadding
        
        // 创建画布
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(renderWidth),
            height: Int(totalHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // 填充白色背景
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: renderWidth, height: totalHeight))
        
        // 布局顺序（从下到上，Core Graphics 坐标系）：
        // Y=0 (底部)
        // 1. bottomPadding = 32
        // 2. 参数（paramsHeight = 30，中心在 32 + 15 = 47）
        // 3. spacing = 24
        // 4. 图片（imageHeight，底部在 32 + 30 + 24 = 86）
        // 5. spacing = 24
        // 6. 品牌标签（brandHeight = 50，中心在 totalHeight - 32 - 25）
        // 7. topPadding = 32
        // Y=totalHeight (顶部)
        
        // 1. 绘制品牌标签（在照片上方，顶部）
        // 品牌标签中心距离顶部 = topPadding + brandHeight/2
        // 转换为从顶部开始的坐标系统
        let brandCenterYFromTop = topPadding + brandHeight / 2
        let brandText = brand.isEmpty ? metadata.cameraBrandLabel : brand
        drawText(
            context: context,
            text: brandText,
            fontSize: 26,
            weight: .black,
            at: CGPoint(x: renderWidth / 2, y: brandCenterYFromTop),
            alignment: .center,
            contextHeight: totalHeight
        )
        
        // 2. 绘制原图（在品牌下方，参数上方）
        // 图片底部距离画布底部 = bottomPadding + paramsHeight + spacing
        let imageBottomY = bottomPadding + paramsHeight + spacing
        let imageRect = CGRect(
            x: containerPadding / 2 + imagePadding,
            y: imageBottomY,
            width: imageWidth,
            height: imageHeight
        )
        context.draw(cgImage, in: imageRect)
        
        // 3. 绘制参数信息（在照片下方，底部）
        // 参数中心距离底部 = bottomPadding + paramsHeight/2
        // 转换为从顶部开始的坐标系统
        let paramsCenterYFromTop = totalHeight - (bottomPadding + paramsHeight / 2)
        let paramsY = paramsCenterYFromTop
        let paramsSpacing: CGFloat = 16
        let params: [(label: String, value: String)] = [
            ("FL", metadata.focalLength),
            ("Aperture", metadata.aperture),
            ("Shutter", metadata.shutterSpeed),
            ("ISO", metadata.iso.replacingOccurrences(of: "ISO", with: ""))
        ]
        
        // 计算总宽度
        var totalWidth: CGFloat = 0
        for param in params {
            let labelSize = measureText(param.label, fontSize: 14)
            let valueSize = measureText(param.value, fontSize: 14)
            totalWidth += labelSize.width + 4 + valueSize.width
        }
        totalWidth += CGFloat(params.count - 1) * paramsSpacing
        
        var currentX = (renderWidth - totalWidth) / 2
        
        for (index, param) in params.enumerated() {
            // 绘制标签（灰色）
            let labelSize = measureText(param.label, fontSize: 14)
            drawText(
                context: context,
                text: param.label,
                fontSize: 14,
                weight: .medium,
                at: CGPoint(x: currentX + labelSize.width / 2, y: paramsY),
                alignment: .center,
                contextHeight: totalHeight,
                color: CGColor(gray: 0.5, alpha: 1)
            )
            currentX += labelSize.width + 4
            
            // 绘制值（黑色）
            let valueSize = measureText(param.value, fontSize: 14)
            drawText(
                context: context,
                text: param.value,
                fontSize: 14,
                weight: .medium,
                at: CGPoint(x: currentX + valueSize.width / 2, y: paramsY),
                alignment: .center,
                contextHeight: totalHeight,
                color: CGColor(gray: 0, alpha: 1)
            )
            currentX += valueSize.width
            
            if index < params.count - 1 {
                currentX += paramsSpacing
            }
        }
        
        // 获取最终图片
        guard let finalCGImage = context.makeImage() else { return nil }
        
        // 保存为 JPEG，保留原始元数据
        let data = NSMutableData()
        let uti = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, uti, 1, nil) else {
            return nil
        }
        
        var combinedMetadata = originalMetadata
        combinedMetadata[kCGImagePropertyOrientation as String] = combinedMetadata[kCGImagePropertyOrientation as String] ?? 1
        
        CGImageDestinationAddImage(destination, finalCGImage, combinedMetadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
    
    private static func measureText(_ text: String, fontSize: CGFloat) -> CGSize {
        #if os(iOS) || os(tvOS)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes)
        #else
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes)
        #endif
    }
    
    private enum TextAlignment {
        case leading, center, trailing
    }
    
    private static func drawText(
        context: CGContext,
        text: String,
        fontSize: CGFloat,
        weight: Font.Weight,
        at point: CGPoint,
        alignment: TextAlignment,
        contextHeight: CGFloat,
        color: CGColor = CGColor(gray: 0, alpha: 1)
    ) {
        
        #if os(iOS) || os(tvOS)
        let nsWeight: UIFont.Weight
        switch weight {
        case .black: nsWeight = .black
        case .bold: nsWeight = .bold
        case .semibold: nsWeight = .semibold
        case .medium: nsWeight = .medium
        default: nsWeight = .regular
        }
        let font = UIFont.systemFont(ofSize: fontSize, weight: nsWeight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(cgColor: color)
        ]
        #else
        let nsWeight: NSFont.Weight
        switch weight {
        case .black: nsWeight = .black
        case .bold: nsWeight = .bold
        case .semibold: nsWeight = .semibold
        case .medium: nsWeight = .medium
        default: nsWeight = .regular
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: nsWeight)
        let nsColor = NSColor(cgColor: color) ?? NSColor.black
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: nsColor
        ]
        #endif
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        // 计算文本绘制位置（考虑对齐方式）
        var drawX = point.x
        switch alignment {
        case .center:
            drawX -= textSize.width / 2
        case .trailing:
            drawX -= textSize.width
        default:
            break
        }
        
        // 将 Y 坐标从顶部坐标系转换为 Core Graphics 坐标系（底部为原点）
        // point.y 是从顶部开始计算的，需要转换为从底部开始
        let centerY = contextHeight - point.y
        
        // 绘制文本
        context.saveGState()
        
        // 创建文本行
        let line = CTLineCreateWithAttributedString(attributedString)
        let lineBounds = CTLineGetBoundsWithOptions(line, [])
        
        // 计算文本的基线位置
        // lineBounds.origin.y 通常是负数（基线在底部，文本向上延伸）
        // 文本的中心点 Y 坐标减去文本高度的一半，得到文本顶部
        // 然后加上基线偏移（-lineBounds.origin.y），得到基线位置
        let textTop = centerY - textSize.height / 2
        let baselineY = textTop - lineBounds.origin.y
        
        // 设置文本矩阵（确保文字方向正确，不翻转 X 轴）
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: drawX, y: baselineY)
        
        // 绘制文本
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

struct WatermarkView: View {
    let platformImage: PlatformImage
    let metadata: PhotoMetadata
    let brand: String
    var containerSize: CGSize? = nil
    
    private var imageAspectRatio: CGFloat {
        platformImage.aspectRatio
    }
    
    // 使用原始图片宽度作为基础宽度
    private var baseRenderWidth: CGFloat {
        CGFloat(platformImage.cgImageSafe?.width ?? 1200)
    }
    
    private var baseImageWidth: CGFloat {
        baseRenderWidth - 64 - (24 * 2)
    }
    
    private var baseImageHeight: CGFloat {
        baseImageWidth / imageAspectRatio
    }
    
    private var baseTotalHeight: CGFloat {
        32 + 50 + 24 + baseImageHeight + 24 + 30 + 32
    }
    
    // 使用与渲染完全相同的布局计算逻辑
    private var scaleFactor: CGFloat {
        guard let containerSize = containerSize else {
            return 1.0
        }
        let widthScale = containerSize.width / baseRenderWidth
        let heightScale = containerSize.height > 0 ? containerSize.height / baseTotalHeight : 1.0
        let scale = min(widthScale, heightScale, 1.0)
        return max(scale, 0.05)
    }
    
    // 按比例缩放后的宽度
    private var scaledWidth: CGFloat {
        baseRenderWidth * scaleFactor
    }
    
    // 按比例缩放后的尺寸（与生成代码完全一致的计算逻辑）
    private var scaledTopPadding: CGFloat { 32 * scaleFactor }
    private var scaledBottomPadding: CGFloat { 32 * scaleFactor }
    private var scaledBrandHeight: CGFloat { 50 * scaleFactor }
    private var scaledParamsHeight: CGFloat { 30 * scaleFactor }
    private var scaledSpacing: CGFloat { 24 * scaleFactor }
    private var scaledImagePadding: CGFloat { 24 * scaleFactor }
    private var scaledSidePadding: CGFloat { 32 * scaleFactor }
    
    private var imageWidth: CGFloat {
        // 与生成代码完全一致：baseRenderWidth - 64 - 48
        (baseRenderWidth - 64 - (24 * 2)) * scaleFactor
    }
    
    private var imageHeight: CGFloat {
        imageWidth / imageAspectRatio
    }
    
    private var brandFontSize: CGFloat {
        26 * scaleFactor
    }
    
    private var paramsFontSize: CGFloat {
        14 * scaleFactor
    }
    
    private var paramsSpacing: CGFloat {
        16 * scaleFactor
    }

    var body: some View {
        VStack(spacing: scaledSpacing) {
            // 品牌标签（与生成代码完全一致，无阴影）
            // 使用标准系统字体，不使用 rounded design，与生成代码一致
            Text(brand.isEmpty ? metadata.cameraBrandLabel : brand)
                .font(.system(size: brandFontSize, weight: .black))
                .foregroundColor(.black)
                .kerning(1.2 * scaleFactor)
                .frame(height: scaledBrandHeight)

            // 照片（与生成代码完全一致：左右 padding 24，无阴影）
            Image(platformImage: platformImage)
                .resizable()
                .aspectRatio(imageAspectRatio, contentMode: .fit)
                .frame(width: imageWidth, height: imageHeight)
                .padding(.horizontal, scaledImagePadding)

            // 参数信息（与生成代码完全一致）
            // 使用标准系统字体，不使用 rounded design，与生成代码一致
            HStack(spacing: paramsSpacing) {
                LabelView(title: "FL", value: metadata.focalLength, fontSize: paramsFontSize)
                LabelView(title: "Aperture", value: metadata.aperture, fontSize: paramsFontSize)
                LabelView(title: "Shutter", value: metadata.shutterSpeed, fontSize: paramsFontSize)
                // ISO 值处理：移除重复的 "ISO"（与生成代码一致）
                LabelView(title: "ISO", value: metadata.iso.replacingOccurrences(of: "ISO", with: ""), fontSize: paramsFontSize)
            }
            .font(.system(size: paramsFontSize, weight: .medium))
            .frame(height: scaledParamsHeight)
        }
        .padding(scaledSidePadding) // 与生成代码一致：四周 padding 32
        .frame(width: scaledWidth)
        .background(Color.white)
    }
}

private struct LabelView: View {
    let title: String
    let value: String
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.black)
        }
        .font(.system(size: fontSize, weight: .medium, design: .rounded))
    }
}
