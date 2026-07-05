//
//  ContentView.swift
//  film space
//

import Combine
import SwiftUI

struct ContentView: View {
    @State private var sceneState = SceneState()
    @State private var cameraController = OrbitCameraController()
    @State private var viewfinderController = CameraViewfinderController()

    var body: some View {
        TabView(selection: $sceneState.mode) {
            LocationPreviewView(sceneState: sceneState)
                .ignoresSafeArea()
                .tabItem { Label(AppSection.location.rawValue, systemImage: AppSection.location.systemImage) }
                .tag(AppSection.location)

            CharacterTab(sceneState: sceneState, cameraController: cameraController)
                .tabItem { Label(AppSection.character.rawValue, systemImage: AppSection.character.systemImage) }
                .tag(AppSection.character)

            CameraTab(sceneState: sceneState, controller: viewfinderController)
                .tabItem { Label(AppSection.camera.rawValue, systemImage: AppSection.camera.systemImage) }
                .tag(AppSection.camera)

            MotionTab(sceneState: sceneState, cameraController: cameraController)
                .tabItem { Label(AppSection.motion.rawValue, systemImage: AppSection.motion.systemImage) }
                .tag(AppSection.motion)
        }
    }
}

// MARK: - Character tab

// The existing mannequin/pose editor: unchanged behavior, just relocated into
// its own tab. `sceneState` and `cameraController` are owned by ContentView and
// passed by reference here and into the Motion tab, so every character node,
// position, pose, and the camera's locked pose all persist across tab switches.
private struct CharacterTab: View {
    @Bindable var sceneState: SceneState
    @Bindable var cameraController: OrbitCameraController

