import ARKit
import RealityKit
import simd
import UIKit

@MainActor
final class ARSceneEctoRenderer {
    private let materialFactory = EctoMaterialFactory()
    private let blobRadius: Float = 0.155
    private let outerShellRestScale = SIMD3<Float>(0.90, 1.18, 0.84)
    private let innerGelScaleRatio: Float = 0.965
    private let jumpPreparationDuration: CFTimeInterval = 0.34
    private let jumpDuration: CFTimeInterval = 0.82
    private let landingDuration: CFTimeInterval = 0.36
    private var renderedEcto: RenderedEcto?

    func spawn(
        variant: EctoVariant,
        planeAnchors: [ARPlaneAnchor],
        cameraTransform: Transform,
        at time: CFTimeInterval,
        in arView: ARView
    ) -> Ecto? {
        guard
            let surface = landingSurface(
                near: cameraTransform.translation + cameraTransform.forwardVector * 1.05,
                planeAnchors: planeAnchors,
                cameraPosition: cameraTransform.translation,
                in: arView
            )
        else {
            return nil
        }

        remove(from: arView)

        let ecto = Ecto(
            position: surface.position + surface.normal * blobRadius,
            variant: variant,
            essenceValue: 1,
            radius: blobRadius
        )
        let anchor = AnchorEntity(world: ecto.position)
        let visual = makeEctoVisual(ecto)
        anchor.addChild(visual.root)
        anchor.addChild(visual.contactShadow)
        arView.scene.addAnchor(anchor)

        renderedEcto = RenderedEcto(
            id: ecto.id,
            anchor: anchor,
            root: visual.root,
            outerShell: visual.outerShell,
            innerGel: visual.innerGel,
            jellyLobes: visual.jellyLobes,
            bubbles: visual.bubbles,
            core: visual.core,
            coreHalo: visual.coreHalo,
            eyes: visual.eyes,
            mouth: visual.mouth,
            contactShadow: visual.contactShadow,
            dropletLayer: visual.dropletLayer,
            variant: variant,
            lastUpdatedAt: time,
            stateStartedAt: time,
            nextJumpAt: time + Double.random(in: 2.1...3.8),
            currentPosition: ecto.position,
            targetPosition: ecto.position,
            motionPhase: Float.random(in: 0...(Float.pi * 2))
        )
        return ecto
    }

    func update(
        at time: CFTimeInterval,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) -> String {
        guard let ecto = renderedEcto else {
            return "ECTO READY"
        }

        ecto.lastUpdatedAt = time

        switch ecto.state {
        case .idle:
            updateIdle(
                ecto,
                at: time,
                planeAnchors: planeAnchors,
                cameraPosition: cameraPosition,
                in: arView
            )

        case .preparingToJump:
            updatePreparingToJump(ecto, at: time)

        case .airborne:
            updateAirborne(ecto, at: time)

        case .landing:
            updateLanding(ecto, at: time)

        case .startled:
            updateIdle(
                ecto,
                at: time,
                planeAnchors: planeAnchors,
                cameraPosition: cameraPosition,
                in: arView
            )

        case .captured:
            break
        }

        orientEcto(ecto, toward: cameraPosition)
        updateVisuals(ecto, at: time)

        return statusText(for: ecto.state)
    }

    func remove(from arView: ARView) {
        if let renderedEcto {
            arView.scene.removeAnchor(renderedEcto.anchor)
        }
        renderedEcto = nil
    }

    func worldPosition(for id: Ecto.ID) -> SIMD3<Float>? {
        guard renderedEcto?.id == id else {
            return nil
        }
        return renderedEcto?.anchor.position
    }

    func isCapturable(id: Ecto.ID) -> Bool {
        guard let renderedEcto, renderedEcto.id == id else {
            return false
        }
        return renderedEcto.state != .captured
    }

    func ectoID(for entity: Entity?) -> Ecto.ID? {
        var cursor = entity
        while let current = cursor {
            if let renderedEcto, current == renderedEcto.root || current == renderedEcto.anchor {
                return renderedEcto.id
            }
            if let idString = current.name.split(separator: ":").last,
               let id = UUID(uuidString: String(idString)) {
                return id
            }
            cursor = current.parent
        }
        return nil
    }

    func collectEcto(id: Ecto.ID, from arView: ARView) {
        guard let ecto = renderedEcto, ecto.id == id else {
            return
        }

        ecto.state = .captured
        ecto.root.components.set(OpacityComponent(opacity: 0))

        let collectionPoint = arView.cameraTransform.translation
            + arView.cameraTransform.forwardVector * 0.22
        var transform = ecto.anchor.transform
        transform.translation = collectionPoint
        transform.scale = SIMD3<Float>(repeating: 0.05)
        ecto.anchor.move(
            to: transform,
            relativeTo: nil,
            duration: 0.42,
            timingFunction: .easeIn
        )

        Task { @MainActor [weak self, weak arView] in
            do {
                try await Task.sleep(for: .milliseconds(460))
            } catch {
                return
            }
            guard let arView else { return }
            self?.remove(from: arView)
        }
    }

    private func updateIdle(
        _ ecto: RenderedEcto,
        at time: CFTimeInterval,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) {
        guard time >= ecto.nextJumpAt else {
            return
        }

        guard
            let target = nextJumpSurface(
                from: ecto.currentPosition,
                planeAnchors: planeAnchors,
                cameraPosition: cameraPosition,
                in: arView
            )
        else {
            ecto.nextJumpAt = time + Double.random(in: 1.3...2.4)
            return
        }

        ecto.jumpStartPosition = ecto.currentPosition
        ecto.targetPosition = target.position + target.normal * blobRadius
        ecto.state = .preparingToJump
        ecto.stateStartedAt = time
    }

