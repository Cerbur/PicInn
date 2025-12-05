import Foundation
import SwiftUI
import PhotosUI
import ImageIO

@MainActor
final class PhotoProcessor: ObservableObject {
    @Published var pickerItem: PhotosPickerItem?
    @Published var originalImage: PlatformImage?
    @Published var displayedMetadata: PhotoMetadata?
    @Published var renderedImageData: Data?
    @Published var isRendering = false
    @Published var errorMessage: String?

    private var originalMetadata: [AnyHashable: Any] = [:]

    func loadSelectedItem() {
        guard let item = pickerItem else { return }

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(domain: "PicInn", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取照片数据"])
                }
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = PlatformImage(data: data) else {
                    throw NSError(domain: "PicInn", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法解析图片"])
                }

                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] ?? [:]
                let metadata = PhotoMetadata.from(properties: properties)

                await MainActor.run {
                    self?.originalImage = image
                    self?.displayedMetadata = metadata
                    self?.originalMetadata = properties
                    self?.renderedImageData = nil
                    self?.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func renderWatermarked(brand: String) {
        guard let image = originalImage, let metadata = displayedMetadata else { return }
        isRendering = true

        Task { @MainActor [weak self] in
            let result = await WatermarkRenderer.render(
                image: image,
                metadata: metadata,
                brand: brand,
                originalMetadata: self?.originalMetadata ?? [:]
            )
            self?.renderedImageData = result
            self?.isRendering = false
            if result == nil {
                self?.errorMessage = "导出失败，请重试。"
            }
        }
    }
}

