import ARKit
import RealityKit
import SwiftUI
import UIKit

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
        coordinator.stop()
        uiView.session.pause()
    }
}

extension ARScannerView {
    @MainActor
    final class Coordinator: NSObject {
        private let viewModel: ARScannerViewModel
        private let essenceRenderer = ARSceneEssenceRenderer()
        private let lostSoulRenderer = ARSceneLostSoulRenderer()
        private let surfacePhaseRouteFactory = SurfacePhaseRouteFactory()
        private let cameraPostProcessor = VeilCameraPostProcessor()
        private weak var arView: ARView?
        private var displayLink: CADisplayLink?
        private var lockedTargetID: UUID?
        private var lockStartedAt: CFTimeInterval?
        private var lostSoulManifestationReadyAt: CFTimeInterval?
        private let haptic = UIImpactFeedbackGenerator(style: .light)

        private let essenceCollectionDistance: Float = 1
        private let lostSoulTrackingDistance: Float = 3
        private let lockOnDuration: CFTimeInterval = 1
        private let lockOnScreenRadius: CGFloat = 56

        init(viewModel: ARScannerViewModel) {
            self.viewModel = viewModel
        }

        func configure(_ arView: ARView) {
            self.arView = arView
            arView.automaticallyConfigureSession = false
            arView.backgroundColor = .black
            cameraPostProcessor.install(on: arView)

            #if DEBUG
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapGesture)
            #endif

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

            essenceRenderer.render(viewModel.visibleEssences, in: arView)
            haptic.prepare()
            startVacuumLoop()
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            viewModel.clearLockOn()
        }

        #if DEBUG
        @objc
        private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else {
                return
            }

            // Temporary debug fallback while scanner vacuum is tuned.
            let location = gesture.location(in: arView)
            let tappedEntity = arView.entity(at: location)

            guard
                let essenceID = essenceRenderer.essenceID(for: tappedEntity),
                let essencePosition = essenceRenderer.worldPosition(for: essenceID),
                simd_distance(arView.cameraTransform.translation, essencePosition) <= essenceCollectionDistance
            else {
                return
            }

