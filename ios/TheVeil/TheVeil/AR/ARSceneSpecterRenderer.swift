import Foundation
import RealityKit

@MainActor
final class ARSceneSpecterRenderer {
    private var renderedSpecter: RenderedSpecter?
    private let vfxFactory = SpecterVFXFactory()

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

        renderedSpecter = RenderedSpecter(
            id: specter.id,
            anchor: anchor,
            root: visual.root,
            bodyLayers: visual.bodyLayers,
            particleLayers: visual.particleLayers,
            motionPhase: specter.phase
        )
    }

    func update(at time: CFTimeInterval, cameraPosition: SIMD3<Float>) {
        guard let specter = renderedSpecter else {
            return
        }

        let clock = Float(time) + specter.motionPhase * 4.1
        specter.root.position = SIMD3<Float>(
            sin(clock * 0.31) * 0.16,
            sin(clock * 0.47) * 0.08,
            cos(clock * 0.27) * 0.12
        )

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
            0.045
        )

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
    }

    func worldPosition(for id: Specter.ID) -> SIMD3<Float>? {
        guard let renderedSpecter, renderedSpecter.id == id else {
            return nil
        }
        return renderedSpecter.root.position(relativeTo: nil)
    }

    func remove(from arView: ARView) {
        if let renderedSpecter {
            arView.scene.removeAnchor(renderedSpecter.anchor)
        }
        renderedSpecter = nil
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

private final class RenderedSpecter {
    let id: Specter.ID
    let anchor: AnchorEntity
    let root: Entity
    let bodyLayers: [ModelEntity]
    let particleLayers: [Entity]
    let motionPhase: Float

    init(
        id: Specter.ID,
        anchor: AnchorEntity,
        root: Entity,
        bodyLayers: [ModelEntity],
        particleLayers: [Entity],
        motionPhase: Float
    ) {
        self.id = id
        self.anchor = anchor
        self.root = root
        self.bodyLayers = bodyLayers
        self.particleLayers = particleLayers
        self.motionPhase = motionPhase
    }
}
