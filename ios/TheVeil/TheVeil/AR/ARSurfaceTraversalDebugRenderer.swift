import RealityKit
import simd
import UIKit

@MainActor
final class ARSurfaceTraversalDebugRenderer {
    private var traversal: DebugTraversal?

    func begin(
        route: SurfacePhaseRoute,
        cameraPosition: SIMD3<Float>,
        at time: CFTimeInterval,
        in arView: ARView
    ) {
        remove(from: arView)

        let towardCamera = cameraPosition - route.entryPosition
        let direction = simd_length(towardCamera) > 0.001
            ? simd_normalize(towardCamera)
            : SIMD3<Float>(0, 0, 1)
        let startPosition = route.entryPosition + direction * 0.42
        let anchor = AnchorEntity(world: startPosition)

        let outer = ModelEntity(
            mesh: .generateBox(size: 0.16, cornerRadius: 0.012),
            materials: [UnlitMaterial(color: UIColor(red: 0.08, green: 0.85, blue: 1, alpha: 0.28))]
        )
        let core = ModelEntity(
            mesh: .generateBox(size: 0.09, cornerRadius: 0.008),
            materials: [UnlitMaterial(color: UIColor(red: 0.72, green: 0.98, blue: 1, alpha: 1))]
        )
        anchor.addChild(outer)
        anchor.addChild(core)
        arView.scene.addAnchor(anchor)

        traversal = DebugTraversal(
            anchor: anchor,
            route: route,
            startPosition: startPosition,
            startedAt: time
        )
    }

    func update(at time: CFTimeInterval, in arView: ARView) -> Bool {
        guard let traversal else {
            return false
        }

        let elapsed = time - traversal.startedAt
        switch elapsed {
        case ..<1.2:
            let progress = smoothStep(Float(elapsed / 1.2))
            traversal.anchor.isEnabled = true
            traversal.anchor.position = simd_mix(
                traversal.startPosition,
                traversal.route.entryPosition,
                SIMD3<Float>(repeating: progress)
            )
            traversal.anchor.scale = SIMD3<Float>(repeating: 1 - progress * 0.82)

        case ..<2.0:
            traversal.anchor.isEnabled = false
            traversal.anchor.position = traversal.route.concealedExitPosition

        case ..<3.2:
            let progress = smoothStep(Float((elapsed - 2.0) / 1.2))
            traversal.anchor.isEnabled = true
            traversal.anchor.position = simd_mix(
                traversal.route.concealedExitPosition,
                traversal.route.emergedExitPosition,
                SIMD3<Float>(repeating: progress)
            )
            traversal.anchor.scale = SIMD3<Float>(repeating: 0.18 + progress * 0.82)

        case ..<4.0:
            traversal.anchor.isEnabled = true

        default:
            remove(from: arView)
            return true
        }

        let rotation = Float(elapsed) * 1.8
        traversal.anchor.orientation = simd_quatf(angle: rotation, axis: simd_normalize(SIMD3<Float>(1, 1, 0.35)))
        return false
    }

    func remove(from arView: ARView) {
        if let traversal {
            arView.scene.removeAnchor(traversal.anchor)
        }
        traversal = nil
    }

    private func smoothStep(_ value: Float) -> Float {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

private struct DebugTraversal {
    let anchor: AnchorEntity
    let route: SurfacePhaseRoute
    let startPosition: SIMD3<Float>
    let startedAt: CFTimeInterval
}
