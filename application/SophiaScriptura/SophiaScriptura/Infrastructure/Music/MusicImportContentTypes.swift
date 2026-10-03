import UniformTypeIdentifiers

enum MusicImportContentTypes {
    /// Extensions validated after import (`UserMusicLibraryStore`).
    static let fileExtensions = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "caf"]

    /// Document picker types. `.item` keeps Safari Downloads MP3s selectable (often tagged `public.data`, not `public.mp3`).
    static var pickerTypes: [UTType] {
        var types: [UTType] = [.item, .data, .content, .audio]
        for ext in fileExtensions {
            if let type = UTType(filenameExtension: ext, conformingTo: .audio) { types.append(type) }
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        types.append(.mp3)
        types.append(.mpeg4Audio)
        types.append(.wav)
        types.append(.aiff)
        var seen = Set<String>()
        return types.filter { seen.insert($0.identifier).inserted }
    }

    static func isSupportedFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return fileExtensions.contains(ext)
    }
}
