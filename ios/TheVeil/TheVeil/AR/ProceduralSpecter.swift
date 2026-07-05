import RealityKit
import simd

@MainActor
enum ProceduralSpecter {
    static func makeMesh() throws -> MeshResource {
        let field = SpecterEnergyField()
        let bounds = SpecterMeshBounds(
            minimum: SIMD3<Float>(-0.48, -0.52, -0.48),
            maximum: SIMD3<Float>(0.48, 0.56, 0.48),
            resolution: SIMD3<Int>(32, 36, 32)
        )
        let samples = sample(field: field, in: bounds)
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        positions.reserveCapacity(50_000)
        normals.reserveCapacity(50_000)
        indices.reserveCapacity(50_000)

        for z in 0..<(bounds.resolution.z - 1) {
            for y in 0..<(bounds.resolution.y - 1) {
                for x in 0..<(bounds.resolution.x - 1) {
                    let cube = cubeSamples(x: x, y: y, z: z, samples: samples, bounds: bounds)
                    polygonize(cube: cube, field: field, positions: &positions, normals: &normals, indices: &indices)
                }
            }
        }

        var descriptor = MeshDescriptor(name: "specter-body")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    private static let cubeOffsets = [
        SIMD3<Int>(0, 0, 0), SIMD3<Int>(1, 0, 0), SIMD3<Int>(1, 1, 0), SIMD3<Int>(0, 1, 0),
        SIMD3<Int>(0, 0, 1), SIMD3<Int>(1, 0, 1), SIMD3<Int>(1, 1, 1), SIMD3<Int>(0, 1, 1)
    ]

    private static let tetrahedra = [
        SIMD4<Int>(0, 5, 1, 6), SIMD4<Int>(0, 1, 2, 6), SIMD4<Int>(0, 2, 3, 6),
        SIMD4<Int>(0, 3, 7, 6), SIMD4<Int>(0, 7, 4, 6), SIMD4<Int>(0, 4, 5, 6)
    ]

    private static func sample(field: SpecterEnergyField, in bounds: SpecterMeshBounds) -> [SpecterFieldSample] {
        var samples: [SpecterFieldSample] = []
        samples.reserveCapacity(bounds.resolution.x * bounds.resolution.y * bounds.resolution.z)

        for z in 0..<bounds.resolution.z {
            for y in 0..<bounds.resolution.y {
                for x in 0..<bounds.resolution.x {
                    let position = bounds.position(x: x, y: y, z: z)
                    samples.append(SpecterFieldSample(position: position, distance: field.distance(to: position)))
                }
            }
        }
        return samples
    }

    private static func cubeSamples(x: Int, y: Int, z: Int, samples: [SpecterFieldSample], bounds: SpecterMeshBounds) -> [SpecterFieldSample] {
        cubeOffsets.map { offset in samples[bounds.index(x: x + offset.x, y: y + offset.y, z: z + offset.z)] }
    }

    private static func polygonize(cube: [SpecterFieldSample], field: SpecterEnergyField, positions: inout [SIMD3<Float>], normals: inout [SIMD3<Float>], indices: inout [UInt32]) {
        for tetrahedron in tetrahedra {
            let vertices = [cube[tetrahedron.x], cube[tetrahedron.y], cube[tetrahedron.z], cube[tetrahedron.w]]
            let inside = vertices.indices.filter { vertices[$0].distance <= 0 }
            let outside = vertices.indices.filter { vertices[$0].distance > 0 }

            switch inside.count {
            case 1:
                let center = inside[0]
                appendTriangle(points: outside.map { interpolate(vertices[center], vertices[$0]) }, field: field, positions: &positions, normals: &normals, indices: &indices)
            case 2:
                let a = inside[0], b = inside[1], c = outside[0], d = outside[1]
                let ac = interpolate(vertices[a], vertices[c])
                let ad = interpolate(vertices[a], vertices[d])
                let bc = interpolate(vertices[b], vertices[c])
                let bd = interpolate(vertices[b], vertices[d])
                appendTriangle(points: [ac, bc, ad], field: field, positions: &positions, normals: &normals, indices: &indices)
                appendTriangle(points: [ad, bc, bd], field: field, positions: &positions, normals: &normals, indices: &indices)
            case 3:
                let center = outside[0]
                appendTriangle(points: inside.reversed().map { interpolate(vertices[center], vertices[$0]) }, field: field, positions: &positions, normals: &normals, indices: &indices)
            default:
                continue
            }
        }
    }

    private static func appendTriangle(points: [SIMD3<Float>], field: SpecterEnergyField, positions: inout [SIMD3<Float>], normals: inout [SIMD3<Float>], indices: inout [UInt32]) {
        guard points.count == 3 else { return }
        for point in points {
            indices.append(UInt32(positions.count))
            positions.append(point)
            normals.append(field.normal(at: point))
        }
    }

    private static func interpolate(_ first: SpecterFieldSample, _ second: SpecterFieldSample) -> SIMD3<Float> {
        let denominator = first.distance - second.distance
        let progress = abs(denominator) > 0.000_001 ? min(max(first.distance / denominator, 0), 1) : 0.5
        return simd_mix(first.position, second.position, SIMD3<Float>(repeating: progress))
    }
}

private struct SpecterMeshBounds {
    let minimum: SIMD3<Float>
    let maximum: SIMD3<Float>
    let resolution: SIMD3<Int>

