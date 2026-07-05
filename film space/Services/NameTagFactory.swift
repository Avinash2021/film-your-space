//
//  NameTagFactory.swift
//  film space
//

import RealityKit
import UIKit

enum NameTagFactory {
    private static let fontSize: CGFloat = 0.045
    private static let paddingX: Float = 0.03
    private static let paddingY: Float = 0.018

    // Floating card, billboarded so it always faces the camera regardless of
    // the figure's own rotation.
    static func makeNameTag(name: String) -> Entity {
        let container = Entity()
        container.name = "NameTag"

        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let textMesh = MeshResource.generateText(
            displayName.isEmpty ? " " : displayName,
            extrusionDepth: 0,
            font: .systemFont(ofSize: fontSize, weight: .semibold)
        )
        let bounds = textMesh.bounds
        let textEntity = ModelEntity(mesh: textMesh, materials: [UnlitMaterial(color: .white)])
        textEntity.position = [
            -(bounds.max.x + bounds.min.x) / 2,
            -(bounds.max.y + bounds.min.y) / 2,
            0.002,
        ]

        let cardWidth = max((bounds.max.x - bounds.min.x) + paddingX * 2, 0.12)
        let cardHeight = (bounds.max.y - bounds.min.y) + paddingY * 2

        var cardMaterial = UnlitMaterial(color: .black)
        cardMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.55))
        let cardMesh = MeshResource.generatePlane(width: cardWidth, height: cardHeight, cornerRadius: cardHeight / 2)
        let card = ModelEntity(mesh: cardMesh, materials: [cardMaterial])

        container.addChild(card)
        container.addChild(textEntity)
        container.components.set(BillboardComponent())

        return container
    }
}
