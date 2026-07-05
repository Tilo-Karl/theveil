import RealityKit
import simd

@MainActor
enum ProceduralLostSoulBody {
    static func makeMesh() throws -> MeshResource {
        let field = LostSoulDistanceField()
        let bounds = LostSoulMeshBounds(
            minimum: SIMD3<Float>(-0.38, -0.78, -0.24),
            maximum: SIMD3<Float>(0.38, 0.76, 0.24),
            resolution: SIMD3<Int>(28, 52, 22)
        )
        let samples = sample(field: field, in: bounds)
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        positions.reserveCapacity(36_000)
        normals.reserveCapacity(36_000)
        indices.reserveCapacity(36_000)

        for z in 0..<(bounds.resolution.z - 1) {
            for y in 0..<(bounds.resolution.y - 1) {
                for x in 0..<(bounds.resolution.x - 1) {
                    let cube = cubeSamples(
                        x: x,
                        y: y,
                        z: z,
                        samples: samples,
                        bounds: bounds
                    )
                    polygonize(
                        cube: cube,
                        field: field,
                        positions: &positions,
                        normals: &normals,
                        indices: &indices
                    )
                }
            }
        }

        var descriptor = MeshDescriptor(name: "lost-soul-body")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    private static let cubeOffsets = [
        SIMD3<Int>(0, 0, 0),
        SIMD3<Int>(1, 0, 0),
        SIMD3<Int>(1, 1, 0),
        SIMD3<Int>(0, 1, 0),
        SIMD3<Int>(0, 0, 1),
        SIMD3<Int>(1, 0, 1),
        SIMD3<Int>(1, 1, 1),
        SIMD3<Int>(0, 1, 1)
    ]

    private static let tetrahedra = [
        SIMD4<Int>(0, 5, 1, 6),
        SIMD4<Int>(0, 1, 2, 6),
        SIMD4<Int>(0, 2, 3, 6),
        SIMD4<Int>(0, 3, 7, 6),
        SIMD4<Int>(0, 7, 4, 6),
        SIMD4<Int>(0, 4, 5, 6)
    ]

    private static func sample(
        field: LostSoulDistanceField,
        in bounds: LostSoulMeshBounds
    ) -> [LostSoulFieldSample] {
        var samples: [LostSoulFieldSample] = []
        samples.reserveCapacity(
            bounds.resolution.x * bounds.resolution.y * bounds.resolution.z
        )

        for z in 0..<bounds.resolution.z {
            for y in 0..<bounds.resolution.y {
                for x in 0..<bounds.resolution.x {
                    let position = bounds.position(x: x, y: y, z: z)
                    samples.append(
                        LostSoulFieldSample(
                            position: position,
                            distance: field.distance(to: position)
                        )
                    )
                }
            }
        }
        return samples
    }

    private static func cubeSamples(
        x: Int,
        y: Int,
        z: Int,
        samples: [LostSoulFieldSample],
        bounds: LostSoulMeshBounds
    ) -> [LostSoulFieldSample] {
        cubeOffsets.map { offset in
            samples[bounds.index(x: x + offset.x, y: y + offset.y, z: z + offset.z)]
        }
    }

    private static func polygonize(
        cube: [LostSoulFieldSample],
        field: LostSoulDistanceField,
        positions: inout [SIMD3<Float>],
        normals: inout [SIMD3<Float>],
        indices: inout [UInt32]
    ) {
        for tetrahedron in tetrahedra {
            let vertices = [
                cube[tetrahedron.x],
                cube[tetrahedron.y],
                cube[tetrahedron.z],
                cube[tetrahedron.w]
            ]
            let inside = vertices.indices.filter { vertices[$0].distance <= 0 }
            let outside = vertices.indices.filter { vertices[$0].distance > 0 }

            switch inside.count {
            case 1:
                let center = inside[0]
                appendTriangle(
                    points: outside.map { interpolate(vertices[center], vertices[$0]) },
                    field: field,
                    positions: &positions,
                    normals: &normals,
                    indices: &indices
                )

            case 2:
                let a = inside[0]
                let b = inside[1]
                let c = outside[0]
                let d = outside[1]
                let ac = interpolate(vertices[a], vertices[c])
                let ad = interpolate(vertices[a], vertices[d])
                let bc = interpolate(vertices[b], vertices[c])
                let bd = interpolate(vertices[b], vertices[d])
                appendTriangle(
                    points: [ac, bc, ad],
                    field: field,
                    positions: &positions,
                    normals: &normals,
                    indices: &indices
                )
                appendTriangle(
                    points: [ad, bc, bd],
                    field: field,
                    positions: &positions,
                    normals: &normals,
                    indices: &indices
                )

            case 3:
                let center = outside[0]
                appendTriangle(
                    points: inside.reversed().map { interpolate(vertices[center], vertices[$0]) },
                    field: field,
                    positions: &positions,
                    normals: &normals,
                    indices: &indices
                )

            default:
                continue
            }
        }
    }

    private static func appendTriangle(
        points: [SIMD3<Float>],
        field: LostSoulDistanceField,
        positions: inout [SIMD3<Float>],
        normals: inout [SIMD3<Float>],
        indices: inout [UInt32]
    ) {
        guard points.count == 3 else {
            return
        }

        for point in points {
            indices.append(UInt32(positions.count))
            positions.append(point)
            normals.append(field.normal(at: point))
        }
    }

    private static func interpolate(
        _ first: LostSoulFieldSample,
        _ second: LostSoulFieldSample
    ) -> SIMD3<Float> {
        let denominator = first.distance - second.distance
        let progress = abs(denominator) > 0.000_001
            ? min(max(first.distance / denominator, 0), 1)
            : 0.5
        return simd_mix(
            first.position,
            second.position,
            SIMD3<Float>(repeating: progress)
        )
    }
}

private struct LostSoulMeshBounds {
    let minimum: SIMD3<Float>
    let maximum: SIMD3<Float>
    let resolution: SIMD3<Int>

