//
//  SceneState.swift
//  film space
//

import Foundation
import RealityKit

/// The four top-level sections of the app, in tab order.
enum AppSection: String, CaseIterable {
    case location = "Location"
    case character = "Character"
    case camera = "Camera"
    case motion = "Motion"

    var systemImage: String {
        switch self {
        case .location: return "globe.americas.fill"
        case .character: return "figure.stand"
        case .camera: return "camera.viewfinder"
        case .motion: return "video.fill"
        }
    }
}

/// Focal lengths for the handheld Motion-tab camera (35mm-equivalent, sensor
/// width convention).
enum FocalLength: Float, CaseIterable {
    case mm35 = 35
    case mm50 = 50
    case mm75 = 75
    case mm200 = 200

    var label: String { "\(Int(rawValue))mm" }

    var next: FocalLength {
        let all = FocalLength.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// Horizontal field of view for a full-frame (36mm wide) sensor.
    var horizontalFOVDegrees: Float {
        let sensorWidth: Float = 36
        return 2 * atan(sensorWidth / (2 * rawValue)) * 180 / .pi
    }
}

/// Focal lengths for the virtual production cameras placed in the Camera tab.
enum CameraLens: Float, CaseIterable {
    case mm24 = 24
    case mm35 = 35
    case mm50 = 50
    case mm85 = 85

    var label: String { "\(Int(rawValue))mm" }

    /// Vertical field of view for a fixed 24mm-tall sensor.
    var verticalFOVDegrees: Float {
        let sensorHeight: Float = 24
        return 2 * atan(sensorHeight / (2 * rawValue)) * 180 / .pi
    }
}

enum CharacterPose: String, CaseIterable, Codable {
    case standing = "Standing"
    case sitting = "Sitting"
    case kneeling = "Kneeling"
    case lying = "Lying"
    case crouch = "Crouch"
    case lean = "Lean"
    case fall = "Fall"
    case stance = "Stance"
    case sprint = "Sprint"
    case walk = "Walk"

    var systemImage: String {
        switch self {
        case .standing: return "figure.stand"
        case .sitting: return "figure.seated.side"
        case .kneeling: return "figure.cooldown"
        case .lying: return "bed.double.fill"
        case .crouch: return "figure.strengthtraining.functional"
        case .lean: return "figure.mixed.cardio"
        case .fall: return "figure.fall"
        case .stance: return "figure.boxing"
        case .sprint: return "figure.run"
        case .walk: return "figure.walk"
        }
    }
}

struct HumanPlacement: Identifiable, Equatable {
    let id: UUID
    var position: SIMD3<Float>
    var rotationY: Float
    var name: String
    var pose: CharacterPose
    /// Forward/backward sway (radians), pivoting at ground level, layered on top of whatever pose is active.
    var tiltPitch: Float
    /// Sideways sway (radians), pivoting at ground level, layered on top of whatever pose is active.
    var tiltRoll: Float
    /// Vertical lift above the floor (meters). Clamped to >= 0 — the character can be
    /// raised off the surface but never lowered below it.
    var liftHeight: Float

    init(
        id: UUID = UUID(),
        position: SIMD3<Float> = [0, 0, 0],
        rotationY: Float = 0,
        name: String = "",
        pose: CharacterPose = .standing,
        tiltPitch: Float = 0,
        tiltRoll: Float = 0,
        liftHeight: Float = 0
    ) {
        self.id = id
        self.position = position
        self.rotationY = rotationY
        self.name = name
        self.pose = pose
        self.tiltPitch = tiltPitch
        self.tiltRoll = tiltRoll
        self.liftHeight = liftHeight
    }
}

/// A virtual production camera placed in the Camera tab.
struct CameraPlacement: Identifiable, Equatable {
    let id: UUID
    var position: SIMD3<Float>
    /// Yaw (radians, about the world Y-axis) — left/right pan.
    var rotationY: Float
    /// Pitch (radians, about the camera's local X-axis) — up/down tilt.
    /// Clamped in `SceneState.adjustSelectedCameraAim` to just short of
    /// straight up/down so it can't flip past vertical.
    var rotationPitch: Float
    var name: String
    var lens: CameraLens

    init(
        id: UUID = UUID(),
        position: SIMD3<Float> = [0, 0, 0],
        rotationY: Float = 0,
        rotationPitch: Float = 0,
        name: String = "",
        lens: CameraLens = .mm35
    ) {
        self.id = id
        self.position = position
        self.rotationY = rotationY
        self.rotationPitch = rotationPitch
        self.name = name
        self.lens = lens
    }
}

@Observable
final class SceneState {
    var mode: AppSection = .character
    var humans: [HumanPlacement] = []
    var selectedHumanID: UUID?
    var cameras: [CameraPlacement] = []
    var selectedCameraID: UUID?
    var focalLength: FocalLength = .mm35
    var isRecording = false
    /// The active 3D room, generated from an uploaded photo in the Location
    /// tab (see RoomLayoutProcessor). `nil` means no room has been generated
    /// yet, and every tab falls back to the default studio grid. Shared here
    /// so Character, Camera, and Motion all render the same environment.
    var roomLayout: RoomLayout?
    /// The detected prop currently selected for review/deletion in the
    /// Location tab (see LocationPreviewView).
    var selectedPropID: UUID?

    func selectProp(id: UUID?) {
        selectedPropID = id
    }

