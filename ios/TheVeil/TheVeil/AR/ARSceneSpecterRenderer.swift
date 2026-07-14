import Foundation
import QuartzCore
import RealityKit
import UIKit

@MainActor
final class ARSceneSpecterRenderer {
    private var renderedSpecter: RenderedSpecter?
    private let vfxFactory = SpecterVFXFactory()
    private let telegraphDuration: CFTimeInterval = 1.1
    private let initialAttackDelay: CFTimeInterval = 4.8
    private let attackCooldownRange: ClosedRange<CFTimeInterval> = 6.4...9.6
    private let boltSpeed: Float = 1.35
    private let boltHitRadius: Float = 0.22

    func render(_ specter: Specter, in arView: ARView) {
        guard renderedSpecter?.id != specter.id else {
            return
        }

        remove(from: arView)

        guard let visual = vfxFactory.make(id: specter.id.uuidString, phase: specter.phase) else {
            assertionFailure("Minor Specter VFX could not be created")
            return
        }

        let cameraPosition = arView.cameraTransform.translation
        let spawnPosition = cameraPosition
            + arView.cameraTransform.forwardVector * 2
            + SIMD3<Float>(0, 0.04, 0)
        let anchor = AnchorEntity(world: spawnPosition)

        visual.root.orientation = orientationFacing(
            cameraPosition: cameraPosition,
            worldPosition: spawnPosition
        )
        anchor.addChild(visual.root)
        anchor.scale = SIMD3<Float>(repeating: 0.01)
        arView.scene.addAnchor(anchor)
        startEmission(for: visual.particleLayers)

        var manifestedTransform = anchor.transform
        manifestedTransform.scale = SIMD3<Float>(repeating: 1)
        anchor.move(
            to: manifestedTransform,
            relativeTo: nil,
            duration: 0.85,
            timingFunction: .easeOut
        )

        let now = CACurrentMediaTime()
        renderedSpecter = RenderedSpecter(
            id: specter.id,
            anchor: anchor,
            root: visual.root,
            bodyLayers: visual.bodyLayers,
            particleLayers: visual.particleLayers,
            motionPhase: specter.phase,
            nextAttackAt: now + initialAttackDelay,
            nextRepositionAt: now + 1.4
        )
    }

    func update(
        at time: CFTimeInterval,
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) -> [SpecterCombatEvent] {
        guard let specter = renderedSpecter else {
            return []
        }

        let deltaTime = min(max(time - specter.lastUpdateAt, 0), 0.1)
        specter.lastUpdateAt = time
        var events = updateBolts(
            for: specter,
            deltaTime: Float(deltaTime),
            cameraPosition: cameraPosition,
            at: time,
            in: arView
        )

        let clock = Float(time) + specter.motionPhase * 4.1
        switch specter.combatState {
        case .roaming:
            updateRoamingMotion(specter, at: time, clock: clock)
            setAttackCharge(0, for: specter.bodyLayers)

            if time >= specter.nextAttackAt {
                specter.combatState = .telegraphing(startedAt: time)
                events.append(.attackTelegraph)
            }

        case .telegraphing(let startedAt):
            let progress = min(max(Float((time - startedAt) / telegraphDuration), 0), 1)
            let pulse = sin(progress * .pi)
            specter.root.position = specter.roamingPosition
                + SIMD3<Float>(0, pulse * 0.045, -pulse * 0.04)
            specter.root.scale = SIMD3<Float>(repeating: 1 + pulse * 0.13)
            setAttackCharge(progress, for: specter.bodyLayers)

            if progress >= 1 {
                fireBolt(from: specter, toward: cameraPosition, at: time, in: arView)
                specter.combatState = .roaming
                specter.root.scale = SIMD3<Float>(repeating: 1)
                specter.nextAttackAt = time + .random(in: attackCooldownRange)
                specter.nextRepositionAt = time
                setAttackCharge(0, for: specter.bodyLayers)
                events.append(.boltFired)
            }
        }

        let worldPosition = specter.root.position(relativeTo: nil)
        let facing = orientationFacing(
            cameraPosition: cameraPosition,
            worldPosition: worldPosition
        )
        let restlessTurn = simd_quatf(
            angle: sin(clock * 0.39) * 0.16,
            axis: SIMD3<Float>(0, 1, 0)
        )
        specter.root.orientation = simd_slerp(
            specter.root.orientation,
            facing * restlessTurn,
            0.055
        )

        updateIndependentPlasmaMotion(specter, clock: clock, at: time)
        return events
    }