    private func updatePreparingToJump(
        _ ecto: RenderedEcto,
        at time: CFTimeInterval
    ) {
        guard time - ecto.stateStartedAt >= jumpPreparationDuration else {
            return
        }

        ecto.state = .airborne
        ecto.stateStartedAt = time
    }

    private func updateAirborne(
        _ ecto: RenderedEcto,
        at time: CFTimeInterval
    ) {
        let progress = smoothStep(Float((time - ecto.stateStartedAt) / jumpDuration))
        let arc = sin(progress * .pi) * 0.34
        ecto.currentPosition = mix(
            ecto.jumpStartPosition,
            ecto.targetPosition,
            progress
        ) + SIMD3<Float>(0, arc, 0)
        ecto.anchor.position = ecto.currentPosition

        guard progress >= 1 else {
            return
        }

        ecto.currentPosition = ecto.targetPosition
        ecto.anchor.position = ecto.targetPosition
        ecto.state = .landing
        ecto.stateStartedAt = time
    }

    private func updateLanding(
        _ ecto: RenderedEcto,
        at time: CFTimeInterval
    ) {
        let progress = smoothStep(Float((time - ecto.stateStartedAt) / landingDuration))
        guard progress >= 1 else {
            return
        }

        ecto.state = .idle
        ecto.stateStartedAt = time
        ecto.nextJumpAt = time + Double.random(in: 2.0...4.2)
    }

