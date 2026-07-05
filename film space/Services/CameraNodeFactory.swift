//
//  CameraNodeFactory.swift
//  film space
//

import RealityKit
import UIKit

enum CameraNodeFactory {
    private static let frustumColor = UIColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 1)
    private static let bodyColor = UIColor(white: 0.12, alpha: 1)

    // Frustum apex sits at the entity's own origin — the same point used as the
    // live render camera's position when this camera becomes active — pointing
    // down -Z, matching RealityKit's default camera forward.
    private static let depth: Float = 0.22
    private static let halfWidth: Float = 0.09
    private static let halfHeight: Float = 0.065
    private static let lineThickness: Float = 0.006
    private static let bodySize: Float = 0.05

    /// Small, semi-transparent wireframe frustum marking a virtual camera's
    /// placement and aim direction — deliberately not a solid opaque mesh, so
    /// it doesn't itself block the view when the camera becomes active (see
    /// CameraViewfinderView, which additionally hides this whole node whenever
    /// any camera is the active viewpoint).
    static func makeCameraNode() -> Entity {
        let root = Entity()
        root.name = "CameraNode"

        var lineMaterial = UnlitMaterial(color: frustumColor)
        lineMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.75))

        let apex = SIMD3<Float>.zero
        let corners = [
            SIMD3<Float>(-halfWidth, halfHeight, -depth),
            SIMD3<Float>(halfWidth, halfHeight, -depth),
            SIMD3<Float>(halfWidth, -halfHeight, -depth),
            SIMD3<Float>(-halfWidth, -halfHeight, -depth),
        ]

        for corner in corners {
            addLine(to: root, from: apex, to: corner, material: lineMaterial)
        }
        for i in corners.indices {
            addLine(to: root, from: corners[i], to: corners[(i + 1) % corners.count], material: lineMaterial)
        }

        // Small solid marker at the apex/eye point — reads as a camera body at
        // a glance and gives a comfortable tap target for selection and drag.
        let bodyMaterial = SimpleMaterial(color: bodyColor, roughness: 0.4, isMetallic: true)
        let body = ModelEntity(mesh: .generateBox(size: bodySize, cornerRadius: 0.012), materials: [bodyMaterial])
        root.addChild(body)

        let bounds = root.visualBounds(relativeTo: nil)
        let size = SIMD3<Float>(
            max(bounds.max.x - bounds.min.x, 0.1),
            max(bounds.max.y - bounds.min.y, 0.1),
            max(bounds.max.z - bounds.min.z, 0.1)
        )
        let center = SIMD3<Float>(
            (bounds.max.x + bounds.min.x) / 2,
            (bounds.max.y + bounds.min.y) / 2,
            (bounds.max.z + bounds.min.z) / 2
        )
        root.components.set(CollisionComponent(shapes: [.generateBox(size: size).offsetBy(translation: center)]))
        root.components.set(InputTargetComponent())

        return root
    }

    private static func addLine(to parent: Entity, from start: SIMD3<Float>, to end: SIMD3<Float>, material: Material) {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.0001 else { return }

        let line = ModelEntity(mesh: .generateBox(size: [lineThickness, lineThickness, length]), materials: [material])
        line.position = (start + end) / 2
        line.look(at: end, from: start, relativeTo: parent)
        parent.addChild(line)
    }

    /// Height above the placement's floor position for the floating name card.
    static let nameTagAnchorHeight: Float = halfHeight + 0.20
}