    func position(x: Int, y: Int, z: Int) -> SIMD3<Float> {
        let divisor = SIMD3<Float>(Float(resolution.x - 1), Float(resolution.y - 1), Float(resolution.z - 1))
        let progress = SIMD3<Float>(Float(x), Float(y), Float(z)) / divisor
        return simd_mix(minimum, maximum, progress)
    }

    func index(x: Int, y: Int, z: Int) -> Int {
        x + resolution.x * (y + resolution.y * z)
    }
}

private struct SpecterFieldSample {
    let position: SIMD3<Float>
    let distance: Float
}

private struct SpecterEnergyField {
    func distance(to point: SIMD3<Float>) -> Float {
        var distance = sphere(point, center: SIMD3<Float>(0, 0.02, 0), radius: 0.12)
        let parts: [(SIMD3<Float>, Float, Float)] = [
            (SIMD3<Float>(-0.18, 0.15, -0.12), 0.14, 0.08), (SIMD3<Float>(0.22, 0.08, 0.18), 0.15, 0.08),
            (SIMD3<Float>(-0.12, -0.22, 0.25), 0.13, 0.07), (SIMD3<Float>(0.25, -0.15, -0.2), 0.14, 0.08),
            (SIMD3<Float>(-0.2, 0.35, 0.05), 0.11, 0.07), (SIMD3<Float>(0.15, 0.4, -0.15), 0.1, 0.065),
            (SIMD3<Float>(0.08, -0.38, 0.2), 0.12, 0.07), (SIMD3<Float>(-0.25, -0.32, -0.15), 0.11, 0.07),
            (SIMD3<Float>(0.35, 0.2, 0.05), 0.08, 0.045), (SIMD3<Float>(-0.32, -0.1, -0.35), 0.085, 0.045),
            (SIMD3<Float>(0.1, 0.45, 0.3), 0.075, 0.04), (SIMD3<Float>(-0.28, 0.25, 0.3), 0.08, 0.045),
            (SIMD3<Float>(0.38, 0.0, 0.0), 0.13, 0.08), (SIMD3<Float>(-0.35, 0.05, 0.0), 0.12, 0.075),
            (SIMD3<Float>(0.05, 0.28, -0.28), 0.095, 0.06), (SIMD3<Float>(-0.15, -0.28, 0.32), 0.09, 0.055)
        ]
        for part in parts {
            distance = smoothUnion(distance, sphere(point, center: part.0, radius: part.1), radius: part.2)
        }
        return distance
    }

    func normal(at point: SIMD3<Float>) -> SIMD3<Float> {
        let epsilon: Float = 0.0025
        let x = distance(to: point + SIMD3<Float>(epsilon, 0, 0)) - distance(to: point - SIMD3<Float>(epsilon, 0, 0))
        let y = distance(to: point + SIMD3<Float>(0, epsilon, 0)) - distance(to: point - SIMD3<Float>(0, epsilon, 0))
        let z = distance(to: point + SIMD3<Float>(0, 0, epsilon)) - distance(to: point - SIMD3<Float>(0, 0, epsilon))
        let gradient = SIMD3<Float>(x, y, z)
        let lengthSquared = simd_length_squared(gradient)
        return lengthSquared > 0.000_001 ? gradient / sqrt(lengthSquared) : SIMD3<Float>(0, 1, 0)
    }

    private func sphere(_ point: SIMD3<Float>, center: SIMD3<Float>, radius: Float) -> Float {
        simd_length(point - center) - radius
    }

    private func smoothUnion(_ first: Float, _ second: Float, radius: Float) -> Float {
        let blend = max(radius - abs(first - second), 0) / radius
        return min(first, second) - blend * blend * radius * 0.25
    }
}
