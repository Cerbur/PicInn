import SwiftUI
import PhotosUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject private var processor = PhotoProcessor()
    @State private var brand: String = "Nikon"
    @State private var showShareSheet = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    heroHeader
                    
                    GlassCard {
                        VStack(spacing: 10) {
                            SectionHeader(icon: "photo.stack", title: "素材管理", subtitle: "批量导入并为作品添加品牌标签")
                            pickerRow
                            brandField
                        }
                    }
                    
                    GlassCard {
                        VStack(spacing: 10) {
                            SectionHeader(icon: "rectangle.stack.person.crop", title: "实时预览", subtitle: "以原始分辨率查看水印效果")
                            previewSection(containerSize: geometry.size)
                        }
                    }
                    
                    GlassCard {
                        VStack(spacing: 10) {
                            SectionHeader(icon: "sparkles", title: "生成与导出", subtitle: "统一的水印参数与快速分享")
                            actionSection
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, max(geometry.safeAreaInsets.top + 8, 8))
                .padding(.bottom, max(geometry.safeAreaInsets.bottom + 8, 8))
                .padding(.horizontal, max(geometry.safeAreaInsets.leading + 12, 12))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(backgroundLayer.ignoresSafeArea())
        }
    }

    private var brandField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("品牌标签")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                Image(systemName: "tag")
                    .foregroundColor(accentColor)
                    .font(.caption2)
                    .padding(7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentColor.opacity(0.15))
                    )
                
                TextField("例如 Nikon / Canon / Sony", text: $brand)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var pickerRow: some View {
        PhotosPicker(
            selection: $processor.pickerItems,
            maxSelectionCount: nil,
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(processor.isLoadingSelection ? "导入中…" : "选择照片")
                        .font(.subheadline.weight(.semibold))
                    Text("RAW、HEIC、JPEG 格式，自动解析 EXIF")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if processor.isLoadingSelection {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .disabled(processor.isRendering || processor.isLoadingSelection)
        .onChange(of: processor.pickerItems) { _ in
            processor.loadSelectedItems()
        }
    }

    @ViewBuilder
    private func previewSection(containerSize: CGSize) -> some View {
        let responsiveSize = CGSize(
            width: containerSize.width,
            height: max(containerSize.height * 0.45, 240)
        )
        if !processor.photos.isEmpty {
            CarouselPreview(
                processor: processor,
                brand: brand,
                containerSize: responsiveSize
            )
        } else if processor.isLoadingSelection {
            previewStateCard(
                icon: "cube.transparent",
                title: "正在创建预览",
                message: "PicInn 正在加载你的原始文件",
                progress: processor.selectionProgress
            )
        } else {
            previewStateCard(
                icon: "sparkles.rectangle.stack",
                title: "开始创作",
                message: "导入照片后即可在此实时预览水印效果"
            )
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    processor.renderWatermarked(brand: brand.isEmpty ? "Nikon" : brand)
                } label: {
                    Label(processor.isRendering ? "生成中…" : "生成水印", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(processor.photos.isEmpty || processor.isRendering || processor.isLoadingSelection)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(processor.photos.isEmpty ? "先导入照片" : "输出 JPEG")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if !processor.photos.isEmpty {
                        Text("\(processor.photos.count) 张待处理")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            statsRow
            
            if processor.isLoadingSelection {
                ProgressView(value: processor.selectionProgress, total: 1.0) {
                    Text("加载照片 \(Int(processor.selectionProgress * 100))%")
                }
            } else if processor.isRendering {
                ProgressView(value: processor.renderingProgress) {
                    Text("生成水印 \(Int(processor.renderingProgress * 100))%")
                }
            }
            
            if !processor.photos.isEmpty && processor.photos.allSatisfy({ $0.renderedData != nil }) {
                ExportBar(photos: processor.photos)
            }
            
            if let error = processor.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.pink)
            }
        }
    }
    
    private var statsRow: some View {
        let total = processor.photos.count
        let rendered = processor.photos.filter { $0.renderedData != nil }.count
        let pending = max(total - rendered, 0)
        
        return HStack(spacing: 12) {
            MetricPill(label: "已导入", value: "\(total)")
            MetricPill(label: "已生成", value: "\(rendered)")
            MetricPill(label: "待处理", value: "\(pending)")
        }
    }
    
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PicInn")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            
            Text("Liquid Glass · Batch Watermark Studio")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Text("导入、预览、导出，一气呵成。以原图分辨率保留每个瞬间的质感。")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
    
    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.17),
                    Color(red: 0.04, green: 0.11, blue: 0.26),
                    Color(red: 0.05, green: 0.18, blue: 0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .blendMode(.softLight)
                .opacity(0.4)
                .ignoresSafeArea()
        }
    }
    
    private func previewStateCard(icon: String, title: String, message: String, progress: Double? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(accentColor)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                )
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let progress {
                ProgressView(value: progress, total: 1.0)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var accentColor: Color {
        Color(red: 0.37, green: 0.52, blue: 0.98)
    }
    
}

