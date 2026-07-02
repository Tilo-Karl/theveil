import Metal
import RealityKit

@MainActor
final class ProceduralEssenceRibbon {
    let entity: ModelEntity

    private static let ribbonCount = 7
    private static let segmentCount = 44
    private static let verticesPerRibbon = segmentCount * 2
    private static let indicesPerSegment = 12

    private let mesh: LowLevelMesh
    private let radius: Float
    private let phase: Float

    init(radius: Float, phase: Float, baseMaterial: CustomMaterial) throws {
        self.radius = radius
        self.phase = phase

        let vertexCount = Self.ribbonCount * Self.verticesPerRibbon
        let indexCount = Self.ribbonCount * (Self.segmentCount - 1) * Self.indicesPerSegment
        let descriptor = LowLevelMesh.Descriptor(
            vertexCapacity: vertexCount,
            vertexAttributes: [
                .init(semantic: .position, format: .float3, offset: 0),
                .init(
                    semantic: .uv0,
                    format: .float2,
                    offset: MemoryLayout<RibbonVertex>.offset(of: \.uv) ?? 16
                ),
                .init(
                    semantic: .uv1,
                    format: .float2,
                    offset: MemoryLayout<RibbonVertex>.offset(of: \.kind) ?? 24
                )
            ],
            vertexLayouts: [
                .init(bufferIndex: 0, bufferStride: MemoryLayout<RibbonVertex>.stride)
            ],
            indexCapacity: indexCount,
            indexType: .uint32
        )

        let mesh = try LowLevelMesh(descriptor: descriptor)
        self.mesh = mesh

        mesh.replaceUnsafeMutableIndices { rawBuffer in
            let indices = rawBuffer.bindMemory(to: UInt32.self)
            var writeIndex = 0

            for ribbonIndex in 0..<Self.ribbonCount {
                let base = ribbonIndex * Self.verticesPerRibbon

                for segmentIndex in 0..<(Self.segmentCount - 1) {
                    let lowerLeft = UInt32(base + segmentIndex * 2)
                    let lowerRight = lowerLeft + 1
                    let upperLeft = lowerLeft + 2
                    let upperRight = lowerLeft + 3

                    let front: [UInt32] = [
                        lowerLeft, upperLeft, lowerRight,
                        lowerRight, upperLeft, upperRight
                    ]
                    let back: [UInt32] = [
                        lowerRight, upperLeft, lowerLeft,
                        upperRight, upperLeft, lowerRight
                    ]

                    for index in front + back {
                        indices[writeIndex] = index
                        writeIndex += 1
                    }
                }
            }
        }

        let boundsRadius = radius * 2.8
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexOffset: 0,
                indexCount: indexCount,
                topology: .triangle,
                materialIndex: 0,
                bounds: BoundingBox(
                    min: SIMD3<Float>(repeating: -boundsRadius),
                    max: SIMD3<Float>(repeating: boundsRadius)
                )
            )
        ])

        let meshResource = try MeshResource(from: mesh)
        var material = baseMaterial
        material.custom.value = SIMD4<Float>(0, 2.15, phase, 0.88)

        entity = ModelEntity(mesh: meshResource, materials: [material])
        entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
        update(
            at: 0,
            reveal: 1,
            trailDirection: SIMD3<Float>(0, -1, 0),
            trailStrength: 0.2
        )
    }

    func update(
        at time: Float,
        reveal: Float,
        trailDirection: SIMD3<Float>,
        trailStrength: Float
    ) {
        let reveal = min(max(reveal, 0), 1)
        let trailStrength = min(max(trailStrength, 0), 1)

        mesh.replaceUnsafeMutableBytes(bufferIndex: 0) { rawBuffer in
            let vertices = rawBuffer.bindMemory(to: RibbonVertex.self)

            for ribbonIndex in 0..<Self.ribbonCount {
                for segmentIndex in 0..<Self.segmentCount {
                    let t = Float(segmentIndex) / Float(Self.segmentCount - 1)
                    let revealedProgress = t * reveal
                    let center = pathPoint(
                        ribbonIndex: ribbonIndex,
                        progress: revealedProgress,
                        time: time,
                        trailDirection: trailDirection,
                        trailStrength: trailStrength
                    ) * reveal
                    let previous = pathPoint(
                        ribbonIndex: ribbonIndex,
                        progress: max(0, revealedProgress - 0.015 * reveal),
                        time: time,
                        trailDirection: trailDirection,
                        trailStrength: trailStrength
                    ) * reveal
                    let next = pathPoint(
                        ribbonIndex: ribbonIndex,
                        progress: min(reveal, revealedProgress + 0.015 * reveal),
                        time: time,
                        trailDirection: trailDirection,
                        trailStrength: trailStrength
                    ) * reveal
                    let tangent = safeNormalize(next - previous, fallback: SIMD3<Float>(0, 1, 0))
                    let reference = abs(tangent.y) > 0.88
                        ? SIMD3<Float>(1, 0, 0)
                        : SIMD3<Float>(0, 1, 0)
                    let side = safeNormalize(
                        simd_cross(tangent, reference),
                        fallback: SIMD3<Float>(1, 0, 0)
                    )
                    let envelope = max(0.08, sin(.pi * t))
                    let shimmer = 0.84 + sin(time * 1.3 + t * 15 + Float(ribbonIndex)) * 0.16
                    let isWisp = ribbonIndex >= 3
                    let baseWidth: Float = isWisp ? 0.028 : 0.009
                    let bodyWidth: Float = isWisp ? 0.085 : 0.014
                    let halfWidth = radius
                        * (baseWidth + envelope * bodyWidth)
                        * shimmer
                        * reveal
                    let vertexIndex = ribbonIndex * Self.verticesPerRibbon + segmentIndex * 2
                    let ribbonKind: Float
                    if !isWisp {
                        ribbonKind = 0
                    } else if ribbonIndex == Self.ribbonCount - 1 {
                        ribbonKind = 2
                    } else {
                        ribbonKind = 1
                    }
                    let kind = SIMD2<Float>(ribbonKind, Float(ribbonIndex) / Float(Self.ribbonCount))

                    vertices[vertexIndex] = RibbonVertex(
                        position: center - side * halfWidth,
                        uv: SIMD2<Float>(t, 0),
                        kind: kind
                    )
                    vertices[vertexIndex + 1] = RibbonVertex(
                        position: center + side * halfWidth,
                        uv: SIMD2<Float>(t, 1),
                        kind: kind
                    )
                }
            }
        }
    }

    private func pathPoint(
        ribbonIndex: Int,
        progress t: Float,
        time: Float,
        trailDirection: SIMD3<Float>,
        trailStrength: Float
    ) -> SIMD3<Float> {
        let ribbon = Float(ribbonIndex)
        let direction: Float = ribbonIndex.isMultiple(of: 2) ? 1 : -1

        if ribbonIndex < 3 {
            let sweep = (0.62 + ribbon * 0.11) * 2 * .pi
            let angle = direction * t * sweep
                + phase
                + ribbon * 1.37
                + time * (0.1 + ribbon * 0.018)
            let radial = radius * (0.76 + sin(time * 0.47 + t * 9 + ribbon) * 0.11)
            let tilt = 0.28 + ribbon * 0.13

            let orbit = SIMD3<Float>(
                cos(angle) * radial,
                sin(angle + ribbon * 0.7) * radial * tilt,
                sin(angle) * radial * (0.72 + ribbon * 0.06)
            )
            return orbit + trailDirection * t * radius * 0.22 * trailStrength
        }

        let wisp = ribbon - 3
        let envelope = sin(.pi * t)
        let angle = direction * t * 2 * .pi * (0.48 + wisp * 0.13)
            + phase
            + ribbon * 0.83
            + time * (0.12 + ribbon * 0.012)
        let radial = radius * envelope * (0.7 + wisp * 0.16)
        let vertical = (t - 0.22) * radius * (3.8 + wisp * 0.55)
        let flutter = envelope * radius * (0.16 + wisp * 0.025)
        let lateralDrift = (wisp - 1.5) * radius * t * 0.42
        let depthDrift = sin(wisp * 1.7 + phase) * radius * t * 0.55

        return SIMD3<Float>(
            cos(angle) * radial
                + sin(time * 0.64 + t * 13 + ribbon) * flutter
                + lateralDrift,
            vertical + sin(angle * 1.2 + time * 0.37) * radius * 0.28,
            sin(angle) * radial
                + cos(time * 0.53 + t * 11 - ribbon) * flutter
                + depthDrift
        )
    }

    private func safeNormalize(
        _ vector: SIMD3<Float>,
        fallback: SIMD3<Float>
    ) -> SIMD3<Float> {
        let lengthSquared = simd_length_squared(vector)
        guard lengthSquared > 0.000_001 else {
            return fallback
        }
        return vector / sqrt(lengthSquared)
    }

}

private struct RibbonVertex {
    var position: SIMD3<Float>
    var uv: SIMD2<Float>
    var kind: SIMD2<Float>
}
