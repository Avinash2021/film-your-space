//
//  CameraViewfinderView.swift
//  film space
//

import SwiftUI
import RealityKit
import Photos
import UniformTypeIdentifiers

/// Lets the SwiftUI panel trigger imperative actions (capture) on the
/// UIViewRepresentable's Coordinator without threading state through bindings.
@MainActor
final class CameraViewfinderController {
    fileprivate weak var coordinator: CameraViewfinderView.Coordinator?

    func captureStoryboard() {
        coordinator?.captureStoryboard()
    }
}

/// The Camera tab's main viewport: displays the same characters and camera
/// props as the Character tab, either from a free-orbiting overview (when no
/// camera is selected) or locked to a selected camera's exact transform and
/// lens (when one is), matching an SCNView's `pointOfView` switch — RealityKit
/// has no direct equivalent, so this is implemented by snapping the one live
/// render camera's transform + `PerspectiveCameraComponent` to the selected
/// camera's stored data each time selection changes.
struct CameraViewfinderView: UIViewRepresentable {
    @Bindable var sceneState: SceneState
    let controller: CameraViewfinderController

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneState: sceneState)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(SceneEnvironment.studioGrey)
        context.coordinator.setup(in: arView)
        controller.coordinator = context.coordinator
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.sceneState = sceneState
        context.coordinator.rebuildScene()
    }

    final class Coordinator: NSObject {
        var sceneState: SceneState
        private let freeCamera = OrbitCameraController()

        private weak var arView: ARView?
        private var studioRoot: Entity?
        private var liveCamera: Entity?
        private var lastHumanSignature = ""
        private var lastCameraSignature = ""

        init(sceneState: SceneState) {
            self.sceneState = sceneState
        }

        func setup(in arView: ARView) {
            self.arView = arView

            let anchor = AnchorEntity(world: .zero)
            let root = SceneEnvironment.makeStudioRoot()
            anchor.addChild(root)
            studioRoot = root

            let camera = freeCamera.makeCameraEntity()
            anchor.addChild(camera)
            liveCamera = camera

            arView.scene.addAnchor(anchor)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tap)

            // One-finger pan: reposition the selected camera, or free-orbit the
            // overview when nothing's selected. Capped at exactly one touch so
            // it can't also fire (and conflict) on two-finger gestures.
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            arView.addGestureRecognizer(pan)

            // Two-finger pan: aim the selected camera (yaw/pitch). Separate
            // recognizer so it never competes with the one-finger move/orbit pan.
            let aim = UIPanGestureRecognizer(target: self, action: #selector(handleAimPan(_:)))
            aim.minimumNumberOfTouches = 2
            aim.maximumNumberOfTouches = 2
            arView.addGestureRecognizer(aim)

            rebuildScene()
        }

        func rebuildScene() {
            guard let root = studioRoot else { return }

            // RoomEnvironmentBuilder dedups internally against the layout it
            // last built, so calling this unconditionally is cheap.
            RoomEnvironmentBuilder.sync(layout: sceneState.roomLayout, into: root)

            let humanSignature = sceneState.humans
                .map { "\($0.id)-\($0.position)-\($0.rotationY)-\($0.name)-\($0.pose.rawValue)-\($0.tiltPitch)-\($0.tiltRoll)-\($0.liftHeight)" }
                .joined(separator: "|")
            if humanSignature != lastHumanSignature {
                lastHumanSignature = humanSignature
                SceneContentBuilder.syncHumans(placements: sceneState.humans, selectedID: nil, into: root)
            }

            let cameraSignature = sceneState.cameras
                .map { "\($0.id)-\($0.position)-\($0.rotationY)-\($0.rotationPitch)-\($0.name)-\($0.lens.rawValue)" }
                .joined(separator: "|")
            if cameraSignature != lastCameraSignature {
                lastCameraSignature = cameraSignature
                CameraContentBuilder.syncCameras(placements: sceneState.cameras, into: root)
            }

            updateViewpoint()
        }

        // Snaps the one live camera to the selected CameraPlacement's transform
        // and lens (locked "through the lens" view); falls back to the free
        // orbit camera when nothing is selected. Whenever a camera is active,
        // every camera helper node/name-tag in the scene is hidden — including
        // the active one's own — so nothing blocks its own lens and no other
        // camera's rig appears in the shot.
        private func updateViewpoint() {
            guard let liveCamera else { return }

            if let selected = sceneState.selectedCamera {
                liveCamera.orientation = simd_quatf(angle: selected.rotationY, axis: [0, 1, 0])
                    * simd_quatf(angle: selected.rotationPitch, axis: [1, 0, 0])
                liveCamera.position = selected.position
                var component = liveCamera.components[PerspectiveCameraComponent.self] ?? PerspectiveCameraComponent()
                component.fieldOfViewOrientation = .vertical
                component.fieldOfViewInDegrees = selected.lens.verticalFOVDegrees
                liveCamera.components.set(component)
                setCameraHelpersHidden(true)
            } else {
                liveCamera.components.set(PerspectiveCameraComponent())
                freeCamera.updateCameraTransform()
                setCameraHelpersHidden(false)
            }
        }

        private func cameraHelperEntities() -> [Entity] {
            guard let root = studioRoot else { return [] }
            return root.children.filter { $0.name == "CameraNode" || $0.name == "CameraNameTag" }
        }

        private func setCameraHelpersHidden(_ hidden: Bool) {
            for entity in cameraHelperEntities() {
                entity.isEnabled = !hidden
            }
        }

        // Tap a camera's frustum to select it (locking the viewport to its
        // perspective — see updateViewpoint); tap empty space to deselect and
        // return to the free-orbiting overview.
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView, let view = gesture.view else { return }
            let point = gesture.location(in: view)
            if let tapped = arView.entity(at: point), let tag = cameraTag(for: tapped) {
                sceneState.selectCamera(id: tag.id)
            } else {
                sceneState.selectCamera(id: nil)
            }
        }

        private func cameraTag(for entity: Entity) -> CameraTagComponent? {
            var current: Entity? = entity
            while let node = current {
                if let tag = node.components[CameraTagComponent.self] { return tag }
                current = node.parent
            }
            return nil
        }

        // With a camera selected, dragging slides it around relative to its own
        // facing (drag up = dolly forward, left/right = truck sideways) — you
        // see the effect live through its own (otherwise-hidden) viewpoint.
        // With nothing selected, dragging orbits the free-look overview camera.
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            gesture.setTranslation(.zero, in: view)

            if let selected = sceneState.selectedCamera {
                let yaw = simd_quatf(angle: selected.rotationY, axis: [0, 1, 0])
                let forward = yaw.act(SIMD3<Float>(0, 0, -1))
                let right = yaw.act(SIMD3<Float>(1, 0, 0))
                let scale: Float = 0.012
                let delta = right * (Float(translation.x) * scale) + forward * (Float(-translation.y) * scale)
                sceneState.updateCameraPosition(id: selected.id, position: selected.position + delta)
            } else {
                freeCamera.orbit(
                    deltaAzimuth: Float(translation.x) * 0.005,
                    deltaElevation: -Float(translation.y) * 0.005
                )
            }
        }

        // Two-finger drag aims the selected camera: horizontal = yaw (pan
        // left/right), vertical = pitch (tilt up/down, dragging up looks up).
        // No-op when nothing's selected — this gesture is for aiming an active
        // camera, not for navigating the free-look overview.
        @objc private func handleAimPan(_ gesture: UIPanGestureRecognizer) {
            guard sceneState.selectedCamera != nil, let view = gesture.view else { return }
            let translation = gesture.translation(in: view)
            gesture.setTranslation(.zero, in: view)

            let scale: Float = 0.006
            sceneState.adjustSelectedCameraAim(
                yawDelta: Float(translation.x) * scale,
                pitchDelta: Float(-translation.y) * scale
            )
        }

        func captureStoryboard() {
            guard let arView else { return }

            // Force every camera helper invisible right before the snapshot —
            // independent of the current lock state — so a capture taken from
            // the free-orbiting overview (with nothing locked, helpers normally
            // visible) still comes out clean, then restore afterward.
            let helpers = cameraHelperEntities()
            let previousStates = helpers.map(\.isEnabled)
            helpers.forEach { $0.isEnabled = false }

            arView.snapshot(saveToHDR: false) { image in
                for (entity, wasEnabled) in zip(helpers, previousStates) {
                    entity.isEnabled = wasEnabled
                }

                guard let image, let pngData = image.pngData() else { return }
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    guard status == .authorized || status == .limited else { return }
                    PHPhotoLibrary.shared().performChanges {
                        let options = PHAssetResourceCreationOptions()
                        options.uniformTypeIdentifier = UTType.png.identifier
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: pngData, options: options)
                    }
                }
            }
        }
    }
}
