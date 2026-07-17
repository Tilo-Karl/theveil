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
        private let specterRenderer = ARSceneSpecterRenderer()
        private let ectoRenderer = ARSceneEctoRenderer()
        private let cameraPostProcessor = VeilCameraPostProcessor()
        private let planeCache = PlaneDetectionCache()
        private weak var arView: ARView?
        private var displayLink: CADisplayLink?
        private var resonanceLockTracker = ResonanceLockTracker()
        private var lastResonanceUpdateAt: CFTimeInterval?
        private let haptic = UIImpactFeedbackGenerator(style: .light)
        private let overloadHaptic = UIImpactFeedbackGenerator(style: .heavy)
        private let combatHaptic = UINotificationFeedbackGenerator()
        private var hasRenderedEssenceField = false
        private var renderedEssenceFieldRevision = -1
        private var handledManifestationPulseEventCount = 0
        #if DEBUG
        private var debugForcedTargetID: AmbientEssence.ID?
        private var debugForcedEctoTargetID: Ecto.ID?
        private var handledDebugEctoSpawnEventCount = 0
        private let traversalDebugRenderer = ARSurfaceTraversalDebugRenderer()
        #endif

        private let essenceCollectionDistance: Float = 1
        private let manifestationTrackingDistance: Float = 3
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
            combatHaptic.prepare()
            startVacuumLoop()
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            resonanceLockTracker.reset()
            lastResonanceUpdateAt = nil
            if let arView {
                #if DEBUG
                traversalDebugRenderer.remove(from: arView)
                #endif
                ectoRenderer.remove(from: arView)
                specterRenderer.remove(from: arView)
            }
            viewModel.clearLockOn()
        }

        #if DEBUG
        @objc
        private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else {
                return
            }

            let location = gesture.location(in: arView)
            let tappedEntity = arView.entity(at: location)

            if
                let ectoID = ectoRenderer.ectoID(for: tappedEntity),
                ectoRenderer.isCapturable(id: ectoID)
            {
                if viewModel.debugAutoLockEnabled {
                    debugForcedEctoTargetID = ectoID
                    let update = resonanceLockTracker.forceLock(targetID: ectoID)
                    viewModel.updateResonanceLock(update.state)
                }
                return
            }

            guard
                let essenceID = essenceRenderer.essenceID(for: tappedEntity),
                viewModel.canExtractEssence,
                essenceRenderer.isCapturable(id: essenceID)
            else {
                return
            }

            if viewModel.debugAutoLockEnabled {
                debugForcedTargetID = essenceID
                let update = resonanceLockTracker.forceLock(targetID: essenceID)
                viewModel.updateResonanceLock(update.state)
                return
            }

            guard
                let essencePosition = essenceRenderer.worldPosition(for: essenceID),
                simd_distance(arView.cameraTransform.translation, essencePosition) <= essenceCollectionDistance
            else {
                return
            }

            let update = resonanceLockTracker.forceLock(targetID: essenceID)
            viewModel.updateResonanceLock(update.state)
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
            viewModel.updateScannerPose(
                position: arView.cameraTransform.translation,
                forward: arView.cameraTransform.forwardVector
            )

            let rawPlaneAnchors = arView.session.currentFrame?.anchors.compactMap { anchor in
                anchor as? ARPlaneAnchor
            } ?? []

            planeCache.update(with: rawPlaneAnchors, at: displayLink.timestamp)
            let stablePlanes = planeCache.stablePlanes(at: displayLink.timestamp)

            if
                viewModel.isScannerActive,
                (!hasRenderedEssenceField || renderedEssenceFieldRevision != viewModel.essenceFieldRevision)
            {
                essenceRenderer.render(viewModel.visibleEssences, in: arView)
                hasRenderedEssenceField = true
                renderedEssenceFieldRevision = viewModel.essenceFieldRevision
            }

            #if DEBUG
            updateSurfacePhaseDebug(
                with: stablePlanes,
                at: displayLink.timestamp,
                in: arView
            )
            updateDebugEcto(
                spawnPlaneAnchors: rawPlaneAnchors,
                movementPlaneAnchors: stablePlanes,
                at: displayLink.timestamp,
                in: arView
            )
            #endif

            if hasRenderedEssenceField {
                if viewModel.manifestationPulseEventCounter > handledManifestationPulseEventCount {
                    handledManifestationPulseEventCount = viewModel.manifestationPulseEventCounter
                    clearVacuumLock()
                    essenceRenderer.beginAwakening(at: displayLink.timestamp)
                    overloadHaptic.impactOccurred(intensity: 1)
                    overloadHaptic.prepare()
                }

                essenceRenderer.updateFloatingMotion(
                    at: displayLink.timestamp,
                    planeAnchors: stablePlanes,
                    cameraPosition: arView.cameraTransform.translation
                )
            }

            lostSoulRenderer.update(
                at: displayLink.timestamp,
                cameraPosition: arView.cameraTransform.translation
            )
            synchronizeManifestationRenderers(in: arView)
            let combatEvents = specterRenderer.update(
                at: displayLink.timestamp,
                cameraPosition: arView.cameraTransform.translation,
                in: arView
            )
            handleSpecterCombatEvents(combatEvents)
            updatePostProcessEffects(in: arView)

            let previousResonanceUpdateAt = lastResonanceUpdateAt ?? displayLink.timestamp
            let resonanceDelta = min(
                max(displayLink.timestamp - previousResonanceUpdateAt, 0),
                0.1
            )
            lastResonanceUpdateAt = displayLink.timestamp

            guard viewModel.isScannerOperational else {
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
                let update = resonanceLockTracker.update(
                    contactTargetID: nil,
                    deltaTime: resonanceDelta,
                    lockDuration: ResonanceTiming.lockDuration
                )
                viewModel.updateResonanceLock(update.state)
                viewModel.updateSpectralSignal(
                    strength: signalSample.strength,
                    anomalyDetected: signalSample.anomalyDetected,
                    lockProgress: update.state.targetID == nil
                        ? nil
                        : update.state.lockProgress
                )
                return
            }

            let update = resonanceLockTracker.update(
                contactTargetID: target.id,
                deltaTime: resonanceDelta,
                lockDuration: ResonanceTiming.lockDuration
            )
            viewModel.updateResonanceLock(update.state)
            viewModel.updateSpectralSignal(
                strength: max(
                    signalSample.strength,
                    0.62 + update.state.lockProgress * 0.28
                        + update.state.beamProgress * 0.1
                ),
                anomalyDetected: true,
                lockProgress: update.state.lockProgress
            )

            if update.didAcquireLock {
                haptic.impactOccurred(intensity: 0.7)
                haptic.prepare()
            }

            if update.didCompleteBeam {
                switch target {
                case .essence(let id, _):
                    collectEssence(id: id, in: arView)
                case .ecto(let id, _):
                    collectEcto(id: id, in: arView)
                case .specter:
                    viewModel.applyWeakResonancePulse()
                case .lostSoul:
                    break
                }
            }
        }

        #if DEBUG
        private func updateDebugEcto(
            spawnPlaneAnchors: [ARPlaneAnchor],
            movementPlaneAnchors: [ARPlaneAnchor],
            at time: CFTimeInterval,
            in arView: ARView
        ) {
            let didHandleSpawnRequest = viewModel.debugEctoSpawnEventCounter > handledDebugEctoSpawnEventCount
            if didHandleSpawnRequest {
                handledDebugEctoSpawnEventCount = viewModel.debugEctoSpawnEventCounter
                debugForcedEctoTargetID = nil

                let variant = EctoVariant.lime
                if let ecto = ectoRenderer.spawn(
                    variant: variant,
                    planeAnchors: spawnPlaneAnchors,
                    cameraTransform: arView.cameraTransform,
                    at: time,
                    in: arView
                ) {
                    viewModel.spawnDebugEcto(ecto)
                    haptic.impactOccurred(intensity: 0.55)
                    haptic.prepare()
                } else {
                    viewModel.ectoStore.clear()
                    viewModel.setDebugEctoStatus("NO SURFACE")
                }
            }

            if viewModel.ectoStore.activeEcto != nil {
                let status = ectoRenderer.update(
                    at: time,
                    planeAnchors: movementPlaneAnchors,
                    cameraPosition: arView.cameraTransform.translation,
                    in: arView
                )
                viewModel.setDebugEctoStatus(status)
            } else if !didHandleSpawnRequest,
                      viewModel.debugEctoStatus != "ECTO READY",
                      viewModel.debugEctoStatus != "NO SURFACE" {
                viewModel.setDebugEctoStatus("ECTO READY")
            }
        }

        private func updateSurfacePhaseDebug(
            with planeAnchors: [ARPlaneAnchor],
            at time: CFTimeInterval,
            in arView: ARView
        ) {
            guard viewModel.debugPhaseCubeEnabled else {
                traversalDebugRenderer.remove(from: arView)
                viewModel.setDebugTraversalStatus("READY")
                return
            }

            traversalDebugRenderer.startIfNeeded(
                cameraTransform: arView.cameraTransform,
                at: time,
                in: arView
            )
            let status = traversalDebugRenderer.update(
                at: time,
                planeAnchors: planeAnchors,
                cameraPosition: arView.cameraTransform.translation,
                in: arView
            )
            viewModel.setDebugTraversalStatus(status)
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

            if viewModel.debugAutoLockEnabled, let debugForcedEctoTargetID {
                if
                    viewModel.ectoStore.activeEcto?.id == debugForcedEctoTargetID,
                    ectoRenderer.isCapturable(id: debugForcedEctoTargetID),
                    let worldPosition = ectoRenderer.worldPosition(for: debugForcedEctoTargetID)
                {
                    return .ecto(id: debugForcedEctoTargetID, worldPosition: worldPosition)
                }

                self.debugForcedEctoTargetID = nil
            }
            #endif

            if viewModel.canExtractEssence && !viewModel.visibleEssences.isEmpty {
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

            if
                let ecto = viewModel.ectoStore.activeEcto,
                ectoRenderer.isCapturable(id: ecto.id),
                let worldPosition = ectoRenderer.worldPosition(for: ecto.id),
                simd_distance(cameraPosition, worldPosition) <= manifestationTrackingDistance,
                aimedScreenDistance(to: worldPosition, center: center, in: arView) != nil
            {
                return .ecto(id: ecto.id, worldPosition: worldPosition)
            }

            if
                let specter = viewModel.specterStore.activeSpecter,
                let worldPosition = specterRenderer.worldPosition(for: specter.id),
                simd_distance(cameraPosition, worldPosition) <= manifestationTrackingDistance,
                aimedScreenDistance(to: worldPosition, center: center, in: arView) != nil
            {
                return .specter(id: specter.id, worldPosition: worldPosition)
            }

            guard
                let lostSoul = viewModel.lostSoulStore.lostSoul,
                let worldPosition = lostSoulRenderer.worldPosition(for: lostSoul.id),
                simd_distance(cameraPosition, worldPosition) <= manifestationTrackingDistance,
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

            if
                let ecto = viewModel.ectoStore.activeEcto,
                let worldPosition = ectoRenderer.worldPosition(for: ecto.id)
            {
                let distance = Double(simd_distance(cameraPosition, worldPosition))
                let proximity = 1 - min(max((distance - 0.45) / 2.8, 0), 1)
                var signal = 0.2 + proximity * 0.48

                if
                    let screenPosition = arView.project(worldPosition),
                    arView.bounds.insetBy(dx: -80, dy: -80).contains(screenPosition)
                {
                    let screenDistance = hypot(
                        screenPosition.x - center.x,
                        screenPosition.y - center.y
                    )
                    let aimInfluence = 1 - min(Double(screenDistance / 260), 1)
                    signal += aimInfluence * 0.24

                    if distance <= 2.8 && screenDistance <= 190 {
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

        private func updatePostProcessEffects(in _: ARView) {
            cameraPostProcessor.updateEssenceEffects([])
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

        private func synchronizeManifestationRenderers(in arView: ARView) {
            if
                viewModel.encounterStore.state.phase == .manifested,
                let specter = viewModel.specterStore.activeSpecter
            {
                specterRenderer.render(specter, in: arView)
            } else {
                specterRenderer.remove(from: arView)
            }

            if let lostSoul = viewModel.lostSoulStore.lostSoul {
                lostSoulRenderer.render(lostSoul, in: arView)
            }
        }

        private func handleSpecterCombatEvents(_ events: [SpecterCombatEvent]) {
            for event in events {
                viewModel.handleSpecterCombatEvent(event)
                switch event {
                case .attackTelegraph:
                    haptic.impactOccurred(intensity: 0.42)
                    haptic.prepare()
                case .boltFired:
                    break
                case .boltHit:
                    combatHaptic.notificationOccurred(.error)
                    combatHaptic.prepare()
                case .boltDodged:
                    combatHaptic.notificationOccurred(.success)
                    combatHaptic.prepare()
                }
            }
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
            resonanceLockTracker.reset()
            #if DEBUG
            debugForcedTargetID = nil
            #endif

            essenceRenderer.collectEssence(id: id, from: arView)
        }

        private func collectEcto(id: Ecto.ID, in arView: ARView) {
            guard
                ectoRenderer.isCapturable(id: id),
                viewModel.collectEcto(id: id)
            else {
                return
            }

            haptic.impactOccurred()
            haptic.prepare()
            resonanceLockTracker.reset()
            #if DEBUG
            debugForcedEctoTargetID = nil
            #endif

            ectoRenderer.collectEcto(id: id, from: arView)
        }

        private func clearVacuumLock() {
            #if DEBUG
            let hadDebugTarget = debugForcedTargetID != nil || debugForcedEctoTargetID != nil
            debugForcedTargetID = nil
            debugForcedEctoTargetID = nil
            #else
            let hadDebugTarget = false
            #endif

            guard resonanceLockTracker.state != .idle || hadDebugTarget else {
                return
            }

            resonanceLockTracker.reset()
            viewModel.clearLockOn()
        }
    }
}

private enum ScannerTarget {
    case essence(id: AmbientEssence.ID, worldPosition: SIMD3<Float>)
    case ecto(id: Ecto.ID, worldPosition: SIMD3<Float>)
    case lostSoul(id: LostSoul.ID, worldPosition: SIMD3<Float>)
    case specter(id: Specter.ID, worldPosition: SIMD3<Float>)

    var id: UUID {
        switch self {
        case .essence(let id, _), .ecto(let id, _), .lostSoul(let id, _), .specter(let id, _):
            return id
        }
    }
}

private struct ScannerSignalSample {
    let strength: Double
    let anomalyDetected: Bool
}
