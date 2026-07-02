import ARKit
import RealityKit
import UIKit

@MainActor
final class ARPlaneDebugRenderer {
    private var renderedPlanes: [UUID: RenderedDebugPlane] = [:]

    func update(with planeAnchors: [ARPlaneAnchor], isVisible: Bool, in arView: ARView) {
        guard isVisible else {
            removeAll(from: arView)
            return
        }

        let currentIDs = Set(planeAnchors.map(\.identifier))
        for id in renderedPlanes.keys where !currentIDs.contains(id) {
            if let renderedPlane = renderedPlanes.removeValue(forKey: id) {
                arView.scene.removeAnchor(renderedPlane.anchor)
            }
        }

        let fallbackFloorCandidateID: UUID?
        if ARPlaneAnchor.isClassificationSupported {
            fallbackFloorCandidateID = nil
        } else {
            fallbackFloorCandidateID = planeAnchors
                .filter { $0.alignment == .horizontal }
                .min { worldHeight(of: $0) < worldHeight(of: $1) }?
                .identifier
        }

        for planeAnchor in planeAnchors {
            guard let style = debugStyle(
                for: planeAnchor,
                fallbackFloorCandidateID: fallbackFloorCandidateID
            ) else {
                if let renderedPlane = renderedPlanes.removeValue(forKey: planeAnchor.identifier) {
                    arView.scene.removeAnchor(renderedPlane.anchor)
                }
                continue
            }
            update(planeAnchor, style: style, in: arView)
        }
    }

    func removeAll(from arView: ARView) {
        for renderedPlane in renderedPlanes.values {
            arView.scene.removeAnchor(renderedPlane.anchor)
        }
        renderedPlanes.removeAll()
    }

    private func update(
        _ planeAnchor: ARPlaneAnchor,
        style: DebugPlaneStyle,
        in arView: ARView
    ) {
        let width = max(planeAnchor.planeExtent.width, 0.01)
        let depth = max(planeAnchor.planeExtent.height, 0.01)
        let center = planeAnchor.center

        if let renderedPlane = renderedPlanes[planeAnchor.identifier] {
            renderedPlane.anchor.transform.matrix = planeAnchor.transform

            if
                abs(renderedPlane.width - width) > 0.01
                    || abs(renderedPlane.depth - depth) > 0.01
                    || simd_distance(renderedPlane.center, center) > 0.01
                    || renderedPlane.style != style
            {
                renderedPlane.width = width
                renderedPlane.depth = depth
                renderedPlane.center = center
                renderedPlane.style = style
                rebuildGeometry(for: renderedPlane)
            }
            return
        }

        let anchor = AnchorEntity(world: planeAnchor.transform)
        let root = Entity()
        anchor.addChild(root)
        arView.scene.addAnchor(anchor)

        let renderedPlane = RenderedDebugPlane(
            anchor: anchor,
            root: root,
            width: width,
            depth: depth,
            center: center,
            style: style
        )
        renderedPlanes[planeAnchor.identifier] = renderedPlane
        rebuildGeometry(for: renderedPlane)
    }

    private func rebuildGeometry(for renderedPlane: RenderedDebugPlane) {
        for child in renderedPlane.root.children {
            child.removeFromParent()
        }

        let color: UIColor
        let outlineColor: UIColor
        switch renderedPlane.style {
        case .floor:
            color = UIColor(white: 1, alpha: 0.24)
            outlineColor = UIColor(white: 1, alpha: 0.98)
        case .table:
            color = UIColor(red: 0.08, green: 0.34, blue: 1, alpha: 0.2)
            outlineColor = UIColor(red: 0.18, green: 0.55, blue: 1, alpha: 0.95)
        case .wall:
            color = UIColor(red: 0.08, green: 1, blue: 0.35, alpha: 0.2)
            outlineColor = UIColor(red: 0.18, green: 1, blue: 0.5, alpha: 0.95)
        case .ceiling:
            color = UIColor(red: 0.05, green: 0.82, blue: 1, alpha: 0.18)
            outlineColor = UIColor(red: 0.2, green: 0.9, blue: 1, alpha: 0.95)
        case .seat:
            color = UIColor(red: 0.66, green: 0.25, blue: 1, alpha: 0.2)
            outlineColor = UIColor(red: 0.78, green: 0.45, blue: 1, alpha: 0.95)
        case .opening:
            color = UIColor(red: 1, green: 0.72, blue: 0.08, alpha: 0.2)
            outlineColor = UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 0.98)
        case .fallbackHorizontal:
            color = UIColor(red: 0.08, green: 0.34, blue: 1, alpha: 0.14)
            outlineColor = UIColor(red: 0.18, green: 0.55, blue: 1, alpha: 0.72)
        case .fallbackVertical:
            color = UIColor(red: 0.08, green: 1, blue: 0.35, alpha: 0.14)
            outlineColor = UIColor(red: 0.18, green: 1, blue: 0.5, alpha: 0.72)
        }