private struct CarouselPreview: View {
    @ObservedObject var processor: PhotoProcessor
    let brand: String
    let containerSize: CGSize
    
    private var previewAreaHeight: CGFloat {
        let adjusted = containerSize.height - 260
        return min(max(adjusted, 220), 720)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            previewContent
            
            // 照片计数和索引指示器
            HStack {
                Text("\(processor.currentIndex + 1) / \(processor.photos.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if processor.photos.count > 1 {
                    #if os(iOS)
                    Text("左右滑动查看")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    #else
                    HStack(spacing: 8) {
                        Button {
                            if processor.currentIndex > 0 {
                                processor.currentIndex -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(processor.currentIndex == 0)
                        
                        Text("双指滑动或使用箭头")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            if processor.currentIndex < processor.photos.count - 1 {
                                processor.currentIndex += 1
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(processor.currentIndex == processor.photos.count - 1)
                    }
                    #endif
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var previewContent: some View {
        GeometryReader { geometry in
            TabView(selection: $processor.currentIndex) {
                ForEach(Array(processor.photos.enumerated()), id: \.element.id) { index, photo in
                    previewPage(
                        for: photo,
                        maxSize: CGSize(
                            width: max(geometry.size.width - 64, 220),
                            height: previewAreaHeight
                        )
                    )
                    .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            #else
            .scrollTargetBehavior(.paging)
            .gesture(
                MagnificationGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
            .overlay(
                TrackpadGestureBridge(
                    onChanged: { translation in
                        // 处理触摸板滑动中
                    },
                    onEnded: { translation in
                        handleTrackpadSwipe(translation: translation)
                    }
                )
            )
            #endif
        }
        .frame(height: previewAreaHeight)
    }
    
    #if os(macOS)
    private func handleTrackpadSwipe(translation: CGFloat) {
        let threshold: CGFloat = 10 // 最小滑动距离
        
        if translation < -threshold {
            // 向左滑动 -> 下一张
            if processor.currentIndex < processor.photos.count - 1 {
                withAnimation(.easeInOut(duration: 0.25)) {
                    processor.currentIndex += 1
                }
            }
        } else if translation > threshold {
            // 向右滑动 -> 上一张
            if processor.currentIndex > 0 {
                withAnimation(.easeInOut(duration: 0.25)) {
                    processor.currentIndex -= 1
                }
            }
        }
    }
    #endif
    
    @ViewBuilder
    private func previewPage(for photo: PhotoItem, maxSize: CGSize) -> some View {
        ZStack {
            WatermarkPreview(
                image: photo.image,
                metadata: photo.metadata,
                brand: brand,
                containerSize: maxSize
            )
            // 修正：只在生成水印任务中且当前照片还未渲染出来时显示蒙层
            if processor.isRendering && photo.renderedData == nil {
                Color.white.opacity(0.6)
                    .frame(width: maxSize.width, height: maxSize.height)
                    .overlay(
                        ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(2)
                    )
            }
        }
    }
}

private struct WatermarkPreview: View {
    let image: PlatformImage
    let metadata: PhotoMetadata
    let brand: String
    let containerSize: CGSize
    
    private var innerSize: CGSize {
        CGSize(
            width: max(containerSize.width - 32, 120),
            height: max(containerSize.height - 32, 120)
        )
    }
    
    var body: some View {
        WatermarkView(
            platformImage: image,
            metadata: metadata,
            brand: brand,
            containerSize: innerSize
        )
        .frame(width: innerSize.width, height: innerSize.height)
        .padding(16)
        // 移除阴影，确保与生成的照片完全一致
        .frame(width: containerSize.width, height: containerSize.height)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thickMaterial)
        )
        .cornerRadius(12)
    }
}

private struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.headline.bold())
                .foregroundColor(.white)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

private struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)
    }
}

private struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

private struct MetricPill: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct ExportBar: View {
    let photos: [PhotoItem]
    @State private var shareURLs: [URL] = []
    @State private var showShare = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("已生成 \(photos.count) 张照片")
                    .font(.subheadline.bold())
                Spacer()
            }
            
            #if os(iOS)
            Button {
                shareURLs = makeTemporaryFiles()
                showShare = !shareURLs.isEmpty
            } label: {
                Label("分享或保存到系统相册", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(photos.contains(where: { $0.renderedData == nil }))
            .sheet(isPresented: $showShare) {
                if !shareURLs.isEmpty {
                    ActivityView(activityItems: shareURLs)
                }
            }
            #else
            Button {
                saveToDownloads()
            } label: {
                Label("保存到下载文件夹", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(photos.contains(where: { $0.renderedData == nil }))
            #endif
        }
    }

    #if os(macOS)
    private func saveToDownloads() {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let downloadsURL else { return }
        
        for (index, photo) in photos.enumerated() {
            guard let data = photo.renderedData else { continue }
            let url = downloadsURL.appendingPathComponent("PicInn-\(Int(Date().timeIntervalSince1970))-\(index + 1).jpg")
            try? data.write(to: url)
        }
    }
    #else
    private func makeTemporaryFiles() -> [URL] {
        var urls: [URL] = []
        for photo in photos {
            guard let data = photo.renderedData else { continue }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("PicInn-\(UUID().uuidString).jpg")
            do {
                try data.write(to: url)
                urls.append(url)
            } catch {
                continue
            }
        }
        return urls
    }
    #endif
}

#if os(macOS)
private struct TrackpadGestureBridge: NSViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }
    
    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        view.postsFrameChangedNotifications = true
        return view
    }
    
    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }
    