    func worldPosition(for id: Specter.ID) -> SIMD3<Float>? {
        guard let renderedSpecter, renderedSpecter.id == id else {
            return nil
        }
        return renderedSpecter.root.position(relativeTo: nil)
    }

    func remove(from arView: ARView) {
        if let renderedSpecter {
            for bolt in renderedSpecter.bolts {
                arView.scene.removeAnchor(bolt.anchor)
            }
            arView.scene.removeAnchor(renderedSpecter.anchor)
        }
        renderedSpecter = nil
    }

    private func updateRoamingMotion(
        _ specter: RenderedSpecter,
        at time: CFTimeInterval,
        clock: Float
    ) {
        if time >= specter.nextRepositionAt {
            specter.roamingDestination = SIMD3<Float>(
                .random(in: -0.48...0.48),
                .random(in: -0.2...0.28),
                .random(in: -0.28...0.22)
            )
            specter.nextRepositionAt = time + .random(in: 1.5...2.8)
        }

        specter.roamingPosition = simd_mix(
            specter.roamingPosition,
            specter.roamingDestination,
            SIMD3<Float>(repeating: 0.035)
        )
        specter.root.position = specter.roamingPosition + SIMD3<Float>(
            sin(clock * 0.31) * 0.05,
            sin(clock * 0.47) * 0.065,
            cos(clock * 0.27) * 0.04
        )
        specter.root.scale = SIMD3<Float>(repeating: 1)
    }

    private func updateIndependentPlasmaMotion(
        _ specter: RenderedSpecter,
        clock: Float,
        at time: CFTimeInterval
    ) {
        for (index, layer) in specter.bodyLayers.enumerated() {
            let seed = Float(index) * 1.7 + specter.motionPhase
            let pulse = 1 + sin(clock * (0.73 + Float(index) * 0.11) + seed) * 0.035
            layer.scale = SIMD3<Float>(repeating: pulse * (index == 0 ? 1 : 0.95))
        }

        for (index, layer) in specter.particleLayers.enumerated() {
            let seed = Float(index) * 2.3 + specter.motionPhase
            layer.orientation = simd_quatf(
                angle: clock * (index == 0 ? 0.08 : -0.06) + seed,
                axis: SIMD3<Float>(0, 1, 0)
            )
        }

        for bolt in specter.bolts {
            let pulse = 1 + sin(Float(time) * 18 + bolt.phase) * 0.16
            bolt.visual.scale = SIMD3<Float>(repeating: pulse)
        }
    }

    private func fireBolt(
        from specter: RenderedSpecter,
        toward cameraPosition: SIMD3<Float>,
        at time: CFTimeInterval,
        in arView: ARView
    ) {
        let specterPosition = specter.root.position(relativeTo: nil)
        let toCamera = cameraPosition - specterPosition
        guard simd_length_squared(toCamera) > 0.000_001 else {
            return
        }

        let direction = simd_normalize(toCamera)
        let startPosition = specterPosition + direction * 0.34
        let anchor = AnchorEntity(world: startPosition)
        let visual = makeBoltVisual()
        anchor.addChild(visual)
        arView.scene.addAnchor(anchor)

        specter.bolts.append(
            SpecterBolt(
                anchor: anchor,
                visual: visual,
                direction: direction,
                maximumTravel: simd_distance(startPosition, cameraPosition) + 0.7,
                phase: Float(time.truncatingRemainder(dividingBy: 10))
            )
        )
    }

    private func updateBolts(
        for specter: RenderedSpecter,
        deltaTime: Float,
        cameraPosition: SIMD3<Float>,
        at _: CFTimeInterval,
        in arView: ARView
    ) -> [SpecterCombatEvent] {
        var events: [SpecterCombatEvent] = []
        var survivors: [SpecterBolt] = []

        for bolt in specter.bolts {
            let previousPosition = bolt.anchor.position
            let travel = boltSpeed * deltaTime
            let nextPosition = previousPosition + bolt.direction * travel
            bolt.anchor.position = nextPosition
            bolt.distanceTravelled += travel

            if distance(
                from: cameraPosition,
                toSegmentFrom: previousPosition,
                to: nextPosition
            ) <= boltHitRadius {
                arView.scene.removeAnchor(bolt.anchor)
                events.append(.boltHit)
            } else if bolt.distanceTravelled >= bolt.maximumTravel {
                arView.scene.removeAnchor(bolt.anchor)
                events.append(.boltDodged)
            } else {
                survivors.append(bolt)
            }
        }

        specter.bolts = survivors
        return events
    }

