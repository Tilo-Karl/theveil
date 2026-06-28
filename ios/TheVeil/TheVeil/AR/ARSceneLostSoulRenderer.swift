import RealityKit
import UIKit

@MainActor
final class ARSceneLostSoulRenderer {
    private var renderedLostSoul: RenderedLostSoul?
    private var phaseToken: UUID?
    private var isPhasing = false

    func render(_ lostSoul: LostSoul, in arView: ARView) {
        guard renderedLostSoul?.id != lostSoul.id else {
            return
        }

        removeRenderedLostSoul(from: arView)

        let spawnPosition = arView.cameraTransform.translation
            + arView.cameraTransform.forwardVector * 1.35
        let anchor = AnchorEntity(world: spawnPosition)
        let entity = makeLostSoulEntity(id: lostSoul.id)
        anchor.addChild(entity)
        anchor.scale = SIMD3<Float>(repeating: 0.01)
        arView.scene.addAnchor(anchor)

        var manifestedTransform = anchor.transform
        manifestedTransform.scale = SIMD3<Float>(repeating: 1)
        anchor.move(to: manifestedTransform, relativeTo: nil, duration: 0.45, timingFunction: .easeOut)

        renderedLostSoul = RenderedLostSoul(
            id: lostSoul.id,
            anchor: anchor,
            entity: entity,
            motionPhase: Float.random(in: 0...(2 * .pi))
        )
    }

    func updateFloatingMotion(at time: CFTimeInterval) {
        guard let renderedLostSoul, !isPhasing else {
            return
        }

        let time = Float(time)
        let phase = renderedLostSoul.motionPhase
        renderedLostSoul.entity.position = SIMD3<Float>(
            sin(time * 0.32 + phase) * 0.025,
            sin(time * 0.74 + phase * 1.4) * 0.055,
            cos(time * 0.27 + phase) * 0.018
        )
    }

    func worldPosition(for id: LostSoul.ID) -> SIMD3<Float>? {
        guard
            let renderedLostSoul,
            renderedLostSoul.id == id,
            !isPhasing
        else {
            return nil
        }

        return renderedLostSoul.entity.position(relativeTo: nil)
    }

    func phase(along route: SurfacePhaseRoute) {
        guard let renderedLostSoul, !isPhasing else {
            return
        }

        let token = UUID()
        phaseToken = token
        isPhasing = true
        renderedLostSoul.entity.position = .zero

        let anchor = renderedLostSoul.anchor
        var entryTransform = anchor.transform
        entryTransform.translation = route.entryPosition
        entryTransform.scale = SIMD3<Float>(repeating: 0.02)
        anchor.move(to: entryTransform, relativeTo: nil, duration: 0.32, timingFunction: .easeIn)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self] in
            guard let self, self.phaseToken == token else {
                return
            }

            anchor.isEnabled = false

            var concealedTransform = anchor.transform
            concealedTransform.translation = route.concealedExitPosition
            concealedTransform.scale = SIMD3<Float>(repeating: 0.02)
            anchor.transform = concealedTransform

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                guard let self, self.phaseToken == token else {
                    return
                }

                anchor.isEnabled = true

                var emergedTransform = concealedTransform
                emergedTransform.translation = route.emergedExitPosition
                emergedTransform.scale = SIMD3<Float>(repeating: 1)
                anchor.move(to: emergedTransform, relativeTo: nil, duration: 0.4, timingFunction: .easeOut)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
                    guard let self, self.phaseToken == token else {
                        return
                    }

                    self.phaseToken = nil
                    self.isPhasing = false
                }
            }
        }
    }

    private func removeRenderedLostSoul(from arView: ARView) {
        if let renderedLostSoul {
            arView.scene.removeAnchor(renderedLostSoul.anchor)
        }

        renderedLostSoul = nil
        phaseToken = nil
        isPhasing = false
    }

    private func makeLostSoulEntity(id: LostSoul.ID) -> Entity {
        let root = Entity()
        root.name = id.uuidString

        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.085),
            materials: [lostSoulMaterial(alpha: 0.78)]
        )
        head.position.y = 0.2

        let torso = ModelEntity(
            mesh: .generateSphere(radius: 0.13),
            materials: [lostSoulMaterial(alpha: 0.58)]
        )
        torso.scale = SIMD3<Float>(0.78, 1.25, 0.56)
        torso.position.y = 0.02

        let lowerBody = ModelEntity(
            mesh: .generateSphere(radius: 0.11),
            materials: [lostSoulMaterial(alpha: 0.4)]
        )
        lowerBody.scale = SIMD3<Float>(0.62, 1.5, 0.48)
        lowerBody.position.y = -0.19

        root.addChild(head)
        root.addChild(torso)
        root.addChild(lowerBody)
        return root
    }

    private func lostSoulMaterial(alpha: CGFloat) -> SimpleMaterial {
        SimpleMaterial(
            color: UIColor(red: 0.72, green: 0.9, blue: 1, alpha: alpha),
            roughness: 0.08,
            isMetallic: false
        )
    }
}

private struct RenderedLostSoul {
    let id: LostSoul.ID
    let anchor: AnchorEntity
    let entity: Entity
    let motionPhase: Float
}

private extension Transform {
    var forwardVector: SIMD3<Float> {
        -SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
    }
}
