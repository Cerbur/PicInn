import Foundation
import SwiftUI
import PhotosUI
import ImageIO

struct PhotoItem: Identifiable {
    let id: UUID
    let image: PlatformImage
    let metadata: PhotoMetadata
    let originalMetadata: [AnyHashable: Any]
    var renderedData: Data?
    
    init(id: UUID = UUID(), image: PlatformImage, metadata: PhotoMetadata, originalMetadata: [AnyHashable: Any], renderedData: Data? = nil) {
        self.id = id
        self.image = image
        self.metadata = metadata
        self.originalMetadata = originalMetadata
        self.renderedData = renderedData
    }
}

@MainActor
final class PhotoProcessor: ObservableObject {
    @Published var pickerItems: [PhotosPickerItem] = []
    @Published var photos: [PhotoItem] = []
    @Published var currentIndex: Int = 0
    @Published var isRendering = false
    @Published var errorMessage: String?
    @Published var renderingProgress: Double = 0.0
    @Published var isLoadingSelection = false
    @Published var selectionProgress: Double = 0.0
    @Published var selectedTemplate: WatermarkTemplateType = .normal

    func loadSelectedItems() {
        guard !pickerItems.isEmpty else { return }
        
        // 在主线程上获取 pickerItems 的副本
        let itemsToLoad = pickerItems
        let totalCount = itemsToLoad.count
        
        photos = []
        currentIndex = 0
        errorMessage = nil
        isLoadingSelection = true
        selectionProgress = 0.0
        
        Task.detached(priority: .userInitiated) { [weak self] in
            var loadedPhotos: [PhotoItem] = []
            
            for (index, item) in itemsToLoad.enumerated() {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        continue
                    }
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let image = PlatformImage(data: data) else {
                        continue
                    }
                    
                    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] ?? [:]
                    let metadata = PhotoMetadata.from(properties: properties)
                    
                    let photoItem = PhotoItem(
                        image: image,
                        metadata: metadata,
                        originalMetadata: properties
                    )
                    loadedPhotos.append(photoItem)
                    
                    // 更新进度
                    await MainActor.run {
                        self?.selectionProgress = Double(index + 1) / Double(totalCount)
                    }
                } catch {
                    await MainActor.run {
                        self?.errorMessage = "加载照片失败: \(error.localizedDescription)"
                    }
                }
            }
            
            await MainActor.run {
                self?.photos = loadedPhotos
                self?.currentIndex = 0
                self?.selectionProgress = 0.0
                self?.isLoadingSelection = false
            }
        }
    }

    func renderWatermarked(brand: String) {
        guard !photos.isEmpty, !isLoadingSelection else { return }
        isRendering = true
        renderingProgress = 0.0
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            var updatedPhotos = self.photos
            
            for (index, photo) in updatedPhotos.enumerated() {
                let result = await WatermarkRenderer.render(
                    image: photo.image,
                    metadata: photo.metadata,
                    brand: brand,
                    originalMetadata: photo.originalMetadata,
                    template: self.selectedTemplate
                )
                
                updatedPhotos[index].renderedData = result
                self.renderingProgress = Double(index + 1) / Double(updatedPhotos.count)
            }
            
            self.photos = updatedPhotos
            self.isRendering = false
            
            if updatedPhotos.allSatisfy({ $0.renderedData == nil }) {
                self.errorMessage = "导出失败，请重试。"
            }
        }
    }
    
    func updateTemplate(_ template: WatermarkTemplateType) {
        selectedTemplate = template
        invalidateRenderedPhotos()
    }
    
    var currentPhoto: PhotoItem? {
        guard currentIndex >= 0 && currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }
    
    func invalidateRenderedPhotos() {
        guard !photos.isEmpty else { return }
        for index in photos.indices {
            photos[index].renderedData = nil
        }
        renderingProgress = 0.0
    }
}
