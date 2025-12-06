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

// MARK: - 水印模板枚举

enum WatermarkTemplateType: String, CaseIterable {
    case normal = "normal"
    case antiNormal = "antiNormal"
    case fusion = "fusion"
    
    var template: WatermarkTemplate {
        switch self {
        case .normal:
            return NormalTemplate()
        case .antiNormal:
            return AntiNormalTemplate()
        case .fusion:
            return FusionTemplate()
        }
    }
    
    var displayName: String {
        switch self {
        case .normal:
            return "标准"
        case .antiNormal:
            return "反向"
        case .fusion:
            return "叠框"
        }
    }
    
    var displayDescription: String {
        switch self {
        case .normal:
            return "品牌在上，参数在下"
        case .antiNormal:
            return "参数在上，品牌在下"
        case .fusion:
            return "窄边框，同列信息"
        }
    }
}

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

// MARK: - 反向模板（参数在上，品牌在下）

struct AntiNormalTemplate: WatermarkTemplate {
    let id: String = "antiNormal"
    let name: String = "反向"
    let description: String = "参数在上，品牌在下"
    
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
        
        // 1. 绘制参数信息（顶部）
        let paramsCenterYFromTop = topPadding + paramsHeight / 2
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
        
        // 2. 绘制原图（参数下方）
        let imageBottomY = bottomPadding + brandHeight + spacing
        let imageRect = CGRect(
            x: containerPadding / 2 + imagePadding,
            y: imageBottomY,
            width: imageWidth,
            height: imageHeight
        )
        context.draw(cgImage, in: imageRect)
        
        // 3. 绘制品牌标签（底部）
        let brandCenterYFromTop = totalHeight - (bottomPadding + brandHeight / 2)
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
    }
}

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
        let topPadding = 32 * scaleFactor
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