    final class TrackingView: NSView {
        weak var coordinator: Coordinator?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self)
        }
        
        override func scrollWheel(with event: NSEvent) {
            coordinator?.handleScroll(
                deltaX: event.scrollingDeltaX,
                deltaY: event.scrollingDeltaY,
                phase: event.phase,
                momentumPhase: event.momentumPhase
            )
        }
    }
    
    final class Coordinator: NSObject {
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void
        private var accumulated: CGFloat = 0
        private var verticalDelta: CGFloat = 0
        private var hasActiveGesture = false
        
        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping (CGFloat) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }
        
        func handleScroll(deltaX: CGFloat, deltaY: CGFloat, phase: NSEvent.Phase, momentumPhase: NSEvent.Phase) {
            if phase.contains(.began) || phase.contains(.mayBegin) {
                accumulated = 0
                verticalDelta = 0
                hasActiveGesture = true
            }
            
            verticalDelta += abs(deltaY)
            accumulated += deltaX
            
            let horizontal = abs(accumulated)
            let ratio = horizontal + verticalDelta == 0 ? 1 : horizontal / (horizontal + verticalDelta)
            let adjusted = accumulated * ratio
            onChanged(adjusted)
            
            if shouldFinish(phase: phase, momentumPhase: momentumPhase) && hasActiveGesture {
                hasActiveGesture = false
                onEnded(accumulated)
                accumulated = 0
                verticalDelta = 0
            }
        }
        
        private func shouldFinish(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase) -> Bool {
            if momentumPhase.contains(.began) || momentumPhase.contains(.changed) {
                return false
            }
            if momentumPhase.contains(.ended) || momentumPhase.contains(.cancelled) {
                return true
            }
            return phase.contains(.ended) || phase.contains(.cancelled)
        }
    }
}
#endif

#if os(iOS)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
#endif
