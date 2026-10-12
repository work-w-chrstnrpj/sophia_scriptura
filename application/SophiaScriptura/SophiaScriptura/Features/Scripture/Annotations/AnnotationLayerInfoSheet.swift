import SwiftUI

struct AnnotationLayerInfoSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let choice: AnnotationSession.LayerChoice
    let collectionNames: [String]

    private static let timestampFormat = Date.FormatStyle(date: .numeric, time: .shortened)

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    row("Preset", value: presetLabel)
                    row("Size", value: "\(Int(choice.layout.fontSize.rounded())) pt")
                }
                .listRowBackground(Color(theme.palette.soft))

                Section("History") {
                    row("Created", value: choice.layer.createdAt.formatted(Self.timestampFormat))
                    row("Last modified", value: choice.layer.updatedAt.formatted(Self.timestampFormat))
                }
                .listRowBackground(Color(theme.palette.soft))

                Section("Collections") {
                    if collectionNames.isEmpty {
                        Text("Not in any collection")
                            .foregroundStyle(Color(theme.palette.secondary))
                    } else {
                        ForEach(collectionNames, id: \.self) { name in
                            Text(name)
                                .foregroundStyle(Color(theme.palette.ink))
                        }
                    }
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle("Layer information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var presetLabel: String {
        let preset = choice.layer.appearance?.presetID.flatMap(ScriptureAppearance.init(rawValue:))
        return preset?.title
            ?? (choice.layer.appearance?.typeface == "Georgia" ? ScriptureAppearance.oldPaper.title : nil)
            ?? choice.layer.appearance?.typeface
            ?? choice.layout.fontName
    }

    private func row(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(Color(theme.palette.secondary))
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color(theme.palette.ink))
        }
    }
}