    func position(x: Int, y: Int, z: Int) -> SIMD3<Float> {
        let divisor = SIMD3<Float>(
            Float(resolution.x - 1),
            Float(resolution.y - 1),
            Float(resolution.z - 1)
        )
        let progress = SIMD3<Float>(Float(x), Float(y), Float(z)) / divisor
        return simd_mix(minimum, maximum, progress)
    }

    func index(x: Int, y: Int, z: Int) -> Int {
        x + resolution.x * (y + resolution.y * z)
    }
}

private struct LostSoulFieldSample {
    let position: SIMD3<Float>
    let distance: Float
}

private struct LostSoulDistanceField {
    func distance(to point: SIMD3<Float>) -> Float {
        var distance = ellipsoid(
            point,
            center: SIMD3<Float>(-0.006, 0.59, 0.004),
            radii: SIMD3<Float>(0.104, 0.12, 0.093)
        )
        distance = smoothUnion(
            distance,
            ellipsoid(
                point,
                center: SIMD3<Float>(-0.004, 0.52, -0.012),
                radii: SIMD3<Float>(0.086, 0.09, 0.078)
            ),
            radius: 0.025
        )
        distance = smoothUnion(
            distance,
            ellipsoid(
                point,
                center: SIMD3<Float>(-0.004, 0.555, -0.095),
                radii: SIMD3<Float>(0.021, 0.033, 0.026)
            ),
            radius: 0.012
        )

        distance = smoothUnion(
            distance,
            capsule(
                point,
                start: SIMD3<Float>(0, 0.38, 0),
                end: SIMD3<Float>(-0.004, 0.49, 0),
                radius: 0.048
            ),
            radius: 0.035
        )
        distance = smoothUnion(
            distance,
            ellipsoid(
                point,
                center: SIMD3<Float>(0, 0.18, 0.012),
                radii: SIMD3<Float>(0.17, 0.27, 0.095)
            ),
            radius: 0.055
        )
        distance = smoothUnion(
            distance,
            capsule(
                point,
                start: SIMD3<Float>(-0.155, 0.32, 0.008),
                end: SIMD3<Float>(0.16, 0.335, -0.004),
                radius: 0.055
            ),
            radius: 0.045
        )
        distance = smoothUnion(
            distance,
            ellipsoid(
                point,
                center: SIMD3<Float>(0, -0.1, 0.015),
                radii: SIMD3<Float>(0.125, 0.19, 0.085)
            ),
            radius: 0.05
        )

        distance = addArm(
            to: distance,
            point: point,
            shoulder: SIMD3<Float>(-0.155, 0.31, 0.005),
            elbow: SIMD3<Float>(-0.205, 0.055, 0.018),
            hand: SIMD3<Float>(-0.205, -0.19, -0.028)
        )
        distance = addArm(
            to: distance,
            point: point,
            shoulder: SIMD3<Float>(0.158, 0.325, -0.006),
            elbow: SIMD3<Float>(0.215, 0.12, -0.025),
            hand: SIMD3<Float>(0.13, 0.015, -0.14)
        )

        distance = smoothUnion(
            distance,
            ellipsoid(
                point,
                center: SIMD3<Float>(0, -0.2, 0.01),
                radii: SIMD3<Float>(0.12, 0.11, 0.078)
            ),
            radius: 0.035
        )

        for side in [Float(-1), Float(1)] {
            distance = smoothUnion(
                distance,
                capsule(
                    point,
                    start: SIMD3<Float>(side * 0.06, -0.2, 0.008),
                    end: SIMD3<Float>(side * 0.073, -0.49, side * 0.006),
                    radius: 0.05
                ),
                radius: 0.026
            )
            distance = smoothUnion(
                distance,
                ellipsoid(
                    point,
                    center: SIMD3<Float>(side * 0.067, -0.59, side * 0.006),
                    radii: SIMD3<Float>(0.036, 0.15, 0.035)
                ),
                radius: 0.02
            )
        }
        return distance
    }

