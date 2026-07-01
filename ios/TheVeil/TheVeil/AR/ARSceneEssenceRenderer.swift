import ARKit
import CoreGraphics
import RealityKit
import UIKit

@MainActor
final class ARSceneEssenceRenderer {
    private let lockCompletionGrace: CFTimeInterval = 0.12
    private var renderedEssences: [AmbientEssence.ID: RenderedEssence] = [:]
    private var atmosphereAnchor: AnchorEntity?
    private let vfxFactory = EssenceVFXFactory()
    private let surfacePhaseRouteFactory = SurfacePhaseRouteFactory()
    private let cyanParticleTexture = ParticleGlowTextureFactory.makeTexture(
        color: UIColor(red: 0.3, green: 0.8, blue: 1, alpha: 1)
    )
    private let violetParticleTexture = ParticleGlowTextureFactory.makeTexture(
        color: UIColor(red: 0.3, green: 0.42, blue: 1, alpha: 1)
    )

    func render(_ essences: [AmbientEssence], in arView: ARView) {
        removeAllEssence(from: arView)

        for essence in essences {
            let anchor = AnchorEntity(world: .zero)
            guard let renderedEssence = makeRenderedEssence(for: essence, anchor: anchor) else {
                continue
            }
            anchor.addChild(renderedEssence.root)
            for layer in renderedEssence.visualLayers {
                anchor.addChild(layer)
            }
            arView.scene.addAnchor(anchor)
            startEmission(for: renderedEssence.particleLayers)
            renderedEssences[essence.id] = renderedEssence
        }

        renderAtmosphere(in: arView)
    }

    func updateFloatingMotion(
        at time: CFTimeInterval,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>
    ) {
        for renderedEssence in renderedEssences.values {
            if renderedEssence.overloadStartedAt == nil {
                updateManifestation(
                    for: renderedEssence,
                    at: time,
                    planeAnchors: planeAnchors,
                    cameraPosition: cameraPosition
                )
            }

            let shaderTime = Float(time)
            let phase = renderedEssence.motionPhase
            let position = motionPosition(for: renderedEssence, at: time)
            let motionSpeed: Float = renderedEssence.isAwakened ? 0.82 : 0.17
            let orientationAmount: Float = renderedEssence.isAwakened ? 0.58 : 0.35
            let orientation = simd_quatf(
                angle: sin(shaderTime * motionSpeed + phase) * orientationAmount,
                axis: simd_normalize(SIMD3<Float>(0.4, 1, 0.25))
            )

            renderedEssence.root.position = position
            renderedEssence.root.orientation = orientation

            for layer in renderedEssence.visualLayers {
                layer.position = position
                layer.orientation = orientation
            }

            renderedEssence.vfx.update(
                at: shaderTime,
                coreLevel: renderedEssence.presentation.core,
                plasmaLevel: renderedEssence.presentation.plasma,
                tendrilLevel: renderedEssence.presentation.tendrils,
                basePosition: position,
                baseOrientation: orientation,
                overloadFlash: renderedEssence.overloadFlash
            )
        }
    }

    func beginAwakening(at time: CFTimeInterval) {
        let essences = renderedEssences.values.sorted {
            $0.motionPhase < $1.motionPhase
        }

        for (index, essence) in essences.enumerated() {
            let origin = essence.root.position(relativeTo: nil)
            let angle = Float(index) / Float(max(essences.count, 1)) * 2 * .pi
                + essence.motionPhase * 0.18
            let scatter = SIMD3<Float>(
                cos(angle) * Float.random(in: 0.58...0.88),
                Float.random(in: -0.28...0.42),
                sin(angle) * Float.random(in: 0.42...0.72)
            )
            let target = boundedAwakenedPosition(origin + scatter)

            essence.isAwakened = true
            essence.overloadStartedAt = time
            essence.scatterOrigin = origin
            essence.scatterTarget = target
            essence.basePosition = origin
            essence.lastPosition = origin
            essence.phaseRoute = nil
            essence.manifestationPhase = .visible
            essence.manifestationStartedAt = time
            essence.visibleDuration = .greatestFiniteMagnitude
            applyManifestation(progress: 1, to: essence)
            startEmission(for: essence.particleLayers)
        }
    }

    func worldPosition(for id: AmbientEssence.ID) -> SIMD3<Float>? {
        renderedEssences[id]?.root.position(relativeTo: nil)
    }