    /// Removes the selected detected prop from the active room layout — for
    /// manually cleaning up false detections. No-op if nothing's selected or
    /// no room has been generated yet.
    func deleteSelectedProp() {
        guard let id = selectedPropID else { return }
        roomLayout?.detectedProps.removeAll { $0.id == id }
        selectedPropID = nil
    }

    func cycleFocalLength() {
        focalLength = focalLength.next
    }

    var selectedHuman: HumanPlacement? {
        guard let id = selectedHumanID else { return nil }
        return humans.first { $0.id == id }
    }

    func addHuman() {
        let offset = Float(humans.count) * 0.6
        let name = "Person \(humans.count + 1)"
        let placement = HumanPlacement(position: [offset, 0, 0], name: name)
        humans.append(placement)
        selectedHumanID = placement.id
    }

    func updateHumanName(id: UUID, name: String) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].name = name
    }

    func updateHumanPose(id: UUID, pose: CharacterPose) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].pose = pose
    }

    func deleteSelectedHuman() {
        guard let id = selectedHumanID else { return }
        humans.removeAll { $0.id == id }
        selectedHumanID = humans.last?.id
    }

    func selectHuman(id: UUID?) {
        selectedHumanID = id
    }

    /// `position.y` is height *above* the floor reference (see
    /// SceneContentBuilder.floorHeight) — 0 means resting on it. Clamped so a
    /// drag can never push a character below the floor it's standing on.
    func updateHumanPosition(id: UUID, position: SIMD3<Float>) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        var clamped = position
        clamped.y = max(0, clamped.y)
        humans[index].position = clamped
    }

    func updateHumanRotation(id: UUID, rotationY: Float) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].rotationY = rotationY
    }

    func rotateSelectedHuman(by delta: Float) {
        guard let id = selectedHumanID,
              let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].rotationY += delta
    }

    /// Nudges the selected character's forward/backward and sideways sway.
    /// Independent of `rotationY` (yaw) and of the active pose — this is a
    /// free trim layered on top of both, pivoting at ground level.
    func tiltSelectedHuman(pitchDelta: Float, rollDelta: Float) {
        guard let id = selectedHumanID,
              let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].tiltPitch += pitchDelta
        humans[index].tiltRoll += rollDelta
    }

    /// Raises/lowers the selected character above the floor. Clamped so it can
    /// never go below the surface (but can be lifted arbitrarily high above it).
    func liftSelectedHuman(by delta: Float) {
        guard let id = selectedHumanID,
              let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].liftHeight = min(2, max(0, humans[index].liftHeight + delta))
    }

    // MARK: - Cameras

    var selectedCamera: CameraPlacement? {
        guard let id = selectedCameraID else { return nil }
        return cameras.first { $0.id == id }
    }

    func addCamera() {
        let offset = Float(cameras.count) * 0.6
        let name = "Camera \(cameras.count + 1)"
        // Placed a few meters back at eye height, facing -Z (RealityKit's default
        // camera forward) back toward the origin, where characters spawn.
        let placement = CameraPlacement(position: [offset, 1.5, 3], name: name)
        cameras.append(placement)
        selectedCameraID = placement.id
    }

    func updateCameraName(id: UUID, name: String) {
        guard let index = cameras.firstIndex(where: { $0.id == id }) else { return }
        cameras[index].name = name
    }

    func updateCameraLens(id: UUID, lens: CameraLens) {
        guard let index = cameras.firstIndex(where: { $0.id == id }) else { return }
        cameras[index].lens = lens
    }

    func deleteSelectedCamera() {
        guard let id = selectedCameraID else { return }
        cameras.removeAll { $0.id == id }
        selectedCameraID = cameras.last?.id
    }

    func selectCamera(id: UUID?) {
        selectedCameraID = id
    }

    func updateCameraPosition(id: UUID, position: SIMD3<Float>) {
        guard let index = cameras.firstIndex(where: { $0.id == id }) else { return }
        cameras[index].position = position
    }

    /// Moves the camera straight up/down (Y-axis only), leaving its X/Z
    /// position, rotation, and lens untouched — the camera stays parallel to
    /// the floor plane, just higher or lower off it.
    func updateCameraHeight(id: UUID, height: Float) {
        guard let index = cameras.firstIndex(where: { $0.id == id }) else { return }
        cameras[index].position.y = max(0, height)
    }

    func rotateSelectedCamera(by delta: Float) {
        guard let id = selectedCameraID,
              let index = cameras.firstIndex(where: { $0.id == id }) else { return }
        cameras[index].rotationY += delta
    }

    /// Two-finger drag support: adjusts the selected camera's yaw and pitch
    /// together. Pitch is clamped just short of ±90° so it can swing from
    /// pointing at the floor to pointing straight up at a character's head
    /// without flipping past vertical (which would invert yaw).
    private static let maxCameraPitch: Float = 85 * .pi / 180

    func adjustSelectedCameraAim(yawDelta: Float, pitchDelta: Float) {
        guard let id = selectedCameraID,
              let index = cameras.firstIndex(where: { $0.id == id }) else { return }
        cameras[index].rotationY += yawDelta
        let newPitch = cameras[index].rotationPitch + pitchDelta
        cameras[index].rotationPitch = min(Self.maxCameraPitch, max(-Self.maxCameraPitch, newPitch))
    }
}
