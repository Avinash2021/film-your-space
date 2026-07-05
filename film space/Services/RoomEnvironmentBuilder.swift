//
//  RoomEnvironmentBuilder.swift
//  film space
//

import RealityKit
import UIKit

/// Owns the one "EnvironmentGeometry" child of a studio root: either the
/// default empty-studio grid (no room uploaded yet) or a generated room built
/// from a `RoomLayout`. `sync` is the scene-clearing routine — it purges only
/// that one node and rebuilds it; every other child of `root` (character
/// hinges, camera nodes, name tags — each tracked by their own tag component)
/// is untouched, so switching or clearing the room never disturbs the
/// characters, cameras, or other session state living alongside it.
enum RoomEnvironmentBuilder {
    private static let environmentNodeName = "EnvironmentGeometry"

    /// Name of the entity marking the floor's top surface — the default grid
    /// and every generated room each tag exactly one entity with this name,
    /// so character grounding (see SceneContentBuilder.floorHeight) can look
    /// up the actual floor height instead of assuming it's always world Y=0.
    static let floorReferenceName = "RoomFloor"

    /// Name tag for each generated prop block — tap/select/delete (see
    /// LocationPreviewView) walks up to whichever entity has this name and a
    /// `RoomPropComponent` to find which detected prop it represents.
    private static let propNodeName = "RoomProp"

    private static let gridLineColor = UIColor(red: 0.32, green: 0.32, blue: 0.32, alpha: 1)
    private static let tileColor = UIColor(red: 0.34, green: 0.34, blue: 0.34, alpha: 1)
    private static let roomFloorColor = UIColor(red: 0.30, green: 0.30, blue: 0.33, alpha: 1)
    private static let roomOutlineColor = UIColor(red: 0.5, green: 0.75, blue: 1.0, alpha: 1)

    static func sync(layout: RoomLayout?, selectedPropID: UUID? = nil, into root: Entity) {
        let environment: Entity
        if let existing = root.children.first(where: { $0.name == environmentNodeName }),
           existing.components[EnvironmentLayoutComponent.self]?.layout == layout {
            environment = existing
        } else {
            root.children.first(where: { $0.name == environmentNodeName })?.removeFromParent()

            let fresh = Entity()
            fresh.name = environmentNodeName
            fresh.components.set(EnvironmentLayoutComponent(layout: layout))
            root.addChild(fresh)

            if let layout {
                buildGeneratedRoom(from: layout, into: fresh)
            } else {
                buildDefaultGrid(into: fresh)
            }
            addLighting(to: fresh)
            environment = fresh
        }

        // Selection highlighting is cheap enough to always re-apply, even when
        // the structural rebuild above was skipped.
        updatePropHighlight(in: environment, selectedPropID: selectedPropID)
    }

    private static func updatePropHighlight(in environment: Entity, selectedPropID: UUID?) {
        for child in environment.children where child.name == propNodeName {
            guard let model = child as? ModelEntity,
                  let tag = child.components[RoomPropComponent.self] else { continue }
            let color = tag.propID == selectedPropID ? UIColor.systemYellow : tag.baseColor
            model.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
        }
    }

    // MARK: - Default grid (no room uploaded yet)

    private static func buildDefaultGrid(into root: Entity) {
        let gridSize: Float = 10
        let divisions = 20
        let step = (gridSize * 2) / Float(divisions)

        let tileMesh = MeshResource.generatePlane(width: step, depth: step)
        let tileMaterial = SimpleMaterial(color: tileColor, roughness: 1, isMetallic: false)
        for i in 0..<divisions {
            for j in 0..<divisions where (i + j) % 2 == 0 {
                let tile = ModelEntity(mesh: tileMesh, materials: [tileMaterial])
                tile.position = [-gridSize + (Float(i) + 0.5) * step, 0, -gridSize + (Float(j) + 0.5) * step]
                root.addChild(tile)
            }
        }

        let lineMaterial = UnlitMaterial(color: gridLineColor)
        for i in 0...divisions {
            let offset = -gridSize + Float(i) * step
            addLine(to: root, from: [offset, 0.001, -gridSize], to: [offset, 0.001, gridSize], material: lineMaterial)
            addLine(to: root, from: [-gridSize, 0.001, offset], to: [gridSize, 0.001, offset], material: lineMaterial)
        }

        let axisLength: Float = 1.2
        let axisThickness: Float = 0.012
        addLine(to: root, from: .zero, to: [axisLength, 0, 0], material: UnlitMaterial(color: SceneEnvironment.axisXColor), thickness: axisThickness)
        addLine(to: root, from: .zero, to: [0, axisLength, 0], material: UnlitMaterial(color: SceneEnvironment.axisYColor), thickness: axisThickness)
        addLine(to: root, from: .zero, to: [0, 0, axisLength], material: UnlitMaterial(color: SceneEnvironment.axisZColor), thickness: axisThickness)

        // Invisible marker at the grid's surface height so character grounding
        // has the same floor-reference lookup to use as the generated-room case.
        let floorReference = Entity()
        floorReference.name = floorReferenceName
        root.addChild(floorReference)
    }