    func isCapturable(id: AmbientEssence.ID) -> Bool {
        guard let essence = renderedEssences[id] else {
            return false
        }

        return essence.manifestationPhase == .visible
            && essence.overloadStartedAt == nil
    }

    func manifestationLevel(for id: AmbientEssence.ID) -> Float {
        renderedEssences[id]?.manifestationLevel ?? 0
    }

    func essenceID(for entity: Entity?) -> AmbientEssence.ID? {
        var currentEntity = entity

        while let current = currentEntity {
            if let id = UUID(uuidString: current.name) {
                return id
            }

            currentEntity = current.parent
        }

        return nil
    }

    func collectEssence(id: AmbientEssence.ID, from arView: ARView) {
        guard let renderedEssence = renderedEssences.removeValue(forKey: id) else {
            return
        }

        let cameraTransform = arView.cameraTransform
        let collectionPoint = cameraTransform.translation + cameraTransform.forwardVector * 0.2

        for (index, layer) in renderedEssence.visualLayers.enumerated() {
            var targetTransform = layer.transform
            let angle = Float(index) * 2.399
            targetTransform.translation = collectionPoint + SIMD3<Float>(
                cos(angle) * 0.008,
                sin(angle) * 0.008,
                0
            )
            targetTransform.scale = SIMD3<Float>(0.015, 0.015, 0.09)
            layer.move(
                to: targetTransform,
                relativeTo: nil,
                duration: 0.48 + Double(index) * 0.035,
                timingFunction: .easeIn
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            self.stopEmission(for: renderedEssence.particleLayers)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) { [weak arView] in
            arView?.scene.removeAnchor(renderedEssence.anchor)
        }
    }

    private func makeRenderedEssence(
        for essence: AmbientEssence,
        anchor: AnchorEntity
    ) -> RenderedEssence? {
        let root = Entity()
        root.name = essence.id.uuidString
        root.position = essence.position
        root.components.set(
            CollisionComponent(
                shapes: [.generateSphere(radius: essence.radius * 1.25)]
            )
        )

        let motes = makeMoteEmitter(radius: essence.radius)
        let wake = makeWakeEmitter(radius: essence.radius)
        let particleLayers = [motes, wake]
        guard let vfx = vfxFactory.make(
            radius: essence.radius,
            phase: Float.random(in: 0...(2 * .pi))
        ) else {
            return nil
        }
        let visualLayers = vfx.entities + particleLayers

        for layer in visualLayers {
            layer.position = essence.position
            layer.components.set(OpacityComponent(opacity: 0))
        }

        return RenderedEssence(
            anchor: anchor,
            root: root,
            vfx: vfx,
            particleLayers: particleLayers,
            visualLayers: visualLayers,
            basePosition: essence.position,
            motionPhase: Float.random(in: 0...(2 * .pi)),
            manifestationStartedAt: CACurrentMediaTime(),
            phaseInDuration: rollOneD3()
        )
    }

    private func updateManifestation(
        for essence: RenderedEssence,
        at time: CFTimeInterval,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>
    ) {
        switch essence.manifestationPhase {
        case .fadingIn:
            let progress = min(
                max((time - essence.manifestationStartedAt) / essence.phaseInDuration, 0),
                1
            )
            applyManifestation(progress: Float(progress), to: essence)

            if progress >= 1 {
                essence.manifestationPhase = .visible
                essence.manifestationStartedAt = time
                if let route = essence.phaseRoute {
                    essence.basePosition = route.emergedExitPosition
                    essence.lastPosition = route.emergedExitPosition
                    essence.phaseRoute = nil
                }
                configureVisiblePhase(for: essence, at: time)
                applyManifestation(progress: 1, to: essence)
            }

        case .visible:
            guard time - essence.manifestationStartedAt >= essence.visibleDuration else {
                return
            }

            if essence.isAwakened {
                essence.phaseOrigin = essence.root.position(relativeTo: nil)
                essence.phaseRoute = surfacePhaseRouteFactory.makeRoute(
                    from: planeAnchors,
                    targetPosition: essence.phaseOrigin ?? essence.basePosition,
                    cameraPosition: cameraPosition
                )
            }
            essence.manifestationPhase = .fadingOut
            essence.manifestationStartedAt = time
            essence.phaseOutDuration = rollOneD3()

        case .fadingOut:
            let progress = min(
                max((time - essence.manifestationStartedAt) / essence.phaseOutDuration, 0),
                1
            )
            applyManifestation(progress: 1 - Float(progress), to: essence)

            if progress >= 1 {
                essence.manifestationPhase = .hidden
                essence.manifestationStartedAt = time
                essence.hiddenDuration = essence.isAwakened ? rollOneD3() : 0
                if let route = essence.phaseRoute {
                    essence.basePosition = route.concealedExitPosition
                    essence.lastPosition = route.concealedExitPosition
                } else if essence.isAwakened {
                    let target = randomAwakenedTarget(from: essence.basePosition)
                    essence.basePosition = target
                    essence.lastPosition = target
                } else {
                    let target = randomCalmTarget(
                        from: essence.root.position(relativeTo: nil),
                        around: cameraPosition
                    )
                    essence.basePosition = target
                    essence.lastPosition = target
                }
                applyManifestation(progress: 0, to: essence)
                stopEmission(for: essence.particleLayers)
            }

        case .hidden:
            guard time - essence.manifestationStartedAt >= essence.hiddenDuration else {
                return
            }

            essence.manifestationPhase = .fadingIn
            essence.manifestationStartedAt = time
            essence.phaseInDuration = rollOneD3()
            startEmission(for: essence.particleLayers)
        }
    }

    private func configureVisiblePhase(
        for essence: RenderedEssence,
        at time: CFTimeInterval
    ) {
        if essence.isAwakened {
            let dartingDuration = rollOneD3()
            let pauseDuration = rollTwoD3() + 0.5 + lockCompletionGrace
            essence.awakenedMotionPhase = .darting
            essence.awakenedMotionPhaseEndsAt = time + dartingDuration
            essence.visibleDuration = dartingDuration + pauseDuration
            essence.nextDartAt = time
        } else {
            essence.visibleDuration = rollTwoD3() + 0.5 + lockCompletionGrace
        }
    }

    private func motionPosition(
        for essence: RenderedEssence,
        at time: CFTimeInterval
    ) -> SIMD3<Float> {
        if let overloadStartedAt = essence.overloadStartedAt {
            let elapsed = time - overloadStartedAt
            if elapsed < 0.5 {
                let flashProgress = Float(min(max((elapsed - 0.22) / 0.28, 0), 1))
                essence.overloadFlash = smoothStep(flashProgress)
                essence.lastPosition = essence.scatterOrigin
                return essence.scatterOrigin
            }

            let progress = Float(min(max((elapsed - 0.5) / 0.62, 0), 1))
            let eased = 1 - pow(1 - progress, 3)
            essence.overloadFlash = max(0, 1 - progress * 2.4)
            let position = simd_mix(essence.scatterOrigin, essence.scatterTarget, SIMD3<Float>(repeating: eased))
            essence.lastPosition = position

            if progress >= 1 {
                essence.overloadStartedAt = nil
                essence.basePosition = essence.scatterTarget
                essence.lastPosition = essence.scatterTarget
                essence.manifestationStartedAt = time
                essence.overloadFlash = 0
                configureVisiblePhase(for: essence, at: time)
            }

            return position
        }

        if let route = essence.phaseRoute {
            let phaseElapsed = time - essence.manifestationStartedAt
            switch essence.manifestationPhase {
            case .fadingOut:
                let progress = Float(min(max(phaseElapsed / essence.phaseOutDuration, 0), 1))
                let origin = essence.phaseOrigin ?? essence.basePosition
                return simd_mix(
                    origin,
                    route.entryPosition,
                    SIMD3<Float>(repeating: smoothStep(progress))
                )
            case .hidden:
                return route.concealedExitPosition
            case .fadingIn:
                let progress = Float(min(max(phaseElapsed / essence.phaseInDuration, 0), 1))
                return simd_mix(
                    route.concealedExitPosition,
                    route.emergedExitPosition,
                    SIMD3<Float>(repeating: smoothStep(progress))
                )
            case .visible:
                break
            }
        }

        if essence.isAwakened {
            return awakenedMotionPosition(for: essence, at: time)
        }

        let shaderTime = Float(time)
        let phase = essence.motionPhase
        let drift = SIMD3<Float>(
            sin(shaderTime * 0.23 + phase) * 0.055 + sin(shaderTime * 0.11 + phase * 2.1) * 0.025,
            sin(shaderTime * 0.57 + phase * 1.3) * 0.045 + cos(shaderTime * 0.19 + phase) * 0.018,
            cos(shaderTime * 0.2 + phase * 0.8) * 0.035 + sin(shaderTime * 0.13 + phase) * 0.018
        )
        let position = essence.basePosition + drift
        essence.lastPosition = position
        return position
    }

    private func awakenedMotionPosition(
        for essence: RenderedEssence,
        at time: CFTimeInterval
    ) -> SIMD3<Float> {
        if
            essence.awakenedMotionPhase == .darting,
            time >= essence.awakenedMotionPhaseEndsAt
        {
            essence.awakenedMotionPhase = .paused
            essence.dartStartedAt = nil
            essence.basePosition = essence.lastPosition
            essence.dartTarget = essence.lastPosition
        }

        if essence.awakenedMotionPhase == .paused {
            essence.lastPosition = essence.basePosition
            return essence.basePosition
        }

        if let dartStartedAt = essence.dartStartedAt {
            let progress = Float(min(max((time - dartStartedAt) / essence.dartDuration, 0), 1))
            let anticipation = sin(progress * .pi) * 0.035
            let eased = progress * progress * (3 - 2 * progress)
            var position = simd_mix(
                essence.dartOrigin,
                essence.dartTarget,
                SIMD3<Float>(repeating: eased)
            )
            position.y += anticipation
            essence.lastPosition = position

            if progress >= 1 {
                essence.dartStartedAt = nil
                essence.basePosition = essence.dartTarget
                essence.lastPosition = essence.dartTarget
                essence.nextDartAt = time + .random(in: 0.1...0.32)
            }

            return position
        }

        if time >= essence.nextDartAt && essence.manifestationPhase == .visible {
            essence.dartStartedAt = time
            essence.dartDuration = .random(in: 0.24...0.48)
            essence.dartOrigin = essence.lastPosition
            essence.dartTarget = randomAwakenedTarget(from: essence.basePosition)
            return essence.lastPosition
        }

        let shaderTime = Float(time)
        let hover = SIMD3<Float>(
            sin(shaderTime * 1.4 + essence.motionPhase) * 0.028,
            sin(shaderTime * 2.1 + essence.motionPhase * 1.3) * 0.035,
            cos(shaderTime * 1.15 + essence.motionPhase) * 0.022
        )
        let position = essence.basePosition + hover
        essence.lastPosition = position
        return position
    }

    private func randomAwakenedTarget(from origin: SIMD3<Float>) -> SIMD3<Float> {
        boundedAwakenedPosition(
            origin + SIMD3<Float>(
                .random(in: -0.72...0.72),
                .random(in: -0.36...0.42),
                .random(in: -0.56...0.56)
            )
        )
    }

    private func randomCalmTarget(
        from origin: SIMD3<Float>,
        around cameraPosition: SIMD3<Float>
    ) -> SIMD3<Float> {
        let angle = Float.random(in: 0...(2 * .pi))
        let relocationDistance = Float.random(in: 0.4...1)
        var candidate = origin + SIMD3<Float>(
            cos(angle) * relocationDistance,
            .random(in: -0.28...0.38),
            sin(angle) * relocationDistance
        )

        var cameraOffset = candidate - cameraPosition
        let distanceFromCamera = simd_length(cameraOffset)
        if distanceFromCamera < 0.001 {
            cameraOffset = SIMD3<Float>(cos(angle), 0, sin(angle))
        }

        let playableDistance = min(max(simd_length(cameraOffset), 0.55), 2.25)
        candidate = cameraPosition + simd_normalize(cameraOffset) * playableDistance
        return candidate
    }

    private func boundedAwakenedPosition(_ position: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            min(max(position.x, -1.55), 1.55),
            min(max(position.y, -0.62), 0.9),
            min(max(position.z, -2.55), -0.5)
        )
    }

