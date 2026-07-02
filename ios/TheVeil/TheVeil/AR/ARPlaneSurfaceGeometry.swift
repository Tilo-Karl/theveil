import ARKit
import simd

struct ARPlaneSurfaceHit {
    let planeID: UUID
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let progress: Float
}

struct ARPlaneSurfaceLocation {
    let planeID: UUID
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
}

enum ARPlaneSurfaceGeometry {
    static func firstHit(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        velocity: SIMD3<Float>,
        planeAnchors: [ARPlaneAnchor],
        ignoring ignoredPlaneID: UUID? = nil,
        margin: Float = 0.045
    ) -> ARPlaneSurfaceHit? {
        planeAnchors
            .filter { $0.identifier != ignoredPlaneID }
            .compactMap {
                planeHit(
                    from: start,
                    to: end,
                    velocity: velocity,
                    planeAnchor: $0,
                    margin: margin
                )
            }
            .min { $0.progress < $1.progress }
    }

    static func nearestExit(
        excluding entryPlaneID: UUID,
        from planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>,
        maximumDistance: Float = 3,
        isVisible: (SIMD3<Float>) -> Bool = { _ in true }
    ) -> ARPlaneSurfaceLocation? {
        planeAnchors
            .filter { $0.identifier != entryPlaneID }
            .compactMap {
                location(
                    on: $0,
                    nearestTo: cameraPosition,
                    normalFacing: cameraPosition
                )
            }
            .filter {
                simd_distance($0.position, cameraPosition) <= maximumDistance
                    && isVisible($0.position)
            }
            .min {
                simd_distance($0.position, cameraPosition)
                    < simd_distance($1.position, cameraPosition)
            }
    }

    static func location(
        on planeAnchor: ARPlaneAnchor,
        nearestTo point: SIMD3<Float>,
        normalFacing facingPosition: SIMD3<Float>
    ) -> ARPlaneSurfaceLocation {
        let position = nearestPoint(on: planeAnchor, to: point)
        var normal = planeNormal(planeAnchor)
        if simd_dot(normal, facingPosition - position) < 0 {
            normal *= -1
        }
        return ARPlaneSurfaceLocation(
            planeID: planeAnchor.identifier,
            position: position,
            normal: normal
        )
    }

    static func nearestPoint(
        on planeAnchor: ARPlaneAnchor,
        to point: SIMD3<Float>
    ) -> SIMD3<Float> {
        let pointLocal4 = planeAnchor.transform.inverse * SIMD4<Float>(
            point.x,
            point.y,
            point.z,
            1
        )
        let pointLocal = SIMD3<Float>(pointLocal4.x, 0, pointLocal4.z)
        let extent = planeAnchor.planeExtent
        let extentRotation = simd_quatf(
            angle: extent.rotationOnYAxis,
            axis: SIMD3<Float>(0, 1, 0)
        )
        let extentSpacePoint = extentRotation.inverse.act(pointLocal - planeAnchor.center)
        let clampedExtentPoint = SIMD3<Float>(
            min(max(extentSpacePoint.x, -extent.width * 0.5), extent.width * 0.5),
            0,
            min(max(extentSpacePoint.z, -extent.height * 0.5), extent.height * 0.5)
        )
        let anchorLocalPoint = planeAnchor.center + extentRotation.act(clampedExtentPoint)
        let worldPoint = planeAnchor.transform * SIMD4<Float>(
            anchorLocalPoint.x,
            anchorLocalPoint.y,
            anchorLocalPoint.z,
            1
        )
        return SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
    }

    static func planeNormal(_ planeAnchor: ARPlaneAnchor) -> SIMD3<Float> {
        simd_normalize(SIMD3<Float>(
            planeAnchor.transform.columns.1.x,
            planeAnchor.transform.columns.1.y,
            planeAnchor.transform.columns.1.z
        ))
    }

    private static func planeHit(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        velocity: SIMD3<Float>,
        planeAnchor: ARPlaneAnchor,
        margin: Float
    ) -> ARPlaneSurfaceHit? {
        let inverseTransform = planeAnchor.transform.inverse
        let localStart4 = inverseTransform * SIMD4<Float>(start.x, start.y, start.z, 1)
        let localEnd4 = inverseTransform * SIMD4<Float>(end.x, end.y, end.z, 1)
        let startDistance = localStart4.y
        let endDistance = localEnd4.y

        guard startDistance * endDistance <= 0, abs(startDistance - endDistance) > 0.0001 else {
            return nil
        }

        let progress = startDistance / (startDistance - endDistance)
        guard progress >= 0, progress <= 1 else {
            return nil
        }

        let localIntersection = SIMD3<Float>(
            localStart4.x + (localEnd4.x - localStart4.x) * progress,
            0,
            localStart4.z + (localEnd4.z - localStart4.z) * progress
        )
        guard contains(localIntersection, in: planeAnchor, margin: margin) else {
            return nil
        }

        let world4 = planeAnchor.transform * SIMD4<Float>(
            localIntersection.x,
            localIntersection.y,
            localIntersection.z,
            1
        )
        var normal = planeNormal(planeAnchor)
        if simd_dot(velocity, normal) > 0 {
            normal *= -1
        }

        return ARPlaneSurfaceHit(
            planeID: planeAnchor.identifier,
            position: SIMD3<Float>(world4.x, world4.y, world4.z),
            normal: normal,
            progress: progress
        )
    }

    private static func contains(
        _ localPoint: SIMD3<Float>,
        in planeAnchor: ARPlaneAnchor,
        margin: Float
    ) -> Bool {
        let extent = planeAnchor.planeExtent
        let relativeToCenter = localPoint - planeAnchor.center
        let inverseExtentRotation = simd_quatf(
            angle: -extent.rotationOnYAxis,
            axis: SIMD3<Float>(0, 1, 0)
        )
        let extentSpacePoint = inverseExtentRotation.act(relativeToCenter)
        return abs(extentSpacePoint.x) <= extent.width * 0.5 + margin
            && abs(extentSpacePoint.z) <= extent.height * 0.5 + margin
    }
}
