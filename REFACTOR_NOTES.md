# 水印模板架构重构

## 目录结构

```
Shared/
├── WatermarkRenderer.swift
├── Templates/
│   ├── WatermarkTemplate.swift          # 模板协议
│   ├── WatermarkTemplateType.swift      # 模板枚举
│   ├── NormalTemplate.swift             # 标准模板
│   ├── AntiNormalTemplate.swift         # 反向模板
│   └── FusionTemplate.swift             # 叠框模板
```

## 重构内容

### 文件拆分
- **WatermarkTemplate.swift**: 模板协议定义，所有模板需要实现该协议
- **WatermarkTemplateType.swift**: 模板枚举，管理模板的注册与选择
- **NormalTemplate.swift**: 品牌在上，参数在下的标准布局
- **AntiNormalTemplate.swift**: 参数在上，品牌在下的反向布局
- **FusionTemplate.swift**: 带边框的叠框布局
- **WatermarkRenderer.swift**: 核心渲染引擎（从 805 行 → 407 行）

## 优势

1. **代码组织**: 每个模板独立为一个文件，易于维护和扩展
2. **可扩展性**: 添加新模板时，只需：
   - 在 `Templates/` 文件夹创建新文件
   - 实现 `WatermarkTemplate` 协议
   - 在 `WatermarkTemplateType` 中添加新 case
3. **行数优化**: WatermarkRenderer 主文件从 805 行减少到 407 行
4. **单一职责**: 每个文件只关注一个模板的逻辑

## 添加新模板的步骤

1. 在 `Templates/` 下创建 `NewTemplate.swift`
2. 实现 `WatermarkTemplate` 协议
3. 在 `WatermarkTemplateType.swift` 中添加:
   ```swift
   case newTemplate = "newTemplate"
   
   var template: WatermarkTemplate {
       switch self {
       case .newTemplate:
           return NewTemplate()
       // ...
       }
   }
   ```
