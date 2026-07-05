//
//  CameraPanel.swift
//  film space
//

import Combine
import RealityKit
import SwiftUI

// Hold-to-repeat button matching the rest of the app's controls.
// `.highPriorityGesture`: this panel overlays the ARView-backed viewfinder
// directly, and needs to win any touch conflict with it.
private func cameraPanelButton(systemName: String, setActive: @escaping (Bool) -> Void) -> some View {
    Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 34, height: 30)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in setActive(true) }
                .onEnded { _ in setActive(false) }
        )
}

// Top bar: horizontally-scrolling list of spawned cameras (tap to select and
// instantly switch the viewport's point of view to that camera) plus the
// "+ Add Camera" button.
struct CameraListBar: View {
    @Bindable var sceneState: SceneState

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(sceneState.cameras) { camera in
                        Button {
                            sceneState.selectCamera(id: camera.id)
                        } label: {
                            Text(camera.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(sceneState.selectedCameraID == camera.id ? .black : .white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background {
                                    if sceneState.selectedCameraID == camera.id {
                                        Capsule().fill(.white)
                                    }
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Button {
                sceneState.addCamera()
            } label: {
                Label("Add Camera", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
                    .fixedSize()
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }
}

// Rename field for the selected camera — same rename pattern used for characters.
struct CameraNameField: View {
    @Bindable var sceneState: SceneState
    let cameraID: UUID
    @State private var name: String

    init(sceneState: SceneState, cameraID: UUID, name: String) {
        self.sceneState = sceneState
        self.cameraID = cameraID
        self._name = State(initialValue: name)
    }

    var body: some View {
        TextField("Name", text: $name)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            .frame(maxWidth: 220)
            .id(cameraID)
            .onChange(of: name) { _, newValue in
                sceneState.updateCameraName(id: cameraID, name: newValue)
            }
    }
}

// Lens selector: 24/35/50/85mm, industry-standard focal lengths, using a fixed
// 24mm sensor height to compute vertical FOV (see CameraLens).
struct CameraLensSelector: View {
    @Bindable var sceneState: SceneState
    let cameraID: UUID
    let lens: CameraLens

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CameraLens.allCases, id: \.self) { option in
                Button {
                    sceneState.updateCameraLens(id: cameraID, lens: option)
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(lens == option ? .black : .white)
                        .frame(width: 52, height: 36)
                        .background {
                            if lens == option {
                                Capsule().fill(.white)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }
}

// Reposition (relative to the camera's own facing) and re-aim the selected
// camera. Hold to move/rotate continuously, matching the rest of the app.
struct CameraMoveControl: View {
    @Bindable var sceneState: SceneState
    let cameraID: UUID

    @State private var forwardDirection: Float = 0
    @State private var rightDirection: Float = 0
    @State private var rotateDirection: Float = 0

    private let tick = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    private let moveSpeed: Float = 0.03
    private let rotationSpeed: Float = 0.03

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                cameraPanelButton(systemName: "chevron.up") { active in forwardDirection = active ? 1 : 0 }
                HStack(spacing: 2) {
                    cameraPanelButton(systemName: "chevron.left") { active in rightDirection = active ? -1 : 0 }
                    cameraPanelButton(systemName: "chevron.right") { active in rightDirection = active ? 1 : 0 }
                }
                cameraPanelButton(systemName: "chevron.down") { active in forwardDirection = active ? -1 : 0 }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.15)))

            VStack(spacing: 4) {
                cameraPanelButton(systemName: "arrow.counterclockwise") { active in rotateDirection = active ? 1 : 0 }
                cameraPanelButton(systemName: "arrow.clockwise") { active in rotateDirection = active ? -1 : 0 }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .onReceive(tick) { _ in
            guard let camera = sceneState.selectedCamera, camera.id == cameraID else { return }
            if rotateDirection != 0 {
                sceneState.rotateSelectedCamera(by: rotateDirection * rotationSpeed)
            }
            if forwardDirection != 0 || rightDirection != 0 {
                let yaw = simd_quatf(angle: camera.rotationY, axis: [0, 1, 0])
                let forward = yaw.act(SIMD3<Float>(0, 0, -1))
                let right = yaw.act(SIMD3<Float>(1, 0, 0))
                let delta = forward * (forwardDirection * moveSpeed) + right * (rightDirection * moveSpeed)
                sceneState.updateCameraPosition(id: cameraID, position: camera.position + delta)
            }
        }
    }
}

// Up/Down arrows: tap to step the selected camera's height (Y-axis only) up
// or down, keeping it parallel to the floor plane — its X/Z position,
// rotation, and lens are untouched (see SceneState.updateCameraHeight).
struct CameraHeightArrows: View {
    @Bindable var sceneState: SceneState
    let cameraID: UUID
    let height: Float

    private let step: Float = 0.15

    var body: some View {
        VStack(spacing: 10) {
            Button {
                sceneState.updateCameraHeight(id: cameraID, height: height + step)
            } label: {
                arrowIcon("arrow.up")
            }
            .buttonStyle(.plain)

            Text(String(format: "%.1fm", height))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))

            Button {
                sceneState.updateCameraHeight(id: cameraID, height: height - step)
            } label: {
                arrowIcon("arrow.down")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private func arrowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.15)))
    }
}

// Always-visible action row: capture a clean PNG of the active viewport, and
// (when a camera is selected) delete it.
struct CameraActionBar: View {
    @Bindable var sceneState: SceneState
    let controller: CameraViewfinderController

    var body: some View {
        HStack(spacing: 12) {
            if sceneState.selectedCameraID != nil {
                Button {
                    sceneState.deleteSelectedCamera()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }

            Button {
                controller.captureStoryboard()
            } label: {
                Label("Capture Storyboard", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}
