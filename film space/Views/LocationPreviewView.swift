//
//  LocationPreviewView.swift
//  film space
//

import SwiftUI
import RealityKit

/// Standalone preview of a 360° location environment: a camera sits at the
/// center of a large sphere textured on its inside walls. Drag to look
/// around, pinch to move closer/farther from center.
struct LocationPreviewView: View {
    @State private var cameraController = OrbitCameraController()
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1

    var body: some View {
        RealityView { content in
            content.add(cameraController.makeCameraEntity())
            content.add(LocationEnvironmentFactory.makeSkybox())
        }
        .gesture(lookAroundGesture)
        .simultaneousGesture(zoomGesture)
        .background(.black)
        .ignoresSafeArea()
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

#Preview {
    LocationPreviewView()
}
