import RealityKit
import UIKit

@MainActor
final class ARSceneEssenceRenderer {
    private var anchorsByEssenceID: [AmbientEssence.ID: AnchorEntity] = [:]

    func render(_ essences: [AmbientEssence], in arView: ARView) {
        removeAllEssence(from: arView)

        for essence in essences {
            let anchor = AnchorEntity(world: essence.position)
            let entity = makeEssenceEntity(for: essence)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)
            anchorsByEssenceID[essence.id] = anchor
        }
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

    func removeEssence(id: AmbientEssence.ID, from arView: ARView) {
        guard let anchor = anchorsByEssenceID.removeValue(forKey: id) else {
            return
        }

        arView.scene.removeAnchor(anchor)
    }

    private func removeAllEssence(from arView: ARView) {
        for anchor in anchorsByEssenceID.values {
            arView.scene.removeAnchor(anchor)
        }

        anchorsByEssenceID.removeAll()
    }

    private func makeEssenceEntity(for essence: AmbientEssence) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: essence.radius)
        let material = SimpleMaterial(color: color(for: essence.kind), roughness: 0.18, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = essence.id.uuidString
        entity.generateCollisionShapes(recursive: true)
        return entity
    }

    private func color(for kind: EssenceKind) -> UIColor {
        switch kind {
        case .wisp:
            return UIColor(red: 0.38, green: 0.88, blue: 1.00, alpha: 0.92)
        case .echo:
            return UIColor(red: 0.58, green: 0.72, blue: 1.00, alpha: 0.92)
        case .ember:
            return UIColor(red: 1.00, green: 0.55, blue: 0.30, alpha: 0.92)
        }
    }
}
