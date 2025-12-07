import SwiftUI

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
