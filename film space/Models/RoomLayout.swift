//
//  RoomLayout.swift
//  film space
//

import Foundation
import RealityKit

/// Structural description of a real-world room, produced by turning a flat
/// 2D photo into a 3D layout (see RoomLayoutProcessor). Stored on SceneState
/// so it survives tab switches and drives the shared environment everywhere
/// (see RoomEnvironmentBuilder) — Character, Camera, and Motion all render
/// whatever room is currently active.
struct RoomLayout: Codable, Equatable {
    struct Dimensions: Codable, Equatable {
        var width: Float
        var length: Float
        var height: Float
    }

    struct Prop: Codable, Equatable, Identifiable {
        var id = UUID()
        var type: String
        var position: SIMD3<Float>
        var scale: SIMD3<Float>
    }

    var roomDimensions: Dimensions
    var detectedProps: [Prop]
}
