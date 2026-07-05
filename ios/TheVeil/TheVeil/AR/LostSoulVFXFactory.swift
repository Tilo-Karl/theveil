import Metal
import RealityKit
import UIKit

@MainActor
final class LostSoulVFXFactory {
    private let bodyMesh: MeshResource?
    private let bodyMaterial: CustomMaterial?
    private let mistTexture = SpectralParticleTextureFactory.makeTexture(
        color: UIColor(red: 0.48, green: 0.9, blue: 1, alpha: 0.72),
        name: "lost-soul-mist"
    )

    init() {
        bodyMesh = try? ProceduralLostSoulBody.makeMesh()

        guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else {
            bodyMaterial = nil
            return
        }
        bodyMaterial = Self.makeBodyMaterial(library: library)
    }

    func make(id: LostSoul.ID, phase: Float) -> LostSoulVFX? {
        guard let bodyMesh, let bodyMaterial, let mistTexture else {
            return nil
        }

        let root = Entity()
        root.name = id.uuidString

        let outerBody = makeBodyLayer(
            mesh: bodyMesh,
            baseMaterial: bodyMaterial,
            controls: SIMD4<Float>(phase, 0, 1.02, 0.68),
            scale: 1
        )
        let innerBody = makeBodyLayer(
            mesh: bodyMesh,
            baseMaterial: bodyMaterial,
            controls: SIMD4<Float>(phase + 0.19, 1, 1.08, 0.6),
            scale: 0.972
        )

        root.addChild(innerBody)
        root.addChild(outerBody)

        let edgeWisps = makeEdgeWisps(texture: mistTexture)
        let lowerMist = makeLowerMist(texture: mistTexture)
        root.addChild(edgeWisps)
        root.addChild(lowerMist)

        root.components.set(OpacityComponent(opacity: 0.72))
        return LostSoulVFX(
            root: root,
            bodyLayers: [outerBody, innerBody],
            particleLayers: [edgeWisps, lowerMist]
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
        let surface = CustomMaterial.SurfaceShader(named: "lostSoulSurface", in: library)
        let geometry = CustomMaterial.GeometryModifier(named: "lostSoulGeometry", in: library)
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

    private func makeEdgeWisps(texture: TextureResource) -> Entity {
        let entity = Entity()
        entity.position = SIMD3<Float>(0, -0.02, 0)
        var component = ParticleEmitterComponent()
        component.emitterShape = .box
        component.emitterShapeSize = SIMD3<Float>(0.35, 1.03, 0.17)
        component.birthLocation = .surface
        component.birthDirection = .local
        component.emissionDirection = SIMD3<Float>(0, 1, 0)
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.028
        component.speedVariation = 0.014
        component.radialAmount = 0.14
        component.mainEmitter.birthRate = 9
        component.mainEmitter.birthRateVariation = 3
        component.mainEmitter.lifeSpan = 1.55
        component.mainEmitter.lifeSpanVariation = 0.4
        component.mainEmitter.size = 0.007
        component.mainEmitter.sizeVariation = 0.003
        component.mainEmitter.opacityCurve = .gradualFadeInOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2
        component.mainEmitter.noiseStrength = 0.06
        component.mainEmitter.noiseScale = 0.14
        component.mainEmitter.noiseAnimationSpeed = 0.18
        component.mainEmitter.stretchFactor = 4.2
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = texture
        entity.components.set(component)
        return entity
    }

    private func makeLowerMist(texture: TextureResource) -> Entity {
        let entity = Entity()
        entity.position = SIMD3<Float>(0, -0.59, 0)
        var component = ParticleEmitterComponent()
        component.emitterShape = .box
        component.emitterShapeSize = SIMD3<Float>(0.22, 0.3, 0.14)
        component.birthLocation = .volume
        component.birthDirection = .local
        component.emissionDirection = SIMD3<Float>(0, -1, 0)
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.025
        component.speedVariation = 0.012
        component.radialAmount = 0.3
        component.mainEmitter.birthRate = 18
        component.mainEmitter.birthRateVariation = 5
        component.mainEmitter.lifeSpan = 2.4
        component.mainEmitter.lifeSpanVariation = 0.6
        component.mainEmitter.size = 0.012
        component.mainEmitter.sizeVariation = 0.006
        component.mainEmitter.opacityCurve = .easeFadeOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.18
        component.mainEmitter.noiseStrength = 0.08
        component.mainEmitter.noiseScale = 0.13
        component.mainEmitter.noiseAnimationSpeed = 0.2
        component.mainEmitter.stretchFactor = 5.5
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = texture
        entity.components.set(component)
        return entity
    }
}

@MainActor
final class LostSoulVFX {
    let root: Entity
    let bodyLayers: [ModelEntity]
    let particleLayers: [Entity]

    init(root: Entity, bodyLayers: [ModelEntity], particleLayers: [Entity]) {
        self.root = root
        self.bodyLayers = bodyLayers
        self.particleLayers = particleLayers
    }
}
