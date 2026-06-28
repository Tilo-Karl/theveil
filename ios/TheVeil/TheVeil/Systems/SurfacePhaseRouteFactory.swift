import ARKit
import simd

struct SurfacePhaseRouteFactory {
    private let maximumSurfaceDistance: Float = 3
    private let maximumEntrySurfaceDistance: Float = 2.5
    private let maximumExitDistance: Float = 3
    private let minimumSurfaceSeparation: Float = 0.35
    private let surfaceInset: Float = 0.025
    private let emergenceDistance: Float = 0.22

    func makeRoute(
        from planeAnchors: [ARPlaneAnchor],
        targetPosition: SIMD3<Float>,
        cameraPosition: SIMD3<Float>
    ) -> SurfacePhaseRoute? {
        let surfaces = planeAnchors.compactMap {
            makeSurface(from: $0, facing: cameraPosition)
        }
        .filter {
            simd_distance($0.position, cameraPosition) <= maximumSurfaceDistance
        }

        guard
            let entrySurface = surfaces
                .filter({
                    simd_distance($0.position, targetPosition) <= maximumEntrySurfaceDistance
                })
                .min(by: {
                    simd_distance($0.position, targetPosition) < simd_distance($1.position, targetPosition)
                }),
            let exitSurface = surfaces
                .filter({
                    $0.id != entrySurface.id
                        && simd_distance($0.position, entrySurface.position) >= minimumSurfaceSeparation
                        && simd_distance(
                            $0.position + $0.normal * emergenceDistance,
                            cameraPosition
                        ) <= maximumExitDistance
                })
                .randomElement()
        else {
            return nil
        }

        let entryPosition = entrySurface.position + entrySurface.normal * surfaceInset
        let concealedExitPosition = exitSurface.position + exitSurface.normal * surfaceInset

        return SurfacePhaseRoute(
            entryPosition: entryPosition,
            concealedExitPosition: concealedExitPosition,
            emergedExitPosition: concealedExitPosition + exitSurface.normal * emergenceDistance
        )
    }

    private func makeSurface(
        from planeAnchor: ARPlaneAnchor,
        facing cameraPosition: SIMD3<Float>
    ) -> DetectedSurface? {
        let planeExtent = planeAnchor.planeExtent

        guard planeExtent.width >= 0.2, planeExtent.height >= 0.2 else {
            return nil
        }

        let cameraLocalPosition = planeAnchor.transform.inverse * SIMD4<Float>(
            cameraPosition.x,
            cameraPosition.y,
            cameraPosition.z,
            1
        )
        let halfWidth = planeExtent.width * 0.5
        let halfHeight = planeExtent.height * 0.5
        let localPosition = SIMD4<Float>(
            min(max(cameraLocalPosition.x, planeAnchor.center.x - halfWidth), planeAnchor.center.x + halfWidth),
            0,
            min(max(cameraLocalPosition.z, planeAnchor.center.z - halfHeight), planeAnchor.center.z + halfHeight),
            1
        )
        let worldPosition = planeAnchor.transform * localPosition
        let position = SIMD3<Float>(worldPosition.x, worldPosition.y, worldPosition.z)
        var normal = simd_normalize(SIMD3<Float>(
            planeAnchor.transform.columns.1.x,
            planeAnchor.transform.columns.1.y,
            planeAnchor.transform.columns.1.z
        ))

        if simd_dot(normal, cameraPosition - position) < 0 {
            normal *= -1
        }

        return DetectedSurface(id: planeAnchor.identifier, position: position, normal: normal)
    }
}

private struct DetectedSurface {
    let id: UUID
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
}