    private func rollOneD3() -> CFTimeInterval {
        CFTimeInterval(Int.random(in: 1...3))
    }

    private func rollTwoD3() -> CFTimeInterval {
        CFTimeInterval(Int.random(in: 1...3) + Int.random(in: 1...3))
    }

    private func applyManifestation(progress: Float, to essence: RenderedEssence) {
        let progress = min(max(progress, 0), 1)
        let presentation = EssenceManifestationPresentation(
            shimmer: stagedProgress(progress, from: 0, to: 0.26),
            plasma: stagedProgress(progress, from: 0.12, to: 0.56),
            core: stagedProgress(progress, from: 0.32, to: 0.68),
            halo: stagedProgress(progress, from: 0.36, to: 0.8),
            tendrils: stagedProgress(progress, from: 0.46, to: 1)
        )

        essence.manifestationLevel = smoothStep(progress)
        essence.presentation = presentation

        setOpacity(presentation.shimmer, on: essence.particleLayers[0])
        setOpacity(presentation.shimmer * presentation.plasma, on: essence.particleLayers[1])
        setOpacity(presentation.core, on: essence.vfx.core)
        setOpacity(presentation.halo, on: essence.vfx.coreHalo)
        setOpacity(presentation.tendrils, on: essence.vfx.ribbon.entity)

        for (index, shell) in essence.vfx.plasmaShells.enumerated() {
            let shellDelay = Float(index) * 0.045
            let shellLevel = stagedProgress(
                progress,
                from: 0.12 + shellDelay,
                to: 0.56 + shellDelay
            )
            setOpacity(shellLevel, on: shell)
        }
    }