    private func makeBoltVisual() -> Entity {
        let root = Entity()
        let halo = ModelEntity(
            mesh: .generateSphere(radius: 0.09),
            materials: [UnlitMaterial(color: UIColor(red: 0.68, green: 0.12, blue: 1, alpha: 0.18))]
        )
        let core = ModelEntity(
            mesh: .generateSphere(radius: 0.042),
            materials: [UnlitMaterial(color: UIColor(red: 0.92, green: 0.56, blue: 1, alpha: 1))]
        )
        root.addChild(halo)
        root.addChild(core)
        return root
    }

    private func setAttackCharge(_ charge: Float, for layers: [ModelEntity]) {
        for layer in layers {
            guard
                var model = layer.model,
                var material = model.materials.first as? CustomMaterial
            else {
                continue
            }

            var controls = material.custom.value
            controls.y = min(max(charge, 0), 1)
            material.custom.value = controls
            var materials = model.materials
            materials[0] = material
            model.materials = materials
            layer.model = model
        }
    }

    private func orientationFacing(
        cameraPosition: SIMD3<Float>,
        worldPosition: SIMD3<Float>
    ) -> simd_quatf {
        let direction = cameraPosition - worldPosition
        guard simd_length_squared(direction) > 0.000_001 else {
            return simd_quatf()
        }
        return simd_quatf(
            from: SIMD3<Float>(0, 0, -1),
            to: simd_normalize(direction)
        )
    }

    private func distance(
        from point: SIMD3<Float>,
        toSegmentFrom start: SIMD3<Float>,
        to end: SIMD3<Float>
    ) -> Float {
        let segment = end - start
        let lengthSquared = simd_length_squared(segment)
        guard lengthSquared > 0.000_001 else {
            return simd_distance(point, start)
        }
        let progress = min(max(simd_dot(point - start, segment) / lengthSquared, 0), 1)
        return simd_distance(point, start + segment * progress)
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
}

private enum SpecterCombatState {
    case roaming
    case telegraphing(startedAt: CFTimeInterval)
}

private final class SpecterBolt {
    let anchor: AnchorEntity
    let visual: Entity
    let direction: SIMD3<Float>
    let maximumTravel: Float
    let phase: Float
    var distanceTravelled: Float = 0

    init(
        anchor: AnchorEntity,
        visual: Entity,
        direction: SIMD3<Float>,
        maximumTravel: Float,
        phase: Float
    ) {
        self.anchor = anchor
        self.visual = visual
        self.direction = direction
        self.maximumTravel = maximumTravel
        self.phase = phase
    }
}

private final class RenderedSpecter {
    let id: Specter.ID
    let anchor: AnchorEntity
    let root: Entity
    let bodyLayers: [ModelEntity]
    let particleLayers: [Entity]
    let motionPhase: Float
    var combatState: SpecterCombatState = .roaming
    var roamingPosition = SIMD3<Float>.zero
    var roamingDestination = SIMD3<Float>.zero
    var nextAttackAt: CFTimeInterval
    var nextRepositionAt: CFTimeInterval
    var lastUpdateAt: CFTimeInterval
    var bolts: [SpecterBolt] = []

    init(
        id: Specter.ID,
        anchor: AnchorEntity,
        root: Entity,
        bodyLayers: [ModelEntity],
        particleLayers: [Entity],
        motionPhase: Float,
        nextAttackAt: CFTimeInterval,
        nextRepositionAt: CFTimeInterval
    ) {
        self.id = id
        self.anchor = anchor
        self.root = root
        self.bodyLayers = bodyLayers
        self.particleLayers = particleLayers
        self.motionPhase = motionPhase
        self.nextAttackAt = nextAttackAt
        self.nextRepositionAt = nextRepositionAt
        self.lastUpdateAt = CACurrentMediaTime()
    }
}