    var body: some View {
        ZStack {
            VirtualStudioView(sceneState: sceneState, cameraController: cameraController)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let selected = sceneState.selectedHuman {
                    NameField(sceneState: sceneState, humanID: selected.id, name: selected.name)
                        .padding(.top, 16)

                    PoseSelector(sceneState: sceneState, humanID: selected.id, pose: selected.pose)

                    HStack(spacing: 12) {
                        LiftControl(sceneState: sceneState, humanID: selected.id)
                        SwayControl(sceneState: sceneState, humanID: selected.id)
                    }
                }

                Spacer()
                StudioToolbar(sceneState: sceneState, cameraController: cameraController)
                    .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Camera tab

// The new multi-camera viewfinder: shows the same characters/positions as the
// Character tab, lets you spawn/select/aim/lens virtual cameras, and capture a
// clean PNG of whichever viewpoint is active.
private struct CameraTab: View {
    @Bindable var sceneState: SceneState
    let controller: CameraViewfinderController

    var body: some View {
        ZStack {
            CameraViewfinderView(sceneState: sceneState, controller: controller)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                CameraListBar(sceneState: sceneState)
                    .padding(.top, 16)

                if let selected = sceneState.selectedCamera {
                    CameraNameField(sceneState: sceneState, cameraID: selected.id, name: selected.name)
                    CameraLensSelector(sceneState: sceneState, cameraID: selected.id, lens: selected.lens)
                }

                Spacer()

                if let selected = sceneState.selectedCamera {
                    CameraMoveControl(sceneState: sceneState, cameraID: selected.id)
                }

                CameraActionBar(sceneState: sceneState, controller: controller)
                    .padding(.bottom, 16)
            }

            if let selected = sceneState.selectedCamera {
                CameraHeightArrows(sceneState: sceneState, cameraID: selected.id, height: selected.position.y)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Motion tab

// The existing AR/VR tracking + recording screen: unchanged behavior, just
// relocated into its own tab and renamed from "Camera" to avoid clashing with
// the new Camera (viewfinder) tab's name.
private struct MotionTab: View {
    @Bindable var sceneState: SceneState
    @Bindable var cameraController: OrbitCameraController

    var body: some View {
        ZStack {
            ARCameraView(sceneState: sceneState, cameraController: cameraController)
                .ignoresSafeArea()

            VStack {
                Spacer()
                StudioToolbar(sceneState: sceneState, cameraController: cameraController)
                    .padding(.bottom, 16)
            }
        }
    }
}

// Compact rename field for the currently-selected character, shown above the toolbar.
private struct NameField: View {
    @Bindable var sceneState: SceneState
    let humanID: UUID
    @State private var name: String

    init(sceneState: SceneState, humanID: UUID, name: String) {
        self.sceneState = sceneState
        self.humanID = humanID
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
            .id(humanID)
            .onChange(of: name) { _, newValue in
                sceneState.updateHumanName(id: humanID, name: newValue)
            }
    }
}

// Pose picker for the currently-selected character, shown below the name field.
private struct PoseSelector: View {
    @Bindable var sceneState: SceneState
    let humanID: UUID
    let pose: CharacterPose

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(CharacterPose.allCases, id: \.self) { option in
                    Button {
                        sceneState.updateHumanPose(id: humanID, pose: option)
                    } label: {
                        Image(systemName: option.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(pose == option ? .black : .white)
                            .frame(width: 40, height: 36)
                            .background {
                                if pose == option {
                                    Capsule().fill(.white)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }
}

// Shared hold-to-repeat button for the character adjustment controls below.
// Uses `.highPriorityGesture` rather than `.gesture` — these controls sit as an
// overlay directly on top of the RealityView, which owns full-screen drag
// gestures of its own (orbit, select, drag-to-move); without priority, touches
// here were being captured by the 3D view underneath instead of the button.
private func adjustButton(systemName: String, setActive: @escaping (Bool) -> Void) -> some View {
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

// Raises/lowers the selected character off the floor. Clamped in SceneState so
// it can never go below the surface, only above it.
private struct LiftControl: View {
    @Bindable var sceneState: SceneState
    let humanID: UUID

    @State private var liftDirection: Float = 0
    private let tick = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    private let liftSpeed: Float = 0.015

    var body: some View {
        VStack(spacing: 4) {
            adjustButton(systemName: "arrow.up.to.line.compact") { active in liftDirection = active ? 1 : 0 }
            adjustButton(systemName: "arrow.down.to.line.compact") { active in liftDirection = active ? -1 : 0 }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .onReceive(tick) { _ in
            guard liftDirection != 0 else { return }
            sceneState.liftSelectedHuman(by: liftDirection * liftSpeed)
        }
    }
}

// Sways the selected character sideways and front/back, pivoting at ground
// level (see SceneContentBuilder) so it leans from a fixed foot point rather
// than floating. Independent of pose and yaw, and — since the character and
// the environment sphere live in entirely separate scenes (Studio vs.
// LocationPreviewView) — independent of the 360° environment too.
private struct SwayControl: View {
    @Bindable var sceneState: SceneState
    let humanID: UUID

    @State private var pitchDirection: Float = 0
    @State private var rollDirection: Float = 0

    private let tick = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    private let swaySpeed: Float = 0.02

    var body: some View {
        VStack(spacing: 2) {
            adjustButton(systemName: "chevron.up") { active in pitchDirection = active ? -1 : 0 }
            HStack(spacing: 2) {
                adjustButton(systemName: "chevron.left") { active in rollDirection = active ? -1 : 0 }
                adjustButton(systemName: "chevron.right") { active in rollDirection = active ? 1 : 0 }
            }
            adjustButton(systemName: "chevron.down") { active in pitchDirection = active ? 1 : 0 }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .onReceive(tick) { _ in
            guard pitchDirection != 0 || rollDirection != 0 else { return }
            sceneState.tiltSelectedHuman(
                pitchDelta: pitchDirection * swaySpeed,
                rollDelta: rollDirection * swaySpeed
            )
        }
    }
}

#Preview {
    ContentView()
}
