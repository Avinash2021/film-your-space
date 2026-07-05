//
//  ContentView.swift
//  film space
//

import SwiftUI

struct ContentView: View {
    @State private var sceneState = SceneState()
    @State private var cameraController = OrbitCameraController()

    // TEMPORARY: dev entry point into the new Location module while it's being
    // built out. Remove once Location has a real place in the app's navigation.
    @State private var showLocationPreview = false

    var body: some View {
        ZStack {
            Group {
                switch sceneState.mode {
                case .edit:
                    VirtualStudioView(sceneState: sceneState, cameraController: cameraController)
                case .camera:
                    ARCameraView(sceneState: sceneState, cameraController: cameraController)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                if sceneState.mode == .edit, let selected = sceneState.selectedHuman {
                    NameField(sceneState: sceneState, humanID: selected.id, name: selected.name)
                        .padding(.top, 16)

                    PoseSelector(sceneState: sceneState, humanID: selected.id, pose: selected.pose)
                }

                Spacer()
                StudioToolbar(sceneState: sceneState, cameraController: cameraController)
                    .padding(.bottom, 16)
            }

            VStack {
                HStack {
                    Spacer()
                    LocationDevEntryButton(showLocationPreview: $showLocationPreview)
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showLocationPreview) {
            LocationPreviewDevContainer(isPresented: $showLocationPreview)
        }
    }
}

// TEMPORARY: dev-only button that opens the Location module preview. Remove
// alongside `showLocationPreview` once Location has a permanent entry point.
private struct LocationDevEntryButton: View {
    @Binding var showLocationPreview: Bool

    var body: some View {
        Button {
            showLocationPreview = true
        } label: {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// TEMPORARY: wraps LocationPreviewView with a close button for the dev cover.
private struct LocationPreviewDevContainer: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            LocationPreviewView()

            VStack {
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    .padding(.leading, 16)

                    Spacer()
                }
                Spacer()
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

#Preview {
    ContentView()
}
