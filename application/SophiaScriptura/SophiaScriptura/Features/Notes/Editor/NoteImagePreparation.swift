import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A serial worker bounds concurrent image decoding and keeps it off the main actor.
enum NoteImagePreparation {
    struct Prepared: Sendable {
        let data: Data
        let size: CGSize
    }
    private static let worker = DispatchQueue(label: "Sophia.Notes.imagePreparation", qos: .userInitiated)
    // CGImage is immutable once created; the worker does not mutate it after delivery.
    struct Decoded: @unchecked Sendable { let image: CGImage }
    static func decode(_ data: Data) async -> Decoded? {
        await withCheckedContinuation { continuation in
            worker.async {
                let decoded: Decoded? = autoreleasepool {
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: 2048,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceShouldCacheImmediately: true
                          ] as CFDictionary) else { return nil }
                    return Decoded(image: image)
                }
                continuation.resume(returning: decoded)
            }
        }
    }
    static func prepare(_ data: Data) async -> Prepared? {
        await withCheckedContinuation { continuation in
            worker.async {
                let prepared: Prepared? = autoreleasepool {
                    guard data.count <= 32 * 1024 * 1024,
                          let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: 2048,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceShouldCacheImmediately: true
                          ] as CFDictionary) else { return nil }
                    let output = NSMutableData()
                    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
                    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
                    guard CGImageDestinationFinalize(destination) else { return nil }
                    return Prepared(data: output as Data, size: CGSize(width: image.width, height: image.height))
                }
                continuation.resume(returning: prepared)
            }
        }
    }
}
