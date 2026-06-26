import ARKit
import RealityKit
import SwiftUI

struct ARScannerView: UIViewRepresentable {
    @ObservedObject var viewModel: ARScannerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }
}

extension ARScannerView {
    @MainActor
    final class Coordinator: NSObject {
        private let viewModel: ARScannerViewModel
        private let renderer = ARSceneEssenceRenderer()
        private weak var arView: ARView?

        init(viewModel: ARScannerViewModel) {
            self.viewModel = viewModel
        }

        func configure(_ arView: ARView) {
            self.arView = arView
            arView.automaticallyConfigureSession = false
            arView.backgroundColor = .black

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapGesture)

            guard ARWorldTrackingConfiguration.isSupported else {
                Task { @MainActor in
                    viewModel.markScannerUnavailable()
                }
                return
            }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.environmentTexturing = .automatic
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            renderer.render(viewModel.visibleEssences, in: arView)
        }

        @objc
        private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else {
                return
            }

            let location = gesture.location(in: arView)
            let tappedEntity = arView.entity(at: location)

            guard let essenceID = renderer.essenceID(for: tappedEntity) else {
                return
            }

            guard viewModel.collectEssence(id: essenceID) else {
                return
            }

            renderer.removeEssence(id: essenceID, from: arView)
        }
    }
}
