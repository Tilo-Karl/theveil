import ARKit
import RealityKit
import SwiftUI
import UIKit

struct ARScannerView: UIViewRepresentable {
    @ObservedObject var viewModel: ARScannerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> SpectralARContainerView {
        let scannerView = context.coordinator.makeScannerView()
        context.coordinator.configure(scannerView.arView)
        return scannerView
    }

    func updateUIView(_ uiView: SpectralARContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: SpectralARContainerView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.stop()
        uiView.arView.session.pause()
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
        private let overloadHaptic = UIImpactFeedbackGenerator(style: .heavy)
        private var hasRenderedEssenceField = false
        private var renderedEssenceFieldRevision = -1
        private var handledOverloadEventCount = 0
        #if DEBUG
        private var debugForcedTargetID: AmbientEssence.ID?
        private let planeDebugRenderer = ARPlaneDebugRenderer()
        private let traversalDebugRenderer = ARSurfaceTraversalDebugRenderer()
        private var handledDebugTraversalEventCount = 0
        #endif

        private let essenceCollectionDistance: Float = 1
        private let lostSoulTrackingDistance: Float = 3
        private let essenceContainmentDuration: CFTimeInterval = 2.5
        private let lostSoulLockDuration: CFTimeInterval = 1
        private let lockOnScreenRadius: CGFloat = 56

        init(viewModel: ARScannerViewModel) {
            self.viewModel = viewModel
        }

        func makeScannerView() -> SpectralARContainerView {
            SpectralARContainerView(postProcessor: cameraPostProcessor)
        }

        func configure(_ arView: ARView) {
            self.arView = arView
            arView.automaticallyConfigureSession = false
            arView.renderOptions.insert(.disableGroundingShadows)

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

            haptic.prepare()
            overloadHaptic.prepare()
            startVacuumLoop()
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            if let arView {
                #if DEBUG
                planeDebugRenderer.removeAll(from: arView)
                traversalDebugRenderer.remove(from: arView)
                #endif
            }
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
                viewModel.canContainEssence,
                essenceRenderer.isCapturable(id: essenceID)
            else {
                return
            }

            if viewModel.debugAutoLockEnabled {
                debugForcedTargetID = essenceID
                lockedTargetID = essenceID
                lockStartedAt = CACurrentMediaTime()
                viewModel.updateLockOn(targetID: essenceID, progress: 0)
                return
            }

            guard
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

            viewModel.updateScannerStartup(at: displayLink.timestamp)
            cameraPostProcessor.setLensIntensity(viewModel.lensIntensity)

            let planeAnchors = arView.session.currentFrame?.anchors.compactMap { anchor in
                anchor as? ARPlaneAnchor
            } ?? []

            if
                viewModel.isScannerActive,
                (!hasRenderedEssenceField || renderedEssenceFieldRevision != viewModel.essenceFieldRevision)
            {
                essenceRenderer.render(viewModel.visibleEssences, in: arView)
                hasRenderedEssenceField = true
                renderedEssenceFieldRevision = viewModel.essenceFieldRevision
            }

            #if DEBUG
            updatePlaneDebug(with: planeAnchors, at: displayLink.timestamp, in: arView)
            #endif

            if hasRenderedEssenceField {
                if viewModel.overloadEventCounter > handledOverloadEventCount {
                    handledOverloadEventCount = viewModel.overloadEventCounter
                    clearVacuumLock()
                    essenceRenderer.beginAwakening(at: displayLink.timestamp)
                    overloadHaptic.impactOccurred(intensity: 1)
                    overloadHaptic.prepare()
                }

                essenceRenderer.updateFloatingMotion(
                    at: displayLink.timestamp,
                    planeAnchors: planeAnchors,
                    cameraPosition: arView.cameraTransform.translation
                )
            }
            lostSoulRenderer.update(
                at: displayLink.timestamp,
                cameraPosition: arView.cameraTransform.translation
            )
            manifestLostSoulIfNeeded(in: arView)
            updatePostProcessEffects(in: arView)

            guard viewModel.isScannerActive else {
                clearVacuumLock()
                viewModel.updateSpectralSignal(
                    strength: 0.05,
                    anomalyDetected: false,
                    lockProgress: nil
                )
                return
            }

            let signalSample = scannerSignalSample(in: arView)
            guard let target = bestScannerTarget(in: arView) else {
                clearVacuumLock()
                viewModel.updateSpectralSignal(
                    strength: signalSample.strength,
                    anomalyDetected: signalSample.anomalyDetected,
                    lockProgress: nil
                )
                return
            }

            if lockedTargetID != target.id {
                lockedTargetID = target.id
                lockStartedAt = displayLink.timestamp
                viewModel.updateLockOn(targetID: target.id, progress: 0)
                viewModel.updateSpectralSignal(
                    strength: max(signalSample.strength, 0.62),
                    anomalyDetected: true,
                    lockProgress: 0
                )
                return
            }

            let elapsed = displayLink.timestamp - (lockStartedAt ?? displayLink.timestamp)
            let lockDuration: CFTimeInterval
            switch target {
            case .essence:
                lockDuration = essenceContainmentDuration
            case .lostSoul:
                lockDuration = lostSoulLockDuration
            }
            let progress = elapsed / lockDuration
            viewModel.updateLockOn(targetID: target.id, progress: progress)
            viewModel.updateSpectralSignal(
                strength: max(signalSample.strength, 0.62 + min(progress, 1) * 0.38),
                anomalyDetected: true,
                lockProgress: progress
            )

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

        #if DEBUG
        private func updatePlaneDebug(
            with planeAnchors: [ARPlaneAnchor],
            at time: CFTimeInterval,
            in arView: ARView
        ) {
            planeDebugRenderer.update(
                with: planeAnchors,
                isVisible: viewModel.debugShowPlanes,
                in: arView
            )
            let classifiedCounts = planeAnchors.reduce(
                into: (floor: 0, wall: 0, table: 0, other: 0)
            ) { counts, anchor in
                switch anchor.classification {
                case .floor:
                    counts.floor += 1
                case .wall:
                    counts.wall += 1
                case .table:
                    counts.table += 1
                case .ceiling, .seat, .window, .door:
                    counts.other += 1
                case .none:
                    break
                @unknown default:
                    break
                }
            }
            viewModel.updateDebugPlaneClassifications(
                isSupported: ARPlaneAnchor.isClassificationSupported,
                floor: classifiedCounts.floor,
                wall: classifiedCounts.wall,
                table: classifiedCounts.table,
                other: classifiedCounts.other
            )

            if viewModel.debugTraversalEventCounter > handledDebugTraversalEventCount {
                handledDebugTraversalEventCount = viewModel.debugTraversalEventCounter
                let cameraTransform = arView.cameraTransform
                let forward = -SIMD3<Float>(
                    cameraTransform.matrix.columns.2.x,
                    cameraTransform.matrix.columns.2.y,
                    cameraTransform.matrix.columns.2.z
                )
                let targetPosition = cameraTransform.translation + forward * 1.2

                if let route = surfacePhaseRouteFactory.makeRoute(
                    from: planeAnchors,
                    targetPosition: targetPosition,
                    cameraPosition: cameraTransform.translation,
                    selection: .classifiedWalls
                ) {
                    traversalDebugRenderer.begin(
                        route: route,
                        cameraPosition: cameraTransform.translation,
                        at: time,
                        in: arView
                    )
                    viewModel.setDebugTraversalStatus("RUNNING")
                } else {
                    viewModel.setDebugTraversalStatus("NEED 2 PLANES")
                }
            }

            if traversalDebugRenderer.update(at: time, in: arView) {
                viewModel.setDebugTraversalStatus("COMPLETE")
            }
        }
        #endif

        private func bestScannerTarget(in arView: ARView) -> ScannerTarget? {
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let cameraPosition = arView.cameraTransform.translation

            #if DEBUG
            if viewModel.debugAutoLockEnabled, let debugForcedTargetID {
                if
                    viewModel.visibleEssences.contains(where: { $0.id == debugForcedTargetID }),
                    essenceRenderer.isCapturable(id: debugForcedTargetID),
                    let worldPosition = essenceRenderer.worldPosition(for: debugForcedTargetID)
                {
                    return .essence(id: debugForcedTargetID, worldPosition: worldPosition)
                }

                self.debugForcedTargetID = nil
            }
            #endif

            if viewModel.canContainEssence && !viewModel.visibleEssences.isEmpty {
                return viewModel.visibleEssences
                    .compactMap { essence -> (target: ScannerTarget, screenDistance: CGFloat)? in
                        guard
                            essenceRenderer.isCapturable(id: essence.id),
                            let worldPosition = essenceRenderer.worldPosition(for: essence.id)
                        else {
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

        private func scannerSignalSample(in arView: ARView) -> ScannerSignalSample {
            let cameraPosition = arView.cameraTransform.translation
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            var strongestSignal = viewModel.gameplayPhase == .awakenedHunt ? 0.18 : 0.08
            var anomalyDetected = false

            for essence in viewModel.visibleEssences {
                let manifestation = Double(essenceRenderer.manifestationLevel(for: essence.id))
                guard
                    manifestation > 0.04,
                    let worldPosition = essenceRenderer.worldPosition(for: essence.id)
                else {
                    continue
                }

                let distance = Double(simd_distance(cameraPosition, worldPosition))
                let proximity = 1 - min(max((distance - 0.55) / 3.45, 0), 1)
                var signal = (0.08 + proximity * 0.62) * manifestation
                if viewModel.gameplayPhase == .awakenedHunt {
                    signal *= 1.18
                }

                if
                    let screenPosition = arView.project(worldPosition),
                    arView.bounds.insetBy(dx: -80, dy: -80).contains(screenPosition)
                {
                    let screenDistance = hypot(
                        screenPosition.x - center.x,
                        screenPosition.y - center.y
                    )
                    let aimInfluence = 1 - min(Double(screenDistance / 260), 1)
                    signal += aimInfluence * 0.26 * manifestation

                    if manifestation > 0.28 && distance <= 2.5 && screenDistance <= 180 {
                        anomalyDetected = true
                    }
                }

                strongestSignal = max(strongestSignal, signal)
            }

            return ScannerSignalSample(
                strength: min(strongestSignal, 1),
                anomalyDetected: anomalyDetected
            )
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
                    essenceRenderer.manifestationLevel(for: essence.id) > 0,
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
                let effectRadius = min(max(0.09 / distance, 0.035), 0.13)
                let manifestationLevel = essenceRenderer.manifestationLevel(for: essence.id)
                let intensity = min(max(1.14 - distance * 0.11, 0.65), 1)
                    * manifestationLevel

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
                cameraPosition: arView.cameraTransform.translation,
                selection: .classifiedWalls
            ) else {
                clearVacuumLock()
                return
            }

            clearVacuumLock()
            lostSoulRenderer.noticeAndEscape(
                along: route,
                cameraPosition: arView.cameraTransform.translation,
                at: CACurrentMediaTime()
            )
        }

        private func collectEssence(id: AmbientEssence.ID, in arView: ARView) {
            guard
                essenceRenderer.isCapturable(id: id),
                viewModel.collectEssence(id: id)
            else {
                return
            }

            haptic.impactOccurred()
            haptic.prepare()
            lockedTargetID = nil
            lockStartedAt = nil
            #if DEBUG
            debugForcedTargetID = nil
            #endif

            if viewModel.gameplayPhase == .manifestation {
                lostSoulManifestationReadyAt = CACurrentMediaTime() + 4.8
            }

            essenceRenderer.collectEssence(id: id, from: arView)
        }

        private func clearVacuumLock() {
            #if DEBUG
            let hadDebugTarget = debugForcedTargetID != nil
            debugForcedTargetID = nil
            #else
            let hadDebugTarget = false
            #endif

            guard lockedTargetID != nil || lockStartedAt != nil || hadDebugTarget else {
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

private struct ScannerSignalSample {
    let strength: Double
    let anomalyDetected: Bool
}
