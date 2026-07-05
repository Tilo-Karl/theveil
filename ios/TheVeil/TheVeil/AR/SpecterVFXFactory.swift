import Metal
import RealityKit
import UIKit

@MainActor
final class SpecterVFXFactory {
    private let bodyMesh: MeshResource?
    private let bodyMaterial: CustomMaterial?
    private let plasmaTexture = SpectralParticleTextureFactory.makeTexture(
        color: UIColor(red: 0.7, green: 0.2, blue: 0.95, alpha: 0.8),
        name: "specter-plasma"
    )

    init() {
        bodyMesh = try? ProceduralSpecter.makeMesh()

        guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else {
            bodyMaterial = nil
            return
        }
        bodyMaterial = Self.makeBodyMaterial(library: library)
    }

    func make(id: String, phase: Float) -> SpecterVFX? {
        guard let bodyMesh, let bodyMaterial, let plasmaTexture else {
            return nil
        }

        let root = Entity()
        root.name = id

        let outerPlasma = makeBodyLayer(
            mesh: bodyMesh,
            baseMaterial: bodyMaterial,
            controls: SIMD4<Float>(phase, 0, 1.28, 0.72),
            scale: 1.0
        )

        let innerPlasma = makeBodyLayer(
            mesh: bodyMesh,
            baseMaterial: bodyMaterial,
            controls: SIMD4<Float>(phase + 0.33, 1, 1.35, 0.65),
            scale: 0.95
        )

        root.addChild(innerPlasma)
        root.addChild(outerPlasma)

        let plasmaDischarge = makePlasmaDischarge(texture: plasmaTexture)
        let curlTendrils = makeCurlTendrils(texture: plasmaTexture)

        root.addChild(plasmaDischarge)
        root.addChild(curlTendrils)

        root.components.set(OpacityComponent(opacity: 0.78))
        return SpecterVFX(
            root: root,
            bodyLayers: [outerPlasma, innerPlasma],
            particleLayers: [plasmaDischarge, curlTendrils]
        )
    }

    private func makeBodyLayer(
        mesh: MeshResource,
        baseMaterial: CustomMaterial,
        controls: SIMD4<Float>,
        scale: Float
    ) -> ModelEntity {
        var material = baseMaterial
        material.custom.value = controls
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.components.set(
            GroundingShadowComponent(castsShadow: false, receivesShadow: false)
        )
        return entity
    }

    private static func makeBodyMaterial(library: any MTLLibrary) -> CustomMaterial? {
        let surface = CustomMaterial.SurfaceShader(named: "specterSurface", in: library)
        let geometry = CustomMaterial.GeometryModifier(named: "specterGeometry", in: library)
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

    private func makePlasmaDischarge(texture: TextureResource) -> Entity {
        let entity = Entity()
        entity.position = SIMD3<Float>(0, 0.1, 0)
        var component = ParticleEmitterComponent()
        component.emitterShape = .sphere
        component.emitterShapeSize = SIMD3<Float>(0.48, 0.48, 0.48)
        component.birthLocation = .surface
        component.birthDirection = .worldY
        component.emissionDirection = SIMD3<Float>(0, 1, 0)
        component.fieldSimulationSpace = .world
        component.particlesInheritTransform = true
        component.speed = 0.055
        component.speedVariation = 0.022
        component.radialAmount = 0.35
        component.mainEmitter.birthRate = 22
        component.mainEmitter.birthRateVariation = 7
        component.mainEmitter.lifeSpan = 1.8
        component.mainEmitter.lifeSpanVariation = 0.5
        component.mainEmitter.size = 0.011
        component.mainEmitter.sizeVariation = 0.005
        component.mainEmitter.opacityCurve = .gradualFadeInOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.18
        component.mainEmitter.noiseStrength = 0.14
        component.mainEmitter.noiseScale = 0.2
        component.mainEmitter.noiseAnimationSpeed = 0.32
        component.mainEmitter.stretchFactor = 4.2
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = texture
        entity.components.set(component)
        return entity
    }

    private func makeCurlTendrils(texture: TextureResource) -> Entity {
        let entity = Entity()
        entity.position = SIMD3<Float>(0, 0.0, 0)
        var component = ParticleEmitterComponent()
        component.emitterShape = .box
        component.emitterShapeSize = SIMD3<Float>(0.42, 0.52, 0.42)
        component.birthLocation = .surface
        component.birthDirection = .local
        component.emissionDirection = SIMD3<Float>(0, 0, 0)
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.038
        component.speedVariation = 0.016
        component.radialAmount = 0.48
        component.mainEmitter.birthRate = 28
        component.mainEmitter.birthRateVariation = 9
        component.mainEmitter.lifeSpan = 2.2
        component.mainEmitter.lifeSpanVariation = 0.6
        component.mainEmitter.size = 0.008
        component.mainEmitter.sizeVariation = 0.004
        component.mainEmitter.opacityCurve = .easeFadeOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2
        component.mainEmitter.noiseStrength = 0.16
        component.mainEmitter.noiseScale = 0.25
        component.mainEmitter.noiseAnimationSpeed = 0.42
        component.mainEmitter.stretchFactor = 5.8
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

    init(root: Entity, bodyLayers: [ModelEntity], particleLayers: [Entity]) {
        self.root = root
        self.bodyLayers = bodyLayers
        self.particleLayers = particleLayers
    }
}
