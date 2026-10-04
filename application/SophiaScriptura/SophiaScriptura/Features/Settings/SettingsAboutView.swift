import SwiftUI

struct SettingsAboutView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sophia Scriptura")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                    Text("A personal, offline-first Bible study app for iPad — scripture reading, notes, collections, and a guardrailed study companion.")
                        .font(.subheadline)
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color(theme.palette.soft))

            Section("App") {
                aboutRow(label: "Version", value: AppVersion.fullLabel, id: "settings.about.version")
                aboutRow(label: "Developed by", value: "Christian Paje", id: "settings.about.developer")
            }
            .listRowBackground(Color(theme.palette.soft))

            Section("Legal") {
                NavigationLink {
                    SettingsLicenseDocumentView(
                        title: "GNU General Public License v3",
                        bodyText: BundledLegalText.gnuGPLv3FullDocument
                    )
                } label: {
                    Text("GNU General Public License v3")
                }
                .accessibilityIdentifier("settings.about.gpl")

                NavigationLink {
                    SettingsAcknowledgmentsView()
                } label: {
                    Text("Acknowledgments & third-party licenses")
                }
                .accessibilityIdentifier("settings.about.acknowledgments")
            }
            .listRowBackground(Color(theme.palette.soft))

            Section {
                Text("Sophia Scriptura is licensed under the GNU GPL v3. You may obtain source code corresponding to this build from the project repository that produced this app.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            .listRowBackground(Color(theme.palette.soft))
        }
        .appSurface()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.about")
    }

    private func aboutRow(label: String, value: String, id: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Color(theme.palette.secondary))
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color(theme.palette.ink))
                .accessibilityIdentifier(id)
        }
    }
}

struct SettingsLicenseDocumentView: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Color(theme.palette.ink))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .textSelection(.enabled)
        }
        .appSurface()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsAcknowledgmentsView: View {
    @Environment(\.appTheme) private var theme

    private let fontFamilies = [
        "Caveat", "Cormorant Garamond", "DM Sans", "EB Garamond",
        "Libre Baskerville", "Lora", "Manrope", "Playfair Display", "Source Sans 3"
    ]

    var body: some View {
        List {
            Section("Scripture") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("World English Bible (WEB)")
                        .font(.headline)
                    Text("American English, Protestant edition. Public domain via eBible.org.")
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                    Link("Edition notice", destination: URL(string: "https://ebible.org/engwebp/")!)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color(theme.palette.soft))

            Section("Fonts (SIL Open Font License 1.1)") {
                ForEach(fontFamilies, id: \.self) { name in
                    NavigationLink {
                        SettingsLicenseDocumentView(
                            title: "\(name) — OFL",
                            bodyText: bundledOFL(for: name)
                        )
                    } label: {
                        Text(name)
                    }
                }
            }
            .listRowBackground(Color(theme.palette.soft))
        }
        .appSurface()
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bundledOFL(for family: String) -> String {
        let key = oflResourceName(for: family)
        let text = BundledLegalText.load(resource: key, subdirectory: "Fonts")
        if text != "License text could not be loaded." { return text }
        return "Open Font License 1.1 applies to \(family). See the bundled \(key).txt file in the app resources."
    }

    private func oflResourceName(for family: String) -> String {
        switch family {
        case "Caveat": "caveat-OFL"
        case "Cormorant Garamond": "cormorantgaramond-OFL"
        case "DM Sans": "dmsans-OFL"
        case "EB Garamond": "ebgaramond-OFL"
        case "Libre Baskerville": "librebaskerville-OFL"
        case "Lora": "lora-OFL"
        case "Manrope": "manrope-OFL"
        case "Playfair Display": "playfairdisplay-OFL"
        case "Source Sans 3": "sourcesans3-OFL"
        default: "sourcesans3-OFL"
        }
    }
}