            collectEssence(id: essenceID, in: arView)
        }
        #endif

        private func startVacuumLoop() {
            displayLink?.invalidate()

            let displayLink = CADisplayLink(target: self, selector: #selector(updateVacuumLock(_:)))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }

        @objc
        private func updateVacuumLock(_ displayLink: CADisplayLink) {
            guard let arView else {
                return
            }

            essenceRenderer.updateFloatingMotion(at: displayLink.timestamp)
            lostSoulRenderer.updateFloatingMotion(at: displayLink.timestamp)
            manifestLostSoulIfNeeded(in: arView)
            updatePostProcessEffects(in: arView)

            guard let target = bestScannerTarget(in: arView) else {
                clearVacuumLock()
                return
            }

            if lockedTargetID != target.id {
                lockedTargetID = target.id
                lockStartedAt = displayLink.timestamp
                viewModel.updateLockOn(targetID: target.id, progress: 0)
                return
            }

            let elapsed = displayLink.timestamp - (lockStartedAt ?? displayLink.timestamp)
            let progress = elapsed / lockOnDuration
            viewModel.updateLockOn(targetID: target.id, progress: progress)

            guard progress >= 1 else {
                return
            }

            switch target {
            case .essence(let id, _):
                collectEssence(id: id, in: arView)
            case .lostSoul(_, let worldPosition):
                beginLostSoulPhase(from: worldPosition, in: arView)
            }
        }

        private func bestScannerTarget(in arView: ARView) -> ScannerTarget? {
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let cameraPosition = arView.cameraTransform.translation

            if !viewModel.visibleEssences.isEmpty {
                return viewModel.visibleEssences
                    .compactMap { essence -> (target: ScannerTarget, screenDistance: CGFloat)? in
                        guard let worldPosition = essenceRenderer.worldPosition(for: essence.id) else {
                            return nil
                        }

                        guard simd_distance(cameraPosition, worldPosition) <= essenceCollectionDistance else {
                            return nil
                        }

                        guard let screenDistance = aimedScreenDistance(
                            to: worldPosition,
                            center: center,
                            in: arView
                        ) else {
                            return nil
                        }

                        return (
                            ScannerTarget.essence(id: essence.id, worldPosition: worldPosition),
                            screenDistance
                        )
                    }
                    .min { $0.screenDistance < $1.screenDistance }?
                    .target
            }

            guard
                let lostSoul = viewModel.lostSoulStore.lostSoul,
                let worldPosition = lostSoulRenderer.worldPosition(for: lostSoul.id),
                simd_distance(cameraPosition, worldPosition) <= lostSoulTrackingDistance,
                aimedScreenDistance(to: worldPosition, center: center, in: arView) != nil
            else {
                return nil
            }

            return .lostSoul(id: lostSoul.id, worldPosition: worldPosition)
        }

        private func updatePostProcessEffects(in arView: ARView) {
            let cameraPosition = arView.cameraTransform.translation
            let bounds = arView.bounds
            guard bounds.width > 0, bounds.height > 0 else {
                cameraPostProcessor.updateEssenceEffects([])
                return
            }

            let effects = viewModel.visibleEssences.compactMap { essence -> SIMD4<Float>? in
                guard
                    let worldPosition = essenceRenderer.worldPosition(for: essence.id),
                    let screenPosition = arView.project(worldPosition),
                    screenPosition.x >= -bounds.width * 0.25,
                    screenPosition.x <= bounds.width * 1.25,
                    screenPosition.y >= -bounds.height * 0.25,
                    screenPosition.y <= bounds.height * 1.25
                else {
                    return nil
                }

                let distance = max(0.35, simd_distance(cameraPosition, worldPosition))
                let effectRadius = min(max(0.12 / distance, 0.045), 0.2)
                let intensity = min(max(1.2 - distance * 0.12, 0.68), 1.08)

                return SIMD4<Float>(
                    Float(screenPosition.x / bounds.width),
                    Float(screenPosition.y / bounds.height),
                    effectRadius,
                    intensity
                )
            }

            cameraPostProcessor.updateEssenceEffects(effects)
        }

        private func aimedScreenDistance(
            to worldPosition: SIMD3<Float>,
            center: CGPoint,
            in arView: ARView
        ) -> CGFloat? {
            guard
                let screenPosition = arView.project(worldPosition),
                arView.bounds.contains(screenPosition)
            else {
                return nil
            }

            let screenDistance = hypot(screenPosition.x - center.x, screenPosition.y - center.y)
            return screenDistance <= lockOnScreenRadius ? screenDistance : nil
        }

        private func manifestLostSoulIfNeeded(in arView: ARView) {
            guard let lostSoul = viewModel.lostSoulStore.lostSoul else {
                return
            }

            if let readyAt = lostSoulManifestationReadyAt {
                guard CACurrentMediaTime() >= readyAt else {
                    return
                }

                lostSoulManifestationReadyAt = nil
            }

            lostSoulRenderer.render(lostSoul, in: arView)
        }

        private func beginLostSoulPhase(from worldPosition: SIMD3<Float>, in arView: ARView) {
            let planeAnchors = arView.session.currentFrame?.anchors.compactMap { anchor in
                anchor as? ARPlaneAnchor
            } ?? []

            guard let route = surfacePhaseRouteFactory.makeRoute(
                from: planeAnchors,
                targetPosition: worldPosition,
                cameraPosition: arView.cameraTransform.translation
            ) else {
                clearVacuumLock()
                return
            }

            clearVacuumLock()
            lostSoulRenderer.phase(along: route)
        }

        private func collectEssence(id: AmbientEssence.ID, in arView: ARView) {
            guard viewModel.collectEssence(id: id) else {
                return
            }

            haptic.impactOccurred()
            haptic.prepare()
            lockedTargetID = nil
            lockStartedAt = nil

            if viewModel.visibleEssences.isEmpty {
                lostSoulManifestationReadyAt = CACurrentMediaTime() + 0.62
            }

            essenceRenderer.collectEssence(id: id, from: arView)
        }

        private func clearVacuumLock() {
            guard lockedTargetID != nil || lockStartedAt != nil else {
                return
            }

            lockedTargetID = nil
            lockStartedAt = nil
            viewModel.clearLockOn()
        }
    }
}

private enum ScannerTarget {
    case essence(id: AmbientEssence.ID, worldPosition: SIMD3<Float>)
    case lostSoul(id: LostSoul.ID, worldPosition: SIMD3<Float>)

    var id: UUID {
        switch self {
        case .essence(let id, _), .lostSoul(let id, _):
            return id
        }
    }
}