    // MARK: - Generated room (from an uploaded image)

    private static func buildGeneratedRoom(from layout: RoomLayout, into root: Entity) {
        let dimensions = layout.roomDimensions

        let floorMaterial = SimpleMaterial(color: roomFloorColor, roughness: 1, isMetallic: false)
        let floor = ModelEntity(
            mesh: .generatePlane(width: dimensions.width, depth: dimensions.length),
            materials: [floorMaterial]
        )
        floor.name = floorReferenceName
        root.addChild(floor)

        addRoomOutline(to: root, dimensions: dimensions)

        for prop in layout.detectedProps {
            let baseColor = color(for: prop.type)
            let box = ModelEntity(
                mesh: .generateBox(size: prop.scale),
                materials: [SimpleMaterial(color: baseColor, roughness: 0.6, isMetallic: false)]
            )
            box.name = propNodeName
            box.position = prop.position
            box.components.set(RoomPropComponent(propID: prop.id, baseColor: baseColor))
            box.components.set(CollisionComponent(shapes: [.generateBox(size: prop.scale)]))
            box.components.set(InputTargetComponent())
            root.addChild(box)
        }
    }

    // Simple open wireframe box outlining the room's footprint and height —
    // floor rectangle plus four vertical corner posts — deliberately low-poly.
    private static func addRoomOutline(to root: Entity, dimensions: RoomLayout.Dimensions) {
        let material = UnlitMaterial(color: roomOutlineColor)
        let halfWidth = dimensions.width / 2
        let halfLength = dimensions.length / 2
        let corners: [SIMD3<Float>] = [
            [-halfWidth, 0, -halfLength], [halfWidth, 0, -halfLength],
            [halfWidth, 0, halfLength], [-halfWidth, 0, halfLength],
        ]

        for i in corners.indices {
            addLine(to: root, from: corners[i], to: corners[(i + 1) % corners.count], material: material)
            addLine(to: root, from: corners[i], to: corners[i] + [0, dimensions.height, 0], material: material)
        }
    }

    private static func color(for propType: String) -> UIColor {
        switch propType.lowercased() {
        case "table": return .systemBrown
        case "chair": return .systemBlue
        case "tv": return .black
        case "sofa", "couch": return .systemGreen
        default: return .systemGray
        }
    }

    // MARK: - Shared

    private static func addLighting(to root: Entity) {
        let keyLight = Entity()
        keyLight.components.set(DirectionalLightComponent(color: .white, intensity: 1200, isRealWorldProxy: false))
        keyLight.look(at: .zero, from: [4, 6, 4], relativeTo: nil)
        root.addChild(keyLight)

        let fillLight = Entity()
        fillLight.components.set(DirectionalLightComponent(color: .white, intensity: 400, isRealWorldProxy: false))
        fillLight.look(at: .zero, from: [-3, 2, -2], relativeTo: nil)
        root.addChild(fillLight)
    }

    private static func addLine(
        to parent: Entity,
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        material: Material,
        thickness: Float = 0.004
    ) {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.0001 else { return }

        let line = ModelEntity(mesh: .generateBox(size: [thickness, thickness, length]), materials: [material])
        line.position = (start + end) / 2
        line.look(at: end, from: start, relativeTo: parent)
        parent.addChild(line)
    }
}

private struct EnvironmentLayoutComponent: Component, Equatable {
    var layout: RoomLayout?
}

/// Tags a generated prop block with which `RoomLayout.Prop` it represents, so
/// a tap/select/delete flow (see LocationPreviewView) can find it by walking
/// up from whatever child entity was actually hit.
struct RoomPropComponent: Component {
    var propID: UUID
    var baseColor: UIColor
}
