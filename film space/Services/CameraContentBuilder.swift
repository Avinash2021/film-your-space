//
//  CameraContentBuilder.swift
//  film space
//

import Foundation
import RealityKit

enum CameraContentBuilder {
    // Node appearance never depends on selection (see CameraNodeFactory — the
    // frustum look is the same either way; CameraViewfinderView is responsible
    // for hiding camera nodes entirely when one becomes the active viewpoint),
    // so syncing is just add/remove/reposition — no rebuild-on-selection needed.
    static func syncCameras(placements: [CameraPlacement], into root: Entity) {
        syncNodes(placements: placements, into: root)
        syncNameTags(placements: placements, into: root)
    }

    private static func syncNodes(placements: [CameraPlacement], into root: Entity) {
        let existing = Dictionary(uniqueKeysWithValues: root.children.compactMap { child -> (UUID, Entity)? in
            guard child.name == "CameraNode", let tag = child.components[CameraTagComponent.self] else { return nil }
            return (tag.id, child)
        })

        let placementIDs = Set(placements.map(\.id))
        for (id, entity) in existing where !placementIDs.contains(id) {
            entity.removeFromParent()
        }

        for placement in placements {
            if let entity = existing[placement.id] {
                applyTransform(to: entity, placement: placement)
            } else {
                root.addChild(makeNode(for: placement))
            }
        }
    }

    private static func makeNode(for placement: CameraPlacement) -> Entity {
        let entity = CameraNodeFactory.makeCameraNode()
        entity.components.set(CameraTagComponent(id: placement.id))
        applyTransform(to: entity, placement: placement)
        return entity
    }

    private static func applyTransform(to entity: Entity, placement: CameraPlacement) {
        entity.orientation = simd_quatf(angle: placement.rotationY, axis: [0, 1, 0])
            * simd_quatf(angle: placement.rotationPitch, axis: [1, 0, 0])
        entity.position = placement.position
    }

    private static func syncNameTags(placements: [CameraPlacement], into root: Entity) {
        let existing = Dictionary(uniqueKeysWithValues: root.children.compactMap { child -> (UUID, Entity)? in
            guard child.name == "CameraNameTag", let tag = child.components[CameraTagComponent.self] else { return nil }
            return (tag.id, child)
        })

        let placementIDs = Set(placements.map(\.id))
        for (id, entity) in existing where !placementIDs.contains(id) {
            entity.removeFromParent()
        }

        for placement in placements {
            let position = placement.position + [0, CameraNodeFactory.nameTagAnchorHeight, 0]

            if let entity = existing[placement.id] {
                entity.position = position
                guard entity.components[CameraNameTagComponent.self]?.name != placement.name else { continue }
                entity.removeFromParent()
                root.addChild(makeNameTag(for: placement, position: position))
            } else {
                root.addChild(makeNameTag(for: placement, position: position))
            }
        }
    }

    private static func makeNameTag(for placement: CameraPlacement, position: SIMD3<Float>) -> Entity {
        let tag = NameTagFactory.makeNameTag(name: placement.name)
        tag.name = "CameraNameTag"
        tag.components.set(CameraTagComponent(id: placement.id))
        tag.components.set(CameraNameTagComponent(name: placement.name))
        tag.position = position
        return tag
    }
}

struct CameraTagComponent: Component {
    var id: UUID
}

struct CameraNameTagComponent: Component {
    var name: String
}
