import LinkPresentation
import UIKit
import ImageIO

/// Fetch only on explicit insertion/refresh. Cached thumbnails remain usable offline.
@MainActor enum NoteLinkPreview {
    struct Preview { var title: String; var image: Data }
    static func load(_ url: URL) async -> Preview? {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        let provider = LPMetadataProvider()
        provider.timeout = 12
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
        var image = Data()
        if let item = metadata.imageProvider ?? metadata.iconProvider {
            let bytes: Data? = await withCheckedContinuation { continuation in
                item.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in continuation.resume(returning: data) }
            }
            if let bytes, bytes.count <= 32 * 1024 * 1024,
               let source = CGImageSourceCreateWithData(bytes as CFData, nil),
               let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1024, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) {
                image = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.8) ?? Data()
            }
        }
        return Preview(title: String((metadata.title ?? url.host ?? url.absoluteString).prefix(2000)), image: image)
    }
}
