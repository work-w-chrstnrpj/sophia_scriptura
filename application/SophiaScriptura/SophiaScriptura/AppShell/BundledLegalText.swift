import Foundation

enum BundledLegalText {
    static func load(resource: String, extension ext: String = "txt", subdirectory: String = "Legal") -> String {
        let url = Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: resource, withExtension: ext)
        guard let url, let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return "License text could not be loaded."
        }
        return text
    }

    static var appCopyrightNotice: String { load(resource: "App-Copyright") }

    static var gnuGPLv3: String { load(resource: "GPL-3.0") }

    static var gnuGPLv3FullDocument: String {
        """
        \(appCopyrightNotice)

        \(gnuGPLv3)
        """
    }
}
