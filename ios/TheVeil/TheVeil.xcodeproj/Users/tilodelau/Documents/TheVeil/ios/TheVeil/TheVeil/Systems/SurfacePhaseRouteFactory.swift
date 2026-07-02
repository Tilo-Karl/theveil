import ARKit
import simd

struct SurfacePhaseRouteFactory {
    enum SurfaceSelection {
        case anyPlane
        case classifiedWalls
    }

    private let maximumSurfaceDistance: Float = 3
    private let maximumEntrySurfaceDistance: Float = 2.5
    private let maximumExitDistance: Float = 3
    private let minimumSurfaceSeparation: Float = 0.35
    private let surfaceInset: Float = 0.025
    private let emergenceDistance: Float = 0.22
    private let minSurfaceExtent: Float = 0.2

    func makeRoute(
        from planeAnchors: [ARPlaneAnchor],
        targetPosition: SIMD3<Float>,
        cameraPosition: SIMD3<Float>,
        selection: SurfaceSelection = .anyPlane
    ) -> SurfacePhaseRoute? {
        let eligibleAnchors = filterEligiblePlanes(planeAnchors, for: selection)
        let surfaces = buildDetectedSurfaces(from: eligibleAnchors, camera: cameraPosition)
            .filter { simd_distance($0.position, cameraPosition) <= maximumSurfaceDistance }

        guard surfaces.count >= 2 else {
            return makeFallbackRoute(from: surfaces, target: targetPosition, camera: cameraPosition)
        }

        guard let entrySurface = selectEntrySurface(from: surfaces, target: targetPosition) else {
            return nil
        }

        guard let exitSurface = selectOptimalExitSurface(
            from: surfaces,
            avoiding: entrySurface,
            camera: cameraPosition
        ) else {
            return nil
        }

        return buildRoute(entry: entrySurface, exit: exitSurface)
    }

    private func filterEligiblePlanes(
        _ anchors: [ARPlaneAnchor],
        for selection: SurfaceSelection
    ) -> [ARPlaneAnchor] {
        anchors.filter { anchor in
            guard anchor.planeExtent.width >= minSurfaceExtent && anchor.planeExtent.height >= minSurfaceExtent else { return false }

            switch selection {
            case .anyPlane:
                return true
            case .classifiedWalls:
                if ARPlaneAnchor.isClassificationSupported {
                    return anchor.classification == .wall
                }
                return anchor.alignment == .vertical
            }
        }
    }

    private func buildDetectedSurfaces(
        from anchors: [ARPlaneAnchor],
        camera: SIMD3<Float>
    ) -> [DetectedSurface] {
        anchors.compactMap { makeSurface(from: $0, camera: camera) }
    }

    private func selectEntrySurface(
        from surfaces: [DetectedSurface],
        target: SIMD3<Float>
    ) -> DetectedSurface? {
        surfaces
            .filter { simd_distance($0.position, target) <= maximumEntrySurfaceDistance }
            .min { a, b in
                simd_distance(a.position, target) < simd_distance(b.position, target)
            }
    }

    private func selectOptimalExitSurface(
        from surfaces: [DetectedSurface],
        avoiding entry: DetectedSurface,
        camera: SIMD3<Float>
    ) -> DetectedSurface? {
        let candidates = surfaces.filter { candidate in
            candidate.id != entry.id
                && simd_distance(candidate.position, entry.position) >= minimumSurfaceSeparation
        }

        guard !candidates.isEmpty else { return nil }

        let emerged = entry.position + entry.normal * emergenceDistance
        return candidates
            .filter { candidate in
                simd_distance(
                    candidate.position + candidate.normal * emergenceDistance,
                    camera
                ) <= maximumExitDistance
            }
            .min { a, b in
                let distA = simd_distance(a.position, emerged)
                let distB = simd_distance(b.position, emerged)
                let visibilityA = calculateExitVisibility(a, from: camera)
                let visibilityB = calculateExitVisibility(b, from: camera)
                return (distA * (1 - visibilityA)) < (distB * (1 - visibilityB))
            }
    }

    private func makeFallbackRoute(
        from surfaces: [DetectedSurface],
        target: SIMD3<Float>,
        camera: SIMD3<Float>
    ) -> SurfacePhaseRoute? {
        guard let surface = surfaces.first else { return nil }

        let entryPosition = surface.position + surface.normal * surfaceInset
        let fallbackExitDirection = simd_normalize(camera - target)
        let concealedExit = target + fallbackExitDirection * 1.2
        let emergedExit = concealedExit + fallbackExitDirection * emergenceDistance

        return SurfacePhaseRoute(
            entryPosition: entryPosition,
            concealedExitPosition: concealedExit,
            emergedExitPosition: emergedExit
        )
    }

    private func calculateExitVisibility(_ surface: DetectedSurface, from camera: SIMD3<Float>) -> Float {
        let toCamera = camera - surface.position
        let distance = simd_length(toCamera)
        guard distance > 0.001 else { return 0 }

        let dot = simd_dot(simd_normalize(toCamera), surface.normal)
        return max(dot, 0)
    }

    private func buildRoute(
        entry: DetectedSurface,
        exit: DetectedSurface
    ) -> SurfacePhaseRoute {
        let entryPosition = entry.position + entry.normal * surfaceInset
        let concealedExitPosition = exit.position + exit.normal * surfaceInset
        let emergedExitPosition = concealedExitPosition + exit.normal * emergenceDistance

        return SurfacePhaseRoute(
            entryPosition: entryPosition,
            concealedExitPosition: concealedExitPosition,
            emergedExitPosition: emergedExitPosition
        )
    }

    private func makeSurface(
        from planeAnchor: ARPlaneAnchor,
        camera: SIMD3<Float>
    ) -> DetectedSurface? {
        let closestPoint = nearestPointOnPlane(planeAnchor, to: camera)
        var normal = planeNormal(planeAnchor)
        normal = ensureNormalPointsAwayFromCamera(normal, surface: closestPoint, camera: camera)

        return DetectedSurface(id: planeAnchor.identifier, position: closestPoint, normal: normal)
    }

    private func nearestPointOnPlane(
        _ anchor: ARPlaneAnchor,
        to camera: SIMD3<Float>
    ) -> SIMD3<Float> {
        let cameraLocal = anchor.transform.inverse * SIMD4<Float>(
            camera.x, camera.y, camera.z, 1
        )

        let halfWidth = anchor.planeExtent.width * 0.5
        let halfHeight = anchor.planeExtent.height * 0.5
        let clampedX = min(max(cameraLocal.x, anchor.center.x - halfWidth), anchor.center.x + halfWidth)
        let clampedZ = min(max(cameraLocal.z, anchor.center.z - halfHeight), anchor.center.z + halfHeight)

        let localPoint = SIMD4<Float>(clampedX, 0, clampedZ, 1)
        let worldPoint = anchor.transform * localPoint
        return SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
    }

    private func planeNormal(_ anchor: ARPlaneAnchor) -> SIMD3<Float> {
        simd_normalize(SIMD3<Float>(
            anchor.transform.columns.1.x,
            anchor.transform.columns.1.y,
            anchor.transform.columns.1.z
        ))
    }

    private func ensureNormalPointsAwayFromCamera(
        _ normal: SIMD3<Float>,
        surface: SIMD3<Float>,
        camera: SIMD3<Float>
    ) -> SIMD3<Float> {
        let toCamera = camera - surface
        return simd_dot(normal, toCamera) > 0 ? normal : -normal
    }


}

private struct DetectedSurface {
    let id: UUID
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
}
