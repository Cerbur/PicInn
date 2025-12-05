import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var processor = PhotoProcessor()
    @State private var brand: String = "Nikon"
    @State private var showShareSheet = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    Text("PicInn · 照片水印")
                        .font(.title2.bold())

                    PhotosPicker(
                        selection: $processor.pickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("选择照片", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .onChange(of: processor.pickerItem) { _ in
                        processor.loadSelectedItem()
                    }

                    brandInput

                    if let image = processor.originalImage, let metadata = processor.displayedMetadata {
                        WatermarkPreview(
                            image: image,
                            metadata: metadata,
                            brand: brand,
                            containerWidth: geometry.size.width
                        )
                    } else {
                        placeholder
                    }

                    actionButtons

                    if let data = processor.renderedImageData {
                        ExportBar(imageData: data)
                    }

                    if let error = processor.errorMessage {
                        Text(error).foregroundColor(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var brandInput: some View {
        HStack {
            Text("品牌标签：")
            TextField("例如 Nikon / Canon / Sony", text: $brand)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                processor.renderWatermarked(brand: brand.isEmpty ? "Nikon" : brand)
            } label: {
                Label(processor.isRendering ? "生成中..." : "生成水印", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(processor.originalImage == nil || processor.isRendering)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(style: .init(lineWidth: 1, dash: [6]))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: 320)
            .overlay {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("选择一张照片开始")
                        .foregroundColor(.secondary)
                }
            }
    }
}

private struct WatermarkPreview: View {
    let image: PlatformImage
    let metadata: PhotoMetadata
    let brand: String
    let containerWidth: CGFloat
    
    var body: some View {
        WatermarkView(
            platformImage: image,
            metadata: metadata,
            brand: brand,
            containerWidth: containerWidth - 32
        )
        .shadow(radius: 4)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(white: 0.97))
        .cornerRadius(12)
    }
}

private struct ExportBar: View {
    let imageData: Data
    @State private var shareURL: URL?
    @State private var showShare = false

    var body: some View {
        HStack {
            Text("已生成，点击分享或保存。")
            Spacer()
            #if os(iOS)
            Button {
                shareURL = makeTemporaryFile()
                showShare = shareURL != nil
            } label: {
                Label("分享/保存", systemImage: "square.and.arrow.up")
            }
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ActivityView(activityItems: [url])
                }
            }
            #else
            Button {
                saveToDownloads()
            } label: {
                Label("保存 JPG", systemImage: "square.and.arrow.down")
            }
            #endif
        }
        .padding(12)
        .background(Color(white: 0.95))
        .cornerRadius(12)
    }

    #if os(macOS)
    private func saveToDownloads() {
        let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PicInn-\(Int(Date().timeIntervalSince1970)).jpg")
        guard let url else { return }
        try? imageData.write(to: url)
    }
    #else
    private func makeTemporaryFile() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PicInn-\(UUID().uuidString).jpg")
        do {
            try imageData.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    #endif
}

#if os(iOS)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
#endif