    private func updateVisuals(_ ecto: RenderedEcto, at time: CFTimeInterval) {
        let elapsed = Float(time - ecto.stateStartedAt)
        let breathing = sin(Float(time) * 2.3 + ecto.motionPhase) * 0.045
        let wobble = sin(Float(time) * 4.7 + ecto.motionPhase * 0.7) * 0.032
        let reactivity: Float

        switch ecto.state {
        case .idle, .startled:
            ecto.root.scale = SIMD3<Float>(
                0.92 + breathing * 0.10,
                1.18 + breathing * 0.10,
                0.88 + wobble * 0.08
            )
            reactivity = 0.08

        case .preparingToJump:
            let progress = smoothStep(Float(elapsed / Float(jumpPreparationDuration)))
            ecto.root.scale = SIMD3<Float>(
                1.04 + progress * 0.22,
                1.10 - progress * 0.22,
                0.94 + progress * 0.12
            )
            reactivity = 0.45 + progress * 0.35

        case .airborne:
            let progress = smoothStep(Float(elapsed / Float(jumpDuration)))
            let taper = sin(progress * .pi)
            ecto.root.scale = SIMD3<Float>(
                0.82 - taper * 0.08,
                1.32 + taper * 0.36,
                0.78 - taper * 0.06
            )
            reactivity = 0.28

        case .landing:
            let progress = smoothStep(Float(elapsed / Float(landingDuration)))
            let squash = max(0, 1 - progress)
            ecto.root.scale = SIMD3<Float>(
                1.08 + squash * 0.36,
                1.02 - squash * 0.30,
                0.96 + squash * 0.20
            )
            reactivity = 0.85 * squash

        case .captured:
            reactivity = 1
        }

        let shellWobble = sin(Float(time) * 1.18 + ecto.motionPhase) * 0.010
        let shellSideFlow = cos(Float(time) * 0.86 + ecto.motionPhase * 0.6) * 0.006
        ecto.outerShell.scale = SIMD3<Float>(
            outerShellRestScale.x + shellWobble,
            outerShellRestScale.y - shellWobble * 0.58,
            outerShellRestScale.z + shellSideFlow
        )
        ecto.outerShell.position = .zero

        let innerPhase = ecto.motionPhase + 1.35
        let innerWobble = sin(Float(time) * 1.02 + innerPhase) * 0.0055
        let innerSideFlow = cos(Float(time) * 0.72 + innerPhase) * 0.0038
        let innerBaseScale = outerShellRestScale * innerGelScaleRatio
        ecto.innerGel.scale = SIMD3<Float>(
            innerBaseScale.x + innerWobble,
            innerBaseScale.y - innerWobble * 0.45,
            innerBaseScale.z + innerSideFlow
        )
        ecto.innerGel.position = SIMD3<Float>(
            sin(Float(time) * 0.64 + innerPhase) * 0.0022,
            cos(Float(time) * 0.58 + innerPhase) * 0.0018,
            0
        )

        if let material = materialFactory.makeOuterShellMaterial(
            variant: ecto.variant,
            phase: Float(time) + ecto.motionPhase,
            visibility: 0.88,
            reactivity: reactivity
        ) {
            ecto.outerShell.model?.materials = [material]
        } else {
            ecto.outerShell.model?.materials = [
                materialFactory.makeOuterShellFallbackMaterial(variant: ecto.variant, alpha: 0.24)
            ]
        }

        if let material = materialFactory.makeInnerGelMaterial(
            variant: ecto.variant,
            phase: Float(time) * 0.82 + innerPhase,
            visibility: 0.92,
            reactivity: reactivity * 0.66
        ) {
            ecto.innerGel.model?.materials = [material]
        } else {
            ecto.innerGel.model?.materials = [
                materialFactory.makeInnerGelFallbackMaterial(variant: ecto.variant, alpha: 0.48)
            ]
        }

        let lobeBases = [
            SIMD3<Float>(-0.118, -0.034, 0.044),
            SIMD3<Float>(0.118, -0.036, 0.044),
            SIMD3<Float>(0.000, -0.126, 0.070),
            SIMD3<Float>(0.000, -0.120, -0.020),
            SIMD3<Float>(-0.046, 0.152, 0.040),
            SIMD3<Float>(-0.050, -0.004, 0.092),
            SIMD3<Float>(0.050, -0.006, 0.092)
        ]
        let lobeScales = [
            SIMD3<Float>(0.48, 0.52, 0.34),
            SIMD3<Float>(0.48, 0.50, 0.34),
            SIMD3<Float>(0.78, 0.22, 0.44),
            SIMD3<Float>(0.62, 0.18, 0.30),
            SIMD3<Float>(0.26, 0.46, 0.20),
            SIMD3<Float>(0.30, 0.34, 0.24),
            SIMD3<Float>(0.30, 0.34, 0.24)
        ]
        for (index, lobe) in ecto.jellyLobes.enumerated() {
            let localPhase = ecto.motionPhase + Float(index) * 1.29
            let pulse = sin(Float(time) * (2.0 + Float(index) * 0.16) + localPhase)
            let slide = cos(Float(time) * (1.1 + Float(index) * 0.11) - localPhase)
            let base = lobeBases[index % lobeBases.count]
            let scale = lobeScales[index % lobeScales.count]
            lobe.position = base + SIMD3<Float>(
                pulse * 0.004,
                slide * 0.004,
                pulse * 0.003
            )
            lobe.scale = SIMD3<Float>(
                scale.x + pulse * 0.030 + reactivity * 0.030,
                scale.y - pulse * 0.026 + reactivity * 0.020,
                scale.z + slide * 0.020
            )
            if let material = materialFactory.makeInnerGelMaterial(
                variant: ecto.variant,
                phase: Float(time) * (0.72 + Float(index) * 0.05) + localPhase + 2.2,
                visibility: 0.42,
                reactivity: 0.10 + reactivity * 0.48
            ) {
                lobe.model?.materials = [material]
            } else {
                lobe.model?.materials = [
                    materialFactory.makeInnerGelFallbackMaterial(
                        variant: ecto.variant,
                        alpha: 0.30
                    )
                ]
            }
        }

        let bubbleBases = [
            SIMD3<Float>(-0.078, 0.104, 0.026),
            SIMD3<Float>(0.080, 0.088, -0.018),
            SIMD3<Float>(-0.024, 0.020, 0.068),
            SIMD3<Float>(0.046, -0.044, 0.026),
            SIMD3<Float>(-0.094, -0.070, -0.006),
            SIMD3<Float>(0.092, -0.096, 0.044),
            SIMD3<Float>(0.010, -0.150, 0.078),
            SIMD3<Float>(-0.010, -0.024, -0.072),
            SIMD3<Float>(0.108, 0.012, -0.044),
            SIMD3<Float>(-0.110, 0.012, 0.042)
        ]
        let bubbleScales = [
            SIMD3<Float>(0.70, 0.54, 0.62),
            SIMD3<Float>(0.48, 0.64, 0.46),
            SIMD3<Float>(0.44, 0.42, 0.58),
            SIMD3<Float>(0.56, 0.46, 0.50),
            SIMD3<Float>(0.38, 0.54, 0.42),
            SIMD3<Float>(0.62, 0.48, 0.58),
            SIMD3<Float>(0.44, 0.38, 0.54),
            SIMD3<Float>(0.52, 0.42, 0.46),
            SIMD3<Float>(0.36, 0.50, 0.40),
            SIMD3<Float>(0.42, 0.36, 0.48)
        ]
        for (index, bubble) in ecto.bubbles.enumerated() {
            let localPhase = ecto.motionPhase + Float(index) * 0.83
            let drift = SIMD3<Float>(
                sin(Float(time) * 0.32 + localPhase) * 0.0030,
                cos(Float(time) * 0.27 + localPhase * 0.7) * 0.0024,
                sin(Float(time) * 0.23 - localPhase) * 0.0026
            )
            let pulse = sin(Float(time) * 0.64 + localPhase) * 0.035
            bubble.position = bubbleBases[index % bubbleBases.count] + drift
            bubble.scale = bubbleScales[index % bubbleScales.count] * (1.0 + pulse)

            if let material = materialFactory.makeOuterShellMaterial(
                variant: ecto.variant,
                phase: Float(time) * 0.31 + localPhase + 8.0,
                visibility: 0.20 + Float(index % 3) * 0.035,
                reactivity: 0.03 + reactivity * 0.16
            ) {
                bubble.model?.materials = [material]
            } else {
                bubble.model?.materials = [
                    materialFactory.makeOuterShellFallbackMaterial(
                        variant: ecto.variant,
                        alpha: 0.10
                    )
                ]
            }
        }

        let corePulse = 1 + sin(Float(time) * 3.9 + ecto.motionPhase) * 0.16 + reactivity * 0.28
        ecto.core.scale = SIMD3<Float>(repeating: corePulse)
        ecto.coreHalo.scale = SIMD3<Float>(
            1.06 + sin(Float(time) * 2.7 + ecto.motionPhase) * 0.11 + reactivity * 0.20,
            0.80 + sin(Float(time) * 2.1 + ecto.motionPhase) * 0.09 + reactivity * 0.14,
            0.92 + reactivity * 0.12
        )
        ecto.core.position = SIMD3<Float>(
            sin(Float(time) * 1.4 + ecto.motionPhase) * 0.008,
            -0.086 + cos(Float(time) * 1.1 + ecto.motionPhase) * 0.006,
            0.086
        )
        ecto.coreHalo.position = SIMD3<Float>(
            ecto.core.position.x * 0.55,
            ecto.core.position.y,
            0.074
        )

        let mouthOpen: Float = ecto.state == .landing ? 1 : reactivity
        ecto.mouth.scale = SIMD3<Float>(
            1.0 + mouthOpen * 0.26,
            0.26 + mouthOpen * 0.88,
            0.24
        )

        let blink = max(0.18, 1.0 - pow(max(0, sin(Float(time) * 1.6 + ecto.motionPhase)), 18.0) * 0.82)
        for (index, eye) in ecto.eyes.enumerated() {
            let eyeBob = sin(Float(time) * 2.0 + ecto.motionPhase + Float(index) * 1.7) * 0.004
            eye.position.y = 0.046 + eyeBob
            eye.scale = SIMD3<Float>(
                0.88,
                (1.08 + reactivity * 0.22) * blink,
                0.30
            )
        }

        let shadowPulse: Float = ecto.state == .landing ? 0.34 : 0
        ecto.contactShadow.scale = SIMD3<Float>(
            0.72 + shadowPulse * 0.55 + reactivity * 0.05,
            0.020,
            0.42 + shadowPulse * 0.12
        )
    }