struct WatermarkRenderer {
    @MainActor
    static func render(
        image: PlatformImage,
        metadata: PhotoMetadata,
        brand: String,
        originalMetadata: [AnyHashable: Any],
        template: WatermarkTemplateType = .normal
    ) async -> Data? {
        guard let cgImage = image.cgImageSafe else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let imageAspectRatio = imageSize.width / imageSize.height
        
        // 使用原始图片的宽度作为渲染宽度
        let renderWidth = CGFloat(cgImage.width)
        
        // 基准宽度（用于计算缩放因子）
        let baseWidth: CGFloat = 1200
        let scaleFactor = renderWidth / baseWidth
        
        // 所有尺寸都根据缩放因子动态调整
        let imagePadding = 24 * scaleFactor
        let containerPadding = 64 * scaleFactor
        let topPadding = 32 * scaleFactor
        let bottomPadding = 32 * scaleFactor
        let brandHeight = 50 * scaleFactor
        let paramsHeight = 30 * scaleFactor
        let spacing = 24 * scaleFactor
        
        // 计算图片在渲染宽度下的实际尺寸（保持宽高比）
        let imageWidth = renderWidth - containerPadding - (imagePadding * 2)
        let imageHeight = imageWidth / imageAspectRatio
        
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
        
        // 使用模板来渲染内容
        let templateInstance = template.template
        await templateInstance.render(
            context: context,
            image: cgImage,
            metadata: metadata,
            brand: brand,
            renderWidth: renderWidth,
            scaleFactor: scaleFactor,
            totalHeight: totalHeight
        )
        
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
    
    static func measureText(_ text: String, fontSize: CGFloat) -> CGSize {
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
    
    enum TextAlignment {
        case leading, center, trailing
    }
    
    static func drawText(
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
    var template: WatermarkTemplateType = .normal
    
    private var imageAspectRatio: CGFloat {
        platformImage.aspectRatio
    }
    
    // 使用原始图片宽度作为基础渲染宽度（与生成逻辑完全一致）
    private var baseRenderWidth: CGFloat {
        CGFloat(platformImage.cgImageSafe?.width ?? 1200)
    }
    
    // 基准宽度为 1200，基于此计算分辨率缩放因子（与生成逻辑完全一致）
    private var resolutionScaleFactor: CGFloat {
        baseRenderWidth / 1200.0
    }
    
    // 计算原始布局高度（与生成逻辑一致）
    private var baseLayoutHeight: CGFloat {
        let topPadding = 32 * resolutionScaleFactor
        let brandHeight = 50 * resolutionScaleFactor
        let spacing = 24 * resolutionScaleFactor
        let paramsHeight = 30 * resolutionScaleFactor
        let bottomPadding = 32 * resolutionScaleFactor
        let imagePadding = 24 * resolutionScaleFactor
        
        let containerPadding = 64 * resolutionScaleFactor
        let imageWidth = baseRenderWidth - containerPadding - (imagePadding * 2)
        let imageHeight = imageWidth / imageAspectRatio
        
        return topPadding + brandHeight + spacing + imageHeight + spacing + paramsHeight + bottomPadding
    }
    
    // 计算预览缩放因子（缩放整个布局以适应容器）
    private var previewScaleFactor: CGFloat {
        guard let containerSize = containerSize else { return 1.0 }
        
        let widthScale = containerSize.width / baseRenderWidth
        let heightScale = containerSize.height > 0 ? containerSize.height / baseLayoutHeight : 1.0
        let scale = min(widthScale, heightScale, 1.0)
        return max(scale, 0.05)
    }
    
    // 与生成代码完全相同的尺寸计算，但额外乘以预览缩放因子
    private var topPadding: CGFloat { 32 * resolutionScaleFactor * previewScaleFactor }
    private var bottomPadding: CGFloat { 32 * resolutionScaleFactor * previewScaleFactor }
    private var brandHeight: CGFloat { 50 * resolutionScaleFactor * previewScaleFactor }
    private var paramsHeight: CGFloat { 30 * resolutionScaleFactor * previewScaleFactor }
    private var spacing: CGFloat { 24 * resolutionScaleFactor * previewScaleFactor }
    private var imagePadding: CGFloat { 24 * resolutionScaleFactor * previewScaleFactor }
    private var containerPadding: CGFloat { 64 * resolutionScaleFactor * previewScaleFactor }
    private var sidePadding: CGFloat { 32 * resolutionScaleFactor * previewScaleFactor }
    
    // 照片尺寸（与生成逻辑完全一致）
    private var imageWidth: CGFloat {
        (baseRenderWidth - 64 * resolutionScaleFactor - (24 * 2 * resolutionScaleFactor)) * previewScaleFactor
    }
    
    private var imageHeight: CGFloat {
        imageWidth / imageAspectRatio
    }
    
    private var brandFontSize: CGFloat {
        26 * resolutionScaleFactor * previewScaleFactor
    }
    
    private var paramsFontSize: CGFloat {
        14 * resolutionScaleFactor * previewScaleFactor
    }
    
    private var paramsSpacing: CGFloat {
        16 * resolutionScaleFactor * previewScaleFactor
    }
    
    private var fusionBottomHeight: CGFloat {
        brandHeight + paramsHeight + spacing
    }
    
    private var fusionBorderThickness: CGFloat {
        spacing
    }
    
    private var fusionBorderColor: Color {
        Color(.sRGBLinear, white: 0.93, opacity: 1)
    }
    
    private var displayBrand: String {
        brand.isEmpty ? metadata.cameraBrandLabel : brand
    }
    
    private var metadataLine: String {
        var parts: [String] = []
        if metadata.focalLength != "-" { parts.append("FL \(metadata.focalLength)") }
        if metadata.aperture != "-" { parts.append(metadata.aperture) }
        if metadata.shutterSpeed != "-" { parts.append(metadata.shutterSpeed) }
        if metadata.iso != "-" { parts.append(metadata.iso) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch template {
            case .normal:
                normalView
            case .antiNormal:
                antiNormalView
            case .fusion:
                fusionView
            }
        }
        .padding(.horizontal, containerPadding / 2)
        .frame(maxWidth: baseRenderWidth * previewScaleFactor, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
    
    private var normalView: some View {
        VStack(spacing: spacing) {
            Text(displayBrand)
                .font(.system(size: brandFontSize, weight: .black))
                .foregroundColor(.black)
                .kerning(1.2 * previewScaleFactor)
                .frame(height: brandHeight)
                .lineLimit(1)
            Image(platformImage: platformImage)
                .resizable()
                .aspectRatio(imageAspectRatio, contentMode: .fit)
            parameterRow
        }
    }
    
    private var antiNormalView: some View {
        VStack(spacing: spacing) {
            parameterRow
            Image(platformImage: platformImage)
                .resizable()
                .aspectRatio(imageAspectRatio, contentMode: .fit)
            Text(displayBrand)
                .font(.system(size: brandFontSize, weight: .black))
                .foregroundColor(.black)
                .kerning(1.2 * previewScaleFactor)
                .frame(height: brandHeight)
                .lineLimit(1)
        }
    }
    
    private var fusionView: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topPadding)
            VStack(spacing: 0) {
                fusionBorderColor
                    .frame(height: fusionBorderThickness)
                HStack(spacing: 0) {
                    fusionBorderColor
                        .frame(width: fusionBorderThickness)
                    Image(platformImage: platformImage)
                        .resizable()
                        .aspectRatio(imageAspectRatio, contentMode: .fit)
                    fusionBorderColor
                        .frame(width: fusionBorderThickness)
                }
                ZStack {
                    fusionBorderColor
                    HStack {
                        Text(displayBrand)
                            .font(.system(size: brandFontSize * 0.85, weight: .black))
                            .foregroundColor(.black)
                        Spacer()
                        Text(metadataLine)
                            .font(.system(size: paramsFontSize * 0.95, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, fusionBorderThickness)
                }
                .frame(height: fusionBottomHeight)
            }
            Color.clear.frame(height: bottomPadding)
        }
    }
    
    private var parameterRow: some View {
        HStack(spacing: paramsSpacing) {
            LabelView(title: "FL", value: metadata.focalLength, fontSize: paramsFontSize)
            LabelView(title: "Aperture", value: metadata.aperture, fontSize: paramsFontSize)
            LabelView(title: "Shutter", value: metadata.shutterSpeed, fontSize: paramsFontSize)
            LabelView(title: "ISO", value: metadata.iso.replacingOccurrences(of: "ISO", with: ""), fontSize: paramsFontSize)
        }
        .font(.system(size: paramsFontSize, weight: .medium))
        .frame(height: paramsHeight)
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