    private func stagedProgress(_ value: Float, from start: Float, to end: Float) -> Float {
        smoothStep(min(max((value - start) / (end - start), 0), 1))
    }

    private func smoothStep(_ value: Float) -> Float {
        return value * value * (3 - 2 * value)
    }

    private func setOpacity(_ opacity: Float, on entity: Entity) {
        entity.components.set(OpacityComponent(opacity: opacity))
    }

    private func makeMoteEmitter(radius: Float) -> Entity {
        let entity = Entity()
        var component = ParticleEmitterComponent()
        component.isEmitting = false
        component.emitterShape = .sphere
        component.birthLocation = .volume
        component.birthDirection = .normal
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.emitterShapeSize = SIMD3<Float>(repeating: radius * 0.68)
        component.speed = 0.018
        component.speedVariation = 0.008
        component.radialAmount = 0.65
        component.mainEmitter.birthRate = 8
        component.mainEmitter.birthRateVariation = 2
        component.mainEmitter.lifeSpan = 0.85
        component.mainEmitter.lifeSpanVariation = 0.18
        component.mainEmitter.size = radius * 0.055
        component.mainEmitter.sizeVariation = radius * 0.018
        component.mainEmitter.opacityCurve = .quickFadeInOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.35
        component.mainEmitter.noiseStrength = 0.08
        component.mainEmitter.noiseScale = 0.045
        component.mainEmitter.noiseAnimationSpeed = 0.3
        component.mainEmitter.dampingFactor = 0.12
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = cyanParticleTexture
        entity.components.set(component)
        return entity
    }

