//
//  SceneEnvironment.swift
//  film space
//

import RealityKit
import UIKit

enum SceneEnvironment {
    static let studioGrey = UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1)
    static let axisXColor = UIColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1)
    static let axisYColor = UIColor(red: 0.35, green: 0.75, blue: 0.35, alpha: 1)
    static let axisZColor = UIColor(red: 0.30, green: 0.45, blue: 0.90, alpha: 1)

    /// Empty studio root. Environment content (the default grid, or a
    /// generated room once one exists) is added separately via
    /// `RoomEnvironmentBuilder.sync`, so it can be swapped without disturbing
    /// whatever else (characters, cameras) is already parented here.
    static func makeStudioRoot() -> Entity {
        let root = Entity()
        root.name = "StudioRoot"
        return root
    }
}