    private func orientEcto(_ ecto: RenderedEcto, toward cameraPosition: SIMD3<Float>) {
        var direction = cameraPosition - ecto.anchor.position
        direction.y = 0
        guard simd_length_squared(direction) > 0.000_001 else {
            return
        }
        ecto.root.orientation = simd_quatf(
            from: SIMD3<Float>(0, 0, 1),
            to: simd_normalize(direction)
        )
    }

    private func landingSurface(
        near point: SIMD3<Float>,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) -> ARPlaneSurfaceLocation? {
        if let reticleSurface = reticleHorizontalSurface(
            cameraPosition: cameraPosition,
            in: arView
        ) {
            return reticleSurface
        }

        return planeAnchors
            .filter { $0.alignment == .horizontal }
            .compactMap { plane -> ARPlaneSurfaceLocation? in
                let location = ARPlaneSurfaceGeometry.location(
                    on: plane,
                    nearestTo: point,
                    normalFacing: cameraPosition
                )
                guard location.normal.y > 0.55 else {
                    return nil
                }
                guard simd_distance(location.position, cameraPosition) <= 3.2 else {
                    return nil
                }
                guard let screenPosition = arView.project(location.position),
                      arView.bounds.insetBy(dx: -40, dy: -80).contains(screenPosition)
                else {
                    return nil
                }
                return location
            }
            .min {
                simd_distance($0.position, point) < simd_distance($1.position, point)
            }
    }

    private func reticleHorizontalSurface(
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) -> ARPlaneSurfaceLocation? {
        let screenCenter = CGPoint(
            x: arView.bounds.midX,
            y: arView.bounds.midY
        )
        let raycastResults = arView.raycast(
            from: screenCenter,
            allowing: .estimatedPlane,
            alignment: .horizontal
        )

        guard let result = raycastResults.first else {
            return nil
        }

        let position = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        guard simd_distance(position, cameraPosition) <= 3.2 else {
            return nil
        }

        return ARPlaneSurfaceLocation(
            planeID: result.anchor?.identifier ?? UUID(),
            position: position,
            normal: SIMD3<Float>(0, 1, 0)
        )
    }

    private func nextJumpSurface(
        from currentPosition: SIMD3<Float>,
        planeAnchors: [ARPlaneAnchor],
        cameraPosition: SIMD3<Float>,
        in arView: ARView
    ) -> ARPlaneSurfaceLocation? {
        let randomOffset = SIMD3<Float>(
            Float.random(in: -0.75...0.75),
            Float.random(in: -0.05...0.24),
            Float.random(in: -0.75...0.75)
        )
        let desired = currentPosition + randomOffset

        return planeAnchors
            .filter { $0.alignment == .horizontal }
            .compactMap { plane -> ARPlaneSurfaceLocation? in
                let location = ARPlaneSurfaceGeometry.location(
                    on: plane,
                    nearestTo: desired,
                    normalFacing: cameraPosition
                )
                guard location.normal.y > 0.55 else {
                    return nil
                }
                let playerDistance = simd_distance(location.position, cameraPosition)
                let jumpDistance = simd_distance(location.position + location.normal * blobRadius, currentPosition)
                guard playerDistance <= 3.2, jumpDistance >= 0.28, jumpDistance <= 1.45 else {
                    return nil
                }
                guard let screenPosition = arView.project(location.position),
                      arView.bounds.insetBy(dx: -60, dy: -120).contains(screenPosition)
                else {
                    return nil
                }
                return location
            }
            .min {
                simd_distance($0.position, desired) < simd_distance($1.position, desired)
            }
    }