    private func makeWakeEmitter(radius: Float) -> Entity {
        let entity = Entity()
        var component = ParticleEmitterComponent()
        component.isEmitting = false
        component.emitterShape = .point
        component.birthLocation = .volume
        component.birthDirection = .local
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.005
        component.speedVariation = 0.003
        component.mainEmitter.birthRate = 7
        component.mainEmitter.birthRateVariation = 2
        component.mainEmitter.lifeSpan = 0.55
        component.mainEmitter.lifeSpanVariation = 0.12
        component.mainEmitter.size = radius * 0.1
        component.mainEmitter.sizeVariation = radius * 0.025
        component.mainEmitter.opacityCurve = .easeFadeOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.16
        component.mainEmitter.noiseStrength = 0.035
        component.mainEmitter.noiseScale = 0.025
        component.mainEmitter.noiseAnimationSpeed = 0.18
        component.mainEmitter.stretchFactor = 4.2
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = violetParticleTexture
        entity.components.set(component)
        return entity
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

    private func stopEmission(for entities: [Entity]) {
        for entity in entities {
            guard var component = entity.components[ParticleEmitterComponent.self] else {
                continue
            }

            component.isEmitting = false
            entity.components.set(component)
        }
    }

    private func renderAtmosphere(in arView: ARView) {
        let anchor = AnchorEntity(world: .zero)
        let field = Entity()
        field.position = SIMD3<Float>(0, 0, -1.4)

        var component = ParticleEmitterComponent()
        component.isEmitting = false
        component.emitterShape = .box
        component.emitterShapeSize = SIMD3<Float>(3.6, 2.4, 3.8)
        component.birthLocation = .volume
        component.birthDirection = .local
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.005
        component.speedVariation = 0.003
        component.mainEmitter.birthRate = 11
        component.mainEmitter.birthRateVariation = 3
        component.mainEmitter.lifeSpan = 13
        component.mainEmitter.lifeSpanVariation = 2.5
        component.mainEmitter.size = 0.006
        component.mainEmitter.sizeVariation = 0.0025
        component.mainEmitter.opacityCurve = .gradualFadeInOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.55
        component.mainEmitter.noiseStrength = 0.018
        component.mainEmitter.noiseScale = 0.5
        component.mainEmitter.noiseAnimationSpeed = 0.08
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = cyanParticleTexture
        field.components.set(component)

        anchor.addChild(field)
        arView.scene.addAnchor(anchor)
        startEmission(for: [field])
        atmosphereAnchor = anchor
    }

    private func removeAllEssence(from arView: ARView) {
        for renderedEssence in renderedEssences.values {
            arView.scene.removeAnchor(renderedEssence.anchor)
        }
        renderedEssences.removeAll()

        if let atmosphereAnchor {
            arView.scene.removeAnchor(atmosphereAnchor)
            self.atmosphereAnchor = nil
        }
    }

}

private enum EssenceManifestationPhase {
    case fadingIn
    case visible
    case fadingOut
    case hidden
}

private enum AwakenedMotionPhase {
    case darting
    case paused
}

private final class RenderedEssence {
    let anchor: AnchorEntity
    let root: Entity
    let vfx: EssenceVFX
    let particleLayers: [Entity]
    let visualLayers: [Entity]
    var basePosition: SIMD3<Float>
    let motionPhase: Float
    var manifestationPhase: EssenceManifestationPhase = .fadingIn
    var manifestationStartedAt: CFTimeInterval
    var phaseInDuration: CFTimeInterval
    var phaseOutDuration: CFTimeInterval = 1
    var manifestationLevel: Float = 0
    var presentation = EssenceManifestationPresentation.hidden
    var hiddenDuration: CFTimeInterval = 0
    var visibleDuration: CFTimeInterval = 3
    var isAwakened = false
    var overloadStartedAt: CFTimeInterval?
    var overloadFlash: Float = 0
    var scatterOrigin = SIMD3<Float>.zero
    var scatterTarget = SIMD3<Float>.zero
    var lastPosition: SIMD3<Float>
    var nextDartAt: CFTimeInterval = .greatestFiniteMagnitude
    var dartStartedAt: CFTimeInterval?
    var dartDuration: CFTimeInterval = 0.35
    var dartOrigin = SIMD3<Float>.zero
    var dartTarget = SIMD3<Float>.zero
    var phaseOrigin: SIMD3<Float>?
    var phaseRoute: SurfacePhaseRoute?
    var awakenedMotionPhase: AwakenedMotionPhase = .darting
    var awakenedMotionPhaseEndsAt: CFTimeInterval = .greatestFiniteMagnitude

