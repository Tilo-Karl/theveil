import ARKit
import RealityKit
import simd
import UIKit

@MainActor
final class ARSurfaceTraversalDebugRenderer {
    private let speed = SurfaceTraversalMotion.speed
    private let meltDuration: CFTimeInterval = 1
    private let concealedDuration: CFTimeInterval = 2
    private var cube: PhaseCube?

    func startIfNeeded(
        cameraTransform: Transform,
        at time: CFTimeInterval,
        in arView: ARView
    ) {
        guard cube == nil else {
            return
        }

        let forward = cameraTransform.forwardVector
        let right = cameraTransform.rightVector
        let up = SIMD3<Float>(0, 1, 0)
        let position = cameraTransform.translation + forward * 1.05 + up * 0.08
        let velocity = simd_normalize(forward * 0.58 + right * 0.7 + up * 0.28) * speed
        let anchor = AnchorEntity(world: position)
        let visual = makeCubeVisual()
        anchor.addChild(visual)
        arView.scene.addAnchor(anchor)

        cube = PhaseCube(
            anchor: anchor,
            visual: visual,
            velocity: velocity,
            lastUpdatedAt: time,
            state: .moving,
            collisionCooldownUntil: time + 0.6
        )
    }

    func update(
        at time: CFTimeInterval,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) -> String {
        guard let cube else {
            return "STARTING"
        }

        let deltaTime = min(max(time - cube.lastUpdatedAt, 0), 1.0 / 20.0)
        cube.lastUpdatedAt = time

        switch cube.state {
        case .moving:
            return updateMovement(
                cube,
                deltaTime: Float(deltaTime),
                time: time,
                planeAnchors: planeAnchors,
                cameraPosition: cameraPosition,
                in: arView
            )

        case .meltingIn(let transition):
            let progress = smoothStep(Float((time - transition.startedAt) / meltDuration))
            applyMeltIn(cube, transition: transition, progress: progress)

            if progress >= 1 {
                cube.anchor.isEnabled = false
                cube.state = .concealed(startedAt: time, exit: transition.exit)
            }
            return "MELTING IN"

        case .concealed(let startedAt, let exit):
            let remaining = max(0, concealedDuration - (time - startedAt))
            if remaining <= 0 {
                beginEmergence(cube, from: exit, at: time)
                return "MELTING OUT"
            }
            return String(format: "CONCEALED %.1fs", remaining)

        case .meltingOut(let transition):
            let progress = smoothStep(Float((time - transition.startedAt) / meltDuration))
            applyMeltOut(cube, transition: transition, progress: progress)

            if progress >= 1 {
                cube.anchor.position = transition.endPosition
                cube.anchor.scale = SIMD3<Float>(repeating: 1)
                cube.visual.components.set(OpacityComponent(opacity: 1))
                cube.velocity = emergenceVelocity(
                    normal: transition.surfaceNormal,
                    cameraPosition: cameraPosition,
                    origin: transition.endPosition
                )
                cube.state = .moving
                cube.collisionCooldownUntil = time + 0.8
                cube.ignoredPlaneID = transition.planeID
            }
            return "MELTING OUT"
        }
    }

    func remove(from arView: ARView) {
        if let cube {
            arView.scene.removeAnchor(cube.anchor)
        }
        cube = nil
    }