    func normal(at point: SIMD3<Float>) -> SIMD3<Float> {
        let epsilon: Float = 0.0025
        let x = distance(to: point + SIMD3<Float>(epsilon, 0, 0))
            - distance(to: point - SIMD3<Float>(epsilon, 0, 0))
        let y = distance(to: point + SIMD3<Float>(0, epsilon, 0))
            - distance(to: point - SIMD3<Float>(0, epsilon, 0))
        let z = distance(to: point + SIMD3<Float>(0, 0, epsilon))
            - distance(to: point - SIMD3<Float>(0, 0, epsilon))
        let gradient = SIMD3<Float>(x, y, z)
        let lengthSquared = simd_length_squared(gradient)
        return lengthSquared > 0.000_001
            ? gradient / sqrt(lengthSquared)
            : SIMD3<Float>(0, 1, 0)
    }

    private func addArm(
        to body: Float,
        point: SIMD3<Float>,
        shoulder: SIMD3<Float>,
        elbow: SIMD3<Float>,
        hand: SIMD3<Float>
    ) -> Float {
        var result = smoothUnion(
            body,
            capsule(point, start: shoulder, end: elbow, radius: 0.038),
            radius: 0.035
        )
        result = smoothUnion(
            result,
            capsule(point, start: elbow, end: hand, radius: 0.031),
            radius: 0.028
        )
        return smoothUnion(
            result,
            ellipsoid(
                point,
                center: hand + SIMD3<Float>(0, -0.035, 0),
                radii: SIMD3<Float>(0.034, 0.06, 0.024)
            ),
            radius: 0.025
        )
    }

    private func ellipsoid(
        _ point: SIMD3<Float>,
        center: SIMD3<Float>,
        radii: SIMD3<Float>
    ) -> Float {
        (simd_length((point - center) / radii) - 1) * min(radii.x, min(radii.y, radii.z))
    }

    private func capsule(
        _ point: SIMD3<Float>,
        start: SIMD3<Float>,
        end: SIMD3<Float>,
        radius: Float
    ) -> Float {
        let segment = end - start
        let progress = min(max(simd_dot(point - start, segment) / simd_length_squared(segment), 0), 1)
        return simd_length(point - (start + segment * progress)) - radius
    }

    private func smoothUnion(_ first: Float, _ second: Float, radius: Float) -> Float {
        let blend = max(radius - abs(first - second), 0) / radius
        return min(first, second) - blend * blend * radius * 0.25
    }
}