    private func makeEctoVisual(_ ecto: Ecto) -> EctoVisual {
        let root = Entity()
        root.name = "ecto-root:\(ecto.id.uuidString)"

        let outerShellMaterials: [any Material]
        if let outerShellMaterial = materialFactory.makeOuterShellMaterial(
            variant: ecto.variant,
            phase: Float.random(in: 0...10),
            visibility: 0.88
        ) {
            outerShellMaterials = [outerShellMaterial]
        } else {
            outerShellMaterials = [
                materialFactory.makeOuterShellFallbackMaterial(variant: ecto.variant, alpha: 0.24)
            ]
        }

        let bodyMesh = makeJellyBlobMesh(radius: ecto.radius)
        let outerShell = ModelEntity(
            mesh: bodyMesh,
            materials: outerShellMaterials
        )
        outerShell.name = "ecto-outer-shell:\(ecto.id.uuidString)"
        outerShell.scale = outerShellRestScale
        disableRealityKitShadows(outerShell)

        let innerGelMaterials: [any Material]
        if let innerGelMaterial = materialFactory.makeInnerGelMaterial(
            variant: ecto.variant,
            phase: Float.random(in: 20...30),
            visibility: 0.92,
            reactivity: 0.10
        ) {
            innerGelMaterials = [innerGelMaterial]
        } else {
            innerGelMaterials = [
                materialFactory.makeInnerGelFallbackMaterial(variant: ecto.variant, alpha: 0.48)
            ]
        }
        let innerGel = ModelEntity(
            mesh: bodyMesh,
            materials: innerGelMaterials
        )
        innerGel.name = "ecto-inner-gel:\(ecto.id.uuidString)"
        innerGel.scale = outerShellRestScale * innerGelScaleRatio
        innerGel.position = .zero
        disableRealityKitShadows(innerGel)
        root.addChild(innerGel)

        let jellyLobes = [
            makeJellyLobe(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 50...60),
                position: SIMD3<Float>(-0.118, -0.034, 0.044),
                scale: SIMD3<Float>(0.48, 0.52, 0.34)
            ),
            makeJellyLobe(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 60...70),
                position: SIMD3<Float>(0.118, -0.036, 0.044),
                scale: SIMD3<Float>(0.48, 0.50, 0.34)
            ),
            makeJellyLobe(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 70...80),
                position: SIMD3<Float>(0.000, -0.126, 0.070),
                scale: SIMD3<Float>(0.78, 0.22, 0.44)
            ),
            makeJellyLobe(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 80...90),
                position: SIMD3<Float>(0.000, -0.120, -0.020),
                scale: SIMD3<Float>(0.62, 0.18, 0.30)
            ),
            makeJellyLobe(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 80...90),
                position: SIMD3<Float>(-0.046, 0.152, 0.040),
                scale: SIMD3<Float>(0.26, 0.46, 0.20)
            ),
            makeJellyLobe(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 90...100),
                position: SIMD3<Float>(-0.050, -0.004, 0.092),
                scale: SIMD3<Float>(0.30, 0.34, 0.24)
            ),
            makeJellyLobe(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 100...110),
                position: SIMD3<Float>(0.050, -0.006, 0.092),
                scale: SIMD3<Float>(0.30, 0.34, 0.24)
            )
        ]
        jellyLobes.forEach { root.addChild($0) }

        let bubbles = [
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 120...130),
                position: SIMD3<Float>(-0.078, 0.104, 0.026),
                scale: SIMD3<Float>(0.70, 0.54, 0.62),
                visibility: 0.22
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 130...140),
                position: SIMD3<Float>(0.080, 0.088, -0.018),
                scale: SIMD3<Float>(0.48, 0.64, 0.46),
                visibility: 0.18
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 140...150),
                position: SIMD3<Float>(-0.024, 0.020, 0.068),
                scale: SIMD3<Float>(0.44, 0.42, 0.58),
                visibility: 0.24
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 150...160),
                position: SIMD3<Float>(0.046, -0.044, 0.026),
                scale: SIMD3<Float>(0.56, 0.46, 0.50),
                visibility: 0.20
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 160...170),
                position: SIMD3<Float>(-0.094, -0.070, -0.006),
                scale: SIMD3<Float>(0.38, 0.54, 0.42),
                visibility: 0.18
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 170...180),
                position: SIMD3<Float>(0.092, -0.096, 0.044),
                scale: SIMD3<Float>(0.62, 0.48, 0.58),
                visibility: 0.24
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 180...190),
                position: SIMD3<Float>(0.010, -0.150, 0.078),
                scale: SIMD3<Float>(0.44, 0.38, 0.54),
                visibility: 0.21
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 190...200),
                position: SIMD3<Float>(-0.010, -0.024, -0.072),
                scale: SIMD3<Float>(0.52, 0.42, 0.46),
                visibility: 0.17
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 200...210),
                position: SIMD3<Float>(0.108, 0.012, -0.044),
                scale: SIMD3<Float>(0.36, 0.50, 0.40),
                visibility: 0.18
            ),
            makeInternalBubble(
                id: ecto.id,
                variant: ecto.variant,
                radius: ecto.radius,
                phase: Float.random(in: 210...220),
                position: SIMD3<Float>(-0.110, 0.012, 0.042),
                scale: SIMD3<Float>(0.42, 0.36, 0.48),
                visibility: 0.21
            )
        ]
        bubbles.forEach { root.addChild($0) }

        let coreHalo = ModelEntity(
            mesh: .generateSphere(radius: ecto.radius * 0.25),
            materials: [materialFactory.makeCoreMaterial(variant: ecto.variant, intensity: 0.28)]
        )
        coreHalo.name = "ecto-core-halo:\(ecto.id.uuidString)"
        coreHalo.position = SIMD3<Float>(0, -0.086, 0.074)
        coreHalo.scale = SIMD3<Float>(1.16, 0.88, 1.00)
        disableRealityKitShadows(coreHalo)
        root.addChild(coreHalo)

        let core = ModelEntity(
            mesh: .generateSphere(radius: ecto.radius * 0.064),
            materials: [materialFactory.makeCoreMaterial(variant: ecto.variant, intensity: 0.54)]
        )
        core.name = "ecto-core:\(ecto.id.uuidString)"
        core.position = SIMD3<Float>(0, -0.086, 0.086)
        disableRealityKitShadows(core)
        root.addChild(core)

        root.addChild(outerShell)

        let eyes = [
            makeEye(id: ecto.id, xOffset: -0.052, variant: ecto.variant),
            makeEye(id: ecto.id, xOffset: 0.052, variant: ecto.variant)
        ]
        for eye in eyes {
            root.addChild(eye)
        }

        let mouth = makeMouth(id: ecto.id, variant: ecto.variant, radius: ecto.radius)
        root.addChild(mouth)

        let dropletLayer = makeDropletLayer(variant: ecto.variant, radius: ecto.radius)
        dropletLayer.name = "ecto-droplets:\(ecto.id.uuidString)"
        root.addChild(dropletLayer)

        let contactShadow = ModelEntity(
            mesh: .generateSphere(radius: ecto.radius),
            materials: [materialFactory.makeContactShadowMaterial(variant: ecto.variant)]
        )
        contactShadow.name = "ecto-contact-shadow:\(ecto.id.uuidString)"
        contactShadow.position = SIMD3<Float>(0, -ecto.radius * 0.97, 0)
        contactShadow.scale = SIMD3<Float>(0.72, 0.020, 0.42)
        disableRealityKitShadows(contactShadow)

        let contactGlow = ModelEntity(
            mesh: .generateSphere(radius: ecto.radius),
            materials: [materialFactory.makeCoreMaterial(variant: ecto.variant, intensity: 0.10)]
        )
        contactGlow.name = "ecto-contact-glow:\(ecto.id.uuidString)"
        contactGlow.position = SIMD3<Float>(0, 0.012, 0)
        contactGlow.scale = SIMD3<Float>(1.28, 0.44, 1.18)
        disableRealityKitShadows(contactGlow)
        contactShadow.addChild(contactGlow)

        root.components.set(
            CollisionComponent(
                shapes: [.generateSphere(radius: ecto.radius * 1.10)]
            )
        )

        return EctoVisual(
            root: root,
            outerShell: outerShell,
            innerGel: innerGel,
            jellyLobes: jellyLobes,
            bubbles: bubbles,
            core: core,
            coreHalo: coreHalo,
            eyes: eyes,
            mouth: mouth,
            contactShadow: contactShadow,
            dropletLayer: dropletLayer
        )
    }

    private func makeEye(id: Ecto.ID, xOffset: Float, variant: EctoVariant) -> ModelEntity {
        let eye = ModelEntity(
            mesh: .generateSphere(radius: blobRadius * 0.104),
            materials: [materialFactory.makeEyeMaterial(variant: variant)]
        )
        eye.name = "ecto-eye:\(id.uuidString)"
        eye.position = SIMD3<Float>(xOffset, 0.046, blobRadius * 0.90)
        eye.scale = SIMD3<Float>(0.88, 1.08, 0.30)
        disableRealityKitShadows(eye)

        let socketGlow = ModelEntity(
            mesh: .generateSphere(radius: blobRadius * 0.145),
            materials: [materialFactory.makeCoreMaterial(variant: variant, intensity: 0.14)]
        )
        socketGlow.name = "ecto-eye-socket-glow:\(id.uuidString)"
        socketGlow.position = SIMD3<Float>(0, 0, -blobRadius * 0.020)
        socketGlow.scale = SIMD3<Float>(1.16, 1.04, 0.10)
        disableRealityKitShadows(socketGlow)
        eye.addChild(socketGlow)

        let sparkSide: Float = xOffset < 0 ? -1 : 1
        let eyeSpark = ModelEntity(
            mesh: .generateSphere(radius: blobRadius * 0.024),
            materials: [materialFactory.makeCoreMaterial(variant: variant, intensity: 0.62)]
        )
        eyeSpark.name = "ecto-eye-inner-glow:\(id.uuidString)"
        eyeSpark.position = SIMD3<Float>(blobRadius * 0.010 * sparkSide, blobRadius * 0.008, blobRadius * 0.022)
        eyeSpark.scale = SIMD3<Float>(0.82, 0.82, 0.46)
        disableRealityKitShadows(eyeSpark)
        eye.addChild(eyeSpark)

        let corneaMaterials: [any Material]
        if let material = materialFactory.makeOuterShellMaterial(
            variant: variant,
            phase: Float.random(in: 220...230),
            visibility: 0.26,
            reactivity: 0.04
        ) {
            corneaMaterials = [material]
        } else {
            corneaMaterials = [
                materialFactory.makeOuterShellFallbackMaterial(variant: variant, alpha: 0.10)
            ]
        }
        let cornea = ModelEntity(
            mesh: .generateSphere(radius: blobRadius * 0.128),
            materials: corneaMaterials
        )
        cornea.name = "ecto-eye-cornea:\(id.uuidString)"
        cornea.position = SIMD3<Float>(0, 0, blobRadius * 0.028)
        cornea.scale = SIMD3<Float>(1.06, 1.00, 0.18)
        disableRealityKitShadows(cornea)
        eye.addChild(cornea)

        return eye
    }

    private func makeMouth(id: Ecto.ID, variant: EctoVariant, radius: Float) -> ModelEntity {
        let mouth = ModelEntity(
            mesh: .generateSphere(radius: radius * 0.064),
            materials: [materialFactory.makeMouthMaterial()]
        )
        mouth.name = "ecto-mouth:\(id.uuidString)"
        mouth.position = SIMD3<Float>(0, -0.004, radius * 0.91)
        mouth.scale = SIMD3<Float>(0.96, 0.30, 0.24)
        disableRealityKitShadows(mouth)

        let mouthGlow = ModelEntity(
            mesh: .generateSphere(radius: radius * 0.086),
            materials: [materialFactory.makeCoreMaterial(variant: variant, intensity: 0.14)]
        )
        mouthGlow.name = "ecto-mouth-socket-glow:\(id.uuidString)"
        mouthGlow.position = SIMD3<Float>(0, -radius * 0.002, -radius * 0.018)
        mouthGlow.scale = SIMD3<Float>(1.22, 0.58, 0.12)
        disableRealityKitShadows(mouthGlow)
        mouth.addChild(mouthGlow)

        let innerGlow = ModelEntity(
            mesh: .generateSphere(radius: radius * 0.028),
            materials: [materialFactory.makeCoreMaterial(variant: variant, intensity: 0.34)]
        )
        innerGlow.name = "ecto-mouth-inner-glow:\(id.uuidString)"
        innerGlow.position = SIMD3<Float>(0, -radius * 0.018, radius * 0.020)
        innerGlow.scale = SIMD3<Float>(1.32, 0.54, 0.30)
        disableRealityKitShadows(innerGlow)
        mouth.addChild(innerGlow)

        return mouth
    }

    private func makeInternalBubble(
        id: Ecto.ID,
        variant: EctoVariant,
        radius: Float,
        phase: Float,
        position: SIMD3<Float>,
        scale: SIMD3<Float>,
        visibility: Float
    ) -> ModelEntity {
        let materials: [any Material]
        if let material = materialFactory.makeOuterShellMaterial(
            variant: variant,
            phase: phase,
            visibility: visibility,
            reactivity: 0.04
        ) {
            materials = [material]
        } else {
            materials = [
                materialFactory.makeOuterShellFallbackMaterial(variant: variant, alpha: 0.10)
            ]
        }

        let bubble = ModelEntity(
            mesh: .generateSphere(radius: radius * 0.050),
            materials: materials
        )
        bubble.name = "ecto-internal-bubble:\(id.uuidString)"
        bubble.position = position
        bubble.scale = scale
        disableRealityKitShadows(bubble)
        return bubble
    }

    private func makeJellyBlobMesh(radius: Float, inflate: Float = 1.0) -> MeshResource {
        let rings = 22
        let segments = 40
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var textureCoordinates: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for ringIndex in 0...rings {
            let v = Float(ringIndex) / Float(rings)
            let phi = v * .pi
            let yUnit = cos(phi)
            let ringUnit = sin(phi)
            let lower = max(0, -yUnit)
            let upper = max(0, yUnit)
            let baseFlatten = smoothStep((lower - 0.78) / 0.22)

            for segmentIndex in 0...segments {
                let u = Float(segmentIndex) / Float(segments)
                let theta = u * .pi * 2
                let wobble = 1
                    + sin(theta * 3.0 + 0.35) * 0.030
                    + sin(theta * 5.0 - 1.10) * 0.020
                let belly = 1 + lower * 0.24 - upper * 0.10
                let crownTaper = 1 - upper * upper * 0.12
                let xRadius = radius * ringUnit * belly * crownTaper * wobble * inflate
                let zRadius = radius * ringUnit * (0.82 + lower * 0.12 - upper * 0.04)
                    * (1 + cos(theta * 4.0 + 0.6) * 0.018)
                    * inflate

                let x = cos(theta) * xRadius
                let z = sin(theta) * zRadius
                var y = yUnit * radius * (1.10 - lower * 0.06) - lower * lower * radius * 0.07
                let flattenedY = -radius * 0.80
                y = mix(
                    SIMD3<Float>(0, y, 0),
                    SIMD3<Float>(0, flattenedY, 0),
                    baseFlatten * 0.46
                ).y

                let position = SIMD3<Float>(x, y, z)
                positions.append(position)
                normals.append(simd_normalize(SIMD3<Float>(
                    x / max(radius * 1.12, 0.001),
                    (y + radius * 0.06) / max(radius * 0.94, 0.001),
                    z / max(radius * 0.92, 0.001)
                )))
                textureCoordinates.append(SIMD2<Float>(u, v))
            }
        }

        let rowLength = segments + 1
        for ringIndex in 0..<rings {
            for segmentIndex in 0..<segments {
                let a = UInt32(ringIndex * rowLength + segmentIndex)
                let b = UInt32((ringIndex + 1) * rowLength + segmentIndex)
                let c = UInt32(ringIndex * rowLength + segmentIndex + 1)
                let d = UInt32((ringIndex + 1) * rowLength + segmentIndex + 1)
                indices.append(contentsOf: [a, b, c, c, b, d])
            }
        }

        var descriptor = MeshDescriptor(name: "ecto-jelly-blob")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        descriptor.primitives = .triangles(indices)

        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            return .generateSphere(radius: radius * inflate)
        }
    }

    private func makeJellyLobe(
        id: Ecto.ID,
        variant: EctoVariant,
        radius: Float,
        phase: Float,
        position: SIMD3<Float>,
        scale: SIMD3<Float>
    ) -> ModelEntity {
        let materials: [any Material]
        if let material = materialFactory.makeInnerGelMaterial(
            variant: variant,
            phase: phase,
            visibility: 0.38,
            reactivity: 0.18
        ) {
            materials = [material]
        } else {
            materials = [
                materialFactory.makeInnerGelFallbackMaterial(
                    variant: variant,
                    alpha: 0.28
                )
            ]
        }

        let lobe = ModelEntity(
            mesh: .generateSphere(radius: radius * 0.46),
            materials: materials
        )
        lobe.name = "ecto-jelly-lobe:\(id.uuidString)"
        lobe.position = position
        lobe.scale = scale
        disableRealityKitShadows(lobe)
        return lobe
    }

    private func makeDropletLayer(variant: EctoVariant, radius: Float) -> Entity {
        let entity = Entity()
        var component = ParticleEmitterComponent()
        component.isEmitting = true
        component.emitterShape = .sphere
        component.emitterShapeSize = SIMD3<Float>(repeating: radius * 1.4)
        component.birthLocation = .surface
        component.birthDirection = .normal
        component.fieldSimulationSpace = .local
        component.particlesInheritTransform = true
        component.speed = 0.028
        component.speedVariation = 0.016
        component.radialAmount = 0.56
        component.mainEmitter.birthRate = 11
        component.mainEmitter.birthRateVariation = 4
        component.mainEmitter.lifeSpan = 1.15
        component.mainEmitter.lifeSpanVariation = 0.35
        component.mainEmitter.size = radius * 0.030
        component.mainEmitter.sizeVariation = radius * 0.022
        component.mainEmitter.opacityCurve = .easeFadeOut
        component.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.2
        component.mainEmitter.noiseStrength = 0.03
        component.mainEmitter.noiseScale = 0.06
        component.mainEmitter.noiseAnimationSpeed = 0.22
        component.mainEmitter.blendMode = .additive
        component.mainEmitter.isLightingEnabled = false
        component.mainEmitter.image = materialFactory.makeDropletTexture(variant: variant)
        entity.components.set(component)
        return entity
    }

    private func disableRealityKitShadows(_ entity: Entity) {
        entity.components.set(
            GroundingShadowComponent(
                castsShadow: false,
                receivesShadow: false
            )
        )
    }

    private func statusText(for state: EctoState) -> String {
        switch state {
        case .idle:
            return "ECTO IDLE"
        case .preparingToJump:
            return "ECTO COILING"
        case .airborne:
            return "ECTO JUMP"
        case .landing:
            return "ECTO LAND"
        case .startled:
            return "ECTO STARTLED"
        case .captured:
            return "ECTO CAPTURED"
        }
    }

    private func mix(_ start: SIMD3<Float>, _ end: SIMD3<Float>, _ progress: Float) -> SIMD3<Float> {
        start + (end - start) * min(max(progress, 0), 1)
    }

    private func smoothStep(_ value: Float) -> Float {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

private struct EctoVisual {
    let root: Entity
    let outerShell: ModelEntity
    let innerGel: ModelEntity
    let jellyLobes: [ModelEntity]
    let bubbles: [ModelEntity]
    let core: ModelEntity
    let coreHalo: ModelEntity
    let eyes: [ModelEntity]
    let mouth: ModelEntity
    let contactShadow: ModelEntity
    let dropletLayer: Entity
}

private final class RenderedEcto {
    let id: Ecto.ID
    let anchor: AnchorEntity
    let root: Entity
    let outerShell: ModelEntity
    let innerGel: ModelEntity
    let jellyLobes: [ModelEntity]
    let bubbles: [ModelEntity]
    let core: ModelEntity
    let coreHalo: ModelEntity
    let eyes: [ModelEntity]
    let mouth: ModelEntity
    let contactShadow: ModelEntity
    let dropletLayer: Entity
    let variant: EctoVariant
    var lastUpdatedAt: CFTimeInterval
    var state: EctoState = .idle
    var stateStartedAt: CFTimeInterval
    var nextJumpAt: CFTimeInterval
    var jumpStartPosition: SIMD3<Float>
    var currentPosition: SIMD3<Float>
    var targetPosition: SIMD3<Float>
    let motionPhase: Float

    init(
        id: Ecto.ID,
        anchor: AnchorEntity,
        root: Entity,
        outerShell: ModelEntity,
        innerGel: ModelEntity,
        jellyLobes: [ModelEntity],
        bubbles: [ModelEntity],
        core: ModelEntity,
        coreHalo: ModelEntity,
        eyes: [ModelEntity],
        mouth: ModelEntity,
        contactShadow: ModelEntity,
        dropletLayer: Entity,
        variant: EctoVariant,
        lastUpdatedAt: CFTimeInterval,
        stateStartedAt: CFTimeInterval,
        nextJumpAt: CFTimeInterval,
        currentPosition: SIMD3<Float>,
        targetPosition: SIMD3<Float>,
        motionPhase: Float
    ) {
        self.id = id
        self.anchor = anchor
        self.root = root
        self.outerShell = outerShell
        self.innerGel = innerGel
        self.jellyLobes = jellyLobes
        self.bubbles = bubbles
        self.core = core
        self.coreHalo = coreHalo
        self.eyes = eyes
        self.mouth = mouth
        self.contactShadow = contactShadow
        self.dropletLayer = dropletLayer
        self.variant = variant
        self.lastUpdatedAt = lastUpdatedAt
        self.stateStartedAt = stateStartedAt
        self.nextJumpAt = nextJumpAt
        self.jumpStartPosition = currentPosition
        self.currentPosition = currentPosition
        self.targetPosition = targetPosition
        self.motionPhase = motionPhase
    }
}