    init(
        anchor: AnchorEntity,
        root: Entity,
        vfx: EssenceVFX,
        particleLayers: [Entity],
        visualLayers: [Entity],
        basePosition: SIMD3<Float>,
        motionPhase: Float,
        manifestationStartedAt: CFTimeInterval,
        phaseInDuration: CFTimeInterval
    ) {
        self.anchor = anchor
        self.root = root
        self.vfx = vfx
        self.particleLayers = particleLayers
        self.visualLayers = visualLayers
        self.basePosition = basePosition
        self.lastPosition = basePosition
        self.motionPhase = motionPhase
        self.manifestationStartedAt = manifestationStartedAt
        self.phaseInDuration = phaseInDuration
    }
}

private struct EssenceManifestationPresentation {
    let shimmer: Float
    let plasma: Float
    let core: Float
    let halo: Float
    let tendrils: Float

    static let hidden = EssenceManifestationPresentation(
        shimmer: 0,
        plasma: 0,
        core: 0,
        halo: 0,
        tendrils: 0
    )
}

private enum ParticleGlowTextureFactory {
    static func makeTexture(color: UIColor) -> TextureResource? {
        let size = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let transparent = color.withAlphaComponent(0).cgColor
        let colors = [color.cgColor, color.withAlphaComponent(0.5).cgColor, transparent] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: [0, 0.28, 1]
        ) else {
            return nil
        }

        let center = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(size) / 2,
            options: [.drawsAfterEndLocation]
        )

        guard let image = context.makeImage() else {
            return nil
        }

        return try? TextureResource(
            image: image,
            withName: "veil-particle-glow",
            options: .init(semantic: .color)
        )
    }
}

private extension Transform {
    var forwardVector: SIMD3<Float> {
        -SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
    }

}
