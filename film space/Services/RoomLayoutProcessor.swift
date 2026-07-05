//
//  RoomLayoutProcessor.swift
//  film space
//

import UIKit

/// Processing stub: this is the seam where a real vision model or a server
/// call would eventually turn a flat photo of a room into a `RoomLayout`
/// (dimensions + detected furniture). For now it generates a plausible mock
/// layout on a background queue and calls back on the main thread, so the
/// rest of the pipeline — scene generation, hand-off to Character/Camera/
/// Motion — can be built and exercised end-to-end before any real detection
/// model is wired in.
enum RoomLayoutProcessor {
    static func process(_ image: UIImage, completion: @escaping (RoomLayout) -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            let layout = mockLayout(for: image)
            DispatchQueue.main.async {
                completion(layout)
            }
        }
    }

    // Derives a room size loosely from the photo's aspect ratio (so it isn't
    // identical for every image) and places a fixed, plausible furniture set.
    // Replace this function with real detection when a model/service exists.
    private static func mockLayout(for image: UIImage) -> RoomLayout {
        let aspect = image.size.width > 0 ? Float(image.size.height / image.size.width) : 0.75
        let width: Float = 5
        let length = max(3, width * aspect)
        let dimensions = RoomLayout.Dimensions(width: width, length: length, height: 2.6)

        let props: [RoomLayout.Prop] = [
            RoomLayout.Prop(type: "table", position: [0, 0.35, 0], scale: [1.2, 0.7, 0.8]),
            RoomLayout.Prop(type: "chair", position: [0.9, 0.4, 0.6], scale: [0.5, 0.8, 0.5]),
            RoomLayout.Prop(type: "chair", position: [-0.9, 0.4, 0.6], scale: [0.5, 0.8, 0.5]),
            RoomLayout.Prop(type: "sofa", position: [0, 0.35, -length / 2 + 0.6], scale: [1.8, 0.7, 0.8]),
            RoomLayout.Prop(type: "tv", position: [0, 1.1, length / 2 - 0.15], scale: [1.1, 0.65, 0.08]),
        ]

        return RoomLayout(roomDimensions: dimensions, detectedProps: props)
    }
}