    private func updateMovement(
        _ cube: PhaseCube,
        deltaTime: Float,
        time: CFTimeInterval,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) -> String {
        let startPosition = cube.anchor.position
        var nextPosition = startPosition + cube.velocity * deltaTime
        keepCubeNearCamera(
            cube,
            proposedPosition: &nextPosition,
            cameraPosition: cameraPosition
        )

        if time >= cube.collisionCooldownUntil,
           let hit = ARPlaneSurfaceGeometry.firstHit(
                from: startPosition,
                to: nextPosition,
                velocity: cube.velocity,
                planeAnchors: planeAnchors,
                ignoring: cube.ignoredPlaneID
           )
        {
            guard let exit = ARPlaneSurfaceGeometry.nearestExit(
                excluding: hit.planeID,
                from: planeAnchors,
                cameraPosition: cameraPosition,
                isVisible: { worldPosition in
                    guard let screenPosition = arView.project(worldPosition) else {
                        return false
                    }
                    return arView.bounds
                        .insetBy(dx: 30, dy: 60)
                        .contains(screenPosition)
                }
            ) else {
                cube.velocity -= hit.normal * (2 * simd_dot(cube.velocity, hit.normal))
                cube.velocity = simd_normalize(cube.velocity) * speed
                cube.anchor.position = hit.position + hit.normal * 0.1
                cube.collisionCooldownUntil = time + 0.35
                cube.ignoredPlaneID = hit.planeID
                return "BOUNCING / NEED EXIT"
            }

            let planeOrientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: hit.normal
            )
            cube.state = .meltingIn(
                MeltInTransition(
                    startedAt: time,
                    startPosition: startPosition,
                    endPosition: hit.position - hit.normal * 0.075,
                    startOrientation: cube.anchor.orientation,
                    planeOrientation: planeOrientation,
                    exit: exit
                )
            )
            cube.ignoredPlaneID = hit.planeID
            return "MELTING IN"
        }

        cube.anchor.position = nextPosition
        cube.anchor.orientation = simd_quatf(
            angle: deltaTime * 1.9,
            axis: simd_normalize(SIMD3<Float>(0.7, 1, 0.4))
        ) * cube.anchor.orientation