        let fill = ModelEntity(
            mesh: .generatePlane(width: renderedPlane.width, depth: renderedPlane.depth),
            materials: [UnlitMaterial(color: color)]
        )
        fill.position = SIMD3<Float>(
            renderedPlane.center.x,
            renderedPlane.center.y,
            renderedPlane.center.z
        )
        renderedPlane.root.addChild(fill)

        let lineThickness: Float = 0.008
        let horizontalEdge = MeshResource.generateBox(
            width: renderedPlane.width,
            height: lineThickness,
            depth: lineThickness
        )
        let verticalEdge = MeshResource.generateBox(
            width: lineThickness,
            height: lineThickness,
            depth: renderedPlane.depth
        )
        let outlineMaterial = UnlitMaterial(color: outlineColor)
        let halfWidth = renderedPlane.width * 0.5
        let halfDepth = renderedPlane.depth * 0.5

        for z in [-halfDepth, halfDepth] {
            let edge = ModelEntity(mesh: horizontalEdge, materials: [outlineMaterial])
            edge.position = SIMD3<Float>(renderedPlane.center.x, renderedPlane.center.y, renderedPlane.center.z + z)
            renderedPlane.root.addChild(edge)
        }

        for x in [-halfWidth, halfWidth] {
            let edge = ModelEntity(mesh: verticalEdge, materials: [outlineMaterial])
            edge.position = SIMD3<Float>(renderedPlane.center.x + x, renderedPlane.center.y, renderedPlane.center.z)
            renderedPlane.root.addChild(edge)
        }
    }

    private func worldHeight(of planeAnchor: ARPlaneAnchor) -> Float {
        let localCenter = SIMD4<Float>(
            planeAnchor.center.x,
            0,
            planeAnchor.center.z,
            1
        )
        return (planeAnchor.transform * localCenter).y
    }

    private func debugStyle(
        for planeAnchor: ARPlaneAnchor,
        fallbackFloorCandidateID: UUID?
    ) -> DebugPlaneStyle? {
        guard ARPlaneAnchor.isClassificationSupported else {
            if planeAnchor.identifier == fallbackFloorCandidateID {
                return .floor
            }
            return planeAnchor.alignment == .horizontal
                ? .fallbackHorizontal
                : .fallbackVertical
        }

        switch planeAnchor.classification {
        case .floor:
            return .floor
        case .wall:
            return .wall
        case .ceiling:
            return .ceiling
        case .table:
            return .table
        case .seat:
            return .seat
        case .window, .door:
            return .opening
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }
}

private enum DebugPlaneStyle: Equatable {
    case floor
    case wall
    case ceiling
    case table
    case seat
    case opening
    case fallbackHorizontal
    case fallbackVertical
}

private final class RenderedDebugPlane {
    let anchor: AnchorEntity
    let root: Entity
    var width: Float
    var depth: Float
    var center: SIMD3<Float>
    var style: DebugPlaneStyle

    init(
        anchor: AnchorEntity,
        root: Entity,
        width: Float,
        depth: Float,
        center: SIMD3<Float>,
        style: DebugPlaneStyle
    ) {
        self.anchor = anchor
        self.root = root
        self.width = width
        self.depth = depth
        self.center = center
        self.style = style
    }
}
