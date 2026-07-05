import Foundation
import RealityKit

@MainActor
final class ARSceneLostSoulRenderer {
    private var renderedLostSoul: RenderedLostSoul?
    private let vfxFactory = LostSoulVFXFactory()

    func render(_ lostSoul: LostSoul, in arView: ARView) {
        guard renderedLostSoul?.id != lostSoul.id else {
            return
        }

        removeRenderedLostSoul(from: arView)

        let phase = Float.random(in: 0...(2 * .pi))
        guard let visual = vfxFactory.make(id: lostSoul.id, phase: phase) else {
            assertionFailure("Lost Soul VFX could not be created")
            return
        }

        let cameraPosition = arView.cameraTransform.translation
        let spawnPosition = cameraPosition
            + arView.cameraTransform.forwardVector * 2.25
            + SIMD3<Float>(0, -0.12, 0)
        let anchor = AnchorEntity(world: spawnPosition)
        let facingDirection = cameraPosition - spawnPosition
        let restOrientation = simd_length_squared(facingDirection) > 0.000_001
            ? simd_quatf(
                from: SIMD3<Float>(0, 0, -1),
                to: simd_normalize(facingDirection)
            )
            : simd_quatf()
        let avertedOrientation = restOrientation * simd_quatf(
            angle: 0.28,
            axis: SIMD3<Float>(0, 1, 0)
        )
        visual.root.orientation = avertedOrientation
        anchor.addChild(visual.root)
        anchor.scale = SIMD3<Float>(repeating: 0.01)
        arView.scene.addAnchor(anchor)
        startEmission(for: visual.particleLayers)

        var manifestedTransform = anchor.transform
        manifestedTransform.scale = SIMD3<Float>(repeating: 1)
        anchor.move(to: manifestedTransform, relativeTo: nil, duration: 0.9, timingFunction: .easeOut)

        renderedLostSoul = RenderedLostSoul(
            id: lostSoul.id,
            anchor: anchor,
            root: visual.root,
            particleLayers: visual.particleLayers,
            motionPhase: phase,
            restOrientation: avertedOrientation
        )
    }

    func update(at time: CFTimeInterval, cameraPosition: SIMD3<Float>) {
        guard let lostSoul = renderedLostSoul else {
            return
        }

        switch lostSoul.state {
        case .idle:
            updateIdle(lostSoul, at: Float(time))

        case .noticing(let startedAt, let startOrientation, let targetOrientation, let route):
            let elapsed = time - startedAt
            let turnProgress = smoothStep(Float(elapsed / 0.85))
            lostSoul.root.orientation = simd_slerp(startOrientation, targetOrientation, turnProgress)
            lostSoul.root.components.set(OpacityComponent(opacity: 0.68))
            updateVeilMotion(lostSoul, at: Float(time), spread: 0.1)

            if elapsed >= 1.45 {
                lostSoul.state = .escaping(
                    startedAt: time,
                    startPosition: lostSoul.anchor.position,
                    startOrientation: targetOrientation,
                    route: route
                )
            }

        case .escaping(let startedAt, let startPosition, let startOrientation, let route):
            updateEscape(
                lostSoul,
                at: time,
                startedAt: startedAt,
                startPosition: startPosition,
                startOrientation: startOrientation,
                route: route
            )
        }
    }

    func worldPosition(for id: LostSoul.ID) -> SIMD3<Float>? {
        guard
            let renderedLostSoul,
            renderedLostSoul.id == id,
            case .idle = renderedLostSoul.state
        else {
            return nil
        }

        return renderedLostSoul.root.position(relativeTo: nil)
    }

    func noticeAndEscape(
        along route: SurfacePhaseRoute,
        cameraPosition: SIMD3<Float>,
        at time: CFTimeInterval
    ) {
        guard let lostSoul = renderedLostSoul, case .idle = lostSoul.state else {
            return
        }

        let worldPosition = lostSoul.root.position(relativeTo: nil)
        lostSoul.anchor.position = worldPosition
        lostSoul.root.position = .zero
        lostSoul.root.scale = SIMD3<Float>(repeating: 1)

        let lookDirection = cameraPosition - worldPosition
        let targetOrientation: simd_quatf
        if simd_length(lookDirection) > 0.001 {
            targetOrientation = simd_quatf(
                from: SIMD3<Float>(0, 0, -1),
                to: simd_normalize(lookDirection)
            )
        } else {
            targetOrientation = lostSoul.root.orientation
        }

        lostSoul.state = .noticing(
            startedAt: time,
            startOrientation: lostSoul.root.orientation,
            targetOrientation: targetOrientation,
            route: route
        )
    }

    private func updateIdle(_ lostSoul: RenderedLostSoul, at time: Float) {
        let clock = Double(time + lostSoul.motionPhase * 1.7)
        let cycleIndex = floor(clock / 11)
        let cycleTime = clock.truncatingRemainder(dividingBy: 11)
        let activeTime = cycleIndex * 8
            + min(cycleTime, 5.5)
            + max(cycleTime - 8.5, 0)
        let motionTime = Float(activeTime)
        let phase = lostSoul.motionPhase

        lostSoul.root.position = SIMD3<Float>(
            sin(motionTime * 0.27 + phase) * 0.08,
            sin(motionTime * 0.43 + phase * 1.3) * 0.07,
            cos(motionTime * 0.23 + phase) * 0.055
        )
        lostSoul.root.orientation = lostSoul.restOrientation * simd_quatf(
            angle: sin(motionTime * 0.19 + phase) * 0.28,
            axis: SIMD3<Float>(0, 1, 0)
        )

        let shimmer = 0.66 + sin(time * 1.7 + phase) * 0.08
        let disappearanceSignal = max(0, sin(time * 0.29 + phase * 2.1) - 0.82) / 0.18
        let disappearance = disappearanceSignal * disappearanceSignal * 0.88
        lostSoul.root.components.set(
            OpacityComponent(opacity: max(0.05, shimmer * (1 - disappearance)))
        )
        updateVeilMotion(lostSoul, at: time, spread: disappearance * 0.2)
    }

