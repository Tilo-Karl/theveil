import RealityKit
import UIKit

@MainActor
final class ARSceneLostSoulRenderer {
    private var renderedLostSoul: RenderedLostSoul?

    func render(_ lostSoul: LostSoul, in arView: ARView) {
        guard renderedLostSoul?.id != lostSoul.id else {
            return
        }

        removeRenderedLostSoul(from: arView)

        let spawnPosition = arView.cameraTransform.translation
            + arView.cameraTransform.forwardVector * 1.65
        let anchor = AnchorEntity(world: spawnPosition)
        let visual = makeLostSoulEntity(id: lostSoul.id)
        anchor.addChild(visual.root)
        anchor.scale = SIMD3<Float>(repeating: 0.01)
        arView.scene.addAnchor(anchor)

        var manifestedTransform = anchor.transform
        manifestedTransform.scale = SIMD3<Float>(repeating: 1)
        anchor.move(to: manifestedTransform, relativeTo: nil, duration: 0.9, timingFunction: .easeOut)

        renderedLostSoul = RenderedLostSoul(
            id: lostSoul.id,
            anchor: anchor,
            root: visual.root,
            headPivot: visual.headPivot,
            motes: visual.motes,
            motionPhase: Float.random(in: 0...(2 * .pi))
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
            lostSoul.headPivot.orientation = simd_quatf()
            lostSoul.root.components.set(OpacityComponent(opacity: 1))
            updateMotes(lostSoul, at: Float(time), spread: 0.1)

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
        lostSoul.root.orientation = simd_quatf(
            angle: sin(motionTime * 0.19 + phase) * 0.28,
            axis: SIMD3<Float>(0, 1, 0)
        )
        lostSoul.headPivot.orientation = simd_quatf(
            angle: sin(time * 0.31 + phase * 1.8) * 0.36,
            axis: SIMD3<Float>(0, 1, 0)
        ) * simd_quatf(
            angle: sin(time * 0.23 + phase) * 0.12,
            axis: SIMD3<Float>(1, 0, 0)
        )

        let shimmer = 0.8 + sin(time * 1.7 + phase) * 0.12
        let disappearanceSignal = max(0, sin(time * 0.29 + phase * 2.1) - 0.82) / 0.18
        let disappearance = disappearanceSignal * disappearanceSignal * 0.88
        lostSoul.root.components.set(
            OpacityComponent(opacity: max(0.08, shimmer * (1 - disappearance)))
        )
        updateMotes(lostSoul, at: time, spread: disappearance * 0.2)
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
            updateMotes(lostSoul, at: Float(time), spread: progress * 0.5)

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
            updateMotes(lostSoul, at: Float(time), spread: (1 - progress) * 0.45)

        default:
            lostSoul.anchor.isEnabled = true
            lostSoul.anchor.position = route.emergedExitPosition
            lostSoul.root.position = .zero
            lostSoul.root.scale = SIMD3<Float>(repeating: 1)
            lostSoul.root.orientation = startOrientation
            lostSoul.root.components.set(OpacityComponent(opacity: 0.86))
            lostSoul.state = .idle
        }
    }

    private func updateMotes(_ lostSoul: RenderedLostSoul, at time: Float, spread: Float) {
        for (index, mote) in lostSoul.motes.enumerated() {
            let seed = Float(index) * 1.37 + lostSoul.motionPhase
            let radius = 0.13 + Float(index % 3) * 0.028 + spread
            mote.position = SIMD3<Float>(
                sin(time * (0.24 + Float(index) * 0.011) + seed) * radius,
                -0.05 + cos(time * 0.2 + seed) * (0.22 + spread * 0.35),
                cos(time * (0.19 + Float(index) * 0.009) + seed) * radius * 0.55
            )
        }
    }

    private func removeRenderedLostSoul(from arView: ARView) {
        if let renderedLostSoul {
            arView.scene.removeAnchor(renderedLostSoul.anchor)
        }
        renderedLostSoul = nil
    }

    private func makeLostSoulEntity(id: LostSoul.ID) -> LostSoulVisual {
        let root = Entity()
        root.name = id.uuidString

        let headPivot = Entity()
        headPivot.position.y = 0.31
        root.addChild(headPivot)

        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.075),
            materials: [lostSoulMaterial(alpha: 0.76)]
        )
        head.scale = SIMD3<Float>(0.86, 1.08, 0.78)
        headPivot.addChild(head)

        let eyeMaterial = UnlitMaterial(color: UIColor(red: 0.03, green: 0.09, blue: 0.15, alpha: 0.75))
        for x: Float in [-0.025, 0.025] {
            let eye = ModelEntity(mesh: .generateSphere(radius: 0.011), materials: [eyeMaterial])
            eye.position = SIMD3<Float>(x, 0.008, -0.061)
            eye.scale.z = 0.45
            headPivot.addChild(eye)
        }

        let torso = ModelEntity(
            mesh: .generateCylinder(height: 0.27, radius: 0.088),
            materials: [lostSoulMaterial(alpha: 0.5)]
        )
        torso.scale = SIMD3<Float>(0.92, 1, 0.56)
        torso.position.y = 0.11
        root.addChild(torso)

        let lowerBody = ModelEntity(
            mesh: .generateCone(height: 0.34, radius: 0.09),
            materials: [lostSoulMaterial(alpha: 0.34)]
        )
        lowerBody.scale = SIMD3<Float>(0.9, 1, 0.52)
        lowerBody.position.y = -0.19
        lowerBody.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        root.addChild(lowerBody)

        for side: Float in [-1, 1] {
            let arm = ModelEntity(
                mesh: .generateCylinder(height: 0.28, radius: 0.021),
                materials: [lostSoulMaterial(alpha: 0.36)]
            )
            arm.position = SIMD3<Float>(side * 0.105, 0.05, 0)
            arm.orientation = simd_quatf(angle: side * 0.12, axis: SIMD3<Float>(0, 0, 1))
            arm.scale.z = 0.7
            root.addChild(arm)
        }

        var motes: [ModelEntity] = []
        let moteMaterial = UnlitMaterial(color: UIColor(red: 0.44, green: 0.86, blue: 1, alpha: 0.72))
        for index in 0..<10 {
            let mote = ModelEntity(
                mesh: .generateSphere(radius: index.isMultiple(of: 3) ? 0.009 : 0.005),
                materials: [moteMaterial]
            )
            root.addChild(mote)
            motes.append(mote)
        }

        root.components.set(OpacityComponent(opacity: 0.86))
        return LostSoulVisual(root: root, headPivot: headPivot, motes: motes)
    }

    private func lostSoulMaterial(alpha: CGFloat) -> UnlitMaterial {
        UnlitMaterial(color: UIColor(red: 0.42, green: 0.82, blue: 1, alpha: alpha))
    }

    private func smoothStep(_ value: Float) -> Float {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

private struct LostSoulVisual {
    let root: Entity
    let headPivot: Entity
    let motes: [ModelEntity]
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
    let headPivot: Entity
    let motes: [ModelEntity]
    let motionPhase: Float
    var state: LostSoulMotionState = .idle

    init(
        id: LostSoul.ID,
        anchor: AnchorEntity,
        root: Entity,
        headPivot: Entity,
        motes: [ModelEntity],
        motionPhase: Float
    ) {
        self.id = id
        self.anchor = anchor
        self.root = root
        self.headPivot = headPivot
        self.motes = motes
        self.motionPhase = motionPhase
    }
}

private extension Transform {
    var forwardVector: SIMD3<Float> {
        -SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
    }
}
