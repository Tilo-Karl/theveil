import Metal
import RealityKit
import UIKit

@MainActor
final class SpecterVFXFactory {
    private let faceMesh: MeshResource?
    private let faceMaterial: CustomMaterial?
    private let faceFieldTexture: TextureResource?
    private let plasmaTexture = SpectralParticleTextureFactory.makeTexture(
        color: UIColor(red: 0.72, green: 0.12, blue: 1.0, alpha: 0.92),
        name: "specter-outline-plasma"
    )

    init() {
        faceMesh = try? ProceduralSpecter.makeFacePlane()
        faceFieldTexture = try? TextureResource.load(named: "SpecterFaceField")

        guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else {
            faceMaterial = nil
            return
        }

        faceMaterial = Self.makeFaceMaterial(library: library)
    }

    func make(id: String, phase: Float) -> SpecterVFX? {
        guard let faceMesh, let faceMaterial, let plasmaTexture else {
            return nil
        }

        let root = Entity()
        root.name = id

        // Broad spectral storm behind the readable face.
        let aura = makeLayer(
            mesh: faceMesh,
            baseMaterial: faceMaterial,
            controls: SIMD4<Float>(phase, 0, 0, 0.88),
            scale: SIMD3<Float>(1.18, 1.18, 1.0),
            z: 0.025
        )

        // Explicit face silhouette. This must remain the dominant readable layer.
        let face = makeLayer(
            mesh: faceMesh,
            baseMaterial: faceMaterial,
            controls: SIMD4<Float>(phase + 0.31, 1, 0, 0.98),
            scale: SIMD3<Float>(1.0, 1.0, 1.0),
            z: 0
        )

        root.addChild(aura)
        root.addChild(face)

        let sparks = makeSparks(texture: plasmaTexture)
        let crown = makeCrownTendrils(texture: plasmaTexture)

        root.addChild(sparks)
        root.addChild(crown)
        root.components.set(OpacityComponent(opacity: 1.0))

        return SpecterVFX(
            root: root,
            bodyLayers: [aura, face],
            particleLayers: [sparks, crown]
        )
    }

    private func makeLayer(
        mesh: MeshResource,
        baseMaterial: CustomMaterial,
        controls: SIMD4<Float>,
        scale: SIMD3<Float>,
        z: Float
    ) -> ModelEntity {
        var material = baseMaterial
        material.custom.value = controls
        if let faceFieldTexture {
            material.custom.texture = .init(faceFieldTexture)
        }

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = scale
        entity.position.z = z
        entity.components.set(
            GroundingShadowComponent(
                castsShadow: false,
                receivesShadow: false
            )
        )
        return entity
    }

    private static func makeFaceMaterial(
        library: any MTLLibrary
    ) -> CustomMaterial? {
        let surface = CustomMaterial.SurfaceShader(
            named: "specterSurface",
            in: library
        )
        let geometry = CustomMaterial.GeometryModifier(
            named: "specterGeometry",
            in: library
        )

        guard var material = try? CustomMaterial(
            surfaceShader: surface,
            geometryModifier: geometry,
            lightingModel: .unlit
        ) else {
            return nil
        }

        material.blending = .transparent(opacity: .init(scale: 1))
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private func makeSparks(texture: TextureResource) -> Entity {
        let entity = Entity()
        entity.position = SIMD3<Float>(0, 0.06, 0.045)

        var component = ParticleEmitterComponent()
        component.emitterShape = .box
        component.emitterShapeSize = SIMD3<Float>(0.78, 1.12, 0.10)
        component.birthLocation = .surface
        component.birthDirection = .local
        component.emissionDirection = SIMD3<Float>(0, 0.22, 0)
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.055
        component.speedVariation = 0.040
        component.radialAmount = 0.58

        component.mainEmitter.birthRate = 34
        component.mainEmitter.birthRateVariation = 12
        component.mainEmitter.lifeSpan = 1.45
        component.mainEmitter.lifeSpanVariation = 0.52
        component.mainEmitter.size = 0.010
        component.mainEmitter.sizeVariation = 0.006
        component.mainEmitter.opacityCurve = .gradualFadeInOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.16
        component.mainEmitter.noiseStrength = 0.18
        component.mainEmitter.noiseScale = 0.22
        component.mainEmitter.noiseAnimationSpeed = 0.36
        component.mainEmitter.stretchFactor = 3.8
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = texture

        entity.components.set(component)
        return entity
    }

    private func makeCrownTendrils(texture: TextureResource) -> Entity {
        let entity = Entity()
        entity.position = SIMD3<Float>(0, 0.42, 0.035)

        var component = ParticleEmitterComponent()
        component.emitterShape = .box
        component.emitterShapeSize = SIMD3<Float>(0.62, 0.24, 0.08)
        component.birthLocation = .surface
        component.birthDirection = .local
        component.emissionDirection = SIMD3<Float>(0, 1, 0)
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.082
        component.speedVariation = 0.038
        component.radialAmount = 0.46

        component.mainEmitter.birthRate = 24
        component.mainEmitter.birthRateVariation = 8
        component.mainEmitter.lifeSpan = 1.75
        component.mainEmitter.lifeSpanVariation = 0.48
        component.mainEmitter.size = 0.012
        component.mainEmitter.sizeVariation = 0.005
        component.mainEmitter.opacityCurve = .easeFadeOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.12
        component.mainEmitter.noiseStrength = 0.22
        component.mainEmitter.noiseScale = 0.18
        component.mainEmitter.noiseAnimationSpeed = 0.50
        component.mainEmitter.stretchFactor = 6.2
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = texture

        entity.components.set(component)
        return entity
    }
}

@MainActor
final class SpecterVFX {
    let root: Entity
    let bodyLayers: [ModelEntity]
    let particleLayers: [Entity]

    init(
        root: Entity,
        bodyLayers: [ModelEntity],
        particleLayers: [Entity]
    ) {
        self.root = root
        self.bodyLayers = bodyLayers
        self.particleLayers = particleLayers
    }
}
