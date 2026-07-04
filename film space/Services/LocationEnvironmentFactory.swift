//
//  LocationEnvironmentFactory.swift
//  film space
//

import RealityKit

enum LocationEnvironmentFactory {
    /// Large enough that a camera orbiting near the origin never gets close to the walls.
    static let sphereRadius: Float = 20

    /// A sphere with a 360° image projected on its *inside* walls, so a camera
    /// positioned near the origin sees the image surrounding it in every direction.
    static func makeSkybox(textureName: String = "warehouse360") -> Entity {
        let skybox = Entity()
        skybox.name = "Skybox360"

        var material = UnlitMaterial()
        // Double-sided rendering: the sphere's front faces point outward by
        // default, so without this the inside walls would be culled and the
        // camera (sitting inside the sphere) would see nothing.
        material.faceCulling = .none
        if let texture = try? TextureResource.load(named: textureName) {
            material.color = .init(texture: .init(texture))
        }

        let sphere = ModelEntity(mesh: .generateSphere(radius: sphereRadius), materials: [material])
        skybox.addChild(sphere)

        return skybox
    }
}
