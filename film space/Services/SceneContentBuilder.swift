//
//  SceneContentBuilder.swift
//  film space
//

import Foundation
import RealityKit

enum SceneContentBuilder {
    static func syncHumans(
        placements: [HumanPlacement],
        selectedID: UUID?,
        into root: Entity
    ) {
        let rootPositions = syncFigures(placements: placements, selectedID: selectedID, into: root)
        syncNameTags(placements: placements, rootPositions: rootPositions, into: root)
    }

    // Returns each figure's final root position (after floor-grounding), keyed by
    // placement id, so the name-tag pass can reuse it without recomputing bounds.
    private static func syncFigures(
        placements: [HumanPlacement],
        selectedID: UUID?,
        into root: Entity
    ) -> [UUID: SIMD3<Float>] {
        let existing = Dictionary(uniqueKeysWithValues: root.children.compactMap { child -> (UUID, Entity)? in
            guard child.name == "HumanFigure", let tag = child.components[HumanTagComponent.self] else { return nil }
            return (tag.id, child)
        })

        let placementIDs = Set(placements.map(\.id))
        for (id, entity) in existing where !placementIDs.contains(id) {
            entity.removeFromParent()
        }

        var rootPositions: [UUID: SIMD3<Float>] = [:]

        for placement in placements {
            let isSelected = placement.id == selectedID
            let entity: Entity
            if let existingEntity = existing[placement.id] {
                let needsRebuild = existingEntity.components[HumanSelectionComponent.self]?.isSelected != isSelected
                    || existingEntity.components[HumanPoseComponent.self]?.pose != placement.pose
                if needsRebuild {
                    existingEntity.removeFromParent()
                    entity = makeFigure(for: placement, isSelected: isSelected)
                    root.addChild(entity)
                } else {
                    entity = existingEntity
                    applyTransform(to: entity, placement: placement)
                }
            } else {
                entity = makeFigure(for: placement, isSelected: isSelected)
                root.addChild(entity)
            }
            rootPositions[placement.id] = entity.position
        }

        return rootPositions
    }

    private static func makeFigure(for placement: HumanPlacement, isSelected: Bool) -> Entity {
        let entity = HumanFigureFactory.makeHumanFigure(isSelected: isSelected, pose: placement.pose)
        entity.components.set(HumanTagComponent(id: placement.id))
        entity.components.set(HumanSelectionComponent(isSelected: isSelected))
        entity.components.set(HumanPoseComponent(pose: placement.pose))
        applyTransform(to: entity, placement: placement)
        return entity
    }

    // Grounds the figure on the floor for *any* pose, then applies the placement's
    // yaw and (for lying) the recline tilt on top.
    //
    // `entity.visualBounds(relativeTo: nil)` measures bounds relative to the entity
    // itself, i.e. it reflects every internal joint rotation (torso pitch/roll, leg
    // stagger, limb bends) but not the entity's own root-level tilt. So for lying —
    // the only pose that rotates the root itself — the lowest point has to be found
    // by rotating the local bounding box's corners by that tilt by hand.
    private static func applyTransform(to entity: Entity, placement: HumanPlacement) {
        let yaw = simd_quatf(angle: placement.rotationY, axis: [0, 1, 0])
        let tilt = HumanFigureFactory.rootTilt(for: placement.pose)

        let localBounds = entity.visualBounds(relativeTo: nil)
        let lowestY: Float
        if placement.pose == .lying {
            lowestY = corners(of: localBounds).map { tilt.act($0).y }.min() ?? localBounds.min.y
        } else {
            lowestY = localBounds.min.y
        }

        let groundedY = placement.position.y - lowestY + HumanFigureFactory.extraLift(for: placement.pose)
        entity.orientation = yaw * tilt
        entity.position = [placement.position.x, groundedY, placement.position.z]
    }

    private static func corners(of bounds: BoundingBox) -> [SIMD3<Float>] {
        [
            [bounds.min.x, bounds.min.y, bounds.min.z], [bounds.max.x, bounds.min.y, bounds.min.z],
            [bounds.min.x, bounds.max.y, bounds.min.z], [bounds.max.x, bounds.max.y, bounds.min.z],
            [bounds.min.x, bounds.min.y, bounds.max.z], [bounds.max.x, bounds.min.y, bounds.max.z],
            [bounds.min.x, bounds.max.y, bounds.max.z], [bounds.max.x, bounds.max.y, bounds.max.z],
        ]
    }

    // Name tags are independent, unrotated top-level entities (not children of the
    // figure), positioned directly above the head using the same pose math the
    // figure itself was built from, so a tilted/staggered pose can't drag it off.
    private static func syncNameTags(
        placements: [HumanPlacement],
        rootPositions: [UUID: SIMD3<Float>],
        into root: Entity
    ) {
        let existing = Dictionary(uniqueKeysWithValues: root.children.compactMap { child -> (UUID, Entity)? in
            guard child.name == "NameTag", let tag = child.components[HumanTagComponent.self] else { return nil }
            return (tag.id, child)
        })

        let placementIDs = Set(placements.map(\.id))
        for (id, entity) in existing where !placementIDs.contains(id) {
            entity.removeFromParent()
        }

        for placement in placements {
            guard let rootPosition = rootPositions[placement.id] else { continue }
            let position = headAnchorPosition(for: placement, rootPosition: rootPosition)

            if let entity = existing[placement.id] {
                entity.position = position
                guard entity.components[NameTagComponent.self]?.name != placement.name else { continue }
                entity.removeFromParent()
                root.addChild(makeNameTag(for: placement, position: position))
            } else {
                root.addChild(makeNameTag(for: placement, position: position))
            }
        }
    }

    private static func headAnchorPosition(for placement: HumanPlacement, rootPosition: SIMD3<Float>) -> SIMD3<Float> {
        let yaw = simd_quatf(angle: placement.rotationY, axis: [0, 1, 0])
        let tilt = HumanFigureFactory.rootTilt(for: placement.pose)
        let headLocal = HumanFigureFactory.headLocalPosition(for: placement.pose)
        let headWorld = rootPosition + yaw.act(tilt.act(headLocal))
        return headWorld + [0, HumanFigureFactory.nameTagOffsetAboveHead, 0]
    }

    private static func makeNameTag(for placement: HumanPlacement, position: SIMD3<Float>) -> Entity {
        let tag = NameTagFactory.makeNameTag(name: placement.name)
        tag.components.set(HumanTagComponent(id: placement.id))
        tag.components.set(NameTagComponent(name: placement.name))
        tag.position = position
        return tag
    }
}

struct HumanTagComponent: Component {
    var id: UUID
}

struct HumanSelectionComponent: Component {
    var isSelected: Bool
}

struct HumanPoseComponent: Component {
    var pose: CharacterPose
}

struct NameTagComponent: Component {
    var name: String
}