    private func updateEscape(
        _ lostSoul: RenderedLostSoul,
        at time: CFTimeInterval,
        startedAt: CFTimeInterval,
        startPosition: SIMD3<Float>,
        startOrientation: simd_quatf,
        route: SurfacePhaseRoute
    ) {
        let elapsed = time - startedAt

        switch elapsed {
        case ..<1.6:
            let progress = smoothStep(Float(elapsed / 1.6))
            lostSoul.anchor.isEnabled = true
            lostSoul.anchor.position = simd_mix(
                startPosition,
                route.entryPosition,
                SIMD3<Float>(repeating: progress)
            )
            lostSoul.root.orientation = startOrientation * simd_quatf(
                angle: -progress * 0.52,
                axis: SIMD3<Float>(1, 0, 0)
            )
            lostSoul.root.scale = SIMD3<Float>(
                1 - progress * 0.2,
                1 - progress * 0.42,
                1 - progress * 0.72
            )
            lostSoul.root.components.set(
                OpacityComponent(opacity: max(0.03, 1 - progress * 0.97))
            )
            updateVeilMotion(lostSoul, at: Float(time), spread: progress * 0.5)

        case ..<2.45:
            lostSoul.anchor.isEnabled = false
            lostSoul.anchor.position = route.concealedExitPosition

        case ..<3.85:
            let progress = smoothStep(Float((elapsed - 2.45) / 1.4))
            lostSoul.anchor.isEnabled = true
            lostSoul.anchor.position = simd_mix(
                route.concealedExitPosition,
                route.emergedExitPosition,
                SIMD3<Float>(repeating: progress)
            )
            lostSoul.root.scale = SIMD3<Float>(
                0.72 + progress * 0.28,
                0.58 + progress * 0.42,
                0.28 + progress * 0.72
            )
            lostSoul.root.orientation = startOrientation * simd_quatf(
                angle: -(1 - progress) * 0.52,
                axis: SIMD3<Float>(1, 0, 0)
            )
            lostSoul.root.components.set(OpacityComponent(opacity: max(0.04, progress * 0.86)))
            updateVeilMotion(lostSoul, at: Float(time), spread: (1 - progress) * 0.45)

        default:
            lostSoul.anchor.isEnabled = true
            lostSoul.anchor.position = route.emergedExitPosition
            lostSoul.root.position = .zero
            lostSoul.root.scale = SIMD3<Float>(repeating: 1)
            lostSoul.root.orientation = startOrientation
            lostSoul.root.components.set(OpacityComponent(opacity: 0.62))
            lostSoul.restOrientation = startOrientation
            lostSoul.state = .idle
        }
    }

    private func updateVeilMotion(_ lostSoul: RenderedLostSoul, at time: Float, spread: Float) {
        for (index, particleLayer) in lostSoul.particleLayers.enumerated() {
            let seed = lostSoul.motionPhase + Float(index) * 1.73
            let pulse = 1 + sin(time * 0.37 + seed) * 0.035 + spread * 0.28
            particleLayer.scale = SIMD3<Float>(
                pulse + spread * 0.22,
                pulse + spread * 0.48,
                pulse + spread * 0.18
            )
            particleLayer.orientation = simd_quatf(
                angle: sin(time * 0.16 + seed) * (0.08 + spread * 0.32),
                axis: SIMD3<Float>(0, 1, 0)
            )
        }
    }

    private func startEmission(for entities: [Entity]) {
        for entity in entities {
            guard var component = entity.components[ParticleEmitterComponent.self] else {
                continue
            }
            component.isEmitting = true
            component.restart()
            entity.components.set(component)
        }
    }

    private func removeRenderedLostSoul(from arView: ARView) {
        if let renderedLostSoul {
            arView.scene.removeAnchor(renderedLostSoul.anchor)
        }
        renderedLostSoul = nil
    }

    private func smoothStep(_ value: Float) -> Float {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

private enum LostSoulMotionState {
    case idle
    case noticing(
        startedAt: CFTimeInterval,
        startOrientation: simd_quatf,
        targetOrientation: simd_quatf,
        route: SurfacePhaseRoute
    )
    case escaping(
        startedAt: CFTimeInterval,
        startPosition: SIMD3<Float>,
        startOrientation: simd_quatf,
        route: SurfacePhaseRoute
    )
}

private final class RenderedLostSoul {
    let id: LostSoul.ID
    let anchor: AnchorEntity
    let root: Entity
    let particleLayers: [Entity]
    let motionPhase: Float
    var restOrientation: simd_quatf
    var state: LostSoulMotionState = .idle

    init(
        id: LostSoul.ID,
        anchor: AnchorEntity,
        root: Entity,
        particleLayers: [Entity],
        motionPhase: Float,
        restOrientation: simd_quatf
    ) {
        self.id = id
        self.anchor = anchor
        self.root = root
        self.particleLayers = particleLayers
        self.motionPhase = motionPhase
        self.restOrientation = restOrientation
    }
}
