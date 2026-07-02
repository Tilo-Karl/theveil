import ARKit
import simd

@MainActor
final class PlaneDetectionCache {
    private struct CachedPlane {
        let anchor: ARPlaneAnchor
        let detectedAt: CFTimeInterval
        let classification: PlaneClassification
    }

    private var cachedPlanes: [UUID: CachedPlane] = [:]
    private let minimumPlaneAge: CFTimeInterval = 0.4
    private let minimumPlaneExtent: Float = 0.2

    enum PlaneClassification {
        case floor
        case wall
        case ceiling
        case table
        case seat
        case opening
        case unknown
    }

    func update(with anchors: [ARPlaneAnchor], at time: CFTimeInterval) {
        let currentIDs = Set(anchors.map(\.identifier))

        for id in cachedPlanes.keys where !currentIDs.contains(id) {
            cachedPlanes.removeValue(forKey: id)
        }

        for anchor in anchors {
            let classification = classifyPlane(anchor)
            let isNewPlane = cachedPlanes[anchor.identifier] == nil

            if isNewPlane {
                cachedPlanes[anchor.identifier] = CachedPlane(
                    anchor: anchor,
                    detectedAt: time,
                    classification: classification
                )
            } else {
                cachedPlanes[anchor.identifier] = CachedPlane(
                    anchor: anchor,
                    detectedAt: cachedPlanes[anchor.identifier]?.detectedAt ?? time,
                    classification: classification
                )
            }
        }
    }

    func stablePlanes(at time: CFTimeInterval, minAge: CFTimeInterval? = nil) -> [ARPlaneAnchor] {
        let ageThreshold = minAge ?? minimumPlaneAge
        return cachedPlanes.values
            .filter { time - $0.detectedAt >= ageThreshold }
            .filter { $0.anchor.planeExtent.width >= minimumPlaneExtent && $0.anchor.planeExtent.height >= minimumPlaneExtent }
            .map(\.anchor)
    }

    func classifiedPlanes(
        at time: CFTimeInterval,
        matching classifications: [PlaneClassification]
    ) -> [ARPlaneAnchor] {
        let classificationSet = Set(classifications)
        return cachedPlanes.values
            .filter { time - $0.detectedAt >= minimumPlaneAge }
            .filter { classificationSet.contains($0.classification) }
            .filter { $0.anchor.planeExtent.width >= minimumPlaneExtent && $0.anchor.planeExtent.height >= minimumPlaneExtent }
            .map(\.anchor)
    }

    func confidence(for planeID: UUID) -> Float {
        guard let cached = cachedPlanes[planeID] else {
            return 0
        }
        let age = CACurrentMediaTime() - cached.detectedAt
        return min(Float(age / 2), 1)
    }

    private func classifyPlane(_ anchor: ARPlaneAnchor) -> PlaneClassification {
        guard ARPlaneAnchor.isClassificationSupported else {
            return anchor.alignment == .horizontal ? .floor : .wall
        }

        switch anchor.classification {
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
            return .unknown
        @unknown default:
            return .unknown
        }
    }


}
