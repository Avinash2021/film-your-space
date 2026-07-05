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
        let transforms = syncFigures(placements: placements, selectedID: selectedID, into: root)
        syncNameTags(placements: placements, transforms: transforms, into: root)
    }

    // Each figure is a two-level rig:
    //   HumanHinge (tagged, tap-selectable via its child's collision)
    //     └─ HumanFigure (the actual mesh, built by HumanFigureFactory)
    //
    // The hinge sits at ground level plus any user-applied lift, and carries the
    // yaw and the sway (pitch/roll) trim — so sway always pivots from a fixed
    // point at the character's feet, the way leaning over a planted foot
    // actually works, rather than from wherever the mesh's own origin happens to
    // sit. The figure underneath only carries the pose's own recline (lying) and
    // is grounded against that alone.
    private struct FigureTransform {
        var hingePosition: SIMD3<Float>
        var figureLocalOffset: SIMD3<Float>
    }

    private static func syncFigures(
        placements: [HumanPlacement],
        selectedID: UUID?,
        into root: Entity
    ) -> [UUID: FigureTransform] {
        let existing = Dictionary(uniqueKeysWithValues: root.children.compactMap { child -> (UUID, Entity)? in
            guard child.name == "HumanHinge", let tag = child.components[HumanTagComponent.self] else { return nil }
            return (tag.id, child)
        })

        let placementIDs = Set(placements.map(\.id))
        for (id, entity) in existing where !placementIDs.contains(id) {
            entity.removeFromParent()
        }

        let floorY = floorHeight(in: root)
        var transforms: [UUID: FigureTransform] = [:]

        for placement in placements {
            let isSelected = placement.id == selectedID
            let hinge: Entity
            if let existingHinge = existing[placement.id] {
                let needsRebuild = existingHinge.components[HumanSelectionComponent.self]?.isSelected != isSelected
                    || existingHinge.components[HumanPoseComponent.self]?.pose != placement.pose
                if needsRebuild {
                    existingHinge.removeFromParent()
                    hinge = makeHinge(for: placement, isSelected: isSelected)
                    root.addChild(hinge)
                } else {
                    hinge = existingHinge
                }
            } else {
                hinge = makeHinge(for: placement, isSelected: isSelected)
                root.addChild(hinge)
            }

            transforms[placement.id] = applyTransform(to: hinge, placement: placement, floorHeight: floorY)
        }

        return transforms
    }

    /// The active floor's top-surface height (world Y), looked up from the
    /// entity RoomEnvironmentBuilder tags in either the default grid or a
    /// generated room — rather than assuming the floor always sits at world
    /// Y=0. Falls back to 0 if no floor reference is found (e.g. the entity
    /// tree hasn't finished building yet).
    private static func floorHeight(in root: Entity) -> Float {
        guard let floor = root.findEntity(named: RoomEnvironmentBuilder.floorReferenceName) else { return 0 }
        return floor.position(relativeTo: root).y
    }

    private static func makeHinge(for placement: HumanPlacement, isSelected: Bool) -> Entity {
        let hinge = Entity()
        hinge.name = "HumanHinge"
        hinge.components.set(HumanTagComponent(id: placement.id))
        hinge.components.set(HumanSelectionComponent(isSelected: isSelected))
        hinge.components.set(HumanPoseComponent(pose: placement.pose))

        let figure = HumanFigureFactory.makeHumanFigure(isSelected: isSelected, pose: placement.pose)
        hinge.addChild(figure)

        return hinge
    }

    /// The sway (pitch/roll) trim, independent of yaw and of pose. This never
    /// touches the environment sphere, which lives in an entirely separate scene
    /// (LocationPreviewView) with no shared entity hierarchy.
    private static func swayRotation(for placement: HumanPlacement) -> simd_quatf {
        simd_quatf(angle: placement.tiltRoll, axis: [0, 0, 1])
            * simd_quatf(angle: placement.tiltPitch, axis: [1, 0, 0])
    }

    // `floorHeight` anchors the hinge's resting height to the actual floor
    // entity (see `floorHeight(in:)`) rather than assuming world Y=0 — so a
    // character stays correctly planted on top of the floor's real surface
    // even if a generated room's floor isn't exactly at the world origin.
    @discardableResult
    private static func applyTransform(to hinge: Entity, placement: HumanPlacement, floorHeight: Float) -> FigureTransform {
        let yaw = simd_quatf(angle: placement.rotationY, axis: [0, 1, 0])
        let sway = swayRotation(for: placement)

        hinge.orientation = yaw * sway
        hinge.position = [
            placement.position.x,
            floorHeight + placement.position.y + placement.liftHeight,
            placement.position.z,
        ]

        guard let figure = hinge.children.first(where: { $0.name == "HumanFigure" }) else {
            return FigureTransform(hingePosition: hinge.position, figureLocalOffset: .zero)
        }

        // `figure.visualBounds(relativeTo: nil)` measures bounds relative to the
        // figure itself, reflecting every internal joint rotation (torso
        // pitch/roll, leg stagger, limb bends) but not the figure's own
        // root-level recline. Lying is the only pose that rotates the figure
        // root, so its lowest point is found by rotating the local bounding
        // box's corners by that tilt by hand.
        let poseTilt = HumanFigureFactory.rootTilt(for: placement.pose)
        let localBounds = figure.visualBounds(relativeTo: nil)
        let lowestY = corners(of: localBounds).map { poseTilt.act($0).y }.min() ?? localBounds.min.y

        let figureLocalOffset = SIMD3<Float>(0, -lowestY + HumanFigureFactory.extraLift(for: placement.pose), 0)
        figure.orientation = poseTilt
        figure.position = figureLocalOffset

        return FigureTransform(hingePosition: hinge.position, figureLocalOffset: figureLocalOffset)
    }

    private static func corners(of bounds: BoundingBox) -> [SIMD3<Float>] {
        [
            [bounds.min.x, bounds.min.y, bounds.min.z], [bounds.max.x, bounds.min.y, bounds.min.z],
            [bounds.min.x, bounds.max.y, bounds.min.z], [bounds.max.x, bounds.max.y, bounds.min.z],
            [bounds.min.x, bounds.min.y, bounds.max.z], [bounds.max.x, bounds.min.y, bounds.max.z],
            [bounds.min.x, bounds.max.y, bounds.max.z], [bounds.max.x, bounds.max.y, bounds.max.z],
        ]
    }

    // Name tags are independent, unrotated top-level entities (not children of
    // the hinge), positioned directly above the head using the same transform
    // the figure itself was built from, so sway/lift/pose can't drag it off.
    private static func syncNameTags(
        placements: [HumanPlacement],
        transforms: [UUID: FigureTransform],
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
            guard let transform = transforms[placement.id] else { continue }
            let position = headAnchorPosition(for: placement, transform: transform)

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

    private static func headAnchorPosition(for placement: HumanPlacement, transform: FigureTransform) -> SIMD3<Float> {
        let yaw = simd_quatf(angle: placement.rotationY, axis: [0, 1, 0])
        let sway = swayRotation(for: placement)
        let poseTilt = HumanFigureFactory.rootTilt(for: placement.pose)
        let headLocal = HumanFigureFactory.headLocalPosition(for: placement.pose)

        let headInHingeSpace = transform.figureLocalOffset + poseTilt.act(headLocal)
        let headWorld = transform.hingePosition + (yaw * sway).act(headInHingeSpace)
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
