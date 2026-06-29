import CoreGraphics
import RealityKit
import UIKit

@MainActor
final class ARSceneEssenceRenderer {
    private let manifestationDuration: CFTimeInterval = 1.1
    private let demanifestationDuration: CFTimeInterval = 0.95
    private let visibleDuration: CFTimeInterval = 3
    private var renderedEssences: [AmbientEssence.ID: RenderedEssence] = [:]
    private var atmosphereAnchor: AnchorEntity?
    private let vfxFactory = EssenceVFXFactory()
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

    func updateFloatingMotion(at time: CFTimeInterval) {
        for renderedEssence in renderedEssences.values {
            updateManifestation(for: renderedEssence, at: time)

            let shaderTime = Float(time)
            let phase = renderedEssence.motionPhase
            let drift = SIMD3<Float>(
                sin(shaderTime * 0.23 + phase) * 0.055 + sin(shaderTime * 0.11 + phase * 2.1) * 0.025,
                sin(shaderTime * 0.57 + phase * 1.3) * 0.045 + cos(shaderTime * 0.19 + phase) * 0.018,
                cos(shaderTime * 0.2 + phase * 0.8) * 0.035 + sin(shaderTime * 0.13 + phase) * 0.018
            )
            let position = renderedEssence.basePosition + drift
            let orientation = simd_quatf(
                angle: sin(shaderTime * 0.17 + phase) * 0.35,
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
                tendrilLevel: renderedEssence.presentation.tendrils
            )
        }
    }

    func worldPosition(for id: AmbientEssence.ID) -> SIMD3<Float>? {
        renderedEssences[id]?.root.position(relativeTo: nil)
    }

    func isCapturable(id: AmbientEssence.ID) -> Bool {
        renderedEssences[id]?.manifestationPhase == .visible
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
            manifestationStartedAt: CACurrentMediaTime()
        )
    }

    private func updateManifestation(
        for essence: RenderedEssence,
        at time: CFTimeInterval
    ) {
        switch essence.manifestationPhase {
        case .fadingIn:
            let progress = min(
                max((time - essence.manifestationStartedAt) / manifestationDuration, 0),
                1
            )
            applyManifestation(progress: Float(progress), to: essence)

            if progress >= 1 {
                essence.manifestationPhase = .visible
                essence.manifestationStartedAt = time
                applyManifestation(progress: 1, to: essence)
            }

        case .visible:
            guard time - essence.manifestationStartedAt >= visibleDuration else {
                return
            }

            essence.manifestationPhase = .fadingOut
            essence.manifestationStartedAt = time

        case .fadingOut:
            let progress = min(
                max((time - essence.manifestationStartedAt) / demanifestationDuration, 0),
                1
            )
            applyManifestation(progress: 1 - Float(progress), to: essence)

            if progress >= 1 {
                essence.manifestationPhase = .hidden
                essence.manifestationStartedAt = time
                essence.hiddenDuration = .random(in: 3...6)
                applyManifestation(progress: 0, to: essence)
                stopEmission(for: essence.particleLayers)
            }

        case .hidden:
            guard time - essence.manifestationStartedAt >= essence.hiddenDuration else {
                return
            }

            essence.manifestationPhase = .fadingIn
            essence.manifestationStartedAt = time
            startEmission(for: essence.particleLayers)
        }
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

private final class RenderedEssence {
    let anchor: AnchorEntity
    let root: Entity
    let vfx: EssenceVFX
    let particleLayers: [Entity]
    let visualLayers: [Entity]
    let basePosition: SIMD3<Float>
    let motionPhase: Float
    var manifestationPhase: EssenceManifestationPhase = .fadingIn
    var manifestationStartedAt: CFTimeInterval
    var manifestationLevel: Float = 0
    var presentation = EssenceManifestationPresentation.hidden
    var hiddenDuration: CFTimeInterval = 0

    init(
        anchor: AnchorEntity,
        root: Entity,
        vfx: EssenceVFX,
        particleLayers: [Entity],
        visualLayers: [Entity],
        basePosition: SIMD3<Float>,
        motionPhase: Float,
        manifestationStartedAt: CFTimeInterval
    ) {
        self.anchor = anchor
        self.root = root
        self.vfx = vfx
        self.particleLayers = particleLayers
        self.visualLayers = visualLayers
        self.basePosition = basePosition
        self.motionPhase = motionPhase
        self.manifestationStartedAt = manifestationStartedAt
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
