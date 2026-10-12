import Foundation

enum AnnotationCollectionCatalog {
    static func referenceTitle(bookTitle: String, chapter: Int, layerName: String) -> String {
        "\(bookTitle) \(chapter) · \(layerName)"
    }

    static func appearanceSubtitle(for layer: AnnotationLayer, layout: AnnotationLayout) -> String {
        let preset = layer.appearance?.presetID.flatMap(ScriptureAppearance.init(rawValue:))
        let presetName = preset?.title
            ?? (layer.appearance?.typeface == "Georgia" ? ScriptureAppearance.oldPaper.title : nil)
            ?? layer.appearance?.typeface
            ?? layout.fontName
        return "\(presetName), \(Int(layout.fontSize.rounded())) pt"
    }

    static func layerChoices(in snapshot: AnnotationSnapshot) -> [(groupID: UUID, layer: AnnotationLayer, layout: AnnotationLayout)] {
        snapshot.groups.flatMap { group in
            group.layers.compactMap { layer -> (UUID, AnnotationLayer, AnnotationLayout)? in
                guard layer.deletedAt == nil else { return nil }
                let layout = layer.layout ?? group.layout
                return (group.id, layer, layout)
            }
        }
    }

    static func resolveLayer(layerID: UUID, in snapshot: AnnotationSnapshot) -> (groupID: UUID, layer: AnnotationLayer, layout: AnnotationLayout, deleted: Bool)? {
        for group in snapshot.groups {
            guard let layer = group.layers.first(where: { $0.id == layerID }) else { continue }
            let layout = layer.layout ?? group.layout
            return (group.id, layer, layout, layer.deletedAt != nil)
        }
        return nil
    }

    static func artifact(
        for saved: SavedAnnotation,
        snapshot: AnnotationSnapshot?
    ) -> CollectionArtifact {
        if let snapshot, let resolved = resolveLayer(layerID: saved.id, in: snapshot) {
            let name = resolved.deleted ? "\(saved.layerName) (deleted)" : resolved.layer.name
            let title = referenceTitle(bookTitle: saved.bookTitle, chapter: saved.source.chapter, layerName: name)
            let subtitle = resolved.deleted
                ? "Annotation layer · unavailable"
                : "Annotation · \(appearanceSubtitle(for: resolved.layer, layout: resolved.layout))"
            return CollectionArtifact(
                id: saved.id,
                title: title,
                subtitle: subtitle,
                kind: .annotation,
                modifiedAt: resolved.layer.updatedAt
            )
        }
        let title = referenceTitle(bookTitle: saved.bookTitle, chapter: saved.source.chapter, layerName: saved.layerName)
        return CollectionArtifact(
            id: saved.id,
            title: title,
            subtitle: "Annotation layer · unavailable",
            kind: .annotation,
            modifiedAt: saved.savedAt
        )
    }

    static func artifact(
        groupID: UUID,
        layer: AnnotationLayer,
        layout: AnnotationLayout,
        bookTitle: String,
        source: AnnotationSource
    ) -> CollectionArtifact {
        CollectionArtifact(
            id: layer.id,
            title: referenceTitle(bookTitle: bookTitle, chapter: source.chapter, layerName: layer.name),
            subtitle: "Annotation · \(appearanceSubtitle(for: layer, layout: layout))",
            kind: .annotation,
            modifiedAt: layer.updatedAt
        )
    }

    static func pickableLayerArtifacts(snapshot: AnnotationSnapshot, bookTitleForCode: (String) -> String) -> [CollectionArtifact] {
        layerChoices(in: snapshot).compactMap { groupID, layer, layout in
            guard let group = snapshot.groups.first(where: { $0.id == groupID }) else { return nil }
            return artifact(
                groupID: groupID,
                layer: layer,
                layout: layout,
                bookTitle: bookTitleForCode(group.source.book),
                source: group.source
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