        if time >= cube.collisionCooldownUntil {
            cube.ignoredPlaneID = nil
        }
        return "BOUNCING / \(planeAnchors.count) SURFACES"
    }

    private func applyMeltIn(
        _ cube: PhaseCube,
        transition: MeltInTransition,
        progress: Float
    ) {
        cube.anchor.isEnabled = true
        cube.anchor.position = mix(
            transition.startPosition,
            transition.endPosition,
            progress
        )
        cube.anchor.orientation = simd_slerp(
            transition.startOrientation,
            transition.planeOrientation,
            progress
        )
        cube.anchor.scale = SIMD3<Float>(
            1 + progress * 0.42,
            max(0.025, 1 - progress * 0.975),
            1 + progress * 0.42
        )
        cube.visual.components.set(
            OpacityComponent(opacity: max(0.03, 1 - progress * 0.97))
        )
    }

    private func beginEmergence(
        _ cube: PhaseCube,
        from exit: ARPlaneSurfaceLocation,
        at time: CFTimeInterval
    ) {
        let planeOrientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: exit.normal
        )
        let startPosition = exit.position - exit.normal * 0.075
        let endPosition = exit.position + exit.normal * 0.28

        cube.anchor.isEnabled = true
        cube.anchor.position = startPosition
        cube.anchor.orientation = planeOrientation
        cube.anchor.scale = SIMD3<Float>(1.42, 0.025, 1.42)
        cube.visual.components.set(OpacityComponent(opacity: 0.03))
        cube.state = .meltingOut(
            MeltOutTransition(
                startedAt: time,
                startPosition: startPosition,
                endPosition: endPosition,
                planeOrientation: planeOrientation,
                surfaceNormal: exit.normal,
                planeID: exit.planeID
            )
        )
    }

    private func applyMeltOut(
        _ cube: PhaseCube,
        transition: MeltOutTransition,
        progress: Float
    ) {
        cube.anchor.position = mix(
            transition.startPosition,
            transition.endPosition,
            progress
        )
        cube.anchor.orientation = transition.planeOrientation
        cube.anchor.scale = SIMD3<Float>(
            1.42 - progress * 0.42,
            0.025 + progress * 0.975,
            1.42 - progress * 0.42
        )
        cube.visual.components.set(
            OpacityComponent(opacity: 0.03 + progress * 0.97)
        )
    }

    private func keepCubeNearCamera(
        _ cube: PhaseCube,
        proposedPosition: inout SIMD3<Float>,
        cameraPosition: SIMD3<Float>
    ) {
        let offset = proposedPosition - cameraPosition
        if simd_length(offset) > 2.4 {
            cube.velocity = simd_normalize(cameraPosition - proposedPosition) * speed
            proposedPosition = cube.anchor.position + cube.velocity * (1.0 / 30.0)
        }

        if offset.y > 1.4 {
            cube.velocity.y = -abs(cube.velocity.y)
        } else if offset.y < -1.25 {
            cube.velocity.y = abs(cube.velocity.y)
        }
        cube.velocity = simd_normalize(cube.velocity) * speed
    }

    private func emergenceVelocity(
        normal: SIMD3<Float>,
        cameraPosition: SIMD3<Float>,
        origin: SIMD3<Float>
    ) -> SIMD3<Float> {
        let towardCamera = simd_normalize(cameraPosition - origin)
        let tangent = simd_cross(normal, SIMD3<Float>(0, 1, 0))
        let safeTangent = simd_length(tangent) > 0.01
            ? simd_normalize(tangent)
            : SIMD3<Float>(1, 0, 0)
        return simd_normalize(normal * 0.65 + towardCamera * 0.45 + safeTangent * 0.38) * speed
    }

    private func makeCubeVisual() -> Entity {
        let root = Entity()
        let outer = ModelEntity(
            mesh: .generateBox(size: 0.17, cornerRadius: 0.014),
            materials: [UnlitMaterial(color: UIColor(red: 0.05, green: 0.82, blue: 1, alpha: 0.28))]
        )
        let core = ModelEntity(
            mesh: .generateBox(size: 0.095, cornerRadius: 0.009),
            materials: [UnlitMaterial(color: UIColor(red: 0.72, green: 0.98, blue: 1, alpha: 1))]
        )
        root.addChild(outer)
        root.addChild(core)
        root.components.set(OpacityComponent(opacity: 1))
        return root
    }

    private func mix(_ start: SIMD3<Float>, _ end: SIMD3<Float>, _ progress: Float) -> SIMD3<Float> {
        start + (end - start) * min(max(progress, 0), 1)
    }

    private func smoothStep(_ value: Float) -> Float {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

private final class PhaseCube {
    let anchor: AnchorEntity
    let visual: Entity
    var velocity: SIMD3<Float>
    var lastUpdatedAt: CFTimeInterval
    var state: PhaseCubeState
    var collisionCooldownUntil: CFTimeInterval
    var ignoredPlaneID: UUID?

    init(
        anchor: AnchorEntity,
        visual: Entity,
        velocity: SIMD3<Float>,
        lastUpdatedAt: CFTimeInterval,
        state: PhaseCubeState,
        collisionCooldownUntil: CFTimeInterval
    ) {
        self.anchor = anchor
        self.visual = visual
        self.velocity = velocity
        self.lastUpdatedAt = lastUpdatedAt
        self.state = state
        self.collisionCooldownUntil = collisionCooldownUntil
    }
}

private enum PhaseCubeState {
    case moving
    case meltingIn(MeltInTransition)
    case concealed(startedAt: CFTimeInterval, exit: ARPlaneSurfaceLocation)
    case meltingOut(MeltOutTransition)
}

private struct MeltInTransition {
    let startedAt: CFTimeInterval
    let startPosition: SIMD3<Float>
    let endPosition: SIMD3<Float>
    let startOrientation: simd_quatf
    let planeOrientation: simd_quatf
    let exit: ARPlaneSurfaceLocation
}

private struct MeltOutTransition {
    let startedAt: CFTimeInterval
    let startPosition: SIMD3<Float>
    let endPosition: SIMD3<Float>
    let planeOrientation: simd_quatf
    let surfaceNormal: SIMD3<Float>
    let planeID: UUID
}

private extension Transform {
    var forwardVector: SIMD3<Float> {
        -SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
    }

    var rightVector: SIMD3<Float> {
        SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
    }
}
