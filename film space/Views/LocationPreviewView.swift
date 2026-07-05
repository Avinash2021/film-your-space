//
//  LocationPreviewView.swift
//  film space
//

import SwiftUI
import RealityKit
import PhotosUI

/// The Location tab: pick a flat photo of a room, run it through
/// RoomLayoutProcessor, and preview the generated 3D layout. Once generated,
/// the room is stored on `sceneState.roomLayout` — shared session state that
/// Character, Camera, and Motion all render (see RoomEnvironmentBuilder), so
/// switching tabs after a successful upload drops you into the same room.
struct LocationPreviewView: View {
    @Bindable var sceneState: SceneState

    @State private var cameraController = OrbitCameraController()
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1
    @State private var studioRoot: Entity?

    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false

    var body: some View {
        let roomLayout = sceneState.roomLayout
        let selectedPropID = sceneState.selectedPropID

        ZStack {
            RealityView { content in
                content.add(cameraController.makeCameraEntity())

                let root = SceneEnvironment.makeStudioRoot()
                content.add(root)
                studioRoot = root

                RoomEnvironmentBuilder.sync(layout: roomLayout, selectedPropID: selectedPropID, into: root)
            } update: { _ in
                guard let root = studioRoot else { return }
                RoomEnvironmentBuilder.sync(layout: roomLayout, selectedPropID: selectedPropID, into: root)
            }
            .gesture(lookAroundGesture)
            .simultaneousGesture(zoomGesture)
            .highPriorityGesture(selectPropGesture)
            .gesture(deselectPropGesture)
            .background(.black)
            .ignoresSafeArea()

            VStack {
                if let selectedProp {
                    selectedPropBar(selectedProp)
                        .padding(.top, 16)
                }
                Spacer()
                uploadButton
                    .padding(.bottom, 40)
            }

            if isProcessing {
                ProcessingOverlay()
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePick(newItem) }
        }
    }

    private var selectedProp: RoomLayout.Prop? {
        guard let id = sceneState.selectedPropID else { return nil }
        return sceneState.roomLayout?.detectedProps.first { $0.id == id }
    }

    // Tap a prop to select it (highlighted yellow — see RoomEnvironmentBuilder)
    // and reveal this bar; tap it again, or tap empty space, to delete or
    // dismiss. This is how false detections get manually cleaned up.
    private func selectedPropBar(_ prop: RoomLayout.Prop) -> some View {
        HStack(spacing: 12) {
            Text(prop.type.capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.15)))

            Button {
                sceneState.deleteSelectedProp()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    // Fires only when a prop is tapped (props have InputTargetComponent). High
    // priority so it wins over the deselect tap / look-around drag.
    private var selectPropGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if let tag = propTag(for: value.entity) {
                    sceneState.selectProp(id: tag.propID)
                }
            }
    }

    // Fires when the tap doesn't hit a prop (empty space, floor, walls).
    private var deselectPropGesture: some Gesture {
        TapGesture()
            .onEnded {
                sceneState.selectProp(id: nil)
            }
    }

    private func propTag(for entity: Entity) -> RoomPropComponent? {
        var current: Entity? = entity
        while let node = current {
            if let tag = node.components[RoomPropComponent.self] {
                return tag
            }
            current = node.parent
        }
        return nil
    }

    private var uploadButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("Upload Location Image", systemImage: "photo.badge.plus")
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        }
        .disabled(isProcessing)
    }

    private func handlePick(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { pickerItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            isProcessing = false
            return
        }

        await withCheckedContinuation { continuation in
            RoomLayoutProcessor.process(image) { layout in
                // Publishing the new layout here is what drives the scene
                // rebuild everywhere: this view's own preview updates
                // immediately, and Character/Camera/Motion pick it up the
                // next time they're shown (RoomEnvironmentBuilder.sync purges
                // only the environment node — characters, cameras, and name
                // tags in those scenes are untouched).
                sceneState.roomLayout = layout
                isProcessing = false
                continuation.resume()
            }
        }
    }

    private var lookAroundGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let delta = CGSize(
                    width: value.translation.width - lastDragTranslation.width,
                    height: value.translation.height - lastDragTranslation.height
                )
                lastDragTranslation = value.translation
                cameraController.orbit(
                    deltaAzimuth: Float(delta.width) * 0.005,
                    deltaElevation: -Float(delta.height) * 0.005
                )
            }
            .onEnded { _ in lastDragTranslation = .zero }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                cameraController.zoom(scale: Float(scale / lastMagnification))
                lastMagnification = scale
            }
            .onEnded { _ in lastMagnification = 1 }
    }
}

private struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
                Text("Generating 3D layout…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    LocationPreviewView(sceneState: SceneState())
}
